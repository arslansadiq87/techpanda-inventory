import os

filepath = 'lib/features/inventory_home.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
import_stmt = "import 'inventory/pages/components_page.dart';\n"
if import_stmt not in content:
    content = content.replace("import 'inventory/pages/dashboard_page.dart';", 
                              "import 'inventory/pages/dashboard_page.dart';\n" + import_stmt)

# Replace _showComponentDetails(compMatch); with ComponentDetailModal.show(...)
content = content.replace(
    "_showComponentDetails(compMatch);",
    """ComponentDetailModal.show(
        context, 
        compMatch, 
        api: widget.api,
        buildImage: _inventoryImage,
        onShowComponentImage: _showComponentImage,
      );"""
)

# Replace _componentsPage() with ComponentsPage(...)
components_page_call = """ComponentsPage(
              api: widget.api,
              components: _components,
              componentTypes: _componentTypes,
              locations: _locations,
              suppliers: _suppliers,
              searchController: _search,
              filterComponentType: _filterComponentType,
              filterLocationId: _filterLocationId,
              filterUnit: _filterUnit,
              filterStockStatus: _filterStockStatus,
              showMobileFilters: _showMobileComponentFilters,
              viewMode: _componentViewMode,
              enableAddComponent: _enableAddComponent,
              enableEditComponent: _enableEditComponent,
              canCaptureImage: _canCaptureComponentImage,
              onFilterComponentTypeChanged: (value) => setState(() => _filterComponentType = value),
              onFilterLocationIdChanged: (value) => setState(() => _filterLocationId = value),
              onFilterUnitChanged: (value) => setState(() => _filterUnit = value),
              onFilterStockStatusChanged: (value) => setState(() => _filterStockStatus = value),
              onToggleMobileFilters: () => setState(() => _showMobileComponentFilters = !_showMobileComponentFilters),
              onClearFilters: _clearComponentFilters,
              onRefresh: _refresh,
              onError: (err) => setState(() => _error = err),
              onOpenComponentInStock: _openComponentInStock,
              onDeleteComponent: _deleteComponent,
              onPickImage: _pickComponentImage,
              onCaptureImage: _captureComponentImage,
              onPickDatasheet: _pickComponentDatasheet,
              onUploadImage: _uploadSelectedImage,
              onUploadDatasheet: _uploadSelectedDatasheet,
              buildThumbnail: _componentThumbnail,
              buildCardImage: _componentCardImage,
              buildImage: _inventoryImage,
              onShowComponentImage: _showComponentImage,
              onAddComponentType: _addComponentType,
              onEditComponentTypes: _editComponentTypes,
              onAddLocation: () => _saveLocation(),
              onEditLocations: _editLocations,
              onAddSupplier: () => _saveSupplier(),
            )"""

content = content.replace("_componentsPage(),", components_page_call + ",")

# Replace _addComponentPanel in _showAddComponentModal
add_component_panel_call = """AddComponentPanel(
              api: widget.api,
              categories: _categories,
              componentTypes: _componentTypes,
              locations: _locations,
              suppliers: _suppliers,
              canCaptureImage: _canCaptureComponentImage,
              onRefresh: _refresh,
              onError: (err) => setState(() => _error = err),
              onCreated: () => Navigator.of(modalContext).pop(),
              onPickImage: _pickComponentImage,
              onCaptureImage: _captureComponentImage,
              onPickDatasheet: _pickComponentDatasheet,
              onUploadImage: _uploadSelectedImage,
              onUploadDatasheet: _uploadSelectedDatasheet,
              onAddComponentType: _addComponentType,
              onEditComponentTypes: _editComponentTypes,
              onAddLocation: () => _saveLocation(),
              onEditLocations: _editLocations,
              onAddSupplier: () => _saveSupplier(),
            )"""

# Note: the original code had:
#             child: _addComponentPanel(
#               onCreated: () => Navigator.of(modalContext).pop(),
#             ),
content = content.replace("""_addComponentPanel(
              onCreated: () => Navigator.of(modalContext).pop(),
            )""", add_component_panel_call)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

