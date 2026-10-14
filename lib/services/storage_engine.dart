import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageEngine {
  static const String _historyKey = 'img2pdf_history_list';
  static const String _trashKey = 'img2pdf_trash_list';
  static const String _themeKey = 'img2pdf_theme_mode';
  static const String _mobileDataKey = 'img2pdf_ask_mobile_data';
  static const String _ocrLangKey = 'img2pdf_ocr_language';

  static const MethodChannel _storageChannel = MethodChannel('com.devvrushabh.img2pdf/storage');

  static Future<List<HistoryItem>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        return decoded
            .map((item) => HistoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveHistory(List<HistoryItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((e) => e.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<void> saveHistoryItem(HistoryItem item) async {
    try {
      final list = await loadHistory();
      list.insert(0, item);
      await saveHistory(list);
    } catch (_) {}
  }

  static Future<bool> loadDarkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to dark mode as shown in user screenshots
      return prefs.getBool(_themeKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveDarkMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    } catch (_) {}
  }

  static Future<bool> loadAskMobileData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_mobileDataKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> saveAskMobileData(bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mobileDataKey, val);
    } catch (_) {}
  }

  static Future<String> loadOcrLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ocrLangKey) ?? 'English';
    } catch (_) {
      return 'English';
    }
  }

  static Future<void> saveOcrLanguage(String lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ocrLangKey, lang);
    } catch (_) {}
  }

  static Future<bool> saveToDownloads(String sourcePath, String fileName) async {
    try {
      if (Platform.isAndroid) {
        try {
          final String? savedLocation = await _storageChannel.invokeMethod<String>(
            'saveToDownloads',
            {'sourcePath': sourcePath, 'fileName': fileName},
          );
          if (savedLocation != null) return true;
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
        final destPath = '${targetDir.path}/$fileName';
        await File(sourcePath).copy(destPath);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> savePdfFile({required String sourcePath, required String fileName}) =>
      saveToDownloads(sourcePath, fileName);

  static Future<bool> openUpiPayment(String upiUri) async {
    if (Platform.isAndroid) {
      try {
        final res = await _storageChannel.invokeMethod<bool>('openUpi', {
          'upiUri': upiUri,
        });
        return res ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // --- TRASH & 30-DAY RETENTION SYSTEM ---

  /// Loads trash items and automatically purges any files retained for > 30 days
  static Future<List<TrashItem>> loadTrash() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trashJson = prefs.getString(_trashKey);
      if (trashJson != null) {
        final List<dynamic> decoded = jsonDecode(trashJson);
        final list = decoded
            .map((item) => TrashItem.fromJson(item as Map<String, dynamic>))
            .toList();

        // Automatic 30-day purge
        final List<TrashItem> activeTrash = [];
        bool hasExpired = false;

        for (final trashItem in list) {
          if (trashItem.isExpired) {
            hasExpired = true;
            try {
              final file = File(trashItem.item.path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          } else {
            activeTrash.add(trashItem);
          }
        }

        if (hasExpired) {
          await saveTrash(activeTrash);
        }

        return activeTrash;
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveTrash(List<TrashItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((e) => e.toJson()).toList();
      await prefs.setString(_trashKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  static Future<TrashItem> moveToTrash(HistoryItem item) async {
    final trashItem = TrashItem(
      item: item,
      deletedAt: DateTime.now(),
    );
    try {
      final trashList = await loadTrash();
      // Remove any existing entry for this id
      trashList.removeWhere((e) => e.item.id == item.id);
      trashList.insert(0, trashItem);
      await saveTrash(trashList);
    } catch (_) {}
    return trashItem;
  }

  static Future<HistoryItem?> restoreFromTrash(TrashItem trashItem) async {
    try {
      final trashList = await loadTrash();
      trashList.removeWhere((e) => e.item.id == trashItem.item.id);
      await saveTrash(trashList);

      final historyList = await loadHistory();
      if (!historyList.any((e) => e.id == trashItem.item.id)) {
        historyList.insert(0, trashItem.item);
        await saveHistory(historyList);
      }
      return trashItem.item;
    } catch (_) {}
    return null;
  }

  static Future<void> deletePermanently(TrashItem trashItem) async {
    try {
      final file = File(trashItem.item.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    try {
      final trashList = await loadTrash();
      trashList.removeWhere((e) => e.item.id == trashItem.item.id);
      await saveTrash(trashList);
    } catch (_) {}
  }

  static Future<void> emptyTrash() async {
    try {
      final trashList = await loadTrash();
      for (final t in trashList) {
        try {
          final file = File(t.item.path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trashKey);
    } catch (_) {}
  }

  static Future<int> cleanExpiredTrash() async {
    int purgedCount = 0;
    try {
      final trashList = await loadTrash(); // loadTrash() automatically purges expired items
      purgedCount = trashList.length;
    } catch (_) {}
    return purgedCount;
  }
}
