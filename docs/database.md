# Database

The first migration creates tables for:

- users
- refresh_tokens
- workspaces
- categories
- specification_definitions
- locations
- suppliers
- components
- component_images
- projects
- project_components
- project_kits
- project_kit_lines
- inventory_transactions
- inventory_transaction_lines

Quantities use `NUMERIC(18, 4)`. Money values use integer minor units.

Project component quantities represent inventory consumed by a project. Increasing
a quantity posts a stock-out transaction; decreasing or removing it posts a return.
