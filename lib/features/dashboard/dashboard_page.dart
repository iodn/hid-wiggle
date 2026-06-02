import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/hid_gadget_profile.dart';
import '../../core/models/jiggle_config.dart';
import '../../core/models/usb_identity_settings.dart';
import '../../core/platform/gadget_providers.dart';
import '../../core/routing/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/app_settings_controller.dart';
import '../../state/jiggler_controller.dart';
import '../modes/pattern_catalog.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(jigglerControllerProvider);
    ref.listen(gadgetStatusStreamProvider, (prev, next) {
      final status = next.asData?.value;
      if (status == null) return;
      if (status.state == 'ERROR' && (status.message?.trim().isNotEmpty ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status.message!.trim()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final config = settings?.jiggle ?? JiggleConfig.defaults();
    final usb = settings?.usbIdentity ?? UsbIdentitySettings.defaults();
    final pattern = PatternCatalog.byId(config.patternId);

    final statusAsync = ref.watch(gadgetStatusProvider);
    final status = statusAsync.asData?.value;
    final stateStr = status?.state ?? 'IDLE';
    final isActive = stateStr == 'ACTIVE';
    final isActivating = stateStr == 'ACTIVATING';
    final isRunning = isActive || isActivating;

    final rootAvailable = status?.rootAvailable ?? false;
    final hidSupported = status?.supportAvailable ?? false;
    final canActivate = rootAvailable && hidSupported;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.mouse, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('HIDWiggle'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Testing Lab',
            onPressed: () => context.push(AppRoutes.testMode),
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          // Root warning banner
          if (!rootAvailable) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.errorContainer,
                    theme.colorScheme.errorContainer.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security,
                    color: theme.colorScheme.error,
                    size: 40,
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Root Access Required',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'HIDWiggle needs root privileges to create USB gadgets through Linux configfs. '
                          'This allows your Android device to emulate a USB mouse/keyboard.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'The app cannot function without root access',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
          ],

          // Main control card
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.primaryContainer.withOpacity(0.7),
                      ]
                    : [
                        theme.colorScheme.surfaceContainerHighest,
                        theme.colorScheme.surfaceContainerHigh,
                      ],
              ),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                color: isActive
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.play_arrow
                            : isActivating
                                ? Icons.hourglass_empty
                                : Icons.stop,
                        color: isActive
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isActive
                                ? 'Jiggler Active'
                                : isActivating
                                    ? 'Starting Up…'
                                    : 'Ready to Start',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive
                                ? 'Mouse movements active • Keeping your session alive'
                                : isActivating
                                    ? 'Initializing USB gadget and binding controller…'
                                    : 'Configure your movement pattern and tap Start',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isActive
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceLg),
                FilledButton.icon(
                  onPressed: (isActivating || !canActivate)
                      ? null
                      : () async {
                          if (isActive) {
                            await ref.read(gadgetChannelProvider).deactivate();
                            return;
                          }
                          await _activate(context, ref, usb);
                        },
                  icon: Icon(
                    isActive ? Icons.stop_circle : Icons.play_circle,
                    size: 24,
                  ),
                  label: Text(
                    isActive ? 'Stop Jiggler' : 'Start Jiggler',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    foregroundColor: isActive
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                ),
                if (!canActivate && !isActivating) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        !rootAvailable
                            ? 'Root access required'
                            : 'USB gadget not supported',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTokens.spaceMd),
                const Divider(),
                const SizedBox(height: AppTokens.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go(AppRoutes.modes),
                        icon: const Icon(Icons.tune),
                        label: const Text('Pattern'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showQuickIntervalSheet(context, ref),
                        icon: const Icon(Icons.speed),
                        label: const Text('Speed'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),

          // Current pattern card
          SectionHeader(
            title: 'Active Movement Pattern',
            subtitle: 'Current jiggler behavior and timing.',
            trailing: TextButton.icon(
              onPressed: () => context.push('${AppRoutes.modes}/${pattern.id}'),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Customize'),
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      child: Icon(
                        Icons.gesture,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pattern.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pattern.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Container(
                  padding: const EdgeInsets.all(AppTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  child: Text(
                    pattern.preview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildParameterChip(
                      theme,
                      Icons.speed,
                      'Speed',
                      Formatters.intervalFromMs(config.intervalMs),
                    ),
                    _buildParameterChip(
                      theme,
                      Icons.open_with,
                      'Distance',
                      Formatters.px(config.amplitudePx),
                    ),
                    _buildParameterChip(
                      theme,
                      Icons.psychology,
                      'Human-like',
                      Formatters.percent(config.humanLike),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),

          // System status card
          const SectionHeader(
            title: 'System Requirements',
            subtitle: 'Hardware and software capabilities.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      icon: rootAvailable ? Icons.check_circle : Icons.cancel,
                      label: rootAvailable ? 'Root Access' : 'No Root Access',
                      emphasized: true,
                      color: rootAvailable
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                    ),
                    StatusChip(
                      icon: hidSupported ? Icons.check_circle : Icons.cancel,
                      label: hidSupported ? 'USB Gadget Ready' : 'USB Gadget Missing',
                      emphasized: true,
                      color: hidSupported
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                    ),
                    StatusChip(
                      icon: Icons.usb,
                      label: 'Controllers: ${status?.udcList.length ?? 0}',
                      color: theme.colorScheme.secondaryContainer,
                    ),
                    StatusChip(
                      icon: isRunning ? Icons.power : Icons.power_off,
                      label: isRunning ? 'Running' : 'Stopped',
                      color: isRunning
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
                if ((status?.message?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: AppTokens.spaceMd),
                  const Divider(),
                  const SizedBox(height: AppTokens.spaceMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status!.message!.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),

          // Device identity info
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Device Identity: ${usb.manufacturer} ${usb.product} • ${usb.vidPidLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildParameterChip(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(
          color: theme.colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activate(BuildContext context, WidgetRef ref, UsbIdentitySettings usb) async {
    final profile = HidGadgetProfile.mouseBaseline(
      vendorId: usb.vendorId,
      productId: usb.productId,
      manufacturer: usb.manufacturer,
      product: usb.product,
      serialNumber: usb.serialNumber,
      maxPowerMa: usb.maxPowerMa,
    );

    try {
      await ref.read(gadgetChannelProvider).activateProfile(profile.toMap());
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showQuickIntervalSheet(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(appSettingsControllerProvider).asData?.value;
    final cfg = settings?.jiggle;
    if (cfg == null) return;

    var ms = cfg.intervalMs.clamp(80, 30000);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Movement Speed', style: Theme.of(ctx).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'How frequently the jiggler sends mouse movements. Lower = faster.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTokens.spaceLg),
                  Row(
                    children: [
                      const Icon(Icons.speed),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.intervalFromMs(ms),
                        style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 80,
                    max: 30000,
                    divisions: null,
                    value: ms.toDouble(),
                    onChanged: (v) => setState(() => ms = v.round()),
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  FilledButton.icon(
                    onPressed: () async {
                      final next = cfg.copyWith(intervalMs: ms);
                      await ref.read(appSettingsControllerProvider.notifier).updateJiggle(next);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Apply Changes'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
