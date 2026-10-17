import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/scanner_engine.dart';
import '../services/storage_engine.dart';
import 'document_crop_screen.dart';
import 'scanner_batch_editor_screen.dart';
import 'signature_scanner_screen.dart';

class ScannerTab extends StatefulWidget {
  final bool isDark;
  final Function(SelectedImageItem) onAddScannedImage;
  final Function(HistoryItem) onAddHistoryItem;

  const ScannerTab({
    super.key,
    required this.isDark,
    required this.onAddScannedImage,
    required this.onAddHistoryItem,
  });

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<ScannedPageData> _scannedPages = [];
  DocScanMode _selectedMode = DocScanMode.document;

  bool _isFlashOn = false;
  bool _showGrid = false;
  bool _isProcessing = false;
  String? _idCardFrontPath;

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

  Future<void> _captureFromCamera() async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 98,
      );

      if (file == null) return;
      setState(() => _isProcessing = true);

      // 1. ID CARD MODE
      if (_selectedMode == DocScanMode.idCard) {
        if (_idCardFrontPath == null) {
          setState(() {
            _idCardFrontPath = file.path;
            _isProcessing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Front side captured! Now scan ID Back side.'),
                backgroundColor: Color(0xFF0288D1),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        } else {
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

      // 2. BOOK SPREAD MODE
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

      // 3. SIGNATURE MODE
      if (_selectedMode == DocScanMode.signature) {
        setState(() => _isProcessing = false);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => SignatureScannerScreen(
                initialImagePath: file.path,
                isDark: widget.isDark,
                onAddHistoryItem: widget.onAddHistoryItem,
              ),
            ),
          );
        }
        return;
      }

      // 4. SINGLE PAGE MODE
      if (_selectedMode == DocScanMode.single) {
        setState(() => _isProcessing = false);
        final initialPage = ScannedPageData(
          id: 'p_${DateTime.now().millisecondsSinceEpoch}',
          rawImagePath: file.path,
          processedImagePath: file.path,
          quad: QuadPoints.inset(0.05),
          filter: DocScanFilter.magicColor,
        );

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

      // 4. DOCUMENT / BATCH MODE
      final page = ScannedPageData(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}_${_scannedPages.length}',
        rawImagePath: file.path,
        processedImagePath: file.path,
        quad: QuadPoints.inset(0.05),
        filter: DocScanFilter.magicColor,
      );

      _scannedPages.add(page);
      _renderBackground(page);
      setState(() => _isProcessing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Page ${_scannedPages.length} captured! Tap shutter for next or Done.'),
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
          onAddHistoryItem: (item) {
            widget.onAddHistoryItem(item);
            setState(() => _scannedPages.clear());
          },
          onSaveDocumentSet: (set) async {
            final currentSets = await StorageEngine.loadDocSets();
            currentSets.insert(0, set);
            await StorageEngine.saveDocSets(currentSets);
            setState(() => _scannedPages.clear());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF141518) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : const Color(0xFFF1F5F9);
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFA9282).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Color(0xFFFA9282), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Document Scanner',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                      color: _showGrid ? const Color(0xFFFA9282) : Colors.grey,
                      size: 22,
                    ),
                    tooltip: 'Grid Lines',
                    onPressed: () => setState(() => _showGrid = !_showGrid),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isFlashOn ? const Color(0xFFFBBF24) : Colors.grey,
                      size: 22,
                    ),
                    tooltip: 'Flash',
                    onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
                  ),
                ],
              ),
            ),

            // Main Viewfinder Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxW = constraints.maxWidth;
                    final boxH = constraints.maxHeight;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Frame
                        Container(
                          width: boxW,
                          height: boxH,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                        ),

                        // Rule of Thirds Grid (Optional)
                        if (_showGrid)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: TabViewfinderGridPainter(),
                            ),
                          ),

                        // Corner Alignment Reticles
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
                                color: const Color(0xFF0288D1).withValues(alpha: 0.8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0288D1).withValues(alpha: 0.5),
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
                                      color: const Color(0xFFFA9282).withValues(alpha: 0.7),
                                      blurRadius: 10,
                                      spreadRadius: 1.5,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Illustration / Instructions
                        if (_scannedPages.isEmpty)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFA9282).withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.document_scanner_rounded, color: Color(0xFFFA9282), size: 36),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Align Document within Frame',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Auto edge detection & Magic Color filters active',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_scannedPages.last.processedImagePath),
                                  width: 170,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '✓ ${_scannedPages.length} Page(s) Scanned',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Center Mode Guidance Status Pill
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: (widget.isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getModeStatusIcon(),
                                  color: const Color(0xFFFA9282),
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getModeStatusText(),
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12,
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
              height: 42,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildModePill(DocScanMode.document, 'DOCUMENT'),
                  _buildModePill(DocScanMode.idCard, 'ID CARD'),
                  _buildModePill(DocScanMode.signature, 'SIGNATURE'),
                  _buildModePill(DocScanMode.book, 'BOOK / SPREAD'),
                  _buildModePill(DocScanMode.batch, 'BATCH SCAN'),
                  _buildModePill(DocScanMode.single, 'SINGLE PAGE'),
                ],
              ),
            ),

            // Bottom Shutter Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
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
                        color: widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: widget.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: widget.isDark ? Colors.white70 : const Color(0xFF0F172A),
                        size: 24,
                      ),
                    ),
                  ),

                  // Main Haptic Shutter Button
                  GestureDetector(
                    onTap: _captureFromCamera,
                    child: Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFA9282).withValues(alpha: 0.7),
                          width: 4,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isProcessing ? Colors.grey : const Color(0xFFFA9282),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFA9282).withValues(alpha: 0.4),
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

                  // Batch Preview & Proceed Button
                  GestureDetector(
                    onTap: _openBatchEditor,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _scannedPages.isNotEmpty
                            ? const Color(0xFFFA9282).withValues(alpha: 0.2)
                            : (widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _scannedPages.isNotEmpty ? const Color(0xFFFA9282) : Colors.grey.withValues(alpha: 0.3),
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
                            Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.withValues(alpha: 0.5), size: 18),

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
          color: isSelected ? const Color(0xFFFA9282) : (widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFA9282) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF141518) : (widget.isDark ? Colors.white70 : const Color(0xFF64748B)),
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
      case DocScanMode.signature:
        return Icons.draw_rounded;
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
      case DocScanMode.signature:
        return 'Frame signature on paper & capture';
      case DocScanMode.book:
        return 'Center open book spine on blue line';
      case DocScanMode.batch:
        return 'Batch Mode • Rapid continuous scanning';
      case DocScanMode.single:
        return 'Single Page Mode • Auto crop & filter';
    }
  }
}

class TabViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
