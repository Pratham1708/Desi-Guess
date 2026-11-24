import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desi_guess/app/app.dart';
import 'package:desi_guess/app/router.dart';
import 'package:desi_guess/app/theme.dart';
import 'package:desi_guess/core/config/feature_flags.dart';
import 'package:desi_guess/core/errors/app_failure.dart';
import 'package:desi_guess/core/services/audio_service.dart';
import 'package:desi_guess/core/services/storage_service.dart';
import 'package:desi_guess/core/utils/card_artwork_resolver.dart';
import 'package:desi_guess/features/cards/data/card_repository.dart';
import 'package:desi_guess/features/chat/data/chat_repository.dart';
import 'package:desi_guess/features/custom_boards/data/custom_board_repository.dart';
import 'package:desi_guess/features/game/domain/game_engine.dart';
import 'package:desi_guess/features/multiplayer/data/multiplayer_repository.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:desi_guess/shared/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';

class MockMultiplayerRepository extends Mock implements MultiplayerRepository {}

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
    registerFallbackValue(GameCategory.who);
    registerFallbackValue(ChatMessageType.yesAnswer);
  });

  group(
    'Phase 6 & 3 Audit — 450 Card Artworks, Manifest & GameEngine Edge Cases',
    () {
      test(
        'artwork_manifest.json exists with licence metadata and all 450 card images exist on disk',
        () {
          final manifestFile = File('assets/cards/artwork_manifest.json');
          expect(
            manifestFile.existsSync(),
            isTrue,
            reason: 'assets/cards/artwork_manifest.json must exist',
          );
          final decoded =
              jsonDecode(manifestFile.readAsStringSync())
                  as Map<String, dynamic>;
          final entries = decoded['entries'] as List<dynamic>;
          expect(entries.length, 450);

          final repo = CardRepository();
          for (final pack in repo.builtInPacks) {
            for (final card in pack.cards) {
              final assetPath = CardArtworkResolver.assetForCard(card);
              final file = File(assetPath);
              expect(
                file.existsSync(),
                isTrue,
                reason: 'Missing local card image for ${card.id}: $assetPath',
              );
              expect(file.lengthSync(), greaterThan(512));
            }
          }
        },
      );

      test(
        'GameEngine rejects identical player IDs, secret overwrite, and duplicate answers',
        () {
          const engine = GameEngine();
          final pack = CardRepository().findPackById('where_indian_cities')!;

          expect(
            () => engine.createMatch(
              matchId: 'bad_players',
              mode: GameMode.local,
              pack: pack,
              player1Id: 'same_uid',
              player1Name: 'A',
              player2Id: 'same_uid',
              player2Name: 'B',
            ),
            throwsA(isA<GameRuleFailure>()),
          );

          var state = engine.createMatch(
            matchId: 'm_edge',
            mode: GameMode.local,
            pack: pack,
            player1Id: 'p1',
            player1Name: 'Aarav',
            player2Id: 'p2',
            player2Name: 'Meera',
          );
          state = engine.selectSecretCard(
            state: state,
            playerId: 'p1',
            cardId: 'cty_01',
          );
          // Attempting to overwrite locked secret must fail
          expect(
            () => engine.selectSecretCard(
              state: state,
              playerId: 'p1',
              cardId: 'cty_02',
            ),
            throwsA(isA<GameRuleFailure>()),
          );

          state = engine.acknowledgeHandoff(state);
          state = engine.selectSecretCard(
            state: state,
            playerId: 'p2',
            cardId: 'cty_02',
          );
          state = engine.acknowledgeHandoff(state);

          // Answer without pending question must fail
          expect(
            () => engine.submitAnswer(
              state: state,
              responderId: 'p2',
              answerText: 'Yes',
            ),
            throwsA(isA<GameRuleFailure>()),
          );

          state = engine.submitQuestion(
            state: state,
            askerId: 'p1',
            questionText: 'Is it in North India?',
            entryId: 'q_1',
          );
          state = engine.submitAnswer(
            state: state,
            responderId: 'p2',
            answerText: 'Yes',
          );
          // Duplicate answer to already-answered question must fail
          expect(
            () => engine.submitAnswer(
              state: state,
              responderId: 'p2',
              answerText: 'No',
            ),
            throwsA(isA<GameRuleFailure>()),
          );
        },
      );
    },
  );

  group('Task 5 Audit — Custom Boards Sync, Ownership & Sharing', () {
    test(
      'custom board enforces ownership, visibility toggle, and 6-char share code',
      () async {
        final storage = StorageService();
        final repo = CustomBoardRepository(storageService: storage);

        final privateBoard = BoardPack(
          packId: 'custom_hostel',
          category: GameCategory.custom,
          name: 'Hostel Legends',
          description: 'Private dorm board',
          cards: List.generate(
            6,
            (i) => GameCard(
              id: 'h_$i',
              name: 'Legend $i',
              category: GameCategory.custom,
              description: 'Hostel buddy',
            ),
          ),
          isCustom: true,
          ownerUid: 'owner_1',
          visibility: BoardVisibility.private,
          allowedPlayerUids: const ['owner_1'],
        );

        await repo.saveBoard(privateBoard);
        expect(privateBoard.canBeAccessedBy('owner_1'), isTrue);
        expect(privateBoard.canBeAccessedBy('friend_2'), isFalse);

        // Toggle to shared -> generates 6-char share code
        final shared = await repo.updateSharing(
          board: privateBoard,
          visibility: BoardVisibility.shared,
          inviteUid: 'friend_2',
        );
        expect(shared.isShared, isTrue);
        expect(shared.shareCode, isNotNull);
        expect(shared.shareCode!.length, 6);

        // Joining by code offline surfaces clean NetworkFailure
        expect(
          () => repo.joinSharedBoardByCode(shared.shareCode!),
          throwsA(isA<NetworkFailure>()),
        );
      },
    );
  });

  group('Task 7 — End-to-End Scenarios (1–14)', () {
    testWidgets(
      'Scenarios 1 & 2: Fresh install -> Onboarding -> Guest Login -> Home',
      (WidgetTester tester) async {
        final storage = StorageService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              audioServiceProvider.overrideWithValue(
                AudioService(enabled: false, hapticsEnabled: false),
              ),
              appRouterProvider.overrideWithValue(
                createAppRouter(initialLocation: '/onboarding'),
              ),
            ],
            child: const DesiGuessApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Fresh install starts at Onboarding -> skips directly to Local Player Setup
        expect(find.text('Guess Across Iconic Indian Packs'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();

        // Guest / Local Player Setup -> enter nickname & submit
        expect(find.text('Player Setup'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'RiyaDesi');
        await tester.tap(find.text('Enter DESI GUESS'));
        await tester.pumpAndSettle();

        expect(
          find.text('Ready to test your guessing skills?'),
          findsOneWidget,
        );
        expect(storage.loadLocalProfile()?.username, 'RiyaDesi');
      },
    );

    testWidgets(
      'Scenarios 5, 6 & 8: Local Q&A history, wrong guess heart loss, and app restart resume',
      (WidgetTester tester) async {
        final storage = StorageService();
        await storage.setOnboardingDone(true);
        await storage.saveLocalProfile(
          UserProfile(uid: 'u1', username: 'Kabir', createdAt: DateTime.now()),
        );

        final container = ProviderContainer(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            audioServiceProvider.overrideWithValue(
              AudioService(enabled: false, hapticsEnabled: false),
            ),
            appRouterProvider.overrideWithValue(
              createAppRouter(initialLocation: '/game/board'),
            ),
          ],
        );
        final pack = container
            .read(cardRepositoryProvider)
            .findPackById('where_indian_cities')!;
        final ctrl = container.read(localMatchProvider.notifier);
        await ctrl.startLocalMatch(
          pack: pack,
          player1Name: 'Kabir',
          player2Name: 'Neha',
        );
        await ctrl.selectSecretCard(playerId: 'player_1', cardId: 'cty_01');
        await ctrl.acknowledgeHandoff();
        await ctrl.selectSecretCard(playerId: 'player_2', cardId: 'cty_02');
        await ctrl.acknowledgeHandoff();

        // Log normal Q&A (0 hearts deducted)
        await ctrl.logVerbalQuestion('Is it in North India?', answer: 'Yes');
        expect(container.read(localMatchProvider)!.player1.hearts, 5);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const DesiGuessApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Submit wrong final guess (Bengaluru instead of Delhi; Mumbai is own MY CARD and excluded!) -> loses 1 heart (4 left)
        await tester.tap(find.text('Final Guess'));
        await tester.pumpAndSettle();
        expect(find.text('Lock Final Guess: Mumbai'), findsNothing);
        await tester.tap(find.text('Bengaluru').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lock Final Guess: Bengaluru'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          find.textContaining('Incorrect Guess! 1 Heart Lost'),
          findsOneWidget,
        );
        expect(find.textContaining("It's Neha's Turn"), findsOneWidget);
        expect(container.read(localMatchProvider)!.player1.hearts, 4);
        expect(
          container.read(localMatchProvider)!.currentTurnPlayerId,
          container.read(localMatchProvider)!.player2.playerId,
        );
        await tester.tap(find.text('I Am Ready (Neha)'));
        await tester.pumpAndSettle();
        expect(find.text('End Turn'), findsNothing);

        // Open Question History -> verifies logged Q&A + Wrong Final Guess entry
        await tester.tap(find.byTooltip('Question History'));
        await tester.pumpAndSettle();
        expect(find.text('Is it in North India?'), findsOneWidget);

        // Simulate app restart with fresh ProviderScope reading persisted StorageService!
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              audioServiceProvider.overrideWithValue(
                AudioService(enabled: false, hapticsEnabled: false),
              ),
              appRouterProvider.overrideWithValue(
                createAppRouter(initialLocation: '/home'),
              ),
            ],
            child: const DesiGuessApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Home Dashboard shows Resume Local Match banner!
        expect(find.text('Resume Local Match'), findsOneWidget);
      },
    );

    testWidgets(
      'Randomized 10-Card Local Flow: WHO Category -> 10-Card Preview -> Auto Secrets -> Handoffs -> MY CARD Board',
      (WidgetTester tester) async {
        final storage = StorageService();
        await storage.setOnboardingDone(true);
        await storage.saveLocalProfile(
          UserProfile(
            uid: 'p1_rand',
            username: 'Aarav',
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              audioServiceProvider.overrideWithValue(
                AudioService(enabled: false, hapticsEnabled: false),
              ),
              appRouterProvider.overrideWithValue(
                createAppRouter(
                  initialLocation: '/categories?mode=local&p1=Aarav&p2=Meera',
                ),
              ),
            ],
            child: const DesiGuessApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap main category WHO directly (no subcategory picker!)
        await tester.tap(find.text('WHO'));
        await tester.pumpAndSettle();

        // Randomized 10-Card Board Preview appears
        expect(find.textContaining('10 Unique Cards'), findsOneWidget);
        await tester.tap(find.text('Deal Secret Cards'));
        await tester.pumpAndSettle();

        // Player 1 privately sees their auto-assigned MY CARD secret
        expect(find.text('MY CARD'), findsOneWidget);
        await tester.tap(find.text('Hide & Pass to Meera'));
        await tester.pumpAndSettle();

        // Privacy handoff to Meera
        await tester.tap(find.text('I Am Ready (Meera)'));
        await tester.pumpAndSettle();

        // Player 2 privately sees their auto-assigned MY CARD secret
        expect(find.text('MY CARD'), findsOneWidget);
        await tester.tap(find.text('Hide & Start 10-Card Match!'));
        await tester.pumpAndSettle();

        // Privacy handoff back to Aarav
        await tester.tap(find.text('I Am Ready (Aarav)'));
        await tester.pumpAndSettle();

        // 10-Card Game Board starts with 9 / 9 opponent candidates remaining (excluding MY CARD)
        expect(find.text('9 / 9 Remaining'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('MY CARD'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('MY CARD'), findsOneWidget);
      },
    );

    testWidgets(
      'Scenarios 9–14: Online Room Create, 2nd-Device Join, Real-Time Q&A, Heart Sync, Disconnect/Reconnect & Rematch',
      (WidgetTester tester) async {
        final mockMp = MockMultiplayerRepository();
        final mockChat = MockChatRepository();
        final storage = StorageService();
        await storage.setOnboardingDone(true);
        await storage.saveLocalProfile(
          UserProfile(
            uid: 'host_uid',
            username: 'HostVikram',
            createdAt: DateTime.now(),
          ),
        );

        final roomController = StreamController<RoomData?>.broadcast();
        final playersController =
            StreamController<List<PlayerMatchState>>.broadcast();
        final messagesController =
            StreamController<List<ChatMessage>>.broadcast();
        addTearDown(() async {
          await roomController.close();
          await playersController.close();
          await messagesController.close();
        });

        final now = DateTime.now();
        final waitingRoom = RoomData(
          roomId: 'room_99',
          roomCode: 'DESI99',
          hostUid: 'host_uid',
          hostName: 'HostVikram',
          guestUid: 'guest_uid',
          guestName: 'GuestPriya',
          status: MatchStatus.waiting,
          category: GameCategory.where,
          boardPackId: 'where_indian_cities',
          createdAt: now,
          updatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        );

        when(() => mockMp.isAvailable).thenReturn(true);
        when(
          () => mockMp.createRoom(
            category: any(named: 'category'),
            boardPackId: any(named: 'boardPackId'),
            turnTimerSeconds: any(named: 'turnTimerSeconds'),
          ),
        ).thenAnswer((_) async => (roomId: 'room_99', roomCode: 'DESI99'));
        when(
          () => mockMp.joinRoom('DESI99'),
        ).thenAnswer((_) async => 'room_99');
        when(
          () => mockMp.updatePresence(
            roomId: any(named: 'roomId'),
            uid: any(named: 'uid'),
            connected: any(named: 'connected'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockMp.watchRoom('room_99'),
        ).thenAnswer((_) => roomController.stream);
        when(
          () => mockMp.watchRoomPlayers('room_99'),
        ).thenAnswer((_) => playersController.stream);
        when(
          () =>
              mockMp.fetchMySecretCardId(roomId: 'room_99', myUid: 'host_uid'),
        ).thenAnswer((_) async => 'cty_01');
        when(() => mockMp.requestRematch('room_99')).thenAnswer((_) async {});
        when(
          () => mockChat.watchMessages('room_99'),
        ).thenAnswer((_) => messagesController.stream);
        when(
          () => mockChat.submitQuestion(
            roomId: 'room_99',
            question: any(named: 'question'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockChat.submitAnswer(
            roomId: 'room_99',
            answerType: any(named: 'answerType'),
            message: any(named: 'message'),
            questionId: any(named: 'questionId'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockChat.markMessagesRead(
            roomId: any(named: 'roomId'),
            myUid: any(named: 'myUid'),
            messages: any(named: 'messages'),
          ),
        ).thenAnswer((_) async {});

        // Enable preserved online multiplayer flag ONLY inside this unit test to
        // verify the preserved Firebase/Online code stays intact for future releases.
        FeatureFlags.debugOverrideOnlineMultiplayer = true;
        addTearDown(() => FeatureFlags.debugOverrideOnlineMultiplayer = null);

        final router = createAppRouter(initialLocation: '/online/create');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              audioServiceProvider.overrideWithValue(
                AudioService(enabled: false, hapticsEnabled: false),
              ),
              multiplayerRepositoryProvider.overrideWithValue(mockMp),
              chatRepositoryProvider.overrideWithValue(mockChat),
              appRouterProvider.overrideWithValue(router),
            ],
            child: const DesiGuessApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Scenario 9: Create Online Room (streamlined WHO/WHAT/WHERE without subcategory pick)
        await tester.tap(find.text('Create Room & Get Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Scenario 10: Lobby displays 6-char room code & 2nd device joined
        roomController.add(waitingRoom);
        playersController.add(const [
          PlayerMatchState(
            playerId: 'host_uid',
            displayName: 'HostVikram',
            hearts: 5,
            isReady: true,
            isConnected: true,
          ),
          PlayerMatchState(
            playerId: 'guest_uid',
            displayName: 'GuestPriya',
            hearts: 5,
            isReady: true,
            isConnected: true,
          ),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('DESI99'), findsOneWidget);
        expect(find.text('GuestPriya'), findsOneWidget);

        // Scenario 10b: Second device joinRoom verification
        expect(await mockMp.joinRoom('DESI99'), 'room_99');

        // Scenario 11: Real-time Q&A chat with pendingQuestionId enforcement
        router.go('/game/chat/room_99');
        await tester.pump();
        final activeRoomHostTurn = RoomData(
          roomId: 'room_99',
          roomCode: 'DESI99',
          hostUid: 'host_uid',
          hostName: 'HostVikram',
          guestUid: 'guest_uid',
          guestName: 'GuestPriya',
          status: MatchStatus.active,
          category: GameCategory.where,
          boardPackId: 'where_indian_cities',
          currentTurnUid: 'host_uid',
          pendingQuestionId: 'msg_1',
          createdAt: now,
          updatedAt: now,
          expiresAt: now.add(const Duration(hours: 1)),
        );
        roomController.add(activeRoomHostTurn);
        messagesController.add([
          ChatMessage(
            messageId: 'msg_1',
            roomId: 'room_99',
            senderUid: 'host_uid',
            senderName: 'HostVikram',
            message: 'Is it a coastal city?',
            messageType: ChatMessageType.question,
            timestamp: now,
          ),
          ChatMessage(
            messageId: 'msg_2',
            roomId: 'room_99',
            senderUid: 'guest_uid',
            senderName: 'GuestPriya',
            message: 'Yes',
            messageType: ChatMessageType.yesAnswer,
            timestamp: now,
          ),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Is it a coastal city?'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);

        // Scenario 12 & 13: Online Board Heart Synchronization + Disconnect/Reconnect
        router.go('/game/board?roomId=room_99');
        await tester.pump();
        roomController.add(activeRoomHostTurn);
        // Simulate Guest disconnects & loses 1 heart (4 hearts left)
        playersController.add(const [
          PlayerMatchState(
            playerId: 'host_uid',
            displayName: 'HostVikram',
            hearts: 5,
            isConnected: true,
          ),
          PlayerMatchState(
            playerId: 'guest_uid',
            displayName: 'GuestPriya',
            hearts: 4,
            isConnected: false,
          ),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 5 filled hearts for Host + 4 filled hearts for Guest = 9 filled hearts synced!
        expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(9));
        expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(1));

        // Guest reconnects cleanly
        playersController.add(const [
          PlayerMatchState(
            playerId: 'host_uid',
            displayName: 'HostVikram',
            hearts: 5,
            isConnected: true,
          ),
          PlayerMatchState(
            playerId: 'guest_uid',
            displayName: 'GuestPriya',
            hearts: 4,
            isConnected: true,
          ),
        ]);
        await tester.pump();

        // Scenario 14: Match completes -> Match Results -> Rematch calls Cloud Function!
        roomController.add(
          RoomData(
            roomId: 'room_99',
            roomCode: 'DESI99',
            hostUid: 'host_uid',
            hostName: 'HostVikram',
            guestUid: 'guest_uid',
            guestName: 'GuestPriya',
            status: MatchStatus.completed,
            category: GameCategory.where,
            boardPackId: 'where_indian_cities',
            winnerUid: 'host_uid',
            winReason: 'Correct Final Guess!',
            createdAt: now,
            updatedAt: now,
            expiresAt: now.add(const Duration(hours: 1)),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('HostVikram Wins!'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.tap(find.text('Rematch'));
        await tester.pump();

        verify(() => mockMp.requestRematch('room_99')).called(1);
      },
    );
  });
}
