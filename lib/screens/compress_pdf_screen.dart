import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/space_empty_illustration.dart';

class CompressPdfScreen extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const CompressPdfScreen({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected PDFs, 1: Compressed PDFs
  bool _isSpeedDialOpen = false;
  bool _isCompressing = false;
  String _selectedLevel = 'Recommended'; // Extreme, Recommended, Low

  final List<SelectedPdfItem> _selectedPdfs = [];

  late AnimationController _fabAnimController;
  late Animation<double> _fabRotationAnim;

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

  Future<void> _pickPdfFromDevice() async {
    _closeSpeedDial();
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final List<SelectedPdfItem> newItems = [];
        for (final platformFile in result.files) {
          final filePath = platformFile.path;
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              final size = await file.length();
              final pageCount = await PdfEngine.getPdfPageCount(filePath);
              final name = platformFile.name.isNotEmpty
                  ? platformFile.name
                  : filePath.split(Platform.pathSeparator).last;

              newItems.add(
                SelectedPdfItem(
                  path: filePath,
                  name: name,
                  sizeBytes: size,
                  pageCount: pageCount,
                ),
              );
            }
          }
        }

        if (newItems.isNotEmpty) {
          setState(() {
            for (final item in newItems) {
              if (!_selectedPdfs.any((e) => e.path == item.path)) {
                _selectedPdfs.add(item);
              }
            }
            _activeChip = 0;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newItems.length} PDF(s) to compress list'),
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick PDF files: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _pickPdfFromHistory() {
    _closeSpeedDial();
    final availableHistory = widget.historyItems.where((item) {
      final file = File(item.path);
      return file.existsSync();
    }).toList();

    if (availableHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved PDFs found in app history yet.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final selectedIndices = <int>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return SafeArea(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select PDFs from History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            if (selectedIndices.length == availableHistory.length) {
                              selectedIndices.clear();
                            } else {
                              selectedIndices.addAll(List.generate(availableHistory.length, (i) => i));
                            }
                          });
                        },
                        child: Text(
                          selectedIndices.length == availableHistory.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: availableHistory.length,
                      itemBuilder: (ctx, i) {
                        final item = availableHistory[i];
                        final isChecked = selectedIndices.contains(i);
                        return CheckboxListTile(
                          activeColor: const Color(0xFF10B981),
                          value: isChecked,
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            '${item.pages} pages • ${item.size} • ${item.date}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedIndices.add(i);
                              } else {
                                selectedIndices.remove(i);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                      label: Text(
                        'Add Selected (${selectedIndices.length})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: selectedIndices.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              setState(() {
                                for (final idx in selectedIndices) {
                                  final hist = availableHistory[idx];
                                  final file = File(hist.path);
                                  final size = file.existsSync() ? file.lengthSync() : 0;
                                  if (!_selectedPdfs.any((e) => e.path == hist.path)) {
                                    _selectedPdfs.add(
                                      SelectedPdfItem(
                                        path: hist.path,
                                        name: hist.name,
                                        sizeBytes: size,
                                        pageCount: hist.pages,
                                      ),
                                    );
                                  }
                                }
                                _activeChip = 0;
                              });
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _removeSelectedPdf(int index) {
    setState(() {
      _selectedPdfs.removeAt(index);
    });
  }

  void _moveSelectedPdf(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _selectedPdfs.length) return;
    setState(() {
      final item = _selectedPdfs.removeAt(oldIndex);
      _selectedPdfs.insert(newIndex, item);
    });
  }

  void _clearSelectedPdfs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear List?'),
        content: const Text('Remove all selected PDF files from the compression list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedPdfs.clear();
              });
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCompressInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('PDF Compression Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• Extreme Compression:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
              Text(
                'Uses cross-reference streams and best deflate algorithms. Reduces file size up to 70% while maintaining document readability.\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Recommended Compression:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
              Text(
                'Best balance between visual quality and file size reduction (~50%). Ideal for email and upload portals.\n',
                style: TextStyle(fontSize: 13),
              ),
              Text(
                '• Low Compression:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
              Text(
                'Minimal compression for maximum graphic and vector preservation (~25% reduction).',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _startCompression() async {
    _closeSpeedDial();
    if (_selectedPdfs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one PDF to compress'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    final String defaultBaseName = _selectedPdfs.length == 1
        ? 'Compressed_${_selectedPdfs[0].name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')}'
        : 'Compressed_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    final controller = TextEditingController(text: defaultBaseName);
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    final docName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name Compressed PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preset: $_selectedLevel Compression\nDocument Name:',
              style: TextStyle(
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter document name'),
                    ),
                  ),
                  const Text(
                    '.pdf',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              var name = controller.text.trim();
              if (name.isEmpty) name = defaultBaseName;
              if (name.toLowerCase().endsWith('.pdf')) {
                name = name.substring(0, name.length - 4);
              }
              Navigator.pop(ctx, name);
            },
            child: const Text('Compress Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (docName != null && docName.isNotEmpty) {
      setState(() => _isCompressing = true);
      try {
        final List<PdfEngineResult> results = await PdfEngine.compressMultiplePdfs(
          items: _selectedPdfs,
          levelName: _selectedLevel,
          baseDocName: docName,
        );

        for (final res in results) {
          final newHistory = HistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: res.name,
            path: res.path,
            pages: res.pages,
            size: res.sizeStr,
            date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            toolType: 'Compress PDF',
          );
          widget.onAddHistoryItem(newHistory);
        }

        if (mounted) {
          final first = results.first;
          ExportModalSheet.show(
            context: context,
            pdfPath: first.path,
            docName: first.name,
            pages: first.pages,
            sizeStr: first.sizeStr,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compression failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isCompressing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = widget.isDark ? const Color(0xFF141518) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.compress_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Compress PDF',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 22),
            onPressed: _showCompressInfoDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Dual Tab Switcher
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabChip(
                        index: 0,
                        title: 'Selected PDFs',
                        count: _selectedPdfs.length,
                        icon: Icons.picture_as_pdf_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTabChip(
                        index: 1,
                        title: 'Compressed PDFs',
                        count: widget.historyItems.where((e) => e.toolType == 'Compress PDF').length,
                        icon: Icons.folder_zip_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Tab Content View
              Expanded(
                child: _activeChip == 0
                    ? _buildSelectedPdfsView()
                    : _buildCompressedHistoryView(),
              ),
            ],
          ),

          // Speed Dial Backdrop
          if (_isSpeedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSpeedDial,
                child: Container(color: Colors.black54),
              ),
            ),

          // Speed Dial Options
          if (_isSpeedDialOpen)
            Positioned(
              right: 20,
              bottom: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSpeedDialOption(
                    label: 'From Device',
                    icon: Icons.file_upload_outlined,
                    onTap: _pickPdfFromDevice,
                  ),
                  const SizedBox(height: 12),
                  _buildSpeedDialOption(
                    label: 'From History',
                    icon: Icons.history_rounded,
                    onTap: _pickPdfFromHistory,
                  ),
                ],
              ),
            ),

          // Floating Action Button
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'compress_fab',
              backgroundColor: const Color(0xFF10B981),
              onPressed: _toggleSpeedDial,
              child: AnimatedBuilder(
                animation: _fabRotationAnim,
                builder: (context, child) => Transform.rotate(
                  angle: _fabRotationAnim.value,
                  child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isCompressing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF10B981)),
                        const SizedBox(height: 18),
                        Text(
                          'Optimizing & Compressing PDF...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _activeChip == index;
    final activeBg = widget.isDark ? const Color(0xFF262831) : const Color(0xFFE2E8F0);
    final inactiveBg = widget.isDark ? const Color(0xFF191A20) : const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: () {
        _closeSpeedDial();
        setState(() => _activeChip = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981).withOpacity(0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF10B981) : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (widget.isDark ? Colors.white : const Color(0xFF0F172A))
                    : Colors.grey,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPdfsView() {
    if (_selectedPdfs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpaceEmptyIllustration(size: 180),
              const SizedBox(height: 20),
              const Text(
                'No PDFs Selected',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to select PDF files from your device or app history to compress.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                    label: const Text('Pick PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: _pickPdfFromDevice,
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('From History', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _pickPdfFromHistory,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final int totalBytes = _selectedPdfs.fold(0, (sum, item) => sum + item.sizeBytes);
    final String formattedTotalSize = PdfEngine.formatBytes(totalBytes);

    return Column(
      children: [
        // Compression Level Selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? const Color(0xFF2C2E37) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text(
                    'Compression Preset',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildLevelCard('Extreme', 'Extreme\n(~70%)', Icons.compress_rounded),
                  const SizedBox(width: 8),
                  _buildLevelCard('Recommended', 'Recommended\n(~50%)', Icons.auto_awesome_rounded),
                  const SizedBox(width: 8),
                  _buildLevelCard('Low', 'Low\n(~25%)', Icons.high_quality_rounded),
                ],
              ),
            ],
          ),
        ),

        // Header with count & Clear button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedPdfs.length} PDF(s) • Total $formattedTotalSize',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _clearSelectedPdfs,
              ),
            ],
          ),
        ),

        // Selected PDF List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 90),
            itemCount: _selectedPdfs.length,
            itemBuilder: (ctx, index) {
              final item = _selectedPdfs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2C2E37) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    // Index Badge
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PDF Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5322D).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE5322D), size: 22),
                    ),
                    const SizedBox(width: 12),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.pageCount} pages • ${item.formattedSize}',
                            style: TextStyle(
                              color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Move Up/Down buttons
                    if (_selectedPdfs.length > 1) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        onPressed: index > 0 ? () => _moveSelectedPdf(index, index - 1) : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        onPressed: index < _selectedPdfs.length - 1 ? () => _moveSelectedPdf(index, index + 1) : null,
                      ),
                    ],
                    // Remove button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.red),
                      onPressed: () => _removeSelectedPdf(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Sticky Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.compress_rounded, color: Colors.white, size: 22),
                label: Text(
                  _selectedPdfs.length == 1
                      ? 'Compress PDF'
                      : 'Compress ${_selectedPdfs.length} PDFs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: _startCompression,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(String level, String label, IconData icon) {
    final isSelected = _selectedLevel == level;
    final activeColor = const Color(0xFF10B981);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedLevel = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withOpacity(0.12)
                : (widget.isDark ? const Color(0xFF141518) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompressedHistoryView() {
    final compressedList = widget.historyItems.where((e) => e.toolType == 'Compress PDF').toList();

    if (compressedList.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SpaceEmptyIllustration(size: 160),
              const SizedBox(height: 18),
              const Text(
                'No Compressed PDFs Yet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Documents compressed with PDFDost will appear here for fast access and sharing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: compressedList.length,
      itemBuilder: (ctx, index) {
        final item = compressedList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? const Color(0xFF2C2E37) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.folder_zip_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.pages} pages • ${item.size} • ${item.date}',
                          style: TextStyle(
                            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDeleteHistoryItem != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                      onPressed: () => widget.onDeleteHistoryItem!(item),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => OpenFilex.open(item.path),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => Share.shareXFiles([XFile(item.path)], text: item.name),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final ok = await StorageEngine.saveToDownloads(item.path, item.name);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '✓ Saved to Downloads' : 'Save failed'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedDialOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
