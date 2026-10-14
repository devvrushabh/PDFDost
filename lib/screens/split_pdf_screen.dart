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

class SplitPdfScreen extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const SplitPdfScreen({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected PDFs, 1: Split PDFs
  bool _isSpeedDialOpen = false;
  bool _isSplitting = false;

  final List<SplitPdfConfigItem> _selectedPdfs = [];

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
        final List<SplitPdfConfigItem> newItems = [];
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
                SplitPdfConfigItem(
                  path: filePath,
                  name: name,
                  sizeBytes: size,
                  pageCount: pageCount,
                  startPage: 1,
                  endPage: pageCount,
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
                content: Text('Added ${newItems.length} PDF(s) to split list'),
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
          ),
        );
      }
    }
  }

  void _showPickFromAppHistoryModal() {
    _closeSpeedDial();

    final availableHistory = widget.historyItems.where((item) {
      final file = File(item.path);
      return file.existsSync();
    }).toList();

    if (availableHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved PDFs found in app history yet. Convert images or browse device files!'),
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select from App PDFs',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick documents to extract or split pages from:',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableHistory.length,
                      itemBuilder: (ctx, i) {
                        final item = availableHistory[i];
                        final isChecked = selectedIndices.contains(i);
                        return CheckboxListTile(
                          activeColor: const Color(0xFFE5322D),
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
                              color: const Color(0xFFFF7A00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.call_split_rounded, color: Color(0xFFFF7A00), size: 20),
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
                        backgroundColor: const Color(0xFFE5322D),
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
                                      SplitPdfConfigItem(
                                        path: hist.path,
                                        name: hist.name,
                                        sizeBytes: size,
                                        pageCount: hist.pages,
                                        startPage: 1,
                                        endPage: hist.pages,
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

  void _clearSelectedPdfs() {
    setState(() {
      _selectedPdfs.clear();
    });
  }

  Future<void> _showRenameAndSplitDialog() async {
    if (_selectedPdfs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 PDF document to split'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Validate page ranges
    for (final item in _selectedPdfs) {
      if (item.startPage > item.endPage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid range for "${item.name}": start page cannot be greater than end page.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    final defaultName = 'Split_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    final docName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name Your Split PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom document name for the extracted PDF output:',
              style: TextStyle(
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
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
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5322D)),
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
              backgroundColor: const Color(0xFFE5322D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              var name = controller.text.trim();
              if (name.isEmpty) name = defaultName;
              if (name.toLowerCase().endsWith('.pdf')) {
                name = name.substring(0, name.length - 4);
              }
              Navigator.pop(ctx, name);
            },
            child: const Text('Split Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (docName != null && docName.isNotEmpty) {
      setState(() => _isSplitting = true);
      try {
        final List<PdfEngineResult> results = await PdfEngine.splitMultiplePdfs(
          items: _selectedPdfs,
          baseDocName: docName,
        );

        for (final result in results) {
          final newHistory = HistoryItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: result.name,
            path: result.path,
            pages: result.pages,
            size: result.sizeStr,
            date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            toolType: 'Split PDF',
          );
          widget.onAddHistoryItem(newHistory);
        }

        if (mounted && results.isNotEmpty) {
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
              content: Text('Split failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSplitting = false);
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
                color: const Color(0xFFFF7A00).withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.call_split_rounded, color: Color(0xFFFF7A00), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Split PDF',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('How to Split PDFs'),
                  content: const Text(
                    '1. Tap the coral (+) button to select one or more PDF files.\n\n'
                    '2. For each document, choose the range of pages to extract (or use presets like First Page, All Pages).\n\n'
                    '3. Tap SPLIT PDF to extract the exact vector pages into your new PDF!',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _closeSpeedDial,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Top Segmented Chips (Exact Match to Images to PDF style)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      // Chip 1: Selected PDFs
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
                                        color: const Color(0xFFFF7A00).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.call_split_rounded,
                                        color: Color(0xFFFF7A00),
                                        size: 18,
                                      ),
                                    ),
                                    if (_selectedPdfs.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF7A00),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_selectedPdfs.length}',
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
                                  'Selected PDFs',
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

                      // Chip 2: Split PDFs
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
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.description_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Split PDFs',
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

                // 2. Body Content
                Expanded(
                  child: _activeChip == 0 ? _buildSelectedPdfsContent() : _buildSplitPdfsContent(),
                ),
              ],
            ),

            // 3. Dark backdrop when speed dial is open
            if (_isSpeedDialOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSpeedDial,
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),

            // 4. Expandable Speed Dial (Coral FAB)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              bottom: (_selectedPdfs.isNotEmpty && _activeChip == 0) ? 92 : 24,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSpeedDialOpen) ...[
                    _buildSpeedDialOption(
                      icon: Icons.folder_open_rounded,
                      label: 'Browse Device',
                      onTap: _pickPdfFromDevice,
                    ),
                    const SizedBox(height: 12),
                    _buildSpeedDialOption(
                      icon: Icons.history_rounded,
                      label: 'From App PDFs',
                      onTap: _showPickFromAppHistoryModal,
                    ),
                    const SizedBox(height: 14),
                  ],

                  GestureDetector(
                    onTap: _toggleSpeedDial,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA9282),
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
                            color: Color(0xFF1E1F24),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Splitting Loading Overlay
            if (_isSplitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                        const CircularProgressIndicator(color: Color(0xFFE5322D)),
                        const SizedBox(height: 18),
                        Text(
                          'Splitting PDF Document...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Extracting vector pages into your new PDF...',
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
            Icon(icon, color: widget.isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPdfsContent() {
    if (_selectedPdfs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpaceEmptyIllustration(
              title: 'No PDFs selected',
              subtitle: 'Select PDF documents to extract or split pages',
              isDark: widget.isDark,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5322D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _pickPdfFromDevice,
              icon: const Icon(Icons.file_open_rounded, color: Colors.white),
              label: const Text(
                'Browse PDF Files',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedPdfs.length} Document(s) to Split',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton.icon(
                onPressed: _clearSelectedPdfs,
                icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _selectedPdfs.length,
            itemBuilder: (ctx, idx) {
              final pdf = _selectedPdfs[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2A2B33) : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top file info row
                    Row(
                      children: [
                        // Position badge
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Color(0xFFFF7A00),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Document icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.call_split_rounded,
                            color: Color(0xFFFF7A00),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pdf.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${pdf.pageCount} total pages • ${pdf.formattedSize}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFEF4444)),
                          onPressed: () => _removeSelectedPdf(idx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: widget.isDark ? const Color(0xFF282A33) : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 12),

                    // Page range selector row
                    Row(
                      children: [
                        const Text(
                          'Extract Range:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5322D).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Extracting ${pdf.pagesToExtractCount} of ${pdf.pageCount} page(s)',
                            style: const TextStyle(
                              color: Color(0xFFE5322D),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Inputs for From & To
                    Row(
                      children: [
                        // From page
                        Expanded(
                          child: _buildPageNumberSelector(
                            label: 'From Page',
                            value: pdf.startPage,
                            min: 1,
                            max: pdf.endPage,
                            onChanged: (newVal) {
                              setState(() {
                                pdf.startPage = newVal;
                              });
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF94A3B8)),
                        ),
                        // To page
                        Expanded(
                          child: _buildPageNumberSelector(
                            label: 'To Page',
                            value: pdf.endPage,
                            min: pdf.startPage,
                            max: pdf.pageCount,
                            onChanged: (newVal) {
                              setState(() {
                                pdf.endPage = newVal;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Presets
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPresetChip(
                          label: 'All Pages (1-${pdf.pageCount})',
                          isSelected: pdf.startPage == 1 && pdf.endPage == pdf.pageCount,
                          onTap: () {
                            setState(() {
                              pdf.startPage = 1;
                              pdf.endPage = pdf.pageCount;
                            });
                          },
                        ),
                        _buildPresetChip(
                          label: 'First Page',
                          isSelected: pdf.startPage == 1 && pdf.endPage == 1,
                          onTap: () {
                            setState(() {
                              pdf.startPage = 1;
                              pdf.endPage = 1;
                            });
                          },
                        ),
                        if (pdf.pageCount > 1)
                          _buildPresetChip(
                            label: 'Last Page (${pdf.pageCount})',
                            isSelected: pdf.startPage == pdf.pageCount && pdf.endPage == pdf.pageCount,
                            onTap: () {
                              setState(() {
                                pdf.startPage = pdf.pageCount;
                                pdf.endPage = pdf.pageCount;
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Sticky Split Action Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5322D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: _showRenameAndSplitDialog,
              icon: const Icon(Icons.call_split_rounded, color: Colors.white),
              label: Text(
                _selectedPdfs.length > 1
                    ? 'SPLIT ${_selectedPdfs.length} PDFS'
                    : 'SPLIT TO PDF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageNumberSelector({
    required String label,
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141518) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF2C2F3A) : const Color(0xFFCBD5E1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE5322D)
              : (widget.isDark ? const Color(0xFF141518) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE5322D)
                : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitPdfsContent() {
    final splitItems = widget.historyItems.where((item) {
      return item.toolType == 'Split PDF' || item.name.toLowerCase().startsWith('split');
    }).toList();

    if (splitItems.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: 'No split PDFs',
          subtitle: 'Documents you extract or split will appear here',
          isDark: widget.isDark,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: splitItems.length,
      itemBuilder: (ctx, idx) {
        final item = splitItems[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? const Color(0xFF2A2B33) : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.call_split_rounded, color: Color(0xFFFF7A00), size: 24),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.pages} pages • ${item.size} • ${item.date}',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) async {
                      if (val == 'open') {
                        OpenFilex.open(item.path);
                      } else if (val == 'share') {
                        Share.shareXFiles([XFile(item.path, mimeType: 'application/pdf')], text: item.name);
                      } else if (val == 'download') {
                        final ok = await StorageEngine.saveToDownloads(item.path, item.name);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? '✓ Saved to Downloads' : 'Save failed')),
                          );
                        }
                      } else if (val == 'print') {
                        try {
                          final bytes = await File(item.path).readAsBytes();
                          await Printing.layoutPdf(onLayout: (format) async => bytes, name: item.name);
                        } catch (_) {}
                      } else if (val == 'delete') {
                        widget.onDeleteHistoryItem?.call(item);
                        setState(() {});
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(children: [
                          Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Open'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(children: [
                          Icon(Icons.share_rounded, size: 18, color: Color(0xFFE5322D)),
                          SizedBox(width: 8),
                          Text('Share'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(children: [
                          Icon(Icons.download_rounded, size: 18, color: Color(0xFF16A34A)),
                          SizedBox(width: 8),
                          Text('Save to Downloads'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'print',
                        child: Row(children: [
                          Icon(Icons.print_rounded, size: 18, color: Color(0xFF0284C7)),
                          SizedBox(width: 8),
                          Text('Print'),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: BorderSide(
                        color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open', style: TextStyle(fontSize: 12)),
                    onPressed: () => OpenFilex.open(item.path),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5322D),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                    label: const Text('Share', style: TextStyle(fontSize: 12, color: Colors.white)),
                    onPressed: () => Share.shareXFiles([XFile(item.path, mimeType: 'application/pdf')], text: item.name),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
