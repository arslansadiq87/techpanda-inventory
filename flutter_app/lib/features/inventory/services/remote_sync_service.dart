import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/local_inventory_client.dart';

/// Service managing remote server configuration, connectivity testing, and data synchronization.
class RemoteSyncService {
  final ApiClient api;

  const RemoteSyncService({required this.api});

  /// Tests connectivity to a remote FastAPI inventory server URL.
  Future<Map<String, dynamic>> testConnection(String rawUrl) async {
    return await ApiClient.testConnection(rawUrl);
  }

  /// Configures remote server connection settings and persists to SharedPreferences.
  Future<void> configureRemote({
    required bool enabled,
    required String url,
  }) async {
    if (api is LocalInventoryClient) {
      await (api as LocalInventoryClient).configureRemote(
        enabled: enabled,
        url: url,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remote_server_enabled', enabled);
      await prefs.setString('remote_server_url', url);
    }
  }

  /// Synchronizes local inventory store items (suppliers, locations, component types, components, images) to remote server.
  Future<void> syncToRemote({
    required ValueChanged<double?> onProgress,
    required ValueChanged<String?> onError,
  }) async {
    final client = api as dynamic;
    onProgress(0.0);
    onError(null);

    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString('tech_panda_local_inventory_store_v1');
      if (raw == null || raw.trim().isEmpty) {
        onProgress(null);
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final components = (data['components'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((c) => c['is_archived'] != true)
          .toList();
      final suppliers = (data['suppliers'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['is_active'] != false)
          .toList();
      final locations = (data['locations'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final componentTypes = (data['component_types'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .where((t) => t['is_active'] != false)
          .toList();

      int done = 0;
      final total = suppliers.length +
          locations.length +
          componentTypes.length +
          components.length;

      void tick() {
        done++;
        onProgress(done / total.clamp(1, total));
      }

      // Upload suppliers
      for (final s in suppliers) {
        try {
          await client.createSupplier({
            'name': s['name'],
            'website': s['website'],
            'contact': s['contact'],
            'notes': s['notes'],
          });
        } catch (_) {}
        tick();
      }

      // Upload locations
      for (final l in locations) {
        try {
          await client.createLocation({
            'name': l['name'],
            'room': l['room'],
            'shelf': l['shelf'],
            'bin': l['bin'],
            'generate_qr_code': l['qr_code_value'] != null,
          });
        } catch (_) {}
        tick();
      }

      // Upload component types
      for (final t in componentTypes) {
        try {
          await client.createComponentType(
            t['name'] as String,
            iconSvg: t['icon_svg'] as String?,
          );
        } catch (_) {}
        tick();
      }

      // Upload components + images
      for (final c in components) {
        Map<String, dynamic>? created;
        try {
          created = await client.createComponent({
            'name': c['name'],
            'category_id': c['category_id'] ?? 'general',
            'manufacturer': c['manufacturer'],
            'model_number': c['model_number'],
            'part_number': c['part_number'],
            'package_type': c['package_type'],
            'description': c['description'],
            'opening_quantity': c['current_quantity'],
            'minimum_quantity': c['minimum_quantity'],
            'unit': c['unit'],
            'price': c['price'],
            'datasheet_text': c['datasheet_text'],
            'expiry_date': c['expiry_date'],
            'location_id': null,
            'supplier_id': null,
          });
        } catch (_) {}

        final imgPath = c['primary_image_preview'] as String?;
        if (created != null && imgPath != null && imgPath.startsWith('data:')) {
          try {
            final parts = imgPath.split(',');
            if (parts.length == 2) {
              final bytes = base64Decode(parts[1]);
              await client.uploadComponentImage(
                created['id'] as String,
                'image.jpg',
                bytes as dynamic,
              );
            }
          } catch (_) {}
        }
        tick();
      }
    } catch (e) {
      onError('Sync error: $e');
    } finally {
      onProgress(null);
    }
  }
}

