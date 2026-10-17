import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/scanner_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import 'document_crop_screen.dart';
import 'document_filter_screen.dart';

class ScannerBatchEditorScreen extends StatefulWidget {
  final List<ScannedPageData> initialPages;
  final bool isDark;
  final Function(DocumentSet)? onSaveDocumentSet;
  final Function(HistoryItem)? onAddHistoryItem;

  const ScannerBatchEditorScreen({
    super.key,
    required this.initialPages,
    required this.isDark,
    this.onSaveDocumentSet,
    this.onAddHistoryItem,
  });

  @override
  State<ScannerBatchEditorScreen> createState() => _ScannerBatchEditorScreenState();
}

class _ScannerBatchEditorScreenState extends State<ScannerBatchEditorScreen> {
  late List<ScannedPageData> _pages;
  late PageController _pageController;
  int _currentPageIndex = 0;
  String _docTitle = '';
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.initialPages);
    _pageController = PageController();
    _docTitle = 'DocScan_${DateFormat('ddMMM_HHmm').format(DateTime.now())}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  // --- ACTIONS ON ACTIVE PAGE ---

  Future<void> _openCropForCurrentPage() async {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => DocumentCropScreen(
          imagePath: page.rawImagePath,
          isDark: widget.isDark,
          initialQuad: page.quad,
          initialRotation: page.rotationDegrees,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        page.quad = result['quad'] as QuadPoints;
        page.rotationDegrees = result['rotation'] as int;
      });
      // Re-render processed image
      _renderPage(page);
    }
  }

  Future<void> _openFilterForCurrentPage() async {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => DocumentFilterScreen(
          imagePath: page.rawImagePath,
          isDark: widget.isDark,
          initialFilter: page.filter,
          initialBrightness: page.brightness,
          initialContrast: page.contrast,
          showApplyToAll: _pages.length > 1,
        ),
      ),
    );

    if (result != null && mounted) {
      final selectedFilter = result['filter'] as DocScanFilter;
      final selectedBrightness = result['brightness'] as double;
      final selectedContrast = result['contrast'] as double;
      final applyToAll = result['applyToAll'] as bool;

      setState(() {
        if (applyToAll) {
          for (final p in _pages) {
            p.filter = selectedFilter;
            p.brightness = selectedBrightness;
            p.contrast = selectedContrast;
          }
        } else {
          page.filter = selectedFilter;
          page.brightness = selectedBrightness;
          page.contrast = selectedContrast;
        }
      });

      if (applyToAll) {
        for (final p in _pages) {
          _renderPage(p);
        }
      } else {
        _renderPage(page);
      }
    }
  }

  void _rotateCurrentPage() {
    if (_pages.isEmpty) return;
    final page = _pages[_currentPageIndex];
    setState(() {
      page.rotationDegrees = (page.rotationDegrees + 90) % 360;
    });
    _renderPage(page);
  }

  Future<void> _retakeCurrentPage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (file != null && mounted) {
        final page = _pages[_currentPageIndex];
        final newPage = ScannedPageData(
          id: page.id,
          rawImagePath: file.path,
          processedImagePath: file.path,
          quad: QuadPoints.inset(0.05),
          filter: page.filter,
        );
        setState(() {
          _pages[_currentPageIndex] = newPage;
        });
        _renderPage(newPage);
      }
    } catch (_) {}
  }

  void _deleteCurrentPage() {
    if (_pages.isEmpty) return;
    if (_pages.length == 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
          title: const Text('Discard Scan?'),
          content: const Text('Deleting the only page will discard the scan session.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Discard', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _pages.removeAt(_currentPageIndex);
      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
    });
  }

  Future<void> _addNewPagesSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Add More Pages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFA9282).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFA9282)),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
                  if (file != null && mounted) {
                    final newPage = ScannedPageData(
                      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
                      rawImagePath: file.path,
                      processedImagePath: file.path,
                      quad: QuadPoints.inset(0.05),
                    );
                    setState(() {
                      _pages.add(newPage);
                      _currentPageIndex = _pages.length - 1;
                    });
                    _pageController.jumpToPage(_currentPageIndex);
                    _renderPage(newPage);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0288D1).withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0288D1)),
                ),
                title: const Text('Import from Photo Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final List<XFile> files = await _picker.pickMultiImage();
                  if (files.isNotEmpty && mounted) {
                    for (final file in files) {
                      final newPage = ScannedPageData(
                        id: 'p_${DateTime.now().millisecondsSinceEpoch}_${_pages.length}',
                        rawImagePath: file.path,
                        processedImagePath: file.path,
                        quad: QuadPoints.inset(0.05),
                      );
                      _pages.add(newPage);
                      _renderPage(newPage);
                    }
                    setState(() {
                      _currentPageIndex = _pages.length - 1;
                    });
                    _pageController.jumpToPage(_currentPageIndex);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renderPage(ScannedPageData page) async {
    try {
      final outPath = await ScannerEngine.renderAndSavePage(
        sourcePath: page.rawImagePath,
        quad: page.quad,
        filter: page.filter,
        rotationDegrees: page.rotationDegrees,
        brightness: page.brightness,
        contrast: page.contrast,
      );
      if (mounted) {
        setState(() {
          page.processedImagePath = outPath;
        });
      }
    } catch (_) {}
  }

  void _editTitleDialog() {
    final controller = TextEditingController(text: _docTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Document Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: 'Enter title...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFA9282)),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _docTitle = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- SAVE & CONVERSION ---

  Future<void> _onFinishPressed() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Scan (${_pages.length} Pages)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to save this scanned document:',
                style: TextStyle(
                  color: widget.isDark ? Colors.white70 : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Generate PDF immediately
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFA9282).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFA9282).withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFA9282),
                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                  ),
                  title: const Text('Convert to PDF & Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Generate PDF with page numbers, compress, share, or print.', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFFFA9282)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _generatePdfDirectly();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: Save as Document Set in PDFDost Files
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0288D1).withValues(alpha: 0.4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0288D1),
                    child: Icon(Icons.folder_shared_rounded, color: Colors.white),
                  ),
                  title: const Text('Save to Document Sets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Store pages in PDFDost Documents tab to edit or reorder anytime.', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF0288D1)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveToDocSets();
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renderAllPagesSynchronously() async {
    for (final page in _pages) {
      if (page.processedImagePath == page.rawImagePath) {
        final out = await ScannerEngine.renderAndSavePage(
          sourcePath: page.rawImagePath,
          quad: page.quad,
          filter: page.filter,
          rotationDegrees: page.rotationDegrees,
          brightness: page.brightness,
          contrast: page.contrast,
        );
        page.processedImagePath = out;
      }
    }
  }

  Future<void> _generatePdfDirectly() async {
    setState(() => _isSaving = true);
    try {
      await _renderAllPagesSynchronously();

      final List<SelectedImageItem> items = [];
      for (int i = 0; i < _pages.length; i++) {
        final p = _pages[i];
        final f = File(p.processedImagePath);
        final size = await f.exists() ? await f.length() : 0;
        items.add(
          SelectedImageItem(
            path: p.processedImagePath,
            name: '${_docTitle}_${i + 1}.png',
            sizeBytes: size,
          ),
        );
      }

      final result = await PdfEngine.convertImagesToPdf(
        images: items,
        docName: _docTitle,
        addPageNumbers: true,
      );

      final historyEntry = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        path: result.path,
        pages: result.pages,
        size: result.sizeStr,
        date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        toolType: 'Doc Scanner',
      );

      widget.onAddHistoryItem?.call(historyEntry);

      if (mounted) {
        setState(() => _isSaving = false);
        // Show PDF export modal
        ExportModalSheet.show(
          context: context,
          pdfPath: result.path,
          docName: result.name,
          pages: result.pages,
          sizeStr: result.sizeStr,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Error: $e')));
      }
    }
  }

  Future<void> _saveToDocSets() async {
    setState(() => _isSaving = true);
    try {
      await _renderAllPagesSynchronously();

      final now = DateTime.now();
      final List<DocPage> docPages = [];
      for (int i = 0; i < _pages.length; i++) {
        final p = _pages[i];
        final f = File(p.processedImagePath);
        final size = await f.exists() ? await f.length() : 0;
        docPages.add(
          DocPage(
            id: 'page_${now.millisecondsSinceEpoch}_${i + 1}',
            imagePath: p.processedImagePath,
            name: '${i + 1}',
            sizeBytes: size,
            date: now,
            isNew: true,
          ),
        );
      }

      final newSet = DocumentSet(
        id: 'set_${now.millisecondsSinceEpoch}',
        title: _docTitle,
        createdAt: now,
        updatedAt: now,
        pages: docPages,
        category: 'All docs',
        isFavourite: false,
      );

      // Save to StorageEngine
      final currentSets = await StorageEngine.loadDocSets();
      currentSets.insert(0, newSet);
      await StorageEngine.saveDocSets(currentSets);

      widget.onSaveDocumentSet?.call(newSet);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Saved "${newSet.title}" with ${newSet.pageCount} pages'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, newSet);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF0F1015) : const Color(0xFF1E2024);
    final cardBg = widget.isDark ? const Color(0xFF1A1C23) : const Color(0xFF2B2D38);

    if (_pages.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: Text('No pages scanned', style: TextStyle(color: Colors.white))),
      );
    }

    final activePage = _pages[_currentPageIndex];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _editTitleDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _docTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded, color: Color(0xFFFA9282), size: 16),
            ],
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentPageIndex + 1} / ${_pages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFA9282),
                foregroundColor: const Color(0xFF141518),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _isSaving ? null : _onFinishPressed,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Center PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final displayPath = page.processedImagePath;

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ColorFiltered(
                          colorFilter: ScannerEngine.getColorFilter(
                            page.filter,
                            brightness: page.brightness,
                            contrast: page.contrast,
                          ),
                          child: RotatedBox(
                            quarterTurns: page.rotationDegrees ~/ 90,
                            child: Image.file(
                              File(displayPath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Thumbnail Carousel (Doc Scanner style)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF141519) : const Color(0xFF1A1C22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        final page = _pages[index];
                        final isSelected = index == _currentPageIndex;

                        return GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            width: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFA9282) : Colors.white24,
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(page.processedImagePath),
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Add Page mini-button
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: GestureDetector(
                      onTap: _addNewPagesSheet,
                      child: Container(
                        width: 48,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions Toolbar (Crop, Filter, Rotate, Retake, Delete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF16171B) : const Color(0xFF262831),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildToolAction(
                    icon: Icons.crop_rounded,
                    label: 'Crop',
                    onTap: _openCropForCurrentPage,
                  ),
                  _buildToolAction(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Filters',
                    onTap: _openFilterForCurrentPage,
                  ),
                  _buildToolAction(
                    icon: Icons.rotate_right_rounded,
                    label: 'Rotate',
                    onTap: _rotateCurrentPage,
                  ),
                  _buildToolAction(
                    icon: Icons.replay_rounded,
                    label: 'Retake',
                    onTap: _retakeCurrentPage,
                  ),
                  _buildToolAction(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: const Color(0xFFEF4444),
                    onTap: _deleteCurrentPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
