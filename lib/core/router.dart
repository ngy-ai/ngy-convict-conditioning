import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/big_six.dart';
import '../data/seed/big_six_seed.dart';
import '../features/backup/backup_page.dart';
import '../features/history/history_page.dart';
import '../features/history/session_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/moves/move_detail_page.dart';
import '../features/moves/move_guide_page.dart';
import '../features/moves/moves_page.dart';
import '../features/plan/plan_editor_page.dart';
import '../features/plan/plan_page.dart';
import '../features/shell/app_shell.dart';
import '../features/stats/stats_page.dart';
import '../features/train/train_page.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/plan',
              builder: (context, state) => const PlanPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/moves',
              builder: (context, state) => const MovesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/stats',
              builder: (context, state) => const StatsPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/train',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          TrainPage(intent: state.extra is TrainIntent ? state.extra as TrainIntent : null),
    ),
    GoRoute(
      path: '/moves/:exercise',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => MoveDetailPage(
        exercise: BigSix.fromName(state.pathParameters['exercise'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/moves/:exercise/guide/:level',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final exercise = BigSix.fromName(state.pathParameters['exercise'] ?? '');
        final level = int.tryParse(state.pathParameters['level'] ?? '') ?? 1;
        return MoveGuidePage(
          move: MoveCatalog.of(exercise, level.clamp(1, 10)),
        );
      },
    ),
    GoRoute(
      path: '/plan/editor',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PlanEditorPage(),
    ),
    GoRoute(
      path: '/sessions/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => SessionDetailPage(
        sessionId: int.tryParse(state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/backup',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const BackupPage(),
    ),
  ],
);
