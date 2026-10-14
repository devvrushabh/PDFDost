import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../services/storage_engine.dart';
import '../widgets/export_modal.dart';
import '../widgets/space_empty_illustration.dart';

class HomeTab extends StatefulWidget {
  final List<SelectedImageItem> selectedImages;
  final List<HistoryItem> historyItems;
  final bool isDark;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final Function(int) onRemoveImage;
  final Function(int, int) onMoveImage;
  final Function(int) onChangePosition;
  final VoidCallback onClearImages;
  final Function(HistoryItem) onDeleteHistoryItem;
  final Function(HistoryItem) onAddHistoryItem;
  final VoidCallback? onOpenMergePdf;
  final VoidCallback? onOpenSplitPdf;

  const HomeTab({
    super.key,
    required this.selectedImages,
    required this.historyItems,
    required this.isDark,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemoveImage,
    required this.onMoveImage,
    required this.onChangePosition,
    required this.onClearImages,
    required this.onDeleteHistoryItem,
    required this.onAddHistoryItem,
    this.onOpenMergePdf,
    this.onOpenSplitPdf,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  int _activeChip = 0; // 0: Scanned Images, 1: Converted PDFs
  bool _isSpeedDialOpen = false;
  bool _isConverting = false;

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

  Future<void> _showRenameAndConvertDialog() async {
    if (widget.selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image first')),
      );
      return;
    }

    final defaultName = 'Document_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    final docName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Name Your PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a custom document name for the converted PDF:',
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
            child: const Text('Convert Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (docName != null && docName.isNotEmpty) {
      setState(() => _isConverting = true);
      try {
        final result = await PdfEngine.convertImagesToPdf(
          images: widget.selectedImages,
          docName: docName,
        );

        final newHistory = HistoryItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result.name,
          path: result.path,
          pages: result.pages,
          size: result.sizeStr,
          date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          toolType: 'Image to PDF',
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
            SnackBar(content: Text('Conversion failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isConverting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeSpeedDial,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Column(
            children: [
              // 1. Top Toggle Chips matching Screenshot 1
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Chip 1: Scanned Images
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
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.image_rounded, color: Color(0xFF10B981), size: 18),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Scanned Images',
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

                    // Chip 2: Converted PDFs
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
                                child: const Icon(Icons.description_rounded, color: Color(0xFF38BDF8), size: 18),
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

              // 2. Body Content (Empty State or List)
              Expanded(
                child: _activeChip == 0 ? _buildScannedImagesContent() : _buildConvertedPdfsContent(),
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

          // 4. Expandable Speed Dial (Matching Screenshot 1)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            bottom: (widget.selectedImages.isNotEmpty && widget.activeChip == 0) ? 92 : 24,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera Option Pill
                if (_isSpeedDialOpen) ...[
                  if (widget.onOpenMergePdf != null) ...[
                    _buildSpeedDialOption(
                      icon: Icons.call_merge_rounded,
                      label: 'Merge PDF',
                      onTap: () {
                        _closeSpeedDial();
                        widget.onOpenMergePdf!();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.onOpenSplitPdf != null) ...[
                    _buildSpeedDialOption(
                      icon: Icons.call_split_rounded,
                      label: 'Split PDF',
                      onTap: () {
                        _closeSpeedDial();
                        widget.onOpenSplitPdf!();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  _buildSpeedDialOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () {
                      _closeSpeedDial();
                      widget.onPickCamera();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Gallery Option Pill
                  _buildSpeedDialOption(
                    icon: Icons.photo_outlined,
                    label: 'Gallery',
                    onTap: () {
                      _closeSpeedDial();
                      widget.onPickGallery();
                    },
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
                      color: const Color(0xFFFA9282), // Soft coral from screenshot
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

          // 5. Converting Loading Overlay
          if (_isConverting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFFE5322D)),
                      SizedBox(height: 16),
                      Text(
                        'Converting Images to PDF...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

  Widget _buildScannedImagesContent() {
    if (widget.selectedImages.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: 'No files found',
          subtitle: 'Tap the button to begin',
          isDark: widget.isDark,
        ),
      );
    }

    // List of selected images with reorder & convert button
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.selectedImages.length} Image(s) Ready',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: widget.onClearImages,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                    label: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: widget.selectedImages.length,
            onReorder: (int oldIndex, int newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              widget.onMoveImage(oldIndex, newIndex);
            },
            itemBuilder: (ctx, idx) {
              final img = widget.selectedImages[idx];
              return Container(
                key: ValueKey('${img.path}_$idx'),
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
                    // Page Number Badge
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => widget.onChangePosition(idx),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5322D).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(color: Color(0xFFE5322D), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Image thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(img.path),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Image details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            img.name,
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
                            img.formattedSize,
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
                      onPressed: () => widget.onRemoveImage(idx),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Convert to PDF Floating Bottom Bar
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
              onPressed: _showRenameAndConvertDialog,
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              label: const Text(
                'CONVERT TO PDF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConvertedPdfsContent() {
    if (widget.historyItems.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: 'No converted PDFs',
          subtitle: 'Files you convert will appear here',
          isDark: widget.isDark,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: widget.historyItems.length,
      itemBuilder: (ctx, idx) {
        final item = widget.historyItems[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark ? const Color(0xFF2A2B33) : const Color(0xFFE2E8F0),
            ),
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
              '${item.pages} Pages  •  ${item.size}  •  ${item.date}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              onSelected: (action) async {
                if (action == 'open') {
                  await OpenFilex.open(item.path);
                } else if (action == 'save') {
                  final ok = await StorageEngine.saveToDownloads(item.path, item.name);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? '✓ Saved to Downloads' : 'Save failed')),
                    );
                  }
                } else if (action == 'delete') {
                  widget.onDeleteHistoryItem(item);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'open', child: Text('Open PDF')),
                const PopupMenuItem(value: 'save', child: Text('Save to Downloads')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () => OpenFilex.open(item.path),
          ),
        );
      },
    );
  }
}
