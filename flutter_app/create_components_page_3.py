file_content3 = """
class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;
  final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;
  final Map<String, dynamic> component;

  const ComponentDetailModal({
    super.key,
    required this.api,
    required this.buildImage,
    required this.onShowComponentImage,
    required this.component,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ComponentDetailModal(
        api: api,
        buildImage: buildImage,
        onShowComponentImage: onShowComponentImage,
        component: component,
      ),
    );
  }

  Widget _componentDetailRow(BuildContext context, String label, Object? value) {
    final text = (value?.toString().trim() ?? '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePath =
        component['primary_image_preview'] as String? ??
        component['primary_image_thumbnail'] as String?;
    final details = (component['description'] as String? ?? '').trim();

    return AlertDialog(
      title: Text(component['name'] as String? ?? 'Component details'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imagePath != null) ...[
                Center(
                  child: InkWell(
                    onTap: () => onShowComponentImage(component),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: buildImage(
                        imagePath,
                        height: 180,
                        width: 180,
                        fit: BoxFit.cover,
                        errorChild: const SizedBox(
                          height: 180,
                          width: 180,
                          child: Icon(Icons.broken_image, size: 42),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _componentDetailRow(context, 'Inventory code', component['inventory_code']),
              _componentDetailRow(context, 'Type', component['package_type']),
              _componentDetailRow(context, 'Manufacturer', component['manufacturer']),
              _componentDetailRow(context, 'Model number', component['model_number']),
              _componentDetailRow(context, 'Part number', component['part_number']),
              _componentDetailRow(context, 'Location', component['location_name']),
              _componentDetailRow(
                context,
                'Stock',
                '${formatComponentQuantity(component['current_quantity'])} ${component['unit'] ?? 'Pieces'}',
              ),
              _componentDetailRow(
                context,
                'Minimum stock',
                '${formatComponentQuantity(component['minimum_quantity'])} ${component['unit'] ?? 'Pieces'}',
              ),
              if (component['price'] != null && '${component['price']}'.trim().isNotEmpty)
                _componentDetailRow(
                  context,
                  'Price',
                  _formatComponentPrice(component['price']),
                ),
              if (component['expiry_date'] != null &&
                  '${component['expiry_date']}'.trim().isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 126,
                        child: Text(
                          'Expiry date',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: buildExpiryBadge('${component['expiry_date']}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (component['datasheet_url'] != null &&
                  '${component['datasheet_url']}'.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Open / Download Datasheet'),
                  onPressed: () {
                    final url = api.mediaUrl('${component['datasheet_url']}');
                    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  },
                ),
                const SizedBox(height: 6),
              ],
              if (component['datasheet_text'] != null &&
                  '${component['datasheet_text']}'.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.notes, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Datasheet & Specifications',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Copy to clipboard',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: '${component['datasheet_text']}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Datasheet text copied to clipboard!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        '${component['datasheet_text']}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              if (details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Details, usage, or specs',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SelectableText(details),
              ],
              if (details.isEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'No details, usage, or specs saved.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
"""

with open("create_components_page_3.py", "w", encoding="utf-8") as f:
    f.write("with open('lib/features/inventory/pages/components_page.dart', 'a', encoding='utf-8') as out:\n")
    f.write("    out.write('''" + file_content3 + "''')\n")

