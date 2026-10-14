import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/space_empty_illustration.dart';
import '../widgets/tool_badge_icon.dart';

class GenericPdfToolScreen extends StatefulWidget {
  final PdfToolType toolType;
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const GenericPdfToolScreen({
    super.key,
    required this.toolType,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<GenericPdfToolScreen> createState() => _GenericPdfToolScreenState();
}

class _GenericPdfToolScreenState extends State<GenericPdfToolScreen>
    with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected PDFs, 1: Completed History
  bool _isSpeedDialOpen = false;
  bool _isProcessing = false;

  final List<SelectedPdfItem> _selectedPdfs = [];

  // Animation controller for Speed Dial FAB
  late AnimationController _fabAnimController;
  late Animation<double> _fabRotationAnim;

  // Tool Specific Options
  // 1. PDF to Word
  bool _wordIncludeHeaders = true;

  // 2. PDF to PowerPoint
  String _pptTheme = 'Modern Indigo'; // Modern Indigo, Crimson Coral, Slate Emerald

  // 3. PDF to Excel
  String _excelDelimiter = 'Auto-Detect Columns';

  // 4. PDF to JPG
  int _jpgDpi = 150; // 150 or 300

  // 5. Page Numbers
  String _pageNumberPosition = 'Bottom Center'; // Bottom Center, Bottom Right, Top Right, Bottom Left
  String _pageNumberFormat = 'Page {n} of {total}'; // Page {n} of {total}, {n} / {total}, Page {n}, {n}
  int _pageNumberStart = 1;

  // 6. Watermark
  final TextEditingController _watermarkTextController =
      TextEditingController(text: 'CONFIDENTIAL');
  double _watermarkOpacity = 0.35;
  bool _watermarkIsDiagonal = true;
  int _watermarkColorValue = 0xFFDC2626; // Red by default

  // 7. Rotate PDF
  int _rotateDegrees = 90; // 90, 180, 270

  // 8. PDF Lock
  final TextEditingController _lockPasswordController = TextEditingController();
  final TextEditingController _lockConfirmPasswordController = TextEditingController();
  bool _lockPasswordObscured = true;
  bool _lockConfirmObscured = true;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabRotationAnim = Tween<double>(begin: 0.0, end: math.pi / 4).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _watermarkTextController.dispose();
    _lockPasswordController.dispose();
    _lockConfirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleSpeedDial() {
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
      if (_isSpeedDialOpen) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
    });
  }

  void _closeSpeedDial() {
    if (_isSpeedDialOpen) {
      setState(() {
        _isSpeedDialOpen = false;
        _fabAnimController.reverse();
      });
    }
  }

  String get _toolTitle {
    switch (widget.toolType) {
      case PdfToolType.pdfToWord:
        return 'PDF to Word';
      case PdfToolType.pdfToPowerPoint:
        return 'PDF to PowerPoint';
      case PdfToolType.pdfToExcel:
        return 'PDF to Excel';
      case PdfToolType.pdfToJpg:
        return 'PDF to JPG';
      case PdfToolType.pageNumbers:
        return 'Page Numbers';
      case PdfToolType.watermark:
        return 'Watermark';
      case PdfToolType.rotatePdf:
        return 'Rotate PDF';
      case PdfToolType.lockPdf:
        return 'PDF Lock';
      default:
        return 'PDF Studio';
    }
  }

  String get _toolSubtitle {
    switch (widget.toolType) {
      case PdfToolType.pdfToWord:
        return 'Convert PDF pages into formatted Word document';
      case PdfToolType.pdfToPowerPoint:
        return 'Generate 16:9 presentation slides from document';
      case PdfToolType.pdfToExcel:
        return 'Extract tables and lines to CSV spreadsheet';
      case PdfToolType.pdfToJpg:
        return 'Export all pages to high-resolution JPG images';
      case PdfToolType.pageNumbers:
        return 'Add page numbering vector overlays to all pages';
      case PdfToolType.watermark:
        return 'Stamp custom security watermark or brand name';
      case PdfToolType.rotatePdf:
        return 'Rotate document pages by 90°, 180°, or 270°';
      case PdfToolType.lockPdf:
        return 'Protect document with AES 128-bit password encryption';
      default:
        return 'Process PDF with PDFDost engine';
    }
  }

  String get _actionButtonLabel {
    switch (widget.toolType) {
      case PdfToolType.pdfToWord:
        return 'Convert to Word (.doc)';
      case PdfToolType.pdfToPowerPoint:
        return 'Convert to PowerPoint Slides';
      case PdfToolType.pdfToExcel:
        return 'Convert to Excel (.csv)';
      case PdfToolType.pdfToJpg:
        return 'Export to JPG Images';
      case PdfToolType.pageNumbers:
        return 'Add Page Numbers';
      case PdfToolType.watermark:
        return 'Apply Watermark';
      case PdfToolType.rotatePdf:
        return 'Rotate Pages ($_rotateDegrees°)';
      case PdfToolType.lockPdf:
        return 'Lock PDF with Password';
      default:
        return 'Process Document';
    }
  }

  String get _historyFilterType {
    switch (widget.toolType) {
      case PdfToolType.pdfToWord:
        return 'PDF to Word';
      case PdfToolType.pdfToPowerPoint:
        return 'PDF to PowerPoint';
      case PdfToolType.pdfToExcel:
        return 'PDF to Excel';
      case PdfToolType.pdfToJpg:
        return 'PDF to JPG';
      case PdfToolType.pageNumbers:
        return 'Page Numbers';
      case PdfToolType.watermark:
        return 'Watermark';
      case PdfToolType.rotatePdf:
        return 'Rotate PDF';
      case PdfToolType.lockPdf:
        return 'PDF Lock';
      default:
        return 'PDF Tool';
    }
  }

  List<HistoryItem> get _filteredHistory {
    return widget.historyItems.where((e) => e.toolType == _historyFilterType).toList();
  }

  Future<void> _pickPdfFromDevice() async {
    _closeSpeedDial();
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<SelectedPdfItem> newItems = [];
        for (final platformFile in result.files) {
          final filePath = platformFile.path;
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              final size = await file.length();
              final pageCount = await PdfEngine.getPdfPageCount(filePath);
              final name = platformFile.name.isNotEmpty
                  ? platformFile.name
                  : filePath.split(Platform.pathSeparator).last;

              newItems.add(
                SelectedPdfItem(
                  path: filePath,
                  name: name,
                  sizeBytes: size,
                  pageCount: pageCount,
                ),
              );
            }
          }
        }

        if (newItems.isNotEmpty) {
          setState(() {
            for (final item in newItems) {
              if (!_selectedPdfs.any((e) => e.path == item.path)) {
                _selectedPdfs.add(item);
              }
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newItems.length} PDF(s) to list'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _showHistoryPicker() {
    _closeSpeedDial();
    final validHistory = widget.historyItems.where((h) => File(h.path).existsSync()).toList();

    if (validHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved PDFs found in history'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select PDF from History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: validHistory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = validHistory[index];
                    final isAlreadySelected = _selectedPdfs.any((e) => e.path == item.path);

                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4B4B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF4B4B), size: 22),
                      ),
                      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.pages} pages • ${item.size} • ${item.date}', style: const TextStyle(fontSize: 11)),
                      trailing: isAlreadySelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                          : const Icon(Icons.add_circle_outline_rounded),
                      onTap: () {
                        if (!isAlreadySelected) {
                          final file = File(item.path);
                          final size = file.existsSync() ? file.lengthSync() : 0;
                          setState(() {
                            _selectedPdfs.add(
                              SelectedPdfItem(
                                path: item.path,
                                name: item.name,
                                sizeBytes: size,
                                pageCount: item.pages,
                              ),
                            );
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${item.name}"'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeSelectedPdf(int index) {
    setState(() {
      _selectedPdfs.removeAt(index);
    });
  }

  void _clearAllSelected() {
    setState(() {
      _selectedPdfs.clear();
    });
  }

  // --- EXECUTION OF CURRENT TOOL ---
  Future<void> _executeTool() async {
    if (_selectedPdfs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one PDF file'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Specific validation for Lock PDF
    if (widget.toolType == PdfToolType.lockPdf) {
      final pwd = _lockPasswordController.text.trim();
      final confirmPwd = _lockConfirmPasswordController.text.trim();
      if (pwd.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a password to lock the PDF'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      if (pwd != confirmPwd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    // Specific validation for Watermark
    if (widget.toolType == PdfToolType.watermark) {
      if (_watermarkTextController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter watermark text'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    final firstItem = _selectedPdfs.first;
    final defaultDocName = '${_toolTitle.replaceAll(' ', '_')}_${firstItem.name.replaceAll('.pdf', '')}';
    final nameController = TextEditingController(text: defaultDocName);

    final docName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            ToolBadgeIcon(type: widget.toolType, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(_toolTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter document title:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4B4B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Process'),
          ),
        ],
      ),
    );

    if (docName == null || docName.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final List<HistoryItem> generatedItems = [];
      String? latestPdfPathForModal;
      String? latestDocNameForModal;
      int latestPages = 1;
      String latestSize = '';

      for (int i = 0; i < _selectedPdfs.length; i++) {
        final pdfItem = _selectedPdfs[i];
        final String currentDocName = _selectedPdfs.length == 1
            ? docName
            : '${docName}_${i + 1}';

        switch (widget.toolType) {
          case PdfToolType.pdfToWord:
            final file = await PdfEngine.pdfToWordFromPath(
              sourcePath: pdfItem.path,
              docName: currentDocName,
              includeHeaders: _wordIncludeHeaders,
            );
            final sizeStr = PdfEngine.formatBytes(await file.length());
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: '${currentDocName}.doc',
              path: file.path,
              pages: pdfItem.pageCount,
              size: sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            break;

          case PdfToolType.pdfToPowerPoint:
            final res = await PdfEngine.pdfToPowerPointFromPath(
              sourcePath: pdfItem.path,
              docName: currentDocName,
              theme: _pptTheme,
            );
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: res.name,
              path: res.path,
              pages: res.pages,
              size: res.sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            latestPdfPathForModal = res.path;
            latestDocNameForModal = res.name;
            latestPages = res.pages;
            latestSize = res.sizeStr;
            break;

          case PdfToolType.pdfToExcel:
            final file = await PdfEngine.pdfToExcelFromPath(
              sourcePath: pdfItem.path,
              docName: currentDocName,
            );
            final sizeStr = PdfEngine.formatBytes(await file.length());
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: '${currentDocName}.csv',
              path: file.path,
              pages: pdfItem.pageCount,
              size: sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            break;

          case PdfToolType.pdfToJpg:
            final images = await PdfEngine.pdfToJpgFromPath(
              sourcePath: pdfItem.path,
              docName: currentDocName,
              dpi: _jpgDpi,
            );
            if (images.isNotEmpty) {
              final firstImg = images.first;
              final sizeStr = PdfEngine.formatBytes(await firstImg.length());
              final item = HistoryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: '${currentDocName}_page_1.jpg (${images.length} pages)',
                path: firstImg.path,
                pages: images.length,
                size: sizeStr,
                date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                toolType: _historyFilterType,
              );
              generatedItems.add(item);
              widget.onAddHistoryItem(item);
              await StorageEngine.saveHistoryItem(item);
            }
            break;

          case PdfToolType.pageNumbers:
            final res = await PdfEngine.addPageNumbersToPdf(
              sourcePath: pdfItem.path,
              position: _pageNumberPosition,
              format: _pageNumberFormat,
              startNumber: _pageNumberStart,
              docName: currentDocName,
            );
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: res.name,
              path: res.path,
              pages: res.pages,
              size: res.sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            latestPdfPathForModal = res.path;
            latestDocNameForModal = res.name;
            latestPages = res.pages;
            latestSize = res.sizeStr;
            break;

          case PdfToolType.watermark:
            final res = await PdfEngine.addWatermarkToPdf(
              sourcePath: pdfItem.path,
              watermarkText: _watermarkTextController.text.trim(),
              opacity: _watermarkOpacity,
              isDiagonal: _watermarkIsDiagonal,
              colorValue: _watermarkColorValue,
              docName: currentDocName,
            );
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: res.name,
              path: res.path,
              pages: res.pages,
              size: res.sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            latestPdfPathForModal = res.path;
            latestDocNameForModal = res.name;
            latestPages = res.pages;
            latestSize = res.sizeStr;
            break;

          case PdfToolType.rotatePdf:
            final res = await PdfEngine.rotatePdfDocument(
              sourcePath: pdfItem.path,
              rotationDegrees: _rotateDegrees,
              docName: currentDocName,
            );
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: res.name,
              path: res.path,
              pages: res.pages,
              size: res.sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            latestPdfPathForModal = res.path;
            latestDocNameForModal = res.name;
            latestPages = res.pages;
            latestSize = res.sizeStr;
            break;

          case PdfToolType.lockPdf:
            final res = await PdfEngine.lockPdfDocument(
              sourcePath: pdfItem.path,
              password: _lockPasswordController.text.trim(),
              docName: currentDocName,
            );
            final item = HistoryItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: res.name,
              path: res.path,
              pages: res.pages,
              size: res.sizeStr,
              date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
              toolType: _historyFilterType,
            );
            generatedItems.add(item);
            widget.onAddHistoryItem(item);
            await StorageEngine.saveHistoryItem(item);
            latestPdfPathForModal = res.path;
            latestDocNameForModal = res.name;
            latestPages = res.pages;
            latestSize = res.sizeStr;
            break;

          default:
            break;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created ${generatedItems.length} document(s)'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );

        // Switch to Tab 1 to see completed documents
        setState(() => _activeChip = 1);

        // Open Export Modal Sheet if a PDF was generated
        if (latestPdfPathForModal != null) {
          ExportModalSheet.show(
            context: context,
            pdfPath: latestPdfPathForModal,
            docName: latestDocNameForModal ?? 'Document',
            pages: latestPages,
            sizeStr: latestSize,
          );
        } else if (generatedItems.isNotEmpty) {
          final firstGenerated = generatedItems.first;
          OpenFilex.open(firstGenerated.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process document: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = widget.isDark ? const Color(0xFF141518) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ToolBadgeIcon(type: widget.toolType, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _toolTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedPdfs.isNotEmpty && _activeChip == 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Clear Selected',
              onPressed: _clearAllSelected,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Dual Tab Switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabChip(
                        index: 0,
                        title: 'Selected PDFs',
                        count: _selectedPdfs.length,
                        icon: Icons.picture_as_pdf_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabChip(
                        index: 1,
                        title: 'Completed',
                        count: _filteredHistory.length,
                        icon: Icons.done_all_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Views
              Expanded(
                child: _activeChip == 0
                    ? _buildSelectedView()
                    : _buildHistoryView(),
              ),
            ],
          ),

          // Speed Dial Backdrop
          if (_isSpeedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSpeedDial,
                child: Container(color: Colors.black54),
              ),
            ),

          // Speed Dial Buttons
          if (_isSpeedDialOpen)
            Positioned(
              right: 20,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSpeedDialItem(
                    label: 'From History',
                    icon: Icons.history_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: _showHistoryPicker,
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialItem(
                    label: 'From Device',
                    icon: Icons.file_upload_outlined,
                    color: const Color(0xFF10B981),
                    onTap: _pickPdfFromDevice,
                  ),
                ],
              ),
            ),

          // Main Floating Action Button
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'generic_pdf_fab',
              backgroundColor: const Color(0xFFFF4B4B),
              elevation: 4,
              onPressed: _toggleSpeedDial,
              child: AnimatedBuilder(
                animation: _fabRotationAnim,
                builder: (context, child) => Transform.rotate(
                  angle: _fabRotationAnim.value,
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),

          // Bottom Action Bar when files selected in Tab 0
          if (_selectedPdfs.isNotEmpty && _activeChip == 0)
            Positioned(
              left: 16,
              right: 88,
              bottom: 24,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3366), Color(0xFFFF5E36)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3366).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _isProcessing ? null : _executeTool,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isProcessing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          else
                            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isProcessing ? 'Processing...' : _actionButtonLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _activeChip == index;
    final primaryColor = const Color(0xFFFF4B4B);

    return GestureDetector(
      onTap: () {
        _closeSpeedDial();
        setState(() => _activeChip = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.12)
              : (widget.isDark ? const Color(0xFF1E2024) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: isSelected ? primaryColor : (widget.isDark ? Colors.white70 : Colors.black87),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // --- TAB 0: SELECTED PDFS VIEW ---

  Widget _buildSelectedView() {
    if (_selectedPdfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpaceEmptyIllustration(size: 160),
              const SizedBox(height: 20),
              Text(
                'No PDF Selected',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _toolSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4B4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _pickPdfFromDevice,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add PDF to Begin', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tool Options Card
          _buildToolOptionsCard(),
          const SizedBox(height: 16),

          // 2. Selected Files Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Selected PDFs (${_selectedPdfs.length})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B4B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.drag_indicator_rounded, size: 12, color: Color(0xFFFF4B4B)),
                        SizedBox(width: 2),
                        Text(
                          'Hold & drag to reorder',
                          style: TextStyle(fontSize: 10, color: Color(0xFFFF4B4B), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${_selectedPdfs.fold<int>(0, (sum, item) => sum + item.pageCount)} total pages',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final item = _selectedPdfs.removeAt(oldIndex);
          _selectedPdfs.insert(newIndex, item);
        });
      },
      children: [
        for (int index = 0; index < _selectedPdfs.length; index++)
          _buildSelectedPdfCard(_selectedPdfs[index], index),
      ],
    );
  }

  Widget _buildSelectedPdfCard(SelectedPdfItem item, int index) {
    return Container(
      key: ValueKey('${item.path}_$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Order Position Badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4B4B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Color(0xFFFF4B4B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4B4B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFF4B4B), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.pageCount} pages',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.formattedSize,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: const Icon(
                Icons.drag_indicator_rounded,
                size: 22,
                color: Colors.grey,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
            onPressed: () => _removeSelectedPdf(index),
          ),
        ],
      ),
    );
  }

  // --- TOOL OPTIONS CARD ---

  Widget _buildToolOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ToolBadgeIcon(type: widget.toolType, size: 24),
              const SizedBox(width: 8),
              Text(
                '$_toolTitle Settings',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildToolSpecificSettings(),
        ],
      ),
    );
  }

  Widget _buildToolSpecificSettings() {
    switch (widget.toolType) {
      // 1. PDF to Word
      case PdfToolType.pdfToWord:
        return Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include Headers & Metadata', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Embeds title, conversion date, and page markers', style: TextStyle(fontSize: 11, color: Colors.grey)),
              value: _wordIncludeHeaders,
              activeColor: const Color(0xFFFF4B4B),
              onChanged: (val) => setState(() => _wordIncludeHeaders = val),
            ),
            const SizedBox(height: 8),
            _buildFeatureBadge('Standard Microsoft Word Compatible .doc with HTML/UTF-8 structure'),
          ],
        );

      // 2. PDF to PowerPoint
      case PdfToolType.pdfToPowerPoint:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Presentation Color Theme:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Modern Indigo', 'Crimson Coral', 'Slate Emerald'].map((theme) {
                final isSelected = _pptTheme == theme;
                return ChoiceChip(
                  label: Text(theme),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF4B4B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _pptTheme = theme);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _buildFeatureBadge('16:9 widescreen presentation slides with slide numbers & master layout'),
          ],
        );

      // 3. PDF to Excel
      case PdfToolType.pdfToExcel:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Extraction Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Auto-Detect Columns', 'Line by Line'].map((mode) {
                final isSelected = _excelDelimiter == mode;
                return ChoiceChip(
                  label: Text(mode),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF4B4B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _excelDelimiter = mode);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _buildFeatureBadge('Outputs clean UTF-8 CSV with Excel BOM for instant spreadsheet analysis'),
          ],
        );

      // 4. PDF to JPG
      case PdfToolType.pdfToJpg:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolution / Quality:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    title: '150 DPI',
                    subtitle: 'Standard (Fast)',
                    isSelected: _jpgDpi == 150,
                    onTap: () => setState(() => _jpgDpi = 150),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOptionTile(
                    title: '300 DPI',
                    subtitle: 'High Definition',
                    isSelected: _jpgDpi == 300,
                    onTap: () => setState(() => _jpgDpi = 300),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFeatureBadge('Renders vector pages into crisp individual JPG image files'),
          ],
        );

      // 5. Page Numbers
      case PdfToolType.pageNumbers:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Position:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Bottom Center', 'Bottom Right', 'Top Right', 'Bottom Left'].map((pos) {
                final isSelected = _pageNumberPosition == pos;
                return ChoiceChip(
                  label: Text(pos),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF4B4B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontSize: 11.5,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _pageNumberPosition = pos);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Format:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Page {n} of {total}', '{n} / {total}', 'Page {n}', '{n}'].map((fmt) {
                final isSelected = _pageNumberFormat == fmt;
                return ChoiceChip(
                  label: Text(fmt.replaceAll('{n}', '1').replaceAll('{total}', '10')),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF4B4B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontSize: 11.5,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _pageNumberFormat = fmt);
                  },
                );
              }).toList(),
            ),
          ],
        );

      // 6. Watermark
      case PdfToolType.watermark:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Watermark Text:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _watermarkTextController,
              decoration: InputDecoration(
                hintText: 'e.g. CONFIDENTIAL or Company Name',
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: ['CONFIDENTIAL', 'DRAFT', 'COPY', 'OFFICIAL', 'PDFDost'].map((preset) {
                return ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _watermarkTextController.text = preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Opacity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                Text('${(_watermarkOpacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            Slider(
              value: _watermarkOpacity,
              min: 0.1,
              max: 0.8,
              divisions: 14,
              activeColor: const Color(0xFFFF4B4B),
              onChanged: (val) => setState(() => _watermarkOpacity = val),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    title: 'Diagonal',
                    subtitle: '45° Angle',
                    isSelected: _watermarkIsDiagonal,
                    onTap: () => setState(() => _watermarkIsDiagonal = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildOptionTile(
                    title: 'Horizontal',
                    subtitle: '0° Angle',
                    isSelected: !_watermarkIsDiagonal,
                    onTap: () => setState(() => _watermarkIsDiagonal = false),
                  ),
                ),
              ],
            ),
          ],
        );

      // 7. Rotate PDF
      case PdfToolType.rotatePdf:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rotation Angle:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildOptionTile(
                    title: '90°',
                    subtitle: 'Clockwise',
                    isSelected: _rotateDegrees == 90,
                    onTap: () => setState(() => _rotateDegrees = 90),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionTile(
                    title: '180°',
                    subtitle: 'Half Turn',
                    isSelected: _rotateDegrees == 180,
                    onTap: () => setState(() => _rotateDegrees = 180),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildOptionTile(
                    title: '270°',
                    subtitle: 'Counter-CW',
                    isSelected: _rotateDegrees == 270,
                    onTap: () => setState(() => _rotateDegrees = 270),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFeatureBadge('Adjusts rotation metadata and viewport coordinates natively without image loss'),
          ],
        );

      // 8. PDF Lock
      case PdfToolType.lockPdf:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Password:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _lockPasswordController,
              obscureText: _lockPasswordObscured,
              decoration: InputDecoration(
                hintText: 'Enter secure password',
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(_lockPasswordObscured ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _lockPasswordObscured = !_lockPasswordObscured),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Confirm Password:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _lockConfirmPasswordController,
              obscureText: _lockConfirmObscured,
              decoration: InputDecoration(
                hintText: 'Confirm password',
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(_lockConfirmObscured ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _lockConfirmObscured = !_lockConfirmObscured),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildFeatureBadge('AES 128-Bit Military Grade Encryption protects your document from unauthorized opening'),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF4B4B).withOpacity(0.12)
              : (widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF4B4B) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFFFF4B4B) : (widget.isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF282A30) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: HISTORY / COMPLETED DOCUMENTS VIEW ---

  Widget _buildHistoryView() {
    final history = _filteredHistory;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpaceEmptyIllustration(size: 150),
              const SizedBox(height: 18),
              Text(
                'No Output Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Documents created with $_toolTitle will appear here for easy viewing and sharing.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final item = history[index];
        return _buildHistoryItemCard(item);
      },
    );
  }

  Widget _buildHistoryItemCard(HistoryItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ToolBadgeIcon(type: widget.toolType, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.pages} pages • ${item.size} • ${item.date}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              if (File(item.path).existsSync()) {
                Share.shareXFiles([XFile(item.path)], text: 'Sharing ${item.name}');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFFFF4B4B)),
            onPressed: () {
              if (File(item.path).existsSync()) {
                OpenFilex.open(item.path);
              }
            },
          ),
        ],
      ),
    );
  }
}
