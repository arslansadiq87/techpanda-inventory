import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../core/api_client.dart';

/// Helper to trigger CSV file selection and import components into the inventory.
Future<void> showCsvImportDialog({
  required BuildContext context,
  required ApiClient api,
  required Future<void> Function() onRefresh,
  required ValueChanged<String> onError,
}) async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final sourceBytes = file.bytes;
    if (sourceBytes == null) {
      onError('Unable to read selected file data.');
      return;
    }
    final isExcel = file.extension?.toLowerCase() == 'xlsx';
    final bytes = isExcel ? _xlsxAsCsv(sourceBytes) : sourceBytes;

    if (!context.mounted) return;

    // Show loading indicator dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(
                  'Importing components from ${isExcel ? 'Excel' : 'CSV'}...',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final res = await api.importComponentsCsv(
      isExcel ? '${file.name}.csv' : file.name,
      bytes,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading
    }

    await onRefresh();

    if (!context.mounted) return;

    final imported = res['imported'] ?? 0;
    final skipped = res['skipped'] ?? 0;
    final errors = (res['errors'] as List<dynamic>?)?.cast<String>() ?? [];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              errors.isEmpty ? Icons.check_circle_outline : Icons.info_outline,
              color: errors.isEmpty ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text('${isExcel ? 'Excel' : 'CSV'} Import Results'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Successfully imported: $imported component(s)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (skipped > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Skipped (duplicates/errors): $skipped',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Details:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: errors.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${errors[i]}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      // If loading dialog is still visible, close it
      Navigator.of(context, rootNavigator: true).maybePop();
      onError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

/// Converts the first worksheet of an .xlsx workbook into UTF-8 CSV so both
/// local mode and the remote API share the same validation and import rules.
Uint8List _xlsxAsCsv(Uint8List bytes) {
  final zip = ZipDecoder().decodeBytes(bytes);
  final sheetFile = zip.findFile('xl/worksheets/sheet1.xml');
  if (sheetFile == null) {
    throw Exception('Excel workbook does not contain a worksheet');
  }
  final sharedFile = zip.findFile('xl/sharedStrings.xml');
  final sharedStrings = sharedFile == null
      ? <String>[]
      : XmlDocument.parse(utf8.decode(sharedFile.content as List<int>))
            .findAllElements('si')
            .map(
              (node) =>
                  node.findAllElements('t').map((t) => t.innerText).join(),
            )
            .toList();
  final document = XmlDocument.parse(
    utf8.decode(sheetFile.content as List<int>),
  );
  final rows = document.findAllElements('row').toList();
  if (rows.isEmpty) {
    throw Exception('Excel worksheet is empty');
  }

  final outputRows = <List<String>>[];
  for (final row in rows) {
    final values = <String>[];
    for (final cell in row.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      final column = RegExp(r'[A-Z]+').firstMatch(ref)?.group(0) ?? '';
      final index = _excelColumnIndex(column);
      while (values.length <= index) {
        values.add('');
      }
      final type = cell.getAttribute('t');
      final valueNodes = cell.findElements('v');
      final inlineNodes = cell.findElements('is');
      final raw = valueNodes.isEmpty ? '' : valueNodes.first.innerText;
      final inline = inlineNodes.isEmpty ? null : inlineNodes.first;
      final value = type == 's'
          ? (int.tryParse(raw) != null && int.parse(raw) < sharedStrings.length
                ? sharedStrings[int.parse(raw)]
                : raw)
          : inline == null
          ? raw
          : inline.findAllElements('t').map((t) => t.innerText).join();
      values[index] = value;
    }
    outputRows.add(values);
  }

  String csvCell(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    return '"${text.replaceAll('"', '""')}"';
  }

  final csv = outputRows.map((row) => row.map(csvCell).join(',')).join('\r\n');
  return Uint8List.fromList(utf8.encode(csv));
}

int _excelColumnIndex(String column) {
  var index = 0;
  for (final codeUnit in column.codeUnits) {
    index = index * 26 + codeUnit - 64;
  }
  return index == 0 ? 0 : index - 1;
}
