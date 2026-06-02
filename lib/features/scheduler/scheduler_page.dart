import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/schedule_settings.dart';
import '../../core/models/time_window.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../state/app_settings_controller.dart';

class SchedulerPage extends ConsumerWidget {
  const SchedulerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final scheduler = settings?.scheduler ?? ScheduleSettings.defaults();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduler'),
        actions: [
          IconButton(
            tooltip: 'Add window',
            onPressed: () => context.push('/scheduler/window/new'),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scheduler/window/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add window'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          const SectionHeader(
            title: 'Time windows',
            subtitle: 'When active, the wiggle loop is paused outside these windows.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (scheduler.windows.isEmpty)
            AppCard(
              child: Text(
                'No windows. Add one to create an automation schedule.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final w in scheduler.windows) ...[
              _windowCard(context, theme, w),
              const SizedBox(height: AppTokens.spaceMd),
            ],
          const SizedBox(height: AppTokens.spaceLg),
          const SectionHeader(
            title: 'Automation rules',
            subtitle: 'Some device-based rules require platform signals and may be stubbed.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pause when screen is off'),
                  subtitle: const Text('Avoid background activity when the display is off.'),
                  value: scheduler.pauseWhenScreenOff,
                  onChanged: (v) => _update(
                    ref,
                    scheduler.copyWith(pauseWhenScreenOff: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pause when battery is low'),
                  subtitle: const Text('Reduce risk of unexpected drain.'),
                  value: scheduler.pauseWhenBatteryLow,
                  onChanged: (v) => _update(
                    ref,
                    scheduler.copyWith(pauseWhenBatteryLow: v),
                  ),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('Auto stop after'),
                  subtitle: Text(
                    scheduler.autoStopMinutes == 0
                        ? 'Disabled'
                        : '${scheduler.autoStopMinutes} minutes',
                  ),
                ),
                Slider(
                  min: 0,
                  max: 240,
                  divisions: 24,
                  value: scheduler.autoStopMinutes.toDouble().clamp(0, 240),
                  onChanged: (v) => _update(
                    ref,
                    scheduler.copyWith(autoStopMinutes: v.round()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _windowCard(BuildContext context, ThemeData theme, TimeWindow w) {
    final days = _daysLabel(w.days);
    final start = Formatters.timeOfDay(Formatters.timeOfDayFromMinutes(w.startMinutes));
    final end = Formatters.timeOfDay(Formatters.timeOfDayFromMinutes(w.endMinutes));

    return AppCard(
      onTap: () => context.push('/scheduler/window/${w.id}'),
      child: Row(
        children: [
          const Icon(Icons.event_available_outlined),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(days, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('$start – $end', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Future<void> _update(WidgetRef ref, ScheduleSettings next) async {
    await ref.read(appSettingsControllerProvider.notifier).updateScheduler(next);
  }

  String _daysLabel(List<int> days) {
    const map = <int, String>{
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final sorted = [...days]..sort();
    if (sorted.length == 7) return 'Every day';
    if (sorted.length == 5 && sorted.every((d) => d >= 1 && d <= 5)) return 'Weekdays';
    if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) return 'Weekends';
    return sorted.map((d) => map[d] ?? 'Day$d').join(', ');
  }
}
