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

class DocPage {
  final String id;
  String imagePath;
  String name;
  int sizeBytes;
  DateTime date;
  bool isNew;

  DocPage({
    required this.id,
    required this.imagePath,
    required this.name,
    required this.sizeBytes,
    required this.date,
    this.isNew = true,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} kB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'name': name,
        'sizeBytes': sizeBytes,
        'date': date.toIso8601String(),
        'isNew': isNew,
      };

  factory DocPage.fromJson(Map<String, dynamic> json) => DocPage(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: json['imagePath'] as String? ?? '',
        name: json['name'] as String? ?? '1',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        date: json['date'] != null
            ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
            : DateTime.now(),
        isNew: json['isNew'] as bool? ?? false,
      );
}

class DocFolder {
  final String id;
  String name;
  DateTime createdAt;
  String colorHex;

  DocFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.colorHex = '#0288D1',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'colorHex': colorHex,
      };

  factory DocFolder.fromJson(Map<String, dynamic> json) => DocFolder(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'New Folder',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        colorHex: json['colorHex'] as String? ?? '#0288D1',
      );
}

class DocumentSet {
  final String id;
  String title;
  DateTime createdAt;
  DateTime updatedAt;
  List<DocPage> pages;
  String category;
  String? folderId;
  bool isFavourite;
  String? generatedPdfPath;

  DocumentSet({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.category = 'All docs',
    this.folderId,
    this.isFavourite = false,
    this.generatedPdfPath,
  });

  int get pageCount => pages.length;

  String get firstImagePath => pages.isNotEmpty ? pages.first.imagePath : '';

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(updatedAt);
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pages': pages.map((p) => p.toJson()).toList(),
        'category': category,
        'folderId': folderId,
        'isFavourite': isFavourite,
        'generatedPdfPath': generatedPdfPath,
      };

  factory DocumentSet.fromJson(Map<String, dynamic> json) => DocumentSet(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Untitled Document',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        pages: json['pages'] != null
            ? (json['pages'] as List<dynamic>)
                .map((p) => DocPage.fromJson(p as Map<String, dynamic>))
                .toList()
            : [],
        category: json['category'] as String? ?? 'All docs',
        folderId: json['folderId'] as String?,
        isFavourite: json['isFavourite'] as bool? ?? false,
        generatedPdfPath: json['generatedPdfPath'] as String?,
      );
}
