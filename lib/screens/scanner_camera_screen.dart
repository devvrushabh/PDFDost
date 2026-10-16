import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/scanner_engine.dart';
import 'document_crop_screen.dart';
import 'scanner_batch_editor_screen.dart';

class ScannerCameraScreen extends StatefulWidget {
  final bool isDark;
  final Function(DocumentSet)? onSaveDocumentSet;
  final Function(HistoryItem)? onAddHistoryItem;

  const ScannerCameraScreen({
    super.key,
    required this.isDark,
    this.onSaveDocumentSet,
    this.onAddHistoryItem,
  });

  @override
  State<ScannerCameraScreen> createState() => _ScannerCameraScreenState();
}

class _ScannerCameraScreenState extends State<ScannerCameraScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<ScannedPageData> _scannedPages = [];
  DocScanMode _selectedMode = DocScanMode.document;

  // Camera settings
  bool _isFlashOn = false;
  bool _showGrid = false;
  bool _autoCropImmediate = true;
  bool _isProcessing = false;

  // ID Card mode state (front / back)
  String? _idCardFrontPath;

  // Laser animation controller
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  // --- CAPTURE & WORKFLOW LOGIC ---

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 98,
      );

      if (file == null) return;
      setState(() => _isProcessing = true);

      // 1. ID CARD WORKFLOW
      if (_selectedMode == DocScanMode.idCard) {
        if (_idCardFrontPath == null) {
          // Front captured, prompt for back
          setState(() {
            _idCardFrontPath = file.path;
            _isProcessing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Front side captured! Now flip and scan the Back side.'),
                backgroundColor: Color(0xFF0288D1),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        } else {
          // Back captured, composite both
          final compositePath = await ScannerEngine.generateIdCardComposite(
            frontPath: _idCardFrontPath!,
            backPath: file.path,
          );
          final pageData = ScannedPageData(
            id: 'id_${DateTime.now().millisecondsSinceEpoch}',
            rawImagePath: compositePath,
            processedImagePath: compositePath,
            filter: DocScanFilter.vibrant,
          );
          setState(() {
            _idCardFrontPath = null;
            _scannedPages.add(pageData);
            _isProcessing = false;
          });
          _openBatchEditor();
          return;
        }
      }

      // 2. BOOK SPREAD WORKFLOW
      if (_selectedMode == DocScanMode.book) {
        final splitPaths = await ScannerEngine.splitBookSpread(file.path);
        for (final p in splitPaths) {
          final page = ScannedPageData(
            id: 'book_${DateTime.now().millisecondsSinceEpoch}_${_scannedPages.length}',
            rawImagePath: p,
            processedImagePath: p,
            quad: QuadPoints.inset(0.04),
            filter: DocScanFilter.magicColor,
          );
          _scannedPages.add(page);
          _renderBackground(page);
        }
        setState(() => _isProcessing = false);
        _openBatchEditor();
        return;
      }

      // 3. SINGLE PAGE OR BATCH/DOCUMENT WORKFLOW
      final initialPage = ScannedPageData(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}_${_scannedPages.length}',
        rawImagePath: file.path,
        processedImagePath: file.path,
        quad: QuadPoints.inset(0.05),
        filter: DocScanFilter.magicColor,
      );

      if (_selectedMode == DocScanMode.single) {
        // In Single mode, immediately open Crop -> Filter -> Editor
        setState(() => _isProcessing = false);
        final cropResult = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder: (ctx) => DocumentCropScreen(
              imagePath: initialPage.rawImagePath,
              isDark: widget.isDark,
              initialQuad: initialPage.quad,
            ),
          ),
        );

        if (cropResult != null) {
          initialPage.quad = cropResult['quad'] as QuadPoints;
          initialPage.rotationDegrees = cropResult['rotation'] as int;
        }

        final rendered = await ScannerEngine.renderAndSavePage(
          sourcePath: initialPage.rawImagePath,
          quad: initialPage.quad,
          filter: initialPage.filter,
          rotationDegrees: initialPage.rotationDegrees,
        );
        initialPage.processedImagePath = rendered;

        _scannedPages.add(initialPage);
        _openBatchEditor();
        return;
      }

      // In Document or Batch mode:
      _scannedPages.add(initialPage);
      _renderBackground(initialPage);
      setState(() => _isProcessing = false);

      // If document mode and only 1 page so far and not continuous batch, let user keep shooting or proceed
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Page ${_scannedPages.length} captured! Tap shutter for next page or Done.'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _renderBackground(ScannedPageData page) async {
    try {
      final out = await ScannerEngine.renderAndSavePage(
        sourcePath: page.rawImagePath,
        quad: page.quad,
        filter: page.filter,
        rotationDegrees: page.rotationDegrees,
      );
      if (mounted) {
        setState(() {
          page.processedImagePath = out;
        });
      }
    } catch (_) {}
  }

  Future<void> _importFromGallery() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      if (files.isNotEmpty) {
        setState(() => _isProcessing = true);
        for (final f in files) {
          final page = ScannedPageData(
            id: 'imp_${DateTime.now().millisecondsSinceEpoch}_${_scannedPages.length}',
            rawImagePath: f.path,
            processedImagePath: f.path,
            quad: QuadPoints.inset(0.04),
            filter: DocScanFilter.magicColor,
          );
          _scannedPages.add(page);
          _renderBackground(page);
        }
        setState(() => _isProcessing = false);
        _openBatchEditor();
      }
    } catch (_) {
      setState(() => _isProcessing = false);
    }
  }

  void _openBatchEditor() {
    if (_scannedPages.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ScannerBatchEditorScreen(
          initialPages: _scannedPages,
          isDark: widget.isDark,
          onSaveDocumentSet: (set) {
            widget.onSaveDocumentSet?.call(set);
            Navigator.pop(context); // Close camera screen
          },
          onAddHistoryItem: (item) {
            widget.onAddHistoryItem?.call(item);
            Navigator.pop(context); // Close camera screen
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0F1015);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Camera Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      color: _showGrid ? const Color(0xFFFA9282) : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Rule of Thirds Grid',
                    onPressed: () => setState(() => _showGrid = !_showGrid),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isFlashOn ? const Color(0xFFFBBF24) : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Flash Mode',
                    onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
                  ),
                  IconButton(
                    icon: Icon(
                      _autoCropImmediate ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
                      color: _autoCropImmediate ? const Color(0xFFFA9282) : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Auto Edge Detection',
                    onPressed: () => setState(() => _autoCropImmediate = !_autoCropImmediate),
                  ),
                ],
              ),
            ),

            // Main Viewfinder Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxW = constraints.maxWidth;
                    final boxH = constraints.maxHeight;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Viewfinder Frame Outline
                        Container(
                          width: boxW,
                          height: boxH,
                          decoration: BoxDecoration(
                            color: const Color(0xFF161820),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // Rule of Thirds Grid (Optional)
                        if (_showGrid)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ViewfinderGridPainter(),
                            ),
                          ),

                        // Corner Alignment Reticles (Doc Scanner Cam style)
                        _buildReticleCorner(top: 18, left: 18, isTL: true),
                        _buildReticleCorner(top: 18, right: 18, isTR: true),
                        _buildReticleCorner(bottom: 18, left: 18, isBL: true),
                        _buildReticleCorner(bottom: 18, right: 18, isBR: true),

                        // Center Book Split Line if in Book Mode
                        if (_selectedMode == DocScanMode.book)
                          Positioned(
                            top: 24,
                            bottom: 24,
                            child: Container(
                              width: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0288D1).withOpacity(0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0288D1).withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Holographic Laser Sweep Effect
                        AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top: boxH * _laserAnimation.value,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFFFA9282),
                                      Colors.white,
                                      Color(0xFFFA9282),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFA9282).withOpacity(0.7),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Guide Message / Status Pill
                        Positioned(
                          bottom: 24,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getModeStatusIcon(),
                                  color: const Color(0xFFFA9282),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getModeStatusText(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Horizontal Scanner Mode Selector Bar
            Container(
              height: 44,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildModePill(DocScanMode.document, 'DOCUMENT'),
                  _buildModePill(DocScanMode.idCard, 'ID CARD'),
                  _buildModePill(DocScanMode.book, 'BOOK / SPREAD'),
                  _buildModePill(DocScanMode.batch, 'BATCH SCAN'),
                  _buildModePill(DocScanMode.single, 'SINGLE PAGE'),
                ],
              ),
            ),

            // Bottom Shutter Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery Import Button
                  GestureDetector(
                    onTap: _importFromGallery,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                    ),
                  ),

                  // Main Haptic Shutter Button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 82,
                      height: 82,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFA9282).withOpacity(0.8),
                          width: 4,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isProcessing ? Colors.grey : const Color(0xFFFA9282),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA9282).withOpacity(0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                            : const Icon(Icons.camera_alt_rounded, color: Color(0xFF141518), size: 34),
                      ),
                    ),
                  ),

                  // Batch Preview & Done Button
                  GestureDetector(
                    onTap: _openBatchEditor,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _scannedPages.isNotEmpty
                            ? const Color(0xFFFA9282).withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _scannedPages.isNotEmpty ? const Color(0xFFFA9282) : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_scannedPages.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(_scannedPages.last.processedImagePath),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 20),

                          // Count Badge
                          if (_scannedPages.isNotEmpty)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFA9282),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_scannedPages.length}',
                                  style: const TextStyle(color: Color(0xFF141518), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModePill(DocScanMode mode, String label) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _idCardFrontPath = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFA9282) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFA9282) : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF141518) : Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReticleCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool isTL = false,
    bool isTR = false,
    bool isBL = false,
    bool isBR = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          border: Border(
            top: (isTL || isTR) ? const BorderSide(color: Color(0xFFFA9282), width: 3.5) : BorderSide.none,
            bottom: (isBL || isBR) ? const BorderSide(color: Color(0xFFFA9282), width: 3.5) : BorderSide.none,
            left: (isTL || isBL) ? const BorderSide(color: Color(0xFFFA9282), width: 3.5) : BorderSide.none,
            right: (isTR || isBR) ? const BorderSide(color: Color(0xFFFA9282), width: 3.5) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  IconData _getModeStatusIcon() {
    switch (_selectedMode) {
      case DocScanMode.document:
        return Icons.document_scanner_rounded;
      case DocScanMode.idCard:
        return Icons.badge_rounded;
      case DocScanMode.book:
        return Icons.menu_book_rounded;
      case DocScanMode.batch:
        return Icons.auto_awesome_motion_rounded;
      case DocScanMode.single:
        return Icons.crop_free_rounded;
    }
  }

  String _getModeStatusText() {
    switch (_selectedMode) {
      case DocScanMode.document:
        return _scannedPages.isEmpty
            ? 'Align document inside frame'
            : '${_scannedPages.length} Page(s) scanned • Tap shutter to add more';
      case DocScanMode.idCard:
        return _idCardFrontPath == null ? 'Scan ID Front Side' : 'Scan ID Back Side';
      case DocScanMode.book:
        return 'Center open book spine on blue line';
      case DocScanMode.batch:
        return 'Batch Mode • Rapid continuous scanning';
      case DocScanMode.single:
        return 'Single Page Mode • Auto crop & filter';
    }
  }
}

class ViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
