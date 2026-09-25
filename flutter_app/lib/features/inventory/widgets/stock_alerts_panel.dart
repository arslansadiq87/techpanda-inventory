import 'package:flutter/material.dart';

/// Stock alert bell button with active badge counter.
class StockAlertBellButton extends StatelessWidget {
  const StockAlertBellButton({
    super.key,
    required this.alertsCount,
    this.unreadCount,
    required this.isOpen,
    required this.onToggle,
  });

  final int alertsCount;
  final int? unreadCount;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final badgeCount = unreadCount ?? alertsCount;
    return Tooltip(
      message: alertsCount == 0
          ? 'No stock alerts'
          : (badgeCount > 0
                ? '$badgeCount unread alert(s)'
                : '$alertsCount stock alert(s) (checked)'),
      child: IconButton(
        onPressed: onToggle,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              isOpen
                  ? Icons.notifications
                  : (badgeCount > 0
                        ? Icons.notifications_active
                        : (alertsCount > 0
                              ? Icons.notifications
                              : Icons.notifications_none)),
              color: badgeCount > 0
                  ? Colors.orange.shade700
                  : (alertsCount > 0
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null),
            ),
            if (badgeCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slide-in panel displaying out-of-stock and low-stock components with direct navigation.
class StockAlertsPanel extends StatelessWidget {
  const StockAlertsPanel({
    super.key,
    required this.alerts,
    required this.onClose,
    required this.onSelectAlert,
    required this.onViewAll,
    this.onClearAll,
  });

  final List<dynamic> alerts;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSelectAlert;
  final VoidCallback onViewAll;
  final VoidCallback? onClearAll;

  Widget _alertSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertRow(BuildContext context, Map<String, dynamic> alert) {
    final isOut = alert['alert_type'] == 'out_of_stock';
    final isExpired = alert['alert_type'] == 'expired';
    final isExpirySoon = alert['alert_type'] == 'expiry_soon';
    final qty = alert['current_quantity'] ?? 0;
    final min = alert['minimum_quantity'] ?? 0;
    final unit = alert['unit'] as String? ?? 'pcs';

    return InkWell(
      onTap: () => onSelectAlert(alert),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert['name'] as String? ?? 'Unknown Component',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Location: ${alert['location_name'] ?? 'Not assigned'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isExpired || isExpirySoon
                      ? '${isExpired ? 'Expired' : 'Expires'}: ${alert['expiry_date']}'
                      : '$qty $unit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isExpired || isOut
                        ? Colors.red
                        : Colors.orange.shade800,
                  ),
                ),
                Text(
                  'Min: $min',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outOfStock = alerts
        .where((a) => (a as Map)['alert_type'] == 'out_of_stock')
        .toList();
    final lowStock = alerts
        .where((a) => (a as Map)['alert_type'] == 'low_stock')
        .toList();
    final expired = alerts
        .where((a) => (a as Map)['alert_type'] == 'expired')
        .toList();
    final expirySoon = alerts
        .where((a) => (a as Map)['alert_type'] == 'expiry_soon')
        .toList();

    return Material(
      elevation: 8,
      child: Container(
        width: 380,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.notifications, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inventory Alerts (${alerts.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onClearAll != null && alerts.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onClearAll,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close alerts',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'All stock levels are optimal',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No components below minimum quantity threshold',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        if (expired.isNotEmpty) ...[
                          _alertSectionHeader(
                            'Expired',
                            expired.length,
                            Colors.red.shade900,
                            Icons.event_busy,
                          ),
                          ...expired.map(
                            (a) => _alertRow(
                              context,
                              Map<String, dynamic>.from(a as Map),
                            ),
                          ),
                        ],
                        if (expirySoon.isNotEmpty) ...[
                          _alertSectionHeader(
                            'Expiring within 30 days',
                            expirySoon.length,
                            Colors.deepOrange,
                            Icons.schedule,
                          ),
                          ...expirySoon.map(
                            (a) => _alertRow(
                              context,
                              Map<String, dynamic>.from(a as Map),
                            ),
                          ),
                        ],
                        if (outOfStock.isNotEmpty) ...[
                          _alertSectionHeader(
                            'Out of Stock',
                            outOfStock.length,
                            Colors.red.shade700,
                            Icons.report_outlined,
                          ),
                          ...outOfStock.map(
                            (a) => _alertRow(
                              context,
                              Map<String, dynamic>.from(a as Map),
                            ),
                          ),
                        ],
                        if (lowStock.isNotEmpty) ...[
                          _alertSectionHeader(
                            'Low Stock',
                            lowStock.length,
                            Colors.orange.shade700,
                            Icons.warning_amber_outlined,
                          ),
                          ...lowStock.map(
                            (a) => _alertRow(
                              context,
                              Map<String, dynamic>.from(a as Map),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.memory, size: 16),
                            label: const Text('View all components'),
                            onPressed: onViewAll,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
