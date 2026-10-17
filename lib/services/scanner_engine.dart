import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum DocScanMode {
  document,
  idCard,
  book,
  signature,
  batch,
  single,
}

enum DocScanFilter {
  vividLight,
  magicColor,
  sharpBw,
  contrastBw,
  bw,
  grayscale,
  vibrant,
  softTone,
  original,
}

class QuadPoints {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const QuadPoints({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  factory QuadPoints.full() => const QuadPoints(
        topLeft: Offset(0, 0),
        topRight: Offset(1, 0),
        bottomRight: Offset(1, 1),
        bottomLeft: Offset(0, 1),
      );

  factory QuadPoints.inset(double margin) => QuadPoints(
        topLeft: Offset(margin, margin),
        topRight: Offset(1 - margin, margin),
        bottomRight: Offset(1 - margin, 1 - margin),
        bottomLeft: Offset(margin, 1 - margin),
      );

  QuadPoints copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    return QuadPoints(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }
}

class ScannedPageData {
  final String id;
  final String rawImagePath;
  String processedImagePath;
  QuadPoints quad;
  DocScanFilter filter;
  int rotationDegrees;
  double brightness; // -0.5 to 0.5
  double contrast;   // 0.5 to 1.5

  ScannedPageData({
    required this.id,
    required this.rawImagePath,
    required this.processedImagePath,
    QuadPoints? quad,
    this.filter = DocScanFilter.magicColor,
    this.rotationDegrees = 0,
    this.brightness = 0.0,
    this.contrast = 1.0,
  }) : quad = quad ?? QuadPoints.full();
}

class ScannerEngine {
  // --- COLOR MATRICES FOR DOCUMENT ENHANCEMENT ---

  static const List<double> matrixOriginal = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Doc Scanner's Default "Vivid Light":
  /// Subtle background whitening, gentle text contrast enhancement, vibrant ink
  static const List<double> matrixVividLight = <double>[
    1.30, -0.08, -0.06, 0, 22,
    -0.06, 1.30, -0.08, 0, 22,
    -0.08, -0.06, 1.30, 0, 22,
    0,     0,     0,    1, 0,
  ];

  /// CamScanner / DocScanner signature Magic Color
  /// Whitens background, increases contrast, boosts ink vibrancy
  static const List<double> matrixMagicColor = <double>[
    1.45, -0.15, -0.10, 0, 18,
    -0.10, 1.45, -0.15, 0, 18,
    -0.15, -0.10, 1.45, 0, 18,
    0,     0,     0,    1, 0,
  ];

  /// Sharp Black & White for maximum text punch
  static const List<double> matrixSharpBw = <double>[
    2.2, 2.2, 2.2, 0, -250,
    2.2, 2.2, 2.2, 0, -250,
    2.2, 2.2, 2.2, 0, -250,
    0,   0,   0,   1, 0,
  ];

  /// Contrast B&W (crisp text with anti-aliasing)
  static const List<double> matrixContrastBw = <double>[
    1.8, 1.8, 1.8, 0, -195,
    1.8, 1.8, 1.8, 0, -195,
    1.8, 1.8, 1.8, 0, -195,
    0,   0,   0,   1, 0,
  ];

  /// High-contrast black and white for crisp text documents
  static const List<double> matrixBlackAndWhite = <double>[
    1.6, 1.6, 1.6, 0, -180,
    1.6, 1.6, 1.6, 0, -180,
    1.6, 1.6, 1.6, 0, -180,
    0,   0,   0,   1, 0,
  ];

  /// Clean monochrome luminance
  static const List<double> matrixGrayscale = <double>[
    0.299, 0.587, 0.114, 0, 0,
    0.299, 0.587, 0.114, 0, 0,
    0.299, 0.587, 0.114, 0, 0,
    0,     0,     0,     1, 0,
  ];

  /// Vibrant colors for charts, certificates, and ID cards
  static const List<double> matrixVibrant = <double>[
    1.25, -0.08, -0.05, 0, 8,
    -0.05, 1.25, -0.08, 0, 8,
    -0.08, -0.05, 1.25, 0, 8,
    0,     0,     0,    1, 0,
  ];

  /// Soft tone for delicate prints without harsh clipping
  static const List<double> matrixSoftTone = <double>[
    1.12, 0.02, 0.02, 0, 10,
    0.02, 1.12, 0.02, 0, 10,
    0.02, 0.02, 1.12, 0, 10,
    0,    0,    0,    1, 0,
  ];

  static List<double> getFilterMatrix(DocScanFilter filter) {
    switch (filter) {
      case DocScanFilter.vividLight:
        return matrixVividLight;
      case DocScanFilter.magicColor:
        return matrixMagicColor;
      case DocScanFilter.sharpBw:
        return matrixSharpBw;
      case DocScanFilter.contrastBw:
        return matrixContrastBw;
      case DocScanFilter.bw:
        return matrixBlackAndWhite;
      case DocScanFilter.grayscale:
        return matrixGrayscale;
      case DocScanFilter.vibrant:
        return matrixVibrant;
      case DocScanFilter.softTone:
        return matrixSoftTone;
      case DocScanFilter.original:
        return matrixOriginal;
    }
  }

  static ColorFilter getColorFilter(DocScanFilter filter, {double brightness = 0.0, double contrast = 1.0}) {
    final base = List<double>.from(getFilterMatrix(filter));
    // Apply contrast and brightness adjustments to color matrix
    if (contrast != 1.0 || brightness != 0.0) {
      final bOffset = brightness * 255;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          base[i * 5 + j] *= contrast;
        }
        base[i * 5 + 4] = (base[i * 5 + 4] * contrast) + bOffset;
      }
    }
    return ColorFilter.matrix(base);
  }

  static String getFilterTitle(DocScanFilter filter) {
    switch (filter) {
      case DocScanFilter.vividLight:
        return 'Vivid Light';
      case DocScanFilter.magicColor:
        return 'Magic Color';
      case DocScanFilter.sharpBw:
        return 'Sharp B & W';
      case DocScanFilter.contrastBw:
        return 'Contrast B&W';
      case DocScanFilter.bw:
        return 'B & W';
      case DocScanFilter.grayscale:
        return 'Grayscale';
      case DocScanFilter.vibrant:
        return 'Vibrant';
      case DocScanFilter.softTone:
        return 'Soft Tone';
      case DocScanFilter.original:
        return 'Original';
    }
  }

  static IconData getFilterIcon(DocScanFilter filter) {
    switch (filter) {
      case DocScanFilter.vividLight:
        return Icons.light_mode_rounded;
      case DocScanFilter.magicColor:
        return Icons.auto_awesome_rounded;
      case DocScanFilter.sharpBw:
        return Icons.filter_sharp;
      case DocScanFilter.contrastBw:
        return Icons.tonality_rounded;
      case DocScanFilter.bw:
        return Icons.contrast_rounded;
      case DocScanFilter.grayscale:
        return Icons.filter_b_and_w_rounded;
      case DocScanFilter.vibrant:
        return Icons.palette_rounded;
      case DocScanFilter.softTone:
        return Icons.wb_sunny_outlined;
      case DocScanFilter.original:
        return Icons.image_outlined;
    }
  }

  // --- IMAGE RENDERING & PERSISTENCE ---

  /// Reads an image from disk, decodes it, applies crop/perspective and color filter, and writes to a new file
  static Future<String> renderAndSavePage({
    required String sourcePath,
    required QuadPoints quad,
    required DocScanFilter filter,
    required int rotationDegrees,
    double brightness = 0.0,
    double contrast = 1.0,
  }) async {
    final rawBytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final ui.Image srcImage = frame.image;

    final origW = srcImage.width.toDouble();
    final origH = srcImage.height.toDouble();

    // Determine target bounding box based on normalized quad points
    final pTL = Offset(quad.topLeft.dx * origW, quad.topLeft.dy * origH);
    final pTR = Offset(quad.topRight.dx * origW, quad.topRight.dy * origH);
    final pBR = Offset(quad.bottomRight.dx * origW, quad.bottomRight.dy * origH);
    final pBL = Offset(quad.bottomLeft.dx * origW, quad.bottomLeft.dy * origH);

    final minX = math.max(0.0, [pTL.dx, pTR.dx, pBR.dx, pBL.dx].reduce(math.min));
    final maxX = math.min(origW, [pTL.dx, pTR.dx, pBR.dx, pBL.dx].reduce(math.max));
    final minY = math.max(0.0, [pTL.dy, pTR.dy, pBR.dy, pBL.dy].reduce(math.min));
    final maxY = math.min(origH, [pTL.dy, pTR.dy, pBR.dy, pBL.dy].reduce(math.max));

    double targetW = maxX - minX;
    double targetH = maxY - minY;
    if (targetW < 10) targetW = origW;
    if (targetH < 10) targetH = origH;

    final isRotated90or270 = (rotationDegrees % 180) != 0;
    final finalW = isRotated90or270 ? targetH : targetW;
    final finalH = isRotated90or270 ? targetW : targetH;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, finalW, finalH));

    // Background fill (pure white for documents)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, finalW, finalH),
      Paint()..color = Colors.white,
    );

    canvas.save();

    // Apply rotation
    if (rotationDegrees != 0) {
      canvas.translate(finalW / 2, finalH / 2);
      canvas.rotate(rotationDegrees * math.pi / 180);
      canvas.translate(-targetW / 2, -targetH / 2);
    }

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..colorFilter = getColorFilter(filter, brightness: brightness, contrast: contrast);

    // Source rect and destination rect
    final srcRect = Rect.fromLTWH(minX, minY, targetW, targetH);
    final dstRect = Rect.fromLTWH(0, 0, targetW, targetH);

    canvas.drawImageRect(srcImage, srcRect, dstRect, paint);
    canvas.restore();

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(finalW.toInt(), finalH.toInt());
    final byteData = await renderedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to encode processed image');
    }

    final tempDir = await getTemporaryDirectory();
    final targetFile = File('${tempDir.path}/scan_proc_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}.png');
    await targetFile.writeAsBytes(byteData.buffer.asUint8List());

    return targetFile.path;
  }

  /// Composite two images into an ID Card format (Front on top, Back on bottom) on a clean document sheet
  static Future<String> generateIdCardComposite({
    required String frontPath,
    required String backPath,
  }) async {
    final fBytes = await File(frontPath).readAsBytes();
    final bBytes = await File(backPath).readAsBytes();

    final fCodec = await ui.instantiateImageCodec(fBytes);
    final fFrame = await fCodec.getNextFrame();
    final fImg = fFrame.image;

    final bCodec = await ui.instantiateImageCodec(bBytes);
    final bFrame = await bCodec.getNextFrame();
    final bImg = bFrame.image;

    // Standard A4 aspect ratio sheet: 1240 x 1754 (at ~150 DPI)
    const sheetW = 1240.0;
    const sheetH = 1754.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, sheetW, sheetH));

    // White background
    canvas.drawRect(const Rect.fromLTWH(0, 0, sheetW, sheetH), Paint()..color = Colors.white);

    // Header label
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    void drawBadge(String text, double yOffset) {
      textPainter.text = TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((sheetW - textPainter.width) / 2, yOffset));
    }

    const cardW = 960.0;
    const cardH = 600.0;
    const cardX = (sheetW - cardW) / 2;

    // Draw Front Side
    drawBadge('• FRONT SIDE •', 90);
    const fRect = Rect.fromLTWH(cardX, 130, cardW, cardH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFFF1F5F9),
    );
    canvas.drawImageRect(
      fImg,
      Rect.fromLTWH(0, 0, fImg.width.toDouble(), fImg.height.toDouble()),
      fRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    // Subtle border
    canvas.drawRRect(
      RRect.fromRectAndRadius(fRect, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw Back Side
    drawBadge('• BACK SIDE •', 850);
    const bRect = Rect.fromLTWH(cardX, 890, cardW, cardH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFFF1F5F9),
    );
    canvas.drawImageRect(
      bImg,
      Rect.fromLTWH(0, 0, bImg.width.toDouble(), bImg.height.toDouble()),
      bRect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Footer branding
    textPainter.text = const TextSpan(
      text: 'Scanned with PDFDost Doc Scanner',
      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 18, fontStyle: FontStyle.italic),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((sheetW - textPainter.width) / 2, sheetH - 90));

    final picture = recorder.endRecording();
    final composite = await picture.toImage(sheetW.toInt(), sheetH.toInt());
    final byteData = await composite.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final outFile = File('${tempDir.path}/id_card_${DateTime.now().millisecondsSinceEpoch}.png');
    await outFile.writeAsBytes(byteData!.buffer.asUint8List());

    return outFile.path;
  }

  /// Splits an open book image right down the vertical center into Left and Right page images
  static Future<List<String>> splitBookSpread(String spreadPath) async {
    final rawBytes = await File(spreadPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final origW = img.width.toDouble();
    final origH = img.height.toDouble();
    final halfW = origW / 2;

    final tempDir = await getTemporaryDirectory();
    final List<String> paths = [];

    // Left Page
    {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, halfW, origH));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, halfW, origH),
        Rect.fromLTWH(0, 0, halfW, origH),
        Paint()..filterQuality = FilterQuality.high,
      );
      final pic = recorder.endRecording();
      final leftImg = await pic.toImage(halfW.toInt(), origH.toInt());
      final bData = await leftImg.toByteData(format: ui.ImageByteFormat.png);
      final f = File('${tempDir.path}/book_left_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bData!.buffer.asUint8List());
      paths.add(f.path);
    }

    // Right Page
    {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, halfW, origH));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(halfW, 0, halfW, origH),
        Rect.fromLTWH(0, 0, halfW, origH),
        Paint()..filterQuality = FilterQuality.high,
      );
      final pic = recorder.endRecording();
      final rightImg = await pic.toImage(halfW.toInt(), origH.toInt());
      final bData = await rightImg.toByteData(format: ui.ImageByteFormat.png);
      final f = File('${tempDir.path}/book_right_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bData!.buffer.asUint8List());
      paths.add(f.path);
    }

    return paths;
  }

  /// Isolates ink strokes from paper background and outputs a transparent PNG.
  /// Replaces ink color with selected pen color (e.g. Royal Blue, Classic Black).
  static Future<String> extractTransparentSignature({
    required String sourcePath,
    required Color penColor,
    double threshold = 0.68,
    double contrast = 1.25,
    int rotationDegrees = 0,
  }) async {
    final rawBytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final ui.Image srcImage = frame.image;

    final origW = srcImage.width;
    final origH = srcImage.height;

    // Read raw RGBA bytes
    final byteData = await srcImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception('Failed to read image pixel data');
    final pixels = Uint8List.fromList(byteData.buffer.asUint8List());

    final penA = (penColor.toARGB32() >> 24) & 0xFF;
    final penR = (penColor.toARGB32() >> 16) & 0xFF;
    final penG = (penColor.toARGB32() >> 8) & 0xFF;
    final penB = penColor.toARGB32() & 0xFF;

    // Threshold cutoff (0-255)
    final lumCutoff = (threshold * 255).clamp(20, 250).toInt();

    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];

      // Luminance formula (ITU-R BT.601)
      final lum = (0.299 * r + 0.587 * g + 0.114 * b).toInt();

      if (lum >= lumCutoff) {
        // Paper background -> completely transparent
        pixels[i + 3] = 0;
      } else {
        // Ink stroke -> antialiased opacity + pen tint
        final darknessFactor = (1.0 - (lum / lumCutoff)).clamp(0.0, 1.0);
        final boostedFactor = math.pow(darknessFactor, 1.0 / contrast).toDouble();

        pixels[i] = penR;
        pixels[i + 1] = penG;
        pixels[i + 2] = penB;
        pixels[i + 3] = (penA * boostedFactor).round().clamp(0, 255);
      }
    }

    // Decode pixels back to ui.Image
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      origW,
      origH,
      ui.PixelFormat.rgba8888,
      (ui.Image img) => completer.complete(img),
    );
    final ui.Image transparentImg = await completer.future;

    // If rotation is required, render through canvas
    ui.Image finalImage = transparentImg;
    if (rotationDegrees % 360 != 0) {
      final is90or270 = (rotationDegrees % 180) != 0;
      final rotW = is90or270 ? origH.toDouble() : origW.toDouble();
      final rotH = is90or270 ? origW.toDouble() : origH.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, rotW, rotH));

      canvas.save();
      canvas.translate(rotW / 2, rotH / 2);
      canvas.rotate((rotationDegrees * math.pi) / 180.0);
      canvas.translate(-origW / 2, -origH / 2);
      canvas.drawImage(transparentImg, Offset.zero, Paint());
      canvas.restore();

      final picture = recorder.endRecording();
      finalImage = await picture.toImage(rotW.round(), rotH.round());
    }

    final pngBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) throw Exception('Failed to encode transparent PNG');

    final outputDir = await getApplicationDocumentsDirectory();
    final signDir = Directory('${outputDir.path}/signatures');
    if (!await signDir.exists()) {
      await signDir.create(recursive: true);
    }

    final outputPath = '${signDir.path}/sign_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outputPath).writeAsBytes(pngBytes.buffer.asUint8List());

    return outputPath;
  }
}
