import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../widgets/csv_import_dialog.dart';
import '../widgets/error_banner.dart';
import '../widgets/metric_card.dart';

/// Reports page displaying inventory export formats (CSV, PDF) and bulk import.
class ReportsPage extends StatefulWidget {
  final ApiClient api;
  final String? error;
  final ValueChanged<String?> onErrorChanged;
  final Future<void> Function()? onRefresh;

  const ReportsPage({
    super.key,
    required this.api,
    this.error,
    required this.onErrorChanged,
    this.onRefresh,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? _exportingReportFormat;

  Future<void> _exportInventoryReport(String format) async {
    setState(() {
      _exportingReportFormat = format;
    });
    widget.onErrorChanged(null);

    try {
      final sourceFormat = format == 'xlsx' ? 'csv' : format;
      final source = await widget.api.downloadInventoryReport(sourceFormat);
      final report = format == 'xlsx'
          ? ReportDownload(
              filename: 'inventory.xlsx',
              bytes: _csvToXlsx(source.bytes),
            )
          : source;
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save ${format.toUpperCase()} inventory report',
        fileName: report.filename,
        type: FileType.custom,
        allowedExtensions: [format],
        bytes: report.bytes,
      );
      if (!mounted) return;
      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${report.filename} has been downloaded.')),
        );
      }
    } catch (error) {
      if (mounted) widget.onErrorChanged(error.toString());
    } finally {
      if (mounted) setState(() => _exportingReportFormat = null);
    }
  }

  Widget _reportExportCard({
    required String format,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final exporting = _exportingReportFormat == format;
    final anotherExportIsRunning = _exportingReportFormat != null && !exporting;

    return SizedBox(
      width: 390,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: iconTileDecoration(
                  context,
                  Theme.of(context).colorScheme.primary,
                  radius: 12,
                ),
                child: Icon(
                  icon,
                  color: iconTileForeground(
                    context,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('export-$format'),
                  onPressed: anotherExportIsRunning || exporting
                      ? null
                      : () => _exportInventoryReport(format),
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    exporting
                        ? 'Preparing ${format.toUpperCase()}...'
                        : 'Export ${format.toUpperCase()}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportImportCard() {
    return SizedBox(
      width: 390,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: iconTileDecoration(
                  context,
                  Theme.of(context).colorScheme.primary,
                  radius: 12,
                ),
                child: Icon(
                  Icons.upload_file,
                  color: iconTileForeground(
                    context,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CSV / Excel inventory import',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Bulk import components from a CSV or Excel (.xlsx) file. Automatically detects columns, creates missing types, locations, and initial stock.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('import-components-csv'),
                  onPressed: () => showCsvImportDialog(
                    context: context,
                    api: widget.api,
                    onRefresh: widget.onRefresh ?? () async {},
                    onError: (err) => widget.onErrorChanged(err),
                  ),
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import CSV / Excel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Reports & Data',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Export or import component inventory with support for CSV and PDF.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (widget.error != null)
          ErrorBanner(
            errorMessage: widget.error!,
            onDismiss: () => widget.onErrorChanged(null),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _reportExportCard(
              format: 'csv',
              icon: Icons.table_view,
              title: 'CSV inventory export',
              description:
                  'Spreadsheet-ready inventory with an image URL and original image dimensions for every component.',
            ),
            _reportExportCard(
              format: 'pdf',
              icon: Icons.picture_as_pdf,
              title: 'PDF inventory export',
              description:
                  'Print-ready inventory with clearly sized component thumbnails and original image dimensions.',
            ),
            _reportExportCard(
              format: 'xlsx',
              icon: Icons.grid_on,
              title: 'Excel inventory export',
              description:
                  'Native Excel workbook with inventory data ready for editing, filtering, and sharing.',
            ),
            _reportImportCard(),
          ],
        ),
      ],
    );
  }
}

Uint8List _csvToXlsx(Uint8List bytes) {
  final rows = _parseCsv(utf8.decode(bytes, allowMalformed: true));
  final sheetRows = rows.asMap().entries.map((entry) {
    final cells = entry.value.asMap().entries.map((cell) {
      final ref = '${_xlsxColumn(cell.key + 1)}${entry.key + 1}';
      return '<c r="$ref" t="inlineStr"><is><t>${_xmlEscape(cell.value)}</t></is></c>';
    }).join();
    return '<row r="${entry.key + 1}">$cells</row>';
  }).join();
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        utf8.encode(_worksheetXml(sheetRows)).length,
        utf8.encode(_worksheetXml(sheetRows)),
      ),
    )
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(_contentTypesXml).length,
        utf8.encode(_contentTypesXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        '_rels/.rels',
        utf8.encode(_relsXml).length,
        utf8.encode(_relsXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        utf8.encode(_workbookXml).length,
        utf8.encode(_workbookXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/_rels/workbook.xml.rels',
        utf8.encode(_workbookRelsXml).length,
        utf8.encode(_workbookRelsXml),
      ),
    );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _xlsxColumn(int number) {
  var result = '';
  while (number > 0) {
    number--;
    result = String.fromCharCode(65 + number % 26) + result;
    number ~/= 26;
  }
  return result;
}

String _xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

List<List<String>> _parseCsv(String input) {
  final result = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(cell.toString());
      cell = StringBuffer();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell = StringBuffer();
      if (row.any((value) => value.isNotEmpty)) result.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    result.add(row);
  }
  return result;
}

const _contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>';
const _relsXml =
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>';
const _workbookXml =
    '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Inventory" sheetId="1" r:id="rId1"/></sheets></workbook>';
const _workbookRelsXml =
    '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>';
String _worksheetXml(String rows) =>
    '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$rows</sheetData></worksheet>';
