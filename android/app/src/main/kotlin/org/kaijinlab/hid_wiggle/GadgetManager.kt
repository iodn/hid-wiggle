package org.kaijinlab.hid_wiggle

import android.content.Context
import android.util.Log
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import java.util.ArrayList
import java.util.LinkedHashMap
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min

class GadgetManager(
    private val context: Context,
    private val log: LogBus,
) {
    private val main = Handler(Looper.getMainLooper())
    private val root = RootShell(log)
    private val prefs = Prefs(context)
    private val udcNameRegex = Regex("^[A-Za-z0-9._-]+$")

    // Persistent writer FD semantics (RootShell uses FD 3/4 internally)
    private val HID_KBD_FD = 3
    private val HID_MOUSE_FD = 4

    /**
     * Keyboard timing: we must hold a key "down" long enough that the host polling interval
     * will actually observe it. This is why we do down -> usleep -> up.
     */
    private val keyDownHoldUs: Int = 9000
    private val interKeyDelayUs: Int = 1500

    /**
     * Avoid building extremely large scripts. We chunk text typing into batches.
     * With a persistent su session, you can safely raise this somewhat, but keep it bounded.
     */
    private val maxTypedCharsPerBatch: Int = 60

    data class Status(
        val rootAvailable: Boolean,
        val supportAvailable: Boolean,
        val udcList: List<String>,
        val state: String,
        val activeProfileId: String?,
        val message: String?,
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "rootAvailable" to rootAvailable,
            "supportAvailable" to supportAvailable,
            "udcList" to udcList,
            "state" to state,
            "activeProfileId" to activeProfileId,
            "message" to message,
        )
    }

    private val statusRef = AtomicReference(
        Status(
            rootAvailable = false,
            supportAvailable = false,
            udcList = emptyList(),
            state = "IDLE",
            activeProfileId = null,
            message = null,
        )
    )
    private val sinkRef = AtomicReference<EventChannel.EventSink?>(null)

    init {
        refreshAndEmitStatus(restoreFromPrefs = true)
    }

    fun attachStatusSink(sink: EventChannel.EventSink) {
        sinkRef.set(sink)
        val snap = statusRef.get().toMap()
        main.post {
            try {
                sink.success(snap)
            } catch (_: Throwable) {
            }
        }
    }

    fun detachStatusSink() {
        sinkRef.set(null)
    }

    fun getStatusSnapshot(): Status {
        return refreshAndEmitStatus(restoreFromPrefs = false)
    }

    fun refreshAndEmitStatus(restoreFromPrefs: Boolean): Status {
        val current = statusRef.get()
        val rootOk = checkRoot()
        val configfsOk = rootOk && ensureConfigfsAvailable()
        val udcs = if (rootOk) listUdcs() else emptyList()
        val supportOk = rootOk && configfsOk && udcs.isNotEmpty()

        var state = current.state
        var activeId = current.activeProfileId
        var msg = current.message

        if (restoreFromPrefs && state != "ACTIVE") {
            val savedId = prefs.activeProfileId
            val savedDir = prefs.activeGadgetDir
            if (!savedId.isNullOrBlank() && !savedDir.isNullOrBlank() && rootOk) {
                val stillActive = isGadgetDirBound(savedDir)
                if (stillActive) {
                    state = "ACTIVE"
                    activeId = savedId
                    msg = null
                    log.log("gadget", "Restored active state for profile=$savedId")

                    // Best-effort: re-open persistent HID writers after process restart.
                    reopenHidWritersFromPrefsBestEffort()
                } else {
                    prefs.clearActive()
                }
            }
        }

        val next = Status(
            rootAvailable = rootOk,
            supportAvailable = supportOk,
            udcList = udcs,
            state = state,
            activeProfileId = activeId,
            message = msg,
        )
        statusRef.set(next)
        emit(next)
        return next
    }

    fun checkRoot(): Boolean = root.hasRoot()

    fun checkSupport(): Boolean {
        if (!checkRoot()) return false
        if (!ensureConfigfsAvailable()) return false
        return listUdcs().isNotEmpty()
    }

    fun listUdcs(): List<String> {
        val r = root.exec("ls -1 /sys/class/udc 2>/dev/null || true")
        val items = r.stdout
            .lineSequence()
            .map { it.trim().trim('\r') }
            .filter { it.isNotBlank() }
            .filter { udcNameRegex.matches(it) }
            .toList()
        if (items.isNotEmpty()) return items

        val p = root.exec("getprop sys.usb.controller 2>/dev/null || true")
        val lines = p.stdout
            .lineSequence()
            .map { it.trim().trim('\r') }
            .filter { it.isNotBlank() }
            .toList()

        val direct = lines.firstOrNull { udcNameRegex.matches(it) }
        if (!direct.isNullOrBlank()) return listOf(direct)

        val dumpLine = lines.firstOrNull { it.startsWith("[sys.usb.controller]") }
        if (!dumpLine.isNullOrBlank()) {
            val m = Regex("\\[sys\\.usb\\.controller\\]: \\[(.*)]").find(dumpLine)
            val v = m?.groupValues?.getOrNull(1)?.trim()
            if (!v.isNullOrBlank() && udcNameRegex.matches(v)) return listOf(v)
        }
        return emptyList()
    }

    fun activate(profileMap: Map<*, *>) {
        val profile = parseProfile(profileMap)
        if (!checkRoot()) {
            setError("Root not available (su denied).")
            return
        }
        if (!checkSupport()) {
            setError("USB gadget support not detected (configfs/UDC missing).")
            return
        }

        setState("ACTIVATING", profile.id, "Creating gadget…")
        val snap = captureUsbSnapshot()
        prefs.setUsbSnapshot(
            sysUsbConfig = snap.sysUsbConfig,
            sysUsbState = snap.sysUsbState,
            sysUsbConfigfs = snap.sysUsbConfigfs,
            persistSysUsbConfig = snap.persistSysUsbConfig,
            boundGadgets = snap.boundGadgetsRaw,
        )

        val gadgetDir = "gadgetfs_${profile.id.take(12).lowercase(Locale.US)}"
        val script = Configfs.buildCreateAndBindScript(profile, gadgetDir)
        val r = root.exec(script, timeoutSec = 30)
        if (!r.ok) {
            log.logError("gadget", "Activation failed; attempting USB restore")
            restoreUsbSnapshotBestEffort(reason = "activation_failed")
            prefs.clearUsbSnapshot()
            setError("Activation failed (exit=${r.exitCode}). ${r.stderr.trim().ifEmpty { r.stdout.trim() }}")
            return
        }

        val kbdDev = when (profile.roleType.lowercase(Locale.US)) {
            "mouse" -> null
            "keyboard" -> "/dev/hidg0"
            else -> "/dev/hidg0" // composite: hidg0 is keyboard
        }
        val mouseDev = when (profile.roleType.lowercase(Locale.US)) {
            "mouse" -> "/dev/hidg0"
            "keyboard" -> null
            else -> "/dev/hidg1" // composite: hidg1 is mouse
        }

        prefs.setActive(profile.id, profile.roleType, gadgetDir, kbdDev, mouseDev)
        startForeground("USB gadget active: ${profile.name}")

        // Critical: open persistent writers (FD 3/4) in the long-lived root session.
        openHidWritersBestEffort(kbdDev, mouseDev)

        setState("ACTIVE", profile.id, null)
        log.log("gadget", "Active profile: ${profile.id} (${profile.roleType})")
    }

    fun deactivate() {
        val current = statusRef.get()
        if (current.state == "IDLE") return
        if (current.state == "ACTIVATING") return

        setState("ACTIVATING", current.activeProfileId, "Deactivating…")

        try {
            // Keep writers open while releasing keys.
            releaseAllKeysBestEffort()
        } catch (_: Throwable) {
        }

        // Now close persistent writers before unbinding (best-effort).
        closeHidWritersBestEffort()

        val gadgetDir = prefs.activeGadgetDir
        if (!gadgetDir.isNullOrBlank()) {
            root.exec(Configfs.buildUnbindAndCleanupScript(gadgetDir), timeoutSec = 20)
        } else {
            root.exec(Configfs.buildPanicStopScript(), timeoutSec = 20)
        }

        stopForeground()
        restoreUsbSnapshotBestEffort(reason = "deactivate")
        prefs.clearActive()
        prefs.clearUsbSnapshot()

        setState("IDLE", null, null)
        log.log("gadget", "Deactivated")
    }

    fun panicStop() {
        setState("ACTIVATING", null, "Panic stop…")

        try {
            // Keep writers open while releasing keys.
            releaseAllKeysBestEffort()
        } catch (_: Throwable) {
        }

        // Close persistent writers best-effort.
        closeHidWritersBestEffort()

        val gadgetDir = prefs.activeGadgetDir
        if (!gadgetDir.isNullOrBlank()) {
            root.exec(Configfs.buildUnbindAndCleanupScript(gadgetDir), timeoutSec = 20)
        } else {
            root.exec(Configfs.buildPanicStopScript(), timeoutSec = 20)
        }

        stopForeground()
        restoreUsbSnapshotBestEffort(reason = "panic_stop")
        prefs.clearActive()
        prefs.clearUsbSnapshot()

        setState("IDLE", null, null)
        log.log("gadget", "Panic stop complete")
    }

    fun testMouseMove(dx: Int, dy: Int, wheel: Int, buttons: Int) {
        val current = statusRef.get()
        if (current.state != "ACTIVE") throw IllegalStateException("Gadget is not active")
        val path = prefs.activeMouseDev ?: throw IllegalStateException("Mouse HID device not available")

        val report = byteArrayOf(
            (buttons and 0xFF).toByte(),
            (dx.coerceIn(-127, 127) and 0xFF).toByte(),
            (dy.coerceIn(-127, 127) and 0xFF).toByte(),
            (wheel.coerceIn(-127, 127) and 0xFF).toByte(),
        )

        writeMouseReport(path, report)
        log.log("test", "Mouse report to $path dx=$dx dy=$dy wheel=$wheel buttons=$buttons")
    }

    /**
     * Backward-compatible API called by Flutter for both:
     * - single key (ENTER, A, BACKSPACE, etc)
     * - typed text batches (e.g. "hello world")
     *
     * Rule:
     * - If keyLabel resolves to a known key -> send one tap.
     * - Else -> treat as text, type it (with chunking).
     */
    fun testKeyboardKey(keyLabel: String) {
        val current = statusRef.get()
        if (current.state != "ACTIVE") throw IllegalStateException("Gadget is not active")
        val path = prefs.activeKeyboardDev ?: throw IllegalStateException("Keyboard HID device not available")

        val trimmed = keyLabel.trimEnd('\r')
        if (trimmed.isEmpty()) return

        val code = HidSpec.keyCodeFor(trimmed)
        if (code != null) {
            // Single key tap
            writeKeyboardTap(path, mods = 0x00, key = code, downHoldUs = keyDownHoldUs)
            log.log("test", "Keyboard key=$trimmed code=0x${Integer.toHexString(code)}")
            return
        }

        // Otherwise treat as text (batch typing)
        typeText(path, trimmed)
        val preview = if (trimmed.length <= 18) trimmed else trimmed.take(18) + "…"
        log.log("test", "Keyboard text(len=${trimmed.length}) \"$preview\"")
    }

    fun testCtrlAltDel() {
        val current = statusRef.get()
        if (current.state != "ACTIVE") throw IllegalStateException("Gadget is not active")
        val path = prefs.activeKeyboardDev ?: throw IllegalStateException("Keyboard HID device not available")

        val mods = 0x01 or 0x04 // left-ctrl + left-alt
        val del = HidSpec.keyCodeFor("DELETE") ?: 0x4C
        writeKeyboardTap(path, mods = mods, key = del, downHoldUs = 12000)
        log.log("test", "Ctrl+Alt+Del sent")
    }

    private fun openHidWritersBestEffort(kbdDev: String?, mouseDev: String?) {
        try {
            val rr = root.openHidWriters(kbdDev, mouseDev, timeoutSec = 6)
            if (rr.ok) {
                log.log(
                    "hid",
                    "Persistent HID writers ready: kbd=${root.isKeyboardWriterReady()} mouse=${root.isMouseWriterReady()}"
                )
            } else {
                log.logError(
                    "hid",
                    "Failed to open persistent HID writers (exit=${rr.exitCode}). Falling back to per-write opens."
                )
            }
        } catch (t: Throwable) {
            log.logError("hid", "openHidWriters failed: ${t.message}")
        }
    }

    private fun reopenHidWritersFromPrefsBestEffort() {
        val kbdDev = prefs.activeKeyboardDev
        val mouseDev = prefs.activeMouseDev
        if (kbdDev.isNullOrBlank() && mouseDev.isNullOrBlank()) return
        openHidWritersBestEffort(kbdDev, mouseDev)
    }

    private fun closeHidWritersBestEffort() {
        try {
            root.closeHidWriters(timeoutSec = 4)
        } catch (_: Throwable) {
        }
    }

    private fun parseProfile(map: Map<*, *>): Configfs.ParsedProfile {
        val id = (map["id"] ?: "").toString().ifBlank { throw IllegalArgumentException("Profile id missing") }
        val name = (map["name"] ?: "Profile").toString()
        val roleType = (map["roleType"] ?: "mouse").toString()
        val tunables = (map["tunables"] as? Map<*, *>)

        fun str(key: String, fallback: String): String {
            val v = (tunables?.get(key) ?: map[key])?.toString()
            return if (v.isNullOrBlank()) fallback else v
        }

        fun intHexOrDec(key: String, fallback: Int): Int {
            val raw = (tunables?.get(key) ?: map[key])?.toString()?.trim()
            if (raw.isNullOrBlank()) return fallback
            return try {
                if (raw.startsWith("0x", ignoreCase = true)) raw.substring(2).toInt(16) else raw.toInt()
            } catch (_: Throwable) {
                fallback
            }
        }

        val manufacturer = str("manufacturer", "KaijinLab")
        val product = str("product", "GadgetFS")
        val serial = str("serialNumber", "GadgetFS:${id.take(12)}")
        val vendorId = intHexOrDec("vendorId", 0x1d6b)
        val productId = intHexOrDec(
            "productId",
            when (roleType.lowercase(Locale.US)) {
                "keyboard" -> 0x0104
                "mouse" -> 0x0104
                else -> 0x0104
            }
        )
        val maxPower = intHexOrDec("maxPowerMa", 250)

        return Configfs.ParsedProfile(
            id = id,
            name = name,
            roleType = roleType,
            manufacturer = manufacturer,
            product = product,
            serialNumber = serial,
            vendorId = vendorId,
            productId = productId,
            maxPowerMa = maxPower,
        )
    }

    private fun keyboardReport(mods: Int, key: Int): ByteArray {
        return byteArrayOf(
            (mods and 0xFF).toByte(),
            0x00,
            (key and 0xFF).toByte(),
            0x00, 0x00, 0x00, 0x00, 0x00
        )
    }

    private fun releaseAllKeysBestEffort() {
        val path = prefs.activeKeyboardDev ?: return
        val up = keyboardReport(0x00, 0x00)
        try {
            writeKeyboardReportsWithDelays(
                path,
                reports = listOf(up, up, up),
                delaysUs = listOf(0, 0)
            )
            log.log("kbd", "Sent all-keys-up before teardown")
        } catch (t: Throwable) {
            log.logError("kbd", "Failed to send all-keys-up: ${t.message}")
        }
    }

    private fun writeKeyboardTap(path: String, mods: Int, key: Int, downHoldUs: Int) {
        val up = keyboardReport(0x00, 0x00)
        val down = keyboardReport(mods, key)
        // Sequence: up -> down -> (hold) -> up
        writeKeyboardReportsWithDelays(
            path,
            reports = listOf(up, down, up),
            delaysUs = listOf(interKeyDelayUs, downHoldUs)
        )
    }

    private fun typeText(path: String, text: String) {
        var idx = 0
        while (idx < text.length) {
            val end = min(text.length, idx + maxTypedCharsPerBatch)
            val chunk = text.substring(idx, end)
            typeTextChunk(path, chunk)
            idx = end
        }
    }

    private fun typeTextChunk(path: String, chunk: String) {
        val strokes = ArrayList<HidSpec.KeyStroke>(chunk.length)
        for (ch in chunk) {
            val s = HidSpec.strokeForChar(ch)
            if (s != null) {
                strokes.add(s)
            } else {
                val c = if (ch.code in 32..126) ch.toString() else "U+${ch.code.toString(16)}"
                log.log("kbd", "Skipping unsupported char: $c")
            }
        }
        if (strokes.isEmpty()) return

        val reports = ArrayList<ByteArray>(1 + strokes.size * 2)
        val delays = ArrayList<Int>(strokes.size * 2)

        // Start from "all keys up"
        reports.add(keyboardReport(0x00, 0x00))

        // Then for each keystroke: DOWN -> UP
        for (stroke in strokes) {
            reports.add(keyboardReport(stroke.mods, stroke.key))
            reports.add(keyboardReport(0x00, 0x00))
        }

        // Delay list is (reports.size - 1)
        for (i in 0 until (reports.size - 1)) {
            val isDownReport = (i % 2 == 1) // 1,3,5... are DOWN
            delays.add(if (isDownReport) keyDownHoldUs else interKeyDelayUs)
        }

        writeKeyboardReportsWithDelays(path, reports, delays)
    }

    /**
     * Writes multiple HID keyboard reports in a single root exec.
     * With the persistent session, FD 3 may already be open (fast path).
     * If FD 3 is not open in the child shell, we open it locally for this call.
     */
    private fun writeKeyboardReportsWithDelays(path: String, reports: List<ByteArray>, delaysUs: List<Int>) {
        if (reports.isEmpty()) return

        val useDirect = root.isKeyboardWriterReady()

        val usleepSnippet = """
          USLP=""
          if command -v toybox >/dev/null 2>&1 && toybox usleep 1 >/dev/null 2>&1; then
            USLP="toybox usleep"
          elif command -v usleep >/dev/null 2>&1; then
            USLP="usleep"
          elif command -v busybox >/dev/null 2>&1 && busybox usleep 1 >/dev/null 2>&1; then
            USLP="busybox usleep"
          fi
        """.trimIndent()

        fun toHexEsc(bytes: ByteArray): String {
            return bytes.joinToString(separator = "") { b ->
                val v = b.toInt() and 0xFF
                String.format(Locale.US, "\\x%02x", v)
            }
        }

        val writes = StringBuilder()
        for (i in reports.indices) {
            val hex = toHexEsc(reports[i])
            writes.append("printf '%b' '").append(hex).append("' >&").append(HID_KBD_FD).append("\n")
            if (i != reports.lastIndex) {
                val d = delaysUs.getOrNull(i) ?: 0
                if (d > 0) {
                    writes.append(
                        """
                          if [ -n "${'$'}USLP" ]; then
                            ${'$'}USLP $d
                          else
                            sleep 0.01
                          fi
                        """.trimIndent()
                    ).append("\n")
                }
            }
        }

        val openLocal = if (useDirect) "" else "exec $HID_KBD_FD> \"${'$'}P\""
        val closeLocal = if (useDirect) "" else "(exec $HID_KBD_FD>&-) 2>/dev/null || true"

        val script = """
          set -e
          P=${shQuote(path)}
          $usleepSnippet
          $openLocal

          $writes

          $closeLocal
        """.trimIndent()

        val r = if (useDirect) root.execDirect(script, timeoutSec = 8) else root.exec(script, timeoutSec = 8)
        if (!r.ok) {
          val detail = r.stderr.trim().ifEmpty { r.stdout.trim() }
          throw IllegalStateException(
            "Failed to write keyboard reports to $path (exit=${r.exitCode}). " +
              (detail.ifEmpty { "no stderr/stdout" })
          )
        }
    }

    /**
     * Mouse report write:
     * - Fast path: persistent FD 4 (no exec, no markers, no open/close)
     * - Fallback: one-shot redirection to path
     */
    private fun writeMouseReport(path: String, bytes: ByteArray) {
        if (root.isMouseWriterReady()) {
            try {
                root.writeMouseFast(bytes)
                return
            } catch (t: Throwable) {
                log.logError("hid", "Mouse fast-writer failed; fallback to slow path: ${t.message}")
            }
        }

        // Slow fallback: open/write/close within one exec
        val hexEsc = bytes.joinToString(separator = "") { b ->
            val v = b.toInt() and 0xFF
            String.format(Locale.US, "\\x%02x", v)
        }
        val script = "printf '%b' '$hexEsc' > ${shQuote(path)}"
        val r = root.exec(script, timeoutSec = 5)
        if (!r.ok) {
            throw IllegalStateException("Failed to write HID report to $path (exit=${r.exitCode})")
        }
    }

    private fun shQuote(s: String): String = "'" + s.replace("'", "'\\''") + "'"

    /**
     * Returns true if configfs USB gadget is available.
     *
     * On many Android devices configfs is mounted at /config (not /sys/kernel/config).
     * Some ROMs do not mount configfs automatically; we try a best-effort mount.
     */
    private fun ensureConfigfsAvailable(): Boolean {
        val fast = root.exec("test -d /config/usb_gadget || test -d /sys/kernel/config/usb_gadget")
        if (fast.ok) return true

        val script = """
            if [ -d /config ] && [ ! -d /config/usb_gadget ]; then
              mount | grep -q " /config " || mount -t configfs none /config 2>/dev/null
            fi
            if [ -d /sys/kernel ] && [ ! -d /sys/kernel/config/usb_gadget ]; then
              mkdir -p /sys/kernel/config 2>/dev/null
              mount | grep -q " /sys/kernel/config " || mount -t configfs none /sys/kernel/config 2>/dev/null
            fi
            test -d /config/usb_gadget || test -d /sys/kernel/config/usb_gadget
        """.trimIndent()

        val mounted = root.exec(script, timeoutSec = 10)
        return mounted.ok
    }

    private fun isGadgetDirBound(gadgetDir: String): Boolean {
        val safe = gadgetDir.replace("\"", "").replace("'", "")
        val script = """
            CFGBASE=/config/usb_gadget
            [ -d "$${'$'}CFGBASE" ] || CFGBASE=/sys/kernel/config/usb_gadget
            test -f "$${'$'}CFGBASE/$safe/UDC" && test -s "$${'$'}CFGBASE/$safe/UDC"
        """.trimIndent()
        val r = root.exec(script, timeoutSec = 5)
        return r.ok
    }

    private fun startForeground(title: String) {
        val intent = Intent(context, GadgetForegroundService::class.java).apply {
            putExtra(GadgetForegroundService.EXTRA_TITLE, title)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(context, intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopForeground() {
        try {
            context.stopService(Intent(context, GadgetForegroundService::class.java))
        } catch (_: Throwable) {
        }
    }

    private fun setState(state: String, activeProfileId: String?, message: String?) {
        val current = statusRef.get()
        val next = current.copy(state = state, activeProfileId = activeProfileId, message = message)
        statusRef.set(next)
        emit(next)
    }

    private fun setError(message: String) {
        val current = statusRef.get()
        val next = current.copy(state = "ERROR", message = message)
        statusRef.set(next)
        emit(next)
        log.logError("gadget", message)
    }

    private data class UsbSnapshot(
        val sysUsbConfig: String?,
        val sysUsbState: String?,
        val sysUsbConfigfs: String?,
        val persistSysUsbConfig: String?,
        val boundGadgetsRaw: String?,
    )

    private fun captureUsbSnapshot(): UsbSnapshot {
        fun getProp(name: String): String? {
            val r = root.exec("getprop $name 2>/dev/null || true", timeoutSec = 5)
            val v = r.stdout.lineSequence().firstOrNull()?.trim()?.trim('\r')
            return v?.takeIf { it.isNotBlank() }
        }

        val bound = root.exec(buildListBoundGadgetsScript(), timeoutSec = 8).stdout
            .lineSequence()
            .map { it.trim().trim('\r') }
            .filter { it.isNotBlank() }
            .joinToString("\n")
            .ifBlank { null }

        val snap = UsbSnapshot(
            sysUsbConfig = getProp("sys.usb.config"),
            sysUsbState = getProp("sys.usb.state"),
            sysUsbConfigfs = getProp("sys.usb.configfs"),
            persistSysUsbConfig = getProp("persist.sys.usb.config"),
            boundGadgetsRaw = bound,
        )

        log.log(
            "usb",
            "Snapshot sys.usb.config=${snap.sysUsbConfig ?: "?"} sys.usb.state=${snap.sysUsbState ?: "?"} " +
                "sys.usb.configfs=${snap.sysUsbConfigfs ?: "?"} persist.sys.usb.config=${snap.persistSysUsbConfig ?: "?"} " +
                "bound=${if (snap.boundGadgetsRaw.isNullOrBlank()) "none" else "yes"}"
        )
        return snap
    }

    private fun buildListBoundGadgetsScript(): String {
        return """
            CFGBASE="/config/usb_gadget"
            if [ ! -d "$${'$'}CFGBASE" ]; then
              CFGBASE="/sys/kernel/config/usb_gadget"
            fi
            if [ ! -d "$${'$'}CFGBASE" ]; then
              exit 0
            fi
            for g in "$${'$'}CFGBASE"/*; do
              [ -d "$${'$'}g" ] || continue
              if [ -f "$${'$'}g/UDC" ]; then
                udc=$${'$'}(cat "$${'$'}g/UDC" 2>/dev/null | tr -d '\r')
                if [ -n "$${'$'}udc" ]; then
                  echo "$${'$'}(basename "$${'$'}g"):$${'$'}udc"
                fi
              fi
            done
            exit 0
        """.trimIndent()
    }

    private fun restoreUsbSnapshotBestEffort(reason: String) {
        val prevConfig = prefs.prevSysUsbConfig?.trim()?.takeIf { it.isNotEmpty() }
        val prevConfigfs = prefs.prevSysUsbConfigfs?.trim()?.takeIf { it.isNotEmpty() }
        val prevPersist = prefs.prevPersistSysUsbConfig?.trim()?.takeIf { it.isNotEmpty() }
        val prevBound = prefs.prevBoundGadgets?.trim()?.takeIf { it.isNotEmpty() }

        if (prevConfig == null && prevConfigfs == null && prevPersist == null && prevBound == null) {
            log.log("usb", "No snapshot to restore ($reason)")
            return
        }

        log.log("usb", "Restoring USB snapshot ($reason) prevConfig=${prevConfig ?: "?"}")
        val script = buildRestoreUsbScript(prevConfig, prevConfigfs, prevPersist, prevBound)
        val r = root.exec(script, timeoutSec = 20)
        if (!r.ok) {
            log.logError("usb", "USB restore script returned exit=${r.exitCode}")
        } else {
            log.log("usb", "USB restore script completed")
        }
    }

    private fun buildRestoreUsbScript(
        prevConfig: String?,
        prevConfigfs: String?,
        prevPersist: String?,
        prevBoundRaw: String?
    ): String {
        val cfg = prevConfig ?: ""
        val cfgfs = prevConfigfs ?: ""
        val pcfg = prevPersist ?: ""

        val boundLines = (prevBoundRaw ?: "")
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toList()

        val rebindBlock = if (boundLines.isNotEmpty()) {
            val entries = boundLines.joinToString("\n") { it }
            """
            CFGBASE="/config/usb_gadget"
            if [ ! -d "$${'$'}CFGBASE" ]; then
              CFGBASE="/sys/kernel/config/usb_gadget"
            fi
            if [ -d "$${'$'}CFGBASE" ]; then
              while IFS= read -r line; do
                g=$${'$'}(echo "$${'$'}line" | cut -d: -f1)
                u=$${'$'}(echo "$${'$'}line" | cut -d: -f2-)
                if [ -n "$${'$'}g" ] && [ -n "$${'$'}u" ] && [ -f "$${'$'}CFGBASE/$${'$'}g/UDC" ]; then
                  (echo "$${'$'}u" > "$${'$'}CFGBASE/$${'$'}g/UDC") 2>/dev/null || true
                fi
              done <<'EOF_BOUND'
            $entries
            EOF_BOUND
            fi
            """.trimIndent()
        } else {
            "true"
        }

        return """
            set -e

            PREV_CFG=${shQuote(cfg)}
            PREV_CFGFS=${shQuote(cfgfs)}
            PREV_PERSIST=${shQuote(pcfg)}

            if [ -n "$${'$'}PREV_CFGFS" ]; then
              setprop sys.usb.configfs "$${'$'}PREV_CFGFS" 2>/dev/null || true
            fi

            if [ -n "$${'$'}PREV_PERSIST" ]; then
              setprop persist.sys.usb.config "$${'$'}PREV_PERSIST" 2>/dev/null || true
            fi

            if [ -n "$${'$'}PREV_CFG" ]; then
              setprop sys.usb.config none 2>/dev/null || true
              sleep 0.1
              setprop sys.usb.config "$${'$'}PREV_CFG" 2>/dev/null || true

              i=0
              while [ $${'$'}i -lt 80 ]; do
                cur=$${'$'}(getprop sys.usb.state 2>/dev/null | tr -d '\r')
                if [ "$${'$'}cur" = "$${'$'}PREV_CFG" ]; then
                  break
                fi
                sleep 0.1
                i=$${'$'}((i+1))
              done
            fi

            $rebindBlock

            exit 0
        """.trimIndent()
    }

    /* ---- Kernel config diagnostics (unchanged) ---- */

    private fun kernelVersionBase(unameR: String): String {
        val trimmed = unameR.trim()
        if (trimmed.isEmpty()) return "Unknown"
        val first = trimmed.split(Regex("[\\s\\-\\+]")).firstOrNull()?.trim()
        return first?.takeIf { it.isNotEmpty() } ?: trimmed
    }

    private fun readKernelUnameR(): String? {
        val r = root.exec("uname -r 2>/dev/null || true", timeoutSec = 5)
        val v = r.stdout.lineSequence().firstOrNull()?.trim()?.trim('\r')
        return v?.takeIf { it.isNotBlank() }
    }

    private fun readKernelConfigConfigfsLines(): String? {
        val script = """
            if [ -r /proc/config.gz ]; then
              ( toybox gzip -dc /proc/config.gz 2>/dev/null \
                || toybox gunzip -c /proc/config.gz 2>/dev/null \
                || gunzip -c /proc/config.gz 2>/dev/null \
                || busybox zcat /proc/config.gz 2>/dev/null \
                || zcat /proc/config.gz 2>/dev/null ) \
                | grep -i configfs \
                | sed 's/^# //; s/ is not set/=NOT_SET/' || true
              exit 0
            fi

            CFG="/boot/config-`uname -r 2>/dev/null`"
            if [ -r "$${'$'}CFG" ]; then
              cat "$${'$'}CFG" 2>/dev/null \
                | grep -i configfs \
                | sed 's/^# //; s/ is not set/=NOT_SET/' || true
              exit 0
            fi

            echo "__NO_KERNEL_CONFIG__"
        """.trimIndent()

        val r = root.exec(script, timeoutSec = 15)
        val out = r.stdout.trim()
        if (out.isEmpty()) return null
        if (out.contains("__NO_KERNEL_CONFIG__")) return null
        return out
    }

    private fun readKernelConfigFlags(keys: List<String>): Map<String, String> {
        val uniqueKeys = LinkedHashSet(keys)
        val out = LinkedHashMap<String, String>()
        for (k in uniqueKeys) out[k] = "Unknown"
        val raw = readKernelConfigConfigfsLines() ?: return out

        val parsed = HashMap<String, String>(512)
        for (line in raw.lineSequence()) {
            val l = line.trim()
            if (l.isEmpty()) continue
            val idx = l.indexOf('=')
            if (idx <= 0) continue
            val name = l.substring(0, idx).trim()
            val value = l.substring(idx + 1).trim()
            if (name.startsWith("CONFIG_")) parsed[name] = value
        }

        for (k in uniqueKeys) {
            val v = parsed[k] ?: continue
            out[k] = when (v.lowercase(Locale.US)) {
                "y" -> "Yes"
                "m" -> "Module"
                "not_set" -> "Not set"
                "n" -> "No"
                else -> v
            }
        }
        return out
    }

    private fun collectKernelConfigInfo(): Map<String, Any?> {
        val keys = listOf(
            "CONFIG_CONFIGFS_FS",
            "CONFIG_IIO_CONFIGFS",
            "CONFIG_PCI_ENDPOINT_CONFIGFS",
            "CONFIG_USB_CONFIGFS",
            "CONFIG_USB_CONFIGFS_ACM",
            "CONFIG_USB_CONFIGFS_ECM",
            "CONFIG_USB_CONFIGFS_ECM_SUBSET",
            "CONFIG_USB_CONFIGFS_EEM",
            "CONFIG_USB_CONFIGFS_F_ACC",
            "CONFIG_USB_CONFIGFS_F_AUDIO_SRC",
            "CONFIG_USB_CONFIGFS_F_CCID",
            "CONFIG_USB_CONFIGFS_F_CDEV",
            "CONFIG_USB_CONFIGFS_F_DIAG",
            "CONFIG_USB_CONFIGFS_F_EMS",
            "CONFIG_USB_CONFIGFS_F_FS",
            "CONFIG_USB_CONFIGFS_F_GSI",
            "CONFIG_USB_CONFIGFS_F_HID",
            "CONFIG_USB_CONFIGFS_F_LB_SS",
            "CONFIG_USB_CONFIGFS_F_MIDI",
            "CONFIG_USB_CONFIGFS_F_PRINTER",
            "CONFIG_USB_CONFIGFS_F_QDSS",
            "CONFIG_USB_CONFIGFS_F_UAC1",
            "CONFIG_USB_CONFIGFS_F_UAC1_LEGACY",
            "CONFIG_USB_CONFIGFS_F_UAC2",
            "CONFIG_USB_CONFIGFS_F_UVC",
            "CONFIG_USB_CONFIGFS_MASS_STORAGE",
            "CONFIG_USB_CONFIGFS_NCM",
            "CONFIG_USB_CONFIGFS_OBEX",
            "CONFIG_USB_CONFIGFS_RNDIS",
            "CONFIG_USB_CONFIGFS_SERIAL",
            "CONFIG_USB_CONFIGFS_UEVENT",
        )

        val unameR = readKernelUnameR()
        val kver = if (!unameR.isNullOrBlank()) kernelVersionBase(unameR) else "Unknown"
        val flags = if (checkRoot()) readKernelConfigFlags(keys) else keys.associateWith { "Unknown" }

        val out = LinkedHashMap<String, Any?>()
        out["KERNEL_VERSION"] = kver
        for ((k, v) in flags) out[k] = v
        return out
    }

    fun getDiagnostics(): Map<String, Any?> {
        val out = LinkedHashMap<String, Any?>()
        out["timestampMs"] = System.currentTimeMillis()
        out["status"] = getStatusSnapshot().toMap()

        try {
            out["kernelConfig"] = collectKernelConfigInfo()
        } catch (t: Throwable) {
            out["kernelConfigError"] = t.toString()
        }

        try {
            val raw = readKernelConfigConfigfsLines()
            out["kernelConfigRawFirstLines"] = raw?.lineSequence()?.take(60)?.toList() ?: emptyList<String>()
        } catch (t: Throwable) {
            out["kernelConfigRawError"] = t.toString()
        }

        try {
            out["rootId"] = root.exec("id").stdout.trim()
        } catch (t: Throwable) {
            out["rootIdError"] = t.toString()
        }

        try {
            out["sysUsbController"] = root.exec("getprop sys.usb.controller").stdout.trim()
        } catch (t: Throwable) {
            out["sysUsbControllerError"] = t.toString()
        }

        try {
            out["udcList"] = listUdcs()
        } catch (t: Throwable) {
            out["udcListError"] = t.toString()
        }

        try {
            val bases = listOf("/config/usb_gadget", "/sys/kernel/config/usb_gadget")
            val existing = ArrayList<String>()
            for (b in bases) {
                val ec = root.exec("test -d $b").exitCode
                if (ec == 0) existing.add(b)
            }
            out["configfsBases"] = existing
            out["configfsMount"] = root.exec("mount | grep -i configfs || true").stdout.trim()
        } catch (t: Throwable) {
            out["configfsError"] = t.toString()
        }

        try {
            out["paths"] = mapOf(
                "config" to root.exec("ls -ld /config 2>/dev/null || echo MISSING").stdout.trim(),
                "sysKernelConfig" to root.exec("ls -ld /sys/kernel/config 2>/dev/null || echo MISSING").stdout.trim(),
                "sysClassUdc" to root.exec("ls -ld /sys/class/udc 2>/dev/null || echo MISSING").stdout.trim(),
            )
        } catch (t: Throwable) {
            out["pathsError"] = t.toString()
        }

        try {
            val gadgets = root.exec("ls -1 /config/usb_gadget 2>/dev/null || true").stdout
                .split("\n")
                .map { it.trim() }
                .filter { it.isNotEmpty() }
            out["existingGadgetsInConfig"] = gadgets
        } catch (t: Throwable) {
            out["existingGadgetsError"] = t.toString()
        }

        return out
    }

    private fun emit(status: Status) {
        val map = status.toMap()
        main.post {
            try {
                sinkRef.get()?.success(map)
            } catch (_: Throwable) {
            }
        }
    }
}
