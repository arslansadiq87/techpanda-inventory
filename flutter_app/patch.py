import re
import sys

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

fields_to_add = """
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;"""

required_args = """
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,"""

# 1. Add fields to ComponentsPage
content = re.sub(
    r'(class ComponentsPage extends StatelessWidget \{.*?)(final bool canCaptureImage;)',
    r'\1\2' + fields_to_add,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(const ComponentsPage\(\{.*?)(required this\.canCaptureImage,)',
    r'\1\2' + required_args,
    content, count=1, flags=re.DOTALL
)

# 2. Add fields to AddComponentPanel
content = re.sub(
    r'(class AddComponentPanel extends StatefulWidget \{.*?)(final bool canCaptureImage;)',
    r'\1\2' + fields_to_add,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(const AddComponentPanel\(\{.*?)(required this\.canCaptureImage,)',
    r'\1\2' + required_args,
    content, count=1, flags=re.DOTALL
)

# 3. Add fields to ComponentDetailModal
content = re.sub(
    r'(class ComponentDetailModal extends StatelessWidget \{.*?)(final ApiClient api;)',
    r'\1\2' + fields_to_add,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(const ComponentDetailModal\(\{.*?)(required this\.api,)',
    r'\1\2' + required_args,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(static Future<void> show\(.*?\{.*?)(required ApiClient api,)',
    r'\1\2' + required_args.replace('this.', 'bool '),
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(ComponentDetailModal\(\s*api: api,)',
    r'\1' + required_args.replace('required this.', '').replace(',\n', ',\n            ').replace('    show', 'show').replace('showComponentDatasheetText', 'showComponentDatasheetText: showComponentDatasheetText'),
    content, count=1, flags=re.DOTALL
)
content = content.replace(
    'showComponentDatasheetText: showComponentDatasheetText,',
    'showComponentSupplier: showComponentSupplier,\n            showComponentPrice: showComponentPrice,\n            showComponentExpiryDate: showComponentExpiryDate,\n            showComponentDatasheetFile: showComponentDatasheetFile,\n            showComponentDatasheetText: showComponentDatasheetText,'
)

# 4. Add fields to EditComponentModal
content = re.sub(
    r'(class EditComponentModal extends StatefulWidget \{.*?)(final bool canCaptureImage;)',
    r'\1\2' + fields_to_add,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(const EditComponentModal\(\{.*?)(required this\.canCaptureImage,)',
    r'\1\2' + required_args,
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(static Future<void> show\(.*?\{.*?)(required ApiClient api,)',
    r'\1\2' + required_args.replace('this.', 'bool '),
    content, count=1, flags=re.DOTALL
)
content = re.sub(
    r'(EditComponentModal\(\s*component: component,\s*api: api,)',
    r'\1\n            showComponentSupplier: showComponentSupplier,\n            showComponentPrice: showComponentPrice,\n            showComponentExpiryDate: showComponentExpiryDate,\n            showComponentDatasheetFile: showComponentDatasheetFile,\n            showComponentDatasheetText: showComponentDatasheetText,',
    content, count=1, flags=re.DOTALL
)

# 5. Pass parameters to AddComponentPanel from ComponentsPage
content = content.replace(
    'canCaptureImage: canCaptureImage,\n              onRefresh: onRefresh,',
    'canCaptureImage: canCaptureImage,\n              showComponentSupplier: showComponentSupplier,\n              showComponentPrice: showComponentPrice,\n              showComponentExpiryDate: showComponentExpiryDate,\n              showComponentDatasheetFile: showComponentDatasheetFile,\n              showComponentDatasheetText: showComponentDatasheetText,\n              onRefresh: onRefresh,'
)

# 6. Pass parameters to Modals from ComponentsPage
content = content.replace(
    'buildImage: buildImage,\n                    onShowComponentImage: onShowComponentImage,',
    'showComponentSupplier: showComponentSupplier,\n                    showComponentPrice: showComponentPrice,\n                    showComponentExpiryDate: showComponentExpiryDate,\n                    showComponentDatasheetFile: showComponentDatasheetFile,\n                    showComponentDatasheetText: showComponentDatasheetText,\n                    buildImage: buildImage,\n                    onShowComponentImage: onShowComponentImage,'
)
content = content.replace(
    'buildImage: buildImage,\n                          onShowComponentImage: onShowComponentImage,',
    'showComponentSupplier: showComponentSupplier,\n                          showComponentPrice: showComponentPrice,\n                          showComponentExpiryDate: showComponentExpiryDate,\n                          showComponentDatasheetFile: showComponentDatasheetFile,\n                          showComponentDatasheetText: showComponentDatasheetText,\n                          buildImage: buildImage,\n                          onShowComponentImage: onShowComponentImage,'
)
content = content.replace(
    'canCaptureImage: canCaptureImage,\n                      onRefresh: onRefresh,',
    'canCaptureImage: canCaptureImage,\n                      showComponentSupplier: showComponentSupplier,\n                      showComponentPrice: showComponentPrice,\n                      showComponentExpiryDate: showComponentExpiryDate,\n                      showComponentDatasheetFile: showComponentDatasheetFile,\n                      showComponentDatasheetText: showComponentDatasheetText,\n                      onRefresh: onRefresh,'
)


# AddComponentPanel toggles
content = re.sub(
    r'(\s*)SizedBox\(\s*width: width\(140\),\s*child: TextField\(\s*controller: _componentPrice,\)',
    r'\1if (widget.showComponentPrice) SizedBox(\n\1  width: width(140),\n\1  child: TextField(\n\1    controller: _componentPrice,',
    content, count=1
)
content = re.sub(
    r'(\s*)SizedBox\(\s*width: width\(160\),\s*child: TextField\(\s*controller: _componentExpiryDate,\)',
    r'\1if (widget.showComponentExpiryDate) SizedBox(\n\1  width: width(160),\n\1  child: TextField(\n\1    controller: _componentExpiryDate,',
    content, count=1
)
content = re.sub(
    r'(\s*)FilledButton.tonalIcon\(\s*onPressed: \(\) async \{\s*final picked = await widget.onPickDatasheet\(\);\s*',
    r'\1if (widget.showComponentDatasheetFile) FilledButton.tonalIcon(\n\1  onPressed: () async {\n\1    final picked = await widget.onPickDatasheet();\n\1',
    content, count=1
)
content = re.sub(
    r'(\s*)if \(_componentDatasheet != null\) \.\.\.\[\s*const SizedBox\(height: 8\),\s*Container\(',
    r'\1if (widget.showComponentDatasheetFile && _componentDatasheet != null) ...[\n\1  const SizedBox(height: 8),\n\1  Container(',
    content, count=1
)
content = re.sub(
    r'(\s*)TextField\(\s*controller: _componentDatasheetText,\)',
    r'\1if (widget.showComponentDatasheetText) TextField(\n\1  controller: _componentDatasheetText,',
    content, count=1
)
content = re.sub(
    r'(\s*)SizedBox\(\s*width: width\(250\),\s*child: Row\(\s*children: \[\s*Expanded\(\s*child: DropdownButtonFormField<String\?>\(',
    r'\1if (widget.showComponentSupplier) SizedBox(\n\1  width: width(250),\n\1  child: Row(\n\1    children: [\n\1      Expanded(\n\1        child: DropdownButtonFormField<String?>(',
    content, count=1
)


# ComponentDetailModal toggles
content = re.sub(
    r'if \(component\[\'price\'\] != null &&\s*\'\$\{component\[\'price\'\]\}\'\.trim\(\)\.isNotEmpty\)',
    r'if (showComponentPrice && component[\'price\'] != null && \'${component[\'price\']}\'.trim().isNotEmpty)',
    content, count=1
)
content = re.sub(
    r'if \(component\[\'expiry_date\'\] != null &&\s*\'\$\{component\[\'expiry_date\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[',
    r'if (showComponentExpiryDate && component[\'expiry_date\'] != null && \'${component[\'expiry_date\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)
content = re.sub(
    r'if \(component\[\'datasheet_url\'\] != null &&\s*\'\$\{component\[\'datasheet_url\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[',
    r'if (showComponentDatasheetFile && component[\'datasheet_url\'] != null && \'${component[\'datasheet_url\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)
content = re.sub(
    r'if \(component\[\'datasheet_text\'\] != null &&\s*\'\$\{component\[\'datasheet_text\'\]\}\'\.trim\(\)\.isNotEmpty\) \.\.\.\[',
    r'if (showComponentDatasheetText && component[\'datasheet_text\'] != null && \'${component[\'datasheet_text\']}\'.trim().isNotEmpty) ...[',
    content, count=1
)

# EditComponentModal toggles
content = re.sub(
    r'(\s*)const SizedBox\(height: 12\),\s*TextField\(\s*controller: price,\)',
    r'\1if (widget.showComponentPrice) ...[\n\1  const SizedBox(height: 12),\n\1  TextField(\n\1    controller: price,',
    content, count=1
)
content = re.sub(
    r'(\s*)const InputDecoration\(labelText: \'Price \(optional\)\'\),\s*\),',
    r'\1const InputDecoration(labelText: \'Price (optional)\'),\n\1  ),\n\1],',
    content, count=1
)
content = re.sub(
    r'(\s*)const SizedBox\(height: 12\),\s*TextField\(\s*controller: expiryDate,\)',
    r'\1if (widget.showComponentExpiryDate) ...[\n\1  const SizedBox(height: 12),\n\1  TextField(\n\1    controller: expiryDate,',
    content, count=1
)
content = re.sub(
    r'(\s*)suffixIcon: expiryDate.text.isNotEmpty(.*?)null,\s*\),\s*\),',
    r'\1suffixIcon: expiryDate.text.isNotEmpty\2null,\n\1  ),\n\1),\n\1],',
    content, count=1, flags=re.DOTALL
)

content = re.sub(
    r'(\s*)const SizedBox\(height: 12\),\s*Container\(\s*width: double\.infinity,\)',
    r'\1if (widget.showComponentDatasheetFile) ...[\n\1  const SizedBox(height: 12),\n\1  Container(\n\1    width: double.infinity,',
    content, count=1
)
content = re.sub(
    r'(\s*)onPressed: \(\) => setState\(\(\) => newDatasheet = null\),\s*\),\s*\]\,\s*\],(.*?)\]\,\s*\),',
    r'\1onPressed: () => setState(() => newDatasheet = null),\n\1  ),\n\1],\n\1],\2],\n\1),\n\1],',
    content, count=1, flags=re.DOTALL
)

content = re.sub(
    r'(\s*)const SizedBox\(height: 12\),\s*TextField\(\s*controller: datasheetText,\)',
    r'\1if (widget.showComponentDatasheetText) ...[\n\1  const SizedBox(height: 12),\n\1  TextField(\n\1    controller: datasheetText,',
    content, count=1
)
content = re.sub(
    r'(\s*)minLines: 3,\s*maxLines: 6,\s*\),',
    r'\1minLines: 3,\n\1maxLines: 6,\n\1),\n\1],',
    content, count=1
)

content = re.sub(
    r'(\s*)const SizedBox\(height: 12\),\s*Row\(\s*children: \[\s*Expanded\(\s*child: DropdownButtonFormField<String\?>\(',
    r'\1if (widget.showComponentSupplier) ...[\n\1  const SizedBox(height: 12),\n\1  Row(\n\1    children: [\n\1      Expanded(\n\1        child: DropdownButtonFormField<String?>(',
    content, count=1
)
content = re.sub(
    r'(\s*)await widget\.onAddSupplier\(\);\s*setState\(\(\) \{\}\);\s*\},(.*?)\]\,\s*\),',
    r'\1await widget.onAddSupplier();\n\1setState(() {});\n\1},\2],\n\1),\n\1],',
    content, count=1, flags=re.DOTALL
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

h_filepath = 'lib/features/inventory_home.dart'
with open(h_filepath, 'r', encoding='utf-8') as f:
    h_content = f.read()

h_args = """
              showComponentSupplier: _showComponentSupplier,
              showComponentPrice: _showComponentPrice,
              showComponentExpiryDate: _showComponentExpiryDate,
              showComponentDatasheetFile: _showComponentDatasheetFile,
              showComponentDatasheetText: _showComponentDatasheetText,"""

h_content = h_content.replace(
    "enableEditComponent: _enableEditComponent,",
    "enableEditComponent: _enableEditComponent," + h_args
)

with open(h_filepath, 'w', encoding='utf-8') as f:
    f.write(h_content)

