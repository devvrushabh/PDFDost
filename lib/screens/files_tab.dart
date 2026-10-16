import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/storage_engine.dart';
import '../widgets/space_empty_illustration.dart';
import 'document_set_screen.dart';
import 'scanner_camera_screen.dart';

class FilesTab extends StatefulWidget {
  final List<HistoryItem> historyItems;
  final List<TrashItem> trashItems;
  final bool isDark;
  final Function(HistoryItem) onDeleteItem;
  final Function(TrashItem) onRestoreTrashItem;
  final Function(TrashItem) onDeletePermanently;
  final VoidCallback onEmptyTrash;
  final VoidCallback onClearAllFiles;
  final Function(List<HistoryItem>)? onBatchDeleteItems;
  final Function(HistoryItem)? onAddHistoryItem;
  final VoidCallback? onOpenImageToPdf;

  const FilesTab({
    super.key,
    required this.historyItems,
    required this.trashItems,
    required this.isDark,
    required this.onDeleteItem,
    required this.onRestoreTrashItem,
    required this.onDeletePermanently,
    required this.onEmptyTrash,
    required this.onClearAllFiles,
    this.onBatchDeleteItems,
    this.onAddHistoryItem,
    this.onOpenImageToPdf,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  // 0: Documents (Doc Sets, Group Images, Folders), 1: PDF Files, 2: Trash
  int _activeTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Document Sets & Folders state
  List<DocumentSet> _documentSets = [];
  List<DocFolder> _folders = [];
  bool _isLoadingDocSets = true;
  String _selectedFilter = 'all'; // 'all', 'recent', 'favourite', or folder name

  // Multi-selection states
  // 1. For Document Sets
  bool _isDocSelectionMode = false;
  final Set<String> _selectedDocSetIds = {};

  // 2. For PDF Files
  bool _isFileSelectionMode = false;
  final Set<String> _selectedFileIds = {};

  // 3. For Trash
  bool _isTrashSelectionMode = false;
  final Set<String> _selectedTrashIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocSetsAndFolders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- DATA LOADING & PERSISTENCE ---

  Future<void> _loadDocSetsAndFolders() async {
    final sets = await StorageEngine.loadDocSets();
    final folders = await StorageEngine.loadDocFolders();
    if (mounted) {
      setState(() {
        _documentSets = sets;
        _folders = folders;
        _isLoadingDocSets = false;
      });
    }
  }

  Future<void> _saveDocSets() async {
    await StorageEngine.saveDocSets(_documentSets);
  }

  // --- FILTERED DATA GETTERS ---

  List<DocumentSet> get _filteredDocuments {
    List<DocumentSet> result;
    if (_selectedFilter == 'all') {
      result = List.from(_documentSets);
    } else if (_selectedFilter == 'recent') {
      result = List.from(_documentSets)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else if (_selectedFilter == 'favourite') {
      result = _documentSets.where((s) => s.isFavourite).toList();
    } else {
      result = _documentSets
          .where((s) => s.category.toLowerCase() == _selectedFilter.toLowerCase())
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((s) => s.title.toLowerCase().contains(q)).toList();
    }

    return result;
  }

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

  // --- ACTIONS: GROUP IMAGES & SCAN DOCUMENT SETS ---

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
          _activeTab = 0; // Ensure on Documents tab
        });
        await _saveDocSets();

        if (mounted) {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ScannerCameraScreen(
          isDark: widget.isDark,
          onSaveDocumentSet: (newSet) {
            setState(() {
              _documentSets.insert(0, newSet);
              _activeTab = 0;
            });
            _saveDocSets();
          },
          onAddHistoryItem: (item) {
            widget.onAddHistoryItem?.call(item);
          },
        ),
      ),
    );
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
          onAddHistoryItem: widget.onAddHistoryItem ?? (_) {},
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

  // --- MOVE DOCUMENT SET TO FOLDER ---

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

  // --- DELETE DOCUMENT SET (MOVE TO TRASH) ---

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

    widget.onDeleteItem(historyItem);

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

              // 4. Convert Images directly to PDF
              if (widget.onOpenImageToPdf != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  title: const Text('Convert Images to PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: const Text('Convert pictures directly into a PDF document', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onOpenImageToPdf!();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- MULTI-SELECTION LOGIC FOR DOCUMENTS ---

  void _enterDocSelectionMode(DocumentSet docSet) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isDocSelectionMode = true;
      _selectedDocSetIds.clear();
      _selectedDocSetIds.add(docSet.id);
    });
  }

  void _exitDocSelectionMode() {
    setState(() {
      _isDocSelectionMode = false;
      _selectedDocSetIds.clear();
    });
  }

  void _toggleSelectDocSet(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDocSetIds.contains(id)) {
        _selectedDocSetIds.remove(id);
        if (_selectedDocSetIds.isEmpty) {
          _isDocSelectionMode = false;
        }
      } else {
        _selectedDocSetIds.add(id);
      }
    });
  }

  void _selectAllDocSets() {
    setState(() {
      if (_selectedDocSetIds.length == _filteredDocuments.length) {
        _selectedDocSetIds.clear();
        _isDocSelectionMode = false;
      } else {
        _selectedDocSetIds.clear();
        for (final doc in _filteredDocuments) {
          _selectedDocSetIds.add(doc.id);
        }
      }
    });
  }

  void _batchDeleteDocSets() {
    final selectedDocs = _documentSets.where((s) => _selectedDocSetIds.contains(s.id)).toList();
    if (selectedDocs.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Move ${selectedDocs.length} Set(s) to Trash?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Selected documents will be moved to Trash and retained for 30 days before permanent deletion.',
          style: TextStyle(color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(ctx);
              final historyItemsToDelete = selectedDocs.map((set) => HistoryItem(
                id: set.id,
                name: '${set.title}.pdf',
                path: set.generatedPdfPath ?? (set.pages.isNotEmpty ? set.pages.first.imagePath : ''),
                pages: set.pageCount,
                size: '${set.pageCount * 130} KB',
                date: set.formattedDate,
                toolType: 'Doc Set',
              )).toList();

              if (widget.onBatchDeleteItems != null) {
                widget.onBatchDeleteItems!(historyItemsToDelete);
              } else {
                for (final item in historyItemsToDelete) {
                  widget.onDeleteItem(item);
                }
              }

              setState(() {
                _documentSets.removeWhere((s) => _selectedDocSetIds.contains(s.id));
                _exitDocSelectionMode();
              });
              _saveDocSets();
            },
            child: const Text('Move to Trash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _batchMoveToFolder() {
    final selectedDocs = _documentSets.where((s) => _selectedDocSetIds.contains(s.id)).toList();
    if (selectedDocs.isEmpty || _folders.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E2024) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Move ${selectedDocs.length} Document(s) to Folder',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 16),
              ..._folders.map((folder) => ListTile(
                leading: Icon(
                  Icons.folder_rounded,
                  color: Color(int.parse(folder.colorHex.replaceFirst('#', '0xFF'))),
                ),
                title: Text(folder.name),
                onTap: () {
                  setState(() {
                    for (final doc in selectedDocs) {
                      doc.category = folder.name;
                    }
                    _exitDocSelectionMode();
                  });
                  _saveDocSets();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Moved ${selectedDocs.length} document(s) to ${folder.name}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _batchShareDocSets() async {
    final selectedDocs = _documentSets.where((s) => _selectedDocSetIds.contains(s.id)).toList();
    if (selectedDocs.isEmpty) return;

    final List<XFile> filesToShare = [];
    for (final doc in selectedDocs) {
      if (doc.generatedPdfPath != null && await File(doc.generatedPdfPath!).exists()) {
        filesToShare.add(XFile(doc.generatedPdfPath!, mimeType: 'application/pdf'));
      } else {
        for (final p in doc.pages) {
          if (p.imagePath.isNotEmpty && await File(p.imagePath).exists()) {
            filesToShare.add(XFile(p.imagePath));
          }
        }
      }
    }

    if (filesToShare.isNotEmpty) {
      await Share.shareXFiles(filesToShare, text: 'PDFDost Documents');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files available to share for selected items')),
        );
      }
    }
  }

  // --- MULTI-SELECTION LOGIC FOR PDF FILES ---

  void _enterFileSelectionMode(HistoryItem item) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFileSelectionMode = true;
      _selectedFileIds.clear();
      _selectedFileIds.add(item.id);
    });
  }

  void _exitFileSelectionMode() {
    setState(() {
      _isFileSelectionMode = false;
      _selectedFileIds.clear();
    });
  }

  void _toggleSelectFile(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
        if (_selectedFileIds.isEmpty) {
          _isFileSelectionMode = false;
        }
      } else {
        _selectedFileIds.add(id);
      }
    });
  }

  void _selectAllFiles() {
    setState(() {
      if (_selectedFileIds.length == _filteredFiles.length) {
        _selectedFileIds.clear();
        _isFileSelectionMode = false;
      } else {
        _selectedFileIds.clear();
        for (final item in _filteredFiles) {
          _selectedFileIds.add(item.id);
        }
      }
    });
  }

  void _batchDeleteFiles() {
    final selectedFiles = widget.historyItems.where((i) => _selectedFileIds.contains(i.id)).toList();
    if (selectedFiles.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Move ${selectedFiles.length} File(s) to Trash?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Selected files will be moved to Trash and retained for 30 days before permanent deletion.',
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
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onBatchDeleteItems != null) {
                widget.onBatchDeleteItems!(selectedFiles);
              } else {
                for (final item in selectedFiles) {
                  widget.onDeleteItem(item);
                }
              }
              _exitFileSelectionMode();
            },
            child: const Text('Move to Trash', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _batchShareFiles() {
    final selectedFiles = widget.historyItems.where((i) => _selectedFileIds.contains(i.id)).toList();
    if (selectedFiles.isEmpty) return;

    final xFiles = selectedFiles
        .where((f) => File(f.path).existsSync())
        .map((f) => XFile(f.path, mimeType: 'application/pdf'))
        .toList();

    if (xFiles.isNotEmpty) {
      Share.shareXFiles(xFiles, text: 'Sharing ${xFiles.length} document(s)');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected files could not be found on storage'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _batchSaveToDownloads() async {
    final selectedFiles = widget.historyItems.where((i) => _selectedFileIds.contains(i.id)).toList();
    if (selectedFiles.isEmpty) return;

    int successCount = 0;
    for (final file in selectedFiles) {
      final ok = await StorageEngine.saveToDownloads(file.path, file.name);
      if (ok) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Saved $successCount file(s) to Downloads'),
          duration: const Duration(seconds: 1),
        ),
      );
      _exitFileSelectionMode();
    }
  }

  // --- MULTI-SELECTION LOGIC FOR TRASH ---

  void _enterTrashSelectionMode(TrashItem item) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isTrashSelectionMode = true;
      _selectedTrashIds.clear();
      _selectedTrashIds.add(item.item.id);
    });
  }

  void _exitTrashSelectionMode() {
    setState(() {
      _isTrashSelectionMode = false;
      _selectedTrashIds.clear();
    });
  }

  void _toggleSelectTrashItem(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTrashIds.contains(id)) {
        _selectedTrashIds.remove(id);
        if (_selectedTrashIds.isEmpty) {
          _isTrashSelectionMode = false;
        }
      } else {
        _selectedTrashIds.add(id);
      }
    });
  }

  void _selectAllTrash() {
    setState(() {
      if (_selectedTrashIds.length == _filteredTrash.length) {
        _selectedTrashIds.clear();
        _isTrashSelectionMode = false;
      } else {
        _selectedTrashIds.clear();
        for (final item in _filteredTrash) {
          _selectedTrashIds.add(item.item.id);
        }
      }
    });
  }

  void _batchRestoreTrash() {
    final selectedItems = widget.trashItems.where((t) => _selectedTrashIds.contains(t.item.id)).toList();
    if (selectedItems.isEmpty) return;

    for (final item in selectedItems) {
      widget.onRestoreTrashItem(item);
    }
    final count = selectedItems.length;
    _exitTrashSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Restored $count item(s) from Trash'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  void _confirmBatchDeletePermanently() {
    final selectedItems = widget.trashItems.where((t) => _selectedTrashIds.contains(t.item.id)).toList();
    if (selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Permanently?'),
        content: Text(
          'Are you sure you want to permanently delete ${selectedItems.length} item(s)? This action cannot be undone.',
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
              for (final item in selectedItems) {
                widget.onDeletePermanently(item);
              }
              final count = selectedItems.length;
              _exitTrashSelectionMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Permanently deleted $count item(s)'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text('Delete Forever', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- FILE ACTIONS MODAL ---

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

  void _confirmClearAllFiles() {
    if (widget.historyItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Clear All Files?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove all ${widget.historyItems.length} file(s)?',
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
              widget.onClearAllFiles();
              setState(() {});
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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

  // --- DOCUMENT THUMBNAIL PREVIEW ---

  Widget _buildDocumentThumbnail(DocumentSet set) {
    if (set.pages.isNotEmpty && set.pages.first.imagePath.isNotEmpty && File(set.pages.first.imagePath).existsSync()) {
      return Image.file(
        File(set.pages.first.imagePath),
        fit: BoxFit.cover,
      );
    }

    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final bg = widget.isDark ? const Color(0xFF14191F) : const Color(0xFFF8FAFC);

    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            width: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF0288D1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2, width: double.infinity, color: borderColor),
          const SizedBox(height: 3),
          Container(height: 2, width: 32, color: borderColor.withOpacity(0.6)),
          const Spacer(),
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

  // --- MAIN BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isAnySelectionMode = _isDocSelectionMode || _isFileSelectionMode || _isTrashSelectionMode;

    return PopScope(
      canPop: !isAnySelectionMode && _activeTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isDocSelectionMode) {
          _exitDocSelectionMode();
        } else if (_isFileSelectionMode) {
          _exitFileSelectionMode();
        } else if (_isTrashSelectionMode) {
          _exitTrashSelectionMode();
        } else if (_activeTab != 0) {
          setState(() => _activeTab = 0);
        }
      },
      child: Scaffold(
        backgroundColor: widget.isDark ? const Color(0xFF12181F) : const Color(0xFFF8FAFC),
        floatingActionButton: !isAnySelectionMode ? _buildDualFab() : null,
        body: Column(
          children: [
            // Top 3 Segmented Chips: Documents | PDF Files | Trash
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  // Chip 0: Documents
                  Expanded(
                    child: _buildSegmentChip(
                      index: 0,
                      label: 'Documents',
                      icon: Icons.photo_library_outlined,
                      activeColor: const Color(0xFF0288D1),
                      count: _documentSets.length,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chip 1: PDF Files
                  Expanded(
                    child: _buildSegmentChip(
                      index: 1,
                      label: 'PDF Files',
                      icon: Icons.picture_as_pdf_outlined,
                      activeColor: const Color(0xFF2563EB),
                      count: widget.historyItems.length,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chip 2: Trash
                  Expanded(
                    child: _buildSegmentChip(
                      index: 2,
                      label: 'Trash',
                      icon: Icons.delete_outline_rounded,
                      activeColor: const Color(0xFFEF4444),
                      count: widget.trashItems.length,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
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
                        style: TextStyle(color: primaryTextColor, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: _activeTab == 0
                              ? 'Search documents...'
                              : _activeTab == 1
                                  ? 'Search PDF files...'
                                  : 'Search trash...',
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

            // Tab Content
            Expanded(
              child: _activeTab == 0
                  ? _buildDocumentsContent()
                  : _activeTab == 1
                      ? _buildAllFilesContent()
                      : _buildTrashContent(),
            ),
          ],
        ),
      ),
    );
  }

  // --- SEGMENT CHIP BUILDER ---

  Widget _buildSegmentChip({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    required int count,
  }) {
    final isSelected = _activeTab == index;
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
          _searchController.clear();
          _searchQuery = '';
          _exitDocSelectionMode();
          _exitFileSelectionMode();
          _exitTrashSelectionMode();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark ? const Color(0xFF1E2026) : Colors.white)
              : (widget.isDark ? const Color(0xFF16171B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
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
              icon,
              color: isSelected ? activeColor : secondaryTextColor,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? primaryTextColor : secondaryTextColor,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : secondaryTextColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : primaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- TAB 0: DOCUMENTS CONTENT (Doc Sets, Folders, Group Images) ---

  Widget _buildDocumentsContent() {
    final textPrimary = widget.isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1B242D) : Colors.white;
    final dividerColor = widget.isDark ? const Color(0xFF24303C) : const Color(0xFFE2E8F0);

    return Column(
      children: [
        // Subheader or Multi-selection Bar
        _isDocSelectionMode
            ? Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0288D1).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Cancel',
                      onPressed: _exitDocSelectionMode,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_selectedDocSetIds.length} Selected',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0288D1),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _selectedDocSetIds.length == _filteredDocuments.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        color: const Color(0xFF0288D1),
                        size: 20,
                      ),
                      tooltip: _selectedDocSetIds.length == _filteredDocuments.length ? 'Deselect All' : 'Select All',
                      onPressed: _selectAllDocSets,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_folders.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.drive_file_move_outlined, color: Color(0xFF0288D1), size: 20),
                        tooltip: 'Move to Folder',
                        onPressed: _batchMoveToFolder,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Color(0xFF2563EB), size: 20),
                      tooltip: 'Share',
                      onPressed: _batchShareDocSets,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      tooltip: 'Move to Trash',
                      onPressed: _batchDeleteDocSets,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 16, 4),
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
                            fontSize: 16,
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

        // List of Document Sets or Empty State
        Expanded(
          child: _isLoadingDocSets
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
                        final isSelected = _selectedDocSetIds.contains(docSet.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (widget.isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF))
                                : cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0288D1) : dividerColor,
                              width: isSelected ? 2.0 : 1.0,
                            ),
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
                            onLongPress: () {
                              if (!_isDocSelectionMode) {
                                _enterDocSelectionMode(docSet);
                              }
                            },
                            onTap: () {
                              if (_isDocSelectionMode) {
                                _toggleSelectDocSet(docSet.id);
                              } else {
                                _openDocumentSet(docSet);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  if (_isDocSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? const Color(0xFF0288D1) : textSecondary.withOpacity(0.5),
                                        size: 24,
                                      ),
                                    ),
                                  // Left: Document Preview Container
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

                                  // Right: 3-dots Menu
                                  if (!_isDocSelectionMode)
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
    );
  }

  // --- TAB 1: ALL PDF FILES CONTENT ---

  Widget _buildAllFilesContent() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_filteredFiles.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: _searchQuery.isEmpty ? 'No PDF files saved yet' : 'No matching files',
          subtitle: _searchQuery.isEmpty ? 'Convert documents or scan sets to access PDFs here' : 'Try searching with another name',
          isDark: widget.isDark,
        ),
      );
    }

    return Column(
      children: [
        if (_isFileSelectionMode)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel Selection',
                  onPressed: _exitFileSelectionMode,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_selectedFileIds.length} Selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _selectedFileIds.length == _filteredFiles.length
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 20,
                    color: const Color(0xFF2563EB),
                  ),
                  tooltip: _selectedFileIds.length == _filteredFiles.length ? 'Deselect All' : 'Select All',
                  onPressed: _selectAllFiles,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF16A34A)),
                  tooltip: 'Save to Downloads',
                  onPressed: _batchSaveToDownloads,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF2563EB)),
                  tooltip: 'Share Selected',
                  onPressed: _batchShareFiles,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                  tooltip: 'Move to Trash',
                  onPressed: _batchDeleteFiles,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )
        else
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
                if (widget.historyItems.isNotEmpty)
                  TextButton(
                    onPressed: _confirmClearAllFiles,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: _filteredFiles.length,
            itemBuilder: (ctx, index) {
              final item = _filteredFiles[index];
              final isSelected = _selectedFileIds.contains(item.id);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.isDark ? const Color(0xFF1E2838) : const Color(0xFFEFF6FF))
                      : cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF2563EB) : borderColor,
                    width: isSelected ? 2.0 : 1.0,
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
                  leading: isSelected || _isFileSelectionMode
                      ? Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? const Color(0xFF2563EB) : secondaryTextColor.withOpacity(0.5),
                            size: 26,
                          ),
                        )
                      : Container(
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(item.size, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                        const SizedBox(width: 8),
                        Text('${item.pages} p.', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                        const SizedBox(width: 8),
                        Text('•', style: TextStyle(color: secondaryTextColor, fontSize: 10)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: secondaryTextColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: _isFileSelectionMode
                      ? null
                      : IconButton(
                          icon: Icon(Icons.more_vert_rounded, color: secondaryTextColor),
                          onPressed: () => _showFileActions(item),
                        ),
                  onLongPress: () {
                    if (!_isFileSelectionMode) {
                      _enterFileSelectionMode(item);
                    }
                  },
                  onTap: () {
                    if (_isFileSelectionMode) {
                      _toggleSelectFile(item.id);
                    } else {
                      OpenFilex.open(item.path);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TAB 2: TRASH CONTENT ---

  Widget _buildTrashContent() {
    final secondaryTextColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = widget.isDark ? const Color(0xFF1E2026) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFE2E8F0);
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    if (_filteredTrash.isEmpty) {
      return Center(
        child: SpaceEmptyIllustration(
          title: _searchQuery.isEmpty ? 'Trash is empty' : 'No matching items in trash',
          subtitle: _searchQuery.isEmpty ? 'Deleted files are safely kept here for 30 days' : 'Try searching with another name',
          isDark: widget.isDark,
        ),
      );
    }

    return Column(
      children: [
        // 30-day banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Items in Trash are permanently deleted after 30 days.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        if (_isTrashSelectionMode)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF2A1C20) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Cancel Selection',
                  onPressed: _exitTrashSelectionMode,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_selectedTrashIds.length} Selected',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFEF4444)),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _selectedTrashIds.length == _filteredTrash.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                    size: 20,
                    color: const Color(0xFFEF4444),
                  ),
                  tooltip: _selectedTrashIds.length == _filteredTrash.length ? 'Deselect All' : 'Select All',
                  onPressed: _selectAllTrash,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.restore_from_trash_rounded, size: 20, color: Color(0xFF10B981)),
                  tooltip: 'Restore Selected',
                  onPressed: _batchRestoreTrash,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_forever_rounded, size: 20, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Forever',
                  onPressed: _confirmBatchDeletePermanently,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredTrash.length} Item${_filteredTrash.length == 1 ? '' : 's'} in Trash',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: secondaryTextColor),
                ),
                TextButton(
                  onPressed: _confirmEmptyTrash,
                  child: const Text(
                    'Empty Trash',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: _filteredTrash.length,
            itemBuilder: (ctx, index) {
              final trashItem = _filteredTrash[index];
              final isSelected = _selectedTrashIds.contains(trashItem.item.id);
              final daysLeft = trashItem.daysRemaining;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (widget.isDark ? const Color(0xFF2A1C20) : const Color(0xFFFEF2F2))
                      : cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEF4444) : borderColor,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: isSelected || _isTrashSelectionMode
                      ? Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          child: Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? const Color(0xFFEF4444) : secondaryTextColor.withOpacity(0.5),
                            size: 26,
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
                        ),
                  title: Text(
                    trashItem.item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(trashItem.item.size, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                      ],
                    ),
                  ),
                  trailing: _isTrashSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore_from_trash_rounded, color: Color(0xFF10B981), size: 22),
                              tooltip: 'Restore',
                              onPressed: () => widget.onRestoreTrashItem(trashItem),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
                              tooltip: 'Delete Forever',
                              onPressed: () => widget.onDeletePermanently(trashItem),
                            ),
                          ],
                        ),
                  onLongPress: () {
                    if (!_isTrashSelectionMode) {
                      _enterTrashSelectionMode(trashItem);
                    }
                  },
                  onTap: () {
                    if (_isTrashSelectionMode) {
                      _toggleSelectTrashItem(trashItem.item.id);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- DUAL FLOATING ACTION BUTTON [ 📷 | + ] ---

  Widget _buildDualFab() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF0288D1),
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
    );
  }
}
