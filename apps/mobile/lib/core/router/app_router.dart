import 'package:go_router/go_router.dart';

import '../../presentation/home/home_screen.dart';

/// Navegación con GoRouter (PRD §9.3). Se amplía con las rutas de cada feature.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
