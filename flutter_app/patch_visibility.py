import os

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add fields to ComponentsPage
fields_to_add = """  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;"""

required_args = """    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,"""

content = content.replace(
    "final bool canCaptureImage;",
    "final bool canCaptureImage;\n" + fields_to_add
)

content = content.replace(
    "required this.canCaptureImage,",
    "required this.canCaptureImage,\n" + required_args
)

# 2. Add fields to AddComponentPanel
content = content.replace(
    """class AddComponentPanel extends StatefulWidget {
  final ApiClient api;""",
    """class AddComponentPanel extends StatefulWidget {
  final ApiClient api;
""" + fields_to_add
)

content = content.replace(
    """const AddComponentPanel({
    super.key,
    required this.api,""",
    """const AddComponentPanel({
    super.key,
    required this.api,
""" + required_args
)

# 3. Add fields to ComponentDetailModal
content = content.replace(
    """class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;""",
    """class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;
""" + fields_to_add
)

content = content.replace(
    """const ComponentDetailModal({
    super.key,
    required this.api,""",
    """const ComponentDetailModal({
    super.key,
    required this.api,
""" + required_args
)

content = content.replace(
    """required ApiClient api,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,""",
    """required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,"""
)

content = content.replace(
    """api: api,
        buildImage: buildImage,""",
    """api: api,
        showComponentSupplier: showComponentSupplier,
        showComponentPrice: showComponentPrice,
        showComponentExpiryDate: showComponentExpiryDate,
        showComponentDatasheetFile: showComponentDatasheetFile,
        showComponentDatasheetText: showComponentDatasheetText,
        buildImage: buildImage,"""
)

# 4. Add fields to EditComponentModal
content = content.replace(
    """class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;""",
    """class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;
""" + fields_to_add
)

content = content.replace(
    """const EditComponentModal({
    super.key,
    required this.component,
    required this.api,""",
    """const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
""" + required_args
)

content = content.replace(
    """required ApiClient api,
    required List<dynamic> componentTypes,""",
    """required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required List<dynamic> componentTypes,"""
)

content = content.replace(
    """component: component,
        api: api,""",
    """component: component,
        api: api,
        showComponentSupplier: showComponentSupplier,
        showComponentPrice: showComponentPrice,
        showComponentExpiryDate: showComponentExpiryDate,
        showComponentDatasheetFile: showComponentDatasheetFile,
        showComponentDatasheetText: showComponentDatasheetText,"""
)

# 5. Pass fields in ComponentsPage build to children
extra_args = """                      showComponentSupplier: showComponentSupplier,
                      showComponentPrice: showComponentPrice,
                      showComponentExpiryDate: showComponentExpiryDate,
                      showComponentDatasheetFile: showComponentDatasheetFile,
                      showComponentDatasheetText: showComponentDatasheetText,
                      onShowComponentImage: onShowComponentImage,"""

content = content.replace("onShowComponentImage: onShowComponentImage,", extra_args)

# In ComponentsPage AddComponentPanel instantiation
add_panel_args = """              showComponentSupplier: showComponentSupplier,
              showComponentPrice: showComponentPrice,
              showComponentExpiryDate: showComponentExpiryDate,
              showComponentDatasheetFile: showComponentDatasheetFile,
              showComponentDatasheetText: showComponentDatasheetText,"""
content = content.replace(
    """onAddSupplier: onAddSupplier,
            ),""",
    """onAddSupplier: onAddSupplier,\n""" + add_panel_args + """\n            ),"""
)


# 6. Apply visibility logic in ComponentDetailModal
content = content.replace(
    """if (component['price'] != null && '${component['price']}'.trim().isNotEmpty)""",
    """if (showComponentPrice && component['price'] != null && '${component['price']}'.trim().isNotEmpty)"""
)
content = content.replace(
    """if (component['expiry_date'] != null &&
                  '${component['expiry_date']}'.trim().isNotEmpty) ...[""",
    """if (showComponentExpiryDate && component['expiry_date'] != null &&
                  '${component['expiry_date']}'.trim().isNotEmpty) ...["""
)
content = content.replace(
    """if (component['datasheet_url'] != null &&
                  '${component['datasheet_url']}'.trim().isNotEmpty) ...[""",
    """if (showComponentDatasheetFile && component['datasheet_url'] != null &&
                  '${component['datasheet_url']}'.trim().isNotEmpty) ...["""
)
content = content.replace(
    """if (component['datasheet_text'] != null &&
                  '${component['datasheet_text']}'.trim().isNotEmpty) ...[""",
    """if (showComponentDatasheetText && component['datasheet_text'] != null &&
                  '${component['datasheet_text']}'.trim().isNotEmpty) ...["""
)


# 7. Apply visibility logic in EditComponentModal
content = content.replace(
    """              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (optional)'),
              ),""",
    """              if (widget.showComponentPrice) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (optional)'),
                ),
              ],"""
)

content = content.replace(
    """              const SizedBox(height: 12),
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
              ),""",
    """              if (widget.showComponentExpiryDate) ...[
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
              ],"""
)

content = content.replace(
    """              const SizedBox(height: 12),
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
              ),""",
    """              if (widget.showComponentDatasheetFile) ...[
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
              ],"""
)

content = content.replace(
    """              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 3,
                maxLines: 6,
              ),""",
    """              if (widget.showComponentDatasheetText) ...[
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
              ],"""
)

content = content.replace(
    """              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: supplierId,
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
              ),""",
    """              if (widget.showComponentSupplier) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: supplierId,
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
              ],"""
)


# 8. Apply visibility logic in AddComponentPanel
content = content.replace(
    """                  SizedBox(
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
                  ),""",
    """                  if (widget.showComponentPrice) SizedBox(
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
                  ),"""
)

content = content.replace(
    """                  SizedBox(
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
                  ),""",
    """                  if (widget.showComponentExpiryDate) SizedBox(
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
                  ),"""
)

content = content.replace(
    """                  FilledButton.tonalIcon(
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
                  ),""",
    """                  if (widget.showComponentDatasheetFile) FilledButton.tonalIcon(
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
                  ),"""
)

content = content.replace(
    """                  if (_componentDatasheet != null) ...[""",
    """                  if (widget.showComponentDatasheetFile && _componentDatasheet != null) ...["""
)

content = content.replace(
    """              TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText:
                      'Datasheet copy-paste / technical specifications (optional)',
                  hintText:
                      'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),""",
    """              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText:
                      'Datasheet copy-paste / technical specifications (optional)',
                  hintText:
                      'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),"""
)

content = content.replace(
    """                  SizedBox(
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
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          tooltip: 'Add new supplier',
                          onPressed: widget.onAddSupplier,
                        ),
                      ],
                    ),
                  ),""",
    """                  if (widget.showComponentSupplier) SizedBox(
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
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          tooltip: 'Add new supplier',
                          onPressed: widget.onAddSupplier,
                        ),
                      ],
                    ),
                  ),"""
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

# Patch inventory_home.dart to pass the boolean fields
h_filepath = 'lib/features/inventory_home.dart'
with open(h_filepath, 'r', encoding='utf-8') as f:
    h_content = f.read()

h_args = """              showComponentSupplier: _showComponentSupplier,
              showComponentPrice: _showComponentPrice,
              showComponentExpiryDate: _showComponentExpiryDate,
              showComponentDatasheetFile: _showComponentDatasheetFile,
              showComponentDatasheetText: _showComponentDatasheetText,"""

if "showComponentSupplier: _showComponentSupplier," not in h_content.split("ComponentsPage(")[1]:
    h_content = h_content.replace(
        "enableEditComponent: _enableEditComponent,",
        "enableEditComponent: _enableEditComponent,\n" + h_args
    )

with open(h_filepath, 'w', encoding='utf-8') as f:
    f.write(h_content)


