import os

filepath_components = 'lib/features/inventory/pages/components_page.dart'
with open(filepath_components, 'r', encoding='utf-8') as f:
    c_content = f.read()

# Fix categories missing in AddComponentPanel inside ComponentsPage
c_content = c_content.replace(
    """child: AddComponentPanel(
              api: api,""",
    """child: AddComponentPanel(
              api: api,
              categories: categories,"""
)

# Fix buildImage signature: change {Widget? errorChild} to {required Widget errorChild} (actually, let's just make it Widget? and fix _inventoryImage or just make it required Widget in signature)
c_content = c_content.replace(
    """final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;""",
    """final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;""" # No change here, we will fix inventory_home instead or actually let's change components_page
)
c_content = c_content.replace(
    """required Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage,""",
    """required Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage,"""
)
# Let's change components_page to match _inventoryImage
c_content = c_content.replace(
    """Widget? errorChild}) buildImage""",
    """Widget? errorChild}) buildImage""" # wait, _inventoryImage expects {Key? key, double? width, double? height, BoxFit? fit, required Widget errorChild}. 
)
c_content = c_content.replace(
    """final Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage;""",
    """final Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage;"""
)
c_content = c_content.replace(
    """required Widget Function(String, {double? width, double? height, BoxFit? fit, Widget? errorChild}) buildImage,""",
    """required Widget Function(String, {double? width, double? height, BoxFit? fit, required Widget errorChild}) buildImage,"""
)

# Fix deprecated 'value' in DropdownButtonFormField -> use 'initialValue' (but it's a field in DropdownButtonFormField. We'll use 'value' in DropdownButtonFormField? Wait, the error says: Use initialValue instead. This feature was deprecated after v3.33.0.
c_content = c_content.replace("value: _componentType,", "initialValue: _componentType,")
c_content = c_content.replace("value: _componentLocationId,", "initialValue: _componentLocationId,")
c_content = c_content.replace("value: _componentSupplierId,", "initialValue: _componentSupplierId,")
c_content = c_content.replace("value: _componentUnit,", "initialValue: _componentUnit,")
c_content = c_content.replace("value: supplierId,", "initialValue: supplierId,")

with open(filepath_components, 'w', encoding='utf-8') as f:
    f.write(c_content)

# Now fix inventory_home.dart
filepath_home = 'lib/features/inventory_home.dart'
with open(filepath_home, 'r', encoding='utf-8') as f:
    h_content = f.read()

# Remove unused fields
unused_fields = [
    "ComponentImageSelection? _componentImage;",
    "ComponentDatasheetSelection? _componentDatasheet;",
    "String? _componentSupplierId;",
    "String? _componentLocationId;",
    "String _componentUnit = 'Pieces';",
]
for f_decl in unused_fields:
    h_content = h_content.replace(f_decl, "")

# Remove unused methods
import re
unused_methods = [
    '_filteredComponents',
    '_expiryBadge',
    '_componentStockBadge'
]
for method in unused_methods:
    pattern = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?=>[^;]+;')
    match_arrow = pattern.search(h_content)
    if match_arrow:
        h_content = h_content[:match_arrow.start()] + h_content[match_arrow.end():]
        continue
    
    pattern = re.compile(r'(?:(?:Future<[\w\s<>]*>|Widget|String|List<[\w\s<>]*>|void|bool)\??\s+)?' + re.escape(method) + r'\s*\([^)]*\)\s*(?:async\s*)?{')
    match = pattern.search(h_content)
    if match:
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

with open(filepath_home, 'w', encoding='utf-8') as f:
    f.write(h_content)

