package com.devvrushabh.img2pdf

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.devvrushabh.img2pdf/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                if (sourcePath == null || fileName == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedPath = saveFileToDownloads(sourcePath, fileName)
                    result.success(savedPath)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            } else if (call.method == "openUpi") {
                val upiUri = call.argument<String>("upiUri")
                if (upiUri == null) {
                    result.error("INVALID_ARGS", "Missing upiUri", null)
                    return@setMethodCallHandler
                }

                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        data = Uri.parse(upiUri)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveFileToDownloads(sourcePath: String, fileName: String): String {
        val srcFile = File(sourcePath)
        if (!srcFile.exists()) {
            throw Exception("Source file not found at $sourcePath")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ (API 29+): Scoped Storage MediaStore.Downloads
            val resolver = applicationContext.contentResolver
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Could not insert file into MediaStore Downloads")

            resolver.openOutputStream(uri)?.use { outputStream ->
                FileInputStream(srcFile).use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            } ?: throw Exception("Could not open output stream to MediaStore URI")

            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return "Downloads/$fileName"
        } else {
            // Android 9 and below
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val destFile = File(downloadsDir, fileName)
            FileInputStream(srcFile).use { inputStream ->
                FileOutputStream(destFile).use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
            return destFile.absolutePath
        }
    }
}
