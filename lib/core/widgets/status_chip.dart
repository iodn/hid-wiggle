import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool emphasized;

  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.surfaceContainerHighest;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Chip(
      avatar: Icon(icon, size: 18, color: emphasized ? fg : null),
      label: Text(label),
      backgroundColor: emphasized ? bg : null,
      labelStyle: emphasized ? TextStyle(color: fg) : null,
      side: emphasized ? BorderSide(color: bg) : null,
      visualDensity: VisualDensity.compact,
    );
  }
}
