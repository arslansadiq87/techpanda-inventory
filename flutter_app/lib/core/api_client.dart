import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_http_client_stub.dart'
    if (dart.library.io) 'secure_http_client_io.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);

class ReportDownload {
  const ReportDownload({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, this.onUnauthorized})
    : _client = client ?? createApiHttpClient(),
      _activeBaseUrl = baseUrl;

  final http.Client _client;
  VoidCallback? onUnauthorized;
  String? accessToken;
  String? _activeBaseUrl;

  String get activeBaseUrl {
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      return _activeBaseUrl!;
    }
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty &&
          !origin.contains('localhost:3000') &&
          !origin.contains('127.0.0.1:3000')) {
        return '$origin/api/v1';
      }
    }
    return apiBaseUrl;
  }

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (accessToken != null) 'authorization': 'Bearer $accessToken',
  };

  static Future<Map<String, dynamic>> testConnection(String rawUrl) async {
    var u = rawUrl.trim();
    if (u.isEmpty) {
      throw Exception('Server URL cannot be empty');
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.endsWith('/api/v1')) {
      u = '$u/api/v1';
    }
    final client = createApiHttpClient();
    try {
      final response = await client
          .get(
            Uri.parse('$u/health/live'),
            headers: {'accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () =>
                throw TimeoutException('Connection timed out after 8s'),
          );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          return {'status': 'ok'};
        }
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    return accessToken != null;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _request(
      (baseUrl) => _client.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'device_name': 'Flutter client',
        }),
      ),
    );
    _check(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    accessToken = data['access_token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken!);
    return data;
  }

  Future<void> logout() async {
    accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  Future<Map<String, dynamic>> uiSettings() => _getMap('/settings/ui');

  Future<Map<String, dynamic>> updateUiSettings({required bool darkMode}) =>
      _putMap('/settings/ui', {'dark_mode': darkMode});

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _postMap('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> dashboard() async => _getMap('/dashboard');
  Future<List<dynamic>> categories() async => _getList('/categories');
  Future<List<dynamic>> componentTypes() async => _getList('/component-types');
  Future<List<dynamic>> locations() async => _getList('/locations');
  Future<List<dynamic>> transactions() async => _getList('/transactions');

  Future<List<dynamic>> transactionsPage({
    int page = 1,
    int limit = 25,
    DateTime? before,
    DateTime? after,
    String? componentId,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (before != null) params['before'] = before.toUtc().toIso8601String();
    if (after != null) params['after'] = after.toUtc().toIso8601String();
    if (componentId != null && componentId.isNotEmpty) {
      params['component_id'] = componentId;
    }
    return _getList(
      Uri(path: '/transactions', queryParameters: params).toString(),
    );
  }

  Future<List<dynamic>> projects() async => _getList('/projects');
  Future<List<dynamic>> alerts() async => _getList('/alerts');
  Future<List<dynamic>> reorderList() async => _getList('/reorder-list');

  Future<List<dynamic>> components({String query = '', int limit = 500}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    final suffix = Uri(path: '/components', queryParameters: params).toString();
    return _getList(suffix);
  }

  Future<Map<String, dynamic>> createComponent(Map<String, dynamic> payload) =>
      _postMap('/components', payload);
  Future<Map<String, dynamic>> updateComponent(
    String id,
    Map<String, dynamic> payload,
  ) => _patchMap('/components/$id', payload);
  Future<void> deleteComponent(String id) => _delete('/components/$id');
  Future<Map<String, dynamic>> createComponentType(
    String name, {
    String? iconSvg,
    String? parentTypeId,
  }) => _postMap('/component-types', {
    'name': name,
    'icon_svg': iconSvg,
    // ignore: use_null_aware_elements
    if (parentTypeId != null) 'parent_type_id': parentTypeId,
  });
  Future<Map<String, dynamic>> updateComponentType(
    String id,
    String name, {
    String? iconSvg,
    String? parentTypeId,
    bool updateParent = false,
  }) {
    final payload = <String, dynamic>{'name': name};
    if (iconSvg != null) payload['icon_svg'] = iconSvg;
    if (updateParent) payload['parent_type_id'] = parentTypeId;
    return _patchMap('/component-types/$id', payload);
  }

  Future<void> deleteComponentType(String id) =>
      _delete('/component-types/$id');

  Future<Map<String, dynamic>> createLocation(Map<String, dynamic> payload) =>
      _postMap('/locations', payload);
  Future<Map<String, dynamic>> updateLocation(
    String id,
    Map<String, dynamic> payload,
  ) => _patchMap('/locations/$id', payload);
  Future<void> deleteLocation(String id) => _delete('/locations/$id');
  Future<ReportDownload> downloadLocationLabels() async {
    final response = await _request(
      (baseUrl) => _client.get(
        Uri.parse('$baseUrl/locations/labels.pdf'),
        headers: _headers,
      ),
    );
    _check(response);
    return _reportDownload(response, 'location_qr_labels.pdf');
  }

  Future<List<dynamic>> suppliers() async => _getList('/suppliers');
  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> payload) =>
      _postMap('/suppliers', payload);
  Future<Map<String, dynamic>> updateSupplier(
    String id,
    Map<String, dynamic> payload,
  ) => _patchMap('/suppliers/$id', payload);
  Future<void> deleteSupplier(String id) => _delete('/suppliers/$id');
  Future<List<dynamic>> componentImages(String id) =>
      _getList('/components/$id/images');
  Future<Map<String, dynamic>> uploadComponentImage(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    final response = await _request((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/components/$id/images'),
      );
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('upload', bytes, filename: filename),
      );
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadComponentDatasheet(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    final response = await _request((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/components/$id/datasheet'),
      );
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('upload', bytes, filename: filename),
      );
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteComponentDatasheet(String id) =>
      _delete('/components/$id/datasheet');

  Future<Map<String, dynamic>> postTransaction(Map<String, dynamic> payload) =>
      _postMap('/transactions', payload);
  Future<Map<String, dynamic>> transaction(String id) =>
      _getMap('/transactions/$id');
  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> payload,
  ) => _putMap('/transactions/$id', payload);
  Future<void> deleteTransaction(String id) => _delete('/transactions/$id');
  Future<Map<String, dynamic>> createProject(Map<String, dynamic> payload) =>
      _postMap('/projects', payload);
  Future<Map<String, dynamic>> updateProject(
    String id,
    Map<String, dynamic> payload,
  ) => _patchMap('/projects/$id', payload);
  Future<void> deleteProject(String id) => _delete('/projects/$id');
  Future<Map<String, dynamic>> uploadProjectImage(
    String id,
    String filename,
    Uint8List bytes,
  ) async {
    final response = await _request((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/projects/$id/image'),
      );
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('upload', bytes, filename: filename),
      );
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> projectComponents(String projectId) =>
      _getList('/projects/$projectId/components');
  Future<List<dynamic>> replaceProjectComponents(
    String projectId,
    List<Map<String, dynamic>> lines,
  ) => _putList('/projects/$projectId/components', {'lines': lines});
  Future<Map<String, dynamic>> setProjectComponent(
    String projectId,
    String componentId,
    String quantity, {
    String? notes,
  }) => _putMap('/projects/$projectId/components/$componentId', {
    'quantity': quantity,
    'notes': notes,
  });
  Future<void> removeProjectComponent(String projectId, String componentId) =>
      _delete('/projects/$projectId/components/$componentId');

  Future<ReportDownload> downloadProjectReport(String projectId) async {
    final response = await _request(
      (baseUrl) => _client.get(
        Uri.parse('$baseUrl/projects/$projectId/report.pdf'),
        headers: Map.from(_headers)..['accept'] = 'application/pdf',
      ),
    );
    _check(response);
    return _reportDownload(response, 'project.pdf');
  }

  Future<ReportDownload> downloadInventoryReport(String format) async {
    final normalizedFormat = format.trim().toLowerCase();
    if (normalizedFormat != 'csv' && normalizedFormat != 'pdf') {
      throw ArgumentError.value(format, 'format', 'Use csv or pdf');
    }
    final response = await _request(
      (baseUrl) => _client.get(
        Uri.parse('$baseUrl/reports/inventory.$normalizedFormat'),
        headers: Map.from(_headers)
          ..['accept'] = normalizedFormat == 'pdf'
              ? 'application/pdf'
              : 'text/csv',
      ),
    );
    _check(response);
    return _reportDownload(response, 'inventory.$normalizedFormat');
  }

  Future<ReportDownload> downloadBackup() async {
    final response = await _request(
      (baseUrl) => _client.post(
        Uri.parse('$baseUrl/backups/manual'),
        headers: Map.from(_headers)..['accept'] = 'application/zip',
      ),
    );
    _check(response);
    return _reportDownload(response, 'tech_panda_inventory_backup.zip');
  }

  Future<Map<String, dynamic>> restoreBackup(
    String filename,
    Uint8List bytes,
  ) async {
    final response = await _request((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/backups/restore'),
      );
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('upload', bytes, filename: filename),
      );
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importComponentsCsv(
    String filename,
    Uint8List bytes,
  ) async {
    final response = await _request((baseUrl) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/components/import/csv'),
      );
      if (accessToken != null) {
        request.headers['authorization'] = 'Bearer $accessToken';
      }
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  ReportDownload _reportDownload(
    http.Response response,
    String fallbackFilename,
  ) {
    final disposition = response.headers['content-disposition'] ?? '';
    final filenameMatch = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return ReportDownload(
      filename: filenameMatch?.group(1)?.trim() ?? fallbackFilename,
      bytes: response.bodyBytes,
    );
  }

  String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = Uri.parse(activeBaseUrl);
    if (!base.hasAuthority) return path;
    return '${base.scheme}://${base.authority}$path';
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await _request(
      (baseUrl) => _client.get(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path) async {
    final response = await _request(
      (baseUrl) => _client.get(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    _check(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      (baseUrl) => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      (baseUrl) => _client.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _putMap(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      (baseUrl) => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    _check(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _putList(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _request(
      (baseUrl) => _client.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(payload),
      ),
    );
    _check(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> _delete(String path) async {
    final response = await _request(
      (baseUrl) =>
          _client.delete(Uri.parse('$baseUrl$path'), headers: _headers),
    );
    _check(response);
  }

  Future<String> _resolveBaseUrl() {
    if (_activeBaseUrl != null) return Future.value(_activeBaseUrl);
    return Future.value(_activeBaseUrl = apiBaseUrl);
  }

  Future<http.Response> _request(
    Future<http.Response> Function(String baseUrl) send,
  ) async {
    final baseUrl = await _resolveBaseUrl();
    try {
      return await send(baseUrl).timeout(const Duration(seconds: 20));
    } on http.ClientException {
      throw ApiConnectionException();
    } on TimeoutException {
      throw ApiConnectionException();
    }
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {}
    if (response.statusCode == 401) {
      accessToken = null;
      SharedPreferences.getInstance().then(
        (prefs) => prefs.remove('access_token'),
      );
      onUnauthorized?.call();
    }
    throw ApiException(response.statusCode, message);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => message;
}

class ApiConnectionException implements Exception {
  @override
  String toString() =>
      'Connection failed. Start the local inventory server and try again.';
}
