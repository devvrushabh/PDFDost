import 'package:flutter/material.dart';
import 'app_logo.dart';

class LoginModalSheet extends StatefulWidget {
  final bool isDark;

  const LoginModalSheet({super.key, this.isDark = true});

  static Future<void> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LoginModalSheet(isDark: isDark),
    );
  }

  @override
  State<LoginModalSheet> createState() => _LoginModalSheetState();
}

class _LoginModalSheetState extends State<LoginModalSheet> {
  bool _isSignUp = false;

  @override
  Widget build(BuildContext context) {
    final bgCardColor = widget.isDark ? const Color(0xFF16171B) : Colors.white;
    final buttonOutlineColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final buttonBgColor = widget.isDark ? const Color(0xFF1F2026) : const Color(0xFFF8FAFC);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      decoration: BoxDecoration(
        color: bgCardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 26,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // App Logo Badge
            const AppLogoBadge(size: 86),
            const SizedBox(height: 28),

            // Headline
            Text(
              'Simplify document\nmanagement',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),

            // Google Button
            _buildSocialButton(
              onTap: () => _handleLoginSuccess('Google'),
              bgColor: buttonBgColor,
              borderColor: buttonOutlineColor,
              textColor: textColor,
              icon: _buildGoogleIcon(),
              text: 'Google',
            ),
            const SizedBox(height: 14),

            // Facebook Button
            _buildSocialButton(
              onTap: () => _handleLoginSuccess('Facebook'),
              bgColor: buttonBgColor,
              borderColor: buttonOutlineColor,
              textColor: textColor,
              icon: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF1877F2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'f',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              text: 'Facebook',
            ),
            const SizedBox(height: 14),

            // SSO Button
            _buildSocialButton(
              onTap: () => _handleLoginSuccess('SSO'),
              bgColor: buttonBgColor,
              borderColor: buttonOutlineColor,
              textColor: textColor,
              icon: const Icon(Icons.key_rounded, size: 20, color: Color(0xFF94A3B8)),
              text: 'SSO',
            ),
            const SizedBox(height: 28),

            // Log in or Sign up switch
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                });
              },
              child: Text(
                _isSignUp ? 'Already have an account? Log in' : 'Log in or Sign up',
                style: const TextStyle(
                  color: Color(0xFFFA9282),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _handleLoginSuccess(String provider) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged in with $provider successfully!'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required Widget icon,
    required String text,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFFEA4335),
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}
