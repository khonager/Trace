package chat.trace.client

import java.io.File
import java.security.MessageDigest
import android.content.ClipboardManager
import android.content.Context
import android.provider.OpenableColumns
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chat.trace/installation")
            .setMethodCallHandler { call, result ->
                val user = call.arguments as? String
                if (user.isNullOrBlank()) {
                    result.error("invalid_user", "Missing account", null)
                    return@setMethodCallHandler
                }
                try {
                    val digest = MessageDigest.getInstance("SHA-256")
                        .digest(user.toByteArray()).joinToString("") { "%02x".format(it) }
                    val receipt = File(noBackupFilesDir, "trace-confirmed-$digest")
                    when (call.method) {
                        "isConfirmed" -> result.success(receipt.exists())
                        "confirm" -> {
                            receipt.writeText("1")
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("storage_failed", "Could not confirm this installation", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chat.trace/clipboard")
            .setMethodCallHandler { call, result ->
                if (call.method == "files") {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = clipboard.primaryClip
                    val files = if (clip == null) emptyList() else
                        (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri?.toString() }
                    result.success(files)
                    return@setMethodCallHandler
                }
                if (call.method != "readContent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val value = call.argument<String>("uri")
                if (value == null || Uri.parse(value).scheme != "content") {
                    result.error("invalid_uri", "Expected a content URI", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val uri = Uri.parse(value)
                        var name = "attachment"
                        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                            if (it.moveToFirst()) name = it.getString(0) ?: name
                        }
                        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                            ?: error("Clipboard file is unavailable")
                        runOnUiThread { result.success(mapOf("name" to name, "bytes" to bytes)) }
                    } catch (error: Exception) {
                        runOnUiThread { result.error("read_failed", "Could not read clipboard file", null) }
                    }
                }.start()
            }
    }
}
