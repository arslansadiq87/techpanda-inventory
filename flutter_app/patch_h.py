import os

h_filepath = 'lib/features/inventory_home.dart'
with open(h_filepath, 'r', encoding='utf-8') as f:
    h_content = f.read()

h_args = """              showComponentSupplier: _showComponentSupplier,
              showComponentPrice: _showComponentPrice,
              showComponentExpiryDate: _showComponentExpiryDate,
              showComponentDatasheetFile: _showComponentDatasheetFile,
              showComponentDatasheetText: _showComponentDatasheetText,"""

h_content = h_content.replace(
    "enableEditComponent: _enableEditComponent,",
    "enableEditComponent: _enableEditComponent,\n" + h_args
)

with open(h_filepath, 'w', encoding='utf-8') as f:
    f.write(h_content)

