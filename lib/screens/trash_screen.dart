import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/models.dart';
import '../widgets/space_empty_illustration.dart';

class TrashScreen extends StatefulWidget {
  final List<TrashItem> trashItems;
  final bool isDark;
  final Function(TrashItem) onRestore;
  final Function(TrashItem) onDeletePermanently;
  final VoidCallback onEmptyTrash;

  const TrashScreen({
    super.key,
    required this.trashItems,
    required this.isDark,
    required this.onRestore,
    required this.onDeletePermanently,
    required this.onEmptyTrash,
  });

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<TrashItem> get _filteredTrash {
    if (_searchQuery.trim().isEmpty) return widget.trashItems;
    final q = _searchQuery.toLowerCase().trim();
    return widget.trashItems
        .where((t) => t.item.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final bgColor = widget.isDark ? const Color(0xFF0F1015) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.isDark ? const Color(0xFF16171B) : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: primaryTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trash (Recycle Bin)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: primaryTextColor,
              ),
            ),
            Text(
              'Retained for 30 days before permanent deletion',
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.trashItems.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmEmptyTrash,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
              label: const Text('Empty', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 30-Day Retention Notice Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_delete_rounded,
                      color: Color(0xFFEF4444),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '30-Day Auto Retention',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Items in Trash are retained for 30 days, then permanently deleted.',
                          style: TextStyle(fontSize: 11, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar (if > 2 items)
            if (widget.trashItems.length > 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: secondaryTextColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(color: primaryTextColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search trash...',
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

            // Header Count
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredTrash.length} Deleted Document(s)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            // Content List / Empty View
            Expanded(
              child: _filteredTrash.isEmpty
                  ? Center(
                      child: SpaceEmptyIllustration(
                        title: widget.trashItems.isEmpty ? 'Trash is empty' : 'No matching items',
                        subtitle: widget.trashItems.isEmpty
                            ? 'Deleted files stay here for 30 days before permanent removal'
                            : 'Try searching with another file name',
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
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                                size: 24,
                              ),
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
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: daysLeft <= 3
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
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
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${item.pages} page(s) • ${item.size} • ${item.date}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Restore Button
                                IconButton(
                                  tooltip: 'Restore File',
                                  icon: const Icon(
                                    Icons.restore_from_trash_rounded,
                                    color: Color(0xFF10B981),
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    widget.onRestore(trashItem);
                                    setState(() {});
                                  },
                                ),
                                // Delete Permanently Button
                                IconButton(
                                  tooltip: 'Delete Permanently',
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 22,
                                  ),
                                  onPressed: () => _confirmDeletePermanently(trashItem),
                                ),
                              ],
                            ),
                            onTap: () {
                              OpenFilex.open(item.path);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
