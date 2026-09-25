import sys

def replace_exact(filepath, old, new):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    count = content.count(old)
    if count != 1:
        print(f"Error: Could not find exactly one match for\n{old}\nin {filepath}. Found {count}.")
        sys.exit(1)
    
    content = content.replace(old, new)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

cp_old_ed_price = """              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (optional)'),
              ),"""
cp_new_ed_price = """              if (widget.showComponentPrice) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price (optional)'),
                ),
              ],"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_ed_price, cp_new_ed_price)

cp_old_ed_exp = """              const SizedBox(height: 12),
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
cp_new_ed_exp = """              if (widget.showComponentExpiryDate) ...[
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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_ed_exp, cp_new_ed_exp)


cp_old_ed_file = """              const SizedBox(height: 12),
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
cp_new_ed_file = """              if (widget.showComponentDatasheetFile) ...[
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
# Let's verify string exactly
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_ed_file, cp_new_ed_file)

cp_old_ed_text = """              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 3,
                maxLines: 6,
              ),"""
cp_new_ed_text = """              if (widget.showComponentDatasheetText) ...[
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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_ed_text, cp_new_ed_text)


cp_old_ed_supplier = """              const SizedBox(height: 12),
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
              ),"""
cp_new_ed_supplier = """              if (widget.showComponentSupplier) ...[
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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_ed_supplier, cp_new_ed_supplier)

print("Patch 2 complete!")

