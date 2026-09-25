import sys
import re

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def safe_replace(old, new, count=1):
    global content
    if content.count(old) != count:
        print(f"Error: Expected {count} match(es) for\n{old}\nFound {content.count(old)}.")
        sys.exit(1)
    content = content.replace(old, new)


# inventory_home.dart
h_filepath = 'lib/features/inventory_home.dart'
with open(h_filepath, 'r', encoding='utf-8') as f:
    h_content = f.read()

h_old = """              showMobileFilters: _showMobileComponentFilters,
              viewMode: _componentViewMode,
              enableAddComponent: _enableAddComponent,
              enableEditComponent: _enableEditComponent,
              canCaptureImage: _canCaptureComponentImage,"""
h_new = """              showMobileFilters: _showMobileComponentFilters,
              viewMode: _componentViewMode,
              enableAddComponent: _enableAddComponent,
              enableEditComponent: _enableEditComponent,
              canCaptureImage: _canCaptureComponentImage,
              showComponentSupplier: _showComponentSupplier,
              showComponentPrice: _showComponentPrice,
              showComponentExpiryDate: _showComponentExpiryDate,
              showComponentDatasheetFile: _showComponentDatasheetFile,
              showComponentDatasheetText: _showComponentDatasheetText,"""
if h_content.count(h_old) == 1:
    h_content = h_content.replace(h_old, h_new)
else:
    print("Error in inventory_home.dart")
    sys.exit(1)

with open(h_filepath, 'w', encoding='utf-8') as f:
    f.write(h_content)


# components_page.dart ComponentsPage fields
cp_old1 = """  final bool enableAddComponent;
  final bool enableEditComponent;
  final bool canCaptureImage;

  final ValueChanged<String?> onFilterComponentTypeChanged;"""

cp_new1 = """  final bool enableAddComponent;
  final bool enableEditComponent;
  final bool canCaptureImage;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;

  final ValueChanged<String?> onFilterComponentTypeChanged;"""
safe_replace(cp_old1, cp_new1)

cp_old2 = """    required this.enableAddComponent,
    required this.enableEditComponent,
    required this.canCaptureImage,
    required this.onFilterComponentTypeChanged,"""

cp_new2 = """    required this.enableAddComponent,
    required this.enableEditComponent,
    required this.canCaptureImage,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
    required this.onFilterComponentTypeChanged,"""
safe_replace(cp_old2, cp_new2)

# AddComponentPanel invocation
cp_old3 = """            child: AddComponentPanel(
              api: api,
              categories: categories,
              componentTypes: componentTypes,
              locations: locations,
              suppliers: suppliers,
              canCaptureImage: canCaptureImage,
              onRefresh: onRefresh,"""

cp_new3 = """            child: AddComponentPanel(
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
              onRefresh: onRefresh,"""
safe_replace(cp_old3, cp_new3)


# AddComponentPanel definition
cp_old4 = """class AddComponentPanel extends StatefulWidget {
  final ApiClient api;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;

  final Future<void> Function() onRefresh;"""

cp_new4 = """class AddComponentPanel extends StatefulWidget {
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

  final Future<void> Function() onRefresh;"""
safe_replace(cp_old4, cp_new4)

cp_old5 = """  const AddComponentPanel({
    super.key,
    required this.api,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.canCaptureImage,
    required this.onRefresh,"""

cp_new5 = """  const AddComponentPanel({
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
    required this.onRefresh,"""
safe_replace(cp_old5, cp_new5)

# ComponentDetailModal & EditComponentModal definition parameters via regex
content = re.sub(
    r'(class (?:ComponentDetailModal|EditComponentModal) extends (?:StatelessWidget|StatefulWidget) \{.*?final ApiClient api;)',
    r'\1\n  final bool showComponentSupplier;\n  final bool showComponentPrice;\n  final bool showComponentExpiryDate;\n  final bool showComponentDatasheetFile;\n  final bool showComponentDatasheetText;',
    content, flags=re.DOTALL
)

content = re.sub(
    r'(const ComponentDetailModal\(\{.*?)(required this\.api)',
    r'\1\2, required this.showComponentSupplier, required this.showComponentPrice, required this.showComponentExpiryDate, required this.showComponentDatasheetFile, required this.showComponentDatasheetText',
    content, flags=re.DOTALL
)

content = re.sub(
    r'(const EditComponentModal\(\{.*?)(required this\.api)',
    r'\1\2, required this.showComponentSupplier, required this.showComponentPrice, required this.showComponentExpiryDate, required this.showComponentDatasheetFile, required this.showComponentDatasheetText',
    content, flags=re.DOTALL
)

# Inject show() arguments
content = re.sub(
    r'(static Future<void> show\(\s*BuildContext context,\s*Map<String, dynamic> component, \{)',
    r'\1\n    required bool showComponentSupplier,\n    required bool showComponentPrice,\n    required bool showComponentExpiryDate,\n    required bool showComponentDatasheetFile,\n    required bool showComponentDatasheetText,',
    content
)

# Inject parameters inside ComponentDetailModal instantiations within show()
content = re.sub(
    r'(ComponentDetailModal\(\s*api: api,)',
    r'\1\n          showComponentSupplier: showComponentSupplier,\n          showComponentPrice: showComponentPrice,\n          showComponentExpiryDate: showComponentExpiryDate,\n          showComponentDatasheetFile: showComponentDatasheetFile,\n          showComponentDatasheetText: showComponentDatasheetText,',
    content
)

# Inject parameters inside EditComponentModal instantiations within show()
content = re.sub(
    r'(EditComponentModal\(\s*component: component,\s*api: api,)',
    r'\1\n          showComponentSupplier: showComponentSupplier,\n          showComponentPrice: showComponentPrice,\n          showComponentExpiryDate: showComponentExpiryDate,\n          showComponentDatasheetFile: showComponentDatasheetFile,\n          showComponentDatasheetText: showComponentDatasheetText,',
    content
)

# Invocations of show()
content = content.replace("""                    api: api,
                    buildImage: buildImage,
                    onShowComponentImage: onShowComponentImage,""",
"""                    api: api,
                    showComponentSupplier: showComponentSupplier,
                    showComponentPrice: showComponentPrice,
                    showComponentExpiryDate: showComponentExpiryDate,
                    showComponentDatasheetFile: showComponentDatasheetFile,
                    showComponentDatasheetText: showComponentDatasheetText,
                    buildImage: buildImage,
                    onShowComponentImage: onShowComponentImage,""")

content = content.replace("""                          api: api,
                          buildImage: buildImage,
                          onShowComponentImage: onShowComponentImage,""",
"""                          api: api,
                          showComponentSupplier: showComponentSupplier,
                          showComponentPrice: showComponentPrice,
                          showComponentExpiryDate: showComponentExpiryDate,
                          showComponentDatasheetFile: showComponentDatasheetFile,
                          showComponentDatasheetText: showComponentDatasheetText,
                          buildImage: buildImage,
                          onShowComponentImage: onShowComponentImage,""")

content = content.replace("""                      canCaptureImage: canCaptureImage,
                      onRefresh: onRefresh,""",
"""                      showComponentSupplier: showComponentSupplier,
                      showComponentPrice: showComponentPrice,
                      showComponentExpiryDate: showComponentExpiryDate,
                      showComponentDatasheetFile: showComponentDatasheetFile,
                      showComponentDatasheetText: showComponentDatasheetText,
                      canCaptureImage: canCaptureImage,
                      onRefresh: onRefresh,""")

# AddComponentPanel toggles
cp_old_price = """                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,"""
cp_new_price = """                  if (widget.showComponentPrice) SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,"""
safe_replace(cp_old_price, cp_new_price)

cp_old_expiry = """                  SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,"""
cp_new_expiry = """                  if (widget.showComponentExpiryDate) SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,"""
safe_replace(cp_old_expiry, cp_new_expiry)

cp_old_file = """                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();"""
cp_new_file = """                  if (widget.showComponentDatasheetFile) FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();"""
safe_replace(cp_old_file, cp_new_file)

cp_old_file2 = """                  if (_componentDatasheet != null) ...[
                    ConstrainedBox("""
cp_new_file2 = """                  if (widget.showComponentDatasheetFile && _componentDatasheet != null) ...[
                    ConstrainedBox("""
safe_replace(cp_old_file2, cp_new_file2)

cp_old_text = """              TextField(
                controller: _componentDatasheetText,"""
cp_new_text = """              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,"""
safe_replace(cp_old_text, cp_new_text)

cp_old_supplier = """                  SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>("""
cp_new_supplier = """                  if (widget.showComponentSupplier) SizedBox(
                    width: width(250),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>("""
safe_replace(cp_old_supplier, cp_new_supplier)

# EditComponentModal toggles
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
safe_replace(cp_old_ed_price, cp_new_ed_price)

cp_old_ed_exp = """              const SizedBox(height: 12),
              TextField(
                controller: expiryDate,"""
cp_new_ed_exp = """              if (widget.showComponentExpiryDate) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: expiryDate,"""
safe_replace(cp_old_ed_exp, cp_new_ed_exp)

content = content.replace("""                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Container(""",
"""                      : null,
                ),
              ),
              ],
              const SizedBox(height: 12),
              Container(""")

cp_old_ed_file = """              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),"""
cp_new_ed_file = """              if (widget.showComponentDatasheetFile) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),"""
safe_replace(cp_old_ed_file, cp_new_ed_file)

content = content.replace("""                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,""",
"""                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: datasheetText,""")

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
safe_replace(cp_old_ed_text, cp_new_ed_text)

cp_old_ed_supplier = """              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>("""
cp_new_ed_supplier = """              if (widget.showComponentSupplier) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>("""
safe_replace(cp_old_ed_supplier, cp_new_ed_supplier)

content = content.replace("""                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),""",
"""                    ),
                  ),
                ],
              ),
              ],
            ],
          ),
        ),
      ),""")

# ComponentDetailModal toggles
content = re.sub(
    r'(if \(component\[\'price\'\] != null &&\s*\'\$\{component\[\'price\'\]\}\'\.trim\(\)\.isNotEmpty\))',
    r'if (showComponentPrice && component[\'price\'] != null && \'${component[\'price\']}\'.trim().isNotEmpty)',
    content, count=1
)
content = re.sub(
    r'(if \(component\[\'expiry_date\'\] != null &&\s*\'\$\{component\[\'expiry_date\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[)',
    r'if (showComponentExpiryDate && component[\'expiry_date\'] != null && \'${component[\'expiry_date\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)
content = re.sub(
    r'(if \(component\[\'datasheet_url\'\] != null &&\s*\'\$\{component\[\'datasheet_url\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[)',
    r'if (showComponentDatasheetFile && component[\'datasheet_url\'] != null && \'${component[\'datasheet_url\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)
content = re.sub(
    r'(if \(component\[\'datasheet_text\'\] != null &&\s*\'\$\{component\[\'datasheet_text\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[)',
    r'if (showComponentDatasheetText && component[\'datasheet_text\'] != null && \'${component[\'datasheet_text\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully.")

