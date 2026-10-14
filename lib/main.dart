import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'models/models.dart';
import 'screens/files_tab.dart';
import 'screens/home_tab.dart';
import 'screens/merge_pdf_screen.dart';
import 'screens/split_pdf_screen.dart';
import 'screens/settings_tab.dart';
import 'screens/tools_tab.dart';
import 'screens/word_to_pdf_screen.dart';
import 'screens/trash_screen.dart';
import 'services/storage_engine.dart';
import 'widgets/app_logo.dart';
import 'widgets/login_modal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  int _currentTabIndex = 0; // 0: Home, 1: Files, 2: Tools, 3: Settings
  final List<SelectedImageItem> _selectedImages = [];
  final List<HistoryItem> _historyItems = [];
  final List<TrashItem> _trashItems = [];
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickGalleryImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final List<SelectedImageItem> newItems = [];
        for (final img in images) {
          final file = File(img.path);
          if (await file.exists()) {
            final size = await file.length();
            final name = img.name.isNotEmpty ? img.name : file.path.split('/').last;
            newItems.add(SelectedImageItem(path: file.path, name: name, sizeBytes: size));
          }
        }
        setState(() {
          for (final item in newItems) {
            if (!_selectedImages.any((e) => e.path == item.path)) {
              _selectedImages.add(item);
            }
          }
          _currentTabIndex = 0; // Switch to Home to view selected images
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick images: $e')),
      );
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
      if (image != null) {
        final file = File(image.path);
        if (await file.exists()) {
          final size = await file.length();
          final name = image.name.isNotEmpty ? image.name : file.path.split('/').last;
          setState(() {
            _selectedImages.add(SelectedImageItem(path: file.path, name: name, sizeBytes: size));
            _currentTabIndex = 0;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _moveSelectedImage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _selectedImages.length) return;
    setState(() {
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _changeSelectedImagePosition(int currentIndex) {
    final controller = TextEditingController(text: '${currentIndex + 1}');
    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move image to new position (1 to ${_selectedImages.length}):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Page number'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (target != null && target >= 1 && target <= _selectedImages.length) {
                _moveSelectedImage(currentIndex, target - 1);
              }
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearSelectedImages() {
    setState(() {
      _selectedImages.clear();
    });
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
          duration: const Duration(seconds: 3),
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
            onPressed: () => setState(() => _currentTabIndex = 1),
          ),
          if (_currentTabIndex == 2)
            IconButton(
              icon: const Icon(Icons.view_agenda_outlined, size: 22),
              onPressed: () {},
            ),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GestureDetector(
              onTap: () => LoginModalSheet.show(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? const Color(0xFF262831) : const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isDarkMode ? const Color(0xFF383A46) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          HomeTab(
            selectedImages: _selectedImages,
            historyItems: _historyItems,
            isDark: widget.isDarkMode,
            onPickGallery: _pickGalleryImages,
            onPickCamera: _pickCameraImage,
            onRemoveImage: _removeSelectedImage,
            onMoveImage: _moveSelectedImage,
            onChangePosition: _changeSelectedImagePosition,
            onClearImages: _clearSelectedImages,
            onDeleteHistoryItem: _deleteHistoryItem,
            onAddHistoryItem: _addHistoryItem,
            onOpenMergePdf: _openMergePdf,
            onOpenSplitPdf: _openSplitPdf,
            onSwitchTab: (idx) => setState(() => _currentTabIndex = idx),
            onOpenWordToPdf: _openWordToPdf,
          ),
          FilesTab(
            historyItems: _historyItems,
            trashItems: _trashItems,
            isDark: widget.isDarkMode,
            onDeleteItem: _deleteHistoryItem,
            onRestoreTrashItem: _restoreTrashItem,
            onDeletePermanently: _deleteTrashItemPermanently,
            onEmptyTrash: _emptyTrash,
          ),
          ToolsTab(
            historyItems: _historyItems,
            isDark: widget.isDarkMode,
            onTriggerImageToPdf: _pickGalleryImages,
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
              _buildNavItem(1, Icons.folder_outlined, Icons.folder_rounded, 'Files'),
              _buildNavItem(2, Icons.handyman_outlined, Icons.handyman_rounded, 'Tools'),
              _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
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
