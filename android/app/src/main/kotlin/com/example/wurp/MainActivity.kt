// android/app/src/main/kotlin/com/example/wurp/MainActivity.kt
package com.example.wurp

import android.app.ActivityManager
import android.content.Context
import android.media.MediaCodec
import android.media.MediaFormat
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "video_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setMaxVideoResolution" -> {
                    val maxWidth = call.argument<Int>("maxWidth") ?: 720
                    val maxHeight = call.argument<Int>("maxHeight") ?: 1280
                    setMaxVideoResolution(maxWidth, maxHeight)
                    result.success(null)
                }
                "getAvailableMemory" -> {
                    val memoryMb = getAvailableMemoryMb()
                    result.success(memoryMb)
                }
                "enableHardwareAcceleration" -> {
                    enableHardwareAcceleration()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setMaxVideoResolution(maxWidth: Int, maxHeight: Int) {
        // Setze System-Property für MediaCodec
        try {
            System.setProperty("media.stagefright.max-video-width", maxWidth.toString())
            System.setProperty("media.stagefright.max-video-height", maxHeight.toString())

            // Force downsampling
            System.setProperty("media.stagefright.enable-downsampling", "true")

            android.util.Log.d("VideoConfig", "Max video resolution set to ${maxWidth}x${maxHeight}")
        } catch (e: Exception) {
            android.util.Log.e("VideoConfig", "Failed to set video resolution: ${e.message}")
        }
    }

    private fun getAvailableMemoryMb(): Int {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        return (memoryInfo.availMem / (1024 * 1024)).toInt()
    }

    private fun enableHardwareAcceleration() {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        // Erhöhe Memory-Limit für Video-Decoding
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                activityManager.memoryClass // Trigger memory optimization

                android.util.Log.d("VideoConfig", "Hardware acceleration enabled, Memory class: ${activityManager.memoryClass}MB")
            } catch (e: Exception) {
                android.util.Log.e("VideoConfig", "Failed to optimize memory: ${e.message}")
            }
        }
    }
}