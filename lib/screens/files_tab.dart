import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/models.dart';
import '../services/storage_engine.dart';
import '../widgets/space_empty_illustration.dart';

class FilesTab extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final List<TrashItem> trashItems;
  final bool isDark;
  final Function(HistoryItem) onDeleteItem;
  final Function(TrashItem) onRestoreTrashItem;
  final Function(TrashItem) onDeletePermanently;
  final VoidCallback onEmptyTrash;

  const FilesTab({
    super.key,
    required this.historyItems,
    required this.trashItems,
    required this.isDark,
    required this.onDeleteItem,
    required this.onRestoreTrashItem,
    required this.onDeletePermanently,
    required this.onEmptyTrash,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  int _activeTab = 0; // 0: All Files, 1: Trash
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<HistoryItem> get _filteredFiles {
    if (_searchQuery.trim().isEmpty) return widget.historyItems;
    final q = _searchQuery.toLowerCase().trim();
    return widget.historyItems.where((item) => item.name.toLowerCase().contains(q)).toList();
  }

  List<TrashItem> get _filteredTrash {
    if (_searchQuery.trim().isEmpty) return widget.trashItems;
    final q = _searchQuery.toLowerCase().trim();
    return widget.trashItems.where((t) => t.item.name.toLowerCase().contains(q)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFileActions(HistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded, color: Color(0xFF2563EB)),
                title: const Text('Open / View Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  OpenFilex.open(item.path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_rounded, color: Color(0xFFE5322D)),
                title: const Text('Share Document'),
                onTap: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(item.path, mimeType: 'application/pdf')], text: item.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF16A34A)),
                title: const Text('Save to Downloads'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await StorageEngine.saveToDownloads(item.path, item.name);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? '✓ Saved to Downloads' : 'Save failed'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_rounded, color: Color(0xFF0284C7)),
                title: const Text('Print Document'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final bytes = await File(item.path).readAsBytes();
                    await Printing.layoutPdf(onLayout: (format) async => bytes, name: item.name);
                  } catch (_) {}
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Move to Trash', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('Retained for 30 days', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteItem(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmEmptyTrash() {
    if (widget.trashItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Empty Trash?'),
          ],
        ),
        content: Text(
          'This will permanently delete all ${widget.trashItems.length} item(s) from your device. This action cannot be undone.',
          style: TextStyle(
            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEmptyTrash();
              setState(() {});
            },
            child: const Text('Empty Trash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePermanently(TrashItem trashItem) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Permanently?'),
        content: Text(
          'Are you sure you want to permanently delete "${trashItem.item.name}"? It cannot be recovered.',
          style: TextStyle(
            color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeletePermanently(trashItem);
              setState(() {});
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Column(
      children: [
        // Top Segmented Chips: All Files vs Trash
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // Chip 0: All Files
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeTab = 0;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _activeTab == 0
                          ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                          : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeTab == 0
                            ? (widget.isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8))
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: _activeTab == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          color: _activeTab == 0 ? const Color(0xFF2563EB) : secondaryTextColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Files',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 0 ? primaryTextColor : secondaryTextColor,
                          ),
                        ),
                        if (widget.historyItems.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.historyItems.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Chip 1: Trash
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeTab = 1;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _activeTab == 1
                          ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
                          : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _activeTab == 1
                            ? (widget.isDark ? const Color(0xFFEF4444) : const Color(0xFFEF4444))
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: _activeTab == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: _activeTab == 1 ? const Color(0xFFEF4444) : secondaryTextColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Trash',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 1 ? primaryTextColor : secondaryTextColor,
                          ),
                        ),
                        if (widget.trashItems.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${widget.trashItems.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: secondaryTextColor),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: primaryTextColor),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: _activeTab == 0 ? 'Search files by name...' : 'Search trash...',
                      hintStyle: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
        ),

        // Body Content
        Expanded(
          child: _activeTab == 0 ? _buildAllFilesContent() : _buildTrashContent(),
        ),
      ],
    );
  }

  Widget _buildAllFilesContent() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_filteredFiles.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: _searchQuery.isEmpty ? 'No files saved yet' : 'No matching files',
          subtitle: _searchQuery.isEmpty ? 'Convert documents to access them here' : 'Try searching with another name',
          isDark: widget.isDark,
        ),
      );
    }

    return Column(
      children: [
        // Files count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredFiles.length} File${_filteredFiles.length == 1 ? '' : 's'} Available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _filteredFiles.length,
            itemBuilder: (ctx, index) {
              final item = _filteredFiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
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
                      color: const Color(0xFFE5322D).withOpacity(0.12),
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
                      color: primaryTextColor,
                    ),
                  ),
                  subtitle: Text(
                    '${item.pages} page(s) • ${item.size} • ${item.date}',
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert_rounded, color: secondaryTextColor),
                    onPressed: () => _showFileActions(item),
                  ),
                  onTap: () => OpenFilex.open(item.path),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrashContent() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      children: [
        // 30-Day Retention Notice Banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_delete_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trash retains files for 30 days before permanent deletion.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (widget.trashItems.isNotEmpty)
                TextButton(
                  onPressed: _confirmEmptyTrash,
                  child: const Text(
                    'Empty',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // Count Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredTrash.length} Item(s) in Trash',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _filteredTrash.isEmpty
              ? Center(
                  child: SpaceEmptyIllustration(
                    title: widget.trashItems.isEmpty ? 'Trash is empty' : 'No matching items',
                    subtitle: widget.trashItems.isEmpty
                        ? 'Deleted files stay here for 30 days before permanent removal'
                        : 'Try searching with another name',
                    isDark: widget.isDark,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _filteredTrash.length,
                  itemBuilder: (ctx, index) {
                    final trashItem = _filteredTrash[index];
                    final item = trashItem.item;
                    final daysLeft = trashItem.daysRemaining;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
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
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: daysLeft <= 3
                                    ? const Color(0xFFEF4444).withOpacity(0.15)
                                    : const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$daysLeft days left',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: daysLeft <= 3
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${item.pages} page(s) • ${item.size} • Deleted ${item.date}',
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Restore Button
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(Icons.restore_from_trash_rounded, color: Color(0xFF10B981), size: 22),
                              onPressed: () {
                                widget.onRestoreTrashItem(trashItem);
                                setState(() {});
                              },
                            ),
                            // Delete Permanently Button
                            IconButton(
                              tooltip: 'Delete Forever',
                              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
                              onPressed: () => _confirmDeletePermanently(trashItem),
                            ),
                          ],
                        ),
                        onTap: () => OpenFilex.open(item.path),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
