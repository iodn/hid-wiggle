import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/models/usb_device.dart';
import '../../core/models/usb_identity_settings.dart';
import '../../core/services/usb_ids_providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../state/app_settings_controller.dart';
import 'usb_device_picker_page.dart';

class UsbIdentityPage extends ConsumerStatefulWidget {
  const UsbIdentityPage({super.key});

  @override
  ConsumerState<UsbIdentityPage> createState() => _UsbIdentityPageState();
}

class _UsbIdentityPageState extends ConsumerState<UsbIdentityPage> {
  final _vidCtrl = TextEditingController();
  final _pidCtrl = TextEditingController();
  final _mfgCtrl = TextEditingController();
  final _prodCtrl = TextEditingController();
  final _snCtrl = TextEditingController();
  final _maxPowerCtrl = TextEditingController();

  String? _vidErr;
  String? _pidErr;
  String? _maxPowerErr;
  bool _initialized = false;

  String? _resolvedVendorName;
  String? _resolvedProductName;

  @override
  void dispose() {
    _vidCtrl.dispose();
    _pidCtrl.dispose();
    _mfgCtrl.dispose();
    _prodCtrl.dispose();
    _snCtrl.dispose();
    _maxPowerCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(UsbIdentitySettings s) {
    _vidCtrl.text = s.vendorId;
    _pidCtrl.text = s.productId;
    _mfgCtrl.text = s.manufacturer;
    _prodCtrl.text = s.product;
    _snCtrl.text = s.serialNumber;
    _maxPowerCtrl.text = s.maxPowerMa.toString();
    _initialized = true;
    _resolveNames();
  }

  Future<void> _resolveNames() async {
    final vid = UsbIdentitySettings.tryParseHexOrDec(_vidCtrl.text);
    final pid = UsbIdentitySettings.tryParseHexOrDec(_pidCtrl.text);

    if (vid == null || pid == null) {
      setState(() {
        _resolvedVendorName = null;
        _resolvedProductName = null;
      });
      return;
    }

    try {
      final repo = ref.read(usbIdsRepositoryProvider);
      final product = await repo.getProduct(vid, pid);
      if (mounted) {
        setState(() {
          _resolvedVendorName = product?.vendorName;
          _resolvedProductName = product?.name;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedVendorName = null;
          _resolvedProductName = null;
        });
      }
    }
  }

  void _validate() {
    final vid = UsbIdentitySettings.tryParseHexOrDec(_vidCtrl.text);
    final pid = UsbIdentitySettings.tryParseHexOrDec(_pidCtrl.text);
    setState(() {
      _vidErr = (vid == null || vid < 0 || vid > 0xFFFF)
          ? 'Invalid VID (use 0xNNNN or decimal)'
          : null;
      _pidErr = (pid == null || pid < 0 || pid > 0xFFFF)
          ? 'Invalid PID (use 0xNNNN or decimal)'
          : null;
      final mp = int.tryParse(_maxPowerCtrl.text.trim());
      _maxPowerErr = (mp == null || mp < 2 || mp > 500)
          ? 'MaxPower must be 2..500 mA'
          : null;
    });
    _resolveNames();
  }

  Future<void> _save() async {
    _validate();
    if (_vidErr != null || _pidErr != null || _maxPowerErr != null) return;

    final next = UsbIdentitySettings(
      vendorId: _vidCtrl.text.trim(),
      productId: _pidCtrl.text.trim(),
      manufacturer: _mfgCtrl.text.trim(),
      product: _prodCtrl.text.trim(),
      serialNumber: _snCtrl.text.trim(),
      maxPowerMa: int.parse(_maxPowerCtrl.text.trim()),
    );

    await ref.read(appSettingsControllerProvider.notifier).updateUsbIdentity(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved USB identity: ${next.vidPidLabel}')),
    );
  }

  Future<void> _pickDevice() async {
    final product = await Navigator.of(context).push<UsbProduct>(
      MaterialPageRoute(builder: (context) => const UsbDevicePickerPage()),
    );

    if (product == null || !mounted) return;

    setState(() {
      _vidCtrl.text = product.vidHex;
      _pidCtrl.text = product.pidHex;
      if (product.vendorName != null && product.vendorName!.isNotEmpty) {
        _mfgCtrl.text = product.vendorName!;
      }
      _prodCtrl.text = product.name;
      _resolvedVendorName = product.vendorName;
      _resolvedProductName = product.name;
    });
    _validate();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final usb = settings?.usbIdentity ?? UsbIdentitySettings.defaults();
    if (!_initialized) _loadFrom(usb);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Identity'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          SectionHeader(
            title: 'Gadget identity',
            subtitle: 'These values are sent to Kotlin in the profile payload (activateProfile).',
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_resolvedVendorName != null)
                  Text(
                    _resolvedVendorName!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.end,
                  ),
                if (_resolvedProductName != null)
                  Text(
                    _resolvedProductName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                if (_resolvedVendorName == null && _resolvedProductName == null)
                  Text(
                    usb.vidPidLabel,
                    style: theme.textTheme.labelLarge,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _pickDevice,
                  icon: const Icon(Icons.search),
                  label: const Text('Search USB Device Database'),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                const Divider(),
                const SizedBox(height: AppTokens.spaceMd),
                _field(
                  label: 'Vendor ID (VID)',
                  controller: _vidCtrl,
                  hint: '0x1d6b',
                  errorText: _vidErr,
                  onChanged: (_) => _validate(),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _field(
                  label: 'Product ID (PID)',
                  controller: _pidCtrl,
                  hint: '0x0104',
                  errorText: _pidErr,
                  onChanged: (_) => _validate(),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _field(
                  label: 'Manufacturer',
                  controller: _mfgCtrl,
                  hint: 'KaijinLab',
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _field(
                  label: 'Product string',
                  controller: _prodCtrl,
                  hint: 'HIDWiggle',
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _field(
                  label: 'Serial number (optional)',
                  controller: _snCtrl,
                  hint: 'Leave blank to auto-generate',
                ),
                const SizedBox(height: AppTokens.spaceSm),
                _field(
                  label: 'MaxPower (mA)',
                  controller: _maxPowerCtrl,
                  hint: '250',
                  keyboardType: TextInputType.number,
                  errorText: _maxPowerErr,
                  onChanged: (_) => _validate(),
                ),
                const SizedBox(height: AppTokens.spaceMd),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
      ),
    );
  }
}
