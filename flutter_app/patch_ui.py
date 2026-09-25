import sys

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def replace_exact(old_str, new_str):
    global content
    if old_str not in content:
        print("ERROR: String not found!")
        print(repr(old_str[:100]))
        sys.exit(1)
    content = content.replace(old_str, new_str)

file_block_old = """                  FilledButton.tonalIcon(
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Cancel selected datasheet',
                      onPressed: () => setState(() => _componentDatasheet = null),
                    ),
                  ],"""

file_block_new = """                  if (widget.showComponentDatasheetFile) ...[
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Cancel selected datasheet',
                        onPressed: () => setState(() => _componentDatasheet = null),
                      ),
                    ],
                  ],"""

replace_exact(file_block_old, file_block_new)

text_block_old = """              TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),"""

text_block_new = """              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),"""

replace_exact(text_block_old, text_block_new)

supplier_block_old = """                  SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No supplier'),
                              ),
                              ...widget.suppliers.map((item) => DropdownMenuItem<String?>(
                                    value: item['id'] as String,
                                    child: Text(item['name'] as String),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
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

supplier_block_new = """                  if (widget.showComponentSupplier) SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            value: _selectedSupplierId,
                            decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No supplier'),
                              ),
                              ...widget.suppliers.map((item) => DropdownMenuItem<String?>(
                                    value: item['id'] as String,
                                    child: Text(item['name'] as String),
                                  )),
                            ],
                            onChanged: (val) => setState(() => _selectedSupplierId = val),
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
replace_exact(supplier_block_old, supplier_block_new)

# EditComponentModal
ed_price_old = """              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (optional)'),
              ),"""
ed_price_new = """              if (widget.showComponentPrice) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (optional)'),
                ),
              ],"""
replace_exact(ed_price_old, ed_price_new)

ed_exp_old = """              const SizedBox(height: 12),
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
              ),"""
ed_exp_new = """              if (widget.showComponentExpiryDate) ...[
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
replace_exact(ed_exp_old, ed_exp_new)

ed_file_old = """              const SizedBox(height: 12),
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
              ),"""
ed_file_new = """              if (widget.showComponentDatasheetFile) ...[
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
              ],"""
replace_exact(ed_file_old, ed_file_new)

ed_text_old = """              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 3,
                maxLines: 6,
              ),"""
ed_text_new = """              if (widget.showComponentDatasheetText) ...[
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
replace_exact(ed_text_old, ed_text_new)

ed_sup_old = """              const SizedBox(height: 12),
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
              ),"""
ed_sup_new = """              if (widget.showComponentSupplier) ...[
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
              ],"""
replace_exact(ed_sup_old, ed_sup_new)

# ComponentDetailModal
det_price_old = """                if (component['price'] != null &&
                    '${component['price']}'.trim().isNotEmpty)
                  _componentDetailRow(
                    context,
                    'Price',
                    _formatComponentPrice(component['price']),
                  ),"""
det_price_new = """                if (showComponentPrice && component['price'] != null &&
                    '${component['price']}'.trim().isNotEmpty)
                  _componentDetailRow(
                    context,
                    'Price',
                    _formatComponentPrice(component['price']),
                  ),"""
replace_exact(det_price_old, det_price_new)

det_exp_old = """                if (component['expiry_date'] != null &&
                    '${component['expiry_date']}'.trim().isNotEmpty) ...["""
det_exp_new = """                if (showComponentExpiryDate && component['expiry_date'] != null &&
                    '${component['expiry_date']}'.trim().isNotEmpty) ...["""
replace_exact(det_exp_old, det_exp_new)


det_file_old = """                if (component['datasheet_url'] != null &&
                    '${component['datasheet_url']}'.trim().isNotEmpty) ...["""
det_file_new = """                if (showComponentDatasheetFile && component['datasheet_url'] != null &&
                    '${component['datasheet_url']}'.trim().isNotEmpty) ...["""
replace_exact(det_file_old, det_file_new)

det_text_old = """                if (component['datasheet_text'] != null &&
                    '${component['datasheet_text']}'.trim().isNotEmpty) ...["""
det_text_new = """                if (showComponentDatasheetText && component['datasheet_text'] != null &&
                    '${component['datasheet_text']}'.trim().isNotEmpty) ...["""
replace_exact(det_text_old, det_text_new)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")

