import 'package:flutter/material.dart';

/// Formats a dynamic numeric quantity for display in badges and cards.
String formatComponentQuantity(Object? value) {
  final parsed = double.tryParse('$value');
  if (parsed == null) return '$value';
  if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
  return parsed
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Displays an expiry chip / badge indicating expired, expiring soon, or active state.
Widget? buildExpiryBadge(String? expiryDate) {
  if (expiryDate == null || expiryDate.trim().isEmpty) return null;
  final date = DateTime.tryParse(expiryDate.trim());
  if (date == null) {
    return Chip(
      avatar: const Icon(Icons.event, size: 14),
      label: Text('Exp: $expiryDate', style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysLeft = date.difference(today).inDays;

  final Color bg;
  final Color fg;
  final String text;
  final IconData icon;

  if (daysLeft < 0) {
    bg = Colors.red.shade100;
    fg = Colors.red.shade900;
    text = 'Expired ($expiryDate)';
    icon = Icons.warning_amber_rounded;
  } else if (daysLeft <= 30) {
    bg = Colors.amber.shade100;
    fg = Colors.amber.shade900;
    text = 'Expiring in $daysLeft d ($expiryDate)';
    icon = Icons.access_time_filled;
  } else {
    bg = Colors.green.shade50;
    fg = Colors.green.shade800;
    text = 'Exp: $expiryDate';
    icon = Icons.event_available;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: fg.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

/// Displays current stock quantity and unit as a styled badge.
class ComponentStockBadge extends StatelessWidget {
  const ComponentStockBadge({
    super.key,
    required this.item,
    this.compact = false,
  });

  final Map<String, dynamic> item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final quantity = formatComponentQuantity(item['current_quantity']);
    final unit = item['unit'] as String? ?? 'Pieces';
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 48 : 118),
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            quantity,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: compact ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}
