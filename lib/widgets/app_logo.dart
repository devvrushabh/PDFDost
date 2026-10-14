import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final bool showDost;
  final bool isDark;

  const AppLogo({
    super.key,
    this.fontSize = 22,
    this.showDost = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconSize = fontSize * 1.35;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App Icon
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(iconSize * 0.26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5322D).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(iconSize * 0.26),
            child: Image.asset(
              'assets/icon.png',
              width: iconSize,
              height: iconSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                'PDFDost-icon.png',
                width: iconSize,
                height: iconSize,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // App Name: PDF in text color, Dost in signature red
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'PDF',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Dost',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE5322D),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppLogoBadge extends StatelessWidget {
  final double size;

  const AppLogoBadge({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset(
            'assets/icon.png',
            width: size * 0.85,
            height: size * 0.85,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              'PDFDost-icon.png',
              width: size * 0.85,
              height: size * 0.85,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
