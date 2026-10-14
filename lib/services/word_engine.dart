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
  final int totalRows;

  const ParsedWordDoc({
    required this.title,
    this.paragraphs = const [],
    this.tableData,
    required this.totalCharacters,
    required this.totalWords,
    this.totalRows = 0,
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

  /// Parses any supported document or spreadsheet into structured paragraphs or table data
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

    // 1. Modern OpenXML Word (.docx)
    if (lowerName.endsWith('.docx')) {
      return _parseDocxBytes(bytes, fileName);
    }

    // 2. Modern OpenXML Spreadsheets (.xlsx, .xlsm, .xltx, .xltm)
    if (lowerName.endsWith('.xlsx') ||
        lowerName.endsWith('.xlsm') ||
        lowerName.endsWith('.xltx') ||
        lowerName.endsWith('.xltm')) {
      return _parseXlsxBytes(bytes, fileName);
    }

    // 3. OpenDocument Spreadsheet (.ods)
    if (lowerName.endsWith('.ods')) {
      return _parseOdsBytes(bytes, fileName);
    }

    // 4. Comma-Separated Values (.csv)
    if (lowerName.endsWith('.csv')) {
      return _parseCsvBytes(bytes, fileName);
    }

    // 5. Formatted Text / Print Files (.prn, .txt)
    if (lowerName.endsWith('.prn') || lowerName.endsWith('.txt')) {
      return _parseTextBytes(bytes, fileName, isPrn: lowerName.endsWith('.prn'));
    }

    // 6. XML Documents (.xml)
    if (lowerName.endsWith('.xml')) {
      return _parseXmlBytes(bytes, fileName);
    }

    // 7. Legacy Spreadsheets (.xls, .xlw, .xlt, .xlsb)
    if (lowerName.endsWith('.xls') ||
        lowerName.endsWith('.xlw') ||
        lowerName.endsWith('.xlt') ||
        lowerName.endsWith('.xlsb')) {
      return _parseLegacyXlsBytes(bytes, fileName);
    }

    // 8. Legacy Word (.doc) & Fallback
    return _parseDocBytes(bytes, fileName);
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
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode DOCX archive: $e');
    }
  }

  /// Parses modern Excel OpenXML (.xlsx, .xlsm, .xltx, .xltm)
  static ParsedWordDoc _parseXlsxBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final archive = ZipDecoder().decodeBytes(bytes);

      // 1. Extract shared strings table if present
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
          final siBody = siMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final tMatch in tRegex.allMatches(siBody)) {
            sb.write(_unescapeXml(tMatch.group(1) ?? ''));
          }
          sharedStrings.add(sb.toString());
        }
      }

      // 2. Find first worksheet
      ArchiveFile? sheetFile;
      for (final f in archive.files) {
        if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
          sheetFile = f;
          break;
        }
      }

      if (sheetFile == null) {
        return _fallbackDoc(fileName, 'Worksheet structure not found in Excel file.');
      }

      final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
      final List<List<String>> tableRows = [];

      final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
      final cRegex = RegExp(r'<c\s+([^>]+)>(.*?)</c>', dotAll: true);
      final vRegex = RegExp(r'<v>(.*?)</v>', dotAll: true);
      final tInlineRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);

      int totalCells = 0;
      int maxCols = 0;

      for (final rMatch in rowRegex.allMatches(sheetXml)) {
        final rowXml = rMatch.group(1) ?? '';
        final List<String> cells = [];

        for (final cMatch in cRegex.allMatches(rowXml)) {
          final attrs = cMatch.group(1) ?? '';
          final cBody = cMatch.group(2) ?? '';

          String cellVal = '';
          if (attrs.contains('t="inlineStr"') || attrs.contains("t='inlineStr'")) {
            final StringBuffer sb = StringBuffer();
            for (final tMatch in tInlineRegex.allMatches(cBody)) {
              sb.write(_unescapeXml(tMatch.group(1) ?? ''));
            }
            cellVal = sb.toString();
          } else if (attrs.contains('t="s"') || attrs.contains("t='s'")) {
            final vMatch = vRegex.firstMatch(cBody);
            final idxStr = vMatch?.group(1);
            if (idxStr != null) {
              final idx = int.tryParse(idxStr) ?? -1;
              if (idx >= 0 && idx < sharedStrings.length) {
                cellVal = sharedStrings[idx];
              }
            }
          } else {
            final vMatch = vRegex.firstMatch(cBody);
            cellVal = _unescapeXml(vMatch?.group(1) ?? '');
          }

          cells.add(cellVal.trim());
          if (cellVal.trim().isNotEmpty) totalCells++;
        }

        if (cells.any((c) => c.isNotEmpty)) {
          // Cap column width to keep PDF clean
          final capped = cells.take(12).toList();
          if (capped.length > maxCols) maxCols = capped.length;
          tableRows.add(capped);
        }
      }

      // Normalize row widths
      for (final row in tableRows) {
        while (row.length < maxCols) {
          row.add('');
        }
      }

      return ParsedWordDoc(
        title: docTitle,
        tableData: tableRows,
        totalCharacters: totalCells * 6,
        totalWords: totalCells,
        totalRows: tableRows.length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode Excel archive: $e');
    }
  }

  /// Parses OpenDocument Spreadsheet (.ods)
  static ParsedWordDoc _parseOdsBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
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
      final List<List<String>> rows = [];

      final rowRegex = RegExp(r'<table:table-row[^>]*>(.*?)</table:table-row>', dotAll: true);
      final cellRegex = RegExp(r'<table:table-cell[^>]*>(.*?)</table:table-cell>', dotAll: true);
      final textRegex = RegExp(r'<text:p[^>]*>(.*?)</text:p>', dotAll: true);

      int maxCols = 0;
      for (final rMatch in rowRegex.allMatches(xml)) {
        final rBody = rMatch.group(1) ?? '';
        final List<String> cells = [];

        for (final cMatch in cellRegex.allMatches(rBody)) {
          final cBody = cMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final tMatch in textRegex.allMatches(cBody)) {
            sb.write(_unescapeXml(tMatch.group(1) ?? ''));
          }
          cells.add(sb.toString().trim());
        }

        if (cells.any((c) => c.isNotEmpty)) {
          final capped = cells.take(12).toList();
          if (capped.length > maxCols) maxCols = capped.length;
          rows.add(capped);
        }
      }

      for (final row in rows) {
        while (row.length < maxCols) {
          row.add('');
        }
      }

      return ParsedWordDoc(
        title: docTitle,
        tableData: rows,
        totalCharacters: rows.length * maxCols * 5,
        totalWords: rows.length * maxCols,
        totalRows: rows.length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode ODS file: $e');
    }
  }

  /// Parses CSV files (.csv)
  static ParsedWordDoc _parseCsvBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      String text = '';
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      final lines = text.split(RegExp(r'\r?\n'));
      final List<List<String>> tableRows = [];

      // Detect separator: comma, semicolon, or tab
      String delimiter = ',';
      if (lines.isNotEmpty) {
        final first = lines.first;
        final commaCount = ','.allMatches(first).length;
        final semiCount = ';'.allMatches(first).length;
        final tabCount = '\t'.allMatches(first).length;
        if (semiCount > commaCount && semiCount > tabCount) {
          delimiter = ';';
        } else if (tabCount > commaCount && tabCount > semiCount) {
          delimiter = '\t';
        }
      }

      int maxCols = 0;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        final List<String> cells = [];
        final StringBuffer curCell = StringBuffer();
        bool inQuotes = false;

        for (int i = 0; i < line.length; i++) {
          final ch = line[i];
          if (ch == '"') {
            inQuotes = !inQuotes;
          } else if (ch == delimiter && !inQuotes) {
            cells.add(curCell.toString().trim());
            curCell.clear();
          } else {
            curCell.write(ch);
          }
        }
        cells.add(curCell.toString().trim());

        if (cells.any((c) => c.isNotEmpty)) {
          final capped = cells.take(12).toList();
          if (capped.length > maxCols) maxCols = capped.length;
          tableRows.add(capped);
        }
      }

      for (final row in tableRows) {
        while (row.length < maxCols) {
          row.add('');
        }
      }

      return ParsedWordDoc(
        title: docTitle,
        tableData: tableRows,
        totalCharacters: text.length,
        totalWords: tableRows.length * maxCols,
        totalRows: tableRows.length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not decode CSV file: $e');
    }
  }

  /// Parses Plain Text (.txt) or Formatted Print (.prn)
  static ParsedWordDoc _parseTextBytes(Uint8List bytes, String fileName, {bool isPrn = false}) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      String text = '';
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      final lines = text.split(RegExp(r'\r?\n'));

      if (isPrn) {
        // Parse space-separated columns for PRN print reports
        final List<List<String>> tableRows = [];
        int maxCols = 0;

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final cells = line.trim().split(RegExp(r'\s{2,}|\t')).where((s) => s.isNotEmpty).toList();
          if (cells.isNotEmpty) {
            final capped = cells.take(10).toList();
            if (capped.length > maxCols) maxCols = capped.length;
            tableRows.add(capped);
          }
        }

        if (tableRows.isNotEmpty && maxCols >= 2) {
          for (final row in tableRows) {
            while (row.length < maxCols) {
              row.add('');
            }
          }
          return ParsedWordDoc(
            title: docTitle,
            tableData: tableRows,
            totalCharacters: text.length,
            totalWords: tableRows.length * maxCols,
            totalRows: tableRows.length,
          );
        }
      }

      // Standard text paragraphs
      final List<WordParagraph> paragraphs = [];
      for (final line in lines) {
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
        totalCharacters: text.length,
        totalWords: text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not read text document: $e');
    }
  }

  /// Parses XML files (.xml)
  static ParsedWordDoc _parseXmlBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      String text = '';
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }

      final lines = text.split(RegExp(r'\r?\n'));
      final List<WordParagraph> paragraphs = [];

      for (final line in lines) {
        final t = line.trim();
        if (t.isNotEmpty) {
          final isTag = t.startsWith('<') && t.endsWith('>');
          paragraphs.add(WordParagraph(
            fullText: t,
            isHeading: isTag && !t.startsWith('</') && t.length < 50,
            headingLevel: isTag ? 2 : 0,
            runs: [WordTextRun(text: t, isBold: isTag)],
          ));
        }
      }

      return ParsedWordDoc(
        title: docTitle,
        paragraphs: paragraphs,
        totalCharacters: text.length,
        totalWords: paragraphs.length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not read XML document: $e');
    }
  }

  /// Parses Legacy Excel (.xls, .xlw, .xlt, .xlsb)
  static ParsedWordDoc _parseLegacyXlsBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

      // Check if HTML table disguised as .xls
      final preview = latin1.decode(bytes.take(2048).toList()).toLowerCase();
      if (preview.contains('<table') || preview.contains('<tr')) {
        final fullStr = latin1.decode(bytes);
        final List<List<String>> rows = [];
        final trRegex = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true, caseSensitive: false);
        final tdRegex = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true, caseSensitive: false);

        int maxCols = 0;
        for (final tr in trRegex.allMatches(fullStr)) {
          final trBody = tr.group(1) ?? '';
          final List<String> cells = [];
          for (final td in tdRegex.allMatches(trBody)) {
            final text = td.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
            cells.add(_unescapeXml(text));
          }
          if (cells.any((c) => c.isNotEmpty)) {
            final capped = cells.take(12).toList();
            if (capped.length > maxCols) maxCols = capped.length;
            rows.add(capped);
          }
        }

        if (rows.isNotEmpty) {
          for (final row in rows) {
            while (row.length < maxCols) {
              row.add('');
            }
          }
          return ParsedWordDoc(
            title: docTitle,
            tableData: rows,
            totalCharacters: fullStr.length,
            totalWords: rows.length * maxCols,
            totalRows: rows.length,
          );
        }
      }

      // Check if CSV disguised as .xls
      if (preview.contains(',') && !preview.contains('\x00')) {
        return _parseCsvBytes(bytes, fileName);
      }

      // Binary extraction of printable cells
      final List<String> extracted = [];
      final StringBuffer cur = StringBuffer();
      int i = 0;
      while (i < bytes.length - 1) {
        final b1 = bytes[i];
        final b2 = bytes[i + 1];
        if (b2 == 0 && ((b1 >= 32 && b1 <= 126) || b1 == 10 || b1 == 9)) {
          cur.writeCharCode(b1);
          i += 2;
        } else {
          if (cur.length >= 2) extracted.add(cur.toString());
          cur.clear();
          i++;
        }
      }
      if (cur.length >= 2) extracted.add(cur.toString());

      final cleanStrings = extracted.where((s) {
        final l = s.toLowerCase();
        return !l.contains('workbook') &&
            !l.contains('worksheet') &&
            !l.contains('compobj') &&
            !l.contains('microsoft excel') &&
            s.trim().isNotEmpty;
      }).toList();

      final List<List<String>> tableRows = [];
      List<String> curRow = [];
      for (final s in cleanStrings) {
        curRow.add(s.trim());
        if (curRow.length >= 5) {
          tableRows.add(List.from(curRow));
          curRow.clear();
        }
      }
      if (curRow.isNotEmpty) tableRows.add(curRow);

      return ParsedWordDoc(
        title: docTitle,
        tableData: tableRows.isNotEmpty ? tableRows : null,
        paragraphs: tableRows.isEmpty
            ? cleanStrings.map((s) => WordParagraph(fullText: s, runs: [WordTextRun(text: s)])).toList()
            : const [],
        totalCharacters: bytes.length,
        totalWords: cleanStrings.length,
        totalRows: tableRows.length,
      );
    } catch (e) {
      return _fallbackDoc(fileName, 'Could not parse Excel document: $e');
    }
  }

  /// Parses DOC (Legacy binary CFBF or RTF format)
  static ParsedWordDoc _parseDocBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

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
    );
  }

  /// Converts one or multiple Word documents, spreadsheets, or data files into a polished vector PDF
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
            : 'DocumentBatch_Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}');

    final wordBlue = PdfColor.fromInt(0xFF185ABD);
    final excelGreen = PdfColor.fromInt(0xFF107C41);
    final accentDark = PdfColor.fromInt(0xFF0F172A);

    for (int docIdx = 0; docIdx < items.length; docIdx++) {
      final item = items[docIdx];
      final parsed = await parseWordFile(item.path);

      final isSpreadsheet = item.isSpreadsheet;
      final badgeColor = isSpreadsheet
          ? excelGreen
          : (item.isText ? PdfColor.fromInt(0xFF4F46E5) : wordBlue);

      // MultiPage orientation: A4 (landscape if table has > 4 columns for readability)
      final bool useLandscape = isSpreadsheet &&
          parsed.tableData != null &&
          parsed.tableData!.isNotEmpty &&
          parsed.tableData!.first.length > 4;

      final pageFormat = useLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
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
                  'PDFDost Universal Document Engine',
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: badgeColor,
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
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: accentDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Source: ${item.name} (${item.formattedSize})  •  Format: ${item.formatLabel}${parsed.tableData != null ? '  •  Rows: ${parsed.totalRows}' : '  •  Words: ${parsed.totalWords}'}',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            // Table rendering for Spreadsheets, CSV, PRN
            if (parsed.tableData != null && parsed.tableData!.isNotEmpty) {
              final table = parsed.tableData!;
              final headers = table.first;
              final dataRows = table.length > 1 ? table.sublist(1) : <List<String>>[];

              widgets.add(
                pw.Table.fromTextArray(
                  headers: headers,
                  data: dataRows,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 8.5,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: badgeColor,
                  ),
                  rowDecoration: const pw.BoxDecoration(
                    color: PdfColors.white,
                  ),
                  oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8FAFC),
                  ),
                  cellStyle: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.black,
                  ),
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  border: pw.TableBorder.all(
                    color: PdfColor.fromInt(0xFFCBD5E1),
                    width: 0.5,
                  ),
                ),
              );
            } else if (parsed.paragraphs.isNotEmpty) {
              // Paragraph rendering for Word, Text, XML
              for (final p in parsed.paragraphs) {
                if (p.isHeading) {
                  final double fontSize = p.headingLevel == 1
                      ? 17
                      : (p.headingLevel == 2 ? 14 : 12);
                  widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
                      child: pw.Text(
                        p.fullText,
                        style: pw.TextStyle(
                          fontSize: fontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: p.headingLevel == 1 ? badgeColor : accentDark,
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
                      padding: const pw.EdgeInsets.only(bottom: 7),
                      child: pw.RichText(
                        text: pw.TextSpan(children: spans),
                      ),
                    ),
                  );
                }
              }
            } else {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 20),
                  child: pw.Text(
                    'No readable data extracted from ${item.name}.',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                  ),
                ),
              );
            }

            return widgets;
          },
        ),
      );
    }

    return await PdfEngine.saveDocumentInternal(pdf, outputName);
  }
}
