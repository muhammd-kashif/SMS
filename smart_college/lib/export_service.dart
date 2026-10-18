import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'design.dart';
import 'file_saver.dart';
import 'theme.dart';

enum ExportFormat { excel, csv, pdf, print }

extension ExportFormatInfo on ExportFormat {
  String get extension => switch (this) {
        ExportFormat.excel => 'xlsx',
        ExportFormat.csv => 'csv',
        ExportFormat.pdf => 'pdf',
        ExportFormat.print => 'pdf',
      };

  String get label => switch (this) {
        ExportFormat.excel => 'Excel workbook',
        ExportFormat.csv => 'CSV file',
        ExportFormat.pdf => 'PDF document',
        ExportFormat.print => 'Print / Save as PDF',
      };

  IconData get icon => switch (this) {
        ExportFormat.excel => Icons.table_chart_rounded,
        ExportFormat.csv => Icons.description_rounded,
        ExportFormat.pdf => Icons.picture_as_pdf_rounded,
        ExportFormat.print => Icons.print_rounded,
      };

  DashTone get tone => switch (this) {
        ExportFormat.excel => DashTone.success,
        ExportFormat.csv => DashTone.info,
        ExportFormat.pdf => DashTone.danger,
        ExportFormat.print => DashTone.warning,
      };
}

/// Everything the exporters need so any screen of the app can print or save.
class ExportBundle {
  const ExportBundle({
    required this.title,
    required this.headers,
    required this.rows,
    this.subtitle,
    this.meta = const [],
    this.sheetName,
    this.landscape,
  });

  final String title;
  final String? subtitle;
  final List<String> headers;
  final List<List<String>> rows;
  final List<(String, String)> meta;
  final String? sheetName;
  final bool? landscape;

  bool get isEmpty => rows.isEmpty;
  int get columnCount => headers.isEmpty ? (rows.isEmpty ? 0 : rows.first.length) : headers.length;

  ExportBundle copyWith({List<List<String>>? rows}) => ExportBundle(
        title: title,
        subtitle: subtitle,
        headers: headers,
        rows: rows ?? this.rows,
        meta: meta,
        sheetName: sheetName,
        landscape: landscape,
      );
}

class ExportOutcome {
  const ExportOutcome(this.message, {this.savedPath});

  final String message;
  final String? savedPath;
}

/// Builds and delivers one export, then reports what happened for the toast.
Future<ExportOutcome> runExport(ExportBundle bundle, ExportFormat format) async {
  if (bundle.rows.isEmpty) {
    return const ExportOutcome('There is no data to export yet.');
  }

  final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
  final fileName = '${_slug(bundle.title)}_$stamp.${format.extension}';

  switch (format) {
    case ExportFormat.print:
      final bytes = await buildPdf(bundle);
      await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
      return const ExportOutcome('Sent to the printer / PDF preview.');
    case ExportFormat.pdf:
      final bytes = await buildPdf(bundle);
      final path = await saveExportFile(fileName, bytes);
      await Printing.sharePdf(bytes: bytes, filename: fileName, subject: bundle.title);
      return ExportOutcome(path == null ? 'PDF shared.' : 'PDF shared · saved to $path', savedPath: path);
    case ExportFormat.csv:
      return _deliverFile(buildCsv(bundle), fileName, 'text/csv', 'CSV');
    case ExportFormat.excel:
      return _deliverFile(buildExcel(bundle), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'Excel');
  }
}

Future<ExportOutcome> _deliverFile(Uint8List bytes, String fileName, String mime, String label) async {
  final path = await saveExportFile(fileName, bytes);
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime, name: fileName)],
        subject: fileName,
        text: '$label export · $fileName',
        downloadFallbackEnabled: true,
      ),
    );
    return ExportOutcome(path == null ? '$label file shared.' : '$label file shared · saved to $path', savedPath: path);
  } catch (_) {
    if (path != null) return ExportOutcome('$label saved to $path', savedPath: path);
    if (kIsWeb) return ExportOutcome('$label downloaded.');
    return ExportOutcome('$label is ready · share it from the files app.');
  }
}

String _slug(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.isEmpty ? 'export' : cleaned;
}

// ---------------------------------------------------------------------------
// CSV
// ---------------------------------------------------------------------------

Uint8List buildCsv(ExportBundle bundle) {
  final buffer = StringBuffer();
  buffer.writeln([bundle.title, bundle.subtitle ?? '', 'Generated', _timestamp()].map(_csvCell).join(','));
  for (final entry in bundle.meta) {
    buffer.writeln([entry.$1, entry.$2].map(_csvCell).join(','));
  }
  if (bundle.meta.isNotEmpty) buffer.writeln();
  buffer.writeln(bundle.headers.map(_csvCell).join(','));
  for (final row in bundle.rows) {
    buffer.writeln(row.map(_csvCell).join(','));
  }
  // Byte order mark keeps Urdu/Arabic text readable inside Excel.
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

// ---------------------------------------------------------------------------
// Excel
// ---------------------------------------------------------------------------

Uint8List buildExcel(ExportBundle bundle) {
  final excel = Excel.createExcel();
  final sheet = excel[sheetNameOf(bundle)];

  sheet.appendRow([TextCellValue(bundle.title)]);
  if (bundle.subtitle != null && bundle.subtitle!.isNotEmpty) {
    sheet.appendRow([TextCellValue(bundle.subtitle!)]);
  }
  sheet.appendRow([TextCellValue('Generated'), TextCellValue(_timestamp())]);
  for (final entry in bundle.meta) {
    sheet.appendRow([TextCellValue(entry.$1), TextCellValue(entry.$2)]);
  }
  sheet.appendRow(List<CellValue?>.filled(bundle.columnCount, null));

  sheet.appendRow([for (final header in bundle.headers) TextCellValue(header)]);
  for (final row in bundle.rows) {
    sheet.appendRow([for (final cell in row) _excelValue(cell)]);
  }

  for (var i = 0; i < bundle.columnCount; i++) {
    sheet.setColumnWidth(i, _widthOf(bundle, i));
  }

  final bytes = excel.encode();
  if (bytes == null) throw StateError('Excel file could not be created.');
  return Uint8List.fromList(bytes);
}

double _widthOf(ExportBundle bundle, int index) {
  var longest = index < bundle.headers.length ? bundle.headers[index].length : 10;
  for (final row in bundle.rows) {
    if (index < row.length && row[index].length > longest) longest = row[index].length;
    if (longest > 40) break;
  }
  return (longest + 3).clamp(11, 45).toDouble();
}

CellValue _excelValue(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return TextCellValue('');
  final asNumber = num.tryParse(text.replaceAll(',', ''));
  if (asNumber != null) return DoubleCellValue(asNumber.toDouble());
  return TextCellValue(text);
}

String sheetNameOf(ExportBundle bundle) {
  final raw = (bundle.sheetName ?? bundle.title).replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  final name = raw.isEmpty ? 'Export' : raw;
  return name.length <= 31 ? name : name.substring(0, 31);
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

Future<Uint8List> buildPdf(ExportBundle bundle) async {
  final brand = _pdfColor(CollegeColors.toHex(CollegeColors.primary));
  final wash = _tint(brand, 0.1);
  final document = pw.Document(title: bundle.title, author: CollegeColors.schoolName, subject: bundle.subtitle ?? bundle.title);

  final columns = bundle.columnCount;
  final format = (bundle.landscape ?? columns > 6) ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  final flex = <int, double>{};
  var totalFlex = 0.0;
  for (var i = 0; i < columns; i++) {
    final header = i < bundle.headers.length ? bundle.headers[i] : 'Column ${i + 1}';
    flex[i] = header.length.clamp(8, 28).toDouble();
    totalFlex += flex[i]!;
  }

  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(24, 26, 24, 26),
      header: (context) => context.pageNumber <= 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.6))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(_latin(bundle.title), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(_latin(CollegeColors.schoolName), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total ${bundle.rows.length} record${bundle.rows.length == 1 ? '' : 's'} · ${_timestamp()}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ),
      build: (context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_latin(bundle.title), style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: brand)),
            if (bundle.subtitle != null && bundle.subtitle!.isNotEmpty)
              pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text(_latin(bundle.subtitle!), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
            if (bundle.meta.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final entry in bundle.meta)
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: pw.BoxDecoration(color: wash, borderRadius: pw.BorderRadius.circular(5)),
                        child: pw.Text('${_latin(entry.$1)}: ${_latin(entry.$2)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
                      ),
                  ],
                ),
              ),
            pw.SizedBox(height: 12),
          ],
        ),
        pw.TableHelper.fromTextArray(
          headers: [for (final header in bundle.headers) _latin(header)],
          data: [for (final row in bundle.rows) [for (final cell in row) _latin(cell)]],
          headerCount: 1,
          headerStyle: pw.TextStyle(fontSize: 7.6, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          cellStyle: const pw.TextStyle(fontSize: 7.4, color: PdfColors.grey900),
          headerDecoration: pw.BoxDecoration(color: brand),
          oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
          border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.4),
          headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          columnWidths: {for (var i = 0; i < columns; i++) i: pw.FlexColumnWidth(flex[i]! / totalFlex)},
          defaultColumnWidth: const pw.FlexColumnWidth(1),
          tableWidth: pw.TableWidth.max,
          headerAlignment: pw.Alignment.centerLeft,
          cellAlignment: pw.Alignment.topLeft,
        ),
      ],
    ),
  );

  return document.save();
}

/// Keeps the built-in PDF font happy: anything outside Latin-1 becomes a dash.
String _latin(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    if (rune == 10 || rune == 13 || rune == 9) {
      buffer.write(' ');
    } else if (rune >= 32 && rune <= 255) {
      buffer.writeCharCode(rune);
    }
  }
  final cleaned = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? '-' : cleaned;
}

PdfColor _pdfColor(String hex) {
  final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
  if (value == null) return PdfColor.fromInt(0xFF1B4F9C);
  return PdfColor.fromInt(0xFF000000 | value);
}

PdfColor _tint(PdfColor color, double alpha) => color.withValues(alpha, null, null, null);

String _timestamp() => DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

/// The one button that every screen uses to export its data.
class ExportButton extends StatelessWidget {
  const ExportButton({required this.bundle, this.label = 'Export', this.compact = false, super.key});

  final ExportBundle Function() bundle;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => DashMenu(
        label: label,
        icon: Icons.download_rounded,
        variant: DashVariant.primary,
        size: compact ? DashSize.sm : DashSize.md,
        items: [
          for (final format in ExportFormat.values)
            DashMenuItem(
              label: format.label,
              icon: format.icon,
              tone: format.tone,
              onSelected: () => _handle(context, format),
            ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, ExportFormat format) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    try {
      final outcome = await runExport(bundle(), format);
      if (!context.mounted) return;
      dashToast(context, outcome.message);
    } catch (error) {
      if (!context.mounted) return;
      dashToast(context, 'Export failed: $error', error: true);
    }
  }
}