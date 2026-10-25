package chat.trace.client

import android.provider.OpenableColumns
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chat.trace/clipboard")
            .setMethodCallHandler { call, result ->
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
