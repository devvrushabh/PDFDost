import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ExportModalSheet extends StatefulWidget {
  final String pdfPath;
  final String docName;
  final int pages;
  final String sizeStr;
  final bool isDark;

  const ExportModalSheet({
    super.key,
    required this.pdfPath,
    required this.docName,
    required this.pages,
    required this.sizeStr,
    this.isDark = true,
  });

  static Future<void> show({
    required BuildContext context,
    required String pdfPath,
    required String docName,
    required int pages,
    required String sizeStr,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ExportModalSheet(
        pdfPath: pdfPath,
        docName: docName,
        pages: pages,
        sizeStr: sizeStr,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ExportModalSheet> createState() => _ExportModalSheetState();
}

class _ExportModalSheetState extends State<ExportModalSheet> {
  bool _hasSaved = false;
  static const MethodChannel _storageChannel = MethodChannel('com.devvrushabh.img2pdf/storage');

  Future<void> _shareFile() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.pdfPath, mimeType: 'application/pdf')],
        text: 'Document: ${widget.docName}',
      );
    } catch (e) {
      _showSnackbar('Share failed: $e', isError: true);
    }
  }

  Future<void> _printDocument() async {
    try {
      final file = File(widget.pdfPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: widget.docName,
        );
      } else {
        _showSnackbar('File not found for printing', isError: true);
      }
    } catch (e) {
      _showSnackbar('Print failed: $e', isError: true);
    }
  }

  Future<void> _saveToDownloads() async {
    try {
      if (Platform.isAndroid) {
        try {
          final String? savedLocation = await _storageChannel.invokeMethod<String>(
            'saveToDownloads',
            {'sourcePath': widget.pdfPath, 'fileName': widget.docName},
          );
          if (savedLocation != null) {
            setState(() => _hasSaved = true);
            _showSnackbar('✓ Saved to Downloads: ${widget.docName}');
            return;
          }
        } catch (_) {}
      }

      // Fallback
      Directory? targetDir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetDir = downloadDir;
        } else {
          targetDir = await getExternalStorageDirectory();
        }
      } else {
        targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (targetDir != null) {
        final destPath = '${targetDir.path}/${widget.docName}';
        await File(widget.pdfPath).copy(destPath);
        setState(() => _hasSaved = true);
        _showSnackbar('✓ Saved to Downloads: ${widget.docName}');
      } else {
        _showSnackbar('Could not locate Downloads folder', isError: true);
      }
    } catch (e) {
      _showSnackbar('Save error: $e', isError: true);
    }
  }

  Future<void> _openPdf() async {
    try {
      await OpenFilex.open(widget.pdfPath);
    } catch (e) {
      _showSnackbar('Could not open file: $e', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 38),
          ),
          const SizedBox(height: 14),
          Text(
            'PDF Processed Successfully!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.docName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE5322D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.pages} Pages  •  ${widget.sizeStr}',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 24),

          // 1. Share Option
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5322D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _shareFile,
              icon: const Icon(Icons.share_rounded),
              label: const Text(
                'Share (WhatsApp, Apps...)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Print Document
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _printDocument,
              icon: const Icon(Icons.print_rounded, color: Color(0xFF0284C7)),
              label: const Text('Print Document', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Save to Downloads
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _hasSaved ? const Color(0xFF16A34A) : textColor,
                side: BorderSide(
                  color: _hasSaved ? const Color(0xFF16A34A) : borderColor,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveToDownloads,
              icon: Icon(
                _hasSaved ? Icons.check_circle_rounded : Icons.download_rounded,
                color: _hasSaved ? const Color(0xFF16A34A) : const Color(0xFFE5322D),
              ),
              label: Text(
                _hasSaved ? '✓ Saved to Downloads!' : 'Save to Device (Downloads)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Open / View PDF
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: borderColor, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _openPdf,
              icon: const Icon(Icons.visibility_rounded, color: Color(0xFF2563EB)),
              label: const Text('Open / View PDF', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Done',
              style: TextStyle(color: subColor, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
