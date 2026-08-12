import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/splash_screen.dart';
import 'presentation/screens/call/live_call_screen.dart';
import 'presentation/screens/call/pre_join_screen.dart';
import 'presentation/screens/chat/chat_list_screen.dart';
import 'presentation/screens/chat/conversation_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/members/members_screen.dart';
import 'presentation/screens/requests/requests_screen.dart';
import 'presentation/screens/sessions/sessions_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final user = authState.valueOrNull;
      final isSplash = loc == '/splash';
      final isAuthRoute = loc == '/login';

      if (isSplash) return null;
      if (user != null && isAuthRoute) return '/home';
      if (user == null && !isAuthRoute && !isSplash) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/members', builder: (_, __) => const MembersScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatListScreen()),
      GoRoute(
        path: '/chat/:chatId/:receiverId',
        builder: (_, state) => ConversationScreen(
          chatId: state.pathParameters['chatId']!,
          receiverId: state.pathParameters['receiverId']!,
        ),
      ),
      GoRoute(path: '/requests', builder: (_, __) => const RequestsScreen()),
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
