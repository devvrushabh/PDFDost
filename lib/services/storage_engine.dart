import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class StorageEngine {
  static const String _historyKey = 'img2pdf_history_list';
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
}
