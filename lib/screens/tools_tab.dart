import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/tool_badge_icon.dart';
import 'merge_pdf_screen.dart';
import 'split_pdf_screen.dart';

class ToolsTab extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final VoidCallback onTriggerImageToPdf;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const ToolsTab({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onTriggerImageToPdf,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> {
  bool _isProcessing = false;
  String _processingMessage = '';

  static const List<ToolDefinition> _toolsList = [
    ToolDefinition(type: PdfToolType.mergePdf, title: 'Merge PDF', subtitle: 'Combine multiple PDFs into one'),
    ToolDefinition(type: PdfToolType.splitPdf, title: 'Split PDF', subtitle: 'Extract pages from document'),
    ToolDefinition(type: PdfToolType.compressPdf, title: 'Compress PDF', subtitle: 'Reduce file size while preserving quality'),
    ToolDefinition(type: PdfToolType.pdfToWord, title: 'PDF to Word', subtitle: 'Convert PDF into DOC document'),
    ToolDefinition(type: PdfToolType.pdfToPowerPoint, title: 'PDF to PowerPoint', subtitle: 'Convert pages into presentation slides'),
    ToolDefinition(type: PdfToolType.pdfToExcel, title: 'PDF to Excel', subtitle: 'Extract data to spreadsheet'),
    ToolDefinition(type: PdfToolType.wordToPdf, title: 'Word to PDF', subtitle: 'Make PDF from document text'),
    ToolDefinition(type: PdfToolType.powerPointToPdf, title: 'PowerPoint to PDF', subtitle: 'Create presentation PDF'),
    ToolDefinition(type: PdfToolType.excelToPdf, title: 'Excel to PDF', subtitle: 'Convert table to PDF'),
    ToolDefinition(type: PdfToolType.editPdf, title: 'Edit PDF', subtitle: 'Add text, signatures, and notes'),
    ToolDefinition(type: PdfToolType.pdfToJpg, title: 'PDF to JPG', subtitle: 'Export pages to images'),
    ToolDefinition(type: PdfToolType.imageToPdf, title: 'Image to PDF', subtitle: 'Convert pictures into PDF'),
    ToolDefinition(type: PdfToolType.pageNumbers, title: 'Page Numbers', subtitle: 'Add numbers to all pages'),
    ToolDefinition(type: PdfToolType.watermark, title: 'Watermark', subtitle: 'Stamp text or logo on PDF'),
    ToolDefinition(type: PdfToolType.rotatePdf, title: 'Rotate PDF', subtitle: 'Rotate document pages'),
  ];

  void _handleToolTap(ToolDefinition tool) {
    switch (tool.type) {
      case PdfToolType.imageToPdf:
        widget.onTriggerImageToPdf();
        break;
      case PdfToolType.mergePdf:
        _openMergePdfScreen();
        break;
      case PdfToolType.splitPdf:
        _openSplitPdfScreen();
        break;
      case PdfToolType.compressPdf:
        _showCompressPdfDialog();
        break;
      case PdfToolType.pdfToWord:
        _showPdfToWordDialog();
        break;
      case PdfToolType.pdfToPowerPoint:
        _showPdfToPowerPointDialog();
        break;
      case PdfToolType.pdfToExcel:
        _showPdfToExcelDialog();
        break;
      case PdfToolType.wordToPdf:
        _showWordToPdfDialog();
        break;
      case PdfToolType.powerPointToPdf:
        _showPowerPointToPdfDialog();
        break;
      case PdfToolType.excelToPdf:
        _showExcelToPdfDialog();
        break;
      case PdfToolType.editPdf:
        _showEditPdfDialog();
        break;
      case PdfToolType.pdfToJpg:
        _showPdfToJpgDialog();
        break;
      case PdfToolType.pageNumbers:
        _showPageNumbersDialog();
        break;
      case PdfToolType.watermark:
        _showWatermarkDialog();
        break;
      case PdfToolType.rotatePdf:
        _showRotatePdfDialog();
        break;
    }
  }

  // --- TOOL IMPLEMENTATIONS ---

  void _openMergePdfScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MergePdfScreen(
          historyItems: widget.historyItems,
          isDark: widget.isDark,
          onAddHistoryItem: widget.onAddHistoryItem,
          onDeleteHistoryItem: widget.onDeleteHistoryItem,
        ),
      ),
    );
  }

  void _openSplitPdfScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SplitPdfScreen(
          historyItems: widget.historyItems,
          isDark: widget.isDark,
          onAddHistoryItem: widget.onAddHistoryItem,
          onDeleteHistoryItem: widget.onDeleteHistoryItem,
        ),
      ),
    );
  }

  // 1. Merge PDF Dialog (Legacy/Fallback)
  void _showMergePdfDialog() {
    if (widget.historyItems.length < 2) {
      _showSnackbar('Need at least 2 saved PDF documents to merge. Convert or create PDFs first!');
      return;
    }

    final selected = List<bool>.filled(widget.historyItems.length, false);
    selected[0] = true;
    if (selected.length > 1) selected[1] = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Merge PDFs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select 2 or more documents to merge into a single PDF:'),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.historyItems.length,
                    itemBuilder: (c, i) => CheckboxListTile(
                      activeColor: const Color(0xFFE5322D),
                      value: selected[i],
                      title: Text(widget.historyItems[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${widget.historyItems[i].pages} pages'),
                      onChanged: (val) => setDialogState(() => selected[i] = val ?? false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
              onPressed: () async {
                final chosen = <HistoryItem>[];
                for (int i = 0; i < selected.length; i++) {
                  if (selected[i]) chosen.add(widget.historyItems[i]);
                }
                if (chosen.length < 2) {
                  _showSnackbar('Please select at least 2 files');
                  return;
                }
                Navigator.pop(ctx);
                _runAsyncProcess('Merging PDF documents...', () async {
                  final result = await PdfEngine.mergePdfs(
                    items: chosen,
                    docName: 'Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
                  );
                  _recordAndExport(result, 'Merge PDF');
                });
              },
              child: const Text('Merge Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Split PDF Dialog
  void _showSplitPdfDialog() {
    _pickSourceFile((source) {
      final startCtrl = TextEditingController(text: '1');
      final endCtrl = TextEditingController(text: '${source.pages}');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Split PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Source: ${source.name} (${source.pages} pages)'),
              const SizedBox(height: 16),
              const Text('Enter page range to extract:'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'From page', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'To page', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
              onPressed: () {
                final start = int.tryParse(startCtrl.text.trim()) ?? 1;
                final end = int.tryParse(endCtrl.text.trim()) ?? source.pages;
                Navigator.pop(ctx);
                _runAsyncProcess('Splitting PDF pages...', () async {
                  final result = await PdfEngine.splitPdf(
                    sourceItem: source,
                    startPage: start,
                    endPage: end,
                    docName: 'Split_${source.name.replaceAll('.pdf', '')}_p${start}_to_p$end',
                  );
                  _recordAndExport(result, 'Split PDF');
                });
              },
              child: const Text('Extract Pages', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  // 3. Compress PDF Dialog
  void _showCompressPdfDialog() {
    _pickSourceFile((source) {
      String selectedLevel = 'Recommended';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Compress PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${source.name} (${source.size})'),
                const SizedBox(height: 16),
                const Text('Choose compression level:'),
                RadioListTile<String>(
                  activeColor: const Color(0xFF10B981),
                  title: const Text('Extreme Compression'),
                  subtitle: const Text('Low quality, ~70% size reduction'),
                  value: 'Extreme',
                  groupValue: selectedLevel,
                  onChanged: (val) => setDialogState(() => selectedLevel = val!),
                ),
                RadioListTile<String>(
                  activeColor: const Color(0xFF10B981),
                  title: const Text('Recommended Compression'),
                  subtitle: const Text('Good quality, ~50% size reduction'),
                  value: 'Recommended',
                  groupValue: selectedLevel,
                  onChanged: (val) => setDialogState(() => selectedLevel = val!),
                ),
                RadioListTile<String>(
                  activeColor: const Color(0xFF10B981),
                  title: const Text('Low Compression'),
                  subtitle: const Text('High quality preservation, ~25% reduction'),
                  value: 'Low',
                  groupValue: selectedLevel,
                  onChanged: (val) => setDialogState(() => selectedLevel = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _runAsyncProcess('Optimizing and compressing PDF...', () async {
                    final result = await PdfEngine.compressPdf(
                      sourceItem: source,
                      levelName: selectedLevel,
                      docName: 'Compressed_${source.name.replaceAll('.pdf', '')}',
                    );
                    _recordAndExport(result, 'Compress PDF');
                  });
                },
                child: const Text('Compress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  // 4. PDF to Word
  void _showPdfToWordDialog() {
    _pickSourceFile((source) {
      _runAsyncProcess('Converting PDF to Word document...', () async {
        final docFile = await PdfEngine.pdfToWord(
          sourceItem: source,
          docName: 'Word_${source.name.replaceAll('.pdf', '')}',
        );

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Word Document Created!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_rounded, color: Color(0xFF2563EB), size: 48),
                  const SizedBox(height: 12),
                  Text('Saved: ${docFile.path.split('/').last}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Document content extracted and ready for Microsoft Word / Google Docs.'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles([XFile(docFile.path)], text: 'Word Document');
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  label: const Text('Share File', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      });
    });
  }

  // 5. PDF to PowerPoint
  void _showPdfToPowerPointDialog() {
    _pickSourceFile((source) {
      _runAsyncProcess('Converting PDF to Presentation slides...', () async {
        final result = await PdfEngine.pdfToPowerPoint(
          sourceItem: source,
          docName: 'Slides_${source.name.replaceAll('.pdf', '')}',
        );
        _recordAndExport(result, 'PDF to PowerPoint');
      });
    });
  }

  // 6. PDF to Excel
  void _showPdfToExcelDialog() {
    _pickSourceFile((source) {
      _runAsyncProcess('Extracting table data to Excel spreadsheet...', () async {
        final csvFile = await PdfEngine.pdfToExcel(
          sourceItem: source,
          docName: 'Spreadsheet_${source.name.replaceAll('.pdf', '')}',
        );

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Spreadsheet Exported!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A), size: 48),
                  const SizedBox(height: 12),
                  Text('Saved: ${csvFile.path.split('/').last}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Structured spreadsheet data compatible with Excel and Google Sheets.'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles([XFile(csvFile.path)], text: 'Excel Spreadsheet');
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  label: const Text('Share CSV', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      });
    });
  }

  // 7. Word to PDF Creator
  void _showWordToPdfDialog() {
    final titleCtrl = TextEditingController(text: 'Project Proposal');
    final authorCtrl = TextEditingController(text: 'PDFDost User');
    final contentCtrl = TextEditingController(
      text: 'This document was composed in PDFDost and compiled directly to a corporate-grade A4 PDF.\n\nKey Highlights:\n• High quality vector typography\n• Clean margin layouts\n• Instant sharing and printing support',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Word to PDF Creator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Document Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author Name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: contentCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Document Content', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () {
              Navigator.pop(ctx);
              _runAsyncProcess('Compiling Word document to PDF...', () async {
                final result = await PdfEngine.wordToPdf(
                  title: titleCtrl.text.trim(),
                  author: authorCtrl.text.trim(),
                  contentText: contentCtrl.text.trim(),
                  docName: 'WordDoc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
                );
                _recordAndExport(result, 'Word to PDF');
              });
            },
            child: const Text('Create PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 8. PowerPoint to PDF Creator
  void _showPowerPointToPdfDialog() {
    final titleCtrl = TextEditingController(text: 'Product Strategy Presentation');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('PowerPoint to PDF Creator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Presentation Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('Generates 4 presentation slides (Introduction, Strategy, Execution, Conclusion) in 16:9 landscape format.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              Navigator.pop(ctx);
              _runAsyncProcess('Rendering presentation slides...', () async {
                final result = await PdfEngine.powerPointToPdf(
                  presentationTitle: titleCtrl.text.trim(),
                  slideTopics: const [
                    'Executive Overview & Vision',
                    'Market Opportunity & Growth',
                    'Product Architecture & Roadmap',
                    'Summary & Next Milestones',
                  ],
                  docName: 'Presentation_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
                );
                _recordAndExport(result, 'PowerPoint to PDF');
              });
            },
            child: const Text('Generate Slides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 9. Excel to PDF Creator
  void _showExcelToPdfDialog() {
    final titleCtrl = TextEditingController(text: 'Monthly Financial Summary');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Excel to PDF Creator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Spreadsheet Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('Compiles a structured spreadsheet table with headers, borders, and rows into an executive landscape PDF.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            onPressed: () {
              Navigator.pop(ctx);
              _runAsyncProcess('Converting spreadsheet to PDF...', () async {
                final result = await PdfEngine.excelToPdf(
                  sheetTitle: titleCtrl.text.trim(),
                  tableData: const [
                    ['ID', 'Quarter', 'Department', 'Revenue', 'Status'],
                    ['#101', 'Q1 2026', 'Engineering', '\$145,000', 'Approved'],
                    ['#102', 'Q2 2026', 'Marketing', '\$98,500', 'Approved'],
                    ['#103', 'Q3 2026', 'Operations', '\$112,300', 'Pending'],
                    ['#104', 'Q4 2026', 'R&D Innovation', '\$230,000', 'Approved'],
                  ],
                  docName: 'ExcelTable_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
                );
                _recordAndExport(result, 'Excel to PDF');
              });
            },
            child: const Text('Generate Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 10. Edit PDF Dialog
  void _showEditPdfDialog() {
    _pickSourceFile((source) {
      final titleCtrl = TextEditingController(text: source.name.replaceAll('.pdf', ''));
      final authorCtrl = TextEditingController(text: 'Verified Reviewer');
      final noteCtrl = TextEditingController(text: 'Approved for final release');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit PDF Metadata', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: authorCtrl, decoration: const InputDecoration(labelText: 'Author / Editor', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Annotation Note', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB87295)),
              onPressed: () {
                Navigator.pop(ctx);
                _runAsyncProcess('Saving edited PDF...', () async {
                  final result = await PdfEngine.editPdf(
                    sourceItem: source,
                    newTitle: titleCtrl.text.trim(),
                    author: authorCtrl.text.trim(),
                    annotationNote: noteCtrl.text.trim(),
                    docName: 'Edited_${source.name.replaceAll('.pdf', '')}',
                  );
                  _recordAndExport(result, 'Edit PDF');
                });
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  // 11. PDF to JPG Dialog
  void _showPdfToJpgDialog() {
    _pickSourceFile((source) {
      _runAsyncProcess('Extracting pages to high-res JPG images...', () async {
        final imgFiles = await PdfEngine.pdfToJpg(sourceItem: source);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('JPG Images Extracted!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, color: Color(0xFFD4A836), size: 48),
                  const SizedBox(height: 12),
                  Text('${imgFiles.length} page image(s) extracted from ${source.name}'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4A836)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Share.shareXFiles(imgFiles.map((f) => XFile(f.path)).toList(), text: 'Extracted JPG Pages');
                  },
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  label: const Text('Share JPGs', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        }
      });
    });
  }

  // 12. Page Numbers Dialog
  void _showPageNumbersDialog() {
    _pickSourceFile((source) {
      String position = 'Bottom Center';
      String format = 'Page X of Y';

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Page Numbers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${source.name} (${source.pages} pages)'),
                const SizedBox(height: 16),
                const Text('Position:'),
                DropdownButton<String>(
                  value: position,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Bottom Center', child: Text('Bottom Center')),
                    DropdownMenuItem(value: 'Bottom Right', child: Text('Bottom Right')),
                    DropdownMenuItem(value: 'Top Right', child: Text('Top Right')),
                  ],
                  onChanged: (val) => setDialogState(() => position = val!),
                ),
                const SizedBox(height: 12),
                const Text('Format:'),
                DropdownButton<String>(
                  value: format,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Page X of Y', child: Text('Page 1 of 5')),
                    DropdownMenuItem(value: 'X / Y', child: Text('1 / 5')),
                    DropdownMenuItem(value: 'Page X', child: Text('Page 1')),
                  ],
                  onChanged: (val) => setDialogState(() => format = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B7EBD)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _runAsyncProcess('Adding page numbers...', () async {
                    final result = await PdfEngine.addPageNumbers(
                      sourceItem: source,
                      position: position,
                      format: format,
                      docName: 'Numbered_${source.name.replaceAll('.pdf', '')}',
                    );
                    _recordAndExport(result, 'Page Numbers');
                  });
                },
                child: const Text('Apply Numbers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  // 13. Watermark Dialog
  void _showWatermarkDialog() {
    _pickSourceFile((source) {
      final textCtrl = TextEditingController(text: 'CONFIDENTIAL');
      double opacity = 0.3;
      bool isDiagonal = true;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Watermark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${source.name}'),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(labelText: 'Watermark Text', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['CONFIDENTIAL', 'DRAFT', 'COPY', 'ORIGINAL'].map((preset) {
                    return ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => textCtrl.text = preset),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text('Opacity: ${(opacity * 100).toInt()}%'),
                Slider(
                  value: opacity,
                  min: 0.1,
                  max: 0.7,
                  activeColor: const Color(0xFF9E556E),
                  onChanged: (val) => setDialogState(() => opacity = val),
                ),
                SwitchListTile(
                  title: const Text('Diagonal 45° angle'),
                  value: isDiagonal,
                  activeColor: const Color(0xFF9E556E),
                  onChanged: (val) => setDialogState(() => isDiagonal = val),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E556E)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _runAsyncProcess('Applying watermark stamp...', () async {
                    final result = await PdfEngine.addWatermark(
                      sourceItem: source,
                      watermarkText: textCtrl.text.trim(),
                      opacity: opacity,
                      isDiagonal: isDiagonal,
                      docName: 'Watermarked_${source.name.replaceAll('.pdf', '')}',
                    );
                    _recordAndExport(result, 'Watermark');
                  });
                },
                child: const Text('Stamp Watermark', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  // 14. Rotate PDF Dialog
  void _showRotatePdfDialog() {
    _pickSourceFile((source) {
      int rotation = 90;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Rotate PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('File: ${source.name}'),
                const SizedBox(height: 16),
                RadioListTile<int>(
                  title: const Text('90° Clockwise'),
                  value: 90,
                  groupValue: rotation,
                  activeColor: const Color(0xFFA16E8C),
                  onChanged: (val) => setDialogState(() => rotation = val!),
                ),
                RadioListTile<int>(
                  title: const Text('180° Flip Upside-Down'),
                  value: 180,
                  groupValue: rotation,
                  activeColor: const Color(0xFFA16E8C),
                  onChanged: (val) => setDialogState(() => rotation = val!),
                ),
                RadioListTile<int>(
                  title: const Text('270° Counter-Clockwise'),
                  value: 270,
                  groupValue: rotation,
                  activeColor: const Color(0xFFA16E8C),
                  onChanged: (val) => setDialogState(() => rotation = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA16E8C)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _runAsyncProcess('Rotating pages orientation...', () async {
                    final result = await PdfEngine.rotatePdf(
                      sourceItem: source,
                      rotationDegrees: rotation,
                      docName: 'Rotated_${rotation}deg_${source.name.replaceAll('.pdf', '')}',
                    );
                    _recordAndExport(result, 'Rotate PDF');
                  });
                },
                child: const Text('Rotate Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    });
  }

  // --- HELPERS ---

  void _pickSourceFile(Function(HistoryItem) onPicked) {
    if (widget.historyItems.isEmpty) {
      _showSnackbar('No PDF files found yet. Convert images to PDF first to use this tool!');
      return;
    }

    if (widget.historyItems.length == 1) {
      onPicked(widget.historyItems.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Source PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.historyItems.length,
              itemBuilder: (c, i) {
                final item = widget.historyItems[i];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE5322D)),
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.pages} pages • ${item.size}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onPicked(item);
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _recordAndExport(PdfEngineResult result, String tool) {
    final entry = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result.name,
      path: result.path,
      pages: result.pages,
      size: result.sizeStr,
      date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      toolType: tool,
    );
    widget.onAddHistoryItem(entry);

    if (mounted) {
      ExportModalSheet.show(
        context: context,
        pdfPath: result.path,
        docName: result.name,
        pages: result.pages,
        sizeStr: result.sizeStr,
      );
    }
  }

  Future<void> _runAsyncProcess(String message, Future<void> Function() action) async {
    setState(() {
      _isProcessing = true;
      _processingMessage = message;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) _showSnackbar('Operation failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 3-Column Grid matching Screenshot 5
        GridView.builder(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
          ),
          itemCount: _toolsList.length,
          itemBuilder: (ctx, idx) {
            final tool = _toolsList[idx];
            return GestureDetector(
              onTap: () => _handleToolTap(tool),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2C2F3A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(widget.isDark ? 0.22 : 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ToolBadgeIcon(type: tool.type, size: 50),
                    const SizedBox(height: 10),
                    Text(
                      tool.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Processing Overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.65),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFE5322D)),
                  const SizedBox(height: 16),
                  Text(
                    _processingMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
