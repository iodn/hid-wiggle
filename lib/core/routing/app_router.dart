import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/diagnostics/diagnostics_page.dart';
import '../../features/diagnostics/logs_page.dart';
import '../../features/modes/modes_list_page.dart';
import '../../features/modes/pattern_detail_page.dart';
import '../../features/scheduler/schedule_window_editor_page.dart';
import '../../features/scheduler/scheduler_page.dart';
import '../../features/settings/about_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/settings/usb_identity_page.dart';
import '../../features/test_mode/test_mode_page.dart';
import '../widgets/app_shell.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.modes,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ModesListPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? 'micro';
                  return PatternDetailPage(patternId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.scheduler,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SchedulerPage()),
            routes: [
              GoRoute(
                path: 'window/new',
                builder: (context, state) => const ScheduleWindowEditorPage(),
              ),
              GoRoute(
                path: 'window/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id'];
                  return ScheduleWindowEditorPage(windowId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
            routes: [
              GoRoute(
                path: 'usb-identity',
                builder: (context, state) => const UsbIdentityPage(),
              ),
              GoRoute(
                path: 'diagnostics',
                builder: (context, state) => const DiagnosticsPage(),
              ),
              GoRoute(
                path: 'logs',
                builder: (context, state) => const LogsPage(),
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutPage(),
              ),
              GoRoute(
                path: 'licenses',
                builder: (context, state) => const LicensePage(
                  applicationName: 'HIDWiggle',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.testMode,
        builder: (context, state) => const TestModePage(),
      ),
    ],
    errorBuilder: (context, state) => _NotFoundPage(uri: state.uri.toString()),
  );
});

class _NotFoundPage extends StatelessWidget {
  final String uri;

  const _NotFoundPage({required this.uri});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text('No route for $uri'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
