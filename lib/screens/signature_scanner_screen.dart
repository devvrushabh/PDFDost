import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/scanner_engine.dart';
import '../models/models.dart';

class SignatureScannerScreen extends StatefulWidget {
  final String? initialImagePath;
  final bool isDark;
  final Function(HistoryItem)? onAddHistoryItem;

  const SignatureScannerScreen({
    super.key,
    this.initialImagePath,
    required this.isDark,
    this.onAddHistoryItem,
  });

  @override
  State<SignatureScannerScreen> createState() => _SignatureScannerScreenState();
}

class _SignatureScannerScreenState extends State<SignatureScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _sourceImagePath;
  String? _extractedSignaturePath;
  bool _isProcessing = false;

  // Signature customization parameters
  Color _selectedPenColor = const Color(0xFF1565C0); // Royal Blue default
  double _threshold = 0.68;
  double _contrast = 1.25;
  int _rotationDegrees = 0;

  static const List<Map<String, dynamic>> _penColors = [
    {'name': 'Royal Blue', 'color': Color(0xFF1565C0)},
    {'name': 'Deep Black', 'color': Color(0xFF111827)},
    {'name': 'Crimson Red', 'color': Color(0xFFB91C1C)},
    {'name': 'Emerald Green', 'color': Color(0xFF047857)},
    {'name': 'Imperial Purple', 'color': Color(0xFF4C1D95)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _sourceImagePath = widget.initialImagePath;
      _processSignature();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 98);
      if (file == null) return;
      setState(() {
        _sourceImagePath = file.path;
        _rotationDegrees = 0;
      });
      await _processSignature();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
      }
    }
  }

  Future<void> _processSignature() async {
    if (_sourceImagePath == null) return;
    setState(() => _isProcessing = true);

    try {
      final outPath = await ScannerEngine.extractTransparentSignature(
        sourcePath: _sourceImagePath!,
        penColor: _selectedPenColor,
        threshold: _threshold,
        contrast: _contrast,
        rotationDegrees: _rotationDegrees,
      );

      if (mounted) {
        setState(() {
          _extractedSignaturePath = outPath;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting signature: $e')),
        );
      }
    }
  }

  void _rotateSignature() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
    _processSignature();
  }

  Future<void> _shareSignature() async {
    if (_extractedSignaturePath == null) return;
    HapticFeedback.lightImpact();
    await Share.shareXFiles(
      [XFile(_extractedSignaturePath!)],
      text: 'My Signature (Transparent PNG) created with PDFDost',
    );
  }

  Future<void> _saveSignature() async {
    if (_extractedSignaturePath == null) return;
    HapticFeedback.mediumImpact();

    if (widget.onAddHistoryItem != null) {
      final file = File(_extractedSignaturePath!);
      final sizeBytes = await file.length();
      final sizeStr = sizeBytes < 1024
          ? '$sizeBytes B'
          : sizeBytes < 1024 * 1024
              ? '${(sizeBytes / 1024).toStringAsFixed(1)} KB'
              : '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

      final historyEntry = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Signature_${DateTime.now().millisecondsSinceEpoch}.png',
        path: _extractedSignaturePath!,
        pages: 1,
        size: sizeStr,
        date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        toolType: 'Signature Scanner',
      );
      widget.onAddHistoryItem!(historyEntry);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Transparent Signature saved successfully!'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, _extractedSignaturePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0F172A);
    const bgLight = Color(0xFFF8FAFC);
    const cardDark = Color(0xFF1E293B);
    const cardLight = Colors.white;
    const textDark = Colors.white;
    const textLight = Color(0xFF0F172A);

    final currentBg = widget.isDark ? bgDark : bgLight;
    final currentCard = widget.isDark ? cardDark : cardLight;
    final currentText = widget.isDark ? textDark : textLight;

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        title: const Text('Signature Studio', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: currentText,
        elevation: 0,
        actions: [
          if (_extractedSignaturePath != null) ...[
            IconButton(
              icon: const Icon(Icons.rotate_right_rounded),
              tooltip: 'Rotate 90°',
              onPressed: _rotateSignature,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share PNG',
              onPressed: _shareSignature,
            ),
            TextButton.icon(
              onPressed: _saveSignature,
              icon: const Icon(Icons.check_rounded, color: Color(0xFF10B981)),
              label: const Text('SAVE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: _sourceImagePath == null ? _buildEmptyState(currentText, currentCard) : _buildEditor(currentText, currentCard),
    );
  }

  Widget _buildEmptyState(Color currentText, Color currentCard) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.draw_rounded, size: 72, color: Color(0xFF0288D1)),
            ),
            const SizedBox(height: 24),
            Text(
              'Capture Signature from Paper',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: currentText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sign on any white paper with a pen, then snap a photo. PDFDost automatically removes the paper background and extracts a crisp, transparent digital signature.',
              style: TextStyle(fontSize: 14, color: currentText.withValues(alpha: 0.65), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: currentText,
                    side: BorderSide(color: currentText.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor(Color currentText, Color currentCard) {
    return Column(
      children: [
        // Live Preview Canvas with Checkered Transparency Background
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: currentCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: currentText.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Checkered pattern for transparent PNG preview
                  CustomPaint(
                    painter: _TransparencyGridPainter(isDark: widget.isDark),
                  ),
                  if (_extractedSignaturePath != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Image.file(
                          File(_extractedSignaturePath!),
                          fit: BoxFit.contain,
                          key: ValueKey('$_extractedSignaturePath$_rotationDegrees$_threshold$_selectedPenColor'),
                        ),
                      ),
                    ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 12),
                            Text('Isolating ink strokes...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Controls Sheet
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: currentCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pen Ink Color Selector
                  Text('Ink Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: currentText)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: _penColors.map((item) {
                      final c = item['color'] as Color;
                      final isSelected = _selectedPenColor.toARGB32() == c.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedPenColor = c);
                          _processSignature();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0288D1) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: c,
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Background Removal Sensitivity (Threshold)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Background Cleansing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: currentText)),
                      Text('${(_threshold * 100).toInt()}%', style: TextStyle(fontSize: 12, color: currentText.withValues(alpha: 0.6))),
                    ],
                  ),
                  Slider(
                    value: _threshold,
                    min: 0.35,
                    max: 0.90,
                    activeColor: const Color(0xFF0288D1),
                    onChanged: (val) => setState(() => _threshold = val),
                    onChangeEnd: (val) => _processSignature(),
                  ),

                  // Ink Thickness / Contrast
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Ink Darkness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: currentText)),
                      Text('${(_contrast * 10).toInt() / 10}x', style: TextStyle(fontSize: 12, color: currentText.withValues(alpha: 0.6))),
                    ],
                  ),
                  Slider(
                    value: _contrast,
                    min: 0.8,
                    max: 2.2,
                    activeColor: const Color(0xFF0288D1),
                    onChanged: (val) => setState(() => _contrast = val),
                    onChangeEnd: (val) => _processSignature(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransparencyGridPainter extends CustomPainter {
  final bool isDark;
  _TransparencyGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 12.0;
    final paint1 = Paint()..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final paint2 = Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white;

    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        final isEven = ((x / cellSize).toInt() + (y / cellSize).toInt()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TransparencyGridPainter oldDelegate) => oldDelegate.isDark != isDark;
}
