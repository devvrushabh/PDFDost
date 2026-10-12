import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Img2PdfApp());
}

class Img2PdfApp extends StatefulWidget {
  const Img2PdfApp({super.key});

  @override
  State<Img2PdfApp> createState() => _Img2PdfAppState();
}

class _Img2PdfAppState extends State<Img2PdfApp> {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _themePrefKey = 'img2pdf_theme_mode';

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themePrefKey) ?? false;
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> _toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() {
      _themeMode = nextMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, nextMode == ThemeMode.dark);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE5322D);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.light,
        primary: primaryRed,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryRed,
        brightness: Brightness.dark,
        primary: primaryRed,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        elevation: 0,
        scrolledUnderElevation: 1,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
        titleTextStyle: TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return MaterialApp(
      title: 'Img2PDF',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomeScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class SelectedImageItem {
  final String path;
  final String name;
  final int sizeBytes;

  SelectedImageItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class HistoryItem {
  final String id;
  final String name;
  final String path;
  final int pages;
  final String size;
  final String date;

  HistoryItem({
    required this.id,
    required this.name,
    required this.path,
    required this.pages,
    required this.size,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'pages': pages,
        'size': size,
        'date': date,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        pages: json['pages'] as int,
        size: json['size'] as String,
        date: json['date'] as String,
      );
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTabIndex = 0; // 0: Convert, 1: History
  final List<SelectedImageItem> _selectedImages = [];
  final List<HistoryItem> _historyItems = [];
  bool _isConverting = false;

  final ImagePicker _picker = ImagePicker();
  static const String _historyKey = 'img2pdf_history_list';
  static const MethodChannel _storageChannel = MethodChannel('com.devvrushabh.img2pdf/storage');

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        setState(() {
          _historyItems.clear();
          _historyItems.addAll(
            decoded.map((item) => HistoryItem.fromJson(item as Map<String, dynamic>)),
          );
        });
      }
    } catch (e) {
      debugPrint('Failed to load history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _historyItems.map((e) => e.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Failed to save history: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final List<SelectedImageItem> newItems = [];
        for (final img in images) {
          final file = File(img.path);
          if (await file.exists()) {
            final size = await file.length();
            final name = img.name.isNotEmpty ? img.name : file.path.split('/').last;
            newItems.add(
              SelectedImageItem(
                path: file.path,
                name: name,
                sizeBytes: size,
              ),
            );
          }
        }
        setState(() {
          for (final item in newItems) {
            if (!_selectedImages.any((existing) => existing.path == item.path)) {
              _selectedImages.add(item);
            }
          }
        });
      }
    } catch (e) {
      _showSnackbar('Failed to pick images: $e', isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _clearSelectedImages() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Clear Selection?'),
        content: const Text('Are you sure you want to remove all selected images?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedImages.clear();
              });
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _moveImage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _selectedImages.length) return;
    setState(() {
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  void _changeImagePosition(int currentIndex) {
    final controller = TextEditingController(text: '${currentIndex + 1}');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move this image to a new page position (1 to ${_selectedImages.length}):',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter page number',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5322D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (target != null && target >= 1 && target <= _selectedImages.length) {
                _moveImage(currentIndex, target - 1);
              } else {
                _showSnackbar('Please enter a valid position between 1 and ${_selectedImages.length}', isError: true);
              }
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog() async {
    if (_selectedImages.isEmpty) {
      _showSnackbar('Please select at least one image first.', isError: true);
      return;
    }

    final defaultName = 'Document_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Name Your PDF',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom name before converting your images:',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter document name',
                      ),
                    ),
                  ),
                  const Text(
                    '.pdf',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE5322D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5322D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              var name = controller.text.trim();
              if (name.isEmpty) name = defaultName;
              if (name.toLowerCase().endsWith('.pdf')) {
                name = name.substring(0, name.length - 4);
              }
              // Sanitize filename
              name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
              Navigator.pop(ctx, name);
            },
            child: const Text('Convert Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _convertImagesToPdf(result);
    }
  }

  Future<void> _convertImagesToPdf(String docName) async {
    setState(() {
      _isConverting = true;
    });

    try {
      final pdf = pw.Document();

      for (final imgItem in _selectedImages) {
        final bytes = await File(imgItem.path).readAsBytes();
        final pdfImage = pw.MemoryImage(bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context ctx) {
              return pw.Center(
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              );
            },
          ),
        );
      }

      final appDir = await getApplicationDocumentsDirectory();
      final pdfFileName = '$docName.pdf';
      final pdfFile = File('${appDir.path}/$pdfFileName');
      final pdfBytes = await pdf.save();
      await pdfFile.writeAsBytes(pdfBytes);

      final fileSizeStr = _formatBytes(pdfBytes.length);
      final historyEntry = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: pdfFileName,
        path: pdfFile.path,
        pages: _selectedImages.length,
        size: fileSizeStr,
        date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      );

      setState(() {
        _historyItems.insert(0, historyEntry);
      });
      await _saveHistory();

      if (mounted) {
        _showExportBottomSheet(pdfFile.path, pdfFileName, _selectedImages.length, fileSizeStr);
      }
    } catch (e) {
      _showSnackbar('Conversion failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
      }
    }
  }

  void _showExportBottomSheet(String pdfPath, String docName, int pages, String sizeStr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool hasSaved = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'PDF Created Successfully!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                docName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE5322D),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$pages Pages  •  $sizeStr',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              // 1. Share Option (WhatsApp, Social Media, etc.)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5322D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await Share.shareXFiles(
                      [XFile(pdfPath, mimeType: 'application/pdf')],
                      text: 'Converted PDF: $docName',
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text(
                    'Share (WhatsApp, Apps...)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 2. Print Document (Option right after Share)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await _printPdf(pdfPath, docName);
                  },
                  icon: const Icon(Icons.print_rounded, color: Color(0xFF0284C7)),
                  label: const Text('Print Document', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              // 3. Save to Device (Downloads)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: hasSaved
                        ? const Color(0xFF16A34A)
                        : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)),
                    side: BorderSide(
                      color: hasSaved
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final success = await _savePdfToDevice(pdfPath, docName);
                    if (success) {
                      setSheetState(() {
                        hasSaved = true;
                      });
                    }
                  },
                  icon: Icon(
                    hasSaved ? Icons.check_circle_rounded : Icons.download_rounded,
                    color: hasSaved ? const Color(0xFF16A34A) : const Color(0xFFE5322D),
                  ),
                  label: Text(
                    hasSaved ? '✓ Saved to Downloads!' : 'Save to Device (Downloads)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 3. Open / View PDF
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await OpenFilex.open(pdfPath);
                  },
                  icon: const Icon(Icons.visibility_rounded, color: Color(0xFF2563EB)),
                  label: const Text('Open / View PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printPdf(String pdfPath, String docName) async {
    try {
      final file = File(pdfPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: docName,
        );
      } else {
        _showSnackbar('File not found for printing.', isError: true);
      }
    } catch (e) {
      _showSnackbar('Print error: $e', isError: true);
    }
  }

  Future<bool> _savePdfToDevice(String sourcePath, String fileName) async {
    try {
      if (Platform.isAndroid) {
        try {
          final String? savedLocation = await _storageChannel.invokeMethod<String>(
            'saveToDownloads',
            {'sourcePath': sourcePath, 'fileName': fileName},
          );
          if (savedLocation != null) {
            _showSnackbar('✓ Saved to Downloads folder: $fileName');
            return true;
          }
        } on PlatformException catch (pe) {
          debugPrint('MethodChannel saveToDownloads error: $pe');
        }
      }

      // Fallback path resolution for non-Android or legacy storage
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = downloadDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (targetDir != null) {
        final destPath = '${targetDir.path}/$fileName';
        await File(sourcePath).copy(destPath);
        _showSnackbar('✓ Saved successfully to ${targetDir.path}/$fileName');
        return true;
      } else {
        _showSnackbar('Could not locate public storage folder.', isError: true);
        return false;
      }
    } catch (e) {
      _showSnackbar('Save error: $e', isError: true);
      return false;
    }
  }

  void _deleteHistoryItem(HistoryItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Delete PDF?'),
        content: Text('Delete "${item.name}" from your saved history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final file = File(item.path);
                if (await file.exists()) {
                  await file.delete();
                }
              } catch (_) {}
              setState(() {
                _historyItems.removeWhere((h) => h.id == item.id);
              });
              await _saveHistory();
              _showSnackbar('Deleted ${item.name}');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _clearAllHistory() {
    if (_historyItems.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Text('Clear All History?'),
        content: const Text('This will clear all records of converted PDFs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE5322D)),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _historyItems.clear();
              });
              await _saveHistory();
              _showSnackbar('History cleared.');
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5322D),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Img2PDF'),
          ],
        ),
        actions: [
          // Theme Switcher Button (Top Right)
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: widget.isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFF1E293B),
            ),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 0 ? const Color(0xFFE5322D) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Convert',
                        style: TextStyle(
                          color: _activeTabIndex == 0
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTabIndex == 1 ? const Color(0xFFE5322D) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'History (${_historyItems.length})',
                        style: TextStyle(
                          color: _activeTabIndex == 1
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _activeTabIndex,
            children: [
              _buildConvertTab(isDark),
              _buildHistoryTab(isDark),
            ],
          ),
          if (_isConverting)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFFE5322D)),
                      const SizedBox(height: 18),
                      Text(
                        'Converting Images to PDF...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Optimizing pages, please wait',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConvertTab(bool isDark) {
    if (_selectedImages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: Color(0xFFE5322D),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Images to Convert',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose multiple pictures from your gallery\nto create an optimized PDF document',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5322D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                        label: const Text(
                          'SELECT IMAGES',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Supports JPG • PNG • WEBP • JPEG',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedImages.length} Image${_selectedImages.length > 1 ? 's' : ''} Selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE5322D),
                      side: const BorderSide(color: Color(0xFFE5322D)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: _clearSelectedImages,
                    child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Image List View
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final img = _selectedImages[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Prominent Position Number Badge (Tap to quickly change position)
                    GestureDetector(
                      onTap: () => _changeImagePosition(index),
                      child: Tooltip(
                        message: 'Tap to change page position',
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5322D),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE5322D).withOpacity(0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 2. Visual Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(img.path),
                        width: 66,
                        height: 66,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 66,
                          height: 66,
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 3. Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _changeImagePosition(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Page ${index + 1} of ${_selectedImages.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE5322D),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            img.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            img.formattedSize,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 4. BIG, CLEARLY VISIBLE POSITIONING ARROWS
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // BIG MOVE UP BUTTON
                        InkWell(
                          onTap: index > 0 ? () => _moveImage(index, index - 1) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: index > 0
                                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: index > 0
                                    ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 22,
                              color: index > 0
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // BIG MOVE DOWN BUTTON
                        InkWell(
                          onTap: index < _selectedImages.length - 1 ? () => _moveImage(index, index + 1) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: index < _selectedImages.length - 1
                                  ? (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: index < _selectedImages.length - 1
                                    ? (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              size: 22,
                              color: index < _selectedImages.length - 1
                                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                  : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // DELETE BUTTON
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => _removeImage(index),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Sticky Bottom Convert Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5322D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _showRenameDialog,
              child: Text(
                'CONVERT ${_selectedImages.length} IMAGE${_selectedImages.length > 1 ? 'S' : ''} TO PDF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_historyItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Converted PDFs Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your generated PDF files will appear here so you can view, share, or save them anytime.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5322D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => setState(() => _activeTabIndex = 0),
                icon: const Icon(Icons.add),
                label: const Text('Convert Images Now'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stored Files (${_historyItems.length})',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 30),
                ),
                onPressed: _clearAllHistory,
                child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: _historyItems.length,
            itemBuilder: (context, index) {
              final item = _historyItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFFE5322D),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.date}  •  ${item.pages} pgs  •  ${item.size}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                          onPressed: () => _deleteHistoryItem(item),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE5322D),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              backgroundColor: isDark ? const Color(0xFF3B0707) : const Color(0xFFFEF2F2),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await Share.shareXFiles(
                                [XFile(item.path, mimeType: 'application/pdf')],
                                text: item.name,
                              );
                            },
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: const Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              side: const BorderSide(color: Color(0xFFBAE6FD)),
                              backgroundColor: isDark ? const Color(0xFF082F49) : const Color(0xFFF0F9FF),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _printPdf(item.path, item.name),
                            icon: const Icon(Icons.print_rounded, size: 14),
                            label: const Text('Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B),
                              side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _savePdfToDevice(item.path, item.name),
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              backgroundColor: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => OpenFilex.open(item.path),
                            icon: const Icon(Icons.visibility_rounded, size: 14),
                            label: const Text('Open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
