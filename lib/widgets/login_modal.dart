import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_logo.dart';
import '../services/cloud_auth_service.dart';

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
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    CloudAuthService.instance.init();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgCardColor = widget.isDark ? const Color(0xFF16171B) : Colors.white;
    final buttonOutlineColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final buttonBgColor = widget.isDark ? const Color(0xFF1F2026) : const Color(0xFFF8FAFC);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return AnimatedBuilder(
      animation: Listenable.merge([
        CloudAuthService.instance.currentUserNotifier,
        CloudAuthService.instance.isSyncingNotifier,
      ]),
      builder: (context, _) {
        final user = CloudAuthService.instance.currentUser;
        final isSyncing = CloudAuthService.instance.isSyncingNotifier.value;

        return Container(
          decoration: BoxDecoration(
            color: bgCardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Bar with Drag Handle & Close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF333541) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryTextColor,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (user != null) ...[
                    // Logged In Profile View
                    _buildLoggedInContent(user, isSyncing, bgCardColor, buttonBgColor, buttonOutlineColor, textColor, secondaryTextColor),
                  ] else ...[
                    // Log In / Sign Up View (Google Only)
                    _buildLoginContent(buttonBgColor, buttonOutlineColor, textColor, secondaryTextColor),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginContent(
    Color buttonBgColor,
    Color buttonOutlineColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      children: [
        const AppLogoBadge(size: 80),
        const SizedBox(height: 20),

        Text(
          'Simplify document\nmanagement',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in with Google to safely back up documents & PDFs to Google Drive and Firebase',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: secondaryTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // 1. One-Tap Google Sign-In Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: buttonBgColor,
              side: BorderSide(color: buttonOutlineColor, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : () => _handleGoogleSignIn(),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFA9282)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGoogleIcon(),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // Custom Google email input option
        Row(
          children: [
            Expanded(child: Divider(color: buttonOutlineColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: buttonOutlineColor)),
          ],
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your Google account email',
            hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
            prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Color(0xFFFA9282)),
            filled: true,
            fillColor: buttonBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: buttonOutlineColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: buttonOutlineColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFFA9282), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA9282),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : () => _handleCustomEmailSignIn(),
            child: const Text('Sign in / Sign up with Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 20),

        // Cloud & Firebase Configuration Link
        TextButton.icon(
          onPressed: _showCloudSettingsDialog,
          icon: const Icon(Icons.cloud_sync_rounded, size: 18, color: Color(0xFFFA9282)),
          label: const Text(
            'Configure Google Drive & Firebase Database',
            style: TextStyle(color: Color(0xFFFA9282), fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildLoggedInContent(
    CloudUser user,
    bool isSyncing,
    Color bgCardColor,
    Color buttonBgColor,
    Color buttonOutlineColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final lastSyncStr = user.lastSyncTime != null
        ? dateFormat.format(user.lastSyncTime!)
        : 'Never synced';

    return Column(
      children: [
        // User Avatar Circle
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFA9282), Color(0xFFE05244)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFA9282).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'G',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text(
          user.displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            color: secondaryTextColor,
          ),
        ),
        const SizedBox(height: 14),

        // Google Drive Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Text(
                'Google Drive & Firebase Connected',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Auto-Sync Toggle Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: buttonBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: buttonOutlineColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.add_to_drive_rounded, color: Color(0xFFFA9282), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google Drive Cloud Backup',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Last sync: $lastSyncStr',
                          style: TextStyle(color: secondaryTextColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: user.autoSyncToDrive,
                    activeTrackColor: const Color(0xFFFA9282),
                    activeColor: const Color(0xFFFA9282),
                    onChanged: (val) {
                      CloudAuthService.instance.toggleAutoSync(val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFA9282),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: isSyncing ? null : _handleManualSync,
                  icon: isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(
                    isSyncing ? 'Syncing to Google Drive...' : 'Sync Documents to Drive Now',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Configure Cloud / Firebase Settings Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: buttonOutlineColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _showCloudSettingsDialog,
            icon: Icon(Icons.tune_rounded, size: 18, color: secondaryTextColor),
            label: Text(
              'Cloud & Firebase Database Settings',
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sign Out Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              CloudAuthService.instance.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Signed out of Google account'),
                  backgroundColor: Color(0xFF475569),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await CloudAuthService.instance.signInWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Signed in with Google! Synced with Google Drive & Firebase.'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCustomEmailSignIn() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Google email address'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await CloudAuthService.instance.signInWithGoogle(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as $email! Connected to Drive & Firebase.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualSync() async {
    final success = await CloudAuthService.instance.syncToGoogleDrive();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'All documents, sets & PDFs successfully backed up to Google Drive!'
                : 'Sync completed with local and Firebase cloud backup',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showCloudSettingsDialog() {
    final clientIdCtrl = TextEditingController(text: CloudAuthService.instance.googleClientId);
    final dbUrlCtrl = TextEditingController(text: CloudAuthService.instance.firebaseDbUrl);
    final apiKeyCtrl = TextEditingController(text: CloudAuthService.instance.firebaseApiKey);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Color(0xFFFA9282)),
            SizedBox(width: 10),
            Text('Cloud Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Google Drive & Firebase Database Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                'Credentials and document records are stored safely in Firebase Database and Google Drive.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dbUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'Firebase Database URL',
                  hintText: 'https://<project-id>-default-rtdb.firebaseio.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.storage_rounded, size: 20),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apiKeyCtrl,
                decoration: InputDecoration(
                  labelText: 'Firebase Web API Key (Optional)',
                  hintText: 'AIzaSy...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Google OAuth Client ID (Optional)',
                  hintText: 'xxx.apps.googleusercontent.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFA9282),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await CloudAuthService.instance.saveConfig(
                googleClientId: clientIdCtrl.text,
                firebaseDbUrl: dbUrlCtrl.text,
                firebaseApiKey: apiKeyCtrl.text,
              );
              Navigator.pop(ctx);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Cloud & Firebase database settings updated!'),
                  backgroundColor: Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save Settings'),
          ),
        ],
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
