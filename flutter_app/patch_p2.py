import sys

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def replace_exact(old_str, new_str):
    global content
    count = content.count(old_str)
    if count != 1:
        print(f"Error: Found {count} occurrences of\n{old_str}")
        sys.exit(1)
    content = content.replace(old_str, new_str)

replace_exact("""                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (optional)'),
                    ),
                  ),""",
"""                  if (widget.showComponentPrice) SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (optional)'),
                    ),
                  ),""")

replace_exact("""                  SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,
                      readOnly: true,
                      onTap: () async {
                        await _selectExpiryDate(context);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Expiry date (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        suffixIcon: _componentExpiryDate.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _componentExpiryDate.clear();
                                  setState(() {});
                                },
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
                        await _selectExpiryDate(context);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        labelText: 'Expiry date (optional)',
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        suffixIcon: _componentExpiryDate.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _componentExpiryDate.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),""")

replace_exact("""                  FilledButton.tonalIcon(
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
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description, size: 16),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: width(180)),
                            child: Text(
                              _componentDatasheet!.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                setState(() => _componentDatasheet = null),
                          ),
                        ],
                      ),
                    ),
                  ],""",
"""                  if (widget.showComponentDatasheetFile) ...[
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
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.description, size: 16),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: width(180)),
                              child: Text(
                                _componentDatasheet!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  setState(() => _componentDatasheet = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],""")

replace_exact("""              TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),""",
"""              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,
                decoration: const InputDecoration(
                  labelText: 'Datasheet copy-paste / specs (optional)',
                  hintText: 'Paste pinouts, ratings, specs, or datasheet notes here',
                ),
                minLines: 2,
                maxLines: 5,
              ),""")

replace_exact("""                  SizedBox(
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
                  ),""",
"""                  if (widget.showComponentSupplier) SizedBox(
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
                  ),""")


with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("AddComponentPanel UI patched successfully.")

