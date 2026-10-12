import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpaceEmptyIllustration extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isDark;

  const SpaceEmptyIllustration({
    super.key,
    this.title = 'No files found',
    this.subtitle = 'Tap the button to begin',
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 220,
          height: 190,
          child: CustomPaint(
            painter: _SpaceEmptyPainter(isDark: isDark),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SpaceEmptyPainter extends CustomPainter {
  final bool isDark;

  _SpaceEmptyPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
    final accentSalmon = const Color(0xFFFA9282);

    final linePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final thinLinePaint = Paint()
      ..color = strokeColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // 1. Ground lines
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.95),
      Offset(size.width * 0.45, size.height * 0.95),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.95),
      Offset(size.width * 0.88, size.height * 0.95),
      linePaint,
    );

    // 2. Telescope on tripod (Left side)
    final teleCenterX = size.width * 0.28;
    final teleCenterY = size.height * 0.80;

    // Tripod legs
    canvas.drawLine(Offset(teleCenterX, teleCenterY), Offset(size.width * 0.20, size.height * 0.95), linePaint);
    canvas.drawLine(Offset(teleCenterX, teleCenterY), Offset(teleCenterX, size.height * 0.95), linePaint);
    canvas.drawLine(Offset(teleCenterX, teleCenterY), Offset(size.width * 0.36, size.height * 0.95), linePaint);

    // Telescope barrel (Angled at ~40 degrees)
    canvas.save();
    canvas.translate(teleCenterX, teleCenterY);
    canvas.rotate(-math.pi / 4.2);

    // Main barrel
    final barrelRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -26, 24, 46),
      const Radius.circular(4),
    );
    canvas.drawRRect(barrelRect, linePaint);
    // Objective lens rim
    canvas.drawLine(const Offset(-16, -26), const Offset(16, -26), linePaint);
    // Eyepiece mount
    canvas.drawRect(const Rect.fromLTWH(-6, 20, 12, 12), linePaint);
    // Eyepiece lens
    canvas.drawLine(const Offset(-10, 32), const Offset(10, 32), linePaint);
    canvas.restore();

    // 3. Small Ringed Planet (Middle left)
    final planetX = size.width * 0.45;
    final planetY = size.height * 0.78;
    canvas.drawCircle(Offset(planetX, planetY), 9, linePaint);
    // Planet ring ellipse
    final ringRect = Rect.fromCenter(center: Offset(planetX, planetY), width: 28, height: 10);
    canvas.save();
    canvas.translate(planetX, planetY);
    canvas.rotate(-math.pi / 6);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 28, height: 8), thinLinePaint);
    canvas.restore();

    // 4. Floating Document Card (Right side)
    final docX = size.width * 0.60;
    final docY = size.height * 0.48;
    final docW = 44.0;
    final docH = 56.0;

    // Document body
    final docRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(docX, docY, docW, docH),
      const Radius.circular(6),
    );
    final fillCardPaint = Paint()
      ..color = accentSalmon.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(docRect, fillCardPaint);

    // Document header bar
    final headerPaint = Paint()
      ..color = const Color(0xFFE5322D)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(docX, docY, docW, 14),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      headerPaint,
    );

    // Mini thumbnails inside document
    final whiteFill = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(docX + 6, docY + 18, 14, 12), const Radius.circular(2)), whiteFill);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(docX + 24, docY + 18, 14, 12), const Radius.circular(2)), whiteFill);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(docX + 6, docY + 34, 14, 12), const Radius.circular(2)), whiteFill);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(docX + 24, docY + 34, 14, 12), const Radius.circular(2)), whiteFill);

    // 5. Floating Astronaut (Above document)
    final astroX = size.width * 0.60;
    final astroY = size.height * 0.30;

    // Astronaut helmet
    canvas.drawCircle(Offset(astroX, astroY), 11, linePaint);
    // Visor
    final visorRect = Rect.fromLTWH(astroX - 6, astroY - 5, 12, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(visorRect, const Radius.circular(4)), linePaint);

    // Astronaut body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(astroX - 8, astroY + 11, 16, 15), const Radius.circular(4)),
      linePaint,
    );
    // Backpack
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(astroX - 12, astroY + 12, 4, 12), const Radius.circular(2)),
      linePaint,
    );
    // Legs
    canvas.drawLine(Offset(astroX - 4, astroY + 26), Offset(astroX - 7, astroY + 34), linePaint);
    canvas.drawLine(Offset(astroX + 4, astroY + 26), Offset(astroX + 7, astroY + 34), linePaint);
    // Arms (Waving towards left)
    canvas.drawLine(Offset(astroX - 8, astroY + 15), Offset(astroX - 15, astroY + 10), linePaint);
    canvas.drawLine(Offset(astroX + 8, astroY + 15), Offset(astroX + 14, astroY + 20), linePaint);

    // 6. Floating Star/Saturn (Right)
    final saturnX = size.width * 0.82;
    final saturnY = size.height * 0.65;
    canvas.drawCircle(Offset(saturnX, saturnY), 8, linePaint);
    canvas.drawLine(Offset(saturnX - 14, saturnY), Offset(saturnX + 14, saturnY), linePaint);

    // 7. Celestial sparkles & circles
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.52), 4, thinLinePaint);
    _drawSparkle(canvas, Offset(size.width * 0.44, size.height * 0.63), 5, thinLinePaint);
    _drawSparkle(canvas, Offset(size.width * 0.80, size.height * 0.45), 6, thinLinePaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double r, Paint paint) {
    canvas.drawLine(Offset(center.dx - r, center.dy), Offset(center.dx + r, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - r), Offset(center.dx, center.dy + r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
