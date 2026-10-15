import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import 'pdf_engine.dart';

/// Represents an individual styled run of text within a paragraph
class WordTextRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrike;
  final double fontSize;
  final PdfColor? color;

  const WordTextRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrike = false,
    this.fontSize = 11.0,
    this.color,
  });
}

/// Abstract node for document elements (paragraphs, tables, images)
abstract class WordDocNode {}

/// Represents a paragraph with styling, alignment, headings, and bullet points
class WordParagraphNode extends WordDocNode {
  final List<WordTextRun> runs;
  final String fullText;
  final bool isHeading;
  final int headingLevel; // 1, 2, 3
  final String alignment; // 'left', 'center', 'right', 'justify'
  final bool isBullet;
  final int bulletIndent;
  final double spaceBefore;
  final double spaceAfter;
  final bool isPageBreak;

  WordParagraphNode({
    required this.runs,
    required this.fullText,
    this.isHeading = false,
    this.headingLevel = 0,
    this.alignment = 'left',
    this.isBullet = false,
    this.bulletIndent = 0,
    this.spaceBefore = 0,
    this.spaceAfter = 4,
    this.isPageBreak = false,
  });
}

/// Backward compatibility class for WordParagraph
class WordParagraph {
  final String fullText;
  final bool isHeading;
  final int headingLevel;
  final List<WordTextRun> runs;

  const WordParagraph({
    required this.fullText,
    this.isHeading = false,
    this.headingLevel = 0,
    this.runs = const [],
  });
}

/// Represents a table cell
class WordTableCellNode {
  final List<WordParagraphNode> paragraphs;
  final String text;
  final PdfColor? backgroundColor;
  final int colSpan;

  WordTableCellNode({
    required this.paragraphs,
    required this.text,
    this.backgroundColor,
    this.colSpan = 1,
  });
}

/// Represents a row in a table
class WordTableRowNode {
  final List<WordTableCellNode> cells;
  final bool isHeader;

  WordTableRowNode({
    required this.cells,
    this.isHeader = false,
  });
}

/// Represents a table element
class WordTableNode extends WordDocNode {
  final List<WordTableRowNode> rows;
  final int maxCols;

  WordTableNode({
    required this.rows,
    required this.maxCols,
  });
}

/// Represents an embedded image in the document
class WordImageNode extends WordDocNode {
  final Uint8List bytes;
  final double widthPt;
  final double heightPt;
  final String alignment;

  WordImageNode({
    required this.bytes,
    this.widthPt = 300,
    this.heightPt = 200,
    this.alignment = 'center',
  });
}

/// Structured document representation
class WordDocModel {
  final String title;
  final List<WordDocNode> nodes;
  final bool isLandscape;
  final double marginPt;
  final int totalCharacters;
  final int totalWords;

  WordDocModel({
    required this.title,
    required this.nodes,
    this.isLandscape = false,
    this.marginPt = 36.0,
    required this.totalCharacters,
    required this.totalWords,
  });
}

/// Backward compatibility class for ParsedWordDoc
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
        .replaceAll('&#39;', "'")
        .replaceAll('&#xA;', '\n')
        .replaceAll('&#xD;', '')
        .replaceAll('&#x9;', '    ');
  }

  /// Sanitizes Unicode characters so standard PDF fonts (e.g. Helvetica) never crash
  static String _sanitizeForPdf(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('„', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('‚', "'")
        .replaceAll('—', ' - ')
        .replaceAll('–', '-')
        .replaceAll('…', '...')
        .replaceAll('•', '*')
        .replaceAll('▪', '*')
        .replaceAll('▫', '*')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\u2011', '-')
        .replaceAll('™', '(TM)')
        .replaceAll('©', '(C)')
        .replaceAll('®', '(R)')
        .replaceAll('±', '+/-')
        .replaceAll('≠', '!=')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('×', 'x')
        .replaceAll('÷', '/')
        .replaceAll('°', ' deg')
        .replaceAll('\t', '    ');
  }

  /// Extracts raw byte content safely from ArchiveFile across archive package versions
  static Uint8List _getArchiveFileBytes(ArchiveFile f) {
    try {
      final dynamic content = f.content;
      if (content is Uint8List) {
        return content;
      } else if (content is List<int>) {
        return Uint8List.fromList(content);
      }
      final dynamic dyn = f;
      if (dyn.rawContent != null) {
        final dynamic rc = dyn.rawContent;
        if (rc is Uint8List) return rc;
        if (rc is List<int>) return Uint8List.fromList(rc);
      }
      return Uint8List(0);
    } catch (_) {
      return Uint8List(0);
    }
  }

  /// Parses any document into a high-fidelity WordDocModel
  static Future<WordDocModel> parseToDocModel(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return WordDocModel(
        title: 'Document',
        nodes: [],
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
      return _parseTextBytes(bytes, fileName);
    } else if (ext == 'xml') {
      return _parseXmlBytes(bytes, fileName);
    } else if (['xls', 'xlsb', 'xlw', 'xlt'].contains(ext)) {
      return _parseBinaryXlsBytes(bytes, fileName);
    } else if (ext == 'doc') {
      return _parseDocBytes(bytes, fileName);
    } else {
      return _parseTextBytes(bytes, fileName);
    }
  }

  /// Backward compatible parseWordFile method
  static Future<ParsedWordDoc> parseWordFile(String filePath) async {
    final model = await parseToDocModel(filePath);
    final List<WordParagraph> paragraphs = [];
    List<List<String>>? tableData;

    for (final node in model.nodes) {
      if (node is WordParagraphNode) {
        paragraphs.add(WordParagraph(
          fullText: node.fullText,
          isHeading: node.isHeading,
          headingLevel: node.headingLevel,
          runs: node.runs,
        ));
      } else if (node is WordTableNode && tableData == null) {
        tableData = [];
        for (final row in node.rows) {
          tableData.add(row.cells.map((c) => c.text).toList());
        }
      }
    }

    return ParsedWordDoc(
      title: model.title,
      paragraphs: paragraphs,
      tableData: tableData,
      totalCharacters: model.totalCharacters,
      totalWords: model.totalWords,
      isTable: tableData != null && tableData.isNotEmpty,
    );
  }

  /// 1. DOCX Parser with Full Format, Table, and Image Extraction
  static WordDocModel _parseDocxBytes(Uint8List bytes, String fileName) {
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
        return _fallbackModel(fileName, 'Document XML structure not found in DOCX archive.');
      }

      final content = _getArchiveFileBytes(docXmlFile);
      final xml = utf8.decode(content, allowMalformed: true);

      // Parse image relationships from word/_rels/document.xml.rels
      final Map<String, String> relIdToMediaPath = {};
      for (final f in archive.files) {
        if (f.name == 'word/_rels/document.xml.rels' || f.name.endsWith('/document.xml.rels')) {
          final relsBytes = _getArchiveFileBytes(f);
          final relsXml = utf8.decode(relsBytes, allowMalformed: true);
          final relRegex = RegExp(r'<Relationship\s+([^>]+)/>');
          final idRegex = RegExp(r'Id="([^"]+)"');
          final targetRegex = RegExp(r'Target="([^"]+)"');
          final typeRegex = RegExp(r'Type="([^"]+)"');

          for (final m in relRegex.allMatches(relsXml)) {
            final attrs = m.group(1) ?? '';
            final idM = idRegex.firstMatch(attrs);
            final targetM = targetRegex.firstMatch(attrs);
            final typeM = typeRegex.firstMatch(attrs);

            if (idM != null && targetM != null) {
              final id = idM.group(1)!;
              final target = targetM.group(1)!;
              final type = typeM?.group(1) ?? '';
              if (type.contains('image')) {
                final cleanTarget = target.replaceAll('../', '');
                relIdToMediaPath[id] = cleanTarget.startsWith('word/') ? cleanTarget : 'word/$cleanTarget';
              }
            }
          }
          break;
        }
      }

      // Load image bytes
      final Map<String, Uint8List> imagesByRelId = {};
      if (relIdToMediaPath.isNotEmpty) {
        for (final f in archive.files) {
          for (final entry in relIdToMediaPath.entries) {
            final targetFileName = entry.value.split('/').last.toLowerCase();
            if (f.name == entry.value || f.name.toLowerCase().endsWith(targetFileName)) {
              final imgBytes = _getArchiveFileBytes(f);
              if (imgBytes.isNotEmpty) {
                imagesByRelId[entry.key] = imgBytes;
              }
            }
          }
        }
      }

      // Inspect section properties for orientation & margins
      bool isLandscape = false;
      double marginPt = 36.0;
      final sectPrRegex = RegExp(r'<w:sectPr[ >](.*?)</w:sectPr>', dotAll: true);
      final sectMatch = sectPrRegex.firstMatch(xml);
      if (sectMatch != null) {
        final sectXml = sectMatch.group(1) ?? '';
        final pgSzMatch = RegExp(r'<w:pgSz\s+([^>]+)/>').firstMatch(sectXml);
        if (pgSzMatch != null) {
          final attrs = pgSzMatch.group(1) ?? '';
          if (attrs.contains('orient="landscape"')) {
            isLandscape = true;
          } else {
            final wMatch = RegExp(r'w:w="(\d+)"').firstMatch(attrs);
            final hMatch = RegExp(r'w:h="(\d+)"').firstMatch(attrs);
            if (wMatch != null && hMatch != null) {
              final w = int.tryParse(wMatch.group(1)!) ?? 0;
              final h = int.tryParse(hMatch.group(1)!) ?? 0;
              if (w > h) isLandscape = true;
            }
          }
        }

        final pgMarMatch = RegExp(r'<w:pgMar\s+([^>]+)/>').firstMatch(sectXml);
        if (pgMarMatch != null) {
          final leftM = RegExp(r'w:left="(\d+)"').firstMatch(pgMarMatch.group(1) ?? '');
          if (leftM != null) {
            final dxa = int.tryParse(leftM.group(1)!) ?? 720;
            marginPt = (dxa / 20.0).clamp(18.0, 54.0);
          }
        }
      }

      // Sequential Body Parsing: preserve exact document order of paragraphs and tables
      final bodyRegex = RegExp(r'<w:body[ >](.*?)</w:body>', dotAll: true);
      final bodyMatch = bodyRegex.firstMatch(xml);
      final bodyContent = bodyMatch != null ? (bodyMatch.group(1) ?? xml) : xml;

      final List<WordDocNode> nodes = [];
      String detectedTitle = '';
      int totalChars = 0;
      int totalWords = 0;

      final topLevelRegex = RegExp(r'<(w:p|w:tbl)[ >](.*?)</\1>', dotAll: true);

      for (final match in topLevelRegex.allMatches(bodyContent)) {
        final tag = match.group(1);
        final innerXml = match.group(2) ?? '';

        if (tag == 'w:tbl') {
          final tableNode = _parseDocxTable(innerXml);
          if (tableNode != null && tableNode.rows.isNotEmpty) {
            nodes.add(tableNode);
          }
        } else if (tag == 'w:p') {
          final pNodes = _parseDocxParagraph(innerXml, imagesByRelId);
          for (final pNode in pNodes) {
            if (pNode is WordParagraphNode) {
              if (pNode.fullText.isNotEmpty) {
                totalChars += pNode.fullText.length;
                totalWords += pNode.fullText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                if (detectedTitle.isEmpty && (pNode.isHeading || pNode.headingLevel == 1)) {
                  detectedTitle = pNode.fullText;
                }
              }
            }
            nodes.add(pNode);
          }
        }
      }

      if (detectedTitle.isEmpty) {
        detectedTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      }

      return WordDocModel(
        title: detectedTitle,
        nodes: nodes,
        isLandscape: isLandscape,
        marginPt: marginPt,
        totalCharacters: totalChars,
        totalWords: totalWords,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not decode DOCX archive: $e');
    }
  }

  /// Parses a Word DOCX table into a structured WordTableNode
  static WordTableNode? _parseDocxTable(String tblInnerXml) {
    try {
      final List<WordTableRowNode> rows = [];
      final trRegex = RegExp(r'<w:tr[ >](.*?)</w:tr>', dotAll: true);
      final tcRegex = RegExp(r'<w:tc[ >](.*?)</w:tc>', dotAll: true);

      int maxCols = 0;

      for (final trMatch in trRegex.allMatches(tblInnerXml)) {
        final trXml = trMatch.group(1) ?? '';
        final bool isHeader = trXml.contains('<w:tblHeader/>') || trXml.contains('<w:tblHeader ');

        final List<WordTableCellNode> cells = [];
        for (final tcMatch in tcRegex.allMatches(trXml)) {
          final tcXml = tcMatch.group(1) ?? '';

          PdfColor? bgColor;
          final shdMatch = RegExp(r'<w:shd\s+[^>]*w:fill="([a-fA-F0-9]{6})"').firstMatch(tcXml);
          if (shdMatch != null) {
            final hex = shdMatch.group(1)!;
            if (hex.toLowerCase() != 'ffffff' && hex.toLowerCase() != 'auto') {
              bgColor = PdfColor.fromInt(0xFF000000 | int.parse(hex, radix: 16));
            }
          }

          int colSpan = 1;
          final gridSpanMatch = RegExp(r'<w:gridSpan\s+[^>]*w:val="(\d+)"').firstMatch(tcXml);
          if (gridSpanMatch != null) {
            colSpan = int.tryParse(gridSpanMatch.group(1)!) ?? 1;
          }

          final pRegex = RegExp(r'<w:p[ >](.*?)</w:p>', dotAll: true);
          final List<WordParagraphNode> cellParagraphs = [];
          final StringBuffer cellTextBuffer = StringBuffer();

          for (final pMatch in pRegex.allMatches(tcXml)) {
            final pNodes = _parseDocxParagraph(pMatch.group(1) ?? '', {});
            for (final pn in pNodes) {
              if (pn is WordParagraphNode) {
                cellParagraphs.add(pn);
                if (pn.fullText.isNotEmpty) {
                  if (cellTextBuffer.isNotEmpty) cellTextBuffer.write('\n');
                  cellTextBuffer.write(pn.fullText);
                }
              }
            }
          }

          cells.add(WordTableCellNode(
            paragraphs: cellParagraphs,
            text: cellTextBuffer.toString(),
            backgroundColor: bgColor,
            colSpan: colSpan,
          ));
        }

        if (cells.isNotEmpty) {
          int count = cells.fold(0, (sum, c) => sum + c.colSpan);
          if (count > maxCols) maxCols = count;
          rows.add(WordTableRowNode(cells: cells, isHeader: isHeader));
        }
      }

      if (rows.isEmpty) return null;
      return WordTableNode(rows: rows, maxCols: maxCols);
    } catch (_) {
      return null;
    }
  }

  /// Parses a Word DOCX paragraph with full formatting, styles, headings, bullets, and drawings
  static List<WordDocNode> _parseDocxParagraph(
    String pInnerXml,
    Map<String, Uint8List> imagesByRelId,
  ) {
    final List<WordDocNode> result = [];

    // Check page break before
    if (pInnerXml.contains('<w:pageBreakBefore/>')) {
      result.add(WordParagraphNode(runs: [], fullText: '', isPageBreak: true));
    }

    bool isHeading = false;
    int headingLevel = 0;
    String alignment = 'left';
    bool isBullet = false;
    int bulletIndent = 0;
    double spaceBefore = 0;
    double spaceAfter = 3;

    final pPrMatch = RegExp(r'<w:pPr[ >](.*?)</w:pPr>', dotAll: true).firstMatch(pInnerXml);
    if (pPrMatch != null) {
      final pPrXml = pPrMatch.group(1) ?? '';

      final styleMatch = RegExp(r'<w:pStyle\s+[^>]*w:val="([^"]+)"').firstMatch(pPrXml);
      if (styleMatch != null) {
        final val = styleMatch.group(1)?.toLowerCase() ?? '';
        if (val.contains('title')) {
          isHeading = true;
          headingLevel = 1;
        } else if (val.contains('subtitle')) {
          isHeading = true;
          headingLevel = 2;
        } else if (val.contains('heading1') || val.contains('heading 1')) {
          isHeading = true;
          headingLevel = 1;
        } else if (val.contains('heading2') || val.contains('heading 2')) {
          isHeading = true;
          headingLevel = 2;
        } else if (val.contains('heading3') || val.contains('heading 3')) {
          isHeading = true;
          headingLevel = 3;
        } else if (val.contains('heading')) {
          isHeading = true;
          headingLevel = 3;
        }
      }

      final jcMatch = RegExp(r'<w:jc\s+[^>]*w:val="([^"]+)"').firstMatch(pPrXml);
      if (jcMatch != null) {
        final jcVal = jcMatch.group(1)?.toLowerCase() ?? '';
        if (jcVal == 'center') {
          alignment = 'center';
        } else if (jcVal == 'right') {
          alignment = 'right';
        } else if (jcVal == 'both' || jcVal == 'justify' || jcVal == 'distribute') {
          alignment = 'justify';
        }
      }

      if (pPrXml.contains('<w:numPr')) {
        isBullet = true;
        final ilvlMatch = RegExp(r'<w:ilvl\s+[^>]*w:val="(\d+)"').firstMatch(pPrXml);
        if (ilvlMatch != null) {
          bulletIndent = int.tryParse(ilvlMatch.group(1)!) ?? 0;
        }
      }

      final spMatch = RegExp(r'<w:spacing\s+([^>]+)/>').firstMatch(pPrXml);
      if (spMatch != null) {
        final attrs = spMatch.group(1) ?? '';
        final bfMatch = RegExp(r'w:before="(\d+)"').firstMatch(attrs);
        final afMatch = RegExp(r'w:after="(\d+)"').firstMatch(attrs);
        if (bfMatch != null) {
          spaceBefore = (int.tryParse(bfMatch.group(1)!) ?? 0) / 20.0;
        }
        if (afMatch != null) {
          spaceAfter = (int.tryParse(afMatch.group(1)!) ?? 60) / 20.0;
        }
      }
    }

    final List<WordTextRun> runs = [];
    final StringBuffer pTextBuffer = StringBuffer();

    final rRegex = RegExp(r'<w:r[ >](.*?)</w:r>', dotAll: true);
    final tRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);

    for (final rMatch in rRegex.allMatches(pInnerXml)) {
      final rXml = rMatch.group(1) ?? '';

      // Check Drawing / Image in run
      if (imagesByRelId.isNotEmpty && (rXml.contains('<w:drawing') || rXml.contains('<w:pict'))) {
        final embedMatch = RegExp(r'(?:r:embed|r:id)="([^"]+)"').firstMatch(rXml);
        if (embedMatch != null) {
          final relId = embedMatch.group(1)!;
          final imgBytes = imagesByRelId[relId];
          if (imgBytes != null && imgBytes.isNotEmpty) {
            double wPt = 320;
            double hPt = 220;
            final extentMatch = RegExp(r'<wp:extent\s+[^>]*cx="(\d+)"\s+cy="(\d+)"').firstMatch(rXml);
            if (extentMatch != null) {
              final cx = int.tryParse(extentMatch.group(1)!) ?? 0;
              final cy = int.tryParse(extentMatch.group(2)!) ?? 0;
              if (cx > 0 && cy > 0) {
                wPt = (cx / 12700.0).clamp(50.0, 480.0);
                hPt = (cy / 12700.0).clamp(50.0, 360.0);
              }
            }

            if (runs.isNotEmpty && pTextBuffer.isNotEmpty) {
              result.add(WordParagraphNode(
                runs: List.from(runs),
                fullText: pTextBuffer.toString(),
                isHeading: isHeading,
                headingLevel: headingLevel,
                alignment: alignment,
                isBullet: isBullet,
                bulletIndent: bulletIndent,
                spaceBefore: spaceBefore,
                spaceAfter: spaceAfter,
              ));
              runs.clear();
              pTextBuffer.clear();
            }

            result.add(WordImageNode(
              bytes: imgBytes,
              widthPt: wPt,
              heightPt: hPt,
              alignment: alignment,
            ));
            continue;
          }
        }
      }

      // Page break in run
      if (rXml.contains('w:type="page"')) {
        if (runs.isNotEmpty && pTextBuffer.isNotEmpty) {
          result.add(WordParagraphNode(
            runs: List.from(runs),
            fullText: pTextBuffer.toString(),
            isHeading: isHeading,
            headingLevel: headingLevel,
            alignment: alignment,
            isBullet: isBullet,
            bulletIndent: bulletIndent,
          ));
          runs.clear();
          pTextBuffer.clear();
        }
        result.add(WordParagraphNode(runs: [], fullText: '', isPageBreak: true));
        continue;
      }

      final bool isBold = rXml.contains('<w:b') &&
          !rXml.contains('<w:b w:val="0"') &&
          !rXml.contains('<w:b w:val="false"');
      final bool isItalic = rXml.contains('<w:i') &&
          !rXml.contains('<w:i w:val="0"') &&
          !rXml.contains('<w:i w:val="false"');
      final bool isUnderline = rXml.contains('<w:u ') || rXml.contains('<w:u/>');
      final bool isStrike = rXml.contains('<w:strike');

      double fontSize = isHeading
          ? (headingLevel == 1 ? 17.0 : (headingLevel == 2 ? 14.0 : 12.0))
          : 11.0;
      final szMatch = RegExp(r'<w:sz\s+[^>]*w:val="(\d+)"').firstMatch(rXml);
      if (szMatch != null) {
        final halfPt = int.tryParse(szMatch.group(1)!) ?? 22;
        fontSize = (halfPt / 2.0).clamp(8.0, 32.0);
      }

      PdfColor? color;
      final colorMatch = RegExp(r'<w:color\s+[^>]*w:val="([a-fA-F0-9]{6})"').firstMatch(rXml);
      if (colorMatch != null) {
        final hex = colorMatch.group(1)!;
        if (hex.toLowerCase() != '000000' && hex.toLowerCase() != 'auto') {
          color = PdfColor.fromInt(0xFF000000 | int.parse(hex, radix: 16));
        }
      }

      final StringBuffer rBuffer = StringBuffer();
      for (final tMatch in tRegex.allMatches(rXml)) {
        final rawText = tMatch.group(1) ?? '';
        rBuffer.write(_sanitizeForPdf(_unescapeXml(rawText)));
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
          isStrike: isStrike,
          fontSize: fontSize,
          color: color,
        ));
        pTextBuffer.write(runText);
      }
    }

    if (runs.isNotEmpty || pTextBuffer.isNotEmpty) {
      result.add(WordParagraphNode(
        runs: runs,
        fullText: pTextBuffer.toString(),
        isHeading: isHeading,
        headingLevel: headingLevel,
        alignment: alignment,
        isBullet: isBullet,
        bulletIndent: bulletIndent,
        spaceBefore: spaceBefore,
        spaceAfter: spaceAfter,
      ));
    }

    return result;
  }

  /// 2. XLSX / XLSM / XLTX Parser
  static WordDocModel _parseXlsxBytes(Uint8List bytes, String fileName) {
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
        final sstBytes = _getArchiveFileBytes(sstFile);
        final sstXml = utf8.decode(sstBytes, allowMalformed: true);
        final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
        final tRegex = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
        for (final siMatch in siRegex.allMatches(sstXml)) {
          final siContent = siMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final tMatch in tRegex.allMatches(siContent)) {
            sb.write(_sanitizeForPdf(_unescapeXml(tMatch.group(1) ?? '')));
          }
          sharedStrings.add(sb.toString());
        }
      }

      // First worksheet
      ArchiveFile? sheetFile;
      for (final f in archive.files) {
        if (f.name == 'xl/worksheets/sheet1.xml' || f.name.endsWith('/sheet1.xml')) {
          sheetFile = f;
          break;
        }
      }
      sheetFile ??= archive.files.firstWhere(
        (f) => f.name.contains('sheet') && f.name.endsWith('.xml'),
        orElse: () => archive.files.first,
      );

      final sheetBytes = _getArchiveFileBytes(sheetFile);
      final sheetXml = utf8.decode(sheetBytes, allowMalformed: true);

      final rowRegex = RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true);
      final cellRegex = RegExp(r'<c\s+([^>]*?)>(.*?)</c>', dotAll: true);
      final vRegex = RegExp(r'<v>(.*?)</v>');
      final tInlineRegex = RegExp(r'<t[^>]*>(.*?)</t>');

      final List<WordTableRowNode> tableRows = [];
      int maxCols = 0;
      bool isFirstRow = true;

      for (final rowMatch in rowRegex.allMatches(sheetXml)) {
        final rowXml = rowMatch.group(1) ?? '';
        final List<WordTableCellNode> cells = [];

        for (final cMatch in cellRegex.allMatches(rowXml)) {
          final cAttrs = cMatch.group(1) ?? '';
          final cInner = cMatch.group(2) ?? '';
          final isString = cAttrs.contains('t="s"');
          final isInlineStr = cAttrs.contains('t="inlineStr"');

          String cellVal = '';
          if (isString) {
            final vMatch = vRegex.firstMatch(cInner);
            if (vMatch != null) {
              final idx = int.tryParse(vMatch.group(1) ?? '');
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                cellVal = sharedStrings[idx];
              }
            }
          } else if (isInlineStr) {
            final tMatch = tInlineRegex.firstMatch(cInner);
            if (tMatch != null) {
              cellVal = _sanitizeForPdf(_unescapeXml(tMatch.group(1) ?? ''));
            }
          } else {
            final vMatch = vRegex.firstMatch(cInner);
            if (vMatch != null) {
              cellVal = vMatch.group(1)?.trim() ?? '';
            }
          }

          cells.add(WordTableCellNode(
            paragraphs: [
              WordParagraphNode(
                runs: [WordTextRun(text: cellVal, isBold: isFirstRow)],
                fullText: cellVal,
              ),
            ],
            text: cellVal,
          ));
        }

        if (cells.any((c) => c.text.isNotEmpty)) {
          if (cells.length > maxCols) maxCols = cells.length;
          tableRows.add(WordTableRowNode(cells: cells, isHeader: isFirstRow));
          isFirstRow = false;
        }
      }

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final List<WordDocNode> nodes = [];
      if (tableRows.isNotEmpty) {
        nodes.add(WordTableNode(rows: tableRows, maxCols: maxCols));
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: maxCols > 4,
        marginPt: 24.0,
        totalCharacters: tableRows.fold(0, (s, r) => s + r.cells.fold(0, (cs, c) => cs + c.text.length)),
        totalWords: tableRows.length * maxCols,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not decode XLSX archive: $e');
    }
  }

  /// 3. ODS (OpenDocument Spreadsheet) Parser
  static WordDocModel _parseOdsBytes(Uint8List bytes, String fileName) {
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
        return _fallbackModel(fileName, 'content.xml not found in ODS archive.');
      }

      final contentBytes = _getArchiveFileBytes(contentFile);
      final xml = utf8.decode(contentBytes, allowMalformed: true);

      final rowRegex = RegExp(r'<table:table-row[^>]*>(.*?)</table:table-row>', dotAll: true);
      final cellRegex = RegExp(r'<table:table-cell[^>]*>(.*?)</table:table-cell>', dotAll: true);
      final pRegex = RegExp(r'<text:p[^>]*>(.*?)</text:p>', dotAll: true);

      final List<WordTableRowNode> tableRows = [];
      int maxCols = 0;
      bool isFirst = true;

      for (final rowMatch in rowRegex.allMatches(xml)) {
        final rowXml = rowMatch.group(1) ?? '';
        final List<WordTableCellNode> cells = [];

        for (final cellMatch in cellRegex.allMatches(rowXml)) {
          final cellXml = cellMatch.group(1) ?? '';
          final StringBuffer sb = StringBuffer();
          for (final pm in pRegex.allMatches(cellXml)) {
            sb.write(_sanitizeForPdf(_unescapeXml(pm.group(1) ?? '')));
          }
          final val = sb.toString().trim();
          cells.add(WordTableCellNode(
            paragraphs: [WordParagraphNode(runs: [WordTextRun(text: val, isBold: isFirst)], fullText: val)],
            text: val,
          ));
        }

        if (cells.any((c) => c.text.isNotEmpty)) {
          if (cells.length > maxCols) maxCols = cells.length;
          tableRows.add(WordTableRowNode(cells: cells, isHeader: isFirst));
          isFirst = false;
        }
      }

      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final List<WordDocNode> nodes = [];
      if (tableRows.isNotEmpty) {
        nodes.add(WordTableNode(rows: tableRows, maxCols: maxCols));
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: maxCols > 4,
        marginPt: 24.0,
        totalCharacters: tableRows.fold(0, (s, r) => s + r.cells.fold(0, (cs, c) => cs + c.text.length)),
        totalWords: tableRows.length * maxCols,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not decode ODS archive: $e');
    }
  }

  /// 4. CSV Parser
  static WordDocModel _parseCsvBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final content = _sanitizeForPdf(utf8.decode(bytes, allowMalformed: true));
      final rawLines = content.split(RegExp(r'\r?\n'));

      final delimiter = rawLines.isNotEmpty && rawLines[0].contains('\t') ? '\t' : ',';
      final List<WordTableRowNode> tableRows = [];
      int maxCols = 0;
      bool isFirst = true;

      for (final line in rawLines) {
        if (line.trim().isEmpty) continue;
        final cells = _splitCsvLine(line, delimiter).map((val) {
          return WordTableCellNode(
            paragraphs: [WordParagraphNode(runs: [WordTextRun(text: val, isBold: isFirst)], fullText: val)],
            text: val,
          );
        }).toList();

        if (cells.length > maxCols) maxCols = cells.length;
        tableRows.add(WordTableRowNode(cells: cells, isHeader: isFirst));
        isFirst = false;
      }

      final List<WordDocNode> nodes = [];
      if (tableRows.isNotEmpty) {
        nodes.add(WordTableNode(rows: tableRows, maxCols: maxCols));
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: maxCols > 4,
        marginPt: 24.0,
        totalCharacters: content.length,
        totalWords: content.split(RegExp(r'\s+')).length,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not parse CSV: $e');
    }
  }

  /// 5. Plain Text (.txt, .prn) Parser
  static WordDocModel _parseTextBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final content = _sanitizeForPdf(utf8.decode(bytes, allowMalformed: true));
      final rawLines = content.split(RegExp(r'\r?\n'));

      final List<WordDocNode> nodes = [];
      for (final line in rawLines) {
        final t = line.trim();
        if (t.isNotEmpty) {
          nodes.add(WordParagraphNode(
            runs: [WordTextRun(text: line)],
            fullText: line,
            spaceAfter: 2,
          ));
        } else {
          nodes.add(WordParagraphNode(runs: [], fullText: '', spaceAfter: 6));
        }
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: false,
        marginPt: 36.0,
        totalCharacters: content.length,
        totalWords: content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not parse text document: $e');
    }
  }

  /// 6. XML Parser
  static WordDocModel _parseXmlBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final xml = utf8.decode(bytes, allowMalformed: true);

      // Check if Excel 2003 XML SpreadsheetML
      if (xml.contains('<Workbook') && xml.contains('<Row')) {
        final rowRegex = RegExp(r'<Row[^>]*>(.*?)</Row>', dotAll: true);
        final cellRegex = RegExp(r'<Cell[^>]*>.*?<Data[^>]*>(.*?)</Data>.*?</Cell>', dotAll: true);
        final List<WordTableRowNode> tableRows = [];
        int maxCols = 0;
        bool isFirst = true;

        for (final rMatch in rowRegex.allMatches(xml)) {
          final rXml = rMatch.group(1) ?? '';
          final List<WordTableCellNode> cells = [];
          for (final cMatch in cellRegex.allMatches(rXml)) {
            final val = _sanitizeForPdf(_unescapeXml(cMatch.group(1) ?? '').trim());
            cells.add(WordTableCellNode(
              paragraphs: [WordParagraphNode(runs: [WordTextRun(text: val, isBold: isFirst)], fullText: val)],
              text: val,
            ));
          }
          if (cells.any((c) => c.text.isNotEmpty)) {
            if (cells.length > maxCols) maxCols = cells.length;
            tableRows.add(WordTableRowNode(cells: cells, isHeader: isFirst));
            isFirst = false;
          }
        }

        if (tableRows.isNotEmpty) {
          return WordDocModel(
            title: docTitle,
            nodes: [WordTableNode(rows: tableRows, maxCols: maxCols)],
            isLandscape: maxCols > 4,
            marginPt: 24.0,
            totalCharacters: xml.length,
            totalWords: tableRows.length * maxCols,
          );
        }
      }

      // Standard XML
      final List<WordDocNode> nodes = [];
      final tagRegex = RegExp(r'<([a-zA-Z0-9_\-]+)([^>]*)>(.*?)</\1>', dotAll: true);
      for (final m in tagRegex.allMatches(xml)) {
        final tag = m.group(1) ?? '';
        final content = _sanitizeForPdf(_unescapeXml(m.group(3) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim());
        if (content.isNotEmpty && !content.contains('\n')) {
          nodes.add(WordParagraphNode(
            runs: [
              WordTextRun(text: '$tag: ', isBold: true),
              WordTextRun(text: content),
            ],
            fullText: '$tag: $content',
          ));
        }
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: false,
        marginPt: 36.0,
        totalCharacters: xml.length,
        totalWords: nodes.length * 4,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not parse XML document: $e');
    }
  }

  /// 7. Binary XLS Parser
  static WordDocModel _parseBinaryXlsBytes(Uint8List bytes, String fileName) {
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
      }).map((s) => _sanitizeForPdf(s.trim())).toList();

      final List<WordTableRowNode> tableRows = [];
      if (cleanStrings.length >= 4) {
        int cols = 4;
        if (cleanStrings.length % 3 == 0 && cleanStrings.length % 4 != 0) cols = 3;
        for (int idx = 0; idx < cleanStrings.length; idx += cols) {
          final row = cleanStrings.skip(idx).take(cols).toList();
          final cells = row.map((val) => WordTableCellNode(
            paragraphs: [WordParagraphNode(runs: [WordTextRun(text: val)], fullText: val)],
            text: val,
          )).toList();
          tableRows.add(WordTableRowNode(cells: cells, isHeader: idx == 0));
        }
      }

      final List<WordDocNode> nodes = [];
      if (tableRows.isNotEmpty) {
        nodes.add(WordTableNode(rows: tableRows, maxCols: 4));
      } else {
        for (final s in cleanStrings) {
          nodes.add(WordParagraphNode(runs: [WordTextRun(text: s)], fullText: s));
        }
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: true,
        marginPt: 24.0,
        totalCharacters: cleanStrings.fold(0, (sum, s) => sum + s.length),
        totalWords: cleanStrings.length * 2,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not parse Excel binary file: $e');
    }
  }

  /// 8. Legacy Word DOC (RTF or Binary CFBF) Parser
  static WordDocModel _parseDocBytes(Uint8List bytes, String fileName) {
    try {
      final docTitle = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

      // RTF format check
      if (bytes.length >= 5 &&
          bytes[0] == 0x7B &&
          bytes[1] == 0x5C &&
          bytes[2] == 0x72 &&
          bytes[3] == 0x74 &&
          bytes[4] == 0x66) {
        final rtfStr = latin1.decode(bytes);
        final cleanText = _sanitizeForPdf(rtfStr
            .replaceAll(RegExp(r'\\[a-zA-Z]+(-?\d+)? ?'), '')
            .replaceAll(RegExp(r'[{}]'), '')
            .trim());
        final rawLines = cleanText.split(RegExp(r'\r?\n+'));
        final List<WordDocNode> nodes = [];
        for (final line in rawLines) {
          final t = line.trim();
          if (t.isNotEmpty) {
            nodes.add(WordParagraphNode(
              runs: [WordTextRun(text: t)],
              fullText: t,
            ));
          }
        }
        return WordDocModel(
          title: docTitle,
          nodes: nodes,
          isLandscape: false,
          marginPt: 36.0,
          totalCharacters: cleanText.length,
          totalWords: cleanText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length,
        );
      }

      // Binary CFBF (Word 97-2004)
      final List<WordDocNode> nodes = [];
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
        final t = _sanitizeForPdf(s.trim());
        if (t.isNotEmpty) {
          nodes.add(WordParagraphNode(
            runs: [WordTextRun(text: t)],
            fullText: t,
          ));
        }
      }

      return WordDocModel(
        title: docTitle,
        nodes: nodes,
        isLandscape: false,
        marginPt: 36.0,
        totalCharacters: filteredStrings.fold(0, (s, w) => s + w.length),
        totalWords: filteredStrings.length,
      );
    } catch (e) {
      return _fallbackModel(fileName, 'Could not parse binary DOC file: $e');
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

  static WordDocModel _fallbackModel(String fileName, String note) {
    final title = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    return WordDocModel(
      title: title,
      nodes: [
        WordParagraphNode(
          runs: [WordTextRun(text: title, isBold: true, fontSize: 16)],
          fullText: title,
          isHeading: true,
          headingLevel: 1,
        ),
        WordParagraphNode(
          runs: [WordTextRun(text: 'Document: $fileName')],
          fullText: 'Document: $fileName',
        ),
        WordParagraphNode(
          runs: [WordTextRun(text: note)],
          fullText: note,
        ),
      ],
      totalCharacters: title.length,
      totalWords: 5,
    );
  }

  /// Converts one or multiple Word/Spreadsheet/Data documents into a high-fidelity PDF
  static Future<PdfEngineResult> convertWordFilesToPdf({
    required List<SelectedWordItem> items,
    String? customName,
    String orientation = 'Auto', // 'Auto', 'Portrait', 'Landscape'
    double pageMargin = 36.0,
    bool addPageNumbers = true,
  }) async {
    if (items.isEmpty) {
      throw Exception('No files provided for conversion');
    }

    final pdf = pw.Document();

    // Load Unicode fonts with timeout; gracefully fall back to standard fonts
    pw.Font? regularFont;
    pw.Font? boldFont;
    pw.Font? italicFont;
    pw.Font? boldItalicFont;
    try {
      regularFont = await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 2));
      boldFont = await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 2));
      italicFont = await PdfGoogleFonts.robotoItalic().timeout(const Duration(seconds: 2));
      boldItalicFont = await PdfGoogleFonts.robotoBoldItalic().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Safe fallback: standard Helvetica fonts with Unicode sanitized characters
    }

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      italic: italicFont,
      boldItalic: boldItalicFont,
    );

    final primaryName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : items.first.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');

    final String outputName = customName?.trim().isNotEmpty == true
        ? customName!.trim()
        : (items.length == 1
            ? '${primaryName}_converted'
            : 'ConvertedDocs_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}');

    final darkTextColor = PdfColor.fromInt(0xFF1E293B);
    final heading1Color = PdfColor.fromInt(0xFF0F172A);
    final heading2Color = PdfColor.fromInt(0xFF1E3A8A);

    for (int docIdx = 0; docIdx < items.length; docIdx++) {
      final item = items[docIdx];
      final model = await parseToDocModel(item.path);

      PdfPageFormat pageFormat;
      if (orientation == 'Landscape') {
        pageFormat = PdfPageFormat.a4.landscape;
      } else if (orientation == 'Portrait') {
        pageFormat = PdfPageFormat.a4;
      } else {
        pageFormat = model.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
      }

      final double appliedMargin = pageMargin;

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(appliedMargin),
          maxPages: 1000,
          footer: addPageNumbers
              ? (ctx) => pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Text(
                      'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8.5),
                    ),
                  )
              : null,
          build: (pw.Context ctx) {
            final List<pw.Widget> widgets = [];

            if (model.nodes.isEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 24),
                  child: pw.Text(
                    'No readable text or content found in ${item.name}.',
                    style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
                  ),
                ),
              );
              return widgets;
            }

            for (final node in model.nodes) {
              if (node is WordParagraphNode) {
                if (node.isPageBreak) {
                  widgets.add(pw.NewPage());
                  continue;
                }

                if (node.fullText.trim().isEmpty) {
                  widgets.add(pw.SizedBox(height: 8));
                  continue;
                }

                pw.TextAlign textAlign;
                switch (node.alignment) {
                  case 'center':
                    textAlign = pw.TextAlign.center;
                    break;
                  case 'right':
                    textAlign = pw.TextAlign.right;
                    break;
                  case 'justify':
                    textAlign = pw.TextAlign.justify;
                    break;
                  default:
                    textAlign = pw.TextAlign.left;
                }

                if (node.isHeading) {
                  final double fontSize = node.headingLevel == 1
                      ? 18.0
                      : (node.headingLevel == 2 ? 15.0 : 13.0);
                  final color = node.headingLevel == 1 ? heading1Color : heading2Color;

                  widgets.add(
                    pw.Padding(
                      padding: pw.EdgeInsets.only(
                        top: node.spaceBefore > 0 ? node.spaceBefore : 12,
                        bottom: node.spaceAfter > 0 ? node.spaceAfter : 4,
                      ),
                      child: pw.Text(
                        node.fullText,
                        textAlign: textAlign,
                        style: pw.TextStyle(
                          fontSize: fontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  );
                } else if (node.isBullet) {
                  final spans = node.runs.map((r) {
                    return pw.TextSpan(
                      text: r.text,
                      style: pw.TextStyle(
                        fontWeight: r.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        fontStyle: r.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                        decoration: r.isUnderline ? pw.TextDecoration.underline : null,
                        fontSize: r.fontSize,
                        color: r.color ?? darkTextColor,
                        lineSpacing: 2.0,
                      ),
                    );
                  }).toList();

                  widgets.add(
                    pw.Padding(
                      padding: pw.EdgeInsets.only(
                        left: (node.bulletIndent * 14.0) + 4,
                        top: node.spaceBefore,
                        bottom: node.spaceAfter,
                      ),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('*  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.Expanded(
                            child: pw.RichText(
                              textAlign: textAlign,
                              text: pw.TextSpan(children: spans),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  final spans = node.runs.map((r) {
                    return pw.TextSpan(
                      text: r.text,
                      style: pw.TextStyle(
                        fontWeight: r.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                        fontStyle: r.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                        decoration: r.isUnderline ? pw.TextDecoration.underline : null,
                        fontSize: r.fontSize,
                        color: r.color ?? darkTextColor,
                        lineSpacing: 2.0,
                      ),
                    );
                  }).toList();

                  widgets.add(
                    pw.Padding(
                      padding: pw.EdgeInsets.only(
                        top: node.spaceBefore,
                        bottom: node.spaceAfter,
                      ),
                      child: pw.RichText(
                        textAlign: textAlign,
                        text: pw.TextSpan(children: spans),
                      ),
                    ),
                  );
                }
              } else if (node is WordTableNode) {
                if (node.rows.isNotEmpty) {
                  widgets.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                        children: node.rows.map((row) {
                          return pw.TableRow(
                            decoration: row.isHeader
                                ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9))
                                : null,
                            children: row.cells.map((cell) {
                              return pw.Container(
                                color: cell.backgroundColor,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                child: pw.Text(
                                  cell.text,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: row.isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                                    color: darkTextColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }
              } else if (node is WordImageNode) {
                try {
                  final memImg = pw.MemoryImage(node.bytes);
                  pw.Alignment align = pw.Alignment.center;
                  if (node.alignment == 'left') align = pw.Alignment.centerLeft;
                  if (node.alignment == 'right') align = pw.Alignment.centerRight;

                  widgets.add(
                    pw.Container(
                      alignment: align,
                      padding: const pw.EdgeInsets.symmetric(vertical: 8),
                      child: pw.Image(
                        memImg,
                        width: node.widthPt.clamp(50.0, 480.0),
                        height: node.heightPt.clamp(50.0, 360.0),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  );
                } catch (_) {
                  // Skip invalid/unsupported image encoding gracefully
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
