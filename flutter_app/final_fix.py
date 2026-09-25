import os
import re

filepath = 'lib/features/inventory_home.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    h_content = f.read()

# Add import
import_stmt = "import 'inventory/pages/components_page.dart';\n"
if import_stmt not in h_content:
    h_content = h_content.replace("import 'inventory/pages/dashboard_page.dart';", 
                              "import 'inventory/pages/dashboard_page.dart';\n" + import_stmt)

# Remove unused fields
unused_fields = [
    "ComponentImageSelection? _componentImage;",
    "ComponentDatasheetSelection? _componentDatasheet;",
    "String? _componentSupplierId;",
    "String? _componentLocationId;",
    "String _componentUnit = 'Pieces';",
    "String? _filterSupplierId;"
]
for f_decl in unused_fields:
    h_content = h_content.replace(f_decl, "")

# Replace _showComponentDetails(compMatch); with ComponentDetailModal.show(...)
h_content = h_content.replace(
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
              categories: _categories,
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

h_content = h_content.replace("_componentsPage(),", components_page_call + ",")

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

h_content = h_content.replace("""_addComponentPanel(
              onCreated: () => Navigator.of(modalContext).pop(),
            )""", add_component_panel_call)

methods_to_remove = [
    '_componentsPage',
    '_componentSearchField',
    '_mobileComponentFilterButton',
    '_componentSliverList',
    '_componentThumbnailSliverGrid',
    '_componentThumbnailCard',
    '_componentTypeLocationLabel',
    '_componentFilterBar',
    '_addComponentPanel',
    '_createComponent',
    '_categoryIdForComponentType',
    '_categoryMatchKey',
    '_editComponent',
    '_showComponentDetails',
    '_componentDetailRow',
    '_selectExpiryDate',
    '_componentTypeDisplayName',
    '_formatComponentPrice',
    '_filteredComponents',
    '_expiryBadge',
    '_componentStockBadge',
    '_matchesStockStatus'
]

for method in methods_to_remove:
    # also try arrow functions
    pattern = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?=>[^;]+;')
    match_arrow = pattern.search(h_content)
    if match_arrow:
        h_content = h_content[:match_arrow.start()] + h_content[match_arrow.end():]
        continue
        
    pattern = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?{')
    match = pattern.search(h_content)
    if not match:
        continue
    
    start_idx = match.start()
    body_start = match.end() - 1
    
    brace_count = 0
    end_idx = body_start
    for i in range(body_start, len(h_content)):
        if h_content[i] == '{':
            brace_count += 1
        elif h_content[i] == '}':
            brace_count -= 1
            if brace_count == 0:
                end_idx = i + 1
                break
    
    while end_idx < len(h_content) and h_content[end_idx] in [' ', '\t', '\n', '\r']:
        end_idx += 1
        
    h_content = h_content[:start_idx] + h_content[end_idx:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(h_content)

