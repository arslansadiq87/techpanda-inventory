import 'package:flutter/material.dart';

/// Helper to get the foreground icon color for an icon tile, adapting to dark mode.
Color iconTileForeground(BuildContext context, Color accent) {
  if (Theme.of(context).brightness != Brightness.dark) return accent;
  return Color.lerp(accent, Colors.white, 0.18)!;
}

/// Helper to get the container decoration for an icon tile, adapting to dark mode.
BoxDecoration iconTileDecoration(
  BuildContext context,
  Color accent, {
  required double radius,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: accent.withValues(alpha: dark ? 0.30 : 0.12),
    border: dark ? Border.all(color: accent.withValues(alpha: 0.42)) : null,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: dark
        ? [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ]
        : null,
  );
}

/// Metric card widget showing an icon, count/value, and label.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double width;
  final Color? accentColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.width = 190,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final iconColor = iconTileForeground(context, accent);

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: ValueKey('metric-icon-$label'),
                padding: const EdgeInsets.all(10),
                decoration: iconTileDecoration(context, accent, radius: 12),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

