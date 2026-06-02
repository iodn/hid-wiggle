import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/schedule_settings.dart';
import '../../core/models/time_window.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../state/app_settings_controller.dart';

class ScheduleWindowEditorPage extends ConsumerStatefulWidget {
  final String? windowId;

  const ScheduleWindowEditorPage({super.key, this.windowId});

  @override
  ConsumerState<ScheduleWindowEditorPage> createState() =>
      _ScheduleWindowEditorPageState();
}

class _ScheduleWindowEditorPageState
    extends ConsumerState<ScheduleWindowEditorPage> {
  late String _id;
  late Set<int> _days;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final scheduler = settings?.scheduler ?? ScheduleSettings.defaults();

    if (!_initialized) {
      final existing = widget.windowId == null
          ? null
          : scheduler.windows
              .where((w) => w.id == widget.windowId)
              .firstOrNull;
      final w = existing ??
          TimeWindow(
            id: widget.windowId ?? 'w_${DateTime.now().millisecondsSinceEpoch}',
            days: const [1, 2, 3, 4, 5],
            startMinutes: 9 * 60,
            endMinutes: 18 * 60,
          );
      _id = w.id;
      _days = {...w.days};
      _start = Formatters.timeOfDayFromMinutes(w.startMinutes);
      _end = Formatters.timeOfDayFromMinutes(w.endMinutes);
      _initialized = true;
    }

    final isEditing = widget.windowId != null;
    final startM = Formatters.minutesFromTimeOfDay(_start);
    final endM = Formatters.minutesFromTimeOfDay(_end);
    final durationMin = (endM - startM).abs();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit window' : 'New window'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: () => _save(context, scheduler),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Days'),
                const SizedBox(height: AppTokens.spaceSm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in _dayOptions)
                      FilterChip(
                        label: Text(d.label),
                        selected: _days.contains(d.value),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _days.add(d.value);
                            } else {
                              _days.remove(d.value);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceMd),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Start'),
                  subtitle: Text(Formatters.timeOfDay(_start)),
                  onTap: () async {
                    final t =
                        await showTimePicker(context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('End'),
                  subtitle: Text(Formatters.timeOfDay(_end)),
                  onTap: () async {
                    final t =
                        await showTimePicker(context: context, initialTime: _end);
                    if (t != null) setState(() => _end = t);
                  },
                ),
                if (durationMin < 5)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Window duration is $durationMin minute(s). Very short windows may not trigger reliably.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          FilledButton.icon(
            onPressed: () => _save(context, scheduler),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save window'),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (isEditing)
            OutlinedButton.icon(
              onPressed: () => _delete(context, scheduler),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete window'),
            ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, ScheduleSettings scheduler) async {
    final days = _days.toList()..sort();
    if (days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day.')),
      );
      return;
    }

    final startM = Formatters.minutesFromTimeOfDay(_start);
    final endM = Formatters.minutesFromTimeOfDay(_end);

    final updated = TimeWindow(
      id: _id,
      days: days,
      startMinutes: startM,
      endMinutes: endM,
    );

    final nextWindows = [
      for (final w in scheduler.windows)
        if (w.id == _id) updated else w,
      if (!scheduler.windows.any((w) => w.id == _id)) updated,
    ];

    final next = scheduler.copyWith(windows: nextWindows);
    await ref.read(appSettingsControllerProvider.notifier).updateScheduler(next);
    if (context.mounted) context.pop();
  }

  Future<void> _delete(BuildContext context, ScheduleSettings scheduler) async {
    final next = scheduler.copyWith(
      windows: scheduler.windows
          .where((w) => w.id != _id)
          .toList(growable: false),
    );
    await ref.read(appSettingsControllerProvider.notifier).updateScheduler(next);
    if (context.mounted) context.pop();
  }
}

class _DayOption {
  final int value;
  final String label;

  const _DayOption(this.value, this.label);
}

const _dayOptions = <_DayOption>[
  _DayOption(1, 'Mon'),
  _DayOption(2, 'Tue'),
  _DayOption(3, 'Wed'),
  _DayOption(4, 'Thu'),
  _DayOption(5, 'Fri'),
  _DayOption(6, 'Sat'),
  _DayOption(7, 'Sun'),
];

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
