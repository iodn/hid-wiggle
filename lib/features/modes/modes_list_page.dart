import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_tokens.dart';
import '../../core/routing/app_routes.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../state/app_settings_controller.dart';
import 'movement_preview.dart';
import 'pattern_catalog.dart';

class ModesListPage extends ConsumerStatefulWidget {
  const ModesListPage({super.key});

  @override
  ConsumerState<ModesListPage> createState() => _ModesListPageState();
}

class _ModesListPageState extends ConsumerState<ModesListPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsControllerProvider).asData?.value;
    final cfg = settings?.jiggle ?? PatternCatalog.defaultsFor('micro');
    final activeId = cfg.patternId;

    final filtered = PatternCatalog.patterns.where((p) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.preview.toLowerCase().contains(q);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modes'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        children: [
          const SectionHeader(
            title: 'Patterns',
            subtitle:
                'Tap a mode to apply a pre-tuned default immediately. Preview and real behavior stay in sync.',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live preview',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  PatternCatalog.byId(activeId).preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
                    child: MovementPreview(config: cfg, height: 170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SearchBar(
            leading: const Icon(Icons.search),
            hintText: 'Search patterns…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          for (final p in filtered) ...[
            AppCard(
              onTap: () async {
                final next = PatternCatalog.defaultsFor(p.id);
                await ref.read(appSettingsControllerProvider.notifier).updateJiggle(next);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    p.id == activeId ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: p.id == activeId ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(p.description, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text(
                          p.preview,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  IconButton(
                    tooltip: 'Tune',
                    onPressed: () => context.push('${AppRoutes.modes}/${p.id}'),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
          ],
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'No matches. Try a different search.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
