import sys

filepath = 'lib/features/inventory/pages/components_page.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

def replace_exact(old_str, new_str):
    global content
    if old_str not in content:
        print("ERROR: String not found!")
        print(repr(old_str[:100]))
        sys.exit(1)
    content = content.replace(old_str, new_str)

b1_old = """  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;"""
b1_new = """  final Future<void> Function() onAddLocation;
  final Future<void> Function() onEditLocations;
  final Future<void> Function() onAddSupplier;
  final Future<void> Function() onEditSuppliers;"""
replace_exact(b1_old, b1_new) # Replaces 2 instances (ComponentsPage and AddComponentPanel)

b2_old = """    required this.onEditLocations,
    required this.onAddSupplier,
  });"""
b2_new = """    required this.onEditLocations,
    required this.onAddSupplier,
    required this.onEditSuppliers,
  });"""
replace_exact(b2_old, b2_new) # Replaces 2 instances

b3_old = """              onAddLocation: onAddLocation,
              onEditLocations: onEditLocations,
              onAddSupplier: onAddSupplier,"""
b3_new = """              onAddLocation: onAddLocation,
              onEditLocations: onEditLocations,
              onAddSupplier: onAddSupplier,
              onEditSuppliers: onEditSuppliers,"""
replace_exact(b3_old, b3_new)

b4_old = """                  OutlinedButton.icon(
                    onPressed: widget.onEditLocations,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Locations'),
                  ),
                ],
              ),"""
b4_new = """                  OutlinedButton.icon(
                    onPressed: widget.onEditLocations,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Locations'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onAddSupplier,
                    icon: const Icon(Icons.domain_add),
                    label: const Text('Supplier'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onEditSuppliers,
                    icon: const Icon(Icons.business),
                    label: const Text('Suppliers'),
                  ),
                ],
              ),"""
replace_exact(b4_old, b4_new)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied to components_page successfully.")
