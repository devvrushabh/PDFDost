import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/space_empty_illustration.dart';

class ImageToPdfScreen extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const ImageToPdfScreen({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected Images, 1: Converted PDFs
  bool _isSpeedDialOpen = false;
  bool _isConverting = false;

  final List<SelectedImageItem> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _docNameController;
  String _pageOrientation = 'Portrait'; // Portrait, Landscape, Auto
  final String _pageSize = 'A4'; // A4, Letter
  double _pageMargin = 16.0; // 0.0 (None), 8.0 (Compact), 16.0 (Standard)
  bool _addPageNumbers = false;

  late AnimationController _fabAnimController;
  late Animation<double> _fabRotationAnim;

  List<HistoryItem> get _convertedHistory {
    return widget.historyItems.where((item) => item.toolType == 'Image to PDF').toList();
  }

  @override
  void initState() {
    super.initState();
    _docNameController = TextEditingController(
      text: 'Image_Doc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );

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
    _docNameController.dispose();
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

  Future<void> _pickImagesFromGallery() async {
    _closeSpeedDial();
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final List<SelectedImageItem> newItems = [];
        for (final img in images) {
          final file = File(img.path);
          if (await file.exists()) {
            final size = await file.length();
            final name = img.name.isNotEmpty ? img.name : file.path.split(Platform.pathSeparator).last;
            newItems.add(SelectedImageItem(path: file.path, name: name, sizeBytes: size));
          }
        }

        if (newItems.isNotEmpty) {
          setState(() {
            for (final item in newItems) {
              if (!_selectedImages.any((e) => e.path == item.path)) {
                _selectedImages.add(item);
              }
            }
            _activeChip = 0;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newItems.length} image(s) to convert list'),
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
            content: Text('Error selecting images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _capturePhotoFromCamera() async {
    _closeSpeedDial();
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (photo != null) {
        final file = File(photo.path);
        if (await file.exists()) {
          final size = await file.length();
          final name = photo.name.isNotEmpty ? photo.name : 'Photo_${DateFormat('HHmmss').format(DateTime.now())}.jpg';
          setState(() {
            _selectedImages.add(SelectedImageItem(path: file.path, name: name, sizeBytes: size));
            _activeChip = 0;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo added to convert list'),
                backgroundColor: Color(0xFF10B981),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _rotateImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedImages[index].rotationDegrees = (_selectedImages[index].rotationDegrees + 90) % 360;
    });
  }

  void _moveImage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _selectedImages.length) return;
    setState(() {
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _clearSelectedImages() {
    setState(() {
      _selectedImages.clear();
    });
  }

  void _previewImage(SelectedImageItem item, int index) {
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
              title: Text('Page ${index + 1}: ${item.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                  child: File(item.path).existsSync()
                      ? Transform.rotate(
                          angle: (item.rotationDegrees * math.pi) / 180,
                          child: Image.file(File(item.path), fit: BoxFit.contain),
                        )
                      : const Center(child: Text('Image file unavailable')),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Size: ${item.formattedSize}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.rotate_right_rounded, color: Color(0xFF2563EB)),
                        tooltip: 'Rotate 90°',
                        onPressed: () {
                          _rotateImage(index);
                          Navigator.pop(ctx);
                          _previewImage(_selectedImages[index], index);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _removeImage(index);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertToPdf() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 image to convert to PDF'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    var docName = _docNameController.text.trim();
    if (docName.isEmpty) {
      docName = 'Image_Doc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    }
    if (docName.toLowerCase().endsWith('.pdf')) {
      docName = docName.substring(0, docName.length - 4);
    }

    setState(() => _isConverting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await PdfEngine.convertImagesToPdf(
        images: _selectedImages,
        docName: docName,
        addPageNumbers: _addPageNumbers,
        orientation: _pageOrientation,
        pageSize: _pageSize,
        margin: _pageMargin,
      );

      final newHistory = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        path: result.path,
        pages: result.pages,
        size: result.sizeStr,
        date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        toolType: 'Image to PDF',
      );

      widget.onAddHistoryItem(newHistory);

      if (mounted) {
        setState(() {
          _isConverting = false;
          _selectedImages.clear();
          _activeChip = 1; // Show converted tab
        });

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
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversion failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHistoryActions(HistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: Color(0xFF2563EB)),
                title: const Text('Open / View PDF'),
                onTap: () {
                  Navigator.pop(ctx);
                  OpenFilex.open(item.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFFE5322D)),
                title: const Text('Share Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(item.path, mimeType: 'application/pdf')], text: item.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF16A34A)),
                title: const Text('Save to Downloads'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await StorageEngine.saveToDownloads(item.path, item.name);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '✓ Saved to Downloads' : 'Save failed'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              if (widget.onDeleteHistoryItem != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text('Delete from List', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onDeleteHistoryItem!(item);
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = widget.isDark ? const Color(0xFF141518) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Image to PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: primaryTextColor,
              ),
            ),
            Text(
              'Convert pictures into high quality PDF',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2563EB)),
            tooltip: 'Add Images',
            onPressed: _pickImagesFromGallery,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Top Segmented Filter Chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    // Chip 0: Selected Images
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeChip = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeChip == 0
                                ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                                : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _activeChip == 0
                                  ? (widget.isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8))
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: _activeChip == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_rounded,
                                color: _activeChip == 0 ? const Color(0xFF2563EB) : secondaryTextColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Selected Images',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeChip == 0 ? primaryTextColor : secondaryTextColor,
                                ),
                              ),
                              if (_selectedImages.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_selectedImages.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Chip 1: Converted PDFs
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeChip = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeChip == 1
                                ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                                : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _activeChip == 1
                                  ? (widget.isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8))
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                            boxShadow: _activeChip == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: _activeChip == 1 ? const Color(0xFFE5322D) : secondaryTextColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Converted PDFs',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _activeChip == 1 ? primaryTextColor : secondaryTextColor,
                                ),
                              ),
                              if (_convertedHistory.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5322D),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_convertedHistory.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Body View
              Expanded(
                child: _activeChip == 0 ? _buildSelectedImagesView() : _buildConvertedHistoryView(),
              ),

              // 3. Bottom Sticky Action Bar (When images selected & on Chip 0)
              if (_activeChip == 0 && _selectedImages.isNotEmpty)
                _buildConvertBottomBar(),
            ],
          ),

          // Speed Dial Overlay
          if (_isSpeedDialOpen)
            GestureDetector(
              onTap: _closeSpeedDial,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

          // Speed Dial Options & FAB
          Positioned(
            right: 20,
            bottom: (_activeChip == 0 && _selectedImages.isNotEmpty) ? 90 : 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isSpeedDialOpen) ...[
                  // Option 1: Camera
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                          ],
                        ),
                        child: Text(
                          'Take Photo',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton.small(
                        heroTag: 'camera_btn',
                        backgroundColor: const Color(0xFFF59E0B),
                        onPressed: _capturePhotoFromCamera,
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Option 2: Gallery
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6),
                          ],
                        ),
                        child: Text(
                          'Pick Gallery Images',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton.small(
                        heroTag: 'gallery_btn',
                        backgroundColor: const Color(0xFF2563EB),
                        onPressed: _pickImagesFromGallery,
                        child: const Icon(Icons.photo_library_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Main Speed Dial FAB
                FloatingActionButton(
                  heroTag: 'speed_dial_main',
                  backgroundColor: const Color(0xFF2563EB),
                  elevation: 4,
                  onPressed: _toggleSpeedDial,
                  child: RotationTransition(
                    turns: _fabRotationAnim,
                    child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedImagesView() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_selectedImages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpaceEmptyIllustration(
                title: 'No images selected yet',
                subtitle: 'Choose pictures from your photo gallery or take new photos to convert them into a PDF',
                isDark: widget.isDark,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                    label: const Text('Pick Images', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _pickImagesFromGallery,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 20),
                    label: const Text('Camera', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    onPressed: _capturePhotoFromCamera,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Top Action Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_selectedImages.length} Image(s) in Conversion Queue',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: secondaryTextColor,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _clearSelectedImages,
                  child: const Text('Clear All', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // List of Images with controls
        ...List.generate(_selectedImages.length, (index) {
          final item = _selectedImages[index];
          final file = File(item.path);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              leading: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: file.existsSync()
                          ? Transform.rotate(
                              angle: (item.rotationDegrees * math.pi) / 180,
                              child: Image.file(file, fit: BoxFit.cover),
                            )
                          : Container(
                              color: Colors.grey.withValues(alpha: 0.2),
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    left: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
              ),
              subtitle: Text(
                'Page ${index + 1} • ${item.formattedSize}${item.rotationDegrees > 0 ? ' • Rotated ${item.rotationDegrees}°' : ''}',
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Move Up
                  if (index > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Move Up',
                      onPressed: () => _moveImage(index, index - 1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  // Move Down
                  if (index < _selectedImages.length - 1) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                      tooltip: 'Move Down',
                      onPressed: () => _moveImage(index, index + 1),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Rotate
                  IconButton(
                    icon: const Icon(Icons.rotate_right_rounded, size: 19, color: Color(0xFF2563EB)),
                    tooltip: 'Rotate 90°',
                    onPressed: () => _rotateImage(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Delete
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFFEF4444)),
                    tooltip: 'Remove',
                    onPressed: () => _removeImage(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              onTap: () => _previewImage(item, index),
            ),
          );
        }),

        const SizedBox(height: 12),

        // PDF Output Settings Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PDF Document Settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Document Name Input
              Text('Document Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF141518) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _docNameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 13),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter PDF name'),
                      ),
                    ),
                    const Text('.pdf', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Page Orientation
              Text('Page Orientation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor)),
              const SizedBox(height: 6),
              Row(
                children: ['Portrait', 'Landscape', 'Auto'].map((opt) {
                  final isSelected = _pageOrientation == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(opt, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.18),
                      onSelected: (val) => setState(() => _pageOrientation = opt),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Page Margins
              Text('Margins', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor)),
              const SizedBox(height: 6),
              Row(
                children: [
                  {'label': 'No Margin', 'val': 0.0},
                  {'label': 'Compact (8pt)', 'val': 8.0},
                  {'label': 'Standard (16pt)', 'val': 16.0},
                ].map((opt) {
                  final isSelected = _pageMargin == opt['val'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(opt['label'] as String, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.18),
                      onSelected: (val) => setState(() => _pageMargin = opt['val'] as double),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Page Numbers Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF2563EB),
                title: Text('Add Page Numbers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor)),
                subtitle: Text('Print "Page X of Y" at the bottom of each page', style: TextStyle(fontSize: 11.5, color: secondaryTextColor)),
                value: _addPageNumbers,
                onChanged: (val) => setState(() => _addPageNumbers = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildConvertBottomBar() {
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isConverting ? null : _convertToPdf,
            child: _isConverting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Converting Images to PDF...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Convert ${_selectedImages.length} Image${_selectedImages.length == 1 ? '' : 's'} to PDF',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildConvertedHistoryView() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_convertedHistory.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: 'No converted PDFs yet',
          subtitle: 'Converted Image-to-PDF documents will appear here automatically',
          isDark: widget.isDark,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _convertedHistory.length,
      itemBuilder: (ctx, index) {
        final item = _convertedHistory[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 24),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: primaryTextColor,
              ),
            ),
            subtitle: Text(
              '${item.pages} page(s) • ${item.size} • ${item.date}',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            trailing: IconButton(
              icon: Icon(Icons.more_vert_rounded, color: secondaryTextColor),
              onPressed: () => _showHistoryActions(item),
            ),
            onTap: () => OpenFilex.open(item.path),
          ),
        );
      },
    );
  }
}
