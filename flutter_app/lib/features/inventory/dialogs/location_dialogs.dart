import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/api_client.dart';

/// Modal dialogs and QR generation utilities for Locations.
class LocationDialogs {
  static Future<void> _printLabels(BuildContext context, ApiClient api) async {
    try {
      final report = await api.downloadLocationLabels();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Save location QR labels',
        fileName: report.filename,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: report.bytes,
      );
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location QR label sheet saved.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create labels: $error')),
        );
      }
    }
  }

  /// Confirms whether a location can be deleted (no components and no child locations) and executes deletion.
  static Future<bool> confirmAndDeleteLocation({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> components,
    required List<dynamic> locations,
    required Future<void> Function() onRefresh,
    required String locationId,
    required String locationName,
  }) async {
    final usedCount = components.where((c) {
      if (c['is_archived'] == true) return false;
      return c['location_id'] == locationId;
    }).length;

    if (usedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Location'),
            ],
          ),
          content: Text(
            "Location '$locationName' cannot be deleted because $usedCount component(s) are stored here.\n\nPlease move or delete those components first.",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    final childCount = locations
        .where((l) => l['parent_location_id'] == locationId)
        .length;
    if (childCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Location'),
            ],
          ),
          content: Text(
            "Location '$locationName' cannot be deleted because $childCount sub-location(s) depend on it.\n\nPlease reassign or delete those sub-locations first.",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location'),
        content: Text(
          "Are you sure you want to delete location '$locationName'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await api.deleteLocation(locationId);
        await onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Location '$locationName' deleted.")),
          );
        }
        return true;
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', '')),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  /// Opens dialog to create or edit a location.
  static Future<void> saveLocation({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> components,
    required List<dynamic> locations,
    required Future<void> Function() onRefresh,
    Map<String, dynamic>? location,
  }) async {
    final name = TextEditingController(
      text: location?['name'] as String? ?? '',
    );
    final cabinet = TextEditingController(
      text: location?['cabinet'] as String? ?? '',
    );
    final shelf = TextEditingController(
      text: location?['shelf'] as String? ?? '',
    );
    final drawer = TextEditingController(
      text: location?['drawer'] as String? ?? '',
    );
    final box = TextEditingController(text: location?['box'] as String? ?? '');
    final bin = TextEditingController(text: location?['bin'] as String? ?? '');
    final description = TextEditingController(
      text: location?['description'] as String? ?? '',
    );
    var addQrCode = location == null
        ? true
        : (location['qr_code_value'] != null);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(location == null ? 'Add location' : 'Edit location'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Location name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cabinet,
                    decoration: const InputDecoration(
                      labelText: 'Cabinet / rack',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shelf,
                    decoration: const InputDecoration(labelText: 'Shelf'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: drawer,
                    decoration: const InputDecoration(labelText: 'Drawer'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: box,
                    decoration: const InputDecoration(labelText: 'Box'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bin,
                    decoration: const InputDecoration(
                      labelText: 'Bin / compartment',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: addQrCode,
                    onChanged: (value) =>
                        setDialogState(() => addQrCode = value),
                    title: const Text('Add QR Code'),
                    subtitle: const Text(
                      'Automatically generate a printable QR code for this location',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (location != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete Location'),
                onPressed: () async {
                  final locId = location['id'] as String;
                  final locName = location['name'] as String? ?? 'Location';
                  final deleted = await confirmAndDeleteLocation(
                    context: dialogCtx,
                    api: api,
                    components: components,
                    locations: locations,
                    onRefresh: onRefresh,
                    locationId: locId,
                    locationName: locName,
                  );
                  if (deleted && dialogCtx.mounted) {
                    Navigator.pop(dialogCtx, false);
                  }
                },
              ),
            if (location != null) const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && name.text.trim().isNotEmpty) {
      final payload = {
        'name': name.text.trim(),
        'cabinet': cabinet.text.trim().isEmpty ? null : cabinet.text.trim(),
        'shelf': shelf.text.trim().isEmpty ? null : shelf.text.trim(),
        'drawer': drawer.text.trim().isEmpty ? null : drawer.text.trim(),
        'box': box.text.trim().isEmpty ? null : box.text.trim(),
        'bin': bin.text.trim().isEmpty ? null : bin.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'generate_qr_code': addQrCode,
      };
      try {
        if (location == null) {
          await api.createLocation(payload);
        } else {
          await api.updateLocation(location['id'] as String, payload);
        }
        await onRefresh();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                error.toString().replaceFirst('ApiException: ', ''),
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    }

    name.dispose();
    cabinet.dispose();
    shelf.dispose();
    drawer.dispose();
    box.dispose();
    bin.dispose();
    description.dispose();
  }

  /// Opens the locations management dialog.
  static Future<void> editLocations({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> Function() locationsProvider,
    required List<dynamic> components,
    required Future<void> Function() onRefresh,
    required VoidCallback onOpenScanner,
  }) async {
    final dialogLocations = locationsProvider()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Locations'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onOpenScanner();
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan QR'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _printLabels(dialogContext, api),
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('Print QR label sheet'),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: ListView(
              shrinkWrap: true,
              children: dialogLocations.map((item) {
                final locId = item['id'] as String;
                final locName =
                    item['display_name'] as String? ??
                    item['name'] as String? ??
                    'Location';
                return ListTile(
                  title: Text(locName),
                  subtitle: (item['description'] as String?)?.isNotEmpty == true
                      ? Text(item['description'] as String)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_2),
                        tooltip: 'View and download QR code',
                        onPressed: () => showLocationQrCodeDialog(
                          context: dialogContext,
                          location: item,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_location_alt),
                        tooltip: 'Edit location',
                        onPressed: () async {
                          await saveLocation(
                            context: dialogContext,
                            api: api,
                            components: components,
                            locations: locationsProvider(),
                            onRefresh: onRefresh,
                            location: item,
                          );
                          await onRefresh();
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              dialogLocations.clear();
                              dialogLocations.addAll(
                                locationsProvider().map(
                                  (l) => Map<String, dynamic>.from(l as Map),
                                ),
                              );
                            });
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete location',
                        onPressed: () async {
                          final deleted = await confirmAndDeleteLocation(
                            context: dialogContext,
                            api: api,
                            components: components,
                            locations: locationsProvider(),
                            onRefresh: onRefresh,
                            locationId: locId,
                            locationName: locName,
                          );
                          if (deleted) {
                            setDialogState(() {
                              dialogLocations.removeWhere(
                                (l) => l['id'] == locId,
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the location QR code dialog.
  static Future<void> showLocationQrCodeDialog({
    required BuildContext context,
    required Map<String, dynamic> location,
  }) async {
    final qrValue =
        location['qr_code_value'] as String? ?? 'location:${location['id']}';
    final displayName =
        location['display_name'] as String? ??
        location['name'] as String? ??
        'Location';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_2),
            const SizedBox(width: 8),
            Expanded(child: Text(displayName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: qrValue,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        qrValue,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Download and print this QR code to paste on the physical storage shelf, box, or drawer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await downloadLocationQrCode(
                context: dialogContext,
                location: location,
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download QR Code'),
          ),
        ],
      ),
    );
  }

  /// Renders and downloads the location QR code as a PNG file.
  static Future<void> downloadLocationQrCode({
    required BuildContext context,
    required Map<String, dynamic> location,
  }) async {
    final qrValue =
        location['qr_code_value'] as String? ?? 'location:${location['id']}';
    final displayName =
        location['display_name'] as String? ??
        location['name'] as String? ??
        'Location';
    try {
      final qrPainter = QrPainter(
        data: qrValue,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
      );
      final picData = await qrPainter.toImageData(
        600.0,
        format: ui.ImageByteFormat.png,
      );
      if (picData == null) {
        throw Exception('Failed to render QR code image data.');
      }
      final bytes = picData.buffer.asUint8List();

      final cleanName = displayName
          .replaceAll(RegExp(r'[^\w\d\-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final fileName = 'location_${cleanName}_qr.png';

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Download Location QR Code',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['png'],
        bytes: bytes,
      );

      if (!context.mounted) return;
      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded $fileName')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download QR code: $error')),
        );
      }
    }
  }
}
