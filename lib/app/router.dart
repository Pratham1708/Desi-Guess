import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../features/authentication/presentation/guest_login_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/onboarding_screen.dart';
import '../features/authentication/presentation/register_screen.dart';
import '../features/authentication/presentation/splash_screen.dart';
import '../features/cards/presentation/board_pack_selection_screen.dart';
import '../features/cards/presentation/category_selection_screen.dart';
import '../features/chat/presentation/online_chat_screen.dart';
import '../features/custom_boards/presentation/custom_board_creator_screen.dart';
import '../features/custom_boards/presentation/custom_card_creator_screen.dart';
import '../features/game/presentation/board_preview_screen.dart';
import '../features/game/presentation/main_game_board_screen.dart';
import '../features/game/presentation/match_results_screen.dart';
import '../features/game/presentation/privacy_handoff_screen.dart';
import '../features/game/presentation/question_history_screen.dart';
import '../features/game/presentation/secret_card_selection_screen.dart';
import '../features/home/presentation/help_rules_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/mode_selection_screen.dart';
import '../features/home/presentation/settings_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/multiplayer/presentation/create_room_screen.dart';
import '../features/multiplayer/presentation/join_room_screen.dart';
import '../features/multiplayer/presentation/online_lobby_screen.dart';
import '../features/profile/presentation/friends_invites_screen.dart';
import '../features/profile/presentation/profile_screen.dart';

CustomTransitionPage<void> _smoothPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeOut).animate(animation),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});

GoRouter createAppRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      if (FeatureFlags.enableOnlineMultiplayer) return null;
      final path = state.uri.path;
      if (path.startsWith('/online')) return '/play';
      if (path.startsWith('/game/chat')) return '/game/history';
      if (path == '/friends' || path == '/leaderboard') return '/home';
      if (!FeatureFlags.enableCloudAccounts &&
          (path == '/login' || path == '/register')) {
        return '/guest-login';
      }
      return null;
    },
    routes: [
      // 1. Splash
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            _smoothPage(state, const SplashScreen()),
      ),
      // 2. Onboarding
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            _smoothPage(state, const OnboardingScreen()),
      ),
      // 3. Login
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _smoothPage(state, const LoginScreen()),
      ),
      // 4. Guest Login
      GoRoute(
        path: '/guest-login',
        pageBuilder: (context, state) =>
            _smoothPage(state, const GuestLoginScreen()),
      ),
      // 5. Registration
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            _smoothPage(state, const RegisterScreen()),
      ),
      // 6. Home Dashboard
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _smoothPage(state, const HomeScreen()),
      ),
      // 7. Game Mode Selection
      GoRoute(
        path: '/play',
        pageBuilder: (context, state) => _smoothPage(
          state,
          ModeSelectionScreen(
            initialFocus: state.uri.queryParameters['focus'],
            preselectedPackId: state.uri.queryParameters['packId'],
          ),
        ),
      ),
      // 8. Category Selection
      GoRoute(
        path: '/categories',
        pageBuilder: (context, state) => _smoothPage(
          state,
          CategorySelectionScreen(
            mode: FeatureFlags.enableOnlineMultiplayer
                ? (state.uri.queryParameters['mode'] ?? 'local')
                : 'local',
            player1Name: state.uri.queryParameters['p1'] ?? 'Player 1',
            player2Name: state.uri.queryParameters['p2'] ?? 'Player 2',
          ),
        ),
      ),
      // 9. Board Pack Selection
      GoRoute(
        path: '/packs/:category',
        pageBuilder: (context, state) => _smoothPage(
          state,
          BoardPackSelectionScreen(
            categoryName: state.pathParameters['category'] ?? 'who',
            mode: FeatureFlags.enableOnlineMultiplayer
                ? (state.uri.queryParameters['mode'] ?? 'local')
                : 'local',
            player1Name: state.uri.queryParameters['p1'] ?? 'Player 1',
            player2Name: state.uri.queryParameters['p2'] ?? 'Player 2',
          ),
        ),
      ),
      // 10. Create Online Room
      GoRoute(
        path: '/online/create',
        pageBuilder: (context, state) => _smoothPage(
          state,
          CreateRoomScreen(
            initialPackId: state.uri.queryParameters['packId'],
            initialCategory: state.uri.queryParameters['category'],
          ),
        ),
      ),
      // 11. Join Online Room
      GoRoute(
        path: '/online/join',
        pageBuilder: (context, state) => _smoothPage(
          state,
          JoinRoomScreen(initialCode: state.uri.queryParameters['code']),
        ),
      ),
      // 12. Online Lobby
      GoRoute(
        path: '/online/lobby/:roomId',
        pageBuilder: (context, state) => _smoothPage(
          state,
          OnlineLobbyScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      // 9b. Randomized 10-Card Board Preview
      GoRoute(
        path: '/game/preview',
        pageBuilder: (context, state) =>
            _smoothPage(state, const BoardPreviewScreen()),
      ),
      // 13. Secret Card Selection
      GoRoute(
        path: '/game/secret-select',
        pageBuilder: (context, state) => _smoothPage(
          state,
          SecretCardSelectionScreen(
            roomId: FeatureFlags.enableOnlineMultiplayer
                ? state.uri.queryParameters['roomId']
                : null,
          ),
        ),
      ),
      // 14. Privacy Handoff
      GoRoute(
        path: '/game/handoff',
        pageBuilder: (context, state) =>
            _smoothPage(state, const PrivacyHandoffScreen()),
      ),
      // 15. Main Game Board
      GoRoute(
        path: '/game/board',
        pageBuilder: (context, state) => _smoothPage(
          state,
          MainGameBoardScreen(
            roomId: FeatureFlags.enableOnlineMultiplayer
                ? state.uri.queryParameters['roomId']
                : null,
          ),
        ),
      ),
      // 16. Online Chat
      GoRoute(
        path: '/game/chat/:roomId',
        pageBuilder: (context, state) => _smoothPage(
          state,
          OnlineChatScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      // 17. Question History
      GoRoute(
        path: '/game/history',
        pageBuilder: (context, state) =>
            _smoothPage(state, const QuestionHistoryScreen()),
      ),
      // 18. Player Profile
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _smoothPage(state, const ProfileScreen()),
      ),
      // 19. Match Results
      GoRoute(
        path: '/game/results',
        pageBuilder: (context, state) =>
            _smoothPage(state, const MatchResultsScreen()),
      ),
      // 20. Leaderboard
      GoRoute(
        path: '/leaderboard',
        pageBuilder: (context, state) =>
            _smoothPage(state, const LeaderboardScreen()),
      ),
      // 21. Friends & Invites
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) =>
            _smoothPage(state, const FriendsInvitesScreen()),
      ),
      // 22. Settings
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _smoothPage(state, const SettingsScreen()),
      ),
      // 23. Custom Board Creator
      GoRoute(
        path: '/custom-boards',
        pageBuilder: (context, state) =>
            _smoothPage(state, const CustomBoardCreatorScreen()),
      ),
      // 24. Custom Card Creator
      GoRoute(
        path: '/custom-boards/:boardId/cards/new',
        pageBuilder: (context, state) => _smoothPage(
          state,
          CustomCardCreatorScreen(boardId: state.pathParameters['boardId']!),
        ),
      ),
      // 25. Help and Rules
      GoRoute(
        path: '/help',
        pageBuilder: (context, state) =>
            _smoothPage(state, const HelpRulesScreen()),
      ),
    ],
  );
}
