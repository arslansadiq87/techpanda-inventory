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

replace_exact("""class ComponentsPage extends StatelessWidget {
  final ApiClient api;
  final List<dynamic> components;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;

  final TextEditingController searchController;
  final String? filterComponentType;
  final String? filterLocationId;
  final String? filterUnit;
  final String filterStockStatus;
  final bool showMobileFilters;
  final String viewMode;

  final bool enableAddComponent;
  final bool enableEditComponent;
  final bool canCaptureImage;""",
"""class ComponentsPage extends StatelessWidget {
  final ApiClient api;
  final List<dynamic> components;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;

  final TextEditingController searchController;
  final String? filterComponentType;
  final String? filterLocationId;
  final String? filterUnit;
  final String filterStockStatus;
  final bool showMobileFilters;
  final String viewMode;

  final bool enableAddComponent;
  final bool enableEditComponent;
  final bool canCaptureImage;
  final bool showComponentSupplier;
  final bool showComponentPrice;
  final bool showComponentExpiryDate;
  final bool showComponentDatasheetFile;
  final bool showComponentDatasheetText;""")

replace_exact("""  const ComponentsPage({
    super.key,
    required this.api,
    required this.components,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.searchController,
    required this.filterComponentType,
    required this.filterLocationId,
    required this.filterUnit,
    required this.filterStockStatus,
    required this.showMobileFilters,
    required this.viewMode,
    required this.enableAddComponent,
    required this.enableEditComponent,
    required this.canCaptureImage,""",
"""  const ComponentsPage({
    super.key,
    required this.api,
    required this.components,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.searchController,
    required this.filterComponentType,
    required this.filterLocationId,
    required this.filterUnit,
    required this.filterStockStatus,
    required this.showMobileFilters,
    required this.viewMode,
    required this.enableAddComponent,
    required this.enableEditComponent,
    required this.canCaptureImage,
    required this.showComponentSupplier,
    required this.showComponentPrice,
    required this.showComponentExpiryDate,
    required this.showComponentDatasheetFile,
    required this.showComponentDatasheetText,""")


replace_exact("""          child: AddComponentPanel(
            api: api,
            categories: categories,
            componentTypes: componentTypes,
            locations: locations,
            suppliers: suppliers,
            canCaptureImage: canCaptureImage,""",
"""          child: AddComponentPanel(
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
            showComponentDatasheetText: showComponentDatasheetText,""")


replace_exact("""class AddComponentPanel extends StatefulWidget {
  final ApiClient api;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;
  final List<dynamic> locations;
  final List<dynamic> suppliers;
  final bool canCaptureImage;""",
"""class AddComponentPanel extends StatefulWidget {
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
  final bool showComponentDatasheetText;""")

replace_exact("""  const AddComponentPanel({
    super.key,
    required this.api,
    required this.categories,
    required this.componentTypes,
    required this.locations,
    required this.suppliers,
    required this.canCaptureImage,""",
"""  const AddComponentPanel({
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
    required this.showComponentDatasheetText,""")


replace_exact("""class ComponentDetailModal extends StatelessWidget {
  final ApiClient api;

  const ComponentDetailModal({
    super.key,
    required this.api,
  });""",
"""class ComponentDetailModal extends StatelessWidget {
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
  });""")

replace_exact("""  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {""",
"""  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required bool showComponentSupplier,
    required bool showComponentPrice,
    required bool showComponentExpiryDate,
    required bool showComponentDatasheetFile,
    required bool showComponentDatasheetText,
    required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,
    required void Function(Map<String, dynamic>) onShowComponentImage,
  }) async {""")


replace_exact("""        builder: (context) => ComponentDetailModal(
          api: api,
          buildImage: buildImage,
          onShowComponentImage: onShowComponentImage,
          component: component,
        ),""",
"""        builder: (context) => ComponentDetailModal(
          api: api,
          showComponentSupplier: showComponentSupplier,
          showComponentPrice: showComponentPrice,
          showComponentExpiryDate: showComponentExpiryDate,
          showComponentDatasheetFile: showComponentDatasheetFile,
          showComponentDatasheetText: showComponentDatasheetText,
          buildImage: buildImage,
          onShowComponentImage: onShowComponentImage,
          component: component,
        ),""")

replace_exact("""class EditComponentModal extends StatefulWidget {
  final Map<String, dynamic> component;
  final ApiClient api;

  const EditComponentModal({
    super.key,
    required this.component,
    required this.api,
  });""",
"""class EditComponentModal extends StatefulWidget {
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
  });""")

replace_exact("""  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> component, {
    required ApiClient api,
    required List<dynamic> componentTypes,
    required List<dynamic> locations,
    required List<dynamic> suppliers,
    required bool canCaptureImage,""",
"""  static Future<void> show(
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
    required bool canCaptureImage,""")

replace_exact("""        builder: (context) => EditComponentModal(
          component: component,
          api: api,
          componentTypes: componentTypes,
          locations: locations,
          suppliers: suppliers,
          canCaptureImage: canCaptureImage,""",
"""        builder: (context) => EditComponentModal(
          component: component,
          api: api,
          showComponentSupplier: showComponentSupplier,
          showComponentPrice: showComponentPrice,
          showComponentExpiryDate: showComponentExpiryDate,
          showComponentDatasheetFile: showComponentDatasheetFile,
          showComponentDatasheetText: showComponentDatasheetText,
          componentTypes: componentTypes,
          locations: locations,
          suppliers: suppliers,
          canCaptureImage: canCaptureImage,""")


# 2 List Invocations of detail modal
replace_exact("""                  ComponentDetailModal.show(
                    context,
                    item,
                    api: api,
                    buildImage: buildImage,
                    onShowComponentImage: onShowComponentImage,
                  );""",
"""                  ComponentDetailModal.show(
                    context,
                    item,
                    api: api,
                    showComponentSupplier: showComponentSupplier,
                    showComponentPrice: showComponentPrice,
                    showComponentExpiryDate: showComponentExpiryDate,
                    showComponentDatasheetFile: showComponentDatasheetFile,
                    showComponentDatasheetText: showComponentDatasheetText,
                    buildImage: buildImage,
                    onShowComponentImage: onShowComponentImage,
                  );""")

replace_exact("""                        ComponentDetailModal.show(
                          context,
                          item,
                          api: api,
                          buildImage: buildImage,
                          onShowComponentImage: onShowComponentImage,
                        );""",
"""                        ComponentDetailModal.show(
                          context,
                          item,
                          api: api,
                          showComponentSupplier: showComponentSupplier,
                          showComponentPrice: showComponentPrice,
                          showComponentExpiryDate: showComponentExpiryDate,
                          showComponentDatasheetFile: showComponentDatasheetFile,
                          showComponentDatasheetText: showComponentDatasheetText,
                          buildImage: buildImage,
                          onShowComponentImage: onShowComponentImage,
                        );""")

# Edit modal invocation
replace_exact("""                    EditComponentModal.show(
                      context,
                      component,
                      api: api,
                      componentTypes: componentTypes,
                      locations: locations,
                      suppliers: suppliers,
                      canCaptureImage: canCaptureImage,""",
"""                    EditComponentModal.show(
                      context,
                      component,
                      api: api,
                      showComponentSupplier: showComponentSupplier,
                      showComponentPrice: showComponentPrice,
                      showComponentExpiryDate: showComponentExpiryDate,
                      showComponentDatasheetFile: showComponentDatasheetFile,
                      showComponentDatasheetText: showComponentDatasheetText,
                      componentTypes: componentTypes,
                      locations: locations,
                      suppliers: suppliers,
                      canCaptureImage: canCaptureImage,""")


with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Headers & calls patched successfully.")

