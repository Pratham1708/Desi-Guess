import 'package:desi_guess/core/errors/app_failure.dart';
import 'package:desi_guess/core/services/audio_service.dart';
import 'package:desi_guess/core/services/storage_service.dart';
import 'package:desi_guess/core/utils/room_code_generator.dart';
import 'package:desi_guess/features/cards/data/card_repository.dart';
import 'package:desi_guess/features/game/presentation/local_match_controller.dart';
import 'package:desi_guess/features/multiplayer/data/multiplayer_repository.dart';
import 'package:desi_guess/features/profile/data/profile_repository.dart';
import 'package:desi_guess/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Room Codes, Expiration, Persistence & Profiles', () {
    test('generates valid 6-character uppercase room codes', () {
      for (var i = 0; i < 30; i++) {
        final code = AppUtils.generateRoomCode();
        expect(code.length, 6);
        expect(AppUtils.isValidRoomCode(code), isTrue);
      }
      expect(AppUtils.isValidRoomCode('ABC'), isFalse);
      expect(AppUtils.isValidRoomCode('AB@123'), isFalse);
    });

    test('detects expired rooms accurately', () {
      final now = DateTime.now();
      final expiredRoom = RoomData(
        roomId: 'r1',
        roomCode: 'A7K9P2',
        hostUid: 'u1',
        hostName: 'Host',
        status: MatchStatus.waiting,
        category: GameCategory.who,
        boardPackId: 'who_bollywood_actors',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(expiredRoom.isExpired, isTrue);
    });

    test(
      'online multiplayer rejects calls cleanly when Firebase is unconfigured',
      () async {
        final mp = MultiplayerRepository();
        expect(
          () => mp.createRoom(
            category: GameCategory.who,
            boardPackId: 'who_bollywood_actors',
          ),
          throwsA(isA<NetworkFailure>()),
        );
        expect(() => mp.joinRoom('A7K9P2'), throwsA(isA<NetworkFailure>()));
      },
    );

    test(
      'local match persists in storage and survives controller recreation',
      () async {
        final storage = StorageService();
        final audio = AudioService(enabled: false, hapticsEnabled: false);
        final pack = CardRepository().findPackById('where_indian_cities')!;

        final ctrl1 = LocalMatchController(
          storageService: storage,
          audioService: audio,
          onMatchCompleted: (_) async {},
        );
        await ctrl1.startLocalMatch(
          pack: pack,
          player1Name: 'Rohan',
          player2Name: 'Ananya',
        );
        await ctrl1.selectSecretCard(playerId: 'player_1', cardId: 'cty_01');
        await ctrl1.acknowledgeHandoff();
        await ctrl1.selectSecretCard(playerId: 'player_2', cardId: 'cty_02');
        await ctrl1.acknowledgeHandoff();
        await ctrl1.toggleEliminateCard('cty_03');

        // Simulate app restart with fresh controller reading same storage
        final ctrl2 = LocalMatchController(
          storageService: storage,
          audioService: audio,
          onMatchCompleted: (_) async {},
        );
        expect(ctrl2.state, isNotNull);
        expect(ctrl2.state!.status, MatchStatus.active);
        expect(ctrl2.state!.player1.eliminatedCardIds, contains('cty_03'));
      },
    );

    test(
      'profile repository updates rating, streaks, and unlocks all 5 achievements',
      () async {
        final storage = StorageService();
        final repo = ProfileRepository(storageService: storage);
        var profile = UserProfile(
          uid: 'u_test',
          username: 'DesiChamp',
          createdAt: DateTime.now(),
        );

        // 1st win with 5 hearts -> unlocks first_victory & perfect_guess
        profile = await repo.recordLocalMatchOutcome(
          profile: profile,
          didWin: true,
          heartsRemaining: 5,
        );
        expect(profile.unlockedAchievements, contains('first_victory'));
        expect(profile.unlockedAchievements, contains('perfect_guess'));

        // Comeback win with 1 heart -> unlocks comeback_king
        profile = await repo.recordLocalMatchOutcome(
          profile: profile,
          didWin: true,
          heartsRemaining: 1,
        );
        expect(profile.unlockedAchievements, contains('comeback_king'));

        // 3 more wins -> 5-win streak -> unlocks five_streak
        for (var i = 0; i < 3; i++) {
          profile = await repo.recordLocalMatchOutcome(
            profile: profile,
            didWin: true,
            heartsRemaining: 4,
          );
        }
        expect(profile.unlockedAchievements, contains('five_streak'));

        // 5 more wins -> 10 wins & rating > 1200 -> unlocks desi_champion
        for (var i = 0; i < 5; i++) {
          profile = await repo.recordLocalMatchOutcome(
            profile: profile,
            didWin: true,
            heartsRemaining: 4,
          );
        }
        expect(profile.unlockedAchievements, contains('desi_champion'));
        expect(profile.wins, 10);
        expect(profile.rating, 1250);
      },
    );
  });
}
