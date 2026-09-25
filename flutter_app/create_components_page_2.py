file_content2 = """
class AddComponentPanel extends StatefulWidget {
  final ApiClient api;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;

  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;
  final VoidCallback? onCreated;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(String componentId, ComponentImageSelection? image) onUploadImage;
  final Future<void> Function(String componentId, ComponentDatasheetSelection? datasheet) onUploadDatasheet;

  final Future<void> Function() onAddComponentType;
  final Future<void> Function() onEditComponentTypes;
  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;

  const AddComponentPanel({
    super.key,
    required this.api,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.canCaptureImage,
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
    final categoryMatch = widget.categories.cast<Map<String, dynamic>>().firstWhere(
      (cat) {
        final catKey = _categoryMatchKey(cat['name'] as String);
        return searchKeys.contains(catKey) || searchKeys.any(catKey.contains);
      },
      orElse: () => widget.categories.first,
    );
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
                      value: _componentType,
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
                      value: _componentLocationId,
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
                  SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _componentSupplierId,
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
                          icon: const Icon(Icons.add_circle_outline, size: 20),
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
                      value: _componentUnit,
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
                  SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,
                      readOnly: true,
                      onTap: () async {
                        await _selectExpiryDate(context, _componentExpiryDate);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Expiry date (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
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
"""

with open("create_components_page_2.py", "w", encoding="utf-8") as f:
    f.write("with open('lib/features/inventory/pages/components_page.dart', 'a', encoding='utf-8') as out:\n")
    f.write("    out.write('''" + file_content2 + "''')\n")

