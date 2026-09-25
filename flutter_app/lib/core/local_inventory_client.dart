import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

const _uuid = Uuid();
const _storeKey = 'tech_panda_local_inventory_store_v1';
const _techPandaYoutubeUrl = 'https://www.youtube.com/@TechPanda-4k';

class LocalInventoryClient extends ApiClient {
  LocalInventoryClient({super.onUnauthorized});

  ApiClient? _remoteClient;
  bool _remoteEnabled = false;
  String _remoteUrl = '';

  @override
  set onUnauthorized(VoidCallback? callback) {
    super.onUnauthorized = callback;
    _remoteClient?.onUnauthorized = callback;
  }

  bool get isRemoteEnabled => _remoteEnabled;
  String get remoteUrl => _remoteUrl;
  ApiClient? get remoteClient => _remoteClient;

  Future<void> configureRemote({
    required bool enabled,
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remote_server_enabled', enabled);
    await prefs.setString('remote_server_url', url);
    _remoteEnabled = enabled;
    _remoteUrl = url.trim();
    if (_remoteEnabled && _remoteUrl.isNotEmpty) {
      _remoteClient = ApiClient(
        baseUrl: _normalizeBaseUrl(_remoteUrl),
        onUnauthorized: onUnauthorized,
      );
      await _remoteClient!.restoreSession();
    } else {
      _remoteClient = null;
    }
  }

  static String _normalizeBaseUrl(String input) {
    var u = input.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.endsWith('/api/v1')) {
      u = '$u/api/v1';
    }
    return u;
  }

  @override
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _remoteEnabled = prefs.getBool('remote_server_enabled') ?? false;
    _remoteUrl = prefs.getString('remote_server_url') ?? '';
    final hasPref = prefs.containsKey('remote_server_enabled');
    if (!hasPref && kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty &&
          !origin.contains('localhost:3000') &&
          !origin.contains('127.0.0.1:3000')) {
        _remoteEnabled = true;
        _remoteUrl = origin;
        await prefs.setBool('remote_server_enabled', true);
        await prefs.setString('remote_server_url', _remoteUrl);
      } else {
        _remoteEnabled = false;
        _remoteUrl = '';
      }
    } else {
      _remoteEnabled = prefs.getBool('remote_server_enabled') ?? false;
      _remoteUrl = prefs.getString('remote_server_url') ?? '';
    }
    if (_remoteEnabled && _remoteUrl.isNotEmpty) {
      _remoteClient = ApiClient(
        baseUrl: _normalizeBaseUrl(_remoteUrl),
        onUnauthorized: onUnauthorized,
      );
      return await _remoteClient!.restoreSession();
    }
    return true;
  }

  @override
  String mediaUrl(String path) {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.mediaUrl(path);
    }
    return path;
  }

  @override
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.login(username, password);
    }
    return {'access_token': 'local-only'};
  }

  @override
  Future<void> logout() async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.logout();
      return;
    }
  }

  @override
  Future<Map<String, dynamic>> uiSettings() async {
    if (_remoteEnabled && _remoteClient != null) {
      try {
        return await _remoteClient!.uiSettings();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    return {'dark_mode': prefs.getBool('dark_mode') ?? false};
  }

  @override
  Future<Map<String, dynamic>> updateUiSettings({
    required bool darkMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', darkMode);
    if (_remoteEnabled && _remoteClient != null) {
      try {
        return await _remoteClient!.updateUiSettings(darkMode: darkMode);
      } catch (_) {}
    }
    return {'dark_mode': darkMode};
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.changePassword(currentPassword, newPassword);
      return;
    }
    // Local password change not supported; no operation.
  }

  @override
  Future<Map<String, dynamic>> dashboard() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.dashboard();
    }
    final store = await _LocalStore.load();
    final components = store.components
        .where((item) => item['is_archived'] != true)
        .toList();
    final types = store.componentTypes
        .where((item) => item['is_active'] != false)
        .toList();
    final total = components.fold<double>(
      0,
      (sum, item) => sum + _number(item['current_quantity']),
    );
    final totalInventoryValue = components.fold<double>(
      0,
      (sum, item) =>
          sum + _number(item['current_quantity']) * _number(item['price']),
    );
    final out = components
        .where((item) => _number(item['current_quantity']) <= 0)
        .length;
    final byType = <String, Map<String, dynamic>>{};
    for (final component in components) {
      final qty = _number(component['current_quantity']);
      if (qty <= 0) continue;
      final name =
          (component['package_type'] as String?)?.trim().isNotEmpty == true
          ? component['package_type'] as String
          : 'Other';
      final type = types.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['name'] == name,
        orElse: () => null,
      );
      final summary = byType.putIfAbsent(
        name,
        () => {
          'name': name,
          'product_count': 0,
          'stock_quantity': '0',
          'icon_svg': type?['icon_svg'],
        },
      );
      summary['product_count'] = (summary['product_count'] as int) + 1;
      summary['stock_quantity'] = _stringNumber(
        _number(summary['stock_quantity']) + qty,
      );
    }
    return {
      'total_component_types': types.length,
      'total_products': components.length,
      'total_stock_quantity': _stringNumber(total),
      'total_inventory_value': _stringNumber(totalInventoryValue),
      'low_stock_count': components.where((item) {
        final qty = _number(item['current_quantity']);
        final min = _number(item['minimum_quantity']);
        return min > 0 && qty > 0 && qty <= min;
      }).length,
      'out_of_stock_count': out,
      'recent_components': components.take(5).toList(),
      'component_type_stock': byType.values.toList()
        ..sort((a, b) => '${a['name']}'.compareTo('${b['name']}')),
    };
  }

  @override
  Future<List<dynamic>> categories() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.categories();
    }
    return (await _LocalStore.load()).categories;
  }

  @override
  Future<List<dynamic>> componentTypes() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.componentTypes();
    }
    final store = await _LocalStore.load();
    final typeMap = <String, String>{};
    for (final t in store.componentTypes) {
      typeMap[t['id'] as String] = t['name'] as String;
    }
    return store.componentTypes.map((t) {
      final copy = Map<String, dynamic>.from(t as Map);
      final parentId = copy['parent_type_id'] as String?;
      copy['parent_type_name'] = parentId != null ? typeMap[parentId] : null;
      return copy;
    }).toList();
  }

  @override
  Future<List<dynamic>> locations() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.locations();
    }
    return (await _LocalStore.load()).locations;
  }

  @override
  Future<List<dynamic>> transactions() async => transactionsPage();

  @override
  Future<List<dynamic>> transactionsPage({
    int page = 1,
    int limit = 25,
    DateTime? before,
    DateTime? after,
    String? componentId,
  }) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.transactionsPage(
        page: page,
        limit: limit,
        before: before,
        after: after,
        componentId: componentId,
      );
    }
    final store = await _LocalStore.load();
    var items = store.transactions.where((item) {
      final created = DateTime.tryParse('${item['created_at']}');
      return (before == null ||
              (created != null && created.isBefore(before))) &&
          (after == null || (created != null && created.isAfter(after)));
    }).toList();
    final start = (page - 1) * limit;
    return start >= items.length
        ? <dynamic>[]
        : items.sublist(start, (start + limit).clamp(0, items.length));
  }

  @override
  Future<List<dynamic>> projects() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.projects();
    }
    final store = await _LocalStore.load();
    const statusOrder = {'To Do': 0, 'In Progress': 1, 'Completed': 2};
    final sorted = List<dynamic>.from(store.projects)
      ..sort((a, b) {
        final aMap = a as Map<String, dynamic>;
        final bMap = b as Map<String, dynamic>;
        final aStatus = aMap['status'] as String? ?? 'To Do';
        final bStatus = bMap['status'] as String? ?? 'To Do';
        final statusCmp = (statusOrder[aStatus] ?? 0).compareTo(
          statusOrder[bStatus] ?? 0,
        );
        if (statusCmp != 0) return statusCmp;
        return ((aMap['name'] as String? ?? '').toLowerCase()).compareTo(
          (bMap['name'] as String? ?? '').toLowerCase(),
        );
      });
    // Compute total_cost for each project from its components
    for (final item in sorted) {
      final project = item as Map<String, dynamic>;
      final projectId = project['id'] as String;
      double total = 0;
      for (final line in store.projectComponents.where(
        (l) => l['project_id'] == projectId,
      )) {
        final qty = _number(line['quantity']);
        final price = _number(line['price']);
        total += qty * price;
      }
      project['total_cost'] = total > 0 ? _stringNumber(total) : null;
    }
    return sorted;
  }

  @override
  Future<List<dynamic>> alerts() async {
    if (_remoteEnabled && _remoteClient != null) {
      try {
        return await _remoteClient!.alerts();
      } catch (_) {}
    }
    final store = await _LocalStore.load();
    final alertsList = <Map<String, dynamic>>[];
    final today = DateTime.now();
    final expiryCutoff = today.add(const Duration(days: 30));
    final locationMap = {
      for (final l in store.locations) l['id']: l['display_name'] ?? l['name'],
    };
    for (final c in store.components) {
      if (c['is_archived'] == true) continue;
      final curQty = _number(c['current_quantity']);
      final minQty = _number(c['minimum_quantity']);
      if (curQty <= 0) {
        alertsList.add({
          'id': c['id'],
          'name': c['name'],
          'current_quantity': curQty,
          'minimum_quantity': minQty,
          'unit': c['unit'] ?? 'pcs',
          'alert_type': 'out_of_stock',
          'location_name': locationMap[c['location_id']] ?? 'Unknown',
        });
      } else if (minQty > 0 && curQty <= minQty) {
        alertsList.add({
          'id': c['id'],
          'name': c['name'],
          'current_quantity': curQty,
          'minimum_quantity': minQty,
          'unit': c['unit'] ?? 'pcs',
          'alert_type': 'low_stock',
          'location_name': locationMap[c['location_id']] ?? 'Unknown',
        });
      }
      final expiryText = '${c['expiry_date'] ?? ''}'.trim();
      final expiry = DateTime.tryParse(expiryText);
      if (expiry != null && expiryText.isNotEmpty && expiry.isBefore(today)) {
        alertsList.add({
          'id': c['id'],
          'name': c['name'],
          'alert_type': 'expired',
          'expiry_date': expiryText,
          'location_name': locationMap[c['location_id']] ?? 'Unknown',
        });
      } else if (expiry != null && expiry.isBefore(expiryCutoff)) {
        alertsList.add({
          'id': c['id'],
          'name': c['name'],
          'alert_type': 'expiry_soon',
          'expiry_date': expiryText,
          'location_name': locationMap[c['location_id']] ?? 'Unknown',
        });
      }
    }
    return alertsList;
  }

  @override
  Future<List<dynamic>> reorderList() async {
    if (_remoteEnabled && _remoteClient != null) {
      try {
        return await _remoteClient!.reorderList();
      } catch (_) {}
    }
    final store = await _LocalStore.load();
    final suppliers = {for (final s in store.suppliers) s['id']: s['name']};
    final items = <Map<String, dynamic>>[];
    for (final raw in store.components) {
      if (raw['is_archived'] == true) continue;
      final current = _number(raw['current_quantity']);
      final minimum = _number(raw['minimum_quantity']);
      if (minimum <= 0 || current >= minimum) continue;
      items.add({...raw, 'reorder_quantity': _stringNumber(minimum - current),
        'supplier_name': suppliers[raw['supplier_id']]});
    }
    items.sort((a, b) => '${a['supplier_name'] ?? ''}${a['name']}'.compareTo(
        '${b['supplier_name'] ?? ''}${b['name']}'));
    return items;
  }

  @override
  Future<List<dynamic>> components({String query = '', int limit = 500}) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.components(query: query, limit: limit);
    }
    final q = query.trim().toLowerCase();
    final items = (await _LocalStore.load()).components
        .where((item) {
          if (item['is_archived'] == true) return false;
          if (q.isEmpty) return true;
          return [
            item['inventory_code'],
            item['name'],
            item['manufacturer'],
            item['package_type'],
            item['location_name'],
            item['description'],
          ].whereType<Object>().join(' ').toLowerCase().contains(q);
        })
        .take(limit)
        .toList();
    return items;
  }

  @override
  Future<Map<String, dynamic>> createComponent(
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.createComponent(payload);
    }
    final store = await _LocalStore.load();
    final name = (payload['name'] as String).trim();
    final duplicate = store.components.cast<Map<String, dynamic>>().any(
      (item) =>
          item['is_archived'] != true &&
          (item['name'] as String).trim().toLowerCase() == name.toLowerCase(),
    );
    if (duplicate) {
      throw ApiException(409, "Component '$name' already exists");
    }
    final now = DateTime.now().toIso8601String();
    final category = store.categories.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == payload['category_id'],
      orElse: () => null,
    );
    final component = {
      'id': _uuid.v4(),
      'inventory_code':
          '${category?['code_prefix'] ?? 'TP'}-${(store.components.length + 1).toString().padLeft(4, '0')}',
      'name': name,
      'category_id': payload['category_id'],
      'manufacturer': payload['manufacturer'],
      'model_number': payload['model_number'],
      'part_number': payload['part_number'],
      'package_type': payload['package_type'],
      'description': payload['description'],
      'current_quantity': _stringNumber(_number(payload['opening_quantity'])),
      'minimum_quantity': _stringNumber(_number(payload['minimum_quantity'])),
      'unit': payload['unit'] ?? 'Pieces',
      'price':
          payload['price'] != null && '${payload['price']}'.trim().isNotEmpty
          ? _stringNumber(_number(payload['price']))
          : null,
      'datasheet_url': payload['datasheet_url'],
      'datasheet_text': payload['datasheet_text'],
      'expiry_date': payload['expiry_date'],
      'location_id': payload['location_id'],
      'location_name': _locationName(store, payload['location_id']),
      'supplier_id': payload['supplier_id'],
      'supplier_name': _supplierName(store, payload['supplier_id']),
      'primary_image_thumbnail': null,
      'primary_image_preview': null,
      'can_delete': true,
      'is_favorite': false,
      'is_archived': false,
      'created_at': now,
      'updated_at': now,
    };
    store.components.add(component);
    await store.save();
    return component;
  }

  @override
  Future<Map<String, dynamic>> updateComponent(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateComponent(id, payload);
    }
    final store = await _LocalStore.load();
    final component = _byId(store.components, id, 'Component');
    if (payload.containsKey('name') && payload['name'] != null) {
      final name = (payload['name'] as String).trim();
      final duplicate = store.components.cast<Map<String, dynamic>>().any(
        (item) =>
            item['id'] != id &&
            item['is_archived'] != true &&
            (item['name'] as String).trim().toLowerCase() == name.toLowerCase(),
      );
      if (duplicate) {
        throw ApiException(409, "Component '$name' already exists");
      }
    }
    component.addAll(payload);
    if (payload.containsKey('location_id')) {
      component['location_name'] = _locationName(store, payload['location_id']);
    }
    if (payload.containsKey('supplier_id')) {
      component['supplier_name'] = _supplierName(store, payload['supplier_id']);
    }
    component['updated_at'] = DateTime.now().toIso8601String();
    await store.save();
    return component;
  }

  @override
  Future<void> deleteComponent(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteComponent(id);
      return;
    }
    final store = await _LocalStore.load();
    store.components.removeWhere((item) => item['id'] == id);
    await store.save();
  }

  @override
  Future<Map<String, dynamic>> createComponentType(
    String name, {
    String? iconSvg,
    String? parentTypeId,
  }) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.createComponentType(
        name,
        iconSvg: iconSvg,
        parentTypeId: parentTypeId,
      );
    }
    final store = await _LocalStore.load();
    final normalizedName = name.trim().toLowerCase();
    final duplicate = store.componentTypes.any(
      (t) =>
          (t['is_active'] != false) &&
          ((t['name'] as String?)?.trim().toLowerCase() == normalizedName),
    );
    if (duplicate) {
      throw ApiException(409, "Component type '$name' already exists");
    }

    final parentName = parentTypeId != null
        ? (store.componentTypes.firstWhere(
                (t) => t['id'] == parentTypeId,
                orElse: () => <String, dynamic>{},
              )['name']
              as String?)
        : null;
    final item = {
      'id': _uuid.v4(),
      'name': name,
      'icon_svg': iconSvg,
      'parent_type_id': parentTypeId,
      'parent_type_name': parentName,
      'is_active': true,
    };
    store.componentTypes.add(item);
    await store.save();
    return item;
  }

  @override
  Future<Map<String, dynamic>> updateComponentType(
    String id,
    String name, {
    String? iconSvg,
    String? parentTypeId,
    bool updateParent = false,
  }) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateComponentType(
        id,
        name,
        iconSvg: iconSvg,
        parentTypeId: parentTypeId,
        updateParent: updateParent,
      );
    }
    final store = await _LocalStore.load();
    final normalizedName = name.trim().toLowerCase();
    final duplicate = store.componentTypes.any(
      (t) =>
          t['id'] != id &&
          (t['is_active'] != false) &&
          ((t['name'] as String?)?.trim().toLowerCase() == normalizedName),
    );
    if (duplicate) {
      throw ApiException(409, "Component type '$name' already exists");
    }

    final item = _byId(store.componentTypes, id, 'Component type');
    final oldName = item['name'];
    item['name'] = name;
    if (iconSvg != null) {
      item['icon_svg'] = iconSvg;
    }
    if (updateParent) {
      item['parent_type_id'] = parentTypeId;
      final parentName = parentTypeId != null
          ? (store.componentTypes.firstWhere(
                  (t) => t['id'] == parentTypeId,
                  orElse: () => <String, dynamic>{},
                )['name']
                as String?)
          : null;
      item['parent_type_name'] = parentName;
    }
    for (final component in store.components) {
      if (component['package_type'] == oldName) {
        component['package_type'] = name;
      }
    }
    await store.save();
    return item;
  }

  @override
  Future<void> deleteComponentType(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteComponentType(id);
      return;
    }
    final store = await _LocalStore.load();
    final index = store.componentTypes.indexWhere((t) => t['id'] == id);
    if (index < 0) return;
    final typeName = store.componentTypes[index]['name'] as String? ?? '';

    final usedCount = store.components.where((c) {
      if (c['is_archived'] == true) return false;
      return (c['package_type'] as String?)?.trim() == typeName.trim();
    }).length;
    if (usedCount > 0) {
      throw Exception(
        "Cannot delete component type '$typeName': $usedCount component(s) are assigned to it.",
      );
    }

    final childCount = store.componentTypes.where((t) {
      if (t['is_active'] == false) return false;
      return t['parent_type_id'] == id;
    }).length;
    if (childCount > 0) {
      throw Exception(
        "Cannot delete component type '$typeName': $childCount sub-type(s) depend on it.",
      );
    }

    store.componentTypes.removeAt(index);
    await store.save();
  }

  @override
  Future<Map<String, dynamic>> createLocation(
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.createLocation(payload);
    }
    final store = await _LocalStore.load();
    final locName = (payload['name'] as String?)?.trim() ?? '';
    if (locName.isNotEmpty) {
      final duplicate = store.locations.any(
        (l) =>
            (l['is_active'] != false) &&
            ((l['name'] as String?)?.trim().toLowerCase() ==
                locName.toLowerCase()),
      );
      if (duplicate) {
        throw ApiException(409, "Location '$locName' already exists");
      }
    }

    final id = _uuid.v4();
    final generateQr = payload['generate_qr_code'] == true;
    final item = Map<String, dynamic>.from(payload);
    item['id'] = id;
    item['qr_code_value'] = generateQr
        ? 'location:$id'
        : (payload['qr_code_value'] as String?);
    item['display_name'] = _displayName(payload);
    item['is_active'] = true;
    store.locations.add(item);
    await store.save();
    return item;
  }

  @override
  Future<Map<String, dynamic>> updateLocation(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateLocation(id, payload);
    }
    final store = await _LocalStore.load();
    if (payload.containsKey('name')) {
      final locName = (payload['name'] as String?)?.trim() ?? '';
      if (locName.isNotEmpty) {
        final duplicate = store.locations.any(
          (l) =>
              l['id'] != id &&
              (l['is_active'] != false) &&
              ((l['name'] as String?)?.trim().toLowerCase() ==
                  locName.toLowerCase()),
        );
        if (duplicate) {
          throw ApiException(409, "Location '$locName' already exists");
        }
      }
    }

    final item = _byId(store.locations, id, 'Location');
    item.addAll(payload);
    if (payload.containsKey('generate_qr_code')) {
      if (payload['generate_qr_code'] == true) {
        item['qr_code_value'] = 'location:$id';
      } else if (payload['generate_qr_code'] == false) {
        item['qr_code_value'] = null;
      }
    }
    item['display_name'] = _displayName(item);
    for (final component in store.components) {
      if (component['location_id'] == id) {
        component['location_name'] = item['display_name'];
      }
    }
    await store.save();
    return item;
  }

  @override
  Future<void> deleteLocation(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteLocation(id);
      return;
    }
    final store = await _LocalStore.load();
    final index = store.locations.indexWhere((l) => l['id'] == id);
    if (index < 0) return;
    final locName = store.locations[index]['name'] as String? ?? 'Location';

    final usedCount = store.components.where((c) {
      if (c['is_archived'] == true) return false;
      return c['location_id'] == id;
    }).length;
    if (usedCount > 0) {
      throw Exception(
        "Cannot delete location '$locName': $usedCount component(s) are stored here.",
      );
    }

    final childCount = store.locations.where((l) {
      if (l['is_active'] == false) return false;
      return l['parent_location_id'] == id;
    }).length;
    if (childCount > 0) {
      throw Exception(
        "Cannot delete location '$locName': $childCount sub-location(s) depend on it.",
      );
    }

    store.locations.removeAt(index);
    await store.save();
  }

  @override
  Future<List<dynamic>> suppliers() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.suppliers();
    }
    final store = await _LocalStore.load();
    return store.suppliers.where((s) => s['is_active'] != false).toList();
  }

  @override
  Future<Map<String, dynamic>> createSupplier(
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.createSupplier(payload);
    }
    final store = await _LocalStore.load();
    final name = (payload['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      throw ApiException(400, 'Supplier name cannot be empty');
    }
    final duplicate = store.suppliers.any(
      (s) =>
          (s['is_active'] != false) &&
          ((s['name'] as String?)?.trim().toLowerCase() == name.toLowerCase()),
    );
    if (duplicate) {
      throw ApiException(409, "Supplier '$name' already exists");
    }
    final now = DateTime.now().toIso8601String();
    final item = {
      'id': _uuid.v4(),
      'name': name,
      'website': payload['website'],
      'contact': payload['contact'],
      'notes': payload['notes'],
      'is_favorite': false,
      'is_active': true,
      'created_at': now,
      'updated_at': now,
    };
    store.suppliers.add(item);
    await store.save();
    return item;
  }

  @override
  Future<Map<String, dynamic>> updateSupplier(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateSupplier(id, payload);
    }
    final store = await _LocalStore.load();
    final item = _byId(store.suppliers, id, 'Supplier');
    if (payload.containsKey('name')) {
      final name = (payload['name'] as String?)?.trim() ?? '';
      if (name.isNotEmpty) {
        final duplicate = store.suppliers.any(
          (s) =>
              s['id'] != id &&
              (s['is_active'] != false) &&
              ((s['name'] as String?)?.trim().toLowerCase() ==
                  name.toLowerCase()),
        );
        if (duplicate) {
          throw ApiException(409, "Supplier '$name' already exists");
        }
      }
    }
    item.addAll(payload);
    if (payload.containsKey('name')) {
      final newName = item['name'];
      for (final component in store.components) {
        if (component['supplier_id'] == id) {
          component['supplier_name'] = newName;
        }
      }
    }
    item['updated_at'] = DateTime.now().toIso8601String();
    await store.save();
    return item;
  }

  @override
  Future<void> deleteSupplier(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteSupplier(id);
      return;
    }
    final store = await _LocalStore.load();
    final item = _byId(store.suppliers, id, 'Supplier');
    item['is_active'] = false;
    item['updated_at'] = DateTime.now().toIso8601String();
    await store.save();
  }

  @override
  Future<Map<String, dynamic>> postTransaction(Map<String, dynamic> payload) {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.postTransaction(payload);
    }
    return _saveTransaction(payload);
  }

  @override
  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateTransaction(id, payload);
    }
    final store = await _LocalStore.load();
    final old = _byId(store.transactions, id, 'Stock movement');
    await _reverseTransaction(store, old);
    store.transactions.removeWhere((item) => item['id'] == id);
    await store.save();
    return _saveTransaction(
      payload,
      id: id,
      code: old['transaction_code'] as String?,
    );
  }

  @override
  Future<Map<String, dynamic>> transaction(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.transaction(id);
    }
    return _byId((await _LocalStore.load()).transactions, id, 'Stock movement');
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteTransaction(id);
      return;
    }
    final store = await _LocalStore.load();
    final old = _byId(store.transactions, id, 'Stock movement');
    await _reverseTransaction(store, old);
    store.transactions.removeWhere((item) => item['id'] == id);
    await store.save();
  }

  @override
  Future<Map<String, dynamic>> createProject(
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.createProject(payload);
    }
    final store = await _LocalStore.load();
    final item = Map<String, dynamic>.from(payload);
    item['status'] = 'To Do';
    item['id'] = _uuid.v4();
    item['image_url'] = null;
    item['is_archived'] = false;
    item['created_at'] = DateTime.now().toIso8601String();
    store.projects.insert(0, item);
    await store.save();
    return item;
  }

  @override
  Future<Map<String, dynamic>> updateProject(
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.updateProject(id, payload);
    }
    final store = await _LocalStore.load();
    final item = _byId(store.projects, id, 'Project');
    final oldStatus = item['status'] as String? ?? 'To Do';
    final newStatus = payload['status'] as String? ?? oldStatus;
    item.addAll(payload);

    // Stock transition logic (mirrors backend)
    final wasActive = oldStatus == 'In Progress' || oldStatus == 'Completed';
    final isActive = newStatus == 'In Progress' || newStatus == 'Completed';
    if (!wasActive && isActive) {
      // To Do → active: deduct stock for all project components
      for (final line in store.projectComponents.where(
        (l) => l['project_id'] == id,
      )) {
        final component = _byId(
          store.components,
          line['component_id'] as String,
          'Component',
        );
        component['current_quantity'] = _stringNumber(
          _number(component['current_quantity']) - _number(line['quantity']),
        );
      }
    } else if (wasActive && !isActive) {
      // active → To Do: return stock
      for (final line in store.projectComponents.where(
        (l) => l['project_id'] == id,
      )) {
        final component = _byId(
          store.components,
          line['component_id'] as String,
          'Component',
        );
        component['current_quantity'] = _stringNumber(
          _number(component['current_quantity']) + _number(line['quantity']),
        );
      }
    }

    await store.save();
    return item;
  }

  @override
  Future<void> deleteProject(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteProject(id);
      return;
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, id, 'Project');
    final status = project['status'] as String? ?? 'To Do';
    final wasActive = status == 'In Progress' || status == 'Completed';
    if (wasActive) {
      final lines = store.projectComponents
          .where((item) => item['project_id'] == id)
          .toList();
      for (final line in lines) {
        final component = _byId(
          store.components,
          line['component_id'] as String,
          'Component',
        );
        component['current_quantity'] = _stringNumber(
          _number(component['current_quantity']) + _number(line['quantity']),
        );
      }
    }

    store.projectComponents.removeWhere((item) => item['project_id'] == id);
    store.projects.removeWhere((item) => item['id'] == id);
    await store.save();
  }

  @override
  Future<List<dynamic>> projectComponents(String projectId) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.projectComponents(projectId);
    }
    final store = await _LocalStore.load();
    return store.projectComponents
        .where((item) => item['project_id'] == projectId)
        .toList();
  }

  @override
  Future<List<dynamic>> replaceProjectComponents(
    String projectId,
    List<Map<String, dynamic>> lines,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.replaceProjectComponents(projectId, lines);
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, projectId, 'Project');
    final isActive = (project['status'] as String? ?? 'To Do') != 'To Do';
    if (isActive) {
      final oldQuantities = <String, double>{};
      for (final line in store.projectComponents.where(
        (item) => item['project_id'] == projectId,
      )) {
        oldQuantities[line['component_id'] as String] =
            (oldQuantities[line['component_id'] as String] ?? 0) +
            _number(line['quantity']);
      }
      final newQuantities = <String, double>{};
      for (final line in lines) {
        final componentId = line['component_id'] as String;
        newQuantities[componentId] =
            (newQuantities[componentId] ?? 0) + _number(line['quantity']);
      }
      final allKeys = <String>{};
      allKeys.addAll(oldQuantities.keys);
      allKeys.addAll(newQuantities.keys);
      for (final componentId in allKeys) {
        final component = _byId(store.components, componentId, 'Component');
        final difference =
            (newQuantities[componentId] ?? 0) -
            (oldQuantities[componentId] ?? 0);
        component['current_quantity'] = _stringNumber(
          _number(component['current_quantity']) - difference,
        );
      }
    }
    store.projectComponents.removeWhere(
      (item) => item['project_id'] == projectId,
    );
    for (final line in lines) {
      store.projectComponents.add(_projectLine(store, projectId, line));
    }
    await store.save();
    return projectComponents(projectId);
  }

  @override
  Future<Map<String, dynamic>> setProjectComponent(
    String projectId,
    String componentId,
    String quantity, {
    String? notes,
  }) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.setProjectComponent(
        projectId,
        componentId,
        quantity,
        notes: notes,
      );
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, projectId, 'Project');
    final isActive = (project['status'] as String? ?? 'To Do') != 'To Do';
    final existing = store.projectComponents
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) =>
              item?['project_id'] == projectId &&
              item?['component_id'] == componentId,
          orElse: () => null,
        );
    if (isActive) {
      final component = _byId(store.components, componentId, 'Component');
      final difference = _number(quantity) - _number(existing?['quantity']);
      component['current_quantity'] = _stringNumber(
        _number(component['current_quantity']) - difference,
      );
    }
    store.projectComponents.removeWhere(
      (item) =>
          item['project_id'] == projectId &&
          item['component_id'] == componentId,
    );
    final line = _projectLine(store, projectId, {
      'component_id': componentId,
      'quantity': quantity,
      'notes': notes,
    });
    store.projectComponents.add(line);
    await store.save();
    return line;
  }

  @override
  Future<void> removeProjectComponent(
    String projectId,
    String componentId,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.removeProjectComponent(projectId, componentId);
      return;
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, projectId, 'Project');
    final isActive = (project['status'] as String? ?? 'To Do') != 'To Do';
    final existing = store.projectComponents
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) =>
              item?['project_id'] == projectId &&
              item?['component_id'] == componentId,
          orElse: () => null,
        );
    if (isActive && existing != null) {
      final component = _byId(store.components, componentId, 'Component');
      component['current_quantity'] = _stringNumber(
        _number(component['current_quantity']) + _number(existing['quantity']),
      );
    }
    store.projectComponents.removeWhere(
      (item) =>
          item['project_id'] == projectId &&
          item['component_id'] == componentId,
    );
    await store.save();
  }

  @override
  Future<Map<String, dynamic>> uploadComponentImage(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.uploadComponentImage(id, filename, bytes);
    }
    final store = await _LocalStore.load();
    final component = _byId(store.components, id, 'Component');
    final dataUri =
        'data:image/${_imageExt(filename)};base64,${base64Encode(bytes)}';
    component['primary_image_thumbnail'] = dataUri;
    component['primary_image_preview'] = dataUri;
    await store.save();
    return {'id': _uuid.v4(), 'thumbnail_url': dataUri, 'preview_url': dataUri};
  }

  @override
  Future<Map<String, dynamic>> uploadComponentDatasheet(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.uploadComponentDatasheet(id, filename, bytes);
    }
    final store = await _LocalStore.load();
    final component = _byId(store.components, id, 'Component');
    final dataUri =
        'data:application/octet-stream;base64,${base64Encode(bytes)}';
    component['datasheet_url'] = dataUri;
    await store.save();
    return {'datasheet_url': dataUri};
  }

  @override
  Future<void> deleteComponentDatasheet(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      await _remoteClient!.deleteComponentDatasheet(id);
      return;
    }
    final store = await _LocalStore.load();
    final component = _byId(store.components, id, 'Component');
    component['datasheet_url'] = null;
    await store.save();
  }

  @override
  Future<List<dynamic>> componentImages(String id) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.componentImages(id);
    }
    final component = _byId(
      (await _LocalStore.load()).components,
      id,
      'Component',
    );
    final path = component['primary_image_preview'];
    return path == null
        ? []
        : [
            {
              'id': id,
              'preview_url': path,
              'thumbnail_url': component['primary_image_thumbnail'],
            },
          ];
  }

  @override
  Future<Map<String, dynamic>> uploadProjectImage(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.uploadProjectImage(id, filename, bytes);
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, id, 'Project');
    project['image_url'] =
        'data:image/${_imageExt(filename)};base64,${base64Encode(bytes)}';
    await store.save();
    return project;
  }

  @override
  Future<ReportDownload> downloadInventoryReport(String format) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.downloadInventoryReport(format);
    }
    final components = await this.components();
    if (format.trim().toLowerCase() == 'pdf') {
      return ReportDownload(
        filename: 'inventory.pdf',
        bytes: await _buildInventoryPdf(
          components.cast<Map<String, dynamic>>(),
        ),
      );
    }
    final rows = [
      'Code,Name,Type,Manufacturer,Location,Quantity,Unit',
      for (final item in components)
        [
          _csv(item['inventory_code']),
          _csv(item['name']),
          _csv(item['package_type']),
          _csv(item['manufacturer']),
          _csv(item['location_name']),
          _csv(item['current_quantity']),
          _csv(item['unit']),
        ].join(','),
    ].join('\n');
    return ReportDownload(
      filename: 'inventory.csv',
      bytes: Uint8List.fromList(utf8.encode(rows)),
    );
  }

  @override
  Future<ReportDownload> downloadLocationLabels() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.downloadLocationLabels();
    }
    final store = await _LocalStore.load();
    final locations = store.locations
        .where((item) => item['is_active'] != false &&
            '${item['qr_code_value'] ?? ''}'.trim().isNotEmpty)
        .toList();
    final document = pw.Document();
    final rows = <pw.Widget>[];
    for (var i = 0; i < locations.length; i += 3) {
      rows.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final item in locations.skip(i).take(3))
              pw.Expanded(
                child: pw.Container(
                  height: 90,
                  margin: const pw.EdgeInsets.all(5),
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: '${item['qr_code_value']}',
                        width: 52,
                        height: 52,
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('${item['display_name'] ?? item['name'] ?? 'Location'}',
                          maxLines: 1, textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),
              ),
            if (locations.skip(i).take(3).length < 3)
              ...List.generate(3 - locations.skip(i).take(3).length,
                  (_) => pw.Expanded(child: pw.SizedBox())),
          ],
        ),
      );
    }
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      build: (_) => rows.isEmpty
          ? [pw.Center(child: pw.Text('No locations have QR codes.'))]
          : rows,
    ));
    return ReportDownload(
      filename: 'location_qr_labels.pdf',
      bytes: await document.save(),
    );
  }

  @override
  Future<ReportDownload> downloadProjectReport(String projectId) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.downloadProjectReport(projectId);
    }
    final store = await _LocalStore.load();
    final project = _byId(store.projects, projectId, 'Project');
    final lines = store.projectComponents
        .where((item) => item['project_id'] == projectId)
        .toList();
    final title = '${project['name'] ?? 'Project'}';
    return ReportDownload(
      filename: '${_filenameStem(title)}.pdf',
      bytes: await _buildProjectPdf(project, lines),
    );
  }

  @override
  Future<ReportDownload> downloadBackup() async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.downloadBackup();
    }
    final prefs = await SharedPreferences.getInstance();
    return ReportDownload(
      filename: 'tech_panda_inventory_backup.json',
      bytes: Uint8List.fromList(
        utf8.encode(prefs.getString(_storeKey) ?? '{}'),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> restoreBackup(
    String filename,
    Uint8List bytes,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.restoreBackup(filename, bytes);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, utf8.decode(bytes));
    return {'restored': true};
  }

  @override
  Future<Map<String, dynamic>> importComponentsCsv(
    String filename,
    Uint8List bytes,
  ) async {
    if (_remoteEnabled && _remoteClient != null) {
      return _remoteClient!.importComponentsCsv(filename, bytes);
    }
    final store = await _LocalStore.load();
    String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      content = latin1.decode(bytes);
    }
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }

    final rows = _parseCsv(content);
    if (rows.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final header = rows[0].map((c) => c.trim().toLowerCase()).toList();
    final fieldMap = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      final norm = header[i].replaceAll(' ', '_').replaceAll('-', '_');
      fieldMap[norm] = i;
    }

    String getVal(List<String> row, List<String> aliases) {
      for (final alias in aliases) {
        final norm = alias
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('-', '_');
        if (fieldMap.containsKey(norm)) {
          final idx = fieldMap[norm]!;
          if (idx < row.length) {
            final val = row[idx].trim();
            if (val.isNotEmpty) return val;
          }
        }
      }
      return '';
    }

    final defaultCat = store.categories.isNotEmpty
        ? store.categories.first
        : null;
    if (defaultCat == null) {
      throw Exception('No category found in local database');
    }

    int importedCount = 0;
    int skippedCount = 0;
    final errors = <String>[];

    for (var rowIdx = 1; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx];
      if (row.isEmpty || row.every((c) => c.trim().isEmpty)) continue;

      final name = getVal(row, ['name', 'component_name', 'title']);
      if (name.isEmpty) {
        skippedCount++;
        errors.add('Row ${rowIdx + 1}: Component name is missing');
        continue;
      }

      // Check duplicates
      final exists = store.components.any(
        (c) =>
            c['is_archived'] != true &&
            (c['name'] as String?)?.trim().toLowerCase() == name.toLowerCase(),
      );
      if (exists) {
        skippedCount++;
        errors.add("Row ${rowIdx + 1} ('$name'): Component already exists");
        continue;
      }

      final typeName = getVal(row, ['type', 'package_type', 'component_type']);
      if (typeName.isNotEmpty) {
        final hasType = store.componentTypes.any(
          (t) =>
              (t['name'] as String?)?.trim().toLowerCase() ==
              typeName.toLowerCase(),
        );
        if (!hasType) {
          store.componentTypes.add({
            'id': _uuid.v4(),
            'name': typeName,
            'is_active': true,
          });
        }
      }

      final locName = getVal(row, ['location', 'location_name']);
      String? locationId;
      if (locName.isNotEmpty) {
        final existingLoc = store.locations
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (l) =>
                  l?['is_active'] != false &&
                  ((l?['display_name'] as String?)?.trim().toLowerCase() ==
                          locName.toLowerCase() ||
                      (l?['name'] as String?)?.trim().toLowerCase() ==
                          locName.toLowerCase()),
              orElse: () => null,
            );
        if (existingLoc != null) {
          locationId = existingLoc['id'] as String?;
        } else {
          locationId = _uuid.v4();
          store.locations.add({
            'id': locationId,
            'name': locName,
            'display_name': locName,
            'is_active': true,
          });
        }
      }

      final suppName = getVal(row, ['supplier', 'supplier_name']);
      String? supplierId;
      if (suppName.isNotEmpty) {
        final existingSupp = store.suppliers
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (s) =>
                  s?['is_active'] != false &&
                  (s?['name'] as String?)?.trim().toLowerCase() ==
                      suppName.toLowerCase(),
              orElse: () => null,
            );
        if (existingSupp != null) {
          supplierId = existingSupp['id'] as String?;
        } else {
          supplierId = _uuid.v4();
          store.suppliers.add({
            'id': supplierId,
            'name': suppName,
            'is_active': true,
          });
        }
      }

      final qtyStr = getVal(row, [
        'quantity',
        'current_quantity',
        'opening_quantity',
        'stock',
      ]);
      final openingQty = double.tryParse(qtyStr) ?? 0.0;

      final minStr = getVal(row, [
        'minimum',
        'minimum_quantity',
        'min_quantity',
        'min',
      ]);
      final minQty = double.tryParse(minStr) ?? 0.0;

      final priceStr = getVal(row, ['price', 'unit_price', 'cost']);
      final cleanedPrice = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
      final price = double.tryParse(cleanedPrice);

      final unit = getVal(row, ['unit']).isNotEmpty
          ? getVal(row, ['unit'])
          : 'Pieces';
      final description = getVal(row, ['details', 'description', 'desc']);
      final partNumber = getVal(row, [
        'part_number',
        'part_no',
        'part#',
        'mpn',
      ]);
      final manufacturer = getVal(row, ['manufacturer', 'mfg', 'brand']);
      final modelNumber = getVal(row, ['model_number', 'model']);
      final datasheetUrl = getVal(row, ['datasheet', 'datasheet_url', 'pdf']);
      final expiryDate = getVal(row, [
        'expiry_date',
        'expiry',
        'expiration_date',
      ]);

      final now = DateTime.now().toIso8601String();
      final compId = _uuid.v4();
      final component = {
        'id': compId,
        'inventory_code':
            '${defaultCat['code_prefix'] ?? 'TP'}-${(store.components.length + 1).toString().padLeft(4, '0')}',
        'name': name,
        'category_id': defaultCat['id'],
        'manufacturer': manufacturer.isNotEmpty ? manufacturer : null,
        'model_number': modelNumber.isNotEmpty ? modelNumber : null,
        'part_number': partNumber.isNotEmpty ? partNumber : null,
        'package_type': typeName.isNotEmpty ? typeName : null,
        'description': description.isNotEmpty ? description : null,
        'current_quantity': _stringNumber(openingQty),
        'minimum_quantity': _stringNumber(minQty),
        'unit': unit,
        'price': price != null && price > 0 ? _stringNumber(price) : null,
        'datasheet_url': datasheetUrl.isNotEmpty ? datasheetUrl : null,
        'datasheet_text': null,
        'expiry_date': expiryDate.isNotEmpty ? expiryDate : null,
        'location_id': locationId,
        'location_name': _locationName(store, locationId),
        'supplier_id': supplierId,
        'supplier_name': _supplierName(store, supplierId),
        'primary_image_thumbnail': null,
        'primary_image_preview': null,
        'can_delete': true,
        'is_favorite': false,
        'is_archived': false,
        'created_at': now,
        'updated_at': now,
      };

      store.components.add(component);

      if (openingQty > 0) {
        store.transactions.insert(0, {
          'id': _uuid.v4(),
          'transaction_code':
              'TX-${(store.transactions.length + 1).toString().padLeft(4, '0')}',
          'transaction_type': 'stock_in',
          'status': 'posted',
          'notes': 'CSV bulk import opening stock',
          'created_at': now,
          'lines': [
            {
              'component_id': compId,
              'quantity': _stringNumber(openingQty),
              'unit': unit,
              'notes': 'CSV import',
              'quantity_delta': _stringNumber(openingQty),
              'quantity_before': '0',
              'quantity_after': _stringNumber(openingQty),
            },
          ],
        });
      }

      importedCount++;
    }

    await store.save();
    return {
      'success': true,
      'imported': importedCount,
      'skipped': skippedCount,
      'errors': errors.take(20).toList(),
    };
  }

  Future<Map<String, dynamic>> _saveTransaction(
    Map<String, dynamic> payload, {
    String? id,
    String? code,
  }) async {
    final store = await _LocalStore.load();
    final now = DateTime.now().toIso8601String();
    final type = payload['transaction_type'] as String;
    final lines = (payload['lines'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final line in lines) {
      final component = _byId(
        store.components,
        line['component_id'] as String,
        'Component',
      );
      final before = _number(component['current_quantity']);
      final qty = _number(line['quantity']);
      final delta = _addsStock(type) ? qty : -qty;
      component['current_quantity'] = _stringNumber(before + delta);
      line['quantity_delta'] = _stringNumber(delta);
      line['quantity_before'] = _stringNumber(before);
      line['quantity_after'] = _stringNumber(before + delta);
    }
    final tx = {
      'id': id ?? _uuid.v4(),
      'transaction_code':
          code ??
          'TX-${(store.transactions.length + 1).toString().padLeft(4, '0')}',
      'transaction_type': type,
      'status': 'posted',
      'project_id': payload['project_id'],
      'can_modify': payload['project_id'] == null,
      'line_count': lines.length,
      'total_quantity': _stringNumber(
        lines.fold<double>(0, (sum, line) => sum + _number(line['quantity'])),
      ),
      'reason': payload['reason'],
      'notes': payload['notes'],
      'lines': lines.map((line) => _transactionLine(store, line)).toList(),
      'created_at': now,
    };
    store.transactions.insert(0, tx);
    await store.save();
    return tx;
  }

  Future<void> _reverseTransaction(
    _LocalStore store,
    Map<String, dynamic> tx,
  ) async {
    for (final line in (tx['lines'] as List<dynamic>? ?? [])) {
      final component = _byId(
        store.components,
        line['component_id'] as String,
        'Component',
      );
      component['current_quantity'] = _stringNumber(
        _number(component['current_quantity']) -
            _number(line['quantity_delta']),
      );
    }
  }
}

class _LocalStore {
  _LocalStore(this.data);

  final Map<String, dynamic> data;

  List<Map<String, dynamic>> get categories => _list('categories');
  List<Map<String, dynamic>> get componentTypes => _list('component_types');
  List<Map<String, dynamic>> get locations => _list('locations');
  List<Map<String, dynamic>> get suppliers => _list('suppliers');
  List<Map<String, dynamic>> get components => _list('components');
  List<Map<String, dynamic>> get transactions => _list('transactions');
  List<Map<String, dynamic>> get projects => _list('projects');
  List<Map<String, dynamic>> get projectComponents =>
      _list('project_components');

  static Future<_LocalStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.trim().isEmpty) return _LocalStore(_seed());
    return _LocalStore(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeKey, jsonEncode(data));
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = data.putIfAbsent(key, () => <dynamic>[]) as List<dynamic>;
    return value.cast<Map<String, dynamic>>();
  }
}

Map<String, dynamic> _seed() => {
  'categories': [
    {
      'id': 'general',
      'name': 'General',
      'code_prefix': 'TP',
      'description': null,
      'is_active': true,
    },
  ],
  'component_types': <dynamic>[],
  'locations': <dynamic>[],
  'suppliers': <dynamic>[],
  'components': <dynamic>[],
  'transactions': <dynamic>[],
  'projects': <dynamic>[],
  'project_components': <dynamic>[],
};

Map<String, dynamic> _byId(
  List<Map<String, dynamic>> items,
  String id,
  String label,
) {
  return items.firstWhere(
    (item) => item['id'] == id,
    orElse: () => throw ApiException(404, '$label not found'),
  );
}

String? _locationName(_LocalStore store, Object? id) {
  if (id == null) return null;
  return store.locations.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == id,
        orElse: () => null,
      )?['display_name']
      as String?;
}

String? _supplierName(_LocalStore store, Object? id) {
  if (id == null) return null;
  return store.suppliers.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == id,
        orElse: () => null,
      )?['name']
      as String?;
}

String _displayName(Map<String, dynamic> location) {
  return ['name', 'cabinet', 'shelf', 'drawer', 'box', 'bin']
      .map((key) => location[key])
      .where((value) => value != null && '$value'.trim().isNotEmpty)
      .join(' / ');
}

Map<String, dynamic> _transactionLine(
  _LocalStore store,
  Map<String, dynamic> line,
) {
  final component = _byId(
    store.components,
    line['component_id'] as String,
    'Component',
  );
  return {
    'component_id': component['id'],
    'quantity': _stringNumber(_number(line['quantity'])),
    'unit': component['unit'],
    'line_notes': line['notes'],
    'quantity_delta': line['quantity_delta'],
    'component_name': component['name'],
    'inventory_code': component['inventory_code'],
    'package_type': component['package_type'],
    'manufacturer': component['manufacturer'],
    'location_name': component['location_name'],
    'available_quantity': component['current_quantity'],
    'primary_image_thumbnail': component['primary_image_thumbnail'],
  };
}

Map<String, dynamic> _projectLine(
  _LocalStore store,
  String projectId,
  Map<String, dynamic> line,
) {
  final component = _byId(
    store.components,
    line['component_id'] as String,
    'Component',
  );
  final now = DateTime.now().toIso8601String();
  final qty = _number(line['quantity']);
  final price = _number(component['price']);
  final totalCost = qty * price;
  return {
    'id': _uuid.v4(),
    'project_id': projectId,
    'component_id': component['id'],
    'quantity': _stringNumber(qty),
    'unit': component['unit'],
    'notes': line['notes'],
    'inventory_code': component['inventory_code'],
    'component_name': component['name'],
    'package_type': component['package_type'],
    'manufacturer': component['manufacturer'],
    'location_name': component['location_name'],
    'available_quantity': component['current_quantity'],
    'primary_image_thumbnail': component['primary_image_thumbnail'],
    'price': price > 0 ? _stringNumber(price) : null,
    'total_cost': totalCost > 0 ? _stringNumber(totalCost) : null,
    'created_at': now,
    'updated_at': now,
  };
}

bool _addsStock(String type) =>
    type == 'stock_in' || type == 'return' || type == 'adjustment';

double _number(Object? value) => double.tryParse('${value ?? 0}') ?? 0;

String _stringNumber(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

String _imageExt(String filename) {
  final ext = filename.split('.').last.toLowerCase();
  return ext == 'jpg' ? 'jpeg' : ext;
}

String _csv(Object? value) {
  final text = '${value ?? ''}'.replaceAll('"', '""');
  return '"$text"';
}

List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentField = StringBuffer();
  var insideQuotes = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (insideQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          currentField.write('"');
          i++; // skip escaped quote
        } else {
          insideQuotes = false;
        }
      } else {
        currentField.write(char);
      }
    } else {
      if (char == '"') {
        insideQuotes = true;
      } else if (char == ',') {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if (char == '\r') {
        if (i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        rows.add(List.from(currentRow));
        currentRow.clear();
      } else if (char == '\n') {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        rows.add(List.from(currentRow));
        currentRow.clear();
      } else {
        currentField.write(char);
      }
    }
  }

  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    currentRow.add(currentField.toString().trim());
    rows.add(currentRow);
  }

  return rows;
}

Future<Uint8List> _buildProjectPdf(
  Map<String, dynamic> project,
  List<Map<String, dynamic>> lines,
) async {
  final logoBytes = await rootBundle.load('assets/techpanda.png');
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final document = pw.Document();
  final title = '${project['name'] ?? 'Project'}';
  final description = (project['description'] as String? ?? '').trim();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 28, 36, 36),
      header: (context) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 42, height: 42),
          pw.SizedBox(width: 10),
          pw.Text(
            'Tech Panda Inventory',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Text(
            _techPandaYoutubeUrl,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 24),
        pw.Center(
          child: pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 18),
        if (description.isNotEmpty) ...[
          pw.Text(
            description,
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
          ),
          pw.SizedBox(height: 22),
        ],
        pw.Text(
          'Components Used',
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        _projectComponentsTable(lines),
      ],
    ),
  );

  return document.save();
}

Future<Uint8List> _buildInventoryPdf(
  List<Map<String, dynamic>> components,
) async {
  final logoBytes = await rootBundle.load('assets/techpanda.png');
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final document = pw.Document();

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 30),
      header: (context) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 36, height: 36),
          pw.SizedBox(width: 10),
          pw.Text(
            'Tech Panda Inventory',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Text(
            _techPandaYoutubeUrl,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 18),
        pw.Text(
          'Complete Inventory',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(2.2),
            2: pw.FlexColumnWidth(1.3),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.6),
            5: pw.FlexColumnWidth(0.9),
            6: pw.FlexColumnWidth(0.9),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _tableHeader('Code'),
                _tableHeader('Component'),
                _tableHeader('Type'),
                _tableHeader('Manufacturer'),
                _tableHeader('Location'),
                _tableHeader('Qty'),
                _tableHeader('Unit'),
              ],
            ),
            for (final component in components)
              pw.TableRow(
                children: [
                  _tableCell('${component['inventory_code'] ?? ''}'),
                  _tableCell('${component['name'] ?? ''}'),
                  _tableCell('${component['package_type'] ?? ''}'),
                  _tableCell('${component['manufacturer'] ?? ''}'),
                  _tableCell('${component['location_name'] ?? ''}'),
                  _tableCell('${component['current_quantity'] ?? ''}'),
                  _tableCell('${component['unit'] ?? ''}'),
                ],
              ),
          ],
        ),
      ],
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(_techPandaYoutubeUrl, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );

  return document.save();
}

pw.Widget _projectComponentsTable(List<Map<String, dynamic>> lines) {
  if (lines.isEmpty) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Text('No components have been added to this project.'),
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
        columnWidths: const {
          0: pw.FixedColumnWidth(50),
          1: pw.FlexColumnWidth(2.2),
          2: pw.FlexColumnWidth(1.6),
          3: pw.FixedColumnWidth(66),
          4: pw.FixedColumnWidth(62),
          5: pw.FixedColumnWidth(70),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _tableHeader('Image'),
              _tableHeader('Component Name'),
              _tableHeader('Location'),
              _tableHeader('Qty Used'),
              _tableHeader('Unit Price'),
              _tableHeader('Line Cost'),
            ],
          ),
          for (final line in lines)
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: _componentPdfThumbnail(
                    line['primary_image_thumbnail'] as String?,
                  ),
                ),
                _tableCell('${line['component_name'] ?? ''}'),
                _tableCell('${line['location_name'] ?? ''}'),
                _tableCell('${line['quantity'] ?? 0} ${line['unit'] ?? ''}'),
                _tableCell(line['price'] != null ? '\$${line['price']}' : '-'),
                _tableCell(
                  line['total_cost'] != null ? '\$${line['total_cost']}' : '-',
                ),
              ],
            ),
        ],
      ),
      () {
        double total = 0;
        for (final line in lines) {
          total += _number(line['total_cost']);
        }
        if (total <= 0) return pw.SizedBox.shrink();
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          child: pw.Text(
            'Total Project Cost: \$${_stringNumber(total)}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        );
      }(),
    ],
  );
}

pw.Widget _tableHeader(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _tableCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );
}

pw.Widget _componentPdfThumbnail(String? path) {
  final bytes = path == null ? null : _decodeDataImageBytes(path);
  if (bytes == null) {
    return pw.Container(
      width: 38,
      height: 38,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text('-', style: const pw.TextStyle(color: PdfColors.grey600)),
    );
  }
  return pw.ClipRRect(
    horizontalRadius: 3,
    verticalRadius: 3,
    child: pw.Image(
      pw.MemoryImage(bytes),
      width: 38,
      height: 38,
      fit: pw.BoxFit.cover,
    ),
  );
}

Uint8List? _decodeDataImageBytes(String path) {
  const marker = ';base64,';
  if (!path.startsWith('data:image/') || !path.contains(marker)) return null;
  try {
    return base64Decode(path.substring(path.indexOf(marker) + marker.length));
  } catch (_) {
    return null;
  }
}

String _filenameStem(String value) {
  final stem = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  final trimmed = stem.replaceAll(RegExp(r'^-+|-+$'), '');
  return trimmed.isEmpty ? 'project' : trimmed;
}
