import os

file_content = """import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../inventory_home.dart' show ComponentImageSelection, ComponentDatasheetSelection, componentUnits;
import '../widgets/inventory_badges.dart';

String _formatComponentPrice(Object? value) {
  if (value == null) return '';
  final str = '$value'.trim();
  if (str.isEmpty) return '';
  final parsed = double.tryParse(str);
  if (parsed == null) return str;
  if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
  return parsed
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\\.$'), '');
}

String _componentTypeDisplayName(dynamic item) {
  if (item is! Map) return item?.toString() ?? '';
  final parentName = item['parent_type_name'] as String?;
  final name = item['name'] as String? ?? '';
  if (parentName != null && parentName.isNotEmpty) {
    return '$parentName / $name';
  }
  return name;
}

Future<void> _selectExpiryDate(
  BuildContext context,
  TextEditingController controller,
) async {
  DateTime initial = DateTime.now().add(const Duration(days: 365));
  if (controller.text.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(controller.text.trim());
    if (parsed != null) initial = parsed;
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2000),
    lastDate: DateTime(2050),
    helpText: 'Select expiry date',
  );
  if (picked != null) {
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    controller.text = formatted;
  }
}

class ComponentsPage extends StatelessWidget {
  final ApiClient api;
  final List<dynamic> components;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;

  final TextEditingController searchController;
  final String? filterComponentType;
  final String? filterLocationId;
  final String? filterUnit;
  final String filterStockStatus;
  final bool showMobileFilters;
  final String viewMode;

  final bool enableAddComponent;
  final bool enableEditComponent;
  final bool canCaptureImage;

  final ValueChanged<String?> onFilterComponentTypeChanged;
  final ValueChanged<String?> onFilterLocationIdChanged;
  final ValueChanged<String?> onFilterUnitChanged;
  final ValueChanged<String> onFilterStockStatusChanged;
  final VoidCallback onToggleMobileFilters;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;

  final ValueChanged<Map<String, dynamic>> onOpenComponentInStock;
  final ValueChanged<Map<String, dynamic>> onDeleteComponent;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(String componentId, ComponentImageSelection? image) onUploadImage;
  final Future<void> Function(String componentId, ComponentDatasheetSelection? datasheet) onUploadDatasheet;

  final Widget Function(Map<String, dynamic>, {required double size}) buildThumbnail;
  final Widget Function(Map<String, dynamic>) buildCardImage;
  final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;
  
  final Future<void> Function() onAddComponentType;
  final Future<void> Function() onEditComponentTypes;
  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;

  const ComponentsPage({
    super.key,
    required this.api,
    required this.components,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.searchController,
    required this.filterComponentType,
    required this.filterLocationId,
    required this.filterUnit,
    required this.filterStockStatus,
    required this.showMobileFilters,
    required this.viewMode,
    required this.enableAddComponent,
    required this.enableEditComponent,
    required this.canCaptureImage,
    required this.onFilterComponentTypeChanged,
    required this.onFilterLocationIdChanged,
    required this.onFilterUnitChanged,
    required this.onFilterStockStatusChanged,
    required this.onToggleMobileFilters,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onError,
    required this.onOpenComponentInStock,
    required this.onDeleteComponent,
    required this.onPickImage,
    required this.onCaptureImage,
    required this.onPickDatasheet,
    required this.onUploadImage,
    required this.onUploadDatasheet,
    required this.buildThumbnail,
    required this.buildCardImage,
    required this.buildImage,
    required this.onShowComponentImage,
    required this.onAddComponentType,
    required this.onEditComponentTypes,
    required this.onAddLocation,
    required this.onEditLocations,
    required this.onAddSupplier,
  });

  List<Map<String, dynamic>> _filteredComponents() {
    final query = searchController.text.toLowerCase().trim();
    return components.cast<Map<String, dynamic>>().where((component) {
      if (filterComponentType != null) {
        final pkgType = component['package_type'] as String?;
        if (pkgType != filterComponentType) {
          final subTypeObj = componentTypes.firstWhere(
            (t) => t['name'] == pkgType,
            orElse: () => <String, dynamic>{},
          );
          if (subTypeObj.isEmpty ||
              subTypeObj['parent_type_name'] != filterComponentType) {
            return false;
          }
        }
      }
      if (filterLocationId != null &&
          component['location_id'] != filterLocationId) {
        return false;
      }
      if (filterUnit != null && component['unit'] != filterUnit) {
        return false;
      }
      if (filterStockStatus != 'All') {
        final current = double.tryParse('${component['current_quantity']}') ?? 0;
        final minimum = double.tryParse('${component['minimum_quantity']}') ?? 0;
        final isOut = current <= 0;
        final isLow = current > 0 && current <= minimum;
        final status = switch (filterStockStatus) {
          'In stock' => current > 0,
          'Low stock' => isLow,
          'Out of stock' => isOut,
          _ => true,
        };
        if (!status) return false;
      }
      if (query.isNotEmpty) {
        final name = (component['name'] as String?)?.toLowerCase() ?? '';
        final desc = (component['description'] as String?)?.toLowerCase() ?? '';
        final part = (component['part_number'] as String?)?.toLowerCase() ?? '';
        final model =
            (component['model_number'] as String?)?.toLowerCase() ?? '';
        final searchStr = '$name $desc $part $model';
        if (!searchStr.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleComponents = _filteredComponents();
    final isMobile = MediaQuery.sizeOf(context).width <= 760;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _componentSearchField()),
              if (isMobile) ...[
                const SizedBox(width: 4),
                _mobileComponentFilterButton(),
              ],
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (isMobile) ...[
          if (showMobileFilters)
            SliverToBoxAdapter(
              child: _componentFilterBar(context, visibleComponents.length),
            ),
        ] else ...[
          SliverToBoxAdapter(
            child: _componentFilterBar(context, visibleComponents.length),
          ),
        ],
        if (enableAddComponent && !isMobile) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: AddComponentPanel(
              api: api,
              componentTypes: componentTypes,
              locations: locations,
              suppliers: suppliers,
              canCaptureImage: canCaptureImage,
              onRefresh: onRefresh,
              onError: onError,
              onPickImage: onPickImage,
              onCaptureImage: onCaptureImage,
              onPickDatasheet: onPickDatasheet,
              onUploadImage: onUploadImage,
              onUploadDatasheet: onUploadDatasheet,
              onAddComponentType: onAddComponentType,
              onEditComponentTypes: onEditComponentTypes,
              onAddLocation: onAddLocation,
              onEditLocations: onEditLocations,
              onAddSupplier: onAddSupplier,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        if (viewMode == 'Thumbnails')
          _componentThumbnailSliverGrid(context, visibleComponents)
        else
          _componentSliverList(context, visibleComponents),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _componentSearchField() {
    return TextField(
      controller: searchController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: 'Search components',
      ),
      // debounce is handled by the caller attaching listener to the controller
    );
  }

  Widget _mobileComponentFilterButton() {
    return IconButton(
      onPressed: onToggleMobileFilters,
      icon: Icon(
        showMobileFilters ? Icons.filter_alt_off : Icons.filter_list,
      ),
      tooltip: showMobileFilters ? 'Hide filters' : 'Show filters',
    );
  }

  Widget _componentFilterBar(BuildContext context, int visibleCount) {
    final loadedCount = components.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 760;
          final mobileFieldWidth = (constraints.maxWidth - 10) / 2;
          double width(double target) => compact
              ? mobileFieldWidth
              : constraints.maxWidth < target
              ? constraints.maxWidth
              : target;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: width(220),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('component-type-filter-$filterComponentType'),
                  initialValue: filterComponentType,
                  decoration: const InputDecoration(
                    labelText: 'Component type',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All types'),
                    ),
                    ...componentTypes.map(
                      (item) => DropdownMenuItem<String>(
                        value: item['name'] as String,
                        child: Text(_componentTypeDisplayName(item)),
                      ),
                    ),
                  ],
                  onChanged: onFilterComponentTypeChanged,
                ),
              ),
              SizedBox(
                width: width(240),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('location-filter-$filterLocationId'),
                  initialValue: filterLocationId,
                  decoration: const InputDecoration(labelText: 'Location'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All locations'),
                    ),
                    ...locations.map(
                      (item) => DropdownMenuItem<String>(
                        value: item['id'] as String,
                        child: Text(item['display_name'] as String),
                      ),
                    ),
                  ],
                  onChanged: onFilterLocationIdChanged,
                ),
              ),
              SizedBox(
                width: width(180),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('unit-filter-$filterUnit'),
                  initialValue: filterUnit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All units'),
                    ),
                    ...componentUnits.map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: onFilterUnitChanged,
                ),
              ),
              SizedBox(
                width: width(180),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: filterStockStatus,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'All',
                      child: Text('All stock'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'In stock',
                      child: Text('In stock'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Low stock',
                      child: Text('Low stock'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Out of stock',
                      child: Text('Out of stock'),
                    ),
                  ],
                  onChanged: (value) => onFilterStockStatusChanged(value ?? 'All'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Showing $visibleCount of $loadedCount'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _componentSliverList(BuildContext context, List<Map<String, dynamic>> visibleComponents) {
    final itemCount = visibleComponents.isEmpty ? 0 : visibleComponents.length * 2 - 1;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index.isOdd) return const Divider(height: 1);

        final item = visibleComponents[index ~/ 2];
        return ListTile(
          minVerticalPadding: 10,
          leading: buildThumbnail(item, size: 44),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  item['name'] as String,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item['datasheet_url'] != null ||
                  (item['datasheet_text'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Datasheet available',
                  child: Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              if (item['expiry_date'] != null &&
                  '${item['expiry_date']}'.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                buildExpiryBadge('${item['expiry_date']}') ??
                    const SizedBox.shrink(),
              ],
            ],
          ),
          subtitle: Text(
            [
              if ((item['manufacturer'] as String?)?.isNotEmpty == true)
                item['manufacturer'],
              if ((item['package_type'] as String?)?.isNotEmpty == true)
                item['package_type'],
              if ((item['location_name'] as String?)?.isNotEmpty == true)
                item['location_name'],
              if (_formatComponentPrice(item['price']).isNotEmpty)
                'Price: ${_formatComponentPrice(item['price'])}',
              if ((item['description'] as String?)?.isNotEmpty == true)
                item['description'],
            ].join(' • '),
          ),
          trailing: SizedBox(
            height: 56,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ComponentStockBadge(item: item),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ComponentDetailModal.show(
                    context,
                    item,
                    api: api,
                    buildImage: buildImage,
                    onShowComponentImage: onShowComponentImage,
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'View component details',
                ),
                if (enableEditComponent) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => EditComponentModal.show(
                      context,
                      item,
                      api: api,
                      componentTypes: componentTypes,
                      locations: locations,
                      suppliers: suppliers,
                      canCaptureImage: canCaptureImage,
                      onRefresh: onRefresh,
                      onError: onError,
                      onPickImage: onPickImage,
                      onCaptureImage: onCaptureImage,
                      onPickDatasheet: onPickDatasheet,
                      onUploadImage: onUploadImage,
                      onUploadDatasheet: onUploadDatasheet,
                      onAddSupplier: onAddSupplier,
                      buildImage: buildImage,
                      onShowComponentImage: onShowComponentImage,
                    ),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit component',
                  ),
                  if (item['can_delete'] == true)
                    IconButton(
                      onPressed: () => onDeleteComponent(item),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete component',
                      color: Theme.of(context).colorScheme.error,
                    ),
                ],
              ],
            ),
          ),
          onTap: () => onOpenComponentInStock(item),
        );
      }, childCount: itemCount),
    );
  }

  Widget _componentThumbnailSliverGrid(BuildContext context, List<Map<String, dynamic>> visibleComponents) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.crossAxisExtent < 620 ? 160.0 : 190.0;
        final columns = (constraints.crossAxisExtent / cardWidth).floor().clamp(
          1,
          6,
        );
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.74,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _componentThumbnailCard(context, visibleComponents[index]),
            childCount: visibleComponents.length,
          ),
        );
      },
    );
  }

  String _componentTypeLocationLabel(Map<String, dynamic> item) {
    final type = (item['package_type'] as String?)?.trim() ?? '';
    final location = (item['location_name'] as String?)?.trim() ?? '';
    final price = _formatComponentPrice(item['price']);
    final parts = <String>[];
    if (type.isNotEmpty) parts.add(type);
    if (location.isNotEmpty) parts.add('($location)');
    if (price.isNotEmpty) parts.add('Price: $price');
    return parts.join(' ');
  }

  Widget _componentThumbnailCard(BuildContext context, Map<String, dynamic> item) {
    final borderRadius = BorderRadius.circular(8);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenComponentInStock(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: buildCardImage(item)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (item['datasheet_url'] != null ||
                          (item['datasheet_text'] as String?)?.isNotEmpty ==
                              true) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Datasheet available',
                          child: Icon(
                            Icons.description_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _componentTypeLocationLabel(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (item['expiry_date'] != null &&
                      '${item['expiry_date']}'.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    buildExpiryBadge('${item['expiry_date']}') ??
                        const SizedBox.shrink(),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ComponentStockBadge(item: item, compact: true),
                        ),
                      ),
                      IconButton(
                        constraints: const BoxConstraints.tightFor(width: 32),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => ComponentDetailModal.show(
                          context,
                          item,
                          api: api,
                          buildImage: buildImage,
                          onShowComponentImage: onShowComponentImage,
                        ),
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: 'View component details',
                      ),
                      if (enableEditComponent)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 32),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => EditComponentModal.show(
                            context,
                            item,
                            api: api,
                            componentTypes: componentTypes,
                            locations: locations,
                            suppliers: suppliers,
                            canCaptureImage: canCaptureImage,
                            onRefresh: onRefresh,
                            onError: onError,
                            onPickImage: onPickImage,
                            onCaptureImage: onCaptureImage,
                            onPickDatasheet: onPickDatasheet,
                            onUploadImage: onUploadImage,
                            onUploadDatasheet: onUploadDatasheet,
                            onAddSupplier: onAddSupplier,
                            buildImage: buildImage,
                            onShowComponentImage: onShowComponentImage,
                          ),
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit component',
                        ),
                      if (enableEditComponent && item['can_delete'] == true)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(width: 32),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onDeleteComponent(item),
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          tooltip: 'Delete component',
                        ),
                    ],
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
"""

with open("create_components_page_1.py", "w", encoding="utf-8") as f:
    f.write("with open('lib/features/inventory/pages/components_page.dart', 'w', encoding='utf-8') as out:\n")
    f.write("    out.write('''" + file_content + "''')\n")

