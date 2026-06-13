package com.example.topicos

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.File
import kotlin.concurrent.thread

class LlamaServerPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        init {
            System.loadLibrary("llama-server-jni")
        }
    }

    private external fun nativeStartServer(
        modelPath: String, port: Int, threads: Int,
        contextSize: Int, useGpu: Boolean
    ): Boolean

    private external fun nativeStopServer()
    private external fun nativeIsRunning(): Boolean

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "llama_server")
        channel.setMethodCallHandler(this)
    }

    private fun resolveModelPath(originalPath: String): String {
        val file = File(originalPath)
        if (file.canRead()) {
            try {
                java.io.RandomAccessFile(file, "r").close()
                Log.d("LlamaServer", "Using original path: $originalPath")
                return originalPath
            } catch (_: Exception) {
                Log.w("LlamaServer", "File exists but Java can't read it")
            }
        }
        val ctx = appContext ?: return originalPath
        val dir = File(ctx.filesDir, "models")
        if (!dir.exists()) dir.mkdirs()
        val dest = File(dir, file.name)
        if (dest.exists() && dest.length() > 0L) {
            Log.d("LlamaServer", "Using cached private copy: ${dest.absolutePath}")
            return dest.absolutePath
        }
        Log.d("LlamaServer", "Copying via shell cp to ${dest.absolutePath}...")
        val t0 = System.currentTimeMillis()
        try {
            val proc = Runtime.getRuntime().exec(arrayOf("cp", originalPath, dest.absolutePath))
            val code = proc.waitFor()
            val dt = System.currentTimeMillis() - t0
            Log.d("LlamaServer", "cp exited=$code in ${dt}ms, dest.exists=${dest.exists()} size=${dest.length()}")
            if (code == 0 && dest.exists()) return dest.absolutePath
        } catch (e: Exception) {
            Log.e("LlamaServer", "Shell cp failed: ${e.message}")
        }
        Log.e("LlamaServer", "Could not access model file at $originalPath")
        Log.e("LlamaServer", "Try: adb shell \"cat $originalPath | run-as com.example.topicos sh -c 'cat > ${dest.absolutePath}'\"")
        return originalPath
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startServer" -> {
                val modelPath = call.argument<String>("modelPath") ?: return result.error("NO_PATH", "modelPath required", null)
                val port = call.argument<Int>("port") ?: 8080
                val threads = call.argument<Int>("threads") ?: 2
                val contextSize = call.argument<Int>("contextSize") ?: 2048
                val useGpu = call.argument<Boolean>("useGpu") ?: false
                thread {
                    Thread.currentThread().setUncaughtExceptionHandler { t, e ->
                        Log.e("LlamaServer", "Uncaught exception in thread ${t.name}", e)
                    }
                    try {
                        val resolvedPath = resolveModelPath(modelPath)
                        val ok = nativeStartServer(resolvedPath, port, threads, contextSize, useGpu)
                        Handler(Looper.getMainLooper()).post { result.success(ok) }
                    } catch (e: Exception) {
                        Log.e("LlamaServer", "JNI start failed", e)
                        Handler(Looper.getMainLooper()).post { result.error("START_FAILED", e.message, null) }
                    }
                }
            }
            "stopServer" -> {
                try {
                    nativeStopServer()
                } catch (_: Exception) {}
                result.success(true)
            }
            "isRunning" -> {
                result.success(nativeIsRunning())
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try { nativeStopServer() } catch (_: Exception) {}
        channel.setMethodCallHandler(null)
        appContext = null
    }
}
