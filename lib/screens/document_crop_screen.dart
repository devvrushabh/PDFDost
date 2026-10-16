import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/scanner_engine.dart';

class DocumentCropScreen extends StatefulWidget {
  final String imagePath;
  final bool isDark;
  final QuadPoints? initialQuad;
  final int initialRotation;

  const DocumentCropScreen({
    super.key,
    required this.imagePath,
    required this.isDark,
    this.initialQuad,
    this.initialRotation = 0,
  });

  @override
  State<DocumentCropScreen> createState() => _DocumentCropScreenState();
}

class _DocumentCropScreenState extends State<DocumentCropScreen> {
  late QuadPoints _quad;
  late int _rotation;
  int? _activeCornerIndex; // 0: TL, 1: TR, 2: BR, 3: BL
  Offset? _touchPosition;

  // Cached image pixel size
  Size _imagePixelSize = const Size(1000, 1400);
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _quad = widget.initialQuad ?? QuadPoints.inset(0.06);
    _rotation = widget.initialRotation;
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() {
        _imagePixelSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
        _isImageLoaded = true;
      });
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  void _resetToFull() {
    setState(() {
      _quad = QuadPoints.full();
    });
  }

  void _autoDetect() {
    setState(() {
      _quad = QuadPoints.inset(0.05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF0F1015) : const Color(0xFF1E2024);
    final isRotated90 = (_rotation % 180) != 0;
    final effectiveAspect = isRotated90
        ? (_imagePixelSize.height / _imagePixelSize.width)
        : (_imagePixelSize.width / _imagePixelSize.height);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop & Adjust Edges',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 24),
            tooltip: 'Rotate 90°',
            onPressed: _rotateClockwise,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
            tooltip: 'Select Full Page',
            onPressed: _resetToFull,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top instructions banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: Color(0xFFFA9282), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Drag the 4 corner handles to align document boundaries.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Center interactive crop canvas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compute letterboxed rect for image display
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;

                  double drawW, drawH;
                  if (maxW / maxH > effectiveAspect) {
                    drawH = maxH;
                    drawW = maxH * effectiveAspect;
                  } else {
                    drawW = maxW;
                    drawH = maxW / effectiveAspect;
                  }

                  final drawRect = Rect.fromLTWH(
                    (maxW - drawW) / 2,
                    (maxH - drawH) / 2,
                    drawW,
                    drawH,
                  );

                  return Stack(
                    children: [
                      // Image Display with Rotation
                      Positioned.fromRect(
                        rect: drawRect,
                        child: RotatedBox(
                          quarterTurns: _rotation ~/ 90,
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),

                      // Interactive Quad Overlay & Handles
                      Positioned.fromRect(
                        rect: drawRect,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (details) {
                            final local = details.localPosition;
                            final nX = (local.dx / drawW).clamp(0.0, 1.0);
                            final nY = (local.dy / drawH).clamp(0.0, 1.0);
                            final norm = Offset(nX, nY);

                            // Find closest corner within touch radius (~44px)
                            final corners = [_quad.topLeft, _quad.topRight, _quad.bottomRight, _quad.bottomLeft];
                            int closest = -1;
                            double minDist = 0.15; // Normalized threshold
                            for (int i = 0; i < 4; i++) {
                              final d = (corners[i] - norm).distance;
                              if (d < minDist) {
                                minDist = d;
                                closest = i;
                              }
                            }
                            if (closest != -1) {
                              setState(() {
                                _activeCornerIndex = closest;
                                _touchPosition = details.globalPosition;
                              });
                            }
                          },
                          onPanUpdate: (details) {
                            if (_activeCornerIndex == null) return;
                            final local = details.localPosition;
                            final nX = (local.dx / drawW).clamp(0.0, 1.0);
                            final nY = (local.dy / drawH).clamp(0.0, 1.0);
                            final norm = Offset(nX, nY);

                            setState(() {
                              _touchPosition = details.globalPosition;
                              switch (_activeCornerIndex) {
                                case 0:
                                  _quad = _quad.copyWith(topLeft: norm);
                                  break;
                                case 1:
                                  _quad = _quad.copyWith(topRight: norm);
                                  break;
                                case 2:
                                  _quad = _quad.copyWith(bottomRight: norm);
                                  break;
                                case 3:
                                  _quad = _quad.copyWith(bottomLeft: norm);
                                  break;
                              }
                            });
                          },
                          onPanEnd: (_) {
                            setState(() {
                              _activeCornerIndex = null;
                              _touchPosition = null;
                            });
                          },
                          onPanCancel: () {
                            setState(() {
                              _activeCornerIndex = null;
                              _touchPosition = null;
                            });
                          },
                          child: CustomPaint(
                            painter: QuadCropPainter(
                              quad: _quad,
                              activeCornerIndex: _activeCornerIndex,
                            ),
                          ),
                        ),
                      ),

                      // Floating Magnifier Loupe (Doc Scanner Signature Feature)
                      if (_activeCornerIndex != null && _touchPosition != null && _isImageLoaded)
                        _buildMagnifierLoupe(drawRect),
                    ],
                  );
                },
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF16171B) : const Color(0xFF262831),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text('Auto-Fit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: _autoDetect,
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    onPressed: () => setState(() => _quad = QuadPoints.inset(0.06)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFA9282),
                      foregroundColor: const Color(0xFF141518),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text(
                      'Apply Crop',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'quad': _quad,
                        'rotation': _rotation,
                      });
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

  Widget _buildMagnifierLoupe(Rect drawRect) {
    Offset targetNorm = Offset.zero;
    switch (_activeCornerIndex) {
      case 0:
        targetNorm = _quad.topLeft;
        break;
      case 1:
        targetNorm = _quad.topRight;
        break;
      case 2:
        targetNorm = _quad.bottomRight;
        break;
      case 3:
        targetNorm = _quad.bottomLeft;
        break;
    }

    final cornerPixelX = drawRect.left + (targetNorm.dx * drawRect.width);
    final cornerPixelY = drawRect.top + (targetNorm.dy * drawRect.height);

    // Place loupe ~90px above the finger
    const loupeDiameter = 110.0;
    double loupeX = cornerPixelX - (loupeDiameter / 2);
    double loupeY = cornerPixelY - loupeDiameter - 40;

    if (loupeY < 20) loupeY = cornerPixelY + 50; // Flip downward if near top screen edge
    loupeX = loupeX.clamp(16.0, MediaQuery.of(context).size.width - loupeDiameter - 16);

    return Positioned(
      left: loupeX,
      top: loupeY,
      child: Container(
        width: loupeDiameter,
        height: loupeDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFA9282), width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 2.5x Zoomed Image snippet
              Transform.scale(
                scale: 2.5,
                alignment: FractionalOffset(targetNorm.dx, targetNorm.dy),
                child: RotatedBox(
                  quarterTurns: _rotation ~/ 90,
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                    width: drawRect.width,
                    height: drawRect.height,
                  ),
                ),
              ),

              // Precision Crosshair
              CustomPaint(
                size: const Size(loupeDiameter, loupeDiameter),
                painter: CrosshairPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuadCropPainter extends CustomPainter {
  final QuadPoints quad;
  final int? activeCornerIndex;

  QuadCropPainter({
    required this.quad,
    required this.activeCornerIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final p0 = Offset(quad.topLeft.dx * size.width, quad.topLeft.dy * size.height);
    final p1 = Offset(quad.topRight.dx * size.width, quad.topRight.dy * size.height);
    final p2 = Offset(quad.bottomRight.dx * size.width, quad.bottomRight.dy * size.height);
    final p3 = Offset(quad.bottomLeft.dx * size.width, quad.bottomLeft.dy * size.height);

    // 1. Draw darkened mask outside quad
    final quadPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final maskPath = Path.combine(PathOperation.difference, fullPath, quadPath);
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.55));

    // 2. Draw connecting border lines
    final linePaint = Paint()
      ..color = const Color(0xFFFA9282)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(quadPath, linePaint);

    // 3. Draw grid lines inside quad (Rule of thirds document alignment)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal thirds
    final h1a = Offset.lerp(p0, p3, 1 / 3)!;
    final h1b = Offset.lerp(p1, p2, 1 / 3)!;
    final h2a = Offset.lerp(p0, p3, 2 / 3)!;
    final h2b = Offset.lerp(p1, p2, 2 / 3)!;
    canvas.drawLine(h1a, h1b, gridPaint);
    canvas.drawLine(h2a, h2b, gridPaint);

    // Vertical thirds
    final v1a = Offset.lerp(p0, p1, 1 / 3)!;
    final v1b = Offset.lerp(p3, p2, 1 / 3)!;
    final v2a = Offset.lerp(p0, p1, 2 / 3)!;
    final v2b = Offset.lerp(p3, p2, 2 / 3)!;
    canvas.drawLine(v1a, v1b, gridPaint);
    canvas.drawLine(v2a, v2b, gridPaint);

    // 4. Draw Corner Handles with touch expansion
    final corners = [p0, p1, p2, p3];
    for (int i = 0; i < 4; i++) {
      final p = corners[i];
      final isActive = activeCornerIndex == i;
      final handleRadius = isActive ? 14.0 : 10.0;

      // Outer halo
      canvas.drawCircle(
        p,
        handleRadius + 4,
        Paint()..color = const Color(0xFFFA9282).withOpacity(0.35),
      );

      // Main handle circle
      canvas.drawCircle(
        p,
        handleRadius,
        Paint()..color = const Color(0xFFFA9282),
      );

      // Inner white dot
      canvas.drawCircle(
        p,
        handleRadius * 0.45,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant QuadCropPainter oldDelegate) {
    return oldDelegate.quad != quad || oldDelegate.activeCornerIndex != activeCornerIndex;
  }
}

class CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 1.5;

    // Horizontal line
    canvas.drawLine(Offset(center.dx - 14, center.dy), Offset(center.dx + 14, center.dy), paint);
    // Vertical line
    canvas.drawLine(Offset(center.dx, center.dy - 14), Offset(center.dx, center.dy + 14), paint);
    // Center point
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFFEF4444));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
