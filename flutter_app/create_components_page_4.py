file_content4 = """
class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;

  final Future<void> Function() onRefresh;
  final ValueChanged<String> onError;

  final Future<ComponentImageSelection?> Function() onPickImage;
  final Future<ComponentImageSelection?> Function() onCaptureImage;
  final Future<ComponentDatasheetSelection?> Function() onPickDatasheet;
  final Future<void> Function(String componentId, ComponentImageSelection? image) onUploadImage;
  final Future<void> Function(String componentId, ComponentDatasheetSelection? datasheet) onUploadDatasheet;
  final Future<void> Function() onAddSupplier;

  final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;
  final void Function(Map<String, dynamic>) onShowComponentImage;

  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
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
    required List<dynamic> componentTypes,
    required List<dynamic> locations,
    required List<dynamic> suppliers,
    required bool canCaptureImage,
    required Future<void> Function() onRefresh,
    required ValueChanged<String> onError,
    required Future<ComponentImageSelection?> Function() onPickImage,
    required Future<ComponentImageSelection?> Function() onCaptureImage,
    required Future<ComponentDatasheetSelection?> Function() onPickDatasheet,
    required Future<void> Function(String componentId, ComponentImageSelection? image) onUploadImage,
    required Future<void> Function(String componentId, ComponentDatasheetSelection? datasheet) onUploadDatasheet,
    required Future<void> Function() onAddSupplier,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => EditComponentModal(
        component: component,
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
    manufacturer = TextEditingController(text: component['manufacturer'] as String? ?? '');
    details = TextEditingController(text: component['description'] as String? ?? '');
    price = TextEditingController(text: _formatComponentPrice(component['price']));
    datasheetText = TextEditingController(text: component['datasheet_text'] as String? ?? '');
    expiryDate = TextEditingController(text: component['expiry_date'] as String? ?? '');

    type = component['package_type'] as String?;
    final typeNames = widget.componentTypes.map((item) => item['name'] as String).toList();
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
        'manufacturer': manufacturer.text.trim().isEmpty ? null : manufacturer.text.trim(),
        'package_type': type,
        'unit': unit,
        'location_id': locationId,
        'price': price.text.trim().isEmpty ? null : price.text.trim(),
        'description': details.text.trim().isEmpty ? null : details.text.trim(),
        'datasheet_text': datasheetText.text.trim().isEmpty ? null : datasheetText.text.trim(),
        'expiry_date': expiryDate.text.trim().isEmpty ? null : expiryDate.text.trim(),
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
                      child: Text(
                        image!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                decoration: const InputDecoration(labelText: 'Manufacturer (optional)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Component type'),
                items: [
                  if (type != null && !widget.componentTypes.any((item) => item['name'] == type))
                    DropdownMenuItem<String>(
                      value: type,
                      child: Text(type!),
                    ),
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
                items: componentUnits.map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                ).toList(),
                onChanged: (value) => setState(() => unit = value ?? 'Pieces'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (optional)'),
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
                    if (existingDatasheetUrl != null && !removeExistingDatasheet && newDatasheet == null) ...[
                      Row(
                        children: [
                          const Icon(Icons.description, size: 18, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Datasheet attached', style: TextStyle(fontSize: 13)),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => removeExistingDatasheet = true),
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
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
                          label: Text(newDatasheet != null ? 'Change file' : 'Upload datasheet (PDF/DOC)'),
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
                            onPressed: () => setState(() => newDatasheet = null),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: supplierId,
                      decoration: const InputDecoration(labelText: 'Supplier (optional)'),
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
              const SizedBox(height: 12),
              TextField(
                controller: details,
                decoration: const InputDecoration(labelText: 'Details, usage, or technical specs'),
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
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
"""

with open("create_components_page_4.py", "w", encoding="utf-8") as f:
    f.write("with open('lib/features/inventory/pages/components_page.dart', 'a', encoding='utf-8') as out:\n")
    f.write("    out.write('''" + file_content4 + "''')\n")

