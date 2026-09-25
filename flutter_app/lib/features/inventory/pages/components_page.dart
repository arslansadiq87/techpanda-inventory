import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../inventory_home.dart'
    show ComponentImageSelection, ComponentDatasheetSelection, componentUnits;
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
      .replaceFirst(RegExp(r'\.$'), '');
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
  final List<dynamic> categories;
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
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;

  final ValueChanged<String?> onFilterComponentTypeChanged;
  final ValueChanged<String?> onFilterLocationIdChanged;
  final ValueChanged<String?> onFilterUnitChanged;
  final ValueChanged<String> onFilterStockStatusChanged;
  final VoidCallback onToggleMobileFilters;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;

  final ValueChanged<Map<String, dynamic>> onOpenComponentInStock;
  final ValueChanged<Map<String, dynamic>> onDeleteComponent;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(
    String componentId,
    ComponentImageSelection? image,
  )
  onUploadImage;
  final Future<void> Function(
    String componentId,
    ComponentDatasheetSelection? datasheet,
  )
  onUploadDatasheet;

  final Widget Function(Map<String, dynamic>, {required double size})
  buildThumbnail;
  final Widget Function(Map<String, dynamic>) buildCardImage;
  final Widget Function(
    String, {
    double? width,
    double? height,
    BoxFit? fit,
    required Widget errorChild,
  })
  buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;

  final Future<void> Function() onAddComponentType;
  final Future<void> Function() onEditComponentTypes;
  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;
  final Future<void> Function() onEditSuppliers;

  const ComponentsPage({
    super.key,
    required this.api,
    required this.components,
    required this.categories,
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
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
    required this.onFilterComponentTypeChanged,
    required this.onFilterLocationIdChanged,
    required this.onFilterUnitChanged,
    required this.onFilterStockStatusChanged,
    required this.onToggleMobileFilters,
    this.onSearchChanged,
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
    required this.onEditSuppliers,
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
        final current =
            double.tryParse('${component['current_quantity']}') ?? 0;
        final minimum =
            double.tryParse('${component['minimum_quantity']}') ?? 0;
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
              categories: categories,
              componentTypes: componentTypes,
              locations: locations,
              suppliers: suppliers,
              canCaptureImage: canCaptureImage,
              showComponentSupplier: showComponentSupplier,
              showComponentPrice: showComponentPrice,
              showComponentExpiryDate: showComponentExpiryDate,
              showComponentDatasheetFile: showComponentDatasheetFile,
              showComponentDatasheetText: showComponentDatasheetText,
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
              onEditSuppliers: onEditSuppliers,
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
      onChanged: onSearchChanged,
    );
  }

  Widget _mobileComponentFilterButton() {
    return IconButton(
      onPressed: onToggleMobileFilters,
      icon: Icon(showMobileFilters ? Icons.filter_alt_off : Icons.filter_list),
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
                  onChanged: (value) =>
                      onFilterStockStatusChanged(value ?? 'All'),
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

  Widget _componentSliverList(
    BuildContext context,
    List<Map<String, dynamic>> visibleComponents,
  ) {
    final itemCount = visibleComponents.isEmpty
        ? 0
        : visibleComponents.length * 2 - 1;
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
                    showComponentSupplier: showComponentSupplier,
                    showComponentPrice: showComponentPrice,
                    showComponentExpiryDate: showComponentExpiryDate,
                    showComponentDatasheetFile: showComponentDatasheetFile,
                    showComponentDatasheetText: showComponentDatasheetText,
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
                      showComponentSupplier: showComponentSupplier,
                      showComponentPrice: showComponentPrice,
                      showComponentExpiryDate: showComponentExpiryDate,
                      showComponentDatasheetFile: showComponentDatasheetFile,
                      showComponentDatasheetText: showComponentDatasheetText,
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

  Widget _componentThumbnailSliverGrid(
    BuildContext context,
    List<Map<String, dynamic>> visibleComponents,
  ) {
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
            (context, index) =>
                _componentThumbnailCard(context, visibleComponents[index]),
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

  Widget _componentThumbnailCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
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
                          showComponentSupplier: showComponentSupplier,
                          showComponentPrice: showComponentPrice,
                          showComponentExpiryDate: showComponentExpiryDate,
                          showComponentDatasheetFile:
                              showComponentDatasheetFile,
                          showComponentDatasheetText:
                              showComponentDatasheetText,
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
                            showComponentSupplier: showComponentSupplier,
                            showComponentPrice: showComponentPrice,
                            showComponentExpiryDate: showComponentExpiryDate,
                            showComponentDatasheetFile:
                                showComponentDatasheetFile,
                            showComponentDatasheetText:
                                showComponentDatasheetText,
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

class AddComponentPanel extends StatefulWidget {
  final ApiClient api;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;

  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;
  final VoidCallback? onCreated;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(
    String componentId,
    ComponentImageSelection? image,
  )
  onUploadImage;
  final Future<void> Function(
    String componentId,
    ComponentDatasheetSelection? datasheet,
  )
  onUploadDatasheet;

  final Future<void> Function() onAddComponentType;
  final Future<void> Function() onEditComponentTypes;
  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;
  final Future<void> Function() onEditSuppliers;

  const AddComponentPanel({
    super.key,
    required this.api,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.canCaptureImage,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
    required this.onRefresh,
    required this.onError,
    this.onCreated,
    required this.onPickImage,
    required this.onCaptureImage,
    required this.onPickDatasheet,
    required this.onUploadImage,
    required this.onUploadDatasheet,
    required this.onAddComponentType,
    required this.onEditComponentTypes,
    required this.onAddLocation,
    required this.onEditLocations,
    required this.onAddSupplier,
    required this.onEditSuppliers,
  });

  @override
  State<AddComponentPanel> createState() => _AddComponentPanelState();
}

class _AddComponentPanelState extends State<AddComponentPanel> {
  final TextEditingController _componentName = TextEditingController();
  final TextEditingController _componentManufacturer = TextEditingController();
  final TextEditingController _openingQuantity = TextEditingController();
  final TextEditingController _minimumQuantity = TextEditingController();
  final TextEditingController _componentPrice = TextEditingController();
  final TextEditingController _componentDetails = TextEditingController();
  final TextEditingController _componentDatasheetText = TextEditingController();
  final TextEditingController _componentExpiryDate = TextEditingController();

  String? _componentType;
  String _componentUnit = 'Pieces';
  String? _componentLocationId;
  String? _componentSupplierId;
  ComponentImageSelection? _componentImage;
  ComponentDatasheetSelection? _componentDatasheet;

  @override
  void initState() {
    super.initState();
    _openingQuantity.text = '0';
    _minimumQuantity.text = '0';
    if (widget.componentTypes.isNotEmpty) {
      _componentType = widget.componentTypes.first['name'] as String;
    }
  }

  @override
  void didUpdateWidget(covariant AddComponentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_componentType == null && widget.componentTypes.isNotEmpty) {
      _componentType = widget.componentTypes.first['name'] as String;
    } else if (_componentType != null &&
        widget.componentTypes.isNotEmpty &&
        !widget.componentTypes.any((t) => t['name'] == _componentType)) {
      _componentType = widget.componentTypes.first['name'] as String;
    }
  }

  @override
  void dispose() {
    _componentName.dispose();
    _componentManufacturer.dispose();
    _openingQuantity.dispose();
    _minimumQuantity.dispose();
    _componentPrice.dispose();
    _componentDetails.dispose();
    _componentDatasheetText.dispose();
    _componentExpiryDate.dispose();
    super.dispose();
  }

  String _categoryMatchKey(String typeName) {
    return typeName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _categoryIdForComponentType() {
    if (widget.categories.isEmpty) return null;
    final typeKey = _categoryMatchKey(_componentType ?? '');
    final aliases = {
      'resistor': 'resistors',
      'capacitor': 'capacitors',
      'sensor': 'sensors',
      'connector': 'connectors',
      'tool': 'tools/equipment',
      'equipment': 'tools/equipment',
      'ic': 'integrated circuits (ics)',
      'integratedcircuit': 'integrated circuits (ics)',
      'microcontroller': 'microcontrollers (mcus)',
      'mcu': 'microcontrollers (mcus)',
      'display': 'displays',
      'led': 'leds',
      'switch': 'switches/buttons',
      'button': 'switches/buttons',
    };
    final searchKeys = [
      typeKey,
      if (aliases.containsKey(typeKey)) aliases[typeKey]!,
      if (!typeKey.endsWith('s')) '${typeKey}s',
    ];
    final categoryMatch = widget.categories
        .cast<Map<String, dynamic>>()
        .firstWhere((cat) {
          final catKey = _categoryMatchKey(cat['name'] as String);
          return searchKeys.contains(catKey) || searchKeys.any(catKey.contains);
        }, orElse: () => widget.categories.first);
    return categoryMatch['id'] as String;
  }

  Future<bool> _createComponent() async {
    final categoryId = _categoryIdForComponentType();
    if (categoryId == null || _componentName.text.trim().isEmpty) return false;
    try {
      final created = await widget.api.createComponent({
        'name': _componentName.text.trim(),
        'category_id': categoryId,
        'opening_quantity': _openingQuantity.text.trim().isEmpty
            ? '0'
            : _openingQuantity.text.trim(),
        'minimum_quantity': _minimumQuantity.text.trim().isEmpty
            ? '0'
            : _minimumQuantity.text.trim(),
        'unit': _componentUnit,
        'location_id': _componentLocationId,
        'price': _componentPrice.text.trim().isEmpty
            ? null
            : _componentPrice.text.trim(),
        'manufacturer': _componentManufacturer.text.trim().isEmpty
            ? null
            : _componentManufacturer.text.trim(),
        'package_type': _componentType,
        'description': _componentDetails.text.trim().isEmpty
            ? null
            : _componentDetails.text.trim(),
        'datasheet_text': _componentDatasheetText.text.trim().isEmpty
            ? null
            : _componentDatasheetText.text.trim(),
        'supplier_id': _componentSupplierId,
        'expiry_date': _componentExpiryDate.text.trim().isEmpty
            ? null
            : _componentExpiryDate.text.trim(),
      });
      await widget.onUploadImage(created['id'] as String, _componentImage);
      await widget.onUploadDatasheet(
        created['id'] as String,
        _componentDatasheet,
      );
      _componentName.clear();
      _componentPrice.clear();
      _componentDetails.clear();
      _componentManufacturer.clear();
      _componentDatasheetText.clear();
      _componentExpiryDate.clear();
      setState(() {
        _componentImage = null;
        _componentDatasheet = null;
        _componentUnit = 'Pieces';
        _componentLocationId = null;
        _openingQuantity.text = '0';
        _minimumQuantity.text = '0';
      });
      await widget.onRefresh();
      return true;
    } catch (error) {
      widget.onError(error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('ApiException: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double width(double target) =>
              constraints.maxWidth < target ? constraints.maxWidth : target;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: width(220),
                    child: Text(
                      'Add component',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onAddComponentType,
                    icon: const Icon(Icons.add),
                    label: const Text('Type'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onEditComponentTypes,
                    icon: const Icon(Icons.tune),
                    label: const Text('Types'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onAddLocation,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Location'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onEditLocations,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Locations'),
                  ),
                  if (widget.showComponentSupplier) ...[
                    OutlinedButton.icon(
                      onPressed: widget.onAddSupplier,
                      icon: const Icon(Icons.domain_add),
                      label: const Text('Supplier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onEditSuppliers,
                      icon: const Icon(Icons.business),
                      label: const Text('Suppliers'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width(280),
                    child: TextField(
                      controller: _componentName,
                      decoration: const InputDecoration(
                        labelText: 'Component name',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width(230),
                    child: TextField(
                      controller: _componentManufacturer,
                      decoration: const InputDecoration(
                        labelText: 'Manufacturer (optional)',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width(220),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _componentType,
                      decoration: const InputDecoration(
                        labelText: 'Component type',
                      ),
                      items: widget.componentTypes
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['name'] as String,
                              child: Text(_componentTypeDisplayName(item)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _componentType = value),
                    ),
                  ),
                  SizedBox(
                    width: width(240),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _componentLocationId,
                      decoration: const InputDecoration(labelText: 'Location'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No location'),
                        ),
                        ...widget.locations.map(
                          (item) => DropdownMenuItem<String>(
                            value: item['id'] as String,
                            child: Text(item['display_name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _componentLocationId = value),
                    ),
                  ),
                  if (widget.showComponentSupplier)
                    SizedBox(
                      width: width(250),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _componentSupplierId,
                              decoration: const InputDecoration(
                                labelText: 'Supplier (optional)',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('No supplier'),
                                ),
                                ...widget.suppliers.map(
                                  (item) => DropdownMenuItem<String?>(
                                    value: item['id'] as String,
                                    child: Text(item['name'] as String),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _componentSupplierId = value),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 20,
                            ),
                            tooltip: 'Add new supplier',
                            onPressed: widget.onAddSupplier,
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: width(320),
                    child: TextField(
                      controller: _componentDetails,
                      decoration: const InputDecoration(
                        labelText: 'Details, usage, or specs',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: width(170),
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _componentUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: componentUnits
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _componentUnit = value ?? 'Pieces'),
                    ),
                  ),
                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _openingQuantity,
                      decoration: const InputDecoration(labelText: 'Opening'),
                    ),
                  ),
                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _minimumQuantity,
                      decoration: const InputDecoration(labelText: 'Minimum'),
                    ),
                  ),
                  if (widget.showComponentPrice)
                    SizedBox(
                      width: width(140),
                      child: TextField(
                        controller: _componentPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Price (optional)',
                        ),
                      ),
                    ),
                  if (widget.showComponentExpiryDate)
                    SizedBox(
                      width: width(160),
                      child: TextField(
                        controller: _componentExpiryDate,
                        readOnly: true,
                        onTap: () async {
                          await _selectExpiryDate(
                            context,
                            _componentExpiryDate,
                          );
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Expiry date (optional)',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            size: 18,
                          ),
                          suffixIcon: _componentExpiryDate.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () => setState(
                                    () => _componentExpiryDate.clear(),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickImage();
                      if (picked != null) {
                        setState(() => _componentImage = picked);
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Choose image'),
                  ),
                  if (widget.canCaptureImage)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final captured = await widget.onCaptureImage();
                        if (captured != null) {
                          setState(() => _componentImage = captured);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture image'),
                    ),
                  if (_componentImage != null)
                    SizedBox(
                      width: width(220),
                      child: Text(
                        _componentImage!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (widget.showComponentDatasheetFile)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final picked = await widget.onPickDatasheet();
                        if (picked != null) {
                          setState(() => _componentDatasheet = picked);
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        _componentDatasheet != null
                            ? 'Change datasheet'
                            : 'Choose datasheet',
                      ),
                    ),
                  if (_componentDatasheet != null) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width(180)),
                      child: Text(
                        _componentDatasheet!.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      tooltip: 'Clear datasheet file',
                      onPressed: () =>
                          setState(() => _componentDatasheet = null),
                    ),
                  ],
                ],
              ),
              if (widget.showComponentDatasheetText) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _componentDatasheetText,
                  decoration: const InputDecoration(
                    labelText:
                        'Datasheet copy-paste / technical specifications (optional)',
                    hintText:
                        'Paste pinouts, ratings, specs, or datasheet notes here',
                  ),
                  minLines: 2,
                  maxLines: 5,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () async {
                    if (await _createComponent()) {
                      widget.onCreated?.call();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add component'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;
  final Widget Function(
    String, {
    double? width,
    double? height,
    BoxFit? fit,
    required Widget errorChild,
  })
  buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;
  final Map<String, dynamic> component;

  const ComponentDetailModal({
    super.key,
    required this.api,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
    required this.buildImage,
    required this.onShowComponentImage,
    required this.component,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required Widget Function(
      String, {
      double? width,
      double? height,
      BoxFit? fit,
      required Widget errorChild,
    })
    buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ComponentDetailModal(
        api: api,
        showComponentSupplier: showComponentSupplier,
        showComponentPrice: showComponentPrice,
        showComponentExpiryDate: showComponentExpiryDate,
        showComponentDatasheetFile: showComponentDatasheetFile,
        showComponentDatasheetText: showComponentDatasheetText,
        buildImage: buildImage,
        onShowComponentImage: onShowComponentImage,
        component: component,
      ),
    );
  }

  Widget _componentDetailRow(
    BuildContext context,
    String label,
    Object? value,
  ) {
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
              _componentDetailRow(
                context,
                'Inventory code',
                component['inventory_code'],
              ),
              _componentDetailRow(context, 'Type', component['package_type']),
              _componentDetailRow(
                context,
                'Manufacturer',
                component['manufacturer'],
              ),
              _componentDetailRow(
                context,
                'Model number',
                component['model_number'],
              ),
              _componentDetailRow(
                context,
                'Part number',
                component['part_number'],
              ),
              _componentDetailRow(
                context,
                'Location',
                component['location_name'],
              ),
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
              if (component['price'] != null &&
                  '${component['price']}'.trim().isNotEmpty)
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
                          child: buildExpiryBadge(
                            '${component['expiry_date']}',
                          ),
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
                    launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.35),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
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
                              Clipboard.setData(
                                ClipboardData(
                                  text: '${component['datasheet_text']}',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Datasheet text copied to clipboard!',
                                  ),
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
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
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

class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;

  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(
    String componentId,
    ComponentImageSelection? image,
  )
  onUploadImage;
  final Future<void> Function(
    String componentId,
    ComponentDatasheetSelection? datasheet,
  )
  onUploadDatasheet;
  final Future<void> Function() onAddSupplier;

  final Widget Function(
    String, {
    double? width,
    double? height,
    BoxFit? fit,
    required Widget errorChild,
  })
  buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;

  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.canCaptureImage,
    required this.onRefresh,
    required this.onError,
    required this.onPickImage,
    required this.onCaptureImage,
    required this.onPickDatasheet,
    required this.onUploadImage,
    required this.onUploadDatasheet,
    required this.onAddSupplier,
    required this.buildImage,
    required this.onShowComponentImage,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required List<dynamic> componentTypes,
    required List<dynamic> locations,
    required List<dynamic> suppliers,
    required bool canCaptureImage,
    required Future<void> Function() onRefresh,
    required ValueChanged<String> onError,
    required Future<ComponentImageSelection?> Function() onPickImage,
    required Future<ComponentImageSelection?> Function() onCaptureImage,
    required Future<ComponentDatasheetSelection?> Function() onPickDatasheet,
    required Future<void> Function(
      String componentId,
      ComponentImageSelection? image,
    )
    onUploadImage,
    required Future<void> Function(
      String componentId,
      ComponentDatasheetSelection? datasheet,
    )
    onUploadDatasheet,
    required Future<void> Function() onAddSupplier,
    required Widget Function(
      String, {
      double? width,
      double? height,
      BoxFit? fit,
      required Widget errorChild,
    })
    buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => EditComponentModal(
        component: component,
        api: api,
        showComponentSupplier: showComponentSupplier,
        showComponentPrice: showComponentPrice,
        showComponentExpiryDate: showComponentExpiryDate,
        showComponentDatasheetFile: showComponentDatasheetFile,
        showComponentDatasheetText: showComponentDatasheetText,
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
    );
  }

  @override
  State<EditComponentModal> createState() => _EditComponentModalState();
}

class _EditComponentModalState extends State<EditComponentModal> {
  late final TextEditingController name;
  late final TextEditingController manufacturer;
  late final TextEditingController details;
  late final TextEditingController price;
  late final TextEditingController datasheetText;
  late final TextEditingController expiryDate;

  String? type;
  String unit = 'Pieces';
  String? locationId;
  String? supplierId;
  ComponentImageSelection? image;
  ComponentDatasheetSelection? newDatasheet;
  bool removeExistingDatasheet = false;

  @override
  void initState() {
    super.initState();
    final component = widget.component;
    name = TextEditingController(text: component['name'] as String? ?? '');
    manufacturer = TextEditingController(
      text: component['manufacturer'] as String? ?? '',
    );
    details = TextEditingController(
      text: component['description'] as String? ?? '',
    );
    price = TextEditingController(
      text: _formatComponentPrice(component['price']),
    );
    datasheetText = TextEditingController(
      text: component['datasheet_text'] as String? ?? '',
    );
    expiryDate = TextEditingController(
      text: component['expiry_date'] as String? ?? '',
    );

    type = component['package_type'] as String?;
    final typeNames = widget.componentTypes
        .map((item) => item['name'] as String)
        .toList();
    if (type != null && !typeNames.contains(type)) {
      type = typeNames.isNotEmpty ? typeNames.first : null;
    }
    unit = component['unit'] as String? ?? 'Pieces';
    if (!componentUnits.contains(unit)) unit = 'Other';
    locationId = component['location_id'] as String?;
    supplierId = component['supplier_id'] as String?;
  }

  @override
  void dispose() {
    name.dispose();
    manufacturer.dispose();
    price.dispose();
    details.dispose();
    datasheetText.dispose();
    expiryDate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final component = widget.component;
    try {
      await widget.api.updateComponent(component['id'] as String, {
        'name': name.text.trim(),
        'manufacturer': manufacturer.text.trim().isEmpty
            ? null
            : manufacturer.text.trim(),
        'package_type': type,
        'unit': unit,
        'location_id': locationId,
        'price': price.text.trim().isEmpty ? null : price.text.trim(),
        'description': details.text.trim().isEmpty ? null : details.text.trim(),
        'datasheet_text': datasheetText.text.trim().isEmpty
            ? null
            : datasheetText.text.trim(),
        'expiry_date': expiryDate.text.trim().isEmpty
            ? null
            : expiryDate.text.trim(),
      });
      if (removeExistingDatasheet) {
        await widget.api.deleteComponentDatasheet(component['id'] as String);
      }
      if (newDatasheet != null) {
        await widget.onUploadDatasheet(component['id'] as String, newDatasheet);
      }
      await widget.onUploadImage(component['id'] as String, image);
      await widget.onRefresh();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      widget.onError(error.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('ApiException: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final component = widget.component;
    final existingDatasheetUrl = component['datasheet_url'] as String?;
    final thumbnail = component['primary_image_thumbnail'] as String?;

    return AlertDialog(
      title: const Text('Edit component'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (thumbnail != null) ...[
                InkWell(
                  onTap: () => widget.onShowComponentImage(component),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.buildImage(
                      thumbnail,
                      height: 96,
                      width: 96,
                      fit: BoxFit.cover,
                      errorChild: const SizedBox(
                        height: 96,
                        width: 96,
                        child: Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickImage();
                      if (picked != null) {
                        setState(() => image = picked);
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Choose image'),
                  ),
                  if (widget.canCaptureImage)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final captured = await widget.onCaptureImage();
                        if (captured != null) {
                          setState(() => image = captured);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture image'),
                    ),
                  if (image != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(image!.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Component name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manufacturer,
                decoration: const InputDecoration(
                  labelText: 'Manufacturer (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Component type'),
                items: [
                  if (type != null &&
                      !widget.componentTypes.any(
                        (item) => item['name'] == type,
                      ))
                    DropdownMenuItem<String>(value: type, child: Text(type!)),
                  ...widget.componentTypes.map(
                    (item) => DropdownMenuItem<String>(
                      value: item['name'] as String,
                      child: Text(_componentTypeDisplayName(item)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => type = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: locationId,
                decoration: const InputDecoration(labelText: 'Location'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No location'),
                  ),
                  ...widget.locations.map(
                    (item) => DropdownMenuItem<String>(
                      value: item['id'] as String,
                      child: Text(item['display_name'] as String),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => locationId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: componentUnits
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => unit = value ?? 'Pieces'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryDate,
                readOnly: true,
                onTap: () async {
                  await _selectExpiryDate(context, expiryDate);
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Expiry date (optional)',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: const Icon(Icons.calendar_today, size: 20),
                  suffixIcon: expiryDate.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            expiryDate.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.showComponentDatasheetFile)
                Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datasheet document (optional)',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    if (existingDatasheetUrl != null &&
                        !removeExistingDatasheet &&
                        newDatasheet == null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.description,
                            size: 18,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Datasheet attached',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => removeExistingDatasheet = true),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final picked = await widget.onPickDatasheet();
                            if (picked != null) {
                              setState(() {
                                newDatasheet = picked;
                                removeExistingDatasheet = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            newDatasheet != null
                                ? 'Change file'
                                : 'Upload datasheet (PDF/DOC)',
                          ),
                        ),
                        if (newDatasheet != null) ...[
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              newDatasheet!.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            tooltip: 'Cancel selected file',
                            onPressed: () =>
                                setState(() => newDatasheet = null),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.showComponentDatasheetText) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: datasheetText,
                  decoration: const InputDecoration(
                    labelText: 'Datasheet copy-paste / specs (optional)',
                    hintText:
                        'Paste pinouts, ratings, specs, or datasheet notes here',
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
              ],
              if (widget.showComponentSupplier) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: supplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No supplier'),
                          ),
                          ...widget.suppliers.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item['id'] as String,
                              child: Text(item['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(() => supplierId = val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      tooltip: 'Add new supplier',
                      onPressed: () async {
                        await widget.onAddSupplier();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: details,
                decoration: const InputDecoration(
                  labelText: 'Details, usage, or technical specs',
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
