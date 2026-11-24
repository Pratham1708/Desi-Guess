import 'package:desi_guess/app/app.dart';
import 'package:desi_guess/app/router.dart';
import 'package:desi_guess/app/theme.dart';
import 'package:desi_guess/core/services/audio_service.dart';
import 'package:desi_guess/core/services/storage_service.dart';
import 'package:desi_guess/core/widgets/hearts_indicator.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:desi_guess/shared/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  setUpAll(() {
    AppTheme.useGoogleFonts = false;
  });

  testWidgets('Home Dashboard renders hero, actions, and categories', (
    WidgetTester tester,
  ) async {
    final storage = StorageService();
    await storage.setOnboardingDone(true);
    await storage.saveLocalProfile(
      UserProfile(
        uid: 'test_user',
        username: 'TestPlayer',
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          appRouterProvider.overrideWithValue(
            createAppRouter(initialLocation: '/home'),
          ),
        ],
        child: const DesiGuessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready to test your guessing skills?'), findsOneWidget);
    expect(find.text('PLAY ONLINE'), findsNothing);
    expect(find.text('PLAY TOGETHER'), findsOneWidget);
    expect(find.text('Ranks'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(find.text('WHO'), findsOneWidget);
    expect(find.text('WHAT'), findsOneWidget);
    expect(find.text('WHERE'), findsOneWidget);
  });

  testWidgets('Settings switches app language between English and Hinglish', (
    WidgetTester tester,
  ) async {
    final storage = StorageService();
    await storage.setOnboardingDone(true);
    await storage.saveSettings(const AppSettings(languageCode: 'hi'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          appRouterProvider.overrideWithValue(
            createAppRouter(initialLocation: '/home'),
          ),
        ],
        child: const DesiGuessApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Guessing skills test karne ke liye ready ho?'),
      findsOneWidget,
    );
    expect(find.text('ONLINE KHELO'), findsNothing);
    expect(find.text('SAATH KHELO'), findsOneWidget);
  });

  testWidgets(
    'Local-only mode hides online rooms, chat, and invites and redirects online routes',
    (WidgetTester tester) async {
      final storage = StorageService();
      await storage.setOnboardingDone(true);
      await storage.saveLocalProfile(
        UserProfile(
          uid: 'local_tester',
          username: 'Ananya',
          createdAt: DateTime.now(),
        ),
      );

      final router = createAppRouter(initialLocation: '/play');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            appRouterProvider.overrideWithValue(router),
          ],
          child: const DesiGuessApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Mode Selection shows only Local Pass & Play
      expect(find.text('Pass & Play Setup'), findsOneWidget);
      expect(find.text('Face-to-Face / Local'), findsOneWidget);
      expect(find.text('Online Multiplayer'), findsNothing);
      expect(find.text('Create Room'), findsNothing);
      expect(find.text('Join Room'), findsNothing);
      expect(find.text('Invite Friends & Send Room Codes'), findsNothing);

      // Attempting to navigate to /online/create safely redirects back to /play
      router.go('/online/create');
      await tester.pumpAndSettle();
      expect(find.text('Pass & Play Setup'), findsOneWidget);

      // Attempting to navigate to /friends safely redirects to /home
      router.go('/friends');
      await tester.pumpAndSettle();
      expect(find.text('Ready to test your guessing skills?'), findsOneWidget);
    },
  );

  testWidgets('HeartsIndicator renders exact filled and empty hearts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 80, child: HeartsIndicator(hearts: 3)),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'End-to-end Local Multiplayer flow: Secret Select -> Handoff -> Board -> Victory',
    (WidgetTester tester) async {
      final storage = StorageService();
      await storage.setOnboardingDone(true);
      await storage.saveLocalProfile(
        UserProfile(
          uid: 'p1_user',
          username: 'Aarav',
          createdAt: DateTime.now(),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          audioServiceProvider.overrideWithValue(
            AudioService(enabled: false, hapticsEnabled: false),
          ),
          appRouterProvider.overrideWithValue(
            createAppRouter(initialLocation: '/game/secret-select'),
          ),
        ],
      );

      final pack = container
          .read(cardRepositoryProvider)
          .findPackById('where_indian_cities')!;
      await container
          .read(localMatchProvider.notifier)
          .startLocalMatch(
            pack: pack,
            player1Name: 'Aarav',
            player2Name: 'Meera',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DesiGuessApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Player 1 selects Mumbai
      await tester.tap(find.text('Mumbai').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock Secret Card'));
      await tester.pumpAndSettle();

      // Privacy handoff to Meera
      expect(find.text('Meera'), findsWidgets);
      await tester.tap(find.text('I Am Ready (Meera)'));
      await tester.pumpAndSettle();

      // Player 2 selects Delhi
      await tester.tap(find.text('Delhi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock Secret Card'));
      await tester.pumpAndSettle();

      // Privacy handoff back to Aarav
      await tester.tap(find.text('I Am Ready (Aarav)'));
      await tester.pumpAndSettle();

      // Main Game Board rendered with 11/11 remaining opponent candidates (12 minus MY CARD)
      expect(find.text('11 / 11 Remaining'), findsOneWidget);
      expect(find.text('End Turn'), findsNothing);

      // Wrong Final Guess (Bengaluru) -> heart lost + automatic turn switch
      await tester.tap(find.text('Final Guess'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bengaluru').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock Final Guess: Bengaluru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        find.textContaining('Incorrect Guess! 1 Heart Lost'),
        findsOneWidget,
      );
      expect(find.textContaining("It's Meera's Turn"), findsOneWidget);
      await tester.tap(find.text('I Am Ready (Meera)'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6)); // snackbar dismissed
      await tester.pumpAndSettle();
      expect(find.text('End Turn'), findsNothing);

      // Meera now plays normally: wrong guess hands the turn back to Aarav
      await tester.tap(find.text('Final Guess'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bengaluru').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock Final Guess: Bengaluru'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining("It's Aarav's Turn"), findsOneWidget);
      await tester.tap(find.text('I Am Ready (Aarav)'));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      // Eliminate Bengaluru on board -> 10/11 remaining
      await tester.tap(find.text('Bengaluru').first);
      await tester.pumpAndSettle();
      expect(find.text('10 / 11 Remaining'), findsOneWidget);

      // Make correct Final Guess (Delhi) -> Immediate Victory!
      await tester.tap(find.text('Final Guess'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delhi').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock Final Guess: Delhi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Aarav Wins!'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rematch'), findsOneWidget);
    },
  );

  testWidgets(
    'CategorySelectionScreen renders with zero RenderFlex overflow on narrow 360px phones',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = StorageService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            appRouterProvider.overrideWithValue(
              createAppRouter(initialLocation: '/categories?mode=local'),
            ),
          ],
          child: const DesiGuessApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WHO'), findsOneWidget);
      expect(find.text('WHAT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('WHERE'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('WHERE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'HomeScreen renders category tiles with zero RenderFlex overflow on narrow 360px phones',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = StorageService();
      await storage.setOnboardingDone(true);
      await storage.saveLocalProfile(
        UserProfile(
          uid: 'narrow_home_user',
          username: 'NarrowTest',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storage),
            appRouterProvider.overrideWithValue(
              createAppRouter(initialLocation: '/home'),
            ),
          ],
          child: const DesiGuessApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(find.text('WHO'), findsOneWidget);
      expect(find.text('CUSTOM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
