import 'dart:convert';

class SelectedImageItem {
  final String path;
  final String name;
  final int sizeBytes;

  SelectedImageItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SelectedPdfItem {
  final String path;
  final String name;
  final int sizeBytes;
  final int pageCount;

  SelectedPdfItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.pageCount = 1,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SelectedWordItem {
  final String path;
  final String name;
  final int sizeBytes;
  final String extension;

  SelectedWordItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.extension,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SplitPdfConfigItem {
  final String path;
  final String name;
  final int sizeBytes;
  final int pageCount;
  int startPage;
  int endPage;
  bool splitAllPages;

  SplitPdfConfigItem({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.pageCount,
    this.startPage = 1,
    int? endPage,
    this.splitAllPages = false,
  }) : endPage = endPage ?? pageCount;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get pagesToExtractCount {
    if (splitAllPages) return pageCount;
    return (endPage - startPage + 1).clamp(1, pageCount);
  }
}

class HistoryItem {
  final String id;
  final String name;
  final String path;
  final int pages;
  final String size;
  final String date;
  final String toolType;

  HistoryItem({
    required this.id,
    required this.name,
    required this.path,
    required this.pages,
    required this.size,
    required this.date,
    this.toolType = 'Image to PDF',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'pages': pages,
        'size': size,
        'date': date,
        'toolType': toolType,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Document.pdf',
        path: json['path'] as String? ?? '',
        pages: json['pages'] as int? ?? 1,
        size: json['size'] as String? ?? '0 KB',
        date: json['date'] as String? ?? '',
        toolType: json['toolType'] as String? ?? 'Image to PDF',
      );
}

class TrashItem {
  final HistoryItem item;
  final DateTime deletedAt;

  TrashItem({
    required this.item,
    required this.deletedAt,
  });

  /// Days remaining out of the 30-day retention period
  int get daysRemaining {
    final expiryDate = deletedAt.add(const Duration(days: 30));
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Whether the item has passed the 30-day retention period
  bool get isExpired {
    return DateTime.now().isAfter(deletedAt.add(const Duration(days: 30)));
  }

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashItem.fromJson(Map<String, dynamic> json) => TrashItem(
        item: HistoryItem.fromJson(json['item'] as Map<String, dynamic>),
        deletedAt: json['deletedAt'] != null
            ? DateTime.tryParse(json['deletedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

enum PdfToolType {
  mergePdf,
  splitPdf,
  compressPdf,
  pdfToWord,
  pdfToPowerPoint,
  pdfToExcel,
  wordToPdf,
  powerPointToPdf,
  excelToPdf,
  editPdf,
  pdfToJpg,
  imageToPdf,
  pageNumbers,
  watermark,
  rotatePdf,
  lockPdf,
}

class ToolDefinition {
  final PdfToolType type;
  final String title;
  final String subtitle;

  const ToolDefinition({
    required this.type,
    required this.title,
    required this.subtitle,
  });
}
