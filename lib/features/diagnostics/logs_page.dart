import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/platform/gadget_providers.dart';
import '../../core/widgets/app_card.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _copyAllLogs() async {
    if (_logs.isEmpty) return;

    try {
      final text = _logs.join('\n');
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied ${_logs.length} log lines')),
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

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsStream = ref.watch(gadgetLogsStreamProvider);

    logsStream.whenData((log) {
      if (log.isNotEmpty) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 2000) {
            _logs.removeAt(0);
          }
        });
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            tooltip: _autoScroll ? 'Disable auto-scroll' : 'Enable auto-scroll',
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            icon: Icon(_autoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined),
          ),
          IconButton(
            tooltip: 'Copy all',
            onPressed: _logs.isEmpty ? null : _copyAllLogs,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _logs.isEmpty ? null : _clearLogs,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: _logs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.article_outlined, size: 48),
                    const SizedBox(height: AppTokens.spaceMd),
                    Text(
                      'No logs yet',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    Text(
                      'Logs will appear here when gadget operations are performed.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _buildLogLine(theme, log),
                );
              },
            ),
    );
  }

  Widget _buildLogLine(ThemeData theme, String log) {
    Color? textColor;
    IconData? icon;

    if (log.contains('/ERR]') || log.toLowerCase().contains('error') || log.toLowerCase().contains('failed')) {
      textColor = theme.colorScheme.error;
      icon = Icons.error_outline;
    } else if (log.toLowerCase().contains('warning') || log.toLowerCase().contains('warn')) {
      textColor = theme.colorScheme.tertiary;
      icon = Icons.warning_amber;
    } else if (log.contains('[gadget]') || log.contains('[root]')) {
      textColor = theme.colorScheme.primary;
      icon = Icons.settings_outlined;
    } else if (log.contains('[hid]') || log.contains('[kbd]')) {
      textColor = theme.colorScheme.secondary;
      icon = Icons.keyboard_outlined;
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: SelectableText(
              log,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
