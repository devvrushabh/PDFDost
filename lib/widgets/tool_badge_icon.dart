import 'package:flutter/material.dart';
import '../models/models.dart';

class ToolBadgeIcon extends StatelessWidget {
  final PdfToolType type;
  final double size;

  const ToolBadgeIcon({
    super.key,
    required this.type,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Widget iconContent;

    switch (type) {
      case PdfToolType.mergePdf:
        bgColor = const Color(0xFFE06D53);
        iconContent = const Icon(Icons.call_merge_rounded, color: Colors.white, size: 24);
        break;

      case PdfToolType.splitPdf:
        bgColor = const Color(0xFFE06D53);
        iconContent = const Icon(Icons.call_split_rounded, color: Colors.white, size: 24);
        break;

      case PdfToolType.compressPdf:
        bgColor = const Color(0xFF7CB380);
        iconContent = const Icon(Icons.compress_rounded, color: Colors.white, size: 24);
        break;

      case PdfToolType.pdfToWord:
        bgColor = const Color(0xFF5C82D1);
        iconContent = _buildDocToFormatBadge('W', Colors.white, const Color(0xFF2563EB));
        break;

      case PdfToolType.pdfToPowerPoint:
        bgColor = const Color(0xFFDD6B4F);
        iconContent = _buildDocToFormatBadge('P', Colors.white, const Color(0xFFEA580C));
        break;

      case PdfToolType.pdfToExcel:
        bgColor = const Color(0xFF66A672);
        iconContent = _buildDocToFormatBadge('X', Colors.white, const Color(0xFF16A34A));
        break;

      case PdfToolType.wordToPdf:
        bgColor = const Color(0xFF5C82D1);
        iconContent = _buildFormatToPdfBadge('W', const Color(0xFF2563EB));
        break;

      case PdfToolType.powerPointToPdf:
        bgColor = const Color(0xFFDD6B4F);
        iconContent = _buildFormatToPdfBadge('P', const Color(0xFFEA580C));
        break;

      case PdfToolType.excelToPdf:
        bgColor = const Color(0xFF66A672);
        iconContent = _buildFormatToPdfBadge('X', const Color(0xFF16A34A));
        break;

      case PdfToolType.editPdf:
        bgColor = const Color(0xFFB87295);
        iconContent = const Icon(Icons.edit_note_rounded, color: Colors.white, size: 26);
        break;

      case PdfToolType.pdfToJpg:
        bgColor = const Color(0xFFD4A836);
        iconContent = _buildJpgBadge();
        break;

      case PdfToolType.imageToPdf:
        bgColor = const Color(0xFFD4A836);
        iconContent = _buildImageToPdfBadge();
        break;

      case PdfToolType.pageNumbers:
        bgColor = const Color(0xFF9B7EBD);
        iconContent = _buildPageNumbersBadge();
        break;

      case PdfToolType.watermark:
        bgColor = const Color(0xFF9E556E);
        iconContent = const Icon(Icons.approval_rounded, color: Colors.white, size: 24);
        break;

      case PdfToolType.rotatePdf:
        bgColor = const Color(0xFFA16E8C);
        iconContent = const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 26);
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: iconContent),
    );
  }

  Widget _buildDocToFormatBadge(String letter, Color textColor, Color docColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 24,
          decoration: BoxDecoration(
            color: docColor,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        Positioned(
          bottom: 1,
          right: 1,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 8, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatToPdfBadge(String letter, Color docColor) {
    return Stack(
      children: [
        Positioned(
          top: 3,
          left: 4,
          child: Container(
            width: 17,
            height: 19,
            decoration: BoxDecoration(
              color: docColor,
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          right: 4,
          child: Container(
            width: 17,
            height: 19,
            decoration: BoxDecoration(
              color: const Color(0xFFE5322D),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 6.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJpgBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'JPG',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildImageToPdfBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 5,
          top: 6,
          child: Icon(Icons.image_rounded, color: Colors.white.withOpacity(0.9), size: 18),
        ),
        Positioned(
          right: 4,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE5322D),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 7,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageNumbersBadge() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
              Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
            ],
          ),
          SizedBox(height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
              Text('4', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }
}
