import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';
import 'pdf_engine.dart';

class WordTextRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  const WordTextRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });
}

class WordParagraph {
  final String fullText;
  final bool isHeading;
  final int headingLevel; // 1, 2, 3
  final List<WordTextRun> runs;

  const WordParagraph({
    required this.fullText,
    this.isHeading = false,
    this.headingLevel = 0,
    this.runs = const [],
  });
}

class ParsedWordDoc {
  final String title;
  final List<WordParagraph> paragraphs;
  final int totalCharacters;
  final int totalWords;

  const ParsedWordDoc({
    required this.title,
    required this.paragraphs,
    required this.totalCharacters,
    required this.totalWords,
  });
}

class WordEngine {
  /// Unescapes standard XML entities
  static String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'");
  }

  /// Parses a .docx or .doc file into structured paragraphs
  static Future<ParsedWordDoc> parseWordFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const ParsedWordDoc(
        title: 'Document',
        paragraphs: [],
        totalCharacters: 0,
        totalWords: 0,
      );
    }

    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last;
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.docx')) {
      return _parseDocxBytes(bytes, fileName);
    } else {
      return _parseDocBytes(bytes, fileName);
    }
  }

  /// Parses DOCX (OpenXML ZIP format)
  static ParsedWordDoc _parseDocxBytes(Uint8List bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? docXmlFile;

      for (final f in archive.files) {
        if (f.name == 'word/document.xml' || f.name.endsWith('/document.xml')) {
          docXmlFile = f;
          break;
        }
      }

      if (docXmlFile == null) {
        return _fallbackDoc(fileName, 'Document XML structure not found in DOCX archive.');
      }

      final content = docXmlFile.content as List<int>;
      final xml = utf8.decode(content, allowMalformed: true);

      final List<WordParagraph> paragraphs = [];
      final pRegex = RegExp(r'<w:p[ >](.*?)</w:p>', dotAll: true);
      final rRegex = RegExp(r'<w:r[ >](.*?)</w:r>', dotAll: true);
      final tRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
      final styleRegex = RegExp(r'<w:pStyle\s+w:val="([^"]+)"');

      String detectedTitle = '';

      for (final pMatch in pRegex.allMatches(xml)) {
        final pXml = pMatch.group(1) ?? '';

        bool isHeading = false;
        int headingLevel = 0;
        final styleMatch = styleRegex.firstMatch(pXml);
        if (styleMatch != null) {
          final styleVal = styleMatch.group(1)?.toLowerCase() ?? '';
          if (styleVal.contains('heading1') || styleVal.contains('title')) {
            isHeading = true;
            headingLevel = 1;
          } else if (styleVal.contains('heading2') || styleVal.contains('subtitle')) {
            isHeading = true;
            headingLevel = 2;
          } else if (styleVal.contains('heading')) {
            isHeading = true;
            headingLevel = 3;
          }
        }

        final List<WordTextRun> runs = [];
        final StringBuffer pBuffer = StringBuffer();

        for (final rMatch in rRegex.allMatches(pXml)) {
          final rXml = rMatch.group(1) ?? '';
          final bool isBold = rXml.contains('<w:b') &&
              !rXml.contains('<w:b w:val="0"') &&
              !rXml.contains('<w:b w:val="false"');
          final bool isItalic = rXml.contains('<w:i') &&
              !rXml.contains('<w:i w:val="0"') &&
              !rXml.contains('<w:i w:val="false"');
          final bool isUnderline = rXml.contains('<w:u ') || rXml.contains('<w:u/>');

          final StringBuffer rBuffer = StringBuffer();
          for (final tMatch in tRegex.allMatches(rXml)) {
            rBuffer.write(_unescapeXml(tMatch.group(1) ?? ''));
          }

          if (rXml.contains('<w:br') || rXml.contains('<w:cr')) {
            rBuffer.write('\n');
          }
          if (rXml.contains('<w:tab')) {
            rBuffer.write('    ');
          }

          final runText = rBuffer.toString();
          if (runText.isNotEmpty) {
            runs.add(WordTextRun(
              text: runText,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
            ));
            pBuffer.write(runText);
          }
        }

        final fullText = pBuffer.toString().trim();
        if (fullText.isNotEmpty) {
          if (detectedTitle.isEmpty && (isHeading || paragraphs.isEmpty)) {
            detectedTitle = fullText;
          }
          paragraphs.add(WordParagraph(
            fullText: fullText,
            isHeading: isHeading,
            headingLevel: headingLevel,
            runs: runs.isNotEmpty ? runs : [WordTextRun(text: fullText)],
          ));
        }
      }

      if (detectedTitle.isEmpty) {
        detectedTitle = fileName.replaceAll(RegExp(r'\.docx?$', caseSensitive: false), '');
      }

      int totalChars = 0;
      int totalWords = 0;
      for (final p in paragraphs) {
        totalChars += p.fullText.length;
        totalWords += p.fullText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      }

      return ParsedWordDoc(
        title: detectedTitle,
        paragraphs: paragraphs,
        totalCharacters: totalChars,
        totalWords: totalWords,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode DOCX archive: $e');
    }
  }

  /// Parses DOC (Legacy binary CFBF or RTF format)
  static ParsedWordDoc _parseDocBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.docx?$', caseSensitive: false), '');

      // Check if RTF format
      if (bytes.length >= 5 &&
          bytes[0] == 0x7B && // '{'
          bytes[1] == 0x5C && // '\'
          bytes[2] == 0x72 && // 'r'
          bytes[3] == 0x74 && // 't'
          bytes[4] == 0x66) { // 'f'
        final rtfStr = latin1.decode(bytes);
        final cleanText = rtfStr
            .replaceAll(RegExp(r'\\[a-zA-Z]+(-?\d+)? ?'), '')
            .replaceAll(RegExp(r'[{}]'), '')
            .trim();
        final rawLines = cleanText.split(RegExp(r'\r?\n+'));
        final List<WordParagraph> paragraphs = [];
        for (final line in rawLines) {
          final t = line.trim();
          if (t.isNotEmpty) {
            paragraphs.add(WordParagraph(
              fullText: t,
              runs: [WordTextRun(text: t)],
            ));
          }
        }
        return ParsedWordDoc(
          title: docTitle,
          paragraphs: paragraphs,
          totalCharacters: cleanText.length,
          totalWords: cleanText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
        );
      }

      // Check if Binary OLE CFBF (Word 97-2004)
      final List<WordParagraph> paragraphs = [];
      final StringBuffer currentWord = StringBuffer();
      final List<String> extractedStrings = [];

      // Scan UTF-16LE characters common in Word binary streams
      int i = 0;
      while (i < bytes.length - 1) {
        final b1 = bytes[i];
        final b2 = bytes[i + 1];

        // UTF-16LE printable ASCII character (32..126 or newline)
        if (b2 == 0 && ((b1 >= 32 && b1 <= 126) || b1 == 10 || b1 == 13 || b1 == 9)) {
          currentWord.writeCharCode(b1);
          i += 2;
        } else {
          if (currentWord.length >= 4) {
            extractedStrings.add(currentWord.toString());
          }
          currentWord.clear();
          i++;
        }
      }
      if (currentWord.length >= 4) {
        extractedStrings.add(currentWord.toString());
      }

      // Filter out internal Word metadata keywords
      final filteredStrings = extractedStrings.where((s) {
        final lower = s.toLowerCase();
        if (lower.contains('microsoft word') ||
            lower.contains('compobj') ||
            lower.contains('worddocument') ||
            lower.contains('summaryinformation') ||
            lower.contains('documentproperties') ||
            lower.startsWith('normal.dotm') ||
            lower.startsWith('times new roman') ||
            lower.startsWith('calibri')) {
          return false;
        }
        return s.trim().length >= 3;
      }).toList();

      for (final s in filteredStrings) {
        final t = s.trim();
        if (t.isNotEmpty) {
          paragraphs.add(WordParagraph(
            fullText: t,
            runs: [WordTextRun(text: t)],
          ));
        }
      }

      if (paragraphs.isEmpty) {
        // Fallback to UTF-8 extraction
        final plain = utf8.decode(bytes, allowMalformed: true);
        final lines = plain.split(RegExp(r'[\r\n\x00-\x08\x0B\x0C\x0E-\x1F]+'));
        for (final line in lines) {
          final t = line.trim();
          if (t.length >= 4 && t.codeUnits.every((c) => c >= 32 && c <= 126)) {
            paragraphs.add(WordParagraph(
              fullText: t,
              runs: [WordTextRun(text: t)],
            ));
          }
        }
      }

      int totalChars = 0;
      int totalWords = 0;
      for (final p in paragraphs) {
        totalChars += p.fullText.length;
        totalWords += p.fullText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      }

      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        totalCharacters: totalChars,
        totalWords: totalWords,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse binary DOC file: $e');
    }
  }

  static ParsedWordDoc _fallbackDoc(String fileName, String note) {
    final title = fileName.replaceAll(RegExp(r'\.docx?$', caseSensitive: false), '');
    return ParsedWordDoc(
      title: title,
      paragraphs: [
        WordParagraph(
          fullText: title,
          isHeading: true,
          headingLevel: 1,
          runs: [WordTextRun(text: title, isBold: true)],
        ),
        WordParagraph(
          fullText: 'Document imported from: $fileName',
          runs: [WordTextRun(text: 'Document imported from: $fileName')],
        ),
        WordParagraph(
          fullText: note,
          runs: [WordTextRun(text: note)],
        ),
      ],
      totalCharacters: title.length,
      totalWords: 5,
    );
  }

  /// Converts one or multiple Word documents into a polished, high quality PDF
  static Future<PdfEngineResult> convertWordFilesToPdf({
    required List<SelectedWordItem> items,
    String? customName,
  }) async {
    if (items.isEmpty) {
      throw Exception('No Word files provided for conversion');
    }

    final pdf = pw.Document();
    final primaryName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : items.first.name.replaceAll(RegExp(r'\.docx?$', caseSensitive: false), '');

    final String outputName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : (items.length == 1
            ? '${primaryName}_converted'
            : 'WordDocs_Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}');

    final wordBlue = PdfColor.fromInt(0xFF185ABD);
    final accentDark = PdfColor.fromInt(0xFF0F172A);

    for (int docIdx = 0; docIdx < items.length; docIdx++) {
      final item = items[docIdx];
      final parsed = await parseWordFile(item.path);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  parsed.title,
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
                ),
                pw.Text(
                  'PDFDost Word-to-PDF Engine',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
                ),
              ],
            ),
          ),
          build: (pw.Context ctx) {
            final List<pw.Widget> widgets = [];

            // Document Header Banner
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 28,
                          height: 28,
                          decoration: pw.BoxDecoration(
                            color: wordBlue,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          alignment: pw.Alignment.center,
                          child: pw.Text(
                            item.extension.toUpperCase(),
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Text(
                            parsed.title.isNotEmpty ? parsed.title : item.name,
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Source File: ${item.name} (${item.formattedSize})  •  Words: ${parsed.totalWords}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            // Document Body Paragraphs
            if (parsed.paragraphs.isEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 20),
                  child: pw.Text(
                    'No readable text extracted from ${item.name}.',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                  ),
                ),
              );
            } else {
              for (final p in parsed.paragraphs) {
                if (p.isHeading) {
                  final double fontSize = p.headingLevel == 1
                      ? 18
                      : (p.headingLevel == 2 ? 15 : 13);
                  widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
                      child: pw.Text(
                        p.fullText,
                        style: pw.TextStyle(
                          fontSize: fontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: p.headingLevel == 1 ? wordBlue : accentDark,
                        ),
                      ),
                    ),
                  );
                } else {
                  // Render paragraph with rich text runs
                  final spans = p.runs.map((r) {
                    return pw.TextSpan(
                      text: r.text,
                      style: pw.TextStyle(
                        fontWeight: r.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        fontStyle: r.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                        decoration: r.isUnderline ? pw.TextDecoration.underline : null,
                        fontSize: 11,
                        color: accentDark,
                        lineSpacing: 3,
                      ),
                    );
                  }).toList();

                  widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.RichText(
                        text: pw.TextSpan(children: spans),
                      ),
                    ),
                  );
                }
              }
            }

            return widgets;
          },
        ),
      );
    }

    return await PdfEngine.saveDocumentInternal(pdf, outputName);
  }
}
