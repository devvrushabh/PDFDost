import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_engine.dart';
import '../widgets/app_logo.dart';
import '../widgets/login_modal.dart';

class SettingsTab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const SettingsTab({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _askMobileData = true;
  String _ocrLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final askData = await StorageEngine.loadAskMobileData();
    final ocr = await StorageEngine.loadOcrLanguage();
    if (mounted) {
      setState(() {
        _askMobileData = askData;
        _ocrLanguage = ocr;
      });
    }
  }

  void _showOcrLanguagePicker() {
    final languages = ['English', 'Spanish', 'Hindi', 'French', 'German', 'Italian', 'Japanese', 'Chinese'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('OCR Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (c, i) {
              final lang = languages[i];
              return RadioListTile<String>(
                title: Text(lang),
                value: lang,
                groupValue: _ocrLanguage,
                activeColor: const Color(0xFFFA9282),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _ocrLanguage = val);
                    StorageEngine.saveOcrLanguage(val);
                    Navigator.pop(ctx);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 44),
            ),
            const SizedBox(height: 18),
            const Text(
              'PDFDost Premium',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Unlimited document conversions\n• High-precision optical OCR text recognition\n• Zero ads & lightning processing\n• Cloud backup & synchronization',
              style: TextStyle(height: 1.6, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA9282),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Free 7-day trial activated! Enjoy Premium.')),
                  );
                },
                child: const Text('Start 7 Days Free Trial', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final dividerColor = widget.isDark ? const Color(0xFF282A33) : const Color(0xFFE2E8F0);
    final headerTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // 1. Log in / Sign up Header Card (Screenshots 2 & 3)
        GestureDetector(
          onTap: () => LoginModalSheet.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF2D2E37) : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 18),
                const Text(
                  'Log in or sign up',
                  style: TextStyle(
                    color: Color(0xFFFA9282), // Exact soft coral from screenshot
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 2. Section: Account
        Text('Account', style: TextStyle(color: headerTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined, size: 24),
                title: const Text('Current membership', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Free', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              Divider(height: 1, color: dividerColor),

              // Upgrade to Premium Banner with glowing 3D Crown
              GestureDetector(
                onTap: _showPremiumDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF262831) : const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upgrade to Premium\nfor unlimited usage',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Get 7 days free trial',
                              style: TextStyle(color: headerTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Golden 3D Crown Badge with Sparkles
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFF1E1F26),
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.credit_card_outlined, size: 24),
                title: const Text('Restore purchases', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchases restored successfully')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Section: Preferences
        Text('Preferences', style: TextStyle(color: headerTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.storage_rounded, size: 24),
                title: const Text('Ask before using mobile data', style: TextStyle(fontWeight: FontWeight.w600)),
                value: _askMobileData,
                activeColor: const Color(0xFFFA9282),
                onChanged: (val) {
                  setState(() => _askMobileData = val);
                  StorageEngine.saveAskMobileData(val);
                },
              ),
              Divider(height: 1, color: dividerColor),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined, size: 24),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w600)),
                value: widget.isDark,
                activeColor: const Color(0xFFFA9282),
                onChanged: (val) => widget.onToggleTheme(),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined, size: 24),
                title: const Text('OCR language', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_ocrLanguage, style: TextStyle(color: headerTextColor, fontSize: 13)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
                onTap: _showOcrLanguagePicker,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4. Section: More
        Text('More', style: TextStyle(color: headerTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dividerColor),
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.policy_outlined, size: 24),
                title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showInfoDialog(
                  'Terms & Conditions',
                  'PDFDost is a privacy-first, on-device document converter and utility app. All conversions and documents remain entirely on your local device without unauthorized third-party uploads.',
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded, size: 24),
                title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showInfoDialog(
                  'Privacy Policy',
                  'We take your privacy seriously. No personal documents, images, or extracted text are transmitted to remote servers. All PDF generation executes natively on your device.',
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.favorite_border_rounded, size: 24),
                title: const Text('About us', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showInfoDialog(
                  'About PDFDost',
                  'PDFDost is engineered to be the ultimate companion for all your PDF and document conversion needs with speed, elegance, and reliability.',
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined, size: 24),
                title: const Text('Credits', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showInfoDialog(
                  'Credits',
                  'Built with Flutter, Material 3, and open-source PDF technologies. Crafted with dedication by devvrushabh.',
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, size: 24),
                title: const Text('Help / Contact', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showInfoDialog(
                  'Help & Support',
                  'For inquiries, bug reports, and feedback, contact support at: vrushabhdhote29@gmail.com',
                ),
              ),
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: const Icon(Icons.share_outlined, size: 24),
                title: const Text('Share App', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  Share.share('Check out PDFDost - High quality Image to PDF converter and PDF tools app!');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // 5. Footer Branding (Screenshots 2 & 3)
        Center(
          child: Column(
            children: [
              AppLogo(fontSize: 22, isDark: widget.isDark),
              const SizedBox(height: 8),
              Text(
                'Version 4.1.0',
                style: TextStyle(
                  color: headerTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
