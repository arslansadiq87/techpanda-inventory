import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

/// Modal dialogs and helpers for creating, editing, and managing suppliers.
class SupplierDialogs {
  /// Opens a modal dialog to create or edit a single supplier.
  static Future<void> saveSupplier({
    required BuildContext context,
    required ApiClient api,
    required Future<void> Function() onRefresh,
    Map<String, dynamic>? supplier,
  }) async {
    final name = TextEditingController(
      text: supplier?['name'] as String? ?? '',
    );
    final website = TextEditingController(
      text: supplier?['website'] as String? ?? '',
    );
    final contact = TextEditingController(
      text: supplier?['contact_info'] as String? ?? '',
    );
    final notes = TextEditingController(
      text: supplier?['notes'] as String? ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'Add supplier' : 'Edit supplier'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Supplier name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: website,
                  decoration: const InputDecoration(
                    labelText: 'Website URL (optional)',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contact,
                  decoration: const InputDecoration(
                    labelText: 'Contact info (optional)',
                    hintText: 'Email, phone, rep...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
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

    if (saved == true && name.text.trim().isNotEmpty) {
      final payload = {
        'name': name.text.trim(),
        'website': website.text.trim().isEmpty ? null : website.text.trim(),
        'contact_info':
            contact.text.trim().isEmpty ? null : contact.text.trim(),
        'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
      };
      try {
        if (supplier == null) {
          await api.createSupplier(payload);
        } else {
          await api.updateSupplier(supplier['id'] as String, payload);
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
    website.dispose();
    contact.dispose();
    notes.dispose();
  }

  /// Opens the full suppliers list management dialog.
  static Future<void> editSuppliers({
    required BuildContext context,
    required ApiClient api,
    required List<dynamic> Function() suppliersProvider,
    required Future<void> Function() onRefresh,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final suppliers = suppliersProvider();
          return AlertDialog(
            title: const Text('Manage suppliers'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${suppliers.length} suppliers registered',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await saveSupplier(
                            context: dialogContext,
                            api: api,
                            onRefresh: onRefresh,
                          );
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add supplier'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: suppliers.isEmpty
                        ? const Center(
                            child: Text('No suppliers registered yet.'),
                          )
                        : ListView(
                            children: suppliers.map((s) {
                              final supplier = Map<String, dynamic>.from(
                                s as Map,
                              );
                              final name = supplier['name'] as String;
                              final website = supplier['website'] as String?;
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.local_shipping_outlined,
                                ),
                                title: Text(name),
                                subtitle: website != null && website.isNotEmpty
                                    ? Text(website)
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      tooltip: 'Edit supplier',
                                      onPressed: () async {
                                        await saveSupplier(
                                          context: dialogContext,
                                          api: api,
                                          onRefresh: onRefresh,
                                          supplier: supplier,
                                        );
                                        setDialogState(() {});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      tooltip: 'Delete supplier',
                                      onPressed: () async {
                                        try {
                                          await api.deleteSupplier(
                                            supplier['id'] as String,
                                          );
                                          await onRefresh();
                                          setDialogState(() {});
                                        } catch (e) {
                                          if (dialogContext.mounted) {
                                            ScaffoldMessenger.of(
                                              dialogContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(e.toString()),
                                                backgroundColor:
                                                    Colors.red.shade700,
                                              ),
                                            );
                                          }
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
          );
        },
      ),
    );
  }
}
