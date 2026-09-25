import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
import '../models/stock_line_draft.dart';

class StockPage extends StatefulWidget {
  const StockPage({
    super.key,
    required this.api,
    required this.transactions,
    required this.components,
    required this.locations,
    required this.stockLines,
    required this.stockMode,
    required this.onStockCommitted,
  });

  final ApiClient api;
  final List<dynamic> transactions;
  final List<dynamic> components;
  final List<dynamic> locations;
  final List<StockLineDraft> stockLines;
  final String stockMode;
  final Future<void> Function() onStockCommitted;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late String _stockMode = widget.stockMode;
  late final ScrollController _scrollController = ScrollController();
  TextEditingController? _stockSearchController;
  bool _showAllStockComponents = false;
  String? _error;
  Map<String, dynamic>? _editingTransaction;
  final Map<String, Map<String, dynamic>> _movementDetails = {};
  final Set<String> _expandedMovementIds = {};
  final Set<String> _loadingMovementIds = {};
  final Map<String, String> _movementDetailErrors = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postStock() async {
    if (widget.stockLines.isEmpty) {
      setState(() => _error = 'Select at least one component.');
      return;
    }
    final lines = widget.stockLines
        .map((line) => {
              'component_id': line.component['id'],
              'quantity': line.quantityController.text.trim().isEmpty
                  ? '1'
                  : line.quantityController.text.trim(),
            })
        .toList();
    final editing = _editingTransaction;
    final payload = <String, dynamic>{
      'transaction_type': _stockMode,
      'lines': lines,
    };
    if (editing == null) payload['idempotency_key'] = const Uuid().v4();
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
      await widget.onStockCommitted();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _editStockMovement(Map<String, dynamic> movement) async {
    try {
      final detail = await widget.api.transaction(movement['id'] as String);
      final mode = detail['transaction_type'] as String;
      if (!{'stock_in', 'stock_out', 'return', 'loss'}.contains(mode)) {
        if (mounted) {
          setState(() => _error =
              'This movement type cannot be edited from the Stock form.');
        }
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
        widget.stockLines.addAll(lines);
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleStockMovementDetails(
      Map<String, dynamic> movement) async {
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
              child: const Text('Cancel')),
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
      await widget.onStockCommitted();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _addStockLine(Map<String, dynamic> component) {
    final id = component['id'] as String;
    if (widget.stockLines.any((line) => line.component['id'] == id)) return;
    widget.stockLines.add(StockLineDraft(
      component: Map<String, dynamic>.from(component),
    ));
  }

  void _removeStockLine(StockLineDraft line) {
    line.quantityController.dispose();
    widget.stockLines.remove(line);
  }

  void _clearStockLines() {
    for (final line in widget.stockLines) {
      line.quantityController.dispose();
    }
    widget.stockLines.clear();
  }

  void _adjustStockLineQuantity(StockLineDraft line, int delta) {
    final current = double.tryParse(line.quantityController.text.trim()) ?? 0;
    final next = current + delta;
    line.quantityController.text = _formatStockQuantity(next <= 0 ? 1 : next);
  }

  String _formatStockQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _formatComponentQuantity(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null) return '$value';
    return _formatStockQuantity(parsed);
  }

  String _stockComponentLabel(Map<String, dynamic> component) =>
      component['name'] as String? ?? 'Component';

  String _stockComponentDetail(Map<String, dynamic> component) => [
        if ((component['package_type'] as String?)?.isNotEmpty == true)
          component['package_type'],
        if ((component['manufacturer'] as String?)?.isNotEmpty == true)
          component['manufacturer'],
        if ((component['location_name'] as String?)?.isNotEmpty == true)
          component['location_name'],
        '${component['current_quantity']} ${component['unit']} available',
      ].join(' • ');

  Widget _componentThumbnail(Map<String, dynamic> component,
      {required double size}) {
    final thumbnail = component['primary_image_thumbnail'] as String?;
    if (thumbnail == null || thumbnail.isEmpty) {
      return SizedBox(width: size, height: size, child: const Icon(Icons.memory));
    }
    Widget image;
    if (thumbnail.startsWith('data:image/') && thumbnail.contains(';base64,')) {
      try {
        image = Image.memory(base64Decode(thumbnail.substring(
          thumbnail.indexOf(';base64,') + ';base64,'.length),
        ));
      } catch (_) {
        image = const Icon(Icons.broken_image);
      }
    } else {
      image = Image.network(widget.api.mediaUrl(thumbnail));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(fit: BoxFit.cover, child: image),
      ),
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
        child: Row(children: [
          Expanded(child: Text(error)),
          TextButton.icon(
            onPressed: () => _loadStockMovementDetails(movementId),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
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
        border: Border(top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        )),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (reason.isNotEmpty || notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text([
              if (reason.isNotEmpty) 'Reason: $reason',
              if (notes.isNotEmpty) 'Notes: $notes',
            ].join('\n'), style: Theme.of(context).textTheme.bodySmall),
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
            key: ValueKey('movement-line-$movementId-${line['component_id']}'),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: _componentThumbnail(component, size: 42),
            title: Text('${line['inventory_code']} • ${line['component_name']}'),
            subtitle: Text([
              if (component['supplier_name'] != null &&
                  '${component['supplier_name']}'.isNotEmpty)
                'Supplier: ${component['supplier_name']}',
              if (details.isNotEmpty) details.join(' • '),
              if (lineNotes.isNotEmpty) 'Note: $lineNotes',
            ].join('\n')),
            trailing: Text(
              '${_formatComponentQuantity(line['quantity'])} ${line['unit']}',
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          );
        }),
      ]),
    );
  }

  Widget _stockComponentPicker() {
    final components = widget.components
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
        } catch (_) {}
        final normalizedQuery = query.toLowerCase();
        return components.where((component) {
          final haystack = [
            component['inventory_code'],
            component['name'],
            component['manufacturer'],
            component['package_type'],
            component['location_name'],
            component['description'],
          ].whereType<Object>().join(' ').toLowerCase();
          return haystack.contains(normalizedQuery);
        }).take(30);
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
                      offset: controller.text.length);
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
      optionsViewBuilder: (context, onSelected, options) => Align(
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
      ),
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
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_stockComponentLabel(component),
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(_stockComponentDetail(component),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        );
        final quantity = SizedBox(
          width: compact ? double.infinity : 320,
          child: Row(children: [
            IconButton.filledTonal(
              onPressed: () => setState(() => _adjustStockLineQuantity(line, -1)),
              icon: const Icon(Icons.remove), tooltip: 'Decrease quantity'),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: line.quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Qty'),
            )),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => setState(() => _adjustStockLineQuantity(line, 1)),
              icon: const Icon(Icons.add), tooltip: 'Increase quantity'),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(unit, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ),
          ]),
        );
        final remove = IconButton.outlined(
          onPressed: () => setState(() => _removeStockLine(line)),
          icon: const Icon(Icons.delete_outline), tooltip: 'Remove component');
        if (compact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              thumbnail, const SizedBox(width: 10), Expanded(child: details),
            ]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: quantity), const SizedBox(width: 8), remove]),
          ]);
        }
        return Row(children: [
          thumbnail, const SizedBox(width: 12), Expanded(child: details),
          const SizedBox(width: 12), quantity, const SizedBox(width: 8), remove,
        ]);
      }),
    );
  }

  Widget _stockPage() {
    return ListView(
      controller: _scrollController,
      children: [
        if (_error != null)
          Card(child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(_error!),
            trailing: IconButton(
              onPressed: () => setState(() => _error = null),
              icon: const Icon(Icons.close),
            ),
          )),
        if (_editingTransaction != null) ...[
          Card(child: ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text('Editing ${_editingTransaction!['transaction_code']}'),
            subtitle: const Text(
              'Change the movement type, components, or quantities, then update the whole movement.',
            ),
            trailing: TextButton(
              onPressed: _cancelStockMovementEdit,
              child: const Text('Cancel edit'),
            ),
          )),
          const SizedBox(height: 12),
        ],
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'stock_in', label: Text('Stock In'), icon: Icon(Icons.add_box)),
            ButtonSegment(value: 'stock_out', label: Text('Stock Out'), icon: Icon(Icons.output)),
            ButtonSegment(value: 'return', label: Text('Return'), icon: Icon(Icons.keyboard_return)),
            ButtonSegment(value: 'loss', label: Text('Loss'), icon: Icon(Icons.delete_sweep)),
          ],
          selected: {_stockMode},
          onSelectionChanged: (value) => setState(() => _stockMode = value.first),
        ),
        const SizedBox(height: 16),
        _stockComponentPicker(),
        const SizedBox(height: 12),
        if (widget.stockLines.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('No components selected. Search and add components above.'),
          )
        else
          ...widget.stockLines.map(_stockLineRow),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: _postStock,
            icon: Icon(_editingTransaction == null ? Icons.cloud_upload : Icons.save),
            label: Text(_editingTransaction == null ? 'Submit' : 'Update entire movement'),
          ),
        ]),
        const SizedBox(height: 24),
        Text('Recent movement', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...widget.transactions.map((rawItem) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final movementId = item['id'] as String;
          final expanded = _expandedMovementIds.contains(movementId);
          final canModify = item['can_modify'] == true;
          final canEdit = canModify &&
              {'stock_in', 'stock_out', 'return', 'loss'}.contains(item['transaction_type']);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.receipt),
                title: Text('${item['transaction_code']} ${item['transaction_type']}'),
                subtitle: Text('${item['line_count']} lines • ${item['created_at']}'),
                trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  IconButton(
                    key: ValueKey('expand-movement-$movementId'),
                    onPressed: () => _toggleStockMovementDetails(item),
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: expanded ? 'Hide movement components' : 'View movement components',
                  ),
                  if (canModify) ...[
                    if (canEdit)
                      IconButton(onPressed: () => _editStockMovement(item), icon: const Icon(Icons.edit_outlined), tooltip: 'Edit entire movement'),
                    IconButton(onPressed: () => _deleteStockMovement(item), icon: const Icon(Icons.delete_outline), tooltip: 'Delete entire movement'),
                  ] else
                    const Tooltip(message: 'Managed from its project', child: Padding(padding: EdgeInsets.all(12), child: Icon(Icons.lock_outline))),
                ]),
              ),
              if (expanded) _stockMovementDetailsPanel(movementId),
            ]),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _stockPage();
}
