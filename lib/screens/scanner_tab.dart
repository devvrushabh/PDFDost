import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/pdf_engine.dart';
import '../widgets/export_modal.dart';

class ScannerTab extends StatefulWidget {
  final bool isDark;
  final Function(SelectedImageItem) onAddScannedImage;
  final Function(HistoryItem) onAddHistoryItem;

  const ScannerTab({
    super.key,
    required this.isDark,
    required this.onAddScannedImage,
    required this.onAddHistoryItem,
  });

  @override
  State<ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<ScannerTab> {
  final ImagePicker _picker = ImagePicker();
  final List<SelectedImageItem> _scannedBatch = [];
  bool _isFlashOn = false;
  bool _isConverting = false;

  Future<void> _captureFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
      );
      if (file != null) {
        final f = File(file.path);
        final size = await f.length();
        final name = 'Scan_${DateFormat('HHmmss').format(DateTime.now())}.jpg';
        final item = SelectedImageItem(path: file.path, name: name, sizeBytes: size);
        setState(() {
          _scannedBatch.add(item);
        });
        widget.onAddScannedImage(item);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final List<XFile> files = await _picker.pickMultiImage();
      for (final file in files) {
        final f = File(file.path);
        final size = await f.length();
        final name = file.name.isNotEmpty ? file.name : 'Scan_${DateFormat('HHmmss').format(DateTime.now())}.jpg';
        final item = SelectedImageItem(path: file.path, name: name, sizeBytes: size);
        setState(() {
          _scannedBatch.add(item);
        });
        widget.onAddScannedImage(item);
      }
    } catch (_) {}
  }

  Future<void> _convertScannedBatchToPdf() async {
    if (_scannedBatch.isEmpty) return;
    setState(() => _isConverting = true);
    try {
      final result = await PdfEngine.convertImagesToPdf(
        images: _scannedBatch,
        docName: 'ScannedDoc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
        addPageNumbers: true,
      );

      final entry = HistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result.name,
        path: result.path,
        pages: result.pages,
        size: result.sizeStr,
        date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
        toolType: 'Scanner to PDF',
      );
      widget.onAddHistoryItem(entry);

      if (mounted) {
        setState(() {
          _scannedBatch.clear();
        });
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
          SnackBar(content: Text('Scan conversion failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Top Scanner Toolbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Document Viewfinder',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: _isFlashOn ? const Color(0xFFFBBF24) : Colors.grey,
                    ),
                    onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
                  ),
                ],
              ),
            ),

            // Viewfinder Camera Frame Simulation
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF1E2026) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: widget.isDark ? const Color(0xFF2E303A) : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Corner guides
                    Positioned(
                      top: 24,
                      left: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                            left: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 24,
                      right: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                            right: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                            left: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 24,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                            right: BorderSide(color: Color(0xFFFA9282), width: 3.5),
                          ),
                        ),
                      ),
                    ),

                    // Center scan instructions / thumbnail preview
                    if (_scannedBatch.isEmpty)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFA9282).withOpacity(0.16),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.document_scanner_rounded, color: Color(0xFFFA9282), size: 36),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Align Document within Frame',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the Camera button below to scan',
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_scannedBatch.last.path),
                              width: 170,
                              height: 220,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${_scannedBatch.length} Page(s) Scanned',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Scan Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Import from gallery
                  IconButton(
                    iconSize: 32,
                    tooltip: 'Gallery',
                    icon: Icon(Icons.photo_library_outlined, color: widget.isDark ? Colors.white70 : Colors.black87),
                    onPressed: _importFromGallery,
                  ),

                  // Shutter Camera Button
                  GestureDetector(
                    onTap: _captureFromCamera,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFA9282),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA9282).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.camera_alt_rounded, color: Color(0xFF1E1F24), size: 34),
                      ),
                    ),
                  ),

                  // Convert to PDF action
                  IconButton(
                    iconSize: 32,
                    tooltip: 'Convert to PDF',
                    icon: Icon(
                      Icons.check_circle_rounded,
                      color: _scannedBatch.isNotEmpty ? const Color(0xFF10B981) : Colors.grey.withOpacity(0.4),
                    ),
                    onPressed: _scannedBatch.isNotEmpty ? _convertScannedBatchToPdf : null,
                  ),
                ],
              ),
            ),
          ],
        ),

        if (_isConverting)
          Container(
            color: Colors.black.withOpacity(0.6),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: Color(0xFFE5322D)),
          ),
      ],
    );
  }
}
