import os

filepath = 'lib/features/inventory_home.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("components: _components,", "components: _components,\n              categories: _categories,")

start = content.find("bool _matchesStockStatus")
if start != -1:
    end = content.find("}", content.find("};", start) + 2) + 1
    content = content[:start] + content[end:]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

