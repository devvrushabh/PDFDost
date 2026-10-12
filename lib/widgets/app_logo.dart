import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final bool showDost;
  final bool isDark;

  const AppLogo({
    super.key,
    this.fontSize = 22,
    this.showDost = false,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'I',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 4),
        // Stylized Red Heart with page corner fold
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFE5322D),
              size: fontSize * 1.05,
            ),
            Positioned(
              top: fontSize * 0.18,
              right: fontSize * 0.18,
              child: Container(
                width: fontSize * 0.28,
                height: fontSize * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(fontSize * 0.12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Text(
          showDost ? 'PDF DOST' : 'PDF',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'I',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.favorite_rounded,
                  color: const Color(0xFFE5322D),
                  size: 22,
                ),
              ],
            ),
            const Text(
              'PDF',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
