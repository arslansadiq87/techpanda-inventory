import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/api_client.dart';
import '../../../core/web_svg_picker_stub.dart'
    if (dart.library.html) '../../../core/web_svg_picker_web.dart';

/// Helper to display a component type's SVG icon or fallback category icon.
Widget buildComponentTypeIcon(
  Map<String, dynamic> type, {
  Color? color,
  double size = 24,
}) {
  final svg = type['icon_svg'] as String?;
  if (svg != null &&
      RegExp(r'<svg(?:\s|>)', caseSensitive: false).hasMatch(svg)) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  return Icon(Icons.category, size: size, color: color);
}

/// Modal dialogs and operations for managing component types and hierarchical sub-types.
class ComponentTypeDialogs {
  /// Picks and validates an SVG icon string across web and desktop platforms.
  static Future<String?> pickComponentTypeSvg() async {
    Uint8List? bytes;
    if (kIsWeb) {
      final file = await pickWebSvgFile();
      if (file == null) return null;
      bytes = file.bytes;
    } else {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Choose component type SVG icon',
        type: FileType.custom,
        allowedExtensions: ['svg'],
        withData: true,
        cancelUploadOnWindowBlur: false,
      );
      if (result == null || result.files.isEmpty) return null;
      bytes = result.files.single.bytes;
      if (bytes == null) {
        throw StateError('The selected SVG file could not be read.');
      }
    }
    if (bytes.length > 100000) {
      throw const FormatException('SVG icon must be smaller than 100 KB.');
    }
    final svg = utf8.decode(bytes).trim();
    if (!RegExp(r'<svg(?:\s|>)', caseSensitive: false).hasMatch(svg)) {
      throw const FormatException('Please select a valid SVG file.');
    }
    return svg;
  }

  /// Verifies safety constraints (no components assigned, no child sub-types) and deletes a type.
  static Future<bool> confirmAndDeleteType({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> components,
    required List<dynamic> componentTypes,
    required Future<void> Function() onRefresh,
    required String typeId,
    required String typeName,
  }) async {
    final usedCount = components.where((c) {
      if (c['is_archived'] == true) return false;
      return (c['package_type'] as String?)?.trim() == typeName.trim();
    }).length;
    if (usedCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Type'),
            ],
          ),
          content: Text(
            "Component type '$typeName' cannot be deleted because $usedCount component(s) are currently assigned to it.\n\nPlease reassign or delete those components first.",
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

    final childCount =
        componentTypes.where((t) => t['parent_type_id'] == typeId).length;
    if (childCount > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Type'),
            ],
          ),
          content: Text(
            "Component type '$typeName' cannot be deleted because $childCount sub-type(s) depend on it as their parent.\n\nPlease reassign or delete those sub-types first.",
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
        title: const Text('Delete component type'),
        content: Text(
          "Are you sure you want to delete component type '$typeName'?",
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
        await api.deleteComponentType(typeId);
        await onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Component type '$typeName' deleted.")),
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

  /// Opens a modal dialog to create a new component type or sub-type.
  static Future<void> addComponentType({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> Function() componentTypesProvider,
    required Future<void> Function() onRefresh,
  }) async {
    final controller = TextEditingController();
    String? iconSvg;
    String? iconError;
    String? selectedParentTypeId;
    var pickingIcon = false;

    final topLevelTypes = componentTypesProvider()
        .where(
          (item) =>
              item is Map &&
              (item['parent_type_id'] == null ||
                  (item['parent_type_id'] as String).isEmpty),
        )
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: const Text('Add component type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Type name'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: selectedParentTypeId,
                decoration: const InputDecoration(
                  labelText: 'Parent type (optional)',
                  helperText:
                      'Select parent to make this a sub-type, or leave empty for top-level',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Top-level type)'),
                  ),
                  ...topLevelTypes.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item['id'] as String,
                      child: Text(item['name'] as String),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setDialogState(() => selectedParentTypeId = value),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: pickingIcon
                    ? null
                    : () async {
                        setDialogState(() {
                          pickingIcon = true;
                          iconError = null;
                        });
                        try {
                          final selected = await pickComponentTypeSvg();
                          if (selected != null && dialogCtx.mounted) {
                            setDialogState(() => iconSvg = selected);
                          }
                        } catch (error) {
                          if (dialogCtx.mounted) {
                            setDialogState(
                              () => iconError = error is FormatException
                                  ? error.message
                                  : error.toString(),
                            );
                          }
                        } finally {
                          if (dialogCtx.mounted) {
                            setDialogState(() => pickingIcon = false);
                          }
                        }
                      },
                icon: pickingIcon
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  iconSvg == null ? 'Choose SVG icon' : 'SVG icon selected',
                ),
              ),
              if (iconError != null) ...[
                const SizedBox(height: 8),
                Text(
                  iconError!,
                  style: TextStyle(
                    color: Theme.of(dialogCtx).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: pickingIcon ? null : () => Navigator.pop(dialogCtx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && controller.text.trim().isNotEmpty) {
      try {
        await api.createComponentType(
          controller.text.trim(),
          iconSvg: iconSvg,
          parentTypeId: selectedParentTypeId,
        );
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
    controller.dispose();
  }

  /// Opens dialog to manage, rename, reassign parents, and delete component types.
  static Future<void> editComponentTypes({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> Function() componentTypesProvider,
    required List<dynamic> components,
    required Future<void> Function() onRefresh,
  }) async {
    final dialogTypes = componentTypesProvider()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final uploadingTypeIds = <String>{};
    String? uploadError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit component types'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (uploadError != null) ...[
                  Text(
                    uploadError!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: dialogTypes.map((item) {
                      final typeId = item['id'] as String;
                      final uploading = uploadingTypeIds.contains(typeId);
                      final parentName = item['parent_type_name'] as String?;
                      return ListTile(
                        leading: buildComponentTypeIcon(item, size: 28),
                        title: Text(item['name'] as String),
                        subtitle: parentName != null && parentName.isNotEmpty
                            ? Text(
                                'Sub-type of $parentName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.primary,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: uploading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file),
                              tooltip: 'Upload SVG icon',
                              onPressed: uploading
                                  ? null
                                  : () async {
                                      setDialogState(() {
                                        uploadingTypeIds.add(typeId);
                                        uploadError = null;
                                      });
                                      try {
                                        final selected =
                                            await pickComponentTypeSvg();
                                        if (selected == null) return;
                                        final updated =
                                            await api.updateComponentType(
                                          typeId,
                                          item['name'] as String,
                                          iconSvg: selected,
                                        );
                                        final index = dialogTypes.indexWhere(
                                          (type) => type['id'] == typeId,
                                        );
                                        if (dialogContext.mounted &&
                                            index >= 0) {
                                          setDialogState(
                                            () => dialogTypes[index] =
                                                Map<String, dynamic>.from(
                                                  updated,
                                                ),
                                          );
                                        }
                                        await onRefresh();
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(
                                            dialogContext,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'SVG icon updated.',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (error) {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => uploadError =
                                                error is FormatException
                                                    ? error.message
                                                    : error.toString(),
                                          );
                                        }
                                      } finally {
                                        if (dialogContext.mounted) {
                                          setDialogState(
                                            () => uploadingTypeIds
                                                .remove(typeId),
                                          );
                                        }
                                      }
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit type & parent',
                              onPressed: () async {
                                final controller = TextEditingController(
                                  text: item['name'] as String,
                                );
                                String? editParentId =
                                    item['parent_type_id'] as String?;
                                final eligibleParents = dialogTypes
                                    .where(
                                      (t) =>
                                          t['id'] != typeId &&
                                          t['parent_type_id'] != typeId,
                                    )
                                    .toList();
                                final saved = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (context) => StatefulBuilder(
                                    builder: (context, setEditState) =>
                                        AlertDialog(
                                      title:
                                          const Text('Edit component type'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextField(
                                            controller: controller,
                                            decoration: const InputDecoration(
                                              labelText: 'Type name',
                                            ),
                                            autofocus: true,
                                          ),
                                          const SizedBox(height: 12),
                                          DropdownButtonFormField<String?>(
                                            initialValue: editParentId,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Parent type (optional)',
                                              helperText:
                                                  'Choose parent type or None for top-level',
                                            ),
                                            items: [
                                              const DropdownMenuItem<String?>(
                                                value: null,
                                                child: Text(
                                                  'None (Top-level type)',
                                                ),
                                              ),
                                              ...eligibleParents.map(
                                                (p) => DropdownMenuItem<
                                                    String?>(
                                                  value: p['id'] as String,
                                                  child: Text(
                                                    p['name'] as String,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setEditState(
                                              () => editParentId = val,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          label: const Text('Delete Type'),
                                          onPressed: () async {
                                            final deleted =
                                                await confirmAndDeleteType(
                                              context: dialogContext,
                                              api: api,
                                              components: components,
                                              componentTypes:
                                                  componentTypesProvider(),
                                              onRefresh: onRefresh,
                                              typeId: typeId,
                                              typeName:
                                                  item['name'] as String,
                                            );
                                            if (deleted) {
                                              setDialogState(() {
                                                dialogTypes.removeWhere(
                                                  (t) => t['id'] == typeId,
                                                );
                                              });
                                              if (context.mounted) {
                                                Navigator.pop(context, false);
                                              }
                                            }
                                          },
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                if (saved == true &&
                                    controller.text.trim().isNotEmpty) {
                                  try {
                                    final updated =
                                        await api.updateComponentType(
                                      typeId,
                                      controller.text.trim(),
                                      parentTypeId: editParentId,
                                      updateParent: true,
                                    );
                                    final index = dialogTypes.indexWhere(
                                      (type) => type['id'] == typeId,
                                    );
                                    if (dialogContext.mounted && index >= 0) {
                                      setDialogState(
                                        () => dialogTypes[index] =
                                            Map<String, dynamic>.from(updated),
                                      );
                                    }
                                    await onRefresh();
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(
                                        dialogContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            error.toString().replaceFirst(
                                                  'ApiException: ',
                                                  '',
                                                ),
                                          ),
                                          backgroundColor: Colors.red.shade700,
                                        ),
                                      );
                                    }
                                  }
                                  await onRefresh();
                                }
                                controller.dispose();
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete type',
                              onPressed: () async {
                                final deleted = await confirmAndDeleteType(
                                  context: dialogContext,
                                  api: api,
                                  components: components,
                                  componentTypes: componentTypesProvider(),
                                  onRefresh: onRefresh,
                                  typeId: typeId,
                                  typeName: item['name'] as String,
                                );
                                if (deleted) {
                                  setDialogState(() {
                                    dialogTypes.removeWhere(
                                      (t) => t['id'] == typeId,
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
              ],
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
}
