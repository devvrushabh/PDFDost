import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/storage_engine.dart';
import '../services/word_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/space_empty_illustration.dart';

class WordToPdfScreen extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const WordToPdfScreen({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected Files, 1: Converted PDFs
  bool _isSpeedDialOpen = false;
  bool _isConverting = false;

  final List<SelectedWordItem> _selectedFiles = [];

  late AnimationController _fabAnimController;
  late Animation<double> _fabRotationAnim;

  static const List<String> supportedExtensions = [
    'doc',
    'docx',
    'xlsx',
    'xlsm',
    'xlsb',
    'xls',
    'xlw',
    'xltx',
    'xltm',
    'xlt',
    'csv',
    'xml',
    'ods',
    'prn',
    'txt',
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabRotationAnim = Tween<double>(begin: 0.0, end: math.pi / 4).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  void _toggleSpeedDial() {
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
      if (_isSpeedDialOpen) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
    });
  }

  void _closeSpeedDial() {
    if (_isSpeedDialOpen) {
      setState(() {
        _isSpeedDialOpen = false;
        _fabAnimController.reverse();
      });
    }
  }

  Color _getFormatColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'doc':
      case 'docx':
        return const Color(0xFF185ABD); // Word Blue
      case 'xlsx':
      case 'xlsm':
      case 'xlsb':
      case 'xls':
      case 'xlw':
      case 'xltx':
      case 'xltm':
      case 'xlt':
        return const Color(0xFF107C41); // Excel Green
      case 'csv':
      case 'ods':
      case 'prn':
        return const Color(0xFF0D9488); // Teal / Data
      case 'xml':
        return const Color(0xFFD97706); // Amber / XML
      case 'txt':
      default:
        return const Color(0xFF64748B); // Slate / Text
    }
  }

  IconData _getFormatIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xlsx':
      case 'xlsm':
      case 'xlsb':
      case 'xls':
      case 'xlw':
      case 'xltx':
      case 'xltm':
      case 'xlt':
        return Icons.table_chart_rounded;
      case 'csv':
      case 'ods':
      case 'prn':
        return Icons.grid_on_rounded;
      case 'xml':
        return Icons.code_rounded;
      case 'txt':
      default:
        return Icons.article_rounded;
    }
  }

  String _getFormatCategory(String ext) {
    switch (ext.toLowerCase()) {
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xlsx':
      case 'xlsm':
      case 'xlsb':
      case 'xls':
      case 'xlw':
      case 'xltx':
      case 'xltm':
      case 'xlt':
        return 'Excel Workbook';
      case 'csv':
        return 'CSV Spreadsheet';
      case 'ods':
        return 'OpenDocument Sheet';
      case 'prn':
        return 'Print Data Document';
      case 'xml':
        return 'XML Data Document';
      case 'txt':
      default:
        return 'Text Document';
    }
  }

  Future<void> _pickWordFilesFromDevice({
    bool forceAny = false,
    List<String>? specificExtensions,
  }) async {
    _closeSpeedDial();
    try {
      FilePickerResult? result;
      final extsToPick = specificExtensions ?? supportedExtensions;

      if (forceAny) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: extsToPick,
          allowMultiple: true,
        );
      }

      if (result != null && result.files.isNotEmpty) {
        final List<SelectedWordItem> newItems = [];
        for (final platformFile in result.files) {
          final filePath = platformFile.path;
          if (filePath != null) {
            final lower = filePath.toLowerCase();
            final ext = lower.contains('.') ? lower.split('.').last : '';

            // Check if extension is supported
            if (!supportedExtensions.contains(ext)) {
              if (forceAny) continue;
            }

            final file = File(filePath);
            if (await file.exists()) {
              final size = await file.length();
              final name = platformFile.name.isNotEmpty
                  ? platformFile.name
                  : filePath.split(Platform.pathSeparator).last;

              newItems.add(
                SelectedWordItem(
                  path: filePath,
                  name: name,
                  sizeBytes: size,
                  extension: ext.isNotEmpty ? ext : 'doc',
                ),
              );
            }
          }
        }

        if (newItems.isNotEmpty) {
          setState(() {
            for (final item in newItems) {
              if (!_selectedFiles.any((e) => e.path == item.path)) {
                _selectedFiles.add(item);
              }
            }
            _activeChip = 0; // Focus on selected files
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newItems.length} file(s) to convert list'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } else if (forceAny && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No supported office or document files selected'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick files: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _clearSelectedFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _removeFile(int index) {
    if (index >= 0 && index < _selectedFiles.length) {
      final removed = _selectedFiles[index];
      setState(() {
        _selectedFiles.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${removed.name}"'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _convertToPdf() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one document or spreadsheet file to convert'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    _closeSpeedDial();
    setState(() => _isConverting = true);

    try {
      final result = await WordEngine.convertWordFilesToPdf(items: _selectedFiles);

      // Save to public storage
      try {
        await StorageEngine.saveToDownloads(result.path, result.name);
      } catch (_) {}

      // Add to app history
      final historyItem = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        path: result.path,
        pages: result.pages,
        size: result.sizeStr,
        date: DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.now()),
        toolType: 'Word to PDF',
      );
      widget.onAddHistoryItem(historyItem);

      if (mounted) {
        setState(() {
          _isConverting = false;
          _activeChip = 1; // Switch to Converted PDFs tab
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document converted to PDF successfully!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 1),
          ),
        );

        // Show Export Modal Sheet
        ExportModalSheet.show(
          context: context,
          pdfPath: result.path,
          docName: result.name,
          pages: result.pages,
          sizeStr: result.sizeStr,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to convert file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<HistoryItem> get _convertedHistory {
    return widget.historyItems.where((e) => e.toolType == 'Word to PDF').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF0F1015) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.isDark ? const Color(0xFF16171B) : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Word & Office to PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              'DOC, DOCX, XLSX, XLS, CSV, XML, ODS, TXT',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import Files',
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF185ABD)),
            onPressed: () => _pickWordFilesFromDevice(),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Segmented Chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      // Chip 0: Selected Files
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _closeSpeedDial();
                            setState(() => _activeChip = 0);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _activeChip == 0
                                  ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                                  : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _activeChip == 0
                                    ? (widget.isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8))
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF185ABD).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.description_rounded,
                                        color: Color(0xFF185ABD),
                                        size: 18,
                                      ),
                                    ),
                                    if (_selectedFiles.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF185ABD),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_selectedFiles.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Selected Files',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Chip 1: Converted PDFs
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            _closeSpeedDial();
                            setState(() => _activeChip = 1);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: _activeChip == 1
                                  ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                                  : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _activeChip == 1
                                    ? (widget.isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8))
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Color(0xFF10B981),
                                        size: 18,
                                      ),
                                    ),
                                    if (_convertedHistory.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_convertedHistory.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Converted PDFs',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Content
                Expanded(
                  child: _activeChip == 0 ? _buildSelectedFilesContent() : _buildConvertedPdfsContent(),
                ),
              ],
            ),

            // Backdrop when speed dial is open
            if (_isSpeedDialOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSpeedDial,
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),

            // Expandable Speed Dial (Positioned right above convert button on the right side)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              bottom: (_selectedFiles.isNotEmpty && _activeChip == 0) ? 92 : 24,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSpeedDialOpen) ...[
                    // Browse All Formats
                    _buildSpeedDialOption(
                      icon: Icons.folder_open_rounded,
                      label: 'Import All Supported Formats',
                      onTap: () => _pickWordFilesFromDevice(),
                    ),
                    const SizedBox(height: 10),
                    // Word DOC / DOCX
                    _buildSpeedDialOption(
                      icon: Icons.description_rounded,
                      label: 'Word (.doc, .docx)',
                      onTap: () => _pickWordFilesFromDevice(specificExtensions: ['doc', 'docx']),
                    ),
                    const SizedBox(height: 10),
                    // Excel & Sheets
                    _buildSpeedDialOption(
                      icon: Icons.table_chart_rounded,
                      label: 'Excel (.xlsx, .xls, .csv, .ods)',
                      onTap: () => _pickWordFilesFromDevice(specificExtensions: [
                        'xlsx', 'xlsm', 'xlsb', 'xls', 'xlw', 'xltx', 'xltm', 'xlt', 'csv', 'ods', 'prn'
                      ]),
                    ),
                    const SizedBox(height: 10),
                    // Text & XML
                    _buildSpeedDialOption(
                      icon: Icons.article_rounded,
                      label: 'Text & XML (.txt, .xml)',
                      onTap: () => _pickWordFilesFromDevice(specificExtensions: ['txt', 'xml', 'prn']),
                    ),
                    const SizedBox(height: 10),
                    // All Documents Fallback
                    _buildSpeedDialOption(
                      icon: Icons.file_present_rounded,
                      label: 'Browse All Documents',
                      onTap: () => _pickWordFilesFromDevice(forceAny: true),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Main Coral Action Button
                  GestureDetector(
                    onTap: _toggleSpeedDial,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA9282), // Coral theme
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA9282).withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _fabRotationAnim,
                        builder: (ctx, child) => Transform.rotate(
                          angle: _fabRotationAnim.value,
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Convert Action Bar
            if (_selectedFiles.isNotEmpty && _activeChip == 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 90, 16),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF16171B) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185ABD),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isConverting ? null : _convertToPdf,
                          icon: _isConverting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                          label: Text(
                            _isConverting
                                ? 'Converting...'
                                : 'Convert to PDF (${_selectedFiles.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Converting Loading Overlay
            if (_isConverting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  alignment: Alignment.center,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF185ABD)),
                        const SizedBox(height: 18),
                        Text(
                          'Converting Documents to PDF...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Extracting tables, text & compiling vector pages...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1A1B20) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: widget.isDark ? Colors.white : const Color(0xFF0F172A), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilesContent() {
    if (_selectedFiles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpaceEmptyIllustration(
                title: 'No files selected',
                subtitle: 'Import .doc, .docx, .xlsx, .csv, .xml, .ods, .txt files from device',
                isDark: widget.isDark,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185ABD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _pickWordFilesFromDevice(),
                icon: const Icon(Icons.file_open_rounded, color: Colors.white),
                label: const Text(
                  'Browse Files (.doc, .xlsx, .csv, .txt)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              // Supported formats badge pills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  'DOCX', 'DOC', 'XLSX', 'XLS', 'CSV', 'XML', 'ODS', 'TXT', 'XLSM', 'XLSB'
                ].map((format) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E2026) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '.$format',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header with count & clear
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedFiles.length} File(s) in Conversion Order',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: _clearSelectedFiles,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ),
            ],
          ),
        ),

        // Reorderable list of files
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _selectedFiles.length,
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _selectedFiles.removeAt(oldIndex);
                _selectedFiles.insert(newIndex, item);
              });
            },
            itemBuilder: (ctx, index) {
              final item = _selectedFiles[index];
              final formatColor = _getFormatColor(item.extension);
              final formatIcon = _getFormatIcon(item.extension);
              final categoryName = _getFormatCategory(item.extension);

              return Container(
                key: ValueKey(item.path),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2A2D35) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: formatColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(formatIcon, color: Colors.white, size: 24),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.extension.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    '${item.formattedSize}  •  $categoryName',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () => _removeFile(index),
                      ),
                      const Icon(Icons.drag_handle_rounded, color: Color(0xFF94A3B8), size: 22),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConvertedPdfsContent() {
    final list = _convertedHistory;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpaceEmptyIllustration(
              title: 'No converted PDFs yet',
              subtitle: 'Select documents or spreadsheets and tap Convert to PDF',
              isDark: widget.isDark,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF185ABD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                setState(() => _activeChip = 0);
              },
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text(
                'Go to Select Files',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: list.length,
      itemBuilder: (ctx, index) {
        final item = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? const Color(0xFF2A2D35) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE5322D).withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE5322D), size: 24),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              '${item.pages} page(s) • ${item.size} • ${item.date}',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_outlined, size: 20, color: Color(0xFF64748B)),
                  onPressed: () {
                    Share.shareXFiles([XFile(item.path)], text: 'PDF from ${item.name}');
                  },
                ),
                IconButton(
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFF185ABD)),
                  onPressed: () {
                    OpenFilex.open(item.path);
                  },
                ),
                if (widget.onDeleteHistoryItem != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                    onPressed: () {
                      widget.onDeleteHistoryItem!(item);
                      setState(() {});
                    },
                  ),
              ],
            ),
            onTap: () {
              OpenFilex.open(item.path);
            },
          ),
        );
      },
    );
  }
}
