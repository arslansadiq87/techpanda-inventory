import os

filepath = 'lib/features/inventory_home.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "onClearFilters: _clearComponentFilters,",
    """onSearchChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), _refresh);
              },
              onClearFilters: _clearComponentFilters,"""
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
