import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/onboarding_screen.dart';
import 'presentation/screens/auth/profile_setup_screen.dart';
import 'presentation/screens/call/live_call_screen.dart';
import 'presentation/screens/call/pre_join_screen.dart';
import 'presentation/screens/chat/chat_list_screen.dart';
import 'presentation/screens/chat/conversation_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/schedule/schedule_screen.dart';
import 'presentation/screens/sessions/sessions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isAuthRoute = state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/setup';

      if (user != null && isAuthRoute) return '/home';
      if (user == null && !isAuthRoute) return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) => ConversationScreen(
          chatId: state.pathParameters['chatId']!,
        ),
      ),
      GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
      GoRoute(path: '/sessions', builder: (_, __) => const SessionsScreen()),
      GoRoute(
        path: '/call/:callRequestId',
        builder: (_, state) => PreJoinScreen(
          callRequestId: state.pathParameters['callRequestId']!,
        ),
      ),
      GoRoute(
        path: '/call/:callRequestId/live',
        builder: (_, state) => LiveCallScreen(
          callRequestId: state.pathParameters['callRequestId']!,
        ),
      ),
    ],
  );
});
