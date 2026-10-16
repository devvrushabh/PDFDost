import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../services/scanner_engine.dart';
import 'document_crop_screen.dart';
import 'document_filter_screen.dart';
import 'scanner_camera_screen.dart';

class DocumentSetScreen extends StatefulWidget {
  final DocumentSet documentSet;
  final bool isDark;
  final Function(DocumentSet) onUpdateSet;
  final Function(DocumentSet) onDeleteSet;
  final Function(HistoryItem) onAddHistoryItem;

  const DocumentSetScreen({
    super.key,
    required this.documentSet,
    required this.isDark,
    required this.onUpdateSet,
    required this.onDeleteSet,
    required this.onAddHistoryItem,
  });

  @override
  State<DocumentSetScreen> createState() => _DocumentSetScreenState();
}

class _DocumentSetScreenState extends State<DocumentSetScreen> {
  late DocumentSet _set;
  final ImagePicker _picker = ImagePicker();
  bool _isGeneratingPdf = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _set = widget.documentSet;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocPage> get _filteredPages {
    if (_searchQuery.trim().isEmpty) return _set.pages;
    final q = _searchQuery.toLowerCase().trim();
    return _set.pages
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  void _notifyUpdate() {
    setState(() {
      _set.updatedAt = DateTime.now();
    });
    widget.onUpdateSet(_set);
  }

  Future<void> _pickGalleryPages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        for (final img in images) {
          final file = File(img.path);
          final size = await file.exists() ? await file.length() : 0;
          _set.pages.add(
            DocPage(
              id: 'page_${DateTime.now().millisecondsSinceEpoch}_${_set.pages.length + 1}',
              imagePath: img.path,
              name: '${_set.pages.length + 1}',
              sizeBytes: size,
              date: DateTime.now(),
              isNew: true,
            ),
          );
        }
        _notifyUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${images.length} page(s) to ${_set.title}'),
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  Future<void> _pickCameraPage() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ScannerCameraScreen(
          isDark: widget.isDark,
          onSaveDocumentSet: (newSet) {
            setState(() {
              _set.pages.addAll(newSet.pages);
              for (int i = 0; i < _set.pages.length; i++) {
                _set.pages[i].name = '${i + 1}';
              }
            });
            _notifyUpdate();
          },
          onAddHistoryItem: widget.onAddHistoryItem,
        ),
      ),
    );
  }

  Future<void> _cropPage(DocPage page, int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => DocumentCropScreen(
          imagePath: page.imagePath,
          isDark: widget.isDark,
        ),
      ),
    );

    if (result != null && mounted) {
      final quad = result['quad'] as QuadPoints;
      final rot = result['rotation'] as int;
      final outPath = await ScannerEngine.renderAndSavePage(
        sourcePath: page.imagePath,
        quad: quad,
        filter: DocScanFilter.original,
        rotationDegrees: rot,
      );
      final f = File(outPath);
      final size = await f.exists() ? await f.length() : page.sizeBytes;
      setState(() {
        page.imagePath = outPath;
        page.sizeBytes = size;
      });
      _notifyUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Page cropped successfully')),
      );
    }
  }

  Future<void> _filterPage(DocPage page, int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => DocumentFilterScreen(
          imagePath: page.imagePath,
          isDark: widget.isDark,
          showApplyToAll: false,
        ),
      ),
    );

    if (result != null && mounted) {
      final filter = result['filter'] as DocScanFilter;
      final brightness = result['brightness'] as double;
      final contrast = result['contrast'] as double;
      final outPath = await ScannerEngine.renderAndSavePage(
        sourcePath: page.imagePath,
        quad: QuadPoints.full(),
        filter: filter,
        rotationDegrees: 0,
        brightness: brightness,
        contrast: contrast,
      );
      final f = File(outPath);
      final size = await f.exists() ? await f.length() : page.sizeBytes;
      setState(() {
        page.imagePath = outPath;
        page.sizeBytes = size;
      });
      _notifyUpdate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Filter applied successfully')),
      );
    }
  }

  void _deletePage(int index) {
    if (index < 0 || index >= _set.pages.length) return;
    setState(() {
      _set.pages.removeAt(index);
      // Re-number remaining pages if they had sequential numbers
      for (int i = 0; i < _set.pages.length; i++) {
        if (int.tryParse(_set.pages[i].name) != null) {
          _set.pages[i].name = '${i + 1}';
        }
      }
    });
    _notifyUpdate();
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _set.pages.length) return;
    setState(() {
      final page = _set.pages.removeAt(oldIndex);
      _set.pages.insert(newIndex, page);
    });
    _notifyUpdate();
  }

  void _renameSet() {
    final controller = TextEditingController(text: _set.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Document Set', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0288D1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _set.title = newName);
                _notifyUpdate();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdfAndOpen() async {
    if (_set.pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document set has no pages to convert.')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfDoc = pw.Document();
      final hasPhysicalFiles = _set.pages.any((p) => p.imagePath.isNotEmpty && File(p.imagePath).existsSync());

      if (hasPhysicalFiles) {
        for (final page in _set.pages) {
          final file = File(page.imagePath);
          if (await file.exists()) {
            final imageBytes = await file.readAsBytes();
            final pwImage = pw.MemoryImage(imageBytes);
            pdfDoc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context ctx) {
                  return pw.Center(
                    child: pw.Image(pwImage, fit: pw.BoxFit.contain),
                  );
                },
              ),
            );
          } else {
            // Page placeholder
            pdfDoc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context ctx) {
                  return pw.Center(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(_set.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 16),
                        pw.Text('Page ${page.name}', style: const pw.TextStyle(fontSize: 18)),
                      ],
                    ),
                  );
                },
              ),
            );
          }
        }
      } else {
        // Sample pages: generate clean document
        for (int i = 0; i < _set.pages.length; i++) {
          final page = _set.pages[i];
          pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context ctx) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Doc Scanner • PDFDost', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                          pw.Text('Page ${i + 1} of ${_set.pages.length}', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                        ],
                      ),
                      pw.Divider(thickness: 1, color: PdfColors.grey300),
                      pw.SizedBox(height: 20),
                      pw.Text(
                        _set.title,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('Page Number: ${page.name}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800)),
                      pw.SizedBox(height: 30),
                      pw.Container(
                        height: 400,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                          borderRadius: pw.BorderRadius.circular(8),
                          color: PdfColors.grey100,
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Document Content • Page ${page.name}', style: const pw.TextStyle(color: PdfColors.grey600)),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final sanitizedName = _set.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '$sanitizedName.pdf';
      final file = File('${outputDir.path}/$fileName');
      await file.writeAsBytes(await pdfDoc.save());

      final fileSize = await file.length();
      final formattedSize = (fileSize / 1024).toStringAsFixed(0);

      final historyItem = HistoryItem(
        id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
        name: fileName,
        path: file.path,
        pages: _set.pages.length,
        size: '${formattedSize} KB',
        date: 'Today',
        toolType: 'Doc Scanner',
      );

      _set.generatedPdfPath = file.path;
      _notifyUpdate();
      widget.onAddHistoryItem(historyItem);

      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        ExportModalSheet.show(
          context: context,
          pdfPath: file.path,
          docName: fileName,
          pages: _set.pages.length,
          sizeStr: '${formattedSize} KB',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  void _previewPage(DocPage page, int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text('Page ${page.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 380,
                  width: double.infinity,
                  child: page.imagePath.isNotEmpty && File(page.imagePath).existsSync()
                      ? Image.file(File(page.imagePath), fit: BoxFit.contain)
                      : _buildSamplePageIllustration(page, index, isLarge: true),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Size: ${page.formattedSize}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                    label: const Text('Delete Page', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deletePage(index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSamplePageIllustration(DocPage page, int index, {bool isLarge = false}) {
    final textColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final bg = widget.isDark ? const Color(0xFF17202A) : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      padding: EdgeInsets.all(isLarge ? 16 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: isLarge ? 20 : 6,
            width: isLarge ? 80 : 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0288D1).withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(height: isLarge ? 12 : 4),
          Container(
            height: isLarge ? 6 : 2,
            width: double.infinity,
            color: borderColor,
          ),
          SizedBox(height: isLarge ? 6 : 3),
          Container(
            height: isLarge ? 6 : 2,
            width: isLarge ? 180 : 40,
            color: borderColor.withOpacity(0.6),
          ),
          const Spacer(),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isLarge ? 14 : 6, vertical: isLarge ? 8 : 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0288D1), width: 1.2),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF0288D1).withOpacity(0.08),
              ),
              child: Text(
                'Page ${page.name}',
                style: TextStyle(
                  fontSize: isLarge ? 14 : 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0288D1),
                ),
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: isLarge ? 6 : 2, width: 24, color: borderColor),
              Text(
                'DocScanner',
                style: TextStyle(fontSize: isLarge ? 9 : 6, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF12181F) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1B242D) : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = widget.isDark ? const Color(0xFF24303C) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: widget.isDark ? const Color(0xFF15222C) : const Color(0xFF1E3A4B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search page...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : GestureDetector(
                onTap: _renameSet,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _set.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined, size: 16, color: Colors.white70),
                  ],
                ),
              ),
        actions: [
          // Search icon button
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),

          // Instant PDF generation button [📄 PDF] (Matches Screenshot 2)
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
            tooltip: 'Generate / Export PDF',
            onPressed: _isGeneratingPdf ? null : _generatePdfAndOpen,
          ),

          // 3-dots overflow menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'rename') {
                _renameSet();
              } else if (val == 'pdf') {
                _generatePdfAndOpen();
              } else if (val == 'delete') {
                widget.onDeleteSet(_set);
                Navigator.pop(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Rename Document'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFF0288D1)),
                    SizedBox(width: 10),
                    Text('Compile & View PDF'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Move to Trash', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _filteredPages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 60, color: textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 14),
                      Text('No pages in this document set', style: TextStyle(color: textSecondary, fontSize: 16)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: const Text('Add Pages'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1)),
                        onPressed: _pickGalleryPages,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _filteredPages.length,
                  itemBuilder: (ctx, index) {
                    final page = _filteredPages[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: dividerColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _previewPage(page, index),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Left: Page Thumbnail (Matches Screenshot 2)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 68,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: widget.isDark ? const Color(0xFF14191F) : const Color(0xFFF1F5F9),
                                    border: Border.all(color: dividerColor, width: 1.2),
                                  ),
                                  child: page.imagePath.isNotEmpty && File(page.imagePath).existsSync()
                                      ? Image.file(
                                          File(page.imagePath),
                                          fit: BoxFit.cover,
                                        )
                                      : _buildSamplePageIllustration(page, index),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Center Column: Title, Date, Size, [N] Badge
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      page.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      page.formattedDate,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Size + Red [N] Badge
                                    Row(
                                      children: [
                                        Text(
                                          page.formattedSize,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                        ),
                                        if (page.isNew) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'N',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Right: 3-dots Menu
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 20),
                                color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (val) {
                                  if (val == 'preview') {
                                    _previewPage(page, index);
                                  } else if (val == 'crop') {
                                    _cropPage(page, index);
                                  } else if (val == 'filter') {
                                    _filterPage(page, index);
                                  } else if (val == 'up' && index > 0) {
                                    _movePage(index, index - 1);
                                  } else if (val == 'down' && index < _set.pages.length - 1) {
                                    _movePage(index, index + 1);
                                  } else if (val == 'delete') {
                                    _deletePage(index);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'preview',
                                    child: Row(
                                      children: [
                                        Icon(Icons.fullscreen_rounded, size: 18),
                                        SizedBox(width: 8),
                                        Text('View Page'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'crop',
                                    child: Row(
                                      children: [
                                        Icon(Icons.crop_rounded, size: 18, color: Color(0xFFFA9282)),
                                        SizedBox(width: 8),
                                        Text('Crop & Adjust Edges'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'filter',
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF0288D1)),
                                        SizedBox(width: 8),
                                        Text('Color Filters'),
                                      ],
                                    ),
                                  ),
                                  if (index > 0)
                                    const PopupMenuItem(
                                      value: 'up',
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_upward_rounded, size: 18),
                                          SizedBox(width: 8),
                                          Text('Move Up'),
                                        ],
                                      ),
                                    ),
                                  if (index < _set.pages.length - 1)
                                    const PopupMenuItem(
                                      value: 'down',
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_downward_rounded, size: 18),
                                          SizedBox(width: 8),
                                          Text('Move Down'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete Page', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

          // Floating Dual Action Capsule (Screenshot 2: [ 📷 | 🖼️ ])
          Positioned(
            bottom: 24,
            right: 20,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1), // DocScanner rich blue
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera button
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      bottomLeft: Radius.circular(30),
                    ),
                    onTap: _pickCameraPage,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 28,
                    width: 1,
                    color: Colors.white.withOpacity(0.35),
                  ),

                  // Gallery button
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    onTap: _pickGalleryPages,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
