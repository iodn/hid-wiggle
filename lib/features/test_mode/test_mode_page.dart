import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/hid_gadget_profile.dart';
import '../../core/models/usb_identity_settings.dart';
import '../../core/platform/gadget_channel.dart';
import '../../core/platform/gadget_providers.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/app_settings_controller.dart';
import '../../state/test_mode_controller.dart';

class TestModePage extends ConsumerWidget {
  const TestModePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(gadgetStatusProvider);
    final status = statusAsync.asData?.value;
    final logs = ref.watch(testModeControllerProvider);
    
    final rootAvailable = status?.rootAvailable ?? false;
    final hidSupported = status?.supportAvailable ?? false;
    final stateStr = status?.state ?? 'IDLE';
    final isActive = stateStr == 'ACTIVE';
    final isActivating = stateStr == 'ACTIVATING';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Mode'),
        actions: [
          IconButton(
            tooltip: 'Clear log',
            onPressed: () => ref.read(testModeControllerProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          const SectionHeader(
            title: 'System Status',
            subtitle: 'Real capabilities from Android backend.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip(
                  icon: rootAvailable ? Icons.check_circle : Icons.cancel,
                  label: rootAvailable ? 'Root: Available' : 'Root: Unavailable',
                  emphasized: true,
                  color: rootAvailable
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                ),
                StatusChip(
                  icon: hidSupported ? Icons.check_circle : Icons.cancel,
                  label: hidSupported ? 'HID: Supported' : 'HID: Not Supported',
                  emphasized: true,
                  color: hidSupported
                      ? Colors.green.shade600
                      : Colors.red.shade600,
                ),
                StatusChip(
                  icon: isActive ? Icons.play_arrow : Icons.stop,
                  label: 'State: $stateStr',
                  emphasized: true,
                  color: isActive
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          
          // Mouse control section
          const SectionHeader(
            title: 'Mouse Control',
            subtitle: 'Enable mouse gadget without movement for testing.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!rootAvailable || !hidSupported) ...[
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: theme.colorScheme.error),
                      const SizedBox(width: AppTokens.spaceSm),
                      Expanded(
                        child: Text(
                          !rootAvailable
                              ? 'Root access required to enable mouse gadget'
                              : 'USB gadget support not available on this device',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                ],
                FilledButton.icon(
                  onPressed: (isActivating || !rootAvailable || !hidSupported)
                      ? null
                      : () => _toggleMouse(context, ref, isActive),
                  icon: Icon(isActive ? Icons.stop_circle : Icons.play_circle),
                  label: Text(isActive ? 'Stop Mouse' : 'Enable Mouse'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive ? theme.colorScheme.error : null,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(
                    'Mouse gadget is active. Use buttons below to test HID events.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          
          const SectionHeader(
            title: 'HID Test Buttons',
            subtitle: 'Send real HID events when mouse is enabled.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _buildTestGrid(context, ref, isActive),
          const SizedBox(height: AppTokens.spaceLg),
          
          SectionHeader(
            title: 'Event Log',
            subtitle: logs.isEmpty ? 'No events yet.' : 'Most recent first.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (logs.isEmpty)
            AppCard(
              child: Text(
                'Enable mouse and tap buttons above to test HID events.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final e in logs) ...[
              AppCard(
                child: Row(
                  children: [
                    Icon(
                      _getLogIcon(e.message),
                      size: 18,
                      color: _getLogColor(e.message, theme),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.message, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.dateTimeShort(e.timestamp),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
            ],
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Future<void> _toggleMouse(BuildContext context, WidgetRef ref, bool isActive) async {
    final channel = ref.read(gadgetChannelProvider);
    final logger = ref.read(testModeControllerProvider.notifier);

    if (isActive) {
      try {
        await channel.deactivate();
        logger.log('✓ Mouse gadget stopped');
      } catch (e) {
        logger.log('✗ Failed to stop: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop: $e')),
          );
        }
      }
    } else {
      try {
        final settings = ref.read(appSettingsControllerProvider).asData?.value;
        final usb = settings?.usbIdentity ?? UsbIdentitySettings.defaults();
        
        final profile = HidGadgetProfile.mouseBaseline(
          id: 'test_mouse',
          name: 'Test Mouse',
          vendorId: usb.vendorId,
          productId: usb.productId,
          manufacturer: usb.manufacturer,
          product: usb.product,
          serialNumber: usb.serialNumber,
          maxPowerMa: usb.maxPowerMa,
        );

        await channel.activateProfile(profile.toMap());
        logger.log('✓ Mouse gadget enabled (no auto-movement)');
      } catch (e) {
        logger.log('✗ Failed to enable: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to enable: $e')),
          );
        }
      }
    }
  }

  Widget _buildTestGrid(BuildContext context, WidgetRef ref, bool isActive) {
    final channel = ref.read(gadgetChannelProvider);
    final logger = ref.read(testModeControllerProvider.notifier);

    final actions = <_TestAction>[
      _TestAction(
        'Move Right',
        Icons.arrow_forward,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 10, dy: 0);
            logger.log('→ Move right (+10, 0)');
          } catch (e) {
            logger.log('✗ Move failed: $e');
          }
        },
      ),
      _TestAction(
        'Move Left',
        Icons.arrow_back,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: -10, dy: 0);
            logger.log('← Move left (-10, 0)');
          } catch (e) {
            logger.log('✗ Move failed: $e');
          }
        },
      ),
      _TestAction(
        'Move Up',
        Icons.arrow_upward,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: -10);
            logger.log('↑ Move up (0, -10)');
          } catch (e) {
            logger.log('✗ Move failed: $e');
          }
        },
      ),
      _TestAction(
        'Move Down',
        Icons.arrow_downward,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: 10);
            logger.log('↓ Move down (0, +10)');
          } catch (e) {
            logger.log('✗ Move failed: $e');
          }
        },
      ),
      _TestAction(
        'Left Click',
        Icons.mouse,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: 0, buttons: 1);
            await Future.delayed(const Duration(milliseconds: 50));
            await channel.testMouseMove(dx: 0, dy: 0, buttons: 0);
            logger.log('🖱 Left click');
          } catch (e) {
            logger.log('✗ Click failed: $e');
          }
        },
      ),
      _TestAction(
        'Right Click',
        Icons.mouse_outlined,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: 0, buttons: 2);
            await Future.delayed(const Duration(milliseconds: 50));
            await channel.testMouseMove(dx: 0, dy: 0, buttons: 0);
            logger.log('🖱 Right click');
          } catch (e) {
            logger.log('✗ Click failed: $e');
          }
        },
      ),
      _TestAction(
        'Scroll Up',
        Icons.arrow_circle_up,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: 0, wheel: 1);
            logger.log('⤴ Scroll up');
          } catch (e) {
            logger.log('✗ Scroll failed: $e');
          }
        },
      ),
      _TestAction(
        'Scroll Down',
        Icons.arrow_circle_down,
        () async {
          if (!isActive) {
            logger.log('✗ Mouse not enabled');
            return;
          }
          try {
            await channel.testMouseMove(dx: 0, dy: 0, wheel: -1);
            logger.log('⤵ Scroll down');
          } catch (e) {
            logger.log('✗ Scroll failed: $e');
          }
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppTokens.spaceMd,
        crossAxisSpacing: AppTokens.spaceMd,
        childAspectRatio: 2.4,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final action = actions[i];
        return FilledButton.tonalIcon(
          onPressed: isActive ? action.onTap : null,
          icon: Icon(action.icon),
          label: Text(action.label),
        );
      },
    );
  }

  IconData _getLogIcon(String message) {
    if (message.startsWith('✓')) return Icons.check_circle;
    if (message.startsWith('✗')) return Icons.error;
    if (message.contains('Move') || message.contains('→') || message.contains('←') || 
        message.contains('↑') || message.contains('↓')) return Icons.open_with;
    if (message.contains('click') || message.contains('🖱')) return Icons.mouse;
    if (message.contains('Scroll') || message.contains('⤴') || message.contains('⤵')) return Icons.swap_vert;
    return Icons.info;
  }

  Color? _getLogColor(String message, ThemeData theme) {
    if (message.startsWith('✓')) return theme.colorScheme.primary;
    if (message.startsWith('✗')) return theme.colorScheme.error;
    return null;
  }
}

class _TestAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _TestAction(this.label, this.icon, this.onTap);
}
