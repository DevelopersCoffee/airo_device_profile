package com.developerscoffee.airo_device_profile

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.media.MediaCodecList
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads runtime device signals for `AiroAndroidRuntimeDeviceProfiler`.
 *
 * Uses only permission-free platform APIs and makes no network calls.
 * Safe on API 24 to 36: newer APIs are behind `Build.VERSION.SDK_INT` checks.
 */
class AiroDeviceProfilePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        val methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        channel = methodChannel
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            METHOD_GET_SIGNALS -> {
                val context = applicationContext
                if (context == null) {
                    result.error("no_context", "Plugin is not attached to an engine.", null)
                    return
                }
                try {
                    result.success(collectSignals(context))
                } catch (e: Exception) {
                    result.error("signals_unavailable", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun collectSignals(context: Context): Map<String, Any?> {
        val signals = HashMap<String, Any?>()
        signals["apiLevel"] = Build.VERSION.SDK_INT

        val activityManager =
            context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        if (activityManager != null) {
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)
            signals["totalMemMb"] = toMb(memoryInfo.totalMem)
            signals["availMemMb"] = toMb(memoryInfo.availMem)
            signals["thresholdMb"] = toMb(memoryInfo.threshold)
            signals["lowMemory"] = memoryInfo.lowMemory
        }

        signals["freeStorageMb"] = freeStorageMb(context)
        signals["thermalStatus"] = thermalStatus(context)
        signals["uiMode"] = uiMode(context)
        signals["hasDpad"] =
            context.resources.configuration.navigation == Configuration.NAVIGATION_DPAD
        signals["securityPatch"] = securityPatch()

        val decoders = decoderSignals()
        signals["videoDecoderCount"] = decoders.first
        signals["decoderMimeTypes"] = decoders.second
        return signals
    }

    private fun freeStorageMb(context: Context): Long? =
        try {
            // App-private volume, where downloaded models are stored.
            toMb(StatFs(context.filesDir.path).availableBytes)
        } catch (e: IllegalArgumentException) {
            null
        }

    private fun thermalStatus(context: Context): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return THERMAL_UNAVAILABLE
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                ?: return THERMAL_UNAVAILABLE
        return powerManager.currentThermalStatus
    }

    private fun uiMode(context: Context): String {
        val uiModeManager =
            context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            return "tv"
        }
        val smallestWidthDp = context.resources.configuration.smallestScreenWidthDp
        return if (smallestWidthDp >= TABLET_SMALLEST_WIDTH_DP) "tablet" else "phone"
    }

    private fun securityPatch(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Build.VERSION.SECURITY_PATCH
        } else {
            null
        }

    /** Returns (video decoder count, distinct decoder MIME types). Best effort. */
    private fun decoderSignals(): Pair<Int, List<String>> =
        try {
            var videoDecoders = 0
            val mimeTypes = LinkedHashSet<String>()
            for (info in MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos) {
                if (info.isEncoder) continue
                val types = info.supportedTypes.map { it.lowercase() }
                if (types.any { it.startsWith("video/") }) videoDecoders++
                mimeTypes.addAll(types)
            }
            Pair(videoDecoders, mimeTypes.toList())
        } catch (e: RuntimeException) {
            Pair(0, emptyList())
        }

    private fun toMb(bytes: Long): Long = bytes / BYTES_PER_MB

    private companion object {
        const val CHANNEL_NAME = "airo_device_profile"
        const val METHOD_GET_SIGNALS = "getSignals"
        const val THERMAL_UNAVAILABLE = -1
        const val TABLET_SMALLEST_WIDTH_DP = 600
        const val BYTES_PER_MB = 1024L * 1024L
    }
}
