import 'package:flutter/material.dart';
import '../models/models.dart';

class ToolBadgeIcon extends StatelessWidget {
  final PdfToolType type;
  final double size;

  const ToolBadgeIcon({
    super.key,
    required this.type,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getToolStyle(type);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: config.gradientColors,
        ),
        boxShadow: [
          // 1. Vibrant colored ambient glow
          BoxShadow(
            color: config.glowColor.withValues(alpha: 0.42),
            blurRadius: size * 0.32,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          // 2. Subtle drop shadow for 3D elevation
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Specular glass shine overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size * 0.45,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(size * 0.26),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Icon content
          Center(child: config.iconWidget),
        ],
      ),
    );
  }

  _ToolBadgeConfig _getToolStyle(PdfToolType toolType) {
    switch (toolType) {
      case PdfToolType.mergePdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFFF3366), Color(0xFFFF5E36)],
          glowColor: const Color(0xFFFF3366),
          iconWidget: const Icon(Icons.call_merge_rounded, color: Colors.white, size: 26),
        );

      case PdfToolType.splitPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFFF7A00), Color(0xFFFF2A6D)],
          glowColor: const Color(0xFFFF6A00),
          iconWidget: const Icon(Icons.call_split_rounded, color: Colors.white, size: 26),
        );

      case PdfToolType.compressPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
          glowColor: const Color(0xFF10B981),
          iconWidget: const Icon(Icons.compress_rounded, color: Colors.white, size: 26),
        );

      case PdfToolType.pdfToWord:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          glowColor: const Color(0xFF2563EB),
          iconWidget: _buildDocToFormatBadge('W', Colors.white, const Color(0xFF1E40AF)),
        );

      case PdfToolType.pdfToPowerPoint:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFFF6D00), Color(0xFFC2410C)],
          glowColor: const Color(0xFFFF6D00),
          iconWidget: _buildDocToFormatBadge('P', Colors.white, const Color(0xFF9A3412)),
        );

      case PdfToolType.pdfToExcel:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF22C55E), Color(0xFF15803D)],
          glowColor: const Color(0xFF22C55E),
          iconWidget: _buildDocToFormatBadge('X', Colors.white, const Color(0xFF166534)),
        );

      case PdfToolType.wordToPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF2563EB), Color(0xFF1E3A8A)],
          glowColor: const Color(0xFF2563EB),
          iconWidget: _buildFormatToPdfBadge('W', const Color(0xFF1E40AF)),
        );

      case PdfToolType.powerPointToPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFEA580C), Color(0xFF9A3412)],
          glowColor: const Color(0xFFEA580C),
          iconWidget: _buildFormatToPdfBadge('P', const Color(0xFFC2410C)),
        );

      case PdfToolType.excelToPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF16A34A), Color(0xFF065F46)],
          glowColor: const Color(0xFF16A34A),
          iconWidget: _buildFormatToPdfBadge('X', const Color(0xFF15803D)),
        );

      case PdfToolType.editPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFFF2E93), Color(0xFF9333EA)],
          glowColor: const Color(0xFFFF2E93),
          iconWidget: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 28),
        );

      case PdfToolType.pdfToJpg:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFFFB800), Color(0xFFFF8800)],
          glowColor: const Color(0xFFFF9900),
          iconWidget: _buildJpgBadge(),
        );

      case PdfToolType.imageToPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFF59E0B), Color(0xFFE11D48)],
          glowColor: const Color(0xFFF59E0B),
          iconWidget: _buildImageToPdfBadge(),
        );

      case PdfToolType.pageNumbers:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFA855F7), Color(0xFF6366F1)],
          glowColor: const Color(0xFFA855F7),
          iconWidget: _buildPageNumbersBadge(),
        );

      case PdfToolType.watermark:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFFF43F5E), Color(0xFFBE123C)],
          glowColor: const Color(0xFFF43F5E),
          iconWidget: const Icon(Icons.approval_rounded, color: Colors.white, size: 26),
        );

      case PdfToolType.rotatePdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF06B6D4), Color(0xFF0284C7)],
          glowColor: const Color(0xFF06B6D4),
          iconWidget: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 28),
        );

      case PdfToolType.lockPdf:
        return _ToolBadgeConfig(
          gradientColors: const [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
          glowColor: const Color(0xFF8B5CF6),
          iconWidget: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
        );
    }
  }

  Widget _buildDocToFormatBadge(String letter, Color textColor, Color docColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 24,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: docColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 9, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatToPdfBadge(String letter, Color docColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 2,
          left: 4,
          child: Container(
            width: 19,
            height: 21,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                color: docColor,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 2,
          right: 3,
          child: Container(
            width: 19,
            height: 21,
            decoration: BoxDecoration(
              color: const Color(0xFFE5322D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 7.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJpgBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Text(
        'JPG',
        style: TextStyle(
          color: Color(0xFFD97706),
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildImageToPdfBadge() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 4,
          top: 3,
          child: Container(
            width: 20,
            height: 21,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_rounded,
              color: Color(0xFFEA580C),
              size: 14,
            ),
          ),
        ),
        Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            width: 19,
            height: 21,
            decoration: BoxDecoration(
              color: const Color(0xFFE5322D),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 7.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageNumbersBadge() {
    return Container(
      width: 25,
      height: 25,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('1', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 9)),
              Text('2', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 9)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('3', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 9)),
              Text('4', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w900, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolBadgeConfig {
  final List<Color> gradientColors;
  final Color glowColor;
  final Widget iconWidget;

  _ToolBadgeConfig({
    required this.gradientColors,
    required this.glowColor,
    required this.iconWidget,
  });
}
