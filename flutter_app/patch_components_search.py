import os

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "final VoidCallback onClearFilters;",
    "final ValueChanged<String>? onSearchChanged;\n  final VoidCallback onClearFilters;"
)

content = content.replace(
    "required this.onClearFilters,",
    "this.onSearchChanged,\n    required this.onClearFilters,"
)

content = content.replace(
    """  Widget _componentSearchField() {
    return TextField(
      controller: searchController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: 'Search components',
      ),
      // debounce is handled by the caller attaching listener to the controller
    );
  }""",
    """  Widget _componentSearchField() {
    return TextField(
      controller: searchController,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        labelText: 'Search components',
      ),
      onChanged: onSearchChanged,
    );
  }"""
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
