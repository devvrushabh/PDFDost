import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/models.dart';
import 'screens/files_tab.dart';
import 'screens/image_to_pdf_screen.dart';
import 'screens/merge_pdf_screen.dart';
import 'screens/split_pdf_screen.dart';
import 'screens/settings_tab.dart';
import 'screens/tools_tab.dart';
import 'screens/word_to_pdf_screen.dart';
import 'services/cloud_auth_service.dart';
import 'services/storage_engine.dart';
import 'widgets/app_logo.dart';
import 'widgets/login_modal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudAuthService.instance.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const PDFDostApp());
}

class PDFDostApp extends StatefulWidget {
  const PDFDostApp({super.key});

  @override
  State<PDFDostApp> createState() => _PDFDostAppState();
}

class _PDFDostAppState extends State<PDFDostApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await StorageEngine.loadDarkMode();
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = next;
    });
    await StorageEngine.saveDarkMode(next == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    const coralAccent = Color(0xFFFA9282);
    const primaryRed = Color(0xFFE5322D);

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF141518),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.dark,
        primary: primaryRed,
        secondary: coralAccent,
        surface: const Color(0xFF1E2026),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF141518),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.light,
        primary: primaryRed,
        secondary: coralAccent,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
    );

    return MaterialApp(
      title: 'PDFDost',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: MainNavigationScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainNavigationScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTabIndex = 0; // 0: Files, 1: Tools, 2: Settings
  final List<HistoryItem> _historyItems = [];
  final List<TrashItem> _trashItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await StorageEngine.loadHistory();
    final trash = await StorageEngine.loadTrash();
    if (mounted) {
      setState(() {
        _historyItems.clear();
        _historyItems.addAll(list);
        _trashItems.clear();
        _trashItems.addAll(trash);
      });
    }
  }

  Future<void> _saveHistory() async {
    await StorageEngine.saveHistory(_historyItems);
  }

  void _addHistoryItem(HistoryItem item) {
    setState(() {
      _historyItems.insert(0, item);
    });
    _saveHistory();
  }

  void _deleteHistoryItem(HistoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFFA9282)),
            SizedBox(width: 8),
            Text('Move to Trash?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text('"${item.name}" will be kept in Trash for 30 days before being permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _moveToTrash(item);
            },
            child: const Text('Move to Trash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _moveToTrash(HistoryItem item) async {
    final trashItem = await StorageEngine.moveToTrash(item);
    setState(() {
      _historyItems.removeWhere((e) => e.id == item.id);
      _trashItems.removeWhere((t) => t.item.id == item.id);
      _trashItems.insert(0, trashItem);
    });
    await _saveHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${item.name}" to Trash (30 days left)'),
          duration: const Duration(seconds: 1),
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFFFA9282),
            onPressed: () async {
              await _restoreTrashItem(trashItem);
            },
          ),
        ),
      );
    }
  }

  Future<void> _batchMoveToTrash(List<HistoryItem> items) async {
    if (items.isEmpty) return;
    final Set<String> ids = items.map((e) => e.id).toSet();
    for (final item in items) {
      final trashItem = await StorageEngine.moveToTrash(item);
      _trashItems.removeWhere((t) => t.item.id == item.id);
      _trashItems.insert(0, trashItem);
    }
    setState(() {
      _historyItems.removeWhere((e) => ids.contains(e.id));
    });
    await _saveHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved ${items.length} item(s) to Trash (30 days left)'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _restoreTrashItem(TrashItem trashItem) async {
    await StorageEngine.restoreFromTrash(trashItem);
    setState(() {
      _trashItems.removeWhere((t) => t.item.id == trashItem.item.id);
      if (!_historyItems.any((h) => h.id == trashItem.item.id)) {
        _historyItems.insert(0, trashItem.item);
      }
    });
    await _saveHistory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Restored "${trashItem.item.name}"'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _deleteTrashItemPermanently(TrashItem trashItem) async {
    await StorageEngine.deletePermanently(trashItem);
    setState(() {
      _trashItems.removeWhere((t) => t.item.id == trashItem.item.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permanently deleted "${trashItem.item.name}"'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _emptyTrash() async {
    await StorageEngine.emptyTrash();
    setState(() {
      _trashItems.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trash emptied successfully'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    await StorageEngine.clearHistory();
    setState(() {
      _historyItems.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All files cleared successfully'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _openMergePdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MergePdfScreen(
          historyItems: _historyItems,
          isDark: widget.isDarkMode,
          onAddHistoryItem: _addHistoryItem,
          onDeleteHistoryItem: _deleteHistoryItem,
        ),
      ),
    );
  }

  void _openSplitPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SplitPdfScreen(
          historyItems: _historyItems,
          isDark: widget.isDarkMode,
          onAddHistoryItem: _addHistoryItem,
          onDeleteHistoryItem: _deleteHistoryItem,
        ),
      ),
    );
  }

  void _openImageToPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ImageToPdfScreen(
          historyItems: _historyItems,
          isDark: widget.isDarkMode,
          onAddHistoryItem: _addHistoryItem,
          onDeleteHistoryItem: _deleteHistoryItem,
        ),
      ),
    );
  }

  void _openWordToPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => WordToPdfScreen(
          historyItems: _historyItems,
          isDark: widget.isDarkMode,
          onAddHistoryItem: _addHistoryItem,
          onDeleteHistoryItem: _deleteHistoryItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavBg = widget.isDarkMode ? const Color(0xFF16171B) : Colors.white;
    final dividerColor = widget.isDarkMode ? const Color(0xFF23242B) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: AppLogo(fontSize: 22, isDark: widget.isDarkMode),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 24),
            onPressed: () => setState(() => _currentTabIndex = 0),
          ),
          if (_currentTabIndex == 1)
            IconButton(
              icon: const Icon(Icons.view_agenda_outlined, size: 22),
              onPressed: () {},
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GestureDetector(
              onTap: () => LoginModalSheet.show(context),
              child: AnimatedBuilder(
                animation: CloudAuthService.instance.currentUserNotifier,
                builder: (context, _) {
                  final user = CloudAuthService.instance.currentUser;
                  final isLogged = user != null;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isLogged
                              ? const Color(0xFFFA9282)
                              : (widget.isDarkMode ? const Color(0xFF262831) : const Color(0xFFE2E8F0)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isLogged
                                ? const Color(0xFFFFB0A3)
                                : (widget.isDarkMode ? const Color(0xFF383A46) : const Color(0xFFCBD5E1)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: isLogged
                              ? Text(
                                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'G',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Icon(
                                  Icons.person_rounded,
                                  size: 20,
                                  color: widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                        ),
                      ),
                      if (isLogged)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: widget.isDarkMode ? const Color(0xFF16171B) : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          FilesTab(
            historyItems: _historyItems,
            trashItems: _trashItems,
            isDark: widget.isDarkMode,
            onDeleteItem: _deleteHistoryItem,
            onRestoreTrashItem: _restoreTrashItem,
            onDeletePermanently: _deleteTrashItemPermanently,
            onEmptyTrash: _emptyTrash,
            onClearAllFiles: _clearAllHistory,
            onBatchDeleteItems: _batchMoveToTrash,
            onAddHistoryItem: _addHistoryItem,
            onOpenImageToPdf: _openImageToPdf,
          ),
          ToolsTab(
            historyItems: _historyItems,
            isDark: widget.isDarkMode,
            onTriggerImageToPdf: _openImageToPdf,
            onAddHistoryItem: _addHistoryItem,
            onDeleteHistoryItem: _deleteHistoryItem,
          ),
          SettingsTab(
            isDark: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
            trashItems: _trashItems,
            onRestoreTrashItem: _restoreTrashItem,
            onDeletePermanently: _deleteTrashItemPermanently,
            onEmptyTrash: _emptyTrash,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bottomNavBg,
          border: Border(top: BorderSide(color: dividerColor, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.handyman_outlined, Icons.handyman_rounded, 'Tools'),
              _buildNavItem(2, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData solidIcon, String label) {
    final isSelected = _currentTabIndex == index;
    final inactiveColor = widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (isSelected) {
      // Rounded coral pill container matching Screenshots
      return GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFA9282), // Soft coral pill container from screenshot
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                solidIcon,
                color: const Color(0xFF1E1F24),
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _currentTabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Icon(outlineIcon, color: inactiveColor, size: 22),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: inactiveColor,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
