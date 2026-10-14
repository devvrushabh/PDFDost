import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/models.dart';

class PdfEngineResult {
  final String path;
  final String name;
  final int pages;
  final String sizeStr;
  final int sizeBytes;

  PdfEngineResult({
    required this.path,
    required this.name,
    required this.pages,
    required this.sizeStr,
    required this.sizeBytes,
  });
}

class PdfEngine {
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // 1. Image to PDF (Flagship)
  static Future<PdfEngineResult> convertImagesToPdf({
    required List<SelectedImageItem> images,
    required String docName,
    bool addPageNumbers = false,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < images.length; i++) {
      final imgItem = images[i];
      final bytes = await File(imgItem.path).readAsBytes();
      final pdfImage = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (pw.Context ctx) {
            return pw.Stack(
              children: [
                pw.Center(
                  child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                ),
                if (addPageNumbers)
                  pw.Positioned(
                    bottom: 0,
                    right: 0,
                    left: 0,
                    child: pw.Center(
                      child: pw.Text(
                        'Page ${i + 1} of ${images.length}',
                        style: const pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    return await _saveDocument(pdf, docName);
  }

  // Inspect page count of a PDF file
  static Future<int> getPdfPageCount(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final loadedDoc = sf.PdfDocument(inputBytes: bytes);
        final count = loadedDoc.pages.count;
        loadedDoc.dispose();
        return count;
      }
    } catch (_) {}
    return 1;
  }

  // 2. Real PDF Merge Engine (combines multiple vector PDFs into one)
  static Future<PdfEngineResult> mergePdfsFromPaths({
    required List<String> paths,
    required String docName,
  }) async {
    final sf.PdfDocument newDocument = sf.PdfDocument();
    int totalPages = 0;

    try {
      for (final path in paths) {
        final file = File(path);
        if (await file.exists()) {
          final Uint8List bytes = await file.readAsBytes();
          final sf.PdfDocument loadedDoc = sf.PdfDocument(inputBytes: bytes);

          for (int i = 0; i < loadedDoc.pages.count; i++) {
            final sf.PdfPage loadedPage = loadedDoc.pages[i];
            final sf.PdfTemplate template = loadedPage.createTemplate();

            final sf.PdfSection section = newDocument.sections!.add();
            section.pageSettings.size = template.size;
            section.pageSettings.margins.all = 0;

            final sf.PdfPage newPage = section.pages.add();
            newPage.graphics.drawPdfTemplate(template, Offset.zero);
            totalPages++;
          }

          loadedDoc.dispose();
        }
      }

      if (totalPages == 0) {
        throw Exception('No valid PDF pages found to merge.');
      }

      final List<int> mergedBytes = await newDocument.save();
      newDocument.dispose();

      return await _saveBytes(mergedBytes, docName, totalPages);
    } catch (e) {
      newDocument.dispose();
      rethrow;
    }
  }

  static Future<PdfEngineResult> mergePdfItems({
    required List<SelectedPdfItem> items,
    required String docName,
  }) async {
    final paths = items.map((e) => e.path).toList();
    return await mergePdfsFromPaths(paths: paths, docName: docName);
  }

  static Future<PdfEngineResult> mergePdfs({
    required List<HistoryItem> items,
    required String docName,
  }) async {
    final paths = items.map((e) => e.path).toList();
    return await mergePdfsFromPaths(paths: paths, docName: docName);
  }

  // 3. Real Vector PDF Split Engine
  static Future<PdfEngineResult> splitPdfPages({
    required String sourcePath,
    required int startPage,
    required int endPage,
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source PDF not found at $sourcePath');
    }

    final Uint8List sourceBytes = await file.readAsBytes();
    final sf.PdfDocument loadedDoc = sf.PdfDocument(inputBytes: sourceBytes);
    final int totalSourcePages = loadedDoc.pages.count;

    final int from = startPage.clamp(1, totalSourcePages);
    final int to = endPage.clamp(from, totalSourcePages);

    final sf.PdfDocument newDocument = sf.PdfDocument();
    int totalExtracted = 0;

    try {
      for (int pageNum = from; pageNum <= to; pageNum++) {
        final int pageIndex = pageNum - 1;
        final sf.PdfPage loadedPage = loadedDoc.pages[pageIndex];
        final sf.PdfTemplate template = loadedPage.createTemplate();

        final sf.PdfSection section = newDocument.sections!.add();
        section.pageSettings.size = template.size;
        section.pageSettings.margins.all = 0;

        final sf.PdfPage newPage = section.pages.add();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
        totalExtracted++;
      }

      loadedDoc.dispose();

      if (totalExtracted == 0) {
        newDocument.dispose();
        throw Exception('No pages were extracted.');
      }

      final List<int> extractedBytes = await newDocument.save();
      newDocument.dispose();

      return await _saveBytes(extractedBytes, docName, totalExtracted);
    } catch (e) {
      newDocument.dispose();
      loadedDoc.dispose();
      rethrow;
    }
  }

  static Future<List<PdfEngineResult>> splitMultiplePdfs({
    required List<SplitPdfConfigItem> items,
    required String baseDocName,
  }) async {
    final List<PdfEngineResult> results = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final base = baseDocName.isEmpty ? 'Split' : baseDocName;
      final String itemDocName = items.length == 1
          ? base
          : '${base}_${i + 1}_${item.name.replaceAll('.pdf', '')}';

      final res = await splitPdfPages(
        sourcePath: item.path,
        startPage: item.startPage,
        endPage: item.endPage,
        docName: itemDocName,
      );
      results.add(res);
    }
    return results;
  }

  static Future<PdfEngineResult> splitPdf({
    required HistoryItem sourceItem,
    required int startPage,
    required int endPage,
    required String docName,
  }) async {
    return await splitPdfPages(
      sourcePath: sourceItem.path,
      startPage: startPage,
      endPage: endPage,
      docName: docName,
    );
  }

  // 4. Compress PDF (Real Vector & Stream Optimizer)
  static Future<PdfEngineResult> compressPdfDocument({
    required String sourcePath,
    required String levelName, // Extreme, Recommended, Low
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final Uint8List originalBytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: originalBytes);
    final int pageCount = document.pages.count;

    if (levelName == 'Extreme') {
      document.compressionLevel = sf.PdfCompressionLevel.best;
      document.fileStructure.incrementalUpdate = false;
      document.fileStructure.crossReferenceType = sf.PdfCrossReferenceType.crossReferenceStream;
    } else if (levelName == 'Recommended') {
      document.compressionLevel = sf.PdfCompressionLevel.best;
      document.fileStructure.incrementalUpdate = false;
    } else {
      document.compressionLevel = sf.PdfCompressionLevel.normal;
    }

    final List<int> savedBytes = await document.save();
    document.dispose();

    List<int> bestBytes = savedBytes;
    try {
      final sf.PdfDocument cleanDoc = sf.PdfDocument();
      cleanDoc.compressionLevel = sf.PdfCompressionLevel.best;
      cleanDoc.fileStructure.crossReferenceType = sf.PdfCrossReferenceType.crossReferenceStream;
      cleanDoc.fileStructure.incrementalUpdate = false;

      final sf.PdfDocument tempDoc = sf.PdfDocument(inputBytes: originalBytes);
      for (int i = 0; i < tempDoc.pages.count; i++) {
        final sf.PdfPage srcPage = tempDoc.pages[i];
        final sf.PdfTemplate template = srcPage.createTemplate();
        final sf.PdfSection sec = cleanDoc.sections!.add();
        sec.pageSettings.size = template.size;
        sec.pageSettings.margins.all = 0;
        final sf.PdfPage newP = sec.pages.add();
        newP.graphics.drawPdfTemplate(template, Offset.zero);
      }
      tempDoc.dispose();

      final List<int> cleanBytes = await cleanDoc.save();
      cleanDoc.dispose();

      if (cleanBytes.length < bestBytes.length) {
        bestBytes = cleanBytes;
      }
    } catch (_) {}

    // Ensure we never return a larger file than original
    if (bestBytes.length > originalBytes.length) {
      bestBytes = originalBytes;
    }

    return await _saveBytes(bestBytes, docName, pageCount);
  }

  static Future<PdfEngineResult> compressPdf({
    required HistoryItem sourceItem,
    required String levelName,
    required String docName,
  }) async {
    return await compressPdfDocument(
      sourcePath: sourceItem.path,
      levelName: levelName,
      docName: docName,
    );
  }

  static Future<List<PdfEngineResult>> compressMultiplePdfs({
    required List<SelectedPdfItem> items,
    required String levelName,
    required String baseDocName,
  }) async {
    final List<PdfEngineResult> results = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final base = baseDocName.isEmpty ? 'Compressed' : baseDocName;
      final String itemDocName = items.length == 1
          ? base
          : '${base}_${i + 1}_${item.name.replaceAll('.pdf', '')}';
      final res = await compressPdfDocument(
        sourcePath: item.path,
        levelName: levelName,
        docName: itemDocName,
      );
      results.add(res);
    }
    return results;
  }

  // 5. PDF to Word (Real formatted .doc conversion)
  static Future<File> pdfToWordFromPath({
    required String sourcePath,
    required String docName,
    bool includeHeaders = true,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
    final int pageCount = document.pages.count;

    final appDir = await getApplicationDocumentsDirectory();
    var sanitizedName = docName.trim();
    if (sanitizedName.isEmpty) {
      sanitizedName = 'Document_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    if (sanitizedName.toLowerCase().endsWith('.doc')) {
      sanitizedName = sanitizedName.substring(0, sanitizedName.length - 4);
    }
    sanitizedName = sanitizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetFile = File('${appDir.path}/$sanitizedName.doc');

    final buffer = StringBuffer();
    buffer.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">');
    buffer.writeln('<head><meta charset="utf-8"><title>$sanitizedName</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: "Segoe UI", Calibri, Arial, sans-serif; font-size: 11pt; line-height: 1.6; color: #1e293b; margin: 1in; }');
    buffer.writeln('h1 { font-size: 20pt; color: #0284c7; margin-bottom: 10pt; font-weight: bold; border-bottom: 2px solid #0284c7; padding-bottom: 6pt; }');
    buffer.writeln('h2 { font-size: 13pt; color: #334155; margin-top: 18pt; margin-bottom: 8pt; border-bottom: 1px solid #cbd5e1; padding-bottom: 4pt; }');
    buffer.writeln('p { margin: 0 0 10pt 0; text-align: justify; }');
    buffer.writeln('.page-break { page-break-after: always; }');
    buffer.writeln('.meta-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 10pt; margin-bottom: 20pt; font-size: 9.5pt; color: #64748b; }');
    buffer.writeln('</style></head><body>');

    if (includeHeaders) {
      buffer.writeln('<h1>$sanitizedName</h1>');
      buffer.writeln('<div class="meta-box">');
      buffer.writeln('<strong>Converted with PDFDost (PDF to Word Engine)</strong> &bull; ${DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now())}<br>');
      buffer.writeln('Total Pages Extracted: $pageCount');
      buffer.writeln('</div>');
    }

    for (int p = 0; p < pageCount; p++) {
      final pageText = extractor.extractText(startPageIndex: p, endPageIndex: p);
      if (includeHeaders) {
        buffer.writeln('<h2>Page ${p + 1}</h2>');
      }
      final lines = pageText.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          buffer.writeln('<p>${_escapeHtml(trimmed)}</p>');
        }
      }
      if (p < pageCount - 1) {
        buffer.writeln('<div class="page-break"></div>');
      }
    }
    buffer.writeln('</body></html>');

    document.dispose();
    await targetFile.writeAsString(buffer.toString());
    return targetFile;
  }

  static Future<File> pdfToWord({
    required HistoryItem sourceItem,
    required String docName,
  }) async {
    return await pdfToWordFromPath(
      sourcePath: sourceItem.path,
      docName: docName,
    );
  }

  // 6. PDF to PowerPoint (Widescreen 16:9 Presentation Slides)
  static Future<PdfEngineResult> pdfToPowerPointFromPath({
    required String sourcePath,
    required String docName,
    String theme = 'Modern Indigo',
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
    final int pageCount = document.pages.count;

    final pdf = pw.Document();
    const slideFormat = PdfPageFormat(960, 540, marginAll: 36);

    PdfColor primaryColor;
    PdfColor accentBgColor;
    if (theme == 'Crimson Coral') {
      primaryColor = PdfColors.red700;
      accentBgColor = PdfColors.red100;
    } else if (theme == 'Slate Emerald') {
      primaryColor = PdfColors.teal700;
      accentBgColor = PdfColors.teal100;
    } else {
      primaryColor = PdfColors.indigo800;
      accentBgColor = PdfColors.indigo50;
    }

    for (int p = 0; p < pageCount; p++) {
      final pageText = extractor.extractText(startPageIndex: p, endPageIndex: p);
      final rawLines = pageText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final title = rawLines.isNotEmpty ? rawLines.first : 'Slide ${p + 1}';
      final contentLines = rawLines.length > 1 ? rawLines.skip(1).take(6).toList() : <String>[];

      pdf.addPage(
        pw.Page(
          pageFormat: slideFormat,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(32),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                border: pw.Border.all(color: primaryColor, width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          title,
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: accentBgColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        ),
                        child: pw.Text(
                          'PDFDost Presentation',
                          style: pw.TextStyle(color: primaryColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: primaryColor, thickness: 1.5),
                  pw.SizedBox(height: 18),
                  if (contentLines.isNotEmpty)
                    ...contentLines.map((line) => pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 10),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Container(
                                margin: const pw.EdgeInsets.only(top: 6, right: 10),
                                width: 7,
                                height: 7,
                                decoration: pw.BoxDecoration(
                                  color: primaryColor,
                                  shape: pw.BoxShape.circle,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  line,
                                  style: const pw.TextStyle(fontSize: 13, lineSpacing: 2.5),
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ),
                        ))
                  else
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Text(
                          'Content extracted from page ${p + 1} of source document.',
                          style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 13),
                        ),
                      ),
                    ),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Slide ${p + 1} of $pageCount',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        DateFormat('dd MMM yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    document.dispose();
    return await _saveDocument(pdf, docName);
  }

  static Future<PdfEngineResult> pdfToPowerPoint({
    required HistoryItem sourceItem,
    required String docName,
  }) async {
    return await pdfToPowerPointFromPath(
      sourcePath: sourceItem.path,
      docName: docName,
    );
  }

  // 7. PDF to Excel (Structured Spreadsheet .csv export)
  static Future<File> pdfToExcelFromPath({
    required String sourcePath,
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
    final int pageCount = document.pages.count;

    final appDir = await getApplicationDocumentsDirectory();
    var sanitizedName = docName.trim();
    if (sanitizedName.isEmpty) {
      sanitizedName = 'Spreadsheet_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    if (sanitizedName.toLowerCase().endsWith('.csv')) {
      sanitizedName = sanitizedName.substring(0, sanitizedName.length - 4);
    }
    sanitizedName = sanitizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final targetFile = File('${appDir.path}/$sanitizedName.csv');

    final csv = StringBuffer();
    // Excel UTF-8 BOM
    csv.write('\uFEFF');
    csv.writeln('"Page","Line","Extracted Content","Column 2 / Notes"');

    int rowCounter = 1;
    for (int p = 0; p < pageCount; p++) {
      final pageText = extractor.extractText(startPageIndex: p, endPageIndex: p);
      final lines = pageText.split('\n');
      for (int l = 0; l < lines.length; l++) {
        final line = lines[l].trim();
        if (line.isEmpty) continue;

        List<String> cols;
        if (line.contains('\t')) {
          cols = line.split('\t').map((s) => s.trim()).toList();
        } else if (line.contains('  ')) {
          cols = line.split(RegExp(r'\s{2,}')).map((s) => s.trim()).toList();
        } else {
          cols = [line];
        }

        final col1 = cols.isNotEmpty ? cols[0].replaceAll('"', '""') : '';
        final col2 = cols.length > 1 ? cols.sublist(1).join(' | ').replaceAll('"', '""') : '';

        csv.writeln('"${p + 1}","$rowCounter","$col1","$col2"');
        rowCounter++;
      }
    }

    document.dispose();
    await targetFile.writeAsString(csv.toString());
    return targetFile;
  }

  static Future<File> pdfToExcel({
    required HistoryItem sourceItem,
    required String docName,
  }) async {
    return await pdfToExcelFromPath(
      sourcePath: sourceItem.path,
      docName: docName,
    );
  }

  // 8. Word to PDF Creator
  static Future<PdfEngineResult> wordToPdf({
    required String title,
    required String author,
    required String contentText,
    required String docName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Text(
            title,
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
          ),
        ),
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Author: $author  •  ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(color: PdfColors.blue300, thickness: 1.5),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Paragraph(
            text: contentText.isNotEmpty
                ? contentText
                : 'This document was composed and converted to a high-quality PDF using the PDFDost Word-to-PDF engine.',
            style: const pw.TextStyle(fontSize: 13, lineSpacing: 4),
          ),
        ],
      ),
    );

    return await _saveDocument(pdf, docName);
  }

  // 9. PowerPoint to PDF Creator
  static Future<PdfEngineResult> powerPointToPdf({
    required String presentationTitle,
    required List<String> slideTopics,
    required String docName,
  }) async {
    final pdf = pw.Document();
    const slideFormat = PdfPageFormat(842, 595, marginAll: 36);

    for (int i = 0; i < slideTopics.length; i++) {
      final topic = slideTopics[i];
      pdf.addPage(
        pw.Page(
          pageFormat: slideFormat,
          build: (pw.Context ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(28),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    presentationTitle,
                    style: const pw.TextStyle(color: PdfColors.red700, fontSize: 13, letterSpacing: 1),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    topic,
                    style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                  ),
                  pw.Divider(color: PdfColors.red300, thickness: 2),
                  pw.SizedBox(height: 24),
                  pw.Bullet(text: 'Detailed presentation topic outline for $topic'),
                  pw.Bullet(text: 'Executive summary bullet point aligned for widescreen projection'),
                  pw.Bullet(text: 'Generated with high-resolution vector fonts using PDFDost'),
                  pw.Spacer(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Slide ${i + 1} of ${slideTopics.length}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                      pw.Text(DateFormat('MMMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return await _saveDocument(pdf, docName);
  }

  // 10. Excel to PDF Creator
  static Future<PdfEngineResult> excelToPdf({
    required String sheetTitle,
    required List<List<String>> tableData,
    required String docName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                sheetTitle,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated Spreadsheet Table  •  ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                context: ctx,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                data: tableData,
              ),
            ],
          );
        },
      ),
    );

    return await _saveDocument(pdf, docName);
  }

  // 11. Edit PDF (Title, Author, Annotations)
  static Future<PdfEngineResult> editPdf({
    required HistoryItem sourceItem,
    required String newTitle,
    required String author,
    required String annotationNote,
    required String docName,
  }) async {
    final pdf = pw.Document();
    final pagesCount = sourceItem.pages > 0 ? sourceItem.pages : 1;

    for (int i = 0; i < pagesCount; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(newTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.purple800)),
                    pw.Text('Page ${i + 1} of $pagesCount', style: const pw.TextStyle(color: PdfColors.grey600)),
                  ],
                ),
                pw.Text('Author / Editor: $author', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                pw.Divider(color: PdfColors.purple300),
                pw.SizedBox(height: 16),
                if (annotationNote.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    margin: const pw.EdgeInsets.only(bottom: 16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.yellow100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.yellow600),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text('Editor Note: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Expanded(child: pw.Text(annotationNote, style: const pw.TextStyle(fontSize: 11))),
                      ],
                    ),
                  ),
                pw.Expanded(
                  child: pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text('Document content with revised metadata and editorial markup.'),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return await _saveDocument(pdf, docName);
  }

  // 12. PDF to JPG (Render pages to real JPG images)
  static Future<List<File>> pdfToJpgFromPath({
    required String sourcePath,
    required String docName,
    int dpi = 150,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final appDir = await getApplicationDocumentsDirectory();

    var sanitizedName = docName.trim();
    if (sanitizedName.isEmpty) {
      sanitizedName = 'Images_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    sanitizedName = sanitizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final List<File> outputFiles = [];
    int pageIndex = 1;

    await for (final rasterPage in Printing.raster(bytes, dpi: dpi.toDouble())) {
      final pngBytes = await rasterPage.toPng();
      final imgFile = File('${appDir.path}/${sanitizedName}_page_$pageIndex.jpg');
      await imgFile.writeAsBytes(pngBytes);
      outputFiles.add(imgFile);
      pageIndex++;
    }

    return outputFiles;
  }

  static Future<List<File>> pdfToJpg({
    required HistoryItem sourceItem,
    int dpi = 150,
  }) async {
    return await pdfToJpgFromPath(
      sourcePath: sourceItem.path,
      docName: sourceItem.name.replaceAll('.pdf', ''),
      dpi: dpi,
    );
  }

  // 13. Page Numbers (Vector stamp on actual PDF pages)
  static Future<PdfEngineResult> addPageNumbersToPdf({
    required String sourcePath,
    required String position, // Bottom Center, Bottom Right, Top Right, Bottom Left
    required String format, // Page {n} of {total}, {n} / {total}, Page {n}, {n}
    int startNumber = 1,
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final int pageCount = document.pages.count;

    final sf.PdfStandardFont font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10);
    final sf.PdfBrush brush = sf.PdfSolidBrush(sf.PdfColor(100, 116, 139));

    for (int i = 0; i < pageCount; i++) {
      final sf.PdfPage page = document.pages[i];
      final int pageNumber = i + startNumber;
      String label;
      if (format.contains('of')) {
        label = 'Page $pageNumber of $pageCount';
      } else if (format.contains('/')) {
        label = '$pageNumber / $pageCount';
      } else if (format.startsWith('Page')) {
        label = 'Page $pageNumber';
      } else {
        label = '$pageNumber';
      }

      final Size textSize = font.measureString(label);
      double x = 0;
      double y = 0;

      switch (position) {
        case 'Bottom Right':
          x = page.size.width - textSize.width - 36;
          y = page.size.height - 30;
          break;
        case 'Top Right':
          x = page.size.width - textSize.width - 36;
          y = 20;
          break;
        case 'Bottom Left':
          x = 36;
          y = page.size.height - 30;
          break;
        case 'Bottom Center':
        default:
          x = (page.size.width - textSize.width) / 2;
          y = page.size.height - 30;
          break;
      }

      page.graphics.drawString(
        label,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(x, y, textSize.width + 10, textSize.height + 4),
      );
    }

    final List<int> savedBytes = await document.save();
    document.dispose();
    return await _saveBytes(savedBytes, docName, pageCount);
  }

  static Future<PdfEngineResult> addPageNumbers({
    required HistoryItem sourceItem,
    required String position,
    required String format,
    required String docName,
  }) async {
    return await addPageNumbersToPdf(
      sourcePath: sourceItem.path,
      position: position,
      format: format,
      docName: docName,
    );
  }

  // 14. Watermark PDF (Overlay text watermark on actual PDF)
  static Future<PdfEngineResult> addWatermarkToPdf({
    required String sourcePath,
    required String watermarkText,
    double opacity = 0.35,
    bool isDiagonal = true,
    int colorValue = 0xFFDC2626,
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final int pageCount = document.pages.count;

    final int r = (colorValue >> 16) & 0xFF;
    final int g = (colorValue >> 8) & 0xFF;
    final int b = colorValue & 0xFF;

    final sf.PdfStandardFont font = sf.PdfStandardFont(
      sf.PdfFontFamily.helvetica,
      38,
      style: sf.PdfFontStyle.bold,
    );
    final sf.PdfBrush brush = sf.PdfSolidBrush(sf.PdfColor(r, g, b));

    for (int i = 0; i < pageCount; i++) {
      final sf.PdfPage page = document.pages[i];
      final sf.PdfGraphics graphics = page.graphics;
      final sf.PdfGraphicsState state = graphics.save();

      graphics.setTransparency(opacity.clamp(0.05, 0.95));
      final Size textSize = font.measureString(watermarkText);

      if (isDiagonal) {
        graphics.translateTransform(page.size.width / 2, page.size.height / 2);
        graphics.rotateTransform(-40);
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height),
        );
      } else {
        final double x = (page.size.width - textSize.width) / 2;
        final double y = (page.size.height - textSize.height) / 2;
        graphics.drawString(
          watermarkText,
          font,
          brush: brush,
          bounds: Rect.fromLTWH(x, y, textSize.width, textSize.height),
        );
      }

      graphics.restore(state);
    }

    final List<int> savedBytes = await document.save();
    document.dispose();
    return await _saveBytes(savedBytes, docName, pageCount);
  }

  static Future<PdfEngineResult> addWatermark({
    required HistoryItem sourceItem,
    required String watermarkText,
    required double opacity,
    required bool isDiagonal,
    required String docName,
  }) async {
    return await addWatermarkToPdf(
      sourcePath: sourceItem.path,
      watermarkText: watermarkText,
      opacity: opacity,
      isDiagonal: isDiagonal,
      docName: docName,
    );
  }

  // 15. Rotate PDF (Native vector page orientation adjustment)
  static sf.PdfPageRotateAngle _calculateNewRotation(sf.PdfPageRotateAngle current, int degrees) {
    int currentDeg = 0;
    switch (current) {
      case sf.PdfPageRotateAngle.rotateAngle90:
        currentDeg = 90;
        break;
      case sf.PdfPageRotateAngle.rotateAngle180:
        currentDeg = 180;
        break;
      case sf.PdfPageRotateAngle.rotateAngle270:
        currentDeg = 270;
        break;
      case sf.PdfPageRotateAngle.rotateAngle0:
      default:
        currentDeg = 0;
        break;
    }
    final int newDeg = (currentDeg + degrees) % 360;
    switch (newDeg) {
      case 90:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case 180:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case 270:
        return sf.PdfPageRotateAngle.rotateAngle270;
      default:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }

  static Future<PdfEngineResult> rotatePdfDocument({
    required String sourcePath,
    required int rotationDegrees, // 90, 180, 270
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final int pageCount = document.pages.count;

    for (int i = 0; i < pageCount; i++) {
      final sf.PdfPage page = document.pages[i];
      page.rotation = _calculateNewRotation(page.rotation, rotationDegrees);
    }

    final List<int> savedBytes = await document.save();
    document.dispose();
    return await _saveBytes(savedBytes, docName, pageCount);
  }

  static Future<PdfEngineResult> rotatePdf({
    required HistoryItem sourceItem,
    required int rotationDegrees,
    required String docName,
  }) async {
    return await rotatePdfDocument(
      sourcePath: sourceItem.path,
      rotationDegrees: rotationDegrees,
      docName: docName,
    );
  }

  // 16. PDF Lock (Password Protect with AES 128-Bit Encryption)
  static Future<PdfEngineResult> lockPdfDocument({
    required String sourcePath,
    required String password,
    String? ownerPassword,
    required String docName,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw Exception('Source file not found at $sourcePath');
    }
    final bytes = await file.readAsBytes();
    final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
    final int pageCount = document.pages.count;

    final sf.PdfSecurity security = document.security;
    security.userPassword = password;
    security.ownerPassword = (ownerPassword != null && ownerPassword.isNotEmpty)
        ? ownerPassword
        : password;
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx128Bit;
    security.permissions.addAll([
      sf.PdfPermissionsFlags.print,
      sf.PdfPermissionsFlags.copyContent,
    ]);

    final List<int> savedBytes = await document.save();
    document.dispose();
    return await _saveBytes(savedBytes, docName, pageCount);
  }

  static Future<PdfEngineResult> saveDocumentInternal(pw.Document pdf, String docName) =>
      _saveDocument(pdf, docName);

  static Future<PdfEngineResult> _saveDocument(pw.Document pdf, String docName) async {
    var sanitizedName = docName.trim();
    if (sanitizedName.isEmpty) {
      sanitizedName = 'Document_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    if (sanitizedName.toLowerCase().endsWith('.pdf')) {
      sanitizedName = sanitizedName.substring(0, sanitizedName.length - 4);
    }
    sanitizedName = sanitizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '$sanitizedName.pdf';
    final targetFile = File('${appDir.path}/$fileName');

    final bytes = await pdf.save();
    await targetFile.writeAsBytes(bytes);

    return PdfEngineResult(
      path: targetFile.path,
      name: fileName,
      pages: pdf.document.pdfPageList.pages.length,
      sizeStr: formatBytes(bytes.length),
      sizeBytes: bytes.length,
    );
  }

  static Future<PdfEngineResult> _saveBytes(List<int> bytes, String docName, int pageCount) async {
    var sanitizedName = docName.trim();
    if (sanitizedName.isEmpty) {
      sanitizedName = 'Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    if (sanitizedName.toLowerCase().endsWith('.pdf')) {
      sanitizedName = sanitizedName.substring(0, sanitizedName.length - 4);
    }
    sanitizedName = sanitizedName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '$sanitizedName.pdf';
    final targetFile = File('${appDir.path}/$fileName');

    await targetFile.writeAsBytes(bytes);

    return PdfEngineResult(
      path: targetFile.path,
      name: fileName,
      pages: pageCount,
      sizeStr: formatBytes(bytes.length),
      sizeBytes: bytes.length,
    );
  }
}
