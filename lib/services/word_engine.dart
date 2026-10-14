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
  final List<List<String>>? tableData;
  final int totalCharacters;
  final int totalWords;
  final bool isTable;

  const ParsedWordDoc({
    required this.title,
    required this.paragraphs,
    this.tableData,
    required this.totalCharacters,
    required this.totalWords,
    this.isTable = false,
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

  /// Parses any supported document, spreadsheet, or text file into structured content
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
    final ext = lowerName.contains('.') ? lowerName.split('.').last : '';

    if (ext == 'docx') {
      return _parseDocxBytes(bytes, fileName);
    } else if (['xlsx', 'xlsm', 'xltx', 'xltm'].contains(ext)) {
      return _parseXlsxBytes(bytes, fileName);
    } else if (ext == 'ods') {
      return _parseOdsBytes(bytes, fileName);
    } else if (ext == 'csv') {
      return _parseCsvBytes(bytes, fileName);
    } else if (['txt', 'prn'].contains(ext)) {
      return _parseTextBytes(bytes, fileName, ext == 'prn');
    } else if (ext == 'xml') {
      return _parseXmlBytes(bytes, fileName);
    } else if (['xls', 'xlsb', 'xlw', 'xlt'].contains(ext)) {
      return _parseBinaryXlsBytes(bytes, fileName);
    } else if (ext == 'doc') {
      return _parseDocBytes(bytes, fileName);
    } else {
      return _parseTextBytes(bytes, fileName, false);
    }
  }

  /// 1. Parses DOCX (OpenXML ZIP format)
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
        detectedTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
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
        isTable: false,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode DOCX archive: $e');
    }
  }

  /// 2. Parses XLSX / XLSM / XLTX / XLTM (OpenXML Spreadsheet)
  static ParsedWordDoc _parseXlsxBytes(Uint8List bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      // Shared Strings
      final List<String> sharedStrings = [];
      ArchiveFile? sstFile;
      for (final f in archive.files) {
        if (f.name == 'xl/sharedStrings.xml' || f.name.endsWith('/sharedStrings.xml')) {
          sstFile = f;
          break;
        }
      }
      if (sstFile != null) {
        final sstXml = utf8.decode(sstFile.content as List<int>, allowMalformed: true);
        final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
        final tRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
        for (final siMatch in siRegex.allMatches(sstXml)) {
          final siContent = siMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final tMatch in tRegex.allMatches(siContent)) {
            sb.write(_unescapeXml(tMatch.group(1) ?? ''));
          }
          sharedStrings.add(sb.toString());
        }
      }

      // First Worksheet
      ArchiveFile? sheetFile;
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }

      if (sheetFile == null) {
        return _fallbackDoc(fileName, 'Worksheet data not found in spreadsheet.');
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
      final cellRegex = RegExp(r'<c\s+([^>]*?)>(.*?)</c>', dotAll: true);
      final valRegex = RegExp(r'<v>(.*?)</v>', dotAll: true);
      final inlineRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

      final List<List<String>> tableRows = [];
      final List<WordParagraph> paragraphs = [];

      for (final rowMatch in rowRegex.allMatches(sheetXml)) {
        final rowXml = rowMatch.group(1) ?? '';
        final List<String> cells = [];

        for (final cellMatch in cellRegex.allMatches(rowXml)) {
          final attr = cellMatch.group(1) ?? '';
          final body = cellMatch.group(2) ?? '';
          final isShared = attr.contains('t="s"');
          final isInline = attr.contains('t="inlineStr"');

          String val = '';
          if (isShared) {
            final vm = valRegex.firstMatch(body);
            if (vm != null) {
              final idx = int.tryParse(vm.group(1) ?? '');
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                val = sharedStrings[idx];
              }
            }
          } else if (isInline) {
            final im = inlineRegex.firstMatch(body);
            if (im != null) {
              val = _unescapeXml(im.group(1) ?? '');
            }
          } else {
            final vm = valRegex.firstMatch(body);
            if (vm != null) {
              val = _unescapeXml(vm.group(1) ?? '');
            }
          }
          cells.add(val.trim());
        }

        if (cells.any((c) => c.isNotEmpty)) {
          tableRows.add(cells);
          final line = cells.where((c) => c.isNotEmpty).join(' | ');
          paragraphs.add(WordParagraph(fullText: line, runs: [WordTextRun(text: line)]));
        }
      }

      _normalizeTable(tableRows);

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        tableData: tableRows.isNotEmpty ? tableRows : null,
        totalCharacters: paragraphs.fold(0, (sum, p) => sum + p.fullText.length),
        totalWords: paragraphs.fold(0, (sum, p) => sum + p.fullText.split(RegExp(r'\s+')).length),
        isTable: tableRows.isNotEmpty,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse Excel document: $e');
    }
  }

  /// 3. Parses ODS (OpenDocument Spreadsheet)
  static ParsedWordDoc _parseOdsBytes(Uint8List bytes, String fileName) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? contentFile;
      for (final f in archive.files) {
        if (f.name == 'content.xml') {
          contentFile = f;
          break;
        }
      }

      if (contentFile == null) {
        return _fallbackDoc(fileName, 'content.xml not found in ODS archive.');
      }

      final xml = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
      final rowRegex = RegExp(r'<table:table-row[^>]*>(.*?)</table:table-row>', dotAll: true);
      final cellRegex = RegExp(r'<table:table-cell[^>]*>(.*?)</table:table-cell>', dotAll: true);
      final textRegex = RegExp(r'<text:p[^>]*>(.*?)</text:p>', dotAll: true);

      final List<List<String>> tableRows = [];
      final List<WordParagraph> paragraphs = [];

      for (final rMatch in rowRegex.allMatches(xml)) {
        final rXml = rMatch.group(1) ?? '';
        final List<String> row = [];

        for (final cMatch in cellRegex.allMatches(rXml)) {
          final cXml = cMatch.group(1) ?? '';
          final StringBuffer cellBuffer = StringBuffer();
          for (final tMatch in textRegex.allMatches(cXml)) {
            cellBuffer.write(_unescapeXml(tMatch.group(1) ?? ''));
          }
          row.add(cellBuffer.toString().trim());
        }

        if (row.any((c) => c.isNotEmpty)) {
          tableRows.add(row);
          final line = row.where((c) => c.isNotEmpty).join(' | ');
          paragraphs.add(WordParagraph(fullText: line, runs: [WordTextRun(text: line)]));
        }
      }

      _normalizeTable(tableRows);

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        tableData: tableRows.isNotEmpty ? tableRows : null,
        totalCharacters: paragraphs.fold(0, (sum, p) => sum + p.fullText.length),
        totalWords: paragraphs.fold(0, (sum, p) => sum + p.fullText.split(RegExp(r'\s+')).length),
        isTable: tableRows.isNotEmpty,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse ODS document: $e');
    }
  }

  /// 4. Parses CSV (Comma / Semicolon / Tab Delimited)
  static ParsedWordDoc _parseCsvBytes(Uint8List bytes, String fileName) {
    try {
      String text = '';
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      final rawLines = text.split(RegExp(r'\r?\n+'));
      final List<List<String>> tableRows = [];
      final List<WordParagraph> paragraphs = [];

      for (final line in rawLines) {
        if (line.trim().isEmpty) continue;

        String delimiter = ',';
        if (!line.contains(',') && line.contains(';')) {
          delimiter = ';';
        } else if (!line.contains(',') && line.contains('\t')) {
          delimiter = '\t';
        }

        final cells = _splitCsvLine(line, delimiter);
        if (cells.any((c) => c.isNotEmpty)) {
          tableRows.add(cells);
          final str = cells.join(' | ');
          paragraphs.add(WordParagraph(fullText: str, runs: [WordTextRun(text: str)]));
        }
      }

      _normalizeTable(tableRows);

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        tableData: tableRows.isNotEmpty ? tableRows : null,
        totalCharacters: text.length,
        totalWords: text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
        isTable: tableRows.isNotEmpty,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse CSV file: $e');
    }
  }

  /// 5. Parses Text and PRN files
  static ParsedWordDoc _parseTextBytes(Uint8List bytes, String fileName, bool isPrn) {
    try {
      String text = '';
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      final lines = text.split(RegExp(r'\r?\n+'));
      final List<WordParagraph> paragraphs = [];
      final List<List<String>> tableRows = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (isPrn && (line.contains('   ') || line.contains('\t'))) {
          final cells = line.split(RegExp(r'\s{2,}|\t')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (cells.length >= 2) {
            tableRows.add(cells);
          }
        }

        paragraphs.add(WordParagraph(
          fullText: trimmed,
          isHeading: i == 0 && trimmed.length < 50,
          headingLevel: (i == 0 && trimmed.length < 50) ? 1 : 0,
          runs: [WordTextRun(text: trimmed, isBold: i == 0 && trimmed.length < 50)],
        ));
      }

      if (tableRows.length >= 2) {
        _normalizeTable(tableRows);
      }

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        tableData: tableRows.length >= 2 ? tableRows : null,
        totalCharacters: text.length,
        totalWords: text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
        isTable: tableRows.length >= 2,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse text file: $e');
    }
  }

  /// 6. Parses XML and Excel 2003 SpreadsheetML files
  static ParsedWordDoc _parseXmlBytes(Uint8List bytes, String fileName) {
    try {
      final xml = utf8.decode(bytes, allowMalformed: true);
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

      // Check if Excel 2003 XML SpreadsheetML
      if (xml.contains('<Workbook') && xml.contains('<Row')) {
        final rowRegex = RegExp(r'<Row[^>]*>(.*?)</Row>', dotAll: true);
        final cellRegex = RegExp(r'<Cell[^>]*>.*?<Data[^>]*>(.*?)</Data>.*?</Cell>', dotAll: true);
        final List<List<String>> tableRows = [];
        final List<WordParagraph> paragraphs = [];

        for (final rMatch in rowRegex.allMatches(xml)) {
          final rXml = rMatch.group(1) ?? '';
          final List<String> row = [];
          for (final cMatch in cellRegex.allMatches(rXml)) {
            row.add(_unescapeXml(cMatch.group(1) ?? '').trim());
          }
          if (row.any((c) => c.isNotEmpty)) {
            tableRows.add(row);
            final line = row.join(' | ');
            paragraphs.add(WordParagraph(fullText: line, runs: [WordTextRun(text: line)]));
          }
        }

        if (tableRows.isNotEmpty) {
          _normalizeTable(tableRows);
          return ParsedWordDoc(
            title: docTitle,
            paragraphs: paragraphs,
            tableData: tableRows,
            totalCharacters: paragraphs.fold(0, (s, p) => s + p.fullText.length),
            totalWords: paragraphs.fold(0, (s, p) => s + p.fullText.split(RegExp(r'\s+')).length),
            isTable: true,
          );
        }
      }

      // Standard XML: extract key-value nodes
      final List<WordParagraph> paragraphs = [];
      final tagRegex = RegExp(r'<([a-zA-Z0-9_\-]+)([^>]*)>(.*?)</\1>', dotAll: true);
      for (final m in tagRegex.allMatches(xml)) {
        final tag = m.group(1) ?? '';
        final content = _unescapeXml(m.group(3) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (content.isNotEmpty && !content.contains('\n')) {
          paragraphs.add(WordParagraph(
            fullText: '$tag: $content',
            runs: [
              WordTextRun(text: '$tag: ', isBold: true),
              WordTextRun(text: content),
            ],
          ));
        }
      }

      if (paragraphs.isEmpty) {
        final stripped = xml.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        paragraphs.add(WordParagraph(fullText: stripped, runs: [WordTextRun(text: stripped)]));
      }

      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        totalCharacters: paragraphs.fold(0, (s, p) => s + p.fullText.length),
        totalWords: paragraphs.fold(0, (s, p) => s + p.fullText.split(RegExp(r'\s+')).length),
        isTable: false,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse XML document: $e');
    }
  }

  /// 7. Parses Binary Excel XLS / XLSB / XLW / XLT
  static ParsedWordDoc _parseBinaryXlsBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final List<String> extracted = [];
      final StringBuffer currentStr = StringBuffer();

      int i = 0;
      while (i < bytes.length - 1) {
        final b1 = bytes[i];
        final b2 = bytes[i + 1];
        if (b2 == 0 && ((b1 >= 32 && b1 <= 126) || b1 == 10 || b1 == 13 || b1 == 9)) {
          currentStr.writeCharCode(b1);
          i += 2;
        } else {
          if (currentStr.length >= 3) {
            extracted.add(currentStr.toString());
          }
          currentStr.clear();
          i++;
        }
      }
      if (currentStr.length >= 3) {
        extracted.add(currentStr.toString());
      }

      final cleanStrings = extracted.where((s) {
        final l = s.toLowerCase();
        if (l.contains('microsoft excel') ||
            l.contains('workbook') ||
            (l.contains('sheet') && s.length < 8) ||
            l.contains('compobj') ||
            l.contains('summaryinformation')) {
          return false;
        }
        return s.trim().length >= 2;
      }).map((s) => s.trim()).toList();

      final List<List<String>> tableRows = [];
      final List<WordParagraph> paragraphs = [];

      if (cleanStrings.length >= 4) {
        int cols = 4;
        if (cleanStrings.length % 3 == 0 && cleanStrings.length % 4 != 0) cols = 3;
        for (int idx = 0; idx < cleanStrings.length; idx += cols) {
          final row = cleanStrings.skip(idx).take(cols).toList();
          tableRows.add(row);
          final line = row.join(' | ');
          paragraphs.add(WordParagraph(fullText: line, runs: [WordTextRun(text: line)]));
        }
        _normalizeTable(tableRows);
      } else {
        for (final s in cleanStrings) {
          paragraphs.add(WordParagraph(fullText: s, runs: [WordTextRun(text: s)]));
        }
      }

      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        tableData: tableRows.isNotEmpty ? tableRows : null,
        totalCharacters: paragraphs.fold(0, (s, p) => s + p.fullText.length),
        totalWords: paragraphs.fold(0, (s, p) => s + p.fullText.split(RegExp(r'\s+')).length),
        isTable: tableRows.isNotEmpty,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse Excel binary file: $e');
    }
  }

  /// 8. Parses Legacy Word DOC (RTF, CFBF binary, or plain text)
  static ParsedWordDoc _parseDocBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

      // Check if RTF format
      if (bytes.length >= 5 &&
          bytes[0] == 0x7B &&
          bytes[1] == 0x5C &&
          bytes[2] == 0x72 &&
          bytes[3] == 0x74 &&
          bytes[4] == 0x66) {
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
          isTable: false,
        );
      }

      // Check if Binary OLE CFBF (Word 97-2004)
      final List<WordParagraph> paragraphs = [];
      final StringBuffer currentWord = StringBuffer();
      final List<String> extractedStrings = [];

      int i = 0;
      while (i < bytes.length - 1) {
        final b1 = bytes[i];
        final b2 = bytes[i + 1];

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
        isTable: false,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse binary DOC file: $e');
    }
  }

  static void _normalizeTable(List<List<String>> table) {
    if (table.isEmpty) return;
    int maxCols = 0;
    for (final row in table) {
      if (row.length > maxCols) maxCols = row.length;
    }
    if (maxCols > 8) maxCols = 8;
    for (final row in table) {
      if (row.length < maxCols) {
        row.addAll(List.filled(maxCols - row.length, ''));
      } else if (row.length > maxCols) {
        row.removeRange(maxCols, row.length);
      }
    }
  }

  static List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> cells = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == delimiter && !inQuotes) {
        cells.add(current.toString().trim());
        current.clear();
      } else {
        current.write(char);
      }
    }
    cells.add(current.toString().trim());
    return cells;
  }

  static ParsedWordDoc _fallbackDoc(String fileName, String note) {
    final title = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
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
      isTable: false,
    );
  }

  /// Converts one or multiple Word/Spreadsheet/Data documents into a polished, high quality PDF
  static Future<PdfEngineResult> convertWordFilesToPdf({
    required List<SelectedWordItem> items,
    String? customName,
  }) async {
    if (items.isEmpty) {
      throw Exception('No files provided for conversion');
    }

    final pdf = pw.Document();
    final primaryName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : items.first.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    final String outputName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : (items.length == 1
            ? '${primaryName}_converted'
            : 'ConvertedDocs_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}');

    final wordBlue = PdfColor.fromInt(0xFF185ABD);
    final excelGreen = PdfColor.fromInt(0xFF107C41);
    final accentDark = PdfColor.fromInt(0xFF0F172A);

    for (int docIdx = 0; docIdx < items.length; docIdx++) {
      final item = items[docIdx];
      final parsed = await parseWordFile(item.path);
      final isSpreadsheet = parsed.isTable && parsed.tableData != null && parsed.tableData!.isNotEmpty;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: isSpreadsheet ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(bottom: 10),
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
                  'PDFDost Document Engine',
                  style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 9),
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 10),
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
            final primaryColor = isSpreadsheet ? excelGreen : wordBlue;

            // Document Header Banner
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 18),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F5F9),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 1),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      width: 32,
                      height: 32,
                      decoration: pw.BoxDecoration(
                        color: primaryColor,
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
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            parsed.title.isNotEmpty ? parsed.title : item.name,
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Source: ${item.name} (${item.formattedSize})  •  Format: .${item.extension}',
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

            // Table rendering for spreadsheets & CSV
            if (isSpreadsheet) {
              final tableData = parsed.tableData!;
              widgets.add(
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: primaryColor),
                  rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  data: tableData,
                ),
              );
            } else {
              // Paragraph rendering for documents and text
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
                        ? 17
                        : (p.headingLevel == 2 ? 14 : 12);
                    widgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
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
                    final spans = p.runs.map((r) {
                      return pw.TextSpan(
                        text: r.text,
                        style: pw.TextStyle(
                          fontWeight: r.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                          fontStyle: r.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                          decoration: r.isUnderline ? pw.TextDecoration.underline : null,
                          fontSize: 10.5,
                          color: accentDark,
                          lineSpacing: 2.5,
                        ),
                      );
                    }).toList();

                    widgets.add(
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.RichText(text: pw.TextSpan(children: spans)),
                      ),
                    );
                  }
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
