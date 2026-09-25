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

# inventory_home.dart
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
replace_exact('lib/features/inventory_home.dart', h_old, h_new)


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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old1, cp_new1)

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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old2, cp_new2)


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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old3, cp_new3)

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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old4, cp_new4)

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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old5, cp_new5)

# AddComponentPanel toggles
cp_old_price = """                  SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,"""
cp_new_price = """                  if (widget.showComponentPrice) SizedBox(
                    width: width(140),
                    child: TextField(
                      controller: _componentPrice,"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_price, cp_new_price)

cp_old_expiry = """                  SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,"""
cp_new_expiry = """                  if (widget.showComponentExpiryDate) SizedBox(
                    width: width(160),
                    child: TextField(
                      controller: _componentExpiryDate,"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_expiry, cp_new_expiry)

cp_old_file = """                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();"""
cp_new_file = """                  if (widget.showComponentDatasheetFile) FilledButton.tonalIcon(
                    onPressed: () async {
                      final picked = await widget.onPickDatasheet();"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_file, cp_new_file)

cp_old_file2 = """                  if (_componentDatasheet != null) ...[
                    const SizedBox(height: 8),
                    Container("""
cp_new_file2 = """                  if (widget.showComponentDatasheetFile && _componentDatasheet != null) ...[
                    const SizedBox(height: 8),
                    Container("""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_file2, cp_new_file2)

cp_old_text = """              TextField(
                controller: _componentDatasheetText,"""
cp_new_text = """              if (widget.showComponentDatasheetText) TextField(
                controller: _componentDatasheetText,"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_text, cp_new_text)

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
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_supplier, cp_new_supplier)


# 3. ComponentDetailModal definition
cp_old6 = """class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;

  const ComponentDetailModal({
    super.key,
    required this.api,
  });"""
cp_new6 = """class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;

  const ComponentDetailModal({
    super.key,
    required this.api,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
  });"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old6, cp_new6)

# ComponentDetailModal show() method
cp_old7 = """  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
  }) {"""
cp_new7 = """  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
  }) {"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old7, cp_new7)

cp_old8 = """          child: ComponentDetailModal(
            api: api,
          ),"""
cp_new8 = """          child: ComponentDetailModal(
            api: api,
            showComponentSupplier: showComponentSupplier,
            showComponentPrice: showComponentPrice,
            showComponentExpiryDate: showComponentExpiryDate,
            showComponentDatasheetFile: showComponentDatasheetFile,
            showComponentDatasheetText: showComponentDatasheetText,
          ),"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old8, cp_new8)

# ComponentDetailModal invocations (there are two!)
with open('lib/features/inventory/pages/components_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

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

with open('lib/features/inventory/pages/components_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# ComponentDetailModal toggles
cp_old_dt_price = """              if (component['price'] != null &&
                  '${component['price']}'.trim().isNotEmpty)
                _componentDetailRow(context, 'Price',
                    _formatComponentPrice(component['price'])),"""
cp_new_dt_price = """              if (showComponentPrice && component['price'] != null &&
                  '${component['price']}'.trim().isNotEmpty)
                _componentDetailRow(context, 'Price',
                    _formatComponentPrice(component['price'])),"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_dt_price, cp_new_dt_price)

cp_old_dt_exp = """              if (component['expiry_date'] != null &&
                  '${component['expiry_date']}'.trim().isNotEmpty) ...["""
cp_new_dt_exp = """              if (showComponentExpiryDate && component['expiry_date'] != null &&
                  '${component['expiry_date']}'.trim().isNotEmpty) ...["""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_dt_exp, cp_new_dt_exp)

cp_old_dt_file = """              if (component['datasheet_url'] != null &&
                  '${component['datasheet_url']}'.trim().isNotEmpty) ...["""
cp_new_dt_file = """              if (showComponentDatasheetFile && component['datasheet_url'] != null &&
                  '${component['datasheet_url']}'.trim().isNotEmpty) ...["""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_dt_file, cp_new_dt_file)

cp_old_dt_text = """              if (component['datasheet_text'] != null &&
                  '${component['datasheet_text']}'.trim().isNotEmpty) ...["""
cp_new_dt_text = """              if (showComponentDatasheetText && component['datasheet_text'] != null &&
                  '${component['datasheet_text']}'.trim().isNotEmpty) ...["""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old_dt_text, cp_new_dt_text)


# 4. EditComponentModal definition
cp_old9 = """class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;

  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
  });"""
cp_new9 = """class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;

  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,
  });"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old9, cp_new9)

# EditComponentModal show() method
cp_old10 = """  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required List<dynamic> componentTypes,
    required List<dynamic> locations,
    required List<dynamic> suppliers,
    required bool canCaptureImage,
    required Future<void> Function() onRefresh,
    required ValueChanged<String> onError,
    required Future<Map<String, dynamic>?> Function() onPickImage,
    required Future<Map<String, dynamic>?> Function() onCaptureImage,
    required Future<Map<String, dynamic>?> Function() onPickDatasheet,
    required Future<String?> Function(Map<String, dynamic>) onUploadImage,
    required Future<String?> Function(Map<String, dynamic>) onUploadDatasheet,
    required VoidCallback onAddSupplier,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
    required void Function(BuildContext, String, String) onShowComponentImage,
  }) {"""
cp_new10 = """  static Future<void> show(
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
    required Future<Map<String, dynamic>?> Function() onPickImage,
    required Future<Map<String, dynamic>?> Function() onCaptureImage,
    required Future<Map<String, dynamic>?> Function() onPickDatasheet,
    required Future<String?> Function(Map<String, dynamic>) onUploadImage,
    required Future<String?> Function(Map<String, dynamic>) onUploadDatasheet,
    required VoidCallback onAddSupplier,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
    required void Function(BuildContext, String, String) onShowComponentImage,
  }) {"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old10, cp_new10)

cp_old11 = """          child: EditComponentModal(
            component: component,
            api: api,
          ),"""
cp_new11 = """          child: EditComponentModal(
            component: component,
            api: api,
            showComponentSupplier: showComponentSupplier,
            showComponentPrice: showComponentPrice,
            showComponentExpiryDate: showComponentExpiryDate,
            showComponentDatasheetFile: showComponentDatasheetFile,
            showComponentDatasheetText: showComponentDatasheetText,
          ),"""
replace_exact('lib/features/inventory/pages/components_page.dart', cp_old11, cp_new11)

# EditComponentModal invocations
with open('lib/features/inventory/pages/components_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("""                      canCaptureImage: canCaptureImage,
                      onRefresh: onRefresh,""",
"""                      showComponentSupplier: showComponentSupplier,
                      showComponentPrice: showComponentPrice,
                      showComponentExpiryDate: showComponentExpiryDate,
                      showComponentDatasheetFile: showComponentDatasheetFile,
                      showComponentDatasheetText: showComponentDatasheetText,
                      canCaptureImage: canCaptureImage,
                      onRefresh: onRefresh,""")

with open('lib/features/inventory/pages/components_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)


print("Patch 1 complete!")

