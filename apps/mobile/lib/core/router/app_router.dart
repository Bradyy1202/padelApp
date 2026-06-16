import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/auth/login_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/matches/matches_list_screen.dart';
import '../../presentation/matches/match_detail_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../state/auth_controller.dart';
import '../../state/me_controller.dart';

/// Navegación con GoRouter (PRD §9.3) + guard de auth/onboarding.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(meProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/', name: 'home', builder: (c, s) => const HomeScreen()),
      GoRoute(path: '/login', name: 'login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/onboarding', name: 'onboarding', builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: '/profile', name: 'profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/matches', name: 'matches', builder: (c, s) => const MatchesListScreen()),
      GoRoute(
        path: '/matches/:id',
        name: 'match',
        builder: (c, s) => MatchDetailScreen(matchId: s.pathParameters['id']!),
      ),
    ],
    redirect: (context, state) {
      final session = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (session == null) {
        return loc == '/login' ? null : '/login';
      }

      final me = ref.read(meProvider).valueOrNull;
      if (me != null && !me.onboarded) {
        return loc == '/onboarding' ? null : '/onboarding';
      }
      if (loc == '/login') return '/';
      if (me != null && me.onboarded && loc == '/onboarding') return '/';
      return null;
    },
  );
});
