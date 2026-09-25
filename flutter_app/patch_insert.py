import sys

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def insert_after(target_str, insert_str):
    global content
    count = content.count(target_str)
    if count != 1:
        print(f"Error: Found {count} occurrences of\n{target_str}")
        sys.exit(1)
    content = content.replace(target_str, target_str + "\n" + insert_str)

def replace_exact(old_str, new_str):
    global content
    count = content.count(old_str)
    if count != 1:
        print(f"Error: Found {count} occurrences of\n{old_str}")
        sys.exit(1)
    content = content.replace(old_str, new_str)

fields_decl = """  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;"""

fields_req = """    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,"""

fields_pass = """              showComponentSupplier: showComponentSupplier,
              showComponentPrice: showComponentPrice,
              showComponentExpiryDate: showComponentExpiryDate,
              showComponentDatasheetFile: showComponentDatasheetFile,
              showComponentDatasheetText: showComponentDatasheetText,"""

fields_pass_modals = """          showComponentSupplier: showComponentSupplier,
          showComponentPrice: showComponentPrice,
          showComponentExpiryDate: showComponentExpiryDate,
          showComponentDatasheetFile: showComponentDatasheetFile,
          showComponentDatasheetText: showComponentDatasheetText,"""

# 1. ComponentsPage
insert_after("  final bool canCaptureImage;", fields_decl)
insert_after("    required this.canCaptureImage,", fields_req)

# 2. AddComponentPanel invocation
insert_after("              canCaptureImage: canCaptureImage,", fields_pass)

# 3. AddComponentPanel
insert_after("  final bool canCaptureImage;", fields_decl)
insert_after("    required this.canCaptureImage,", fields_req)

# 4. ComponentDetailModal
cdm_decl = """class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;"""
insert_after(cdm_decl, fields_decl)

cdm_req = """  const ComponentDetailModal({
    super.key,
    required this.api,"""
insert_after(cdm_req, fields_req)

cdm_show_decl = """  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,"""
insert_after(cdm_show_decl, fields_req.replace('this.', 'bool '))

cdm_show_pass = """        builder: (context) => ComponentDetailModal(
          api: api,"""
insert_after(cdm_show_pass, fields_pass_modals)

# 5. EditComponentModal
ecm_decl = """class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;"""
insert_after(ecm_decl, fields_decl)

ecm_req = """  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,"""
insert_after(ecm_req, fields_req)

ecm_show_decl = """  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,"""
insert_after(ecm_show_decl, fields_req.replace('this.', 'bool '))

ecm_show_pass = """        builder: (context) => EditComponentModal(
          component: component,
          api: api,"""
insert_after(ecm_show_pass, fields_pass_modals)

# 6. Pass into modals
cm_pass_list = """                    api: api,"""
insert_after(cm_pass_list, fields_pass_modals.replace('          ', '                    '))

cm_pass_grid = """                          api: api,"""
insert_after(cm_pass_grid, fields_pass_modals.replace('          ', '                          '))

ecm_pass_list = """                      api: api,"""
insert_after(ecm_pass_list, fields_pass_modals.replace('          ', '                      '))


# 7. AddComponentPanel UI Toggles

# Price
replace_exact("""                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,""", 
"""                  if (widget.showComponentPrice) SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,""")

# Expiry
replace_exact("""                  SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,""",
"""                  if (widget.showComponentExpiryDate) SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,""")

# File upload
replace_exact("""                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();""",
"""                  if (widget.showComponentDatasheetFile) FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();""")

replace_exact("""                  if (_componentDatasheet != null) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width(180)),""",
"""                  if (widget.showComponentDatasheetFile && _componentDatasheet != null) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width(180)),""")

# Datasheet Text
replace_exact("""              TextField(
                controller: _componentDatasheetText,""",
"""              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,""")

# Supplier
replace_exact("""                  SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(""",
"""                  if (widget.showComponentSupplier) SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(""")

# 8. EditComponentModal UI Toggles
# Price
replace_exact("""              const SizedBox(height: 12),
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
              ],""")

# Expiry
replace_exact("""              const SizedBox(height: 12),
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
              ],""")

# File
replace_exact("""              const SizedBox(height: 12),
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
                          const Icon(Icons.description,
                              size: 18, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Datasheet attached',
                                style: TextStyle(fontSize: 13)),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => removeExistingDatasheet = true),
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                            label: const Text('Remove',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12)),
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
                          label: Text(newDatasheet != null
                              ? 'Change file'
                              : 'Upload datasheet (PDF/DOC)'),
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
                      if (existingDatasheetUrl != null &&
                          !removeExistingDatasheet &&
                          newDatasheet == null) ...[
                        Row(
                          children: [
                            const Icon(Icons.description,
                                size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text('Datasheet attached',
                                  style: TextStyle(fontSize: 13)),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => removeExistingDatasheet = true),
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.red),
                              label: const Text('Remove',
                                  style:
                                      TextStyle(color: Colors.red, fontSize: 12)),
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
                            label: Text(newDatasheet != null
                                ? 'Change file'
                                : 'Upload datasheet (PDF/DOC)'),
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
              ],""")

# Text
replace_exact("""              const SizedBox(height: 12),
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
              ],""")


# Supplier
replace_exact("""              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: supplierId,
                      decoration: const InputDecoration(
                          labelText: 'Supplier (optional)'),
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
                        decoration: const InputDecoration(
                            labelText: 'Supplier (optional)'),
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
              ],""")


# 9. ComponentDetailModal Toggles
replace_exact("""                if (component['price'] != null &&
                    '${component['price']}'.trim().isNotEmpty)
                  _componentDetailRow(
                    context,
                    'Price',
                    _formatComponentPrice(component['price']),
                  ),""",
"""                if (showComponentPrice && component['price'] != null &&
                    '${component['price']}'.trim().isNotEmpty)
                  _componentDetailRow(
                    context,
                    'Price',
                    _formatComponentPrice(component['price']),
                  ),""")

replace_exact("""                if (component['expiry_date'] != null &&
                    '${component['expiry_date']}'.trim().isNotEmpty) ...[""",
"""                if (showComponentExpiryDate && component['expiry_date'] != null &&
                    '${component['expiry_date']}'.trim().isNotEmpty) ...[""")

replace_exact("""                if (component['datasheet_url'] != null &&
                    '${component['datasheet_url']}'.trim().isNotEmpty) ...[""",
"""                if (showComponentDatasheetFile && component['datasheet_url'] != null &&
                    '${component['datasheet_url']}'.trim().isNotEmpty) ...[""")

replace_exact("""                if (component['datasheet_text'] != null &&
                    '${component['datasheet_text']}'.trim().isNotEmpty) ...[""",
"""                if (showComponentDatasheetText && component['datasheet_text'] != null &&
                    '${component['datasheet_text']}'.trim().isNotEmpty) ...[""")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")

