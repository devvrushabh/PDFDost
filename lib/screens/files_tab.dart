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
  final bool isDark;
  final Function(HistoryItem) onDeleteItem;

  const FilesTab({
    super.key,
    required this.historyItems,
    required this.isDark,
    required this.onDeleteItem,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<HistoryItem> get _filteredItems {
    if (_searchQuery.trim().isEmpty) return widget.historyItems;
    final q = _searchQuery.toLowerCase().trim();
    return widget.historyItems.where((item) => item.name.toLowerCase().contains(q)).toList();
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
                      SnackBar(content: Text(ok ? '✓ Saved to Downloads' : 'Save failed')),
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
                title: const Text('Delete Document', style: TextStyle(color: Colors.red)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2026) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search files by name...',
                      hintStyle: TextStyle(color: widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
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

        // Files count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredItems.length} File${_filteredItems.length == 1 ? '' : 's'} Available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _filteredItems.isEmpty
              ? Center(
                  child: SpaceEmptyIllustration(
                    title: _searchQuery.isEmpty ? 'No files saved yet' : 'No matching files',
                    subtitle: _searchQuery.isEmpty ? 'Convert documents to access them here' : 'Try searching with another name',
                    isDark: widget.isDark,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _filteredItems.length,
                  itemBuilder: (ctx, idx) {
                    final item = _filteredItems[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: widget.isDark ? const Color(0xFF1E2026) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: widget.isDark ? const Color(0xFF2A2B33) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        onTap: () => OpenFilex.open(item.path),
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
                        trailing: IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => _showFileActions(item),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
