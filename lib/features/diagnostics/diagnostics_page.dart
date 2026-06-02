import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/platform/gadget_providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';

class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends ConsumerState<DiagnosticsPage> {
  Map<String, dynamic>? _diagnostics;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  /// Safely convert any Map to Map<String, dynamic>
  static Map<String, dynamic> _toStringMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return <String, dynamic>{};
  }

  /// Safely extract a nested map
  static Map<String, dynamic>? _extractMap(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    return _toStringMap(value);
  }

  /// Safely extract a list
  static List<dynamic>? _extractList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is List) return value;
    return null;
  }

  Future<void> _loadDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final channel = ref.read(gadgetChannelProvider);
      final rawData = await channel.getDiagnostics();
      
      // Convert to proper Map<String, dynamic>
      final data = _toStringMap(rawData);
      
      debugPrint('[Diagnostics] Received keys: ${data.keys.toList()}');
      debugPrint('[Diagnostics] Data length: ${data.length}');
      
      if (mounted) {
        setState(() {
          _diagnostics = data;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[Diagnostics] Error: $e');
      debugPrint('[Diagnostics] Stack: $stackTrace');
      
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_diagnostics == null) return;

    try {
      const encoder = JsonEncoder.withIndent('  ');
      final json = encoder.convert(_diagnostics);
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Diagnostics copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to copy: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadDiagnostics,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Copy JSON',
            onPressed: _diagnostics == null ? null : _copyToClipboard,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme)
              : _diagnostics == null || _diagnostics!.isEmpty
                  ? _buildEmpty(theme)
                  : _buildDiagnostics(theme),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              'Failed to load diagnostics',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            FilledButton.icon(
              onPressed: _loadDiagnostics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              'No diagnostics data available',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'The backend returned empty diagnostics. This might indicate the getDiagnostics() method is not implemented yet.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            FilledButton.icon(
              onPressed: _loadDiagnostics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnostics(ThemeData theme) {
    final data = _diagnostics!;
    
    debugPrint('[Diagnostics] Building UI with keys: ${data.keys.toList()}');
    
    // Safely extract nested maps
    final status = _extractMap(data, 'status');
    final kernelConfig = _extractMap(data, 'kernelConfig');

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: [
        // Debug card showing raw keys
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.data_object, size: 18),
                  const SizedBox(width: 8),
                  Text('Raw Data Keys', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.keys.isEmpty ? 'No keys found' : data.keys.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        
        if (status != null) ...[
          const SectionHeader(
            title: 'System Status',
            subtitle: 'Current gadget state and capabilities.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _buildStatusSection(theme, status),
          const SizedBox(height: AppTokens.spaceLg),
        ],
        
        if (kernelConfig != null) ...[
          const SectionHeader(
            title: 'Kernel Configuration',
            subtitle: 'USB gadget and configfs kernel flags.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _buildKernelConfigSection(theme, kernelConfig),
          const SizedBox(height: AppTokens.spaceLg),
        ],
        
        const SectionHeader(
          title: 'System Information',
          subtitle: 'Root access, UDC, and configfs details.',
        ),
        const SizedBox(height: AppTokens.spaceSm),
        _buildSystemInfoSection(theme, data),
        const SizedBox(height: AppTokens.spaceLg),
        
        const SectionHeader(
          title: 'Raw Kernel Config',
          subtitle: 'First 60 lines from /proc/config.gz or /boot/config-*.',
        ),
        const SizedBox(height: AppTokens.spaceSm),
        _buildRawKernelConfig(theme, data),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildStatusSection(ThemeData theme, Map<String, dynamic> status) {
    final rootAvailable = status['rootAvailable'] == true;
    final supportAvailable = status['supportAvailable'] == true;
    final state = status['state']?.toString() ?? 'UNKNOWN';
    final message = status['message']?.toString();
    final udcList = _extractList(status, 'udcList');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeyValue(theme, 'Root Available', rootAvailable ? 'Yes' : 'No',
              valueColor: rootAvailable ? theme.colorScheme.primary : theme.colorScheme.error),
          const Divider(),
          _buildKeyValue(theme, 'USB Gadget Support', supportAvailable ? 'Yes' : 'No',
              valueColor: supportAvailable ? theme.colorScheme.primary : theme.colorScheme.error),
          const Divider(),
          _buildKeyValue(theme, 'State', state),
          if (message != null) ...[
            const Divider(),
            _buildKeyValue(theme, 'Message', message),
          ],
          if (udcList != null && udcList.isNotEmpty) ...[
            const Divider(),
            _buildKeyValue(theme, 'UDC List', udcList.join(', ')),
          ],
        ],
      ),
    );
  }

  Widget _buildKernelConfigSection(ThemeData theme, Map<String, dynamic> config) {
    final kernelVersion = config['KERNEL_VERSION']?.toString() ?? 'Unknown';
    final entries = config.entries.where((e) => e.key != 'KERNEL_VERSION').toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeyValue(theme, 'Kernel Version', kernelVersion),
          if (entries.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              'Configuration Flags',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            ...entries.map((e) {
              final value = e.value?.toString() ?? 'Unknown';
              Color? valueColor;
              if (value == 'Yes' || value == 'Module') {
                valueColor = theme.colorScheme.primary;
              } else if (value == 'Not set' || value == 'No') {
                valueColor = theme.colorScheme.onSurfaceVariant;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildKeyValue(theme, e.key, value, valueColor: valueColor),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemInfoSection(ThemeData theme, Map<String, dynamic> data) {
    final rootId = data['rootId']?.toString();
    final sysUsbController = data['sysUsbController']?.toString();
    final udcList = _extractList(data, 'udcList');
    final configfsBases = _extractList(data, 'configfsBases');
    final configfsMount = data['configfsMount']?.toString();
    final paths = _extractMap(data, 'paths');
    final existingGadgets = _extractList(data, 'existingGadgetsInConfig');

    final hasAnyData = rootId != null ||
        sysUsbController != null ||
        udcList != null ||
        configfsBases != null ||
        configfsMount != null ||
        paths != null ||
        existingGadgets != null;

    if (!hasAnyData) {
      return AppCard(
        child: Text(
          'No system information available. The backend may not be returning this data yet.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rootId != null) ...[
            _buildKeyValue(theme, 'Root ID', rootId),
            const Divider(),
          ],
          if (sysUsbController != null) ...[
            _buildKeyValue(theme, 'sys.usb.controller', sysUsbController),
            const Divider(),
          ],
          if (udcList != null) ...[
            _buildKeyValue(theme, 'UDC List', udcList.isEmpty ? 'None' : udcList.join(', ')),
            const Divider(),
          ],
          if (configfsBases != null) ...[
            _buildKeyValue(
              theme,
              'Configfs Bases',
              configfsBases.isEmpty ? 'None found' : configfsBases.join(', '),
            ),
            const Divider(),
          ],
          if (configfsMount != null) ...[
            _buildKeyValue(theme, 'Configfs Mount', configfsMount.isEmpty ? 'Not mounted' : configfsMount),
            const Divider(),
          ],
          if (existingGadgets != null) ...[
            _buildKeyValue(
              theme,
              'Existing Gadgets',
              existingGadgets.isEmpty ? 'None' : existingGadgets.join(', '),
            ),
            const Divider(),
          ],
          if (paths != null && paths.isNotEmpty) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Text('Paths', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppTokens.spaceSm),
            ...paths.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _buildKeyValue(theme, e.key, e.value?.toString() ?? 'N/A'),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildRawKernelConfig(ThemeData theme, Map<String, dynamic> data) {
    final rawLines = _extractList(data, 'kernelConfigRawFirstLines');
    final rawError = data['kernelConfigRawError']?.toString();

    if (rawError != null) {
      return AppCard(
        child: Text(
          'Error: $rawError',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    if (rawLines == null || rawLines.isEmpty) {
      return AppCard(
        child: Text(
          'No raw kernel config available',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: SelectableText(
              rawLines.join('\n'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValue(ThemeData theme, String key, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            key,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
