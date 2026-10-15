import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/models.dart';
import '../services/storage_engine.dart';
import 'document_set_screen.dart';

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
  final Function(int)? onSwitchTab;
  final VoidCallback? onOpenWordToPdf;

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
    this.onSwitchTab,
    this.onOpenWordToPdf,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ImagePicker _picker = ImagePicker();
  List<DocumentSet> _documentSets = [];
  List<DocFolder> _folders = [];
  bool _isLoading = true;

  // Selected filter: 'all', 'recent', 'favourite', or folder name
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final sets = await StorageEngine.loadDocSets();
    final folders = await StorageEngine.loadDocFolders();
    if (mounted) {
      setState(() {
        _documentSets = sets;
        _folders = folders;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDocSets() async {
    await StorageEngine.saveDocSets(_documentSets);
  }

  List<DocumentSet> get _filteredDocuments {
    if (_selectedFilter == 'all') {
      return _documentSets;
    } else if (_selectedFilter == 'recent') {
      // Sort by updatedAt descending
      final sorted = List<DocumentSet>.from(_documentSets)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sorted;
    } else if (_selectedFilter == 'favourite') {
      return _documentSets.where((s) => s.isFavourite).toList();
    } else {
      // Match folder / category name
      return _documentSets
          .where((s) => s.category.toLowerCase() == _selectedFilter.toLowerCase())
          .toList();
    }
  }

  // --- ACTIONS: GROUP IMAGES INTO DOCUMENT SET ---

  Future<void> _importImagesAndGroupSet() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final now = DateTime.now();
        final defaultTitle = 'New Doc ${DateFormat('dd-MMM HH:mm').format(now)}';

        final List<DocPage> pages = [];
        for (int i = 0; i < images.length; i++) {
          final img = images[i];
          final file = File(img.path);
          final size = await file.exists() ? await file.length() : 0;
          pages.add(
            DocPage(
              id: 'page_${now.millisecondsSinceEpoch}_${i + 1}',
              imagePath: img.path,
              name: '${i + 1}',
              sizeBytes: size,
              date: now,
              isNew: true,
            ),
          );
        }

        final newSet = DocumentSet(
          id: 'set_${now.millisecondsSinceEpoch}',
          title: defaultTitle,
          createdAt: now,
          updatedAt: now,
          pages: pages,
          category: _selectedFilter != 'all' && _selectedFilter != 'recent' && _selectedFilter != 'favourite'
              ? _selectedFilter
              : 'All docs',
          isFavourite: false,
        );

        setState(() {
          _documentSets.insert(0, newSet);
        });
        await _saveDocSets();

        if (mounted) {
          // Open Document Set view directly (Screenshot 2)
          _openDocumentSet(newSet);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing images: $e')),
        );
      }
    }
  }

  Future<void> _captureCameraAndStartSet() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (image != null) {
        final now = DateTime.now();
        final file = File(image.path);
        final size = await file.exists() ? await file.length() : 0;
        final defaultTitle = 'Scanned Doc ${DateFormat('dd-MMM HH:mm').format(now)}';

        final newSet = DocumentSet(
          id: 'set_${now.millisecondsSinceEpoch}',
          title: defaultTitle,
          createdAt: now,
          updatedAt: now,
          pages: [
            DocPage(
              id: 'page_${now.millisecondsSinceEpoch}_1',
              imagePath: image.path,
              name: '1',
              sizeBytes: size,
              date: now,
              isNew: true,
            ),
          ],
          category: _selectedFilter != 'all' && _selectedFilter != 'recent' && _selectedFilter != 'favourite'
              ? _selectedFilter
              : 'All docs',
          isFavourite: false,
        );

        setState(() {
          _documentSets.insert(0, newSet);
        });
        await _saveDocSets();

        if (mounted) {
          _openDocumentSet(newSet);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  void _openDocumentSet(DocumentSet set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => DocumentSetScreen(
          documentSet: set,
          isDark: widget.isDark,
          onUpdateSet: (updatedSet) {
            setState(() {
              final index = _documentSets.indexWhere((s) => s.id == updatedSet.id);
              if (index != -1) {
                _documentSets[index] = updatedSet;
              }
            });
            _saveDocSets();
          },
          onDeleteSet: (deletedSet) {
            _deleteDocumentSet(deletedSet);
          },
          onAddHistoryItem: widget.onAddHistoryItem,
        ),
      ),
    );
  }

  // --- CREATE FOLDER MODAL ---

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    String selectedColor = '#0288D1';
    final colors = ['#0288D1', '#10B981', '#8B5CF6', '#F59E0B', '#EF4444', '#06B6D4'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.create_new_folder_rounded, color: Color(0xFF0288D1)),
              SizedBox(width: 10),
              Text('Create Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter a name for your new document folder:',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. Work, Invoices, Certificates',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.folder_outlined),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Folder Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colors.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final isChosen = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isChosen ? Border.all(color: Colors.white, width: 2.5) : null,
                        boxShadow: isChosen
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: isChosen ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final folderName = controller.text.trim();
                if (folderName.isNotEmpty) {
                  final newFolder = await StorageEngine.createFolder(folderName, colorHex: selectedColor);
                  setState(() {
                    _folders.add(newFolder);
                    _selectedFilter = folderName;
                  });
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Folder "$folderName" created!'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // --- MOVE TO FOLDER MODAL ---

  void _showMoveToFolderDialog(DocumentSet set) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Move to Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open_rounded, color: Colors.grey),
                title: const Text('All docs (Uncategorized)'),
                trailing: set.category == 'All docs' ? const Icon(Icons.check, color: Color(0xFF0288D1)) : null,
                onTap: () {
                  setState(() => set.category = 'All docs');
                  _saveDocSets();
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ..._folders.map((folder) {
                final color = Color(int.parse(folder.colorHex.replaceFirst('#', '0xFF')));
                return ListTile(
                  leading: Icon(Icons.folder_rounded, color: color),
                  title: Text(folder.name),
                  trailing: set.category == folder.name ? const Icon(Icons.check, color: Color(0xFF0288D1)) : null,
                  onTap: () {
                    setState(() {
                      set.category = folder.name;
                      set.folderId = folder.id;
                    });
                    _saveDocSets();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Moved "${set.title}" to ${folder.name}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // --- MOVE TO TRASH FLOW ---

  void _deleteDocumentSet(DocumentSet set) {
    final historyItem = HistoryItem(
      id: set.id,
      name: '${set.title}.pdf',
      path: set.generatedPdfPath ?? (set.pages.isNotEmpty ? set.pages.first.imagePath : ''),
      pages: set.pageCount,
      size: '${set.pageCount * 130} KB',
      date: set.formattedDate,
      toolType: 'Doc Set',
    );

    widget.onDeleteHistoryItem(historyItem);

    setState(() {
      _documentSets.removeWhere((s) => s.id == set.id);
    });
    _saveDocSets();
  }

  // --- PLUS FAB BOTTOM SHEET ---

  void _showPlusActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Create or Import',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // 1. Create New Folder
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0288D1).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.create_new_folder_rounded, color: Color(0xFF0288D1), size: 22),
                ),
                title: const Text('Create New Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Organize your documents and sets', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateFolderDialog();
                },
              ),

              // 2. Import Images (Group into One Set)
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text('Import Images into New Set', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Select multiple images to group into a set', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _importImagesAndGroupSet();
                },
              ),

              // 3. Scan Document with Camera
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFA9282).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFA9282), size: 22),
                ),
                title: const Text('Scan with Camera', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Capture pages using on-device camera', style: TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _captureCameraAndStartSet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- THUMBNAIL ILLUSTRATION (Simulates Document Cover from Screenshot 1) ---

  Widget _buildDocumentThumbnail(DocumentSet set) {
    if (set.pages.isNotEmpty && set.pages.first.imagePath.isNotEmpty && File(set.pages.first.imagePath).existsSync()) {
      return Image.file(
        File(set.pages.first.imagePath),
        fit: BoxFit.cover,
      );
    }

    // High quality vector document mockup matching Screenshot 1
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final bg = widget.isDark ? const Color(0xFF14191F) : const Color(0xFFF8FAFC);

    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top mini header
          Container(
            height: 4,
            width: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF0288D1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: double.infinity,
            color: borderColor,
          ),
          const SizedBox(height: 3),
          Container(
            height: 2,
            width: 32,
            color: borderColor.withOpacity(0.6),
          ),
          const Spacer(),
          // Center diagram box
          Center(
            child: Container(
              width: 36,
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0288D1).withOpacity(0.5), width: 0.8),
                borderRadius: BorderRadius.circular(3),
                color: const Color(0xFF0288D1).withOpacity(0.06),
              ),
              child: const Icon(Icons.art_track_rounded, size: 14, color: Color(0xFF0288D1)),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 2, width: 14, color: borderColor),
              Container(height: 2, width: 14, color: borderColor),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF12181F) : const Color(0xFFF8FAFC);
    final cardBg = widget.isDark ? const Color(0xFF1B242D) : Colors.white;
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = widget.isDark ? const Color(0xFF24303C) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Column(
            children: [
              // Documents (N) Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedFilter == 'all'
                              ? 'Documents (${_filteredDocuments.length})'
                              : '$_selectedFilter (${_filteredDocuments.length})',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        if (_selectedFilter != 'all') ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _selectedFilter = 'all'),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, size: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        // Folder Filter Dropdown
                        PopupMenuButton<String>(
                          icon: Icon(
                            _selectedFilter == 'all' ? Icons.filter_list_rounded : Icons.filter_alt_rounded,
                            size: 22,
                            color: _selectedFilter != 'all' ? const Color(0xFF0288D1) : textSecondary,
                          ),
                          tooltip: 'Filter by Folder',
                          color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          onSelected: (val) => setState(() => _selectedFilter = val),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'all', child: Text('All Documents')),
                            const PopupMenuItem(value: 'recent', child: Text('Recent')),
                            const PopupMenuItem(value: 'favourite', child: Text('Favourites')),
                            if (_folders.isNotEmpty) const PopupMenuDivider(),
                            ..._folders.map(
                              (f) => PopupMenuItem(
                                value: f.name,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.folder_rounded,
                                      size: 18,
                                      color: Color(int.parse(f.colorHex.replaceFirst('#', '0xFF'))),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(f.name),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.create_new_folder_outlined, size: 22),
                          tooltip: 'Create Folder',
                          onPressed: _showCreateFolderDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.sort_rounded, size: 22),
                          tooltip: 'Sort Documents',
                          onPressed: () {
                            setState(() {
                              _documentSets = _documentSets.reversed.toList();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 4. Documents List (Document Sets)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredDocuments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 64, color: textSecondary.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No documents in $_selectedFilter',
                                  style: TextStyle(fontSize: 16, color: textSecondary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Tap the + button below to import images or scan',
                                  style: TextStyle(fontSize: 13, color: textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.photo_library_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Import Images into Set',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 2,
                                    shadowColor: const Color(0xFF0284C7).withOpacity(0.35),
                                  ),
                                  onPressed: _importImagesAndGroupSet,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: _filteredDocuments.length,
                            itemBuilder: (ctx, index) {
                              final docSet = _filteredDocuments[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: dividerColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _openDocumentSet(docSet),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Left: Document Preview Container (Screenshot 1)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 66,
                                            height: 86,
                                            decoration: BoxDecoration(
                                              color: widget.isDark ? const Color(0xFF14191F) : const Color(0xFFF1F5F9),
                                              border: Border.all(color: dividerColor, width: 1.2),
                                            ),
                                            child: _buildDocumentThumbnail(docSet),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Center Column: Title, Subtitle, Badges
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                docSet.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: textPrimary,
                                                  height: 1.25,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                docSet.formattedDate,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 8),

                                              // Badges Row: [50] [N] [📄]
                                              Row(
                                                children: [
                                                  // Page count pill
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color: widget.isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                                        width: 1,
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${docSet.pageCount}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),

                                                  // Red [N] Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'N',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFFEF4444),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),

                                                  // Blue PDF Icon
                                                  const Icon(
                                                    Icons.picture_as_pdf_rounded,
                                                    size: 18,
                                                    color: Color(0xFF0288D1),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Right: 3-dots Menu (...)
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_horiz_rounded, color: textSecondary, size: 24),
                                          color: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          onSelected: (val) {
                                            if (val == 'open') {
                                              _openDocumentSet(docSet);
                                            } else if (val == 'folder') {
                                              _showMoveToFolderDialog(docSet);
                                            } else if (val == 'favourite') {
                                              setState(() => docSet.isFavourite = !docSet.isFavourite);
                                              _saveDocSets();
                                            } else if (val == 'delete') {
                                              _deleteDocumentSet(docSet);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'open',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.folder_open_rounded, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Open Document Set'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'folder',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.drive_file_move_outlined, size: 18),
                                                  SizedBox(width: 8),
                                                  Text('Move to Folder'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'favourite',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    docSet.isFavourite ? Icons.star_rounded : Icons.star_outline_rounded,
                                                    size: 18,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(docSet.isFavourite ? 'Remove Favourite' : 'Add to Favourite'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuDivider(),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Move to Trash', style: TextStyle(color: Colors.red)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // 5. Dual Floating Action Button (Screenshot 1: [ 📷 | + ])
          Positioned(
            bottom: 24,
            right: 20,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0288D1), // DocScanner rich blue
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera button (Quick capture to new set)
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      bottomLeft: Radius.circular(30),
                    ),
                    onTap: _captureCameraAndStartSet,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),

                  // Divider
                  Container(
                    height: 28,
                    width: 1,
                    color: Colors.white.withOpacity(0.35),
                  ),

                  // Plus button (Create folder / import images / make group)
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    onTap: _showPlusActionsSheet,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
