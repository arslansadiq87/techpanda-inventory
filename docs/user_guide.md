# User Guide

## Components

Open Components, search by name/code/part number, or add a new component with category, opening quantity, minimum quantity, and unit.
Open Components, search by name/code/part number, or add a new component with category, opening quantity, minimum quantity, unit, and optional price.

### Duplicate Prevention & Name Validation
To maintain inventory data integrity and avoid accidental double-entries:
- **Components**: Component names must be unique within your inventory workspace. If you attempt to add or rename a component with a name that already exists (evaluated case-insensitively and whitespace-trimmed), the system rejects the operation and alerts you (e.g. `Component '<name>' already exists as <code/id>`).
- **Suppliers**: Supplier names must be unique (case-insensitive). Adding or renaming a supplier to an existing name will be rejected with an alert (e.g. `Supplier '<name>' already exists`).
- **Component Types & Sub-Types**: Type names must be unique across the workspace (case-insensitive). Creating or renaming a type to an existing name is blocked with `Component type '<name>' already exists`.
- **Locations**: Location names must be unique (case-insensitive). Attempting to create or edit a location using an existing name is blocked with `Location '<name>' already exists`.
- **Self-Updates Allowed**: Saving other fields of an existing component, type, or location without changing its name will proceed smoothly without triggering a duplicate error.
- **Self-Updates Allowed**: Saving other fields of an existing component, type, supplier, or location without changing its name will proceed smoothly without triggering a duplicate error.
- **Offline & Cloud Consistency**: Uniqueness validation is strictly enforced whether working connected to the local API server or working offline.

### Component Types & Sub-Types (Sub-Categories)
Component types allow you to classify electronic parts (e.g. Resistors, Capacitors, Microcontrollers, Sensors). You can create hierarchical sub-types to easily organize and find specific parts.

- **Creating a Top-Level Type**:
  1. Click **+ Add component type** in the Dashboard or the component creation area.
  2. Enter the type name (e.g., `Sensors`, `Microcontrollers`, `Passive Components`).
  3. Leave **Parent type (optional)** set to `None (Top-level type)`.
  4. (Optional) Choose an SVG icon file.
  5. Click **Save**.

- **Creating a Sub-Type / Sub-Category**:
  1. Click **+ Add component type**.
  2. Enter the sub-type name (e.g., `Temperature Sensor`, `Pressure Sensor`, `Gas Sensor`).
  3. Under **Parent type (optional)**, choose the parent category from the dropdown (e.g., `Sensors`).
  4. (Optional) Choose an SVG icon.
  5. Click **Save**.

- **Hierarchical Display in Dropdowns**:
  - In the Component Filter and Add/Edit Component dialogs, sub-types are listed right beneath their parent type and displayed as `Parent / Sub-type` (e.g. `Sensors / Temperature Sensor`).

- **Hierarchical Filtering**:
  - **Filter by Parent**: Selecting a parent type (e.g., `Sensors`) in the **Component type** filter shows components assigned directly to `Sensors` as well as all components assigned to any of its sub-types (`Temperature Sensor`, `Pressure Sensor`, etc.).
  - **Filter by Sub-Type**: Selecting a specific sub-type filters strictly to components of that sub-type.

- **Editing & Managing Types and Sub-Types**:
  1. Click **Edit component types** (or the manage icon).
  2. Any sub-type displays a clear badge indicating `Sub-type of <Parent Name>`.
  3. Click the **Edit** (pencil) icon next to any type to rename it or change its parent type (move to another parent or promote to top-level).
  4. Click the upload icon to assign or replace the type's custom SVG icon.

- **Smart Category Inheritance**:
  - If a sub-type does not have a distinct system category rule, it automatically inherits the category prefix and classification of its parent type.

### Component Price
- **Adding a Price**: In the **Add component** panel (or modal), enter the unit cost in the **Price (optional)** field. Decimal values (such as `12.50` or `0.05`) are fully supported. If no price is specified, the component is created without one.
- **Editing a Price**: To update an existing component's price, click the **Edit** (pencil icon) button on the component card or row. In the dialog, update the **Price (optional)** field and click **Save**. Leaving the field blank and saving will clear the price.
- **Viewing Prices**: If a price is set, it will be displayed in:
  - The **Component details** dialog (click the eye icon).
  - The component list view subtitle.
  - The thumbnail grid card label.

### Component Datasheets
- **Uploading a Datasheet Document (Optional)**: Click **Choose datasheet** when adding or editing a component to attach a specification file (such as `.pdf`, `.txt`, `.doc`, `.docx`, or diagrams).
- **Viewing & Downloading**: In the **Component details** dialog, an **Open / Download Datasheet** button appears when a file is attached. Clicking it opens the document in your browser or PDF reader.
- **Replacing or Removing**: While editing a component, choose **Change file** to upload a revised datasheet, or click **Remove** to delete the existing attachment.
- **Catalog Indicators**: Components with an attached datasheet display a document icon (`📄`) badge in the list and thumbnail grid cards.

### Datasheet Copy-Paste & Technical Specifications (Optional)
- **Multi-Row Editor**: Use the spacious **Datasheet copy-paste / technical specifications** text editor to paste pinouts, absolute maximum ratings, circuit notes, or ASCII diagrams directly into the component record.
- **One-Click Copy**: In the **Component details** modal, technical specifications are displayed in a formatted container with a **Copy to clipboard** button for fast copying into schematics or code editors.
- **Indexed Search**: Any text pasted into this field is indexed in component search, enabling you to find components by part features, voltage ratings, or pin names.

### Expiry Date (e.g., Batteries & Chemical Consumables)
- **Setting an Expiry Date (Optional)**: Click the **Expiry date** field to launch the calendar date picker. Choose a date formatted as `YYYY-MM-DD`. Use the **✕** button to clear the date at any time.
- **Status Badges & Visual Alerts**:
  - **Active (Green)**: Components with healthy expiration dates show a green badge (e.g., `Exp: 2028-06-30`).
  - **Expiring Soon (Amber Warning)**: Items expiring within 30 days display an alert badge with countdown (e.g., `Expiring in 18 d`).
  - **Expired (Red Alert)**: Items whose expiration date has passed display a prominent red warning (e.g., `Expired (2026-08-15)`).
  - Visible on component list tiles, thumbnail cards, and the component details view.

## Suppliers

Manage vendors and distributors (e.g., DigiKey, Mouser, LCSC, Adafruit, SparkFun) and optionally track where each electronic component was sourced from.

### Creating Suppliers
- **From Quick Actions**: Click the **Supplier** button in the **Add component** panel to open the quick supplier dialog.
- **Inline While Adding a Component**: In the **Add component** panel, click the `+` icon next to the **Supplier (optional)** dropdown to create a supplier immediately without leaving your component workflow.
- **Supplier Details**:
  - **Supplier name**: Required. Must be unique (case-insensitive duplicate checking prevents accidental duplicates).
  - **Website URL (optional)**: e.g. `https://www.digikey.com`.
  - **Contact info (optional)**: Email, phone number, or sales representative info.
  - **Notes (optional)**: Account numbers, delivery terms, or notes.

### Managing & Editing Suppliers
- Click the **Suppliers** button in the **Add component** panel to view the complete list of registered suppliers.
- Click the **Edit** (pencil) icon next to any supplier to update its name, website, contact details, or notes.
- Click **Add supplier** from within the supplier manager to add more suppliers at any time.

### Associating Suppliers with Components
- **Optional Association**: When creating or editing any component, the **Supplier (optional)** field allows choosing a registered supplier or leaving it as `No supplier`.
- **Displaying Suppliers**:
  - **Component Cards & List**: If a component has an assigned supplier, the supplier name appears in the component card subtitle (e.g. `• DigiKey`) and list view details.
  - **Component Details Modal**: The full supplier name is shown under the Supplier field in the details dialog (click the eye icon).

### Filtering Components by Supplier
- Use the **Supplier** dropdown in the component filter bar (next to Location and Unit filters) to filter components by a specific supplier or select **All suppliers** to clear the filter.

## Locations & QR Codes

Organize components into physical storage locations (e.g. shelves, bins, cabinets, racks, or rooms).

### Creating & Managing Location QR Codes
- **Add QR Code Toggle**: When adding a new location (via the **Add location** modal or quick-add), an **Add QR Code** switch is enabled by default. Leaving this enabled generates an official, unique QR code for the location upon creation.
- **Viewing & Downloading QR Codes**:
  1. Open the Location manager (click the location selector dropdown and choose **Manage locations**, or use the location settings icon).
  2. Next to each location item, click the **QR Code** button (QR icon).
  3. A preview dialog will open displaying the QR code, location name, and identifier.
  4. Click **Download PNG** to save a high-resolution, printable image file (`location_<name>_qr.png`).
  5. Print this image and paste the label onto your physical drawer, bin, box, or shelf.

### Scanning Location QR Codes
Use the QR scanner to instantly identify which components are stored at any physical location.
- **Opening the Scanner**: Click the **Scan QR** button in the top navigation bar or the QR scanner icon next to the Component search box.
- **Scanning Methods Supported**:
  1. **Camera Scanner**: Point your device webcam or mobile camera at the printed location QR code label.
  2. **Image Upload**: Click **Upload Image** to decode a QR code from a saved picture or screenshot.
  3. **Barcode Gun / Manual Entry**: If using a USB/Bluetooth handheld 2D barcode gun, scan directly into the text field, or type the code / location name and press Enter.
- **Automatic Filtering**:
  - Once recognized, the app automatically switches to the **Components** catalog.
  - The view filters dynamically to display **only the components stored in that scanned location**.
  - A location badge is shown above the component list. Click the **✕** button on the badge or reset the location dropdown to clear the filter and view all components again.



## Stock

Use Stock for Stock In, Stock Out, Return, and Loss. If the local API is not running, save the transaction as an offline draft and sync it after starting the API again.

Recent manual movements can be edited or deleted as a whole. Editing loads all
saved lines back into the Stock form. Deleting reverses every inventory line and
is refused when reversing a stock-in would make current inventory negative.
Project-generated movements are locked and must be changed from their project.

## Projects

Create a project, open it, and search for inventory components directly on the
project page. Selecting a search result adds it to the working list immediately.
Adjust each quantity, remove unwanted draft lines, and choose **Save all** to
apply the complete project component list atomically. Increased quantities are
deducted from inventory; decreased or removed quantities are returned.

## Reports

Download the complete inventory as CSV or PDF from Reports. CSV exports include
an image URL and the original image dimensions. PDF exports include a clearly
sized component thumbnail and the original image dimensions.

## Backups

Backups are stored under `local_data/backups`.
