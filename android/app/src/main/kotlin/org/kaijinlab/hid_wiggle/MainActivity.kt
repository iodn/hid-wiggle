package org.kaijinlab.hid_wiggle

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var logBus: LogBus
    private lateinit var manager: GadgetManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val backend = BackendHolder.get(applicationContext)
        logBus = backend.logBus
        manager = backend.manager

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CHANNEL_METHODS).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkRoot" -> runAsync(result) { manager.checkRoot() }
                "checkSupport" -> runAsync(result) { manager.checkSupport() }
                "listUdcs" -> runAsync(result) { manager.listUdcs() }
                "getStatus" -> runAsync(result) { manager.getStatusSnapshot().toMap() }
                "getDiagnostics" -> runAsync(result) { manager.getDiagnostics() }
                "activateProfile" -> {
                    val map = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    runAsync(result) { manager.activate(map); null }
                }
                "deactivate" -> runAsync(result) { manager.deactivate(); null }
                "panicStop" -> runAsync(result) { manager.panicStop(); null }
                "testMouseMove" -> {
                    val args = (call.arguments as? Map<*, *>) ?: emptyMap<String, Any>()
                    val dx = (args["dx"] as? Number)?.toInt() ?: 8
                    val dy = (args["dy"] as? Number)?.toInt() ?: 0
                    val wheel = (args["wheel"] as? Number)?.toInt() ?: 0
                    val buttons = (args["buttons"] as? Number)?.toInt() ?: 0
                    runAsync(result) { manager.testMouseMove(dx, dy, wheel, buttons); null }
                }
                "testKeyboardKey" -> {
                    val args = (call.arguments as? Map<*, *>) ?: emptyMap<String, Any>()
                    val key = args["label"]?.toString() ?: args["key"]?.toString() ?: "A"
                    runAsync(result) { manager.testKeyboardKey(key); null }
                }
                "testCtrlAltDel" -> runAsync(result) { manager.testCtrlAltDel(); null }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, CHANNEL_DEVICE_STATE).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceState" -> runAsync(result) { getDeviceState() }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, CHANNEL_LOGS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                logBus.attach(events)
            }
            override fun onCancel(arguments: Any?) {
                logBus.detach()
            }
        })

        EventChannel(messenger, CHANNEL_STATUS).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                manager.attachStatusSink(events)
            }
            override fun onCancel(arguments: Any?) {
                manager.detachStatusSink()
            }
        })
    }

    private fun getDeviceState(): Map<String, Any> {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val screenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
            powerManager.isInteractive
        } else {
            @Suppress("DEPRECATION")
            powerManager.isScreenOn
        }

        val batteryStatus: Intent? = IntentFilter(Intent.ACTION_BATTERY_CHANGED).let { filter ->
            applicationContext.registerReceiver(null, filter)
        }

        val batteryPercent = batteryStatus?.let { intent ->
            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            if (level >= 0 && scale > 0) {
                (level * 100 / scale)
            } else {
                100
            }
        } ?: 100

        val charging = batteryStatus?.let { intent ->
            val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
        } ?: false

        return mapOf(
            "screenOn" to screenOn,
            "charging" to charging,
            "batteryPercent" to batteryPercent
        )
    }

    private fun runAsync(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (t: Throwable) {
                mainHandler.post { result.error("ERR", t.message, null) }
            }
        }
    }

    companion object {
        private const val CHANNEL_METHODS = "org.kaijinlab.hid_wiggle/gadget"
        private const val CHANNEL_DEVICE_STATE = "org.kaijinlab.hid_wiggle/device_state"
        private const val CHANNEL_LOGS = "org.kaijinlab.hid_wiggle/gadget_logs"
        private const val CHANNEL_STATUS = "org.kaijinlab.hid_wiggle/gadget_status"
    }
}

private object BackendHolder {
    @Volatile
    private var instance: Backend? = null

    fun get(ctx: android.content.Context): Backend {
        return instance ?: synchronized(this) {
            instance ?: Backend(ctx.applicationContext).also { instance = it }
        }
    }

    class Backend(ctx: android.content.Context) {
        val logBus = LogBus()
        val manager = GadgetManager(ctx, logBus)
    }
}
