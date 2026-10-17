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

class MergePdfScreen extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final bool isDark;
  final Function(HistoryItem) onAddHistoryItem;
  final Function(HistoryItem)? onDeleteHistoryItem;

  const MergePdfScreen({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onAddHistoryItem,
    this.onDeleteHistoryItem,
  });

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Selected PDFs, 1: Merged PDFs
  bool _isSpeedDialOpen = false;
  bool _isMerging = false;

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
            _activeChip = 0; // Focus on selected PDFs
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${newItems.length} PDF(s) to merge list'),
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

    // Filter available PDFs from history
    final availableHistory = widget.historyItems.where((item) {
      final file = File(item.path);
      return file.existsSync();
    }).toList();

    if (availableHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved PDFs found in app history yet. Convert images to PDF first or browse device files!'),
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
                    'Pick existing documents to combine into your merged PDF:',
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
                              color: const Color(0xFFE5322D).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE5322D), size: 20),
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

  void _changeSelectedPdfPosition(int currentIndex) {
    final controller = TextEditingController(text: '${currentIndex + 1}');
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move PDF to new position (1 to ${_selectedPdfs.length}):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: 'Position number',
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
              final target = int.tryParse(controller.text.trim());
              Navigator.pop(ctx);
              if (target != null && target >= 1 && target <= _selectedPdfs.length) {
                _moveSelectedPdf(currentIndex, target - 1);
              }
            },
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearSelectedPdfs() {
    setState(() {
      _selectedPdfs.clear();
    });
  }

  Future<void> _showRenameAndMergeDialog() async {
    if (_selectedPdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 PDF documents to merge'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final defaultName = 'Merged_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    final docName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name Your Merged PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom document name for the merged PDF (${_selectedPdfs.length} files combined):',
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
            child: const Text('Merge Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (docName != null && docName.isNotEmpty) {
      setState(() => _isMerging = true);
      try {
        final result = await PdfEngine.mergePdfItems(
          items: _selectedPdfs,
          docName: docName,
        );

        final newHistory = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.name,
          path: result.path,
          pages: result.pages,
          size: result.sizeStr,
          date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          toolType: 'Merge PDF',
        );

        widget.onAddHistoryItem(newHistory);

        if (mounted) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Merge failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isMerging = false);
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
                color: const Color(0xFFE5322D).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.call_merge_rounded, color: Color(0xFFE5322D), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Merge PDF',
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
                  title: const Text('How to Merge PDFs'),
                  content: const Text(
                    '1. Tap the coral (+) button to add 2 or more PDF files.\n\n'
                    '2. Arrange the files in the order you want them merged using the up/down arrows or position badges.\n\n'
                    '3. Tap MERGE PDF to combine all pages into one document!',
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
                                        color: const Color(0xFFE5322D).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Color(0xFFE5322D),
                                        size: 18,
                                      ),
                                    ),
                                    if (_selectedPdfs.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE5322D),
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

                      // Chip 2: Merged PDFs
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
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.call_merge_rounded,
                                    color: Color(0xFF38BDF8),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Merged PDFs',
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
                  child: _activeChip == 0 ? _buildSelectedPdfsContent() : _buildMergedPdfsContent(),
                ),
              ],
            ),

            // 3. Dark backdrop when speed dial is open
            if (_isSpeedDialOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSpeedDial,
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),

            // 4. Expandable Speed Dial (Matching Screenshot coral style)
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
                    // Browse Files Pill
                    _buildSpeedDialOption(
                      icon: Icons.folder_open_rounded,
                      label: 'Browse Device',
                      onTap: _pickPdfFromDevice,
                    ),
                    const SizedBox(height: 12),
                    // App History Pill
                    _buildSpeedDialOption(
                      icon: Icons.history_rounded,
                      label: 'From App PDFs',
                      onTap: _showPickFromAppHistoryModal,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Main Circular Coral FAB
                  GestureDetector(
                    onTap: _toggleSpeedDial,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA9282), // Soft coral
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA9282).withValues(alpha: 0.4),
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

            // 5. Merging Loading Overlay
            if (_isMerging)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
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
                          'Merging PDF Documents...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Combining pages into a unified document...',
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
              color: Colors.black.withValues(alpha: 0.18),
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
              subtitle: 'Add 2 or more PDF documents to merge',
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
        // Header row with count & clear
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedPdfs.length} PDF(s) in Merge Order',
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

        // List of PDFs in order
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _selectedPdfs.length,
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _selectedPdfs.removeAt(oldIndex);
                _selectedPdfs.insert(newIndex, item);
              });
            },
            itemBuilder: (ctx, idx) {
              final pdf = _selectedPdfs[idx];
              return Container(
                key: ValueKey('${pdf.path}_$idx'),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2A2B33) : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Position Number Badge (Tappable for Quick Jump dialog)
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _changeSelectedPdfPosition(idx),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5322D).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            color: Color(0xFFE5322D),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // PDF Document Icon Badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5322D).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Color(0xFFE5322D),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // PDF Details
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
                          const SizedBox(height: 4),
                          Text(
                            '${pdf.pageCount} page${pdf.pageCount > 1 ? 's' : ''} • ${pdf.formattedSize}',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Drag Handle
                    ReorderableDragStartListener(
                      index: idx,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: const Icon(Icons.drag_indicator_rounded, size: 22, color: Colors.grey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFEF4444)),
                      onPressed: () => _removeSelectedPdf(idx),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Sticky Merge Action Bar
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
              onPressed: _showRenameAndMergeDialog,
              icon: const Icon(Icons.call_merge_rounded, color: Colors.white),
              label: Text(
                _selectedPdfs.length >= 2
                    ? 'MERGE ${_selectedPdfs.length} PDFS'
                    : 'MERGE TO PDF',
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

  Widget _buildMergedPdfsContent() {
    final mergedItems = widget.historyItems.where((item) {
      return item.toolType == 'Merge PDF' || item.name.toLowerCase().startsWith('merged');
    }).toList();

    if (mergedItems.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: 'No merged PDFs',
          subtitle: 'Documents you merge will appear here',
          isDark: widget.isDark,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: mergedItems.length,
      itemBuilder: (ctx, idx) {
        final item = mergedItems[idx];
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
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.call_merge_rounded, color: Color(0xFF38BDF8), size: 24),
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
