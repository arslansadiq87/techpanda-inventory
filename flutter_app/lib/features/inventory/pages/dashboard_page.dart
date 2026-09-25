import 'package:flutter/material.dart';

import '../dialogs/component_type_dialogs.dart';
import '../widgets/error_banner.dart';
import '../widgets/inventory_badges.dart';
import '../widgets/metric_card.dart';

/// Palette used for component type stock cards.
const componentCardAccents = [
  Color(0xFF2F80ED),
  Color(0xFF16A765),
  Color(0xFFFF9F1C),
  Color(0xFFE83E8C),
  Color(0xFF7C4DFF),
  Color(0xFF0B8F8F),
];

/// Computes a stable accent color for a component type name.
Color componentTypeAccent(String name) {
  final hash = name.codeUnits.fold<int>(0, (sum, code) => sum + code);
  return componentCardAccents[hash % componentCardAccents.length];
}

/// Returns a time-based greeting for the current hour.
String timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

String formatInventoryValue(dynamic value) {
  final amount = double.tryParse('$value') ?? 0;
  return amount.toStringAsFixed(2);
}

/// Dashboard overview page showing metrics, stock summary by component type,
/// and recently added components.
class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  final String? error;
  final VoidCallback onDismissError;
  final VoidCallback onViewAllComponents;
  final ValueChanged<String> onOpenComponentsForType;
  final ValueChanged<Map<String, dynamic>> onOpenComponentInStock;
  final Widget Function(Map<String, dynamic> item, {required double size})
  buildThumbnail;

  const DashboardPage({
    super.key,
    required this.dashboard,
    required this.error,
    required this.onDismissError,
    required this.onViewAllComponents,
    required this.onOpenComponentsForType,
    required this.onOpenComponentInStock,
    required this.buildThumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (error != null)
          ErrorBanner(errorMessage: error!, onDismiss: onDismissError),
        if (MediaQuery.sizeOf(context).width <= 760)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${timeGreeting()}, TechPanda',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here is what is happening with your inventory today.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final metricWidth = constraints.maxWidth <= 760
                ? (constraints.maxWidth - 12) / 2
                : 190.0;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(
                  label: 'Component types',
                  value: '${dashboard['total_component_types'] ?? 0}',
                  icon: Icons.category,
                  width: metricWidth,
                  accentColor: const Color(0xFF2F80ED),
                ),
                MetricCard(
                  label: 'Number of products',
                  value: '${dashboard['total_products'] ?? 0}',
                  icon: Icons.widgets,
                  width: metricWidth,
                  accentColor: const Color(0xFF16A765),
                ),
                MetricCard(
                  label: 'Total stock',
                  value: formatComponentQuantity(
                    dashboard['total_stock_quantity'],
                  ),
                  icon: Icons.inventory_2,
                  width: metricWidth,
                  accentColor: const Color(0xFFFF9F1C),
                ),
                MetricCard(
                  label: 'Total inventory value',
                  value: formatInventoryValue(
                    dashboard['total_inventory_value'],
                  ),
                  icon: Icons.account_balance_wallet,
                  width: metricWidth,
                  accentColor: const Color(0xFF00A896),
                ),
                MetricCard(
                  label: 'Out of stock',
                  value: '${dashboard['out_of_stock_count'] ?? 0}',
                  icon: Icons.report,
                  width: metricWidth,
                  accentColor: const Color(0xFFE83E8C),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Component type stock',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton(
              onPressed: onViewAllComponents,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildComponentTypeStockCards(context),
        const SizedBox(height: 20),
        _buildRecentComponents(context),
      ],
    );
  }

  Widget _buildRecentComponents(BuildContext context) {
    final recent = (dashboard['recent_components'] as List<dynamic>? ?? []);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent components',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton(
              onPressed: onViewAllComponents,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No components have been added yet.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = Map<String, dynamic>.from(
                      recent[index] as Map,
                    );
                    final details = [
                      if ((item['package_type'] as String?)?.isNotEmpty == true)
                        item['package_type'],
                      if ((item['location_name'] as String?)?.isNotEmpty ==
                          true)
                        item['location_name'],
                    ].join(' • ');
                    return ListTile(
                      minVerticalPadding: 10,
                      leading: buildThumbnail(item, size: 44),
                      title: Text(
                        item['name'] as String? ?? 'Component',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: details.isEmpty ? null : Text(details),
                      trailing: SizedBox(
                        width: 64,
                        height: 48,
                        child: Center(
                          child: ComponentStockBadge(item: item, compact: true),
                        ),
                      ),
                      onTap: () => onOpenComponentInStock(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComponentTypeStockCards(BuildContext context) {
    final items = (dashboard['component_type_stock'] as List<dynamic>? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No component types have stock available.'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth <= 760 ? 2 : 4;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        final maxStock = items.fold<double>(0, (maximum, item) {
          final stock = double.tryParse('${item['stock_quantity']}') ?? 0;
          return stock > maximum ? stock : maximum;
        });
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            final stock = double.tryParse('${item['stock_quantity']}') ?? 0;
            final accent = componentTypeAccent(
              item['name'] as String? ?? 'Other',
            );
            final iconColor = iconTileForeground(context, accent);
            return SizedBox(
              width: cardWidth,
              child: Card(
                child: InkWell(
                  onTap: () => onOpenComponentsForType(
                    item['name'] as String? ?? 'Other',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              key: ValueKey(
                                'component-type-icon-${item['name']}',
                              ),
                              padding: const EdgeInsets.all(8),
                              decoration: iconTileDecoration(
                                context,
                                accent,
                                radius: 10,
                              ),
                              child: buildComponentTypeIcon(
                                item,
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] as String? ?? 'Other',
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${item['product_count'] ?? 0} products',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatComponentQuantity(item['stock_quantity'])} Qty',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            value: maxStock == 0 ? 0 : stock / maxStock,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
