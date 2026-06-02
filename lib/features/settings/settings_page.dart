import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/usb_identity_settings.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/usb_ids_providers.dart';
import '../../state/app_settings_controller.dart';
import '../../state/dynamic_color_controller.dart';
import 'widgets/donation_sheet.dart';
import 'widgets/section_card.dart';
import 'widgets/support_pill.dart';
import 'about_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _resolvedVendorName;
  String? _resolvedProductName;

  static const String _repoUrl = 'https://github.com/iodn/hid-wiggle';
  static const String _btcAddress = 'bc1qtf79uecssueu4u4u86zct46vcs0vcd2cnmvw6f';
  static const String _ethAddress = '0xCaCc52Cd2D534D869a5C61dD3cAac57455f3c2fD';
  static const String _liberapayUrl = 'https://liberapay.com/KaijinLab/donate';

  @override
  void initState() {
    super.initState();
    _resolveUsbNames();
  }

  Future<void> _resolveUsbNames() async {
    final settings = ref.read(appSettingsControllerProvider).asData?.value;
    if (settings == null) return;

    final usb = settings.usbIdentity;
    final vid = UsbIdentitySettings.tryParseHexOrDec(usb.vendorId);
    final pid = UsbIdentitySettings.tryParseHexOrDec(usb.productId);
    if (vid == null || pid == null) return;

    try {
      final repo = ref.read(usbIdsRepositoryProvider);
      final product = await repo.getProduct(vid, pid);
      if (!mounted) return;
      setState(() {
        _resolvedVendorName = product?.vendorName;
        _resolvedProductName = product?.name;
      });
    } catch (_) {}
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No browser available'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyToClipboard(
    BuildContext context, {
    required String text,
    required String message,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    HapticFeedback.selectionClick();
  }

  Future<void> _changeTheme(ThemeMode mode) async {
    await ref.read(appSettingsControllerProvider.notifier).updateThemeMode(mode);
    HapticFeedback.selectionClick();
  }

  void _openDonationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: DonationSheet(
            repoUrl: _repoUrl,
            btcAddress: _btcAddress,
            ethAddress: _ethAddress,
            liberapayUrl: _liberapayUrl,
            onCopy: (text, message) => _copyToClipboard(ctx, text: text, message: message),
          ),
        );
      },
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Auto Theme';
      case ThemeMode.light:
        return 'Light Theme';
      case ThemeMode.dark:
        return 'Dark Theme';
    }
  }

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.auto_awesome_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }

  String _getThemeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follows your device settings';
      case ThemeMode.light:
        return 'Always bright and clear';
      case ThemeMode.dark:
        return 'Easy on the eyes';
    }
  }

  String _getThemeHint(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Theme automatically switches when you change your device settings between light and dark mode';
      case ThemeMode.light:
        return 'Perfect for daytime use and well-lit environments';
      case ThemeMode.dark:
        return 'Reduces eye strain in low-light conditions and saves battery on OLED screens';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Failed to load settings: $e')),
        data: (s) {
          final themeMode = s.themeMode ?? ThemeMode.system;
          final usb = s.usbIdentity;
          String usbLabel;
          if (_resolvedVendorName != null && _resolvedProductName != null) {
            usbLabel = '$_resolvedVendorName - $_resolvedProductName';
          } else if (_resolvedVendorName != null) {
            usbLabel = _resolvedVendorName!;
          } else {
            usbLabel = usb.vidPidLabel;
          }

          return ListView(
            children: [
              const SizedBox(height: 10),
              _buildSupportSection(context),
              const SizedBox(height: 10),
              _buildAppearanceSection(context, themeMode),
              const SizedBox(height: 10),
              _buildConfigurationSection(context, usbLabel),
              const SizedBox(height: 10),
              _buildDebuggingSection(context),
              const SizedBox(height: 10),
              _buildAboutSection(context),
              const SizedBox(height: 18),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: 'Support Development',
        subtitle: 'Keep this app fast, free, and maintained',
        leading: Icon(Icons.volunteer_activism_rounded, color: cs.primary),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.secondaryContainer.withOpacity(0.7),
                      cs.secondaryContainer.withOpacity(0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'No ads, no tracking, no locked features. Your support funds reliability improvements, better motion patterns, and ongoing maintenance for HIDWiggle.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openDonationSheet(context),
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('Donate'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchUrl(context, _repoUrl),
                      onLongPress: () => _copyToClipboard(
                        context,
                        text: _repoUrl,
                        message: 'Repository link copied',
                      ),
                      icon: const Icon(Icons.star_border_rounded),
                      label: const Text('Star Repo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SupportPill(icon: Icons.lock_outline_rounded, label: 'Local-only'),
                  SupportPill(icon: Icons.shield_outlined, label: 'No tracking'),
                  SupportPill(icon: Icons.speed_rounded, label: 'Lightweight'),
                  SupportPill(icon: Icons.code_rounded, label: 'Open-source'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, ThemeMode mode) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: 'Appearance',
        subtitle: 'Customize your visual experience',
        leading: Icon(Icons.palette_outlined, color: cs.primary),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer.withOpacity(0.6),
                      cs.primaryContainer.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getThemeIcon(mode),
                        size: 20,
                        color: cs.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getThemeName(mode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getThemeDescription(mode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ThemeCard(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Auto',
                      isSelected: mode == ThemeMode.system,
                      onTap: () => _changeTheme(ThemeMode.system),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeCard(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      isSelected: mode == ThemeMode.light,
                      onTap: () => _changeTheme(ThemeMode.light),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeCard(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark',
                      isSelected: mode == ThemeMode.dark,
                      onTap: () => _changeTheme(ThemeMode.dark),
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
             SwitchListTile.adaptive(
               secondary: const Icon(Icons.wallpaper_rounded),
               title: const Text('Use dynamic colors'),
               subtitle: const Text('Match Material You palette on Android 12+. Disable to use the app palette.'),
               value: ref.watch(dynamicColorsControllerProvider),
               onChanged: (v) async {
                 await ref.read(dynamicColorsControllerProvider.notifier).setEnabled(v);
                 HapticFeedback.selectionClick();
               },
             ),
             const SizedBox(height: 12),
             Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getThemeHint(mode),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationSection(BuildContext context, String usbLabel) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: 'Configuration',
        subtitle: 'USB gadget identity and device settings',
        leading: Icon(Icons.tune, color: cs.primary),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.usb_outlined),
              title: const Text('USB Identity'),
              subtitle: Text(usbLabel),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push(AppRoutes.usbIdentity).then((_) {
                  _resolveUsbNames();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebuggingSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: 'Debugging',
        subtitle: 'System diagnostics and operation logs',
        leading: Icon(Icons.bug_report_outlined, color: cs.primary),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Diagnostics'),
              subtitle: const Text('Kernel config, root status, UDC info'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.diagnostics),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Logs'),
              subtitle: const Text('Real-time gadget operation logs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.logs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SectionCard(
        title: 'About',
        subtitle: 'App information and legal',
        leading: Icon(Icons.info_outline, color: cs.primary),
        child: Column(
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final version = info == null ? '—' : '${info.version}+${info.buildNumber}';
                return ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('HIDWiggle - KaijinLab Inc.'),
                  subtitle: Text('Version $version'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AboutPage()),
                    );
                  },
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('Licenses'),
              subtitle: const Text('Open source licenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'HIDWiggle',
                  applicationVersion: 'by KaijinLab Inc.',
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.mouse_outlined,
                      size: 48,
                      color: cs.primary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ThemeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.7)
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cs.primary.withOpacity(0.5) : cs.outlineVariant.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle, size: 16, color: cs.primary),
            ],
          ],
        ),
      ),
    );
  }
}
