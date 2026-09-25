import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_tools;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/api_client.dart';
import 'inventory/widgets/brand_header.dart';
import 'inventory/widgets/error_banner.dart';
import 'inventory/widgets/inventory_badges.dart';
import 'inventory/widgets/stock_alerts_panel.dart';
import 'inventory/dialogs/scanner_modal.dart';
import 'inventory/dialogs/supplier_dialogs.dart';
import 'inventory/dialogs/location_dialogs.dart';
import 'inventory/dialogs/component_type_dialogs.dart';
import 'inventory/pages/login_page.dart';
import 'inventory/pages/dashboard_page.dart';
import 'inventory/pages/components_page.dart';

import 'inventory/pages/reports_page.dart';
import 'inventory/pages/settings_page.dart';
import 'inventory/services/remote_sync_service.dart';
import '../core/web_image_picker_stub.dart'
    if (dart.library.html) '../core/web_image_picker_web.dart';

const componentUnits = [
  'Pieces',
  'Meters',
  'Centimeters',
  'Millimeters',
  'Feet',
  'Inches',
  'Yards',
  'Kilograms',
  'Grams',
  'Milligrams',
  'Liters',
  'Milliliters',
  'Rolls',
  'Spools',
  'Sets',
  'Other',
];

const techPandaYoutubeUrl = 'https://www.youtube.com/@TechPanda-4k';

class ComponentImageSelection {
  const ComponentImageSelection({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ComponentDatasheetSelection {
  const ComponentDatasheetSelection({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class StockLineDraft {
  StockLineDraft({required this.component, String quantity = '1'})
    : quantityController = TextEditingController(text: quantity);

  final Map<String, dynamic> component;
  final TextEditingController quantityController;
}

class InventoryHome extends StatefulWidget {
  const InventoryHome({
    super.key,
    required this.api,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  final ApiClient api;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<InventoryHome> createState() => _InventoryHomeState();
}

class _InventoryHomeState extends State<InventoryHome> {
  final _username = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _search = TextEditingController();
  final _componentName = TextEditingController();
  final _componentPrice = TextEditingController();
  final _componentDatasheetText = TextEditingController();
  final _componentExpiryDate = TextEditingController();
  final _openingQuantity = TextEditingController(text: '0');
  final _minimumQuantity = TextEditingController(text: '0');
  final _projectName = TextEditingController();
  final _newProjectDescription = TextEditingController();
  final _activeProjectDescription = TextEditingController();
  final _componentDetails = TextEditingController();
  final _componentManufacturer = TextEditingController();
  final _imagePicker = ImagePicker();
  final _stockPageController = ScrollController();
  TextEditingController? _stockSearchController;
  TextEditingController? _projectSearchController;

  Timer? _debounce;
  bool _loading = true;
  bool _loggedIn = false;
  bool _rememberCredentials = false;
  bool _displayComponentImages = true;
  bool _enableAddComponent = true;
  bool _enableEditComponent = true;
  bool _showComponentSupplier = true;
  bool _showComponentPrice = true;
  bool _showComponentExpiryDate = true;
  bool _showComponentDatasheetFile = true;
  bool _showComponentDatasheetText = true;
  List<dynamic> _alerts = [];
  Set<String> _readAlertComponentIds = {};
  bool _showAlertsPanel = false;
  bool _showAllStockComponents = false;
  bool _showAllProjectComponents = false;
  bool _showMobileComponentFilters = false;
  int _selected = 0;
  int _mobileSelected = 0;
  String? _exportingProjectId;
  String? _error;
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _categories = [];
  List<dynamic> _componentTypes = [];
  List<dynamic> _locations = [];
  List<dynamic> _components = [];
  List<dynamic> _transactions = [];
  int _transactionPage = 1;
  static const int _transactionPageSize = 25;
  String? _transactionComponentId;
  List<dynamic> _suppliers = [];

  final Map<String, Map<String, dynamic>> _movementDetails = {};
  final Set<String> _expandedMovementIds = {};
  final Set<String> _loadingMovementIds = {};
  final Map<String, String> _movementDetailErrors = {};
  List<dynamic> _projects = [];
  final Map<String, List<Map<String, dynamic>>> _projectListComponents = {};
  final Set<String> _expandedProjectIds = {};
  final Set<String> _loadingProjectListIds = {};
  final Map<String, String> _projectListErrors = {};
  final List<StockLineDraft> _stockLines = [];
  final List<StockLineDraft> _projectDraftLines = [];
  String? _selectedCategoryId;
  String? _selectedComponentId;
  String? _componentType;

  String? _filterComponentType;
  String? _filterLocationId;
  String? _filterUnit;
  String _filterStockStatus = 'All';
  String _componentViewMode = 'List';
  String _projectViewMode = 'List';

  String _stockMode = 'stock_in';
  Map<String, dynamic>? _editingTransaction;
  Map<String, dynamic>? _activeProject;
  bool _loadingProjectComponents = false;
  bool _savingProjectComponents = false;
  bool _projectComponentsDirty = false;
  bool _savingProjectDescription = false;
  bool _projectDescriptionDirty = false;
  bool _uploadingProjectImage = false;

  late final RemoteSyncService _syncService = RemoteSyncService(
    api: widget.api,
  );

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    for (final controller in [
      _username,
      _password,
      _search,
      _componentName,
      _componentPrice,
      _componentDatasheetText,
      _componentExpiryDate,
      _openingQuantity,
      _minimumQuantity,
      _projectName,
      _newProjectDescription,
      _activeProjectDescription,
      _componentDetails,
      _componentManufacturer,
    ]) {
      controller.dispose();
    }
    for (final line in _stockLines) {
      line.quantityController.dispose();
    }
    for (final line in _projectDraftLines) {
      line.quantityController.dispose();
    }
    _stockPageController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    final loggedIn = await widget.api.restoreSession();
    final prefs = await SharedPreferences.getInstance();
    _rememberCredentials = prefs.getBool('remember_credentials') ?? false;
    _displayComponentImages = prefs.getBool('display_component_images') ?? true;
    _enableAddComponent = prefs.getBool('enable_add_component') ?? true;
    _enableEditComponent = prefs.getBool('enable_edit_component') ?? true;
    _showComponentSupplier = prefs.getBool('show_component_supplier') ?? true;
    _showComponentPrice = prefs.getBool('show_component_price') ?? true;
    _showComponentExpiryDate =
        prefs.getBool('show_component_expiry_date') ?? true;
    _showComponentDatasheetFile =
        prefs.getBool('show_component_datasheet_file') ?? true;
    _showComponentDatasheetText =
        prefs.getBool('show_component_datasheet_text') ?? true;
    _componentViewMode = prefs.getString('component_view_mode') == 'Thumbnails'
        ? 'Thumbnails'
        : 'List';
    _projectViewMode = prefs.getString('project_view_mode') == 'Thumbnails'
        ? 'Thumbnails'
        : 'List';
    if (_rememberCredentials) {
      _username.text = _usernameOnly(prefs.getString('saved_login') ?? 'admin');
      _password.text = prefs.getString('saved_password') ?? 'admin';
    }
    final savedReadAlerts =
        prefs.getStringList('read_alert_component_ids') ?? [];
    _readAlertComponentIds = savedReadAlerts.toSet();

    setState(() {
      _loggedIn = loggedIn;
      _loading = false;
    });
    if (loggedIn) await _refresh();
  }

  Future<void> _setDisplayComponentImages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('display_component_images', value);
    setState(() => _displayComponentImages = value);
  }

  Future<void> _setEnableAddComponent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_add_component', value);
    setState(() => _enableAddComponent = value);
  }

  Future<void> _setEnableEditComponent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_edit_component', value);
    setState(() => _enableEditComponent = value);
  }

  Future<void> _setShowComponentSupplier(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_component_supplier', value);
    setState(() => _showComponentSupplier = value);
  }

  Future<void> _setShowComponentPrice(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_component_price', value);
    setState(() => _showComponentPrice = value);
  }

  Future<void> _setShowComponentExpiryDate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_component_expiry_date', value);
    setState(() => _showComponentExpiryDate = value);
  }

  Future<void> _setShowComponentDatasheetFile(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_component_datasheet_file', value);
    setState(() => _showComponentDatasheetFile = value);
  }

  Future<void> _setShowComponentDatasheetText(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_component_datasheet_text', value);
    setState(() => _showComponentDatasheetText = value);
  }

  void _clearComponentFilters() {
    setState(() {
      _filterComponentType = null;
      _filterLocationId = null;
      _filterUnit = null;
      _filterStockStatus = 'All';
    });
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.api.dashboard(),
        widget.api.categories(),
        widget.api.componentTypes(),
        widget.api.locations(),
        widget.api.components(query: _search.text),
        widget.api.transactionsPage(
          page: _transactionPage,
          limit: _transactionPageSize,
          componentId: _transactionComponentId,
        ),
        widget.api.projects(),
        widget.api.suppliers(),
        widget.api.alerts(),
      ]);
      setState(() {
        _dashboard = results[0] as Map<String, dynamic>;
        _categories = results[1] as List<dynamic>;
        _componentTypes = _sortedByText(results[2] as List<dynamic>, 'name');
        _componentTypes = _hierarchicallySortedTypes(
          results[2] as List<dynamic>,
        );
        _locations = _sortedByText(results[3] as List<dynamic>, 'display_name');
        _components = results[4] as List<dynamic>;
        _transactions = results[5] as List<dynamic>;
        _projects = results[6] as List<dynamic>;
        _suppliers = _sortedByText(results[7] as List<dynamic>, 'name');
        _alerts = results.length > 8 ? (results[8] as List<dynamic>) : [];
        final currentAlertIds = _alerts
            .map(
              (a) => (a is Map)
                  ? (a['component_id'] ?? a['id'])?.toString()
                  : null,
            )
            .whereType<String>()
            .toSet();
        _readAlertComponentIds.removeWhere(
          (id) => !currentAlertIds.contains(id),
        );
        _selectedCategoryId ??= _categories.isNotEmpty
            ? _categories.first['id'] as String
            : null;
        _componentType ??= _componentTypes.isNotEmpty
            ? _componentTypes.first['name'] as String
            : null;
        _selectedComponentId ??= _components.isNotEmpty
            ? _components.first['id'] as String
            : null;
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  List<dynamic> _sortedByText(List<dynamic> items, String key) {
    final sorted = List<dynamic>.from(items);
    sorted.sort((left, right) {
      final leftText = ((left as Map)[key] as String? ?? '').toLowerCase();
      final rightText = ((right as Map)[key] as String? ?? '').toLowerCase();
      return leftText.compareTo(rightText);
    });
    return sorted;
  }

  List<dynamic> _hierarchicallySortedTypes(List<dynamic> types) {
    final parentMap = <String?, List<Map<String, dynamic>>>{};
    for (final raw in types) {
      final item = Map<String, dynamic>.from(raw as Map);
      final parentId = item['parent_type_id'] as String?;
      parentMap.putIfAbsent(parentId, () => []).add(item);
    }
    for (final list in parentMap.values) {
      list.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );
    }
    final result = <Map<String, dynamic>>[];
    final rootItems = parentMap[null] ?? [];
    for (final root in rootItems) {
      result.add(root);
      final children = parentMap[root['id'] as String] ?? [];
      for (final child in children) {
        result.add(child);
      }
    }
    for (final raw in types) {
      final item = Map<String, dynamic>.from(raw as Map);
      if (!result.any((r) => r['id'] == item['id'])) {
        result.add(item);
      }
    }
    return result;
  }

  Future<void> _login() async {
    try {
      await widget.api.login(_usernameOnly(_username.text), _password.text);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_credentials', _rememberCredentials);
      if (_rememberCredentials) {
        await prefs.setString('saved_login', _usernameOnly(_username.text));
        await prefs.setString('saved_password', _password.text);
      } else {
        await prefs.remove('saved_login');
        await prefs.remove('saved_password');
      }
      setState(() => _loggedIn = true);
      await _refresh();
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  String _usernameOnly(String value) => value.trim().split('@').first;

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Good night';
  }

  bool get _canCaptureComponentImage =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<ComponentImageSelection?> _pickComponentImage() =>
      _selectComponentImage(ImageSource.gallery);

  Future<ComponentImageSelection?> _captureComponentImage() =>
      _selectComponentImage(ImageSource.camera);

  Future<ComponentImageSelection?> _selectComponentImage(
    ImageSource source,
  ) async {
    try {
      if (kIsWeb && source == ImageSource.gallery) {
        final file = await pickWebImageFile();
        if (file == null) return null;
        return _prepareComponentImage(file.name, file.bytes);
      }

      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (picked == null) return null;
      final bytes = await picked.readAsBytes();
      return _prepareComponentImage(picked.name, bytes);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    }
  }

  ComponentImageSelection _prepareComponentImage(
    String originalName,
    Uint8List bytes,
  ) {
    final decoded = image_tools.decodeImage(bytes);
    if (decoded == null) {
      return ComponentImageSelection(name: originalName, bytes: bytes);
    }

    final oriented = image_tools.bakeOrientation(decoded);
    const maxDimension = 1280;
    final longestSide = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    final resized = longestSide > maxDimension
        ? image_tools.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? maxDimension : null,
            height: oriented.height > oriented.width ? maxDimension : null,
            interpolation: image_tools.Interpolation.average,
          )
        : oriented;
    final jpg = Uint8List.fromList(image_tools.encodeJpg(resized, quality: 78));
    final baseName = originalName.replaceFirst(RegExp(r'\.[^.]*$'), '');
    return ComponentImageSelection(name: '$baseName.jpg', bytes: jpg);
  }

  Future<void> _uploadSelectedImage(
    String componentId,
    ComponentImageSelection? image,
  ) async {
    if (image == null) return;
    await widget.api.uploadComponentImage(componentId, image.name, image.bytes);
  }

  Future<ComponentDatasheetSelection?> _pickComponentDatasheet() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select datasheet file',
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'txt',
          'doc',
          'docx',
          'rtf',
          'csv',
          'tsv',
          'png',
          'jpg',
          'jpeg',
        ],
        withData: true,
      );
      final file = result?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return null;
      return ComponentDatasheetSelection(name: file.name, bytes: bytes);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    }
  }

  Future<void> _uploadSelectedDatasheet(
    String componentId,
    ComponentDatasheetSelection? datasheet,
  ) async {
    if (datasheet == null) return;
    await widget.api.uploadComponentDatasheet(
      componentId,
      datasheet.name,
      datasheet.bytes,
    );
  }

  Future<void> _showComponentImage(Map<String, dynamic> component) async {
    try {
      final images = await widget.api.componentImages(
        component['id'] as String,
      );
      if (!mounted) return;
      if (images.isEmpty) {
        setState(() => _error = 'No images found for this component.');
        return;
      }
      final image = images.first as Map<String, dynamic>;
      final path =
          image['preview'] as String? ??
          image['preview_url'] as String? ??
          image['thumbnail'] as String? ??
          image['thumbnail_url'] as String? ??
          component['primary_image_thumbnail'] as String?;
      if (path == null) {
        setState(() => _error = 'No image preview is available.');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          component['name'] as String? ?? 'Component image',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: _inventoryImage(
                      path,
                      fit: BoxFit.contain,
                      errorChild: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Unable to load image.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Widget _componentThumbnail(
    Map<String, dynamic> component, {
    required double size,
    IconData fallbackIcon = Icons.memory,
  }) {
    final thumbnail = component['primary_image_thumbnail'] as String?;
    if (!_displayComponentImages || thumbnail == null) {
      return SizedBox(width: size, height: size, child: Icon(fallbackIcon));
    }

    return InkWell(
      onTap: () => _showComponentImage(component),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _inventoryImage(
          thumbnail,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorChild: SizedBox(
            width: size,
            height: size,
            child: const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }

  Widget _componentCardImage(Map<String, dynamic> component) {
    final imagePath =
        component['primary_image_preview'] as String? ??
        component['primary_image_thumbnail'] as String?;
    if (!_displayComponentImages || imagePath == null) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.memory, size: 42)),
      );
    }

    return InkWell(
      onTap: () => _showComponentImage(component),
      child: _inventoryImage(
        imagePath,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorChild: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image, size: 42)),
        ),
      ),
    );
  }

  Widget _inventoryImage(
    String path, {
    Key? key,
    double? width,
    double? height,
    BoxFit? fit,
    required Widget errorChild,
  }) {
    final bytes = _decodeDataImage(path);
    if (bytes != null) {
      return Image.memory(
        bytes,
        key: key,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorChild,
      );
    }
    return Image.network(
      widget.api.mediaUrl(path),
      key: key,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => errorChild,
    );
  }

  Uint8List? _decodeDataImage(String path) {
    final marker = ';base64,';
    if (!path.startsWith('data:image/') || !path.contains(marker)) return null;
    try {
      return base64Decode(path.substring(path.indexOf(marker) + marker.length));
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAddComponentModal() async {
    if (!_enableAddComponent) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalContext) {
        final bottomInset = MediaQuery.viewInsetsOf(modalContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            child: AddComponentPanel(
              api: widget.api,
              categories: _categories,
              componentTypes: _componentTypes,
              locations: _locations,
              suppliers: _suppliers,
              canCaptureImage: _canCaptureComponentImage,
              showComponentSupplier: _showComponentSupplier,
              showComponentPrice: _showComponentPrice,
              showComponentExpiryDate: _showComponentExpiryDate,
              showComponentDatasheetFile: _showComponentDatasheetFile,
              showComponentDatasheetText: _showComponentDatasheetText,
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
              onEditSuppliers: _editSuppliers,
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteComponent(Map<String, dynamic> component) async {
    if (component['can_delete'] != true) {
      setState(() {
        _error =
            'This component has stock movement or project history and cannot be deleted.';
      });
      return;
    }
    final componentId = component['id'] as String;
    final componentName = component['name'] as String? ?? 'this component';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete component'),
        content: Text(
          'Delete $componentName? This removes it from the component list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteComponent(componentId);
      setState(() {
        if (_selectedComponentId == componentId) {
          _selectedComponentId = null;
        }
        for (final line
            in _stockLines
                .where((line) => line.component['id'] == componentId)
                .toList()) {
          _removeStockLine(line);
        }
      });
      await _refresh();
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _addComponentType() => ComponentTypeDialogs.addComponentType(
    context: context,
    api: widget.api,
    componentTypesProvider: () => _componentTypes,
    onRefresh: _refresh,
  );

  Future<void> _editComponentTypes() => ComponentTypeDialogs.editComponentTypes(
    context: context,
    api: widget.api,
    componentTypesProvider: () => _componentTypes,
    components: _components,
    onRefresh: _refresh,
  );

  Future<void> _saveLocation({Map<String, dynamic>? location}) =>
      LocationDialogs.saveLocation(
        context: context,
        api: widget.api,
        components: _components,
        locations: _locations,
        onRefresh: _refresh,
        location: location,
      );

  Future<void> _saveSupplier({Map<String, dynamic>? supplier}) =>
      SupplierDialogs.saveSupplier(
        context: context,
        api: widget.api,
        onRefresh: _refresh,
        supplier: supplier,
      );

  Future<void> _editSuppliers() => SupplierDialogs.editSuppliers(
    context: context,
    api: widget.api,
    suppliersProvider: () => _suppliers,
    onRefresh: _refresh,
  );

  Future<void> _editLocations() => LocationDialogs.editLocations(
    context: context,
    api: widget.api,
    locationsProvider: () => _locations,
    components: _components,
    onRefresh: _refresh,
    onOpenScanner: _showScannerModal,
  );

  void _handleScannedCode(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) return;

    final locMatch = _locations.cast<Map<String, dynamic>?>().firstWhere((loc) {
      if (loc == null) return false;
      final qr = loc['qr_code_value'] as String?;
      final id = loc['id'] as String?;
      final name = (loc['name'] as String?)?.toLowerCase();
      final display = (loc['display_name'] as String?)?.toLowerCase();
      final target = code.toLowerCase();
      return (qr != null && qr.toLowerCase() == target) ||
          (id != null &&
              (id.toLowerCase() == target ||
                  'location:'.toLowerCase() == target)) ||
          (name != null && name == target) ||
          (display != null && display == target);
    }, orElse: () => null);

    if (locMatch != null) {
      final locId = locMatch['id'] as String;
      final locName =
          locMatch['display_name'] as String? ??
          locMatch['name'] as String? ??
          'Location';
      final count = _components
          .where((item) => item['location_id'] == locId)
          .length;

      setState(() {
        _filterLocationId = locId;
        _search.clear();
        _selected = 1;
        _mobileSelected = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Showing components in "$locName" ($count component${count == 1 ? '' : 's'} found)',
          ),
          action: SnackBarAction(
            label: 'Clear filter',
            onPressed: () => setState(() => _filterLocationId = null),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final compMatch = _components.cast<Map<String, dynamic>?>().firstWhere((
      comp,
    ) {
      if (comp == null) return false;
      final barcode = comp['barcode'] as String?;
      final invCode = comp['inventory_code'] as String?;
      final target = code.toLowerCase();
      return (barcode != null && barcode.toLowerCase() == target) ||
          (invCode != null && invCode.toLowerCase() == target);
    }, orElse: () => null);

    if (compMatch != null) {
      setState(() {
        _selected = 1;
        _mobileSelected = 1;
      });
      ComponentDetailModal.show(
        context,
        compMatch,
        api: widget.api,
        showComponentSupplier: _showComponentSupplier,
        showComponentPrice: _showComponentPrice,
        showComponentExpiryDate: _showComponentExpiryDate,
        showComponentDatasheetFile: _showComponentDatasheetFile,
        showComponentDatasheetText: _showComponentDatasheetText,
        buildImage: _inventoryImage,
        onShowComponentImage: _showComponentImage,
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No location or component found matching ""')),
    );
  }

  Future<void> _showScannerModal() =>
      ScannerModal.show(context: context, onCodeScanned: _handleScannedCode);

  Future<void> _postStock() async {
    if (_stockLines.isEmpty) {
      setState(() => _error = 'Select at least one component.');
      return;
    }
    final lines = _stockLines
        .map(
          (line) => {
            'component_id': line.component['id'],
            'quantity': line.quantityController.text.trim().isEmpty
                ? '1'
                : line.quantityController.text.trim(),
          },
        )
        .toList();
    final editing = _editingTransaction;
    final payload = <String, dynamic>{
      'transaction_type': _stockMode,
      'lines': lines,
    };
    if (editing == null) {
      payload['idempotency_key'] = const Uuid().v4();
    }
    try {
      if (editing == null) {
        await widget.api.postTransaction(payload);
      } else {
        await widget.api.updateTransaction(editing['id'] as String, payload);
        final movementId = editing['id'] as String;
        _movementDetails.remove(movementId);
        _expandedMovementIds.remove(movementId);
        _movementDetailErrors.remove(movementId);
      }
      _clearStockLines();
      _editingTransaction = null;
      await _refresh();
    } on ApiException catch (error) {
      setState(() => _error = error.toString());
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _editStockMovement(Map<String, dynamic> movement) async {
    try {
      final detail = await widget.api.transaction(movement['id'] as String);
      final mode = detail['transaction_type'] as String;
      if (!{'stock_in', 'stock_out', 'return', 'loss'}.contains(mode)) {
        setState(() {
          _error = 'This movement type cannot be edited from the Stock form.';
        });
        return;
      }
      final lines = (detail['lines'] as List<dynamic>).map((item) {
        final line = Map<String, dynamic>.from(item as Map);
        return StockLineDraft(
          component: {
            'id': line['component_id'],
            'inventory_code': line['inventory_code'],
            'name': line['component_name'],
            'package_type': line['package_type'],
            'manufacturer': line['manufacturer'],
            'location_name': line['location_name'],
            'current_quantity': line['available_quantity'],
            'unit': line['unit'],
            'primary_image_thumbnail': line['primary_image_thumbnail'],
          },
          quantity: _formatComponentQuantity(line['quantity']),
        );
      }).toList();
      _clearStockLines();
      if (!mounted) return;
      setState(() {
        _editingTransaction = detail;
        _stockMode = mode;
        _stockLines.addAll(lines);
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_stockPageController.hasClients) {
          _stockPageController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleStockMovementDetails(
    Map<String, dynamic> movement,
  ) async {
    final movementId = movement['id'] as String;
    if (_expandedMovementIds.contains(movementId)) {
      setState(() => _expandedMovementIds.remove(movementId));
      return;
    }
    setState(() => _expandedMovementIds.add(movementId));
    if (!_movementDetails.containsKey(movementId)) {
      await _loadStockMovementDetails(movementId);
    }
  }

  Future<void> _loadStockMovementDetails(String movementId) async {
    if (_loadingMovementIds.contains(movementId)) return;
    setState(() {
      _loadingMovementIds.add(movementId);
      _movementDetailErrors.remove(movementId);
    });
    try {
      final detail = await widget.api.transaction(movementId);
      if (!mounted) return;
      setState(() => _movementDetails[movementId] = detail);
    } catch (error) {
      if (mounted) {
        setState(() => _movementDetailErrors[movementId] = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingMovementIds.remove(movementId));
    }
  }

  void _cancelStockMovementEdit() {
    _clearStockLines();
    setState(() {
      _editingTransaction = null;
      _error = null;
    });
  }

  Future<void> _deleteStockMovement(Map<String, dynamic> movement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entire stock movement?'),
        content: Text(
          '${movement['transaction_code']} will be removed and all '
          '${movement['line_count']} inventory line'
          '${movement['line_count'] == 1 ? '' : 's'} will be reversed. '
          'This may be refused if later stock usage would make inventory negative.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete movement'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteTransaction(movement['id'] as String);
      final movementId = movement['id'] as String;
      _movementDetails.remove(movementId);
      _expandedMovementIds.remove(movementId);
      _movementDetailErrors.remove(movementId);
      if (_editingTransaction?['id'] == movement['id']) {
        _clearStockLines();
        _editingTransaction = null;
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _addStockLine(Map<String, dynamic> component) {
    final id = component['id'] as String;
    if (_stockLines.any((line) => line.component['id'] == id)) return;
    _stockLines.add(
      StockLineDraft(component: Map<String, dynamic>.from(component)),
    );
  }

  void _removeStockLine(StockLineDraft line) {
    line.quantityController.dispose();
    _stockLines.remove(line);
  }

  void _clearStockLines() {
    for (final line in _stockLines) {
      line.quantityController.dispose();
    }
    _stockLines.clear();
  }

  void _adjustStockLineQuantity(StockLineDraft line, int delta) {
    final current = double.tryParse(line.quantityController.text.trim()) ?? 0;
    final next = current + delta;
    line.quantityController.text = _formatStockQuantity(next <= 0 ? 1 : next);
  }

  String _formatStockQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _createProject() async {
    if (_projectName.text.trim().isEmpty) return;
    try {
      await widget.api.createProject({
        'name': _projectName.text.trim(),
        'project_type': 'YouTube Video',
        'status': 'To Do',
        'description': _newProjectDescription.text.trim().isEmpty
            ? null
            : _newProjectDescription.text.trim(),
      });
      _projectName.clear();
      _newProjectDescription.clear();
      await _refresh();
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  Future<void> _openProject(Map<String, dynamic> project) async {
    _clearProjectDraftLines();
    _activeProjectDescription.text = project['description'] as String? ?? '';
    setState(() {
      _activeProject = Map<String, dynamic>.from(project);
      _projectComponentsDirty = false;
      _projectDescriptionDirty = false;
    });
    await _loadProjectComponents();
  }

  Future<void> _toggleProjectListComponents(
    Map<String, dynamic> project,
  ) async {
    final projectId = project['id'] as String;
    if (_expandedProjectIds.contains(projectId)) {
      setState(() => _expandedProjectIds.remove(projectId));
      return;
    }
    setState(() => _expandedProjectIds.add(projectId));
    if (!_projectListComponents.containsKey(projectId)) {
      await _loadProjectListComponents(projectId);
    }
  }

  Future<void> _loadProjectListComponents(String projectId) async {
    if (_loadingProjectListIds.contains(projectId)) return;
    setState(() {
      _loadingProjectListIds.add(projectId);
      _projectListErrors.remove(projectId);
    });
    try {
      final items = await widget.api.projectComponents(projectId);
      if (!mounted) return;
      final components = items
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      setState(() => _projectListComponents[projectId] = components);
    } catch (error) {
      if (mounted) {
        setState(() => _projectListErrors[projectId] = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loadingProjectListIds.remove(projectId));
    }
  }

  Future<void> _loadProjectComponents() async {
    final project = _activeProject;
    if (project == null) return;
    setState(() {
      _loadingProjectComponents = true;
      _error = null;
    });
    try {
      final items = await widget.api.projectComponents(project['id'] as String);
      if (!mounted || _activeProject?['id'] != project['id']) return;
      final lines = items.map((item) {
        final projectLine = Map<String, dynamic>.from(item as Map);
        return StockLineDraft(
          component: _projectLineAsComponent(projectLine),
          quantity: _formatComponentQuantity(projectLine['quantity']),
        );
      }).toList();
      _clearProjectDraftLines();
      setState(() {
        _projectDraftLines.addAll(lines);
        _projectComponentsDirty = false;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted && _activeProject?['id'] == project['id']) {
        setState(() => _loadingProjectComponents = false);
      }
    }
  }

  Future<void> _reloadProjectInventory() async {
    await _refresh();
    await _loadProjectComponents();
  }

  Future<void> _saveProjectComponents() async {
    final project = _activeProject;
    if (project == null || _savingProjectComponents) return;
    final lines = <Map<String, dynamic>>[];
    for (final line in _projectDraftLines) {
      final quantity = double.tryParse(line.quantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        setState(() {
          _error =
              'Every project component must have a quantity greater than zero.';
        });
        return;
      }
      lines.add({
        'component_id': line.component['id'],
        'quantity': line.quantityController.text.trim(),
      });
    }
    setState(() {
      _savingProjectComponents = true;
      _error = null;
    });
    try {
      await widget.api.replaceProjectComponents(project['id'] as String, lines);
      final projectId = project['id'] as String;
      _projectListComponents.remove(projectId);
      _expandedProjectIds.remove(projectId);
      _projectListErrors.remove(projectId);
      await _reloadProjectInventory();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _savingProjectComponents = false);
    }
  }

  Map<String, dynamic> _projectLineAsComponent(
    Map<String, dynamic> projectLine,
  ) {
    return {
      'id': projectLine['component_id'],
      'name': projectLine['component_name'],
      'inventory_code': projectLine['inventory_code'],
      'package_type': projectLine['package_type'],
      'manufacturer': projectLine['manufacturer'],
      'location_name': projectLine['location_name'],
      'unit': projectLine['unit'],
      'current_quantity': projectLine['available_quantity'],
      'primary_image_thumbnail': projectLine['primary_image_thumbnail'],
    };
  }

  void _addProjectDraftLine(Map<String, dynamic> component) {
    final id = component['id'] as String;
    if (_projectDraftLines.any((line) => line.component['id'] == id)) return;
    _projectDraftLines.add(
      StockLineDraft(component: Map<String, dynamic>.from(component)),
    );
    _projectComponentsDirty = true;
  }

  void _removeProjectDraftLine(StockLineDraft line) {
    line.quantityController.dispose();
    _projectDraftLines.remove(line);
    _projectComponentsDirty = true;
  }

  void _clearProjectDraftLines() {
    for (final line in _projectDraftLines) {
      line.quantityController.dispose();
    }
    _projectDraftLines.clear();
  }

  void _adjustProjectDraftQuantity(StockLineDraft line, int delta) {
    final current = double.tryParse(line.quantityController.text.trim()) ?? 0;
    final next = current + delta;
    line.quantityController.text = _formatStockQuantity(next <= 0 ? 1 : next);
    _projectComponentsDirty = true;
  }

  Future<void> _closeProject() async {
    if (_projectComponentsDirty || _projectDescriptionDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          content: const Text(
            'The project description or component quantities have not been saved yet.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    _clearProjectDraftLines();
    if (!mounted) return;
    setState(() {
      _activeProject = null;
      _projectComponentsDirty = false;
      _projectDescriptionDirty = false;
      _error = null;
    });
  }

  Future<void> _saveProjectDescription() async {
    final project = _activeProject;
    if (project == null || _savingProjectDescription) return;
    setState(() {
      _savingProjectDescription = true;
      _error = null;
    });
    try {
      final updated = await widget.api.updateProject(project['id'] as String, {
        'description': _activeProjectDescription.text.trim().isEmpty
            ? null
            : _activeProjectDescription.text.trim(),
      });
      if (!mounted) return;
      final updatedProject = Map<String, dynamic>.from(updated);
      final index = _projects.indexWhere(
        (item) => (item as Map)['id'] == updatedProject['id'],
      );
      setState(() {
        _activeProject = updatedProject;
        if (index >= 0) _projects[index] = updatedProject;
        _projectDescriptionDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project description saved.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _savingProjectDescription = false);
    }
  }

  Future<void> _editProject(Map<String, dynamic> project) async {
    final name = TextEditingController(text: project['name'] as String? ?? '');
    final description = TextEditingController(
      text: project['description'] as String? ?? '',
    );
    String status = project['status'] as String? ?? 'To Do';
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit project'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Project name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Project description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'To Do', child: Text('To Do')),
                    DropdownMenuItem(
                      value: 'In Progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'Completed',
                      child: Text('Completed'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) status = val;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (saved != true || name.text.trim().isEmpty) return;
      final updated = await widget.api.updateProject(project['id'] as String, {
        'name': name.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
      });
      if (!mounted) return;
      final updatedProject = Map<String, dynamic>.from(updated);
      final index = _projects.indexWhere(
        (item) => (item as Map)['id'] == updatedProject['id'],
      );
      setState(() {
        if (index >= 0) _projects[index] = updatedProject;
        if (_activeProject?['id'] == updatedProject['id']) {
          _activeProject = updatedProject;
          _activeProjectDescription.text =
              updatedProject['description'] as String? ?? '';
          _projectDescriptionDirty = false;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final projectId = project['id'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove project?'),
        content: Text(
          '${project['name']} will be removed. All components used in this project will be returned to stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove project'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteProject(projectId);
      _projectListComponents.remove(projectId);
      _expandedProjectIds.remove(projectId);
      _projectListErrors.remove(projectId);
      if (_activeProject?['id'] == projectId) {
        _clearProjectDraftLines();
        _activeProject = null;
      }
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _uploadProjectImage({required bool capture}) async {
    final project = _activeProject;
    if (project == null || _uploadingProjectImage) return;
    final selected = capture
        ? await _captureComponentImage()
        : await _pickComponentImage();
    if (selected == null) return;
    setState(() {
      _uploadingProjectImage = true;
      _error = null;
    });
    try {
      final updated = await widget.api.uploadProjectImage(
        project['id'] as String,
        selected.name,
        selected.bytes,
      );
      if (!mounted) return;
      final updatedProject = Map<String, dynamic>.from(updated);
      final index = _projects.indexWhere(
        (item) => (item as Map)['id'] == updatedProject['id'],
      );
      setState(() {
        _activeProject = updatedProject;
        if (index >= 0) _projects[index] = updatedProject;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project image saved.')));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploadingProjectImage = false);
    }
  }

  void _selectPage(int index) {
    setState(() {
      _selected = index;
      if (index >= 0 && index <= 3) {
        _mobileSelected = index;
      }
    });
  }

  Future<void> _openTechPandaYoutube() async {
    final uri = Uri.parse(techPandaYoutubeUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _error = 'Could not open the TechPanda YouTube channel.');
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _selected = 0;
      _mobileSelected = 0;
    });
  }

  Future<void> _exportProjectPdf(Map<String, dynamic> project) async {
    final projectId = project['id'] as String;
    setState(() {
      _exportingProjectId = projectId;
      _error = null;
    });
    try {
      final report = await widget.api.downloadProjectReport(projectId);
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save ${project['name']} project report',
        fileName: report.filename,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: report.bytes,
      );
      if (!mounted) return;
      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${report.filename} has been downloaded.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _exportingProjectId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) return _loginPage(context);

    final pages = [
      _dashboardPage(),
      ComponentsPage(
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
        showComponentSupplier: _showComponentSupplier,
        showComponentPrice: _showComponentPrice,
        showComponentExpiryDate: _showComponentExpiryDate,
        showComponentDatasheetFile: _showComponentDatasheetFile,
        showComponentDatasheetText: _showComponentDatasheetText,
        onFilterComponentTypeChanged: (value) =>
            setState(() => _filterComponentType = value),
        onFilterLocationIdChanged: (value) =>
            setState(() => _filterLocationId = value),
        onFilterUnitChanged: (value) => setState(() => _filterUnit = value),
        onFilterStockStatusChanged: (value) =>
            setState(() => _filterStockStatus = value),
        onToggleMobileFilters: () => setState(
          () => _showMobileComponentFilters = !_showMobileComponentFilters,
        ),
        onSearchChanged: (_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), _refresh);
        },
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
        onEditSuppliers: _editSuppliers,
      ),
      _stockPage(),
      _projectsPage(),
      _reportsPage(),
      _settingsPage(),
    ];
    final desktop = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(title: _brandTitle(), actions: _headerActions()),
      drawer: desktop ? null : _mobileDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 760;
          Widget contentWidget;
          if (isDesktop) {
            contentWidget = Column(
              children: [
                _desktopHeader(),
                Expanded(
                  child: Row(
                    children: [
                      _rail(),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: pages[_selected],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            contentWidget = Padding(
              padding: const EdgeInsets.all(16),
              child: pages[_selected],
            );
          }

          return Stack(
            children: [
              Positioned.fill(child: contentWidget),
              if (_showAlertsPanel)
                Positioned(
                  top: isDesktop ? 68 : 0,
                  right: 0,
                  bottom: 0,
                  width: isDesktop ? 380 : constraints.maxWidth,
                  child: _alertsPanel(),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width <= 760
          ? NavigationBar(
              selectedIndex: _mobileSelected,
              onDestinationSelected: _selectPage,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.memory),
                  label: 'Components',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_horiz),
                  label: 'Stock',
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_library),
                  label: 'Projects',
                ),
              ],
            )
          : null,
      floatingActionButton: _selected == 1 && _enableAddComponent
          ? FloatingActionButton(
              onPressed: _showAddComponentModal,
              tooltip: 'Add component',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  List<Widget> _headerActions() {
    return [
      if (_selected == 1) ...[
        IconButton(
          onPressed: _showScannerModal,
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'Scan barcode or QR code',
        ),
        IconButton(
          onPressed: _toggleComponentView,
          icon: Icon(
            _componentViewMode == 'List' ? Icons.grid_view : Icons.view_list,
          ),
          tooltip: _componentViewMode == 'List'
              ? 'Switch to thumbnail view'
              : 'Switch to list view',
        ),
      ],
      if (_selected == 3)
        IconButton(
          onPressed: _toggleProjectView,
          icon: Icon(
            _projectViewMode == 'List' ? Icons.grid_view : Icons.view_list,
          ),
          tooltip: _projectViewMode == 'List'
              ? 'Switch projects to thumbnail view'
              : 'Switch projects to list view',
        ),
      IconButton(
        onPressed: _refresh,
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh',
      ),
      _alertBellButton(),
      if (MediaQuery.sizeOf(context).width > 760)
        IconButton(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          tooltip: 'Logout',
        ),
    ];
  }

  int get _unreadAlertsCount {
    return _alerts.where((alert) {
      final id = (alert is Map)
          ? (alert['component_id'] ?? alert['id'])?.toString()
          : null;
      if (id == null) return true;
      return !_readAlertComponentIds.contains(id);
    }).length;
  }

  Future<void> _markAlertsAsChecked() async {
    final ids = <String>{};
    for (final alert in _alerts) {
      if (alert is Map) {
        final id = (alert['component_id'] ?? alert['id'])?.toString();
        if (id != null) ids.add(id);
      }
    }
    setState(() {
      _readAlertComponentIds.addAll(ids);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'read_alert_component_ids',
      _readAlertComponentIds.toList(),
    );
  }

  Future<void> _toggleAlertsPanel() async {
    final willOpen = !_showAlertsPanel;
    setState(() {
      _showAlertsPanel = willOpen;
    });
    if (willOpen && _unreadAlertsCount > 0) {
      await _markAlertsAsChecked();
    }
  }

  Widget _alertBellButton() {
    return StockAlertBellButton(
      alertsCount: _alerts.length,
      unreadCount: _unreadAlertsCount,
      isOpen: _showAlertsPanel,
      onToggle: _toggleAlertsPanel,
    );
  }

  Widget _alertsPanel() {
    return StockAlertsPanel(
      alerts: _alerts,
      onClose: () => setState(() => _showAlertsPanel = false),
      onClearAll: () async {
        await _markAlertsAsChecked();
        setState(() => _showAlertsPanel = false);
      },
      onSelectAlert: (alert) {
        final isOut = alert['alert_type'] == 'out_of_stock';
        setState(() {
          _showAlertsPanel = false;
          _filterStockStatus = isOut ? 'Out of stock' : 'Low stock';
          _search.text = alert['name'] as String? ?? '';
        });
        _selectPage(1);
      },
      onViewAll: () {
        setState(() {
          _showAlertsPanel = false;
          _filterStockStatus = 'All';
        });
        _selectPage(1);
      },
    );
  }

  Widget _mobileDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _brandTitle(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.ondemand_video_outlined),
              title: const Text('TechPanda'),
              onTap: () {
                Navigator.pop(context);
                _openTechPandaYoutube();
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize_outlined),
              selected: _selected == 4,
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                _selectPage(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              selected: _selected == 5,
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _selectPage(5);
              },
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    final pageTitle = switch (_selected) {
      0 => null,
      1 => 'Components',
      2 => 'Stock',
      3 => 'Projects',
      4 => 'Reports',
      _ => 'Settings',
    };
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          SizedBox(
            width: 196,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _brandTitle(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: pageTitle == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_timeGreeting()}, TechPanda',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Here is what is happening with your inventory today.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : Text(
                            pageTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                  ),
                  ..._headerActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandTitle() => const BrandTitle();

  Widget _loginPage(BuildContext context) => LoginPage(
    usernameController: _username,
    passwordController: _password,
    rememberCredentials: _rememberCredentials,
    onRememberCredentialsChanged: (value) =>
        setState(() => _rememberCredentials = value),
    onLogin: _login,
    error: _error,
  );

  Widget _rail() {
    return Container(
      width: 196,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _desktopNavTile(
            index: 0,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Dashboard',
          ),
          _desktopYoutubeCard(),
          _desktopNavTile(
            index: 1,
            icon: Icons.memory_outlined,
            selectedIcon: Icons.memory,
            label: 'Components',
          ),
          _desktopNavTile(
            index: 2,
            icon: Icons.swap_horiz_outlined,
            selectedIcon: Icons.swap_horiz,
            label: 'Stock',
          ),
          _desktopNavTile(
            index: 3,
            icon: Icons.video_library_outlined,
            selectedIcon: Icons.video_library,
            label: 'Projects',
          ),
          _desktopNavTile(
            index: 4,
            icon: Icons.summarize_outlined,
            selectedIcon: Icons.summarize,
            label: 'Reports',
          ),
          _desktopNavTile(
            index: 5,
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _desktopNavTile({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _selected == index;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: Icon(selected ? selectedIcon : icon),
          title: Text(label),
          onTap: () => _selectPage(index),
        ),
      ),
    );
  }

  Widget _desktopYoutubeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: InkWell(
        onTap: _openTechPandaYoutube,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE7E7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFB3B3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.ondemand_video, color: Color(0xFFCC0000)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TechPanda',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.open_in_new, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardPage() => DashboardPage(
    dashboard: _dashboard,
    error: _error,
    onDismissError: () => setState(() => _error = null),
    onViewAllComponents: () => _selectPage(1),
    onOpenComponentsForType: _openComponentsForType,
    onOpenComponentInStock: _openComponentInStock,
    buildThumbnail: (item, {required size}) =>
        _componentThumbnail(item, size: size),
  );

  void _openComponentsForType(String componentType) {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _filterComponentType = componentType;
      _filterLocationId = null;
      _filterUnit = null;
      _filterStockStatus = 'All';
      _showMobileComponentFilters = true;
      _selected = 1;
      _mobileSelected = 1;
    });
  }

  String _formatComponentQuantity(Object? value) =>
      formatComponentQuantity(value);

  void _openComponentInStock(Map<String, dynamic> item) {
    setState(() {
      _selectedComponentId = item['id'] as String;
      _addStockLine(item);
      _selected = 2;
      _mobileSelected = 2;
    });
  }

  Future<void> _toggleComponentView() async {
    final nextMode = _componentViewMode == 'List' ? 'Thumbnails' : 'List';
    setState(() {
      _componentViewMode = nextMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('component_view_mode', nextMode);
  }

  Future<void> _toggleProjectView() async {
    final nextMode = _projectViewMode == 'List' ? 'Thumbnails' : 'List';
    setState(() => _projectViewMode = nextMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('project_view_mode', nextMode);
  }

  Future<void> _showReorderList() async {
    try {
      final items = await widget.api.reorderList();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reorder list'),
          content: SizedBox(
            width: 620,
            child: items.isEmpty
                ? const Text('No components are below their minimum stock.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = Map<String, dynamic>.from(
                        items[index] as Map,
                      );
                      final supplier = item['supplier_name'] ?? 'No supplier';
                      return ListTile(
                        title: Text(
                          '${item['inventory_code']} • ${item['name']}',
                        ),
                        subtitle: Text(
                          '$supplier · Current ${item['current_quantity']} / Minimum ${item['minimum_quantity']}',
                        ),
                        trailing: Text(
                          'Order ${item['reorder_quantity']} ${item['unit'] ?? ''}',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        setState(() => _error = 'Unable to load reorder list: $error');
    }
  }

  Widget _stockPage() {
    return ListView(
      controller: _stockPageController,
      children: [
        if (_error != null) _errorBanner(),
        if (_editingTransaction != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note),
              title: Text(
                'Editing ${_editingTransaction!['transaction_code']}',
              ),
              subtitle: const Text(
                'Change the movement type, components, or quantities, then update the whole movement.',
              ),
              trailing: TextButton(
                onPressed: _cancelStockMovementEdit,
                child: const Text('Cancel edit'),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'stock_in',
              label: Text('Stock In'),
              icon: Icon(Icons.add_box),
            ),
            ButtonSegment(
              value: 'stock_out',
              label: Text('Stock Out'),
              icon: Icon(Icons.output),
            ),
            ButtonSegment(
              value: 'return',
              label: Text('Return'),
              icon: Icon(Icons.keyboard_return),
            ),
            ButtonSegment(
              value: 'loss',
              label: Text('Loss'),
              icon: Icon(Icons.delete_sweep),
            ),
          ],
          selected: {_stockMode},
          onSelectionChanged: (value) =>
              setState(() => _stockMode = value.first),
        ),
        const SizedBox(height: 16),
        _stockComponentPicker(),
        const SizedBox(height: 12),
        if (_stockLines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No components selected. Search and add components above.',
            ),
          )
        else
          ..._stockLines.map(_stockLineRow),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _postStock(),
              icon: Icon(
                _editingTransaction == null ? Icons.cloud_upload : Icons.save,
              ),
              label: Text(
                _editingTransaction == null
                    ? 'Submit'
                    : 'Update entire movement',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Stock movement history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showReorderList,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Reorder list'),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String?>(
                initialValue: _transactionComponentId,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Filter by component',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All components'),
                  ),
                  ..._components.map((raw) {
                    final component = Map<String, dynamic>.from(raw as Map);
                    return DropdownMenuItem<String?>(
                      value: component['id'] as String,
                      child: Text(
                        '${component['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) async {
                  setState(() {
                    _transactionComponentId = value;
                    _transactionPage = 1;
                  });
                  await _refresh();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._transactions.map((rawItem) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final movementId = item['id'] as String;
          final expanded = _expandedMovementIds.contains(movementId);
          final canModify = item['can_modify'] == true;
          final canEdit =
              canModify &&
              {
                'stock_in',
                'stock_out',
                'return',
                'loss',
              }.contains(item['transaction_type']);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text(
                    '${item['transaction_code']} ${item['transaction_type']}',
                  ),
                  subtitle: Text(
                    '${item['line_count']} lines • ${item['created_at']}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        key: ValueKey('expand-movement-$movementId'),
                        onPressed: () => _toggleStockMovementDetails(item),
                        icon: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        tooltip: expanded
                            ? 'Hide movement components'
                            : 'View movement components',
                      ),
                      if (canModify) ...[
                        if (canEdit)
                          IconButton(
                            onPressed: () => _editStockMovement(item),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit entire movement',
                          ),
                        IconButton(
                          onPressed: () => _deleteStockMovement(item),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete entire movement',
                        ),
                      ] else
                        const Tooltip(
                          message: 'Managed from its project',
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.lock_outline),
                          ),
                        ),
                    ],
                  ),
                ),
                if (expanded) _stockMovementDetailsPanel(movementId),
              ],
            ),
          );
        }),
        if (_transactions.isNotEmpty || _transactionPage > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: _transactionPage == 1
                    ? null
                    : () async {
                        setState(() => _transactionPage--);
                        await _refresh();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page $_transactionPage'),
              IconButton(
                tooltip: 'Next page',
                onPressed: _transactions.length < _transactionPageSize
                    ? null
                    : () async {
                        setState(() => _transactionPage++);
                        await _refresh();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }

  Widget _stockMovementDetailsPanel(String movementId) {
    final detail = _movementDetails[movementId];
    final error = _movementDetailErrors[movementId];
    final loading = _loadingMovementIds.contains(movementId);
    if (loading && detail == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LinearProgressIndicator(),
      );
    }
    if (error != null && detail == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(child: Text(error)),
            TextButton.icon(
              onPressed: () => _loadStockMovementDetails(movementId),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (detail == null) return const SizedBox.shrink();

    final lines = (detail['lines'] as List<dynamic>? ?? const [])
        .map((rawLine) => Map<String, dynamic>.from(rawLine as Map))
        .toList();
    final reason = (detail['reason'] as String? ?? '').trim();
    final notes = (detail['notes'] as String? ?? '').trim();
    return Container(
      key: ValueKey('movement-details-$movementId'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason.isNotEmpty || notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                [
                  if (reason.isNotEmpty) 'Reason: $reason',
                  if (notes.isNotEmpty) 'Notes: $notes',
                ].join('\n'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ...lines.map((line) {
            final component = <String, dynamic>{
              'id': line['component_id'],
              'inventory_code': line['inventory_code'],
              'name': line['component_name'],
              'package_type': line['package_type'],
              'manufacturer': line['manufacturer'],
              'location_name': line['location_name'],
              'current_quantity': line['available_quantity'],
              'unit': line['unit'],
              'primary_image_thumbnail': line['primary_image_thumbnail'],
            };
            final details = [
              line['package_type'],
              line['manufacturer'],
              line['location_name'],
            ].whereType<String>().where((value) => value.trim().isNotEmpty);
            final lineNotes = (line['line_notes'] as String? ?? '').trim();
            return ListTile(
              key: ValueKey(
                'movement-line-$movementId-${line['component_id']}',
              ),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: _componentThumbnail(component, size: 42),
              title: Text(
                '${line['inventory_code']} • ${line['component_name']}',
              ),
              subtitle: Text(
                [
                  if (component['supplier_name'] != null &&
                      '${component['supplier_name']}'.isNotEmpty)
                    'Supplier: ${component['supplier_name']}',
                  if (details.isNotEmpty) details.join(' • '),
                  if (lineNotes.isNotEmpty) 'Note: $lineNotes',
                ].join('\n'),
              ),
              trailing: Text(
                '${_formatComponentQuantity(line['quantity'])} ${line['unit']}',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stockComponentPicker() {
    final components = _components
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: _stockComponentLabel,
      optionsBuilder: (value) async {
        final query = value.text.trim();
        if (query.isEmpty) {
          return _showAllStockComponents
              ? components.take(30)
              : const Iterable<Map<String, dynamic>>.empty();
        }
        try {
          final results = await widget.api.components(query: query);
          return results
              .map((item) => Map<String, dynamic>.from(item as Map))
              .take(30);
        } catch (_) {
          // Keep the picker usable offline or during a transient request failure.
        }
        final normalizedQuery = query.toLowerCase();
        return components
            .where((component) {
              final haystack = [
                component['inventory_code'],
                component['name'],
                component['manufacturer'],
                component['package_type'],
                component['location_name'],
                component['description'],
              ].whereType<Object>().join(' ').toLowerCase();
              return haystack.contains(normalizedQuery);
            })
            .take(30);
      },
      onSelected: (component) {
        setState(() {
          _addStockLine(component);
          _showAllStockComponents = false;
        });
        _stockSearchController?.clear();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _stockSearchController = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            prefixIcon: IconButton(
              onPressed: () {
                setState(() => _showAllStockComponents = true);
                focusNode.requestFocus();
                if (controller.text.trim().isEmpty) {
                  controller.text = ' ';
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }
              },
              icon: const Icon(Icons.search),
              tooltip: 'Show components',
            ),
            labelText: 'Search component to add',
          ),
          onChanged: (value) {
            if (value.trim().isNotEmpty && _showAllStockComponents) {
              setState(() => _showAllStockComponents = false);
            }
          },
          onSubmitted: (_) {
            onSubmitted();
            controller.clear();
            setState(() => _showAllStockComponents = false);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 620),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final component = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: _componentThumbnail(component, size: 40),
                    title: Text(_stockComponentLabel(component)),
                    subtitle: Text(_stockComponentDetail(component)),
                    onTap: () => onSelected(component),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stockLineRow(StockLineDraft line) {
    final component = line.component;
    final unit = component['unit'] as String? ?? 'Pieces';
    final thumbnail = _componentThumbnail(component, size: 52);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stockComponentLabel(component),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                _stockComponentDetail(component),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
          final quantity = SizedBox(
            width: compact ? double.infinity : 320,
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () =>
                      setState(() => _adjustStockLineQuantity(line, -1)),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Decrease quantity',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: line.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () =>
                      setState(() => _adjustStockLineQuantity(line, 1)),
                  icon: const Icon(Icons.add),
                  tooltip: 'Increase quantity',
                ),
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 72),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unit,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
          final remove = IconButton.outlined(
            onPressed: () => setState(() => _removeStockLine(line)),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove component',
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thumbnail,
                    const SizedBox(width: 10),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: quantity),
                    const SizedBox(width: 8),
                    remove,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              thumbnail,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 12),
              quantity,
              const SizedBox(width: 8),
              remove,
            ],
          );
        },
      ),
    );
  }

  String _stockComponentLabel(Map<String, dynamic> component) {
    return component['name'] as String? ?? 'Component';
  }

  String _stockComponentDetail(Map<String, dynamic> component) {
    return [
      if ((component['package_type'] as String?)?.isNotEmpty == true)
        component['package_type'],
      if ((component['manufacturer'] as String?)?.isNotEmpty == true)
        component['manufacturer'],
      if ((component['location_name'] as String?)?.isNotEmpty == true)
        component['location_name'],
      '${component['current_quantity']} ${component['unit']} available',
    ].join(' • ');
  }

  Widget _projectComponentPicker() {
    final localComponents = _components
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    Iterable<Map<String, dynamic>> excludeSelected(
      Iterable<Map<String, dynamic>> options,
    ) {
      final selectedIds = _projectDraftLines
          .map((line) => line.component['id'] as String)
          .toSet();
      return options.where(
        (component) => !selectedIds.contains(component['id'] as String),
      );
    }

    return Autocomplete<Map<String, dynamic>>(
      displayStringForOption: _stockComponentLabel,
      optionsBuilder: (value) async {
        final query = value.text.trim();
        if (query.isEmpty) {
          return _showAllProjectComponents
              ? excludeSelected(localComponents).take(30)
              : const Iterable<Map<String, dynamic>>.empty();
        }
        try {
          final results = await widget.api.components(query: query);
          return excludeSelected(
            results.map((item) => Map<String, dynamic>.from(item as Map)),
          ).take(30);
        } catch (_) {
          final normalizedQuery = query.toLowerCase();
          return excludeSelected(localComponents)
              .where((component) {
                final haystack = [
                  component['inventory_code'],
                  component['name'],
                  component['manufacturer'],
                  component['package_type'],
                  component['location_name'],
                  component['description'],
                ].whereType<Object>().join(' ').toLowerCase();
                return haystack.contains(normalizedQuery);
              })
              .take(30);
        }
      },
      onSelected: (component) {
        setState(() {
          _addProjectDraftLine(component);
          _showAllProjectComponents = false;
        });
        _projectSearchController?.clear();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        _projectSearchController = controller;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            prefixIcon: IconButton(
              onPressed: () {
                setState(() => _showAllProjectComponents = true);
                focusNode.requestFocus();
                if (controller.text.trim().isEmpty) {
                  controller.text = ' ';
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }
              },
              icon: const Icon(Icons.search),
              tooltip: 'Show inventory components',
            ),
            labelText: 'Search component to add to this project',
            helperText:
                'Select a result to add it instantly, then adjust quantities below.',
          ),
          onChanged: (value) {
            if (value.trim().isNotEmpty && _showAllProjectComponents) {
              setState(() => _showAllProjectComponents = false);
            }
          },
          onSubmitted: (_) {
            onSubmitted();
            controller.clear();
            setState(() => _showAllProjectComponents = false);
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 620),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final component = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: _componentThumbnail(component, size: 40),
                    title: Text(_stockComponentLabel(component)),
                    subtitle: Text(_stockComponentDetail(component)),
                    onTap: () => onSelected(component),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _projectDraftLineRow(StockLineDraft line) {
    final component = line.component;
    final unit = component['unit'] as String? ?? 'Pieces';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _componentThumbnail(component, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stockComponentLabel(component),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _stockComponentDetail(component),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final controls = Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () =>
                      setState(() => _adjustProjectDraftQuantity(line, -1)),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Decrease quantity',
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: compact ? 92 : 120,
                  child: TextField(
                    controller: line.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      suffixText: unit,
                    ),
                    onChanged: (_) {
                      if (!_projectComponentsDirty) {
                        setState(() => _projectComponentsDirty = true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () =>
                      setState(() => _adjustProjectDraftQuantity(line, 1)),
                  icon: const Icon(Icons.add),
                  tooltip: 'Increase quantity',
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () =>
                      setState(() => _removeProjectDraftLine(line)),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove from project draft',
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                controls,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _projectsPage() {
    final activeProject = _activeProject;
    if (activeProject != null) {
      return _projectDetailsPage(activeProject);
    }

    return Column(
      children: [
        if (_error != null) _errorBanner(),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _projectName,
                decoration: const InputDecoration(
                  labelText: 'Project or YouTube video',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              tooltip: 'Add project',
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newProjectDescription,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Project description (optional)',
            hintText: 'Purpose, scope, build notes, or other project details',
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects yet. Create one above to start consuming components.',
                    textAlign: TextAlign.center,
                  ),
                )
              : _projectViewMode == 'Thumbnails'
              ? _projectThumbnailView()
              : ListView(
                  children: _projects.map((item) {
                    final project = Map<String, dynamic>.from(item as Map);
                    final description =
                        (project['description'] as String? ?? '').trim();
                    final projectId = project['id'] as String;
                    final expanded = _expandedProjectIds.contains(projectId);
                    final exporting = _exportingProjectId == project['id'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: _projectImageTile(project, size: 48),
                            title: Text(project['name'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${project['project_type']} • ${project['status']}',
                                ),
                                if (description.isNotEmpty)
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  key: ValueKey(
                                    'expand-project-components-$projectId',
                                  ),
                                  onPressed: () =>
                                      _toggleProjectListComponents(project),
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  tooltip: expanded
                                      ? 'Hide project components'
                                      : 'View project components',
                                ),
                                IconButton(
                                  key: ValueKey(
                                    'export-project-pdf-${project['id']}',
                                  ),
                                  onPressed: exporting
                                      ? null
                                      : () => _exportProjectPdf(project),
                                  icon: exporting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.picture_as_pdf),
                                  tooltip: 'Export project as PDF',
                                ),
                                IconButton(
                                  onPressed: () => _editProject(project),
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit project',
                                ),
                                IconButton(
                                  onPressed: () => _deleteProject(project),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Remove project',
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => _openProject(project),
                          ),
                          if (expanded) _projectListComponentsPanel(projectId),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _projectImageTile(
    Map<String, dynamic> project, {
    required double size,
  }) {
    final path = project['image_url'] as String?;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.video_library),
              )
            : _inventoryImage(
                path,
                key: ValueKey('project-image-${project['id']}'),
                fit: BoxFit.cover,
                errorChild: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }

  Widget _projectImageBanner(
    Map<String, dynamic> project, {
    required double height,
  }) {
    final path = project['image_url'] as String?;
    if (path == null) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.video_library, size: 48)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: _inventoryImage(
        path,
        key: ValueKey('project-banner-${project['id']}'),
        fit: BoxFit.cover,
        errorChild: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),
      ),
    );
  }

  Widget _projectThumbnailView() {
    final projects = _projects
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        const spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: projects
                .map((project) => _projectThumbnailCard(project, cardWidth))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _projectThumbnailCard(Map<String, dynamic> project, double width) {
    final projectId = project['id'] as String;
    final expanded = _expandedProjectIds.contains(projectId);
    final exporting = _exportingProjectId == projectId;
    final description = (project['description'] as String? ?? '').trim();
    return SizedBox(
      key: ValueKey('project-thumbnail-$projectId'),
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _openProject(project),
              child: _projectImageBanner(project, height: 170),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['name'] as String,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${project['project_type']} • ${project['status']}${project['total_cost'] != null ? ' • Cost: \$${project['total_cost']}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _toggleProjectListComponents(project),
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    tooltip: expanded
                        ? 'Hide project components'
                        : 'View project components',
                  ),
                  IconButton(
                    onPressed: exporting
                        ? null
                        : () => _exportProjectPdf(project),
                    icon: exporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    tooltip: 'Export project as PDF',
                  ),
                  IconButton(
                    onPressed: () => _editProject(project),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit project',
                  ),
                  IconButton(
                    onPressed: () => _deleteProject(project),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove project',
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openProject(project),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
            if (expanded) _projectListComponentsPanel(projectId),
          ],
        ),
      ),
    );
  }

  Widget _projectListComponentsPanel(String projectId) {
    final components = _projectListComponents[projectId];
    final error = _projectListErrors[projectId];
    final loading = _loadingProjectListIds.contains(projectId);
    if (loading && components == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LinearProgressIndicator(),
      );
    }
    if (error != null && components == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(child: Text(error)),
            TextButton.icon(
              onPressed: () => _loadProjectListComponents(projectId),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (components == null) return const SizedBox.shrink();

    return Container(
      key: ValueKey('project-components-$projectId'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: components.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No components have been added to this project.'),
            )
          : Column(
              children: components.map((line) {
                final component = _projectLineAsComponent(line);
                final details = [
                  line['package_type'],
                  line['manufacturer'],
                  line['location_name'],
                ].whereType<String>().where((value) => value.trim().isNotEmpty);
                final notes = (line['notes'] as String? ?? '').trim();
                return ListTile(
                  key: ValueKey(
                    'project-list-line-$projectId-${line['component_id']}',
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: _componentThumbnail(component, size: 42),
                  title: Text(
                    '${line['inventory_code']} • ${line['component_name']}',
                  ),
                  subtitle: Text(
                    [
                      if (component['supplier_name'] != null &&
                          '${component['supplier_name']}'.isNotEmpty)
                        'Supplier: ${component['supplier_name']}',
                      if (details.isNotEmpty) details.join(' • '),
                      if (notes.isNotEmpty) 'Note: $notes',
                    ].join('\n'),
                  ),
                  trailing: Text(
                    '${_formatComponentQuantity(line['quantity'])} ${line['unit']}',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _projectDetailsPage(Map<String, dynamic> project) {
    final hasProjectImage = project['image_url'] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _errorBanner(),
        Row(
          children: [
            IconButton(
              onPressed: _closeProject,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to projects',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${project['project_type']} • ${project['status']}${project['total_cost'] != null ? ' • Cost: \$${project['total_cost']}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.memory, size: 18),
              label: Text(
                '${_projectDraftLines.length} component'
                '${_projectDraftLines.length == 1 ? '' : 's'}',
              ),
            ),
            IconButton(
              onPressed: () => _editProject(project),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit project',
            ),
            IconButton(
              onPressed: () => _deleteProject(project),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove project',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasProjectImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _projectImageBanner(project, height: 190),
                  ),
                  const SizedBox(height: 10),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('upload-project-image'),
                      onPressed: _uploadingProjectImage
                          ? null
                          : () => _uploadProjectImage(capture: false),
                      icon: _uploadingProjectImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate),
                      label: Text(
                        hasProjectImage
                            ? 'Replace project image'
                            : 'Add project image',
                      ),
                    ),
                    if (_canCaptureComponentImage)
                      OutlinedButton.icon(
                        onPressed: _uploadingProjectImage
                            ? null
                            : () => _uploadProjectImage(capture: true),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take project photo'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('project-description-field'),
                  controller: _activeProjectDescription,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (_) {
                    if (!_projectDescriptionDirty) {
                      setState(() => _projectDescriptionDirty = true);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Project description',
                    hintText:
                        'Save the purpose, scope, progress, or other useful notes about this project',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('save-project-description'),
                    onPressed:
                        !_projectDescriptionDirty || _savingProjectDescription
                        ? null
                        : _saveProjectDescription,
                    icon: _savingProjectDescription
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Save description'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingProjectComponents)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else ...[
          _projectComponentPicker(),
          const SizedBox(height: 12),
          Expanded(
            child: _projectDraftLines.isEmpty
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: const Text(
                        'No components selected. Search above and select a component to add it instantly.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: _projectDraftLines
                        .map(_projectDraftLineRow)
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _projectComponentsDirty
                      ? 'You have unsaved project changes.'
                      : 'Project components are saved.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: !_projectComponentsDirty || _savingProjectComponents
                    ? null
                    : _loadProjectComponents,
                child: const Text('Discard'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: !_projectComponentsDirty || _savingProjectComponents
                    ? null
                    : _saveProjectComponents,
                icon: _savingProjectComponents
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save all'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _reportsPage() => ReportsPage(
    api: widget.api,
    error: _error,
    onErrorChanged: (val) => setState(() => _error = val),
    onRefresh: _refresh,
  );

  Widget _settingsPage() => SettingsPage(
    api: widget.api,
    syncService: _syncService,
    darkMode: widget.darkMode,
    onDarkModeChanged: widget.onDarkModeChanged,
    displayComponentImages: _displayComponentImages,
    onDisplayComponentImagesChanged: _setDisplayComponentImages,
    enableAddComponent: _enableAddComponent,
    onEnableAddComponentChanged: _setEnableAddComponent,
    enableEditComponent: _enableEditComponent,
    onEnableEditComponentChanged: _setEnableEditComponent,
    showComponentSupplier: _showComponentSupplier,
    onShowComponentSupplierChanged: _setShowComponentSupplier,
    showComponentPrice: _showComponentPrice,
    onShowComponentPriceChanged: _setShowComponentPrice,
    showComponentExpiryDate: _showComponentExpiryDate,
    onShowComponentExpiryDateChanged: _setShowComponentExpiryDate,
    showComponentDatasheetFile: _showComponentDatasheetFile,
    onShowComponentDatasheetFileChanged: _setShowComponentDatasheetFile,
    showComponentDatasheetText: _showComponentDatasheetText,
    onShowComponentDatasheetTextChanged: _setShowComponentDatasheetText,
    onNavigateToTab: _selectPage,
    onRefreshData: _refresh,
    onError: (err) => setState(() => _error = err),
    usernameController: _username,
    passwordController: _password,
  );

  Widget _errorBanner() {
    return ErrorBanner(
      errorMessage: _error ?? '',
      onDismiss: () => setState(() => _error = null),
    );
  }
}
