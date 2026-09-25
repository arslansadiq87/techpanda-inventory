import os

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add categories to ComponentsPage
content = content.replace(
    """final List<dynamic> components;
  final List<dynamic> componentTypes;""",
    """final List<dynamic> components;
  final List<dynamic> categories;
  final List<dynamic> componentTypes;"""
)

content = content.replace(
    """required this.components,
    required this.componentTypes,""",
    """required this.components,
    required this.categories,
    required this.componentTypes,"""
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

