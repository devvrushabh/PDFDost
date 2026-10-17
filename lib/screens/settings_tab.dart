import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/storage_engine.dart';
import '../widgets/app_logo.dart';
import '../widgets/login_modal.dart';
import 'trash_screen.dart';

class SettingsTab extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final List<TrashItem> trashItems;
  final Function(TrashItem)? onRestoreTrashItem;
  final Function(TrashItem)? onDeletePermanently;
  final VoidCallback? onEmptyTrash;

  const SettingsTab({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.trashItems = const [],
    this.onRestoreTrashItem,
    this.onDeletePermanently,
    this.onEmptyTrash,
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

  Future<void> _openUpiPayment() async {
    const upiId = '8830638458-2@ybl';
    const payeeName = 'Vrushabh Dhote';
    final upiUrl = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&cu=INR&tn=${Uri.encodeComponent('Donate to PDFDost')}';

    // Copy UPI ID to clipboard automatically
    await Clipboard.setData(const ClipboardData(text: upiId));

    // Launch native UPI intent
    final success = await StorageEngine.openUpiPayment(upiUrl);

    if (mounted) {
      if (!success) {
        _showQrCodeModal(noAppFound: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening UPI payment app...'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _showQrCodeModal({bool noAppFound = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Support Open Source',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Donate to PDFDost',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('By ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA9282).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color(0xFFFA9282).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Vrushabh Dhote',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFA9282),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/upi_qr.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF282A33) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      '8830638458-2@ybl',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: '8830638458-2@ybl'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ UPI ID copied to clipboard: 8830638458-2@ybl'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 16, color: Color(0xFFFA9282)),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(color: Color(0xFFFA9282), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (noAppFound) ...[
              const SizedBox(height: 10),
              const Text(
                'UPI ID copied to clipboard. Scan QR or open your payment app to donate.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFA9282),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'Open UPI App to Pay',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openUpiPayment();
                },
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
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.code_rounded, color: Color(0xFF10B981), size: 20),
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Free App By',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA9282).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFA9282).withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Vrushabh Dhote',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: Color(0xFFFA9282),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: const Text(
                  '100% Free Forever • Privacy First • Offline',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // Open Source Support Banner with small QR code replacing yellow icon
              GestureDetector(
                onTap: _showQrCodeModal,
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
                              'Support PDFDost\nOpen Source Project',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.25),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Scan QR or tap to donate via UPI',
                              style: TextStyle(color: headerTextColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Small QR Code replacing dark yellow icon
                      Container(
                        width: 58,
                        height: 58,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: widget.isDark ? const Color(0xFF3B3E4A) : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/upi_qr.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: dividerColor),

              // Donate and Pay Button (replaces Restore purchases)
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA9282).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFFA9282), size: 20),
                ),
                title: const Text('Donate and Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('UPI ID: 8830638458-2@ybl', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA9282),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFA9282).withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Pay',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                onTap: _openUpiPayment,
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
                activeThumbColor: const Color(0xFFFA9282),
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
                activeThumbColor: const Color(0xFFFA9282),
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
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                ),
                title: const Text('Trash & Retention', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Kept for 30 days before permanent deletion', style: TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.trashItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.trashItems.length}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => TrashScreen(
                        trashItems: widget.trashItems,
                        isDark: widget.isDark,
                        onRestore: (item) => widget.onRestoreTrashItem?.call(item),
                        onDeletePermanently: (item) => widget.onDeletePermanently?.call(item),
                        onEmptyTrash: () => widget.onEmptyTrash?.call(),
                      ),
                    ),
                  );
                },
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
                'Version 1.1.1',
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
