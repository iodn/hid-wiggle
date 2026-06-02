package org.kaijinlab.hid_wiggle

import java.util.Locale

object HidSpec {
    /* Standard boot mouse with wheel: buttons + X + Y + Wheel */
    val MOUSE_REPORT_DESC: ByteArray = byteArrayOf(
        0x05, 0x01, /* Usage Page (Generic Desktop) */
        0x09, 0x02, /* Usage (Mouse) */
        0xA1.toByte(), 0x01, /* Collection (Application) */
        0x09, 0x01, /* Usage (Pointer) */
        0xA1.toByte(), 0x00, /* Collection (Physical) */
        0x05, 0x09, /* Usage Page (Button) */
        0x19, 0x01, /* Usage Minimum (1) */
        0x29, 0x03, /* Usage Maximum (3) */
        0x15, 0x00, /* Logical Minimum (0) */
        0x25, 0x01, /* Logical Maximum (1) */
        0x95.toByte(), 0x03, /* Report Count (3) */
        0x75, 0x01, /* Report Size (1) */
        0x81.toByte(), 0x02, /* Input (Data,Var,Abs) */
        0x95.toByte(), 0x01, /* Report Count (1) */
        0x75, 0x05, /* Report Size (5) */
        0x81.toByte(), 0x03, /* Input (Const,Var,Abs) Padding */
        0x05, 0x01, /* Usage Page (Generic Desktop) */
        0x09, 0x30, /* Usage (X) */
        0x09, 0x31, /* Usage (Y) */
        0x09, 0x38, /* Usage (Wheel) */
        0x15, 0x81.toByte(), /* Logical Minimum (-127) */
        0x25, 0x7F, /* Logical Maximum (127) */
        0x75, 0x08, /* Report Size (8) */
        0x95.toByte(), 0x03, /* Report Count (3) */
        0x81.toByte(), 0x06, /* Input (Data,Var,Rel) */
        0xC0.toByte(), /* End Collection */
        0xC0.toByte(), /* End Collection */
    )

    /* Standard boot keyboard: 8-byte report */
    val KEYBOARD_REPORT_DESC: ByteArray = byteArrayOf(
        0x05, 0x01, /* Usage Page (Generic Desktop) */
        0x09, 0x06, /* Usage (Keyboard) */
        0xA1.toByte(), 0x01, /* Collection (Application) */
        0x05, 0x07, /* Usage Page (Key Codes) */
        0x19, 0xE0.toByte(), /* Usage Minimum (224) */
        0x29, 0xE7.toByte(), /* Usage Maximum (231) */
        0x15, 0x00, /* Logical Minimum (0) */
        0x25, 0x01, /* Logical Maximum (1) */
        0x75, 0x01, /* Report Size (1) */
        0x95.toByte(), 0x08, /* Report Count (8) */
        0x81.toByte(), 0x02, /* Input (Data,Var,Abs) */
        0x95.toByte(), 0x01, /* Report Count (1) */
        0x75, 0x08, /* Report Size (8) */
        0x81.toByte(), 0x03, /* Input (Const,Var,Abs) */
        0x95.toByte(), 0x05, /* Report Count (5) */
        0x75, 0x01, /* Report Size (1) */
        0x05, 0x08, /* Usage Page (LEDs) */
        0x19, 0x01, /* Usage Minimum (1) */
        0x29, 0x05, /* Usage Maximum (5) */
        0x91.toByte(), 0x02, /* Output (Data,Var,Abs) */
        0x95.toByte(), 0x01, /* Report Count (1) */
        0x75, 0x03, /* Report Size (3) */
        0x91.toByte(), 0x03, /* Output (Const,Var,Abs) */
        0x95.toByte(), 0x06, /* Report Count (6) */
        0x75, 0x08, /* Report Size (8) */
        0x15, 0x00, /* Logical Minimum (0) */
        0x25, 0x65, /* Logical Maximum (101) */
        0x05, 0x07, /* Usage Page (Key Codes) */
        0x19, 0x00, /* Usage Minimum (0) */
        0x29, 0x65, /* Usage Maximum (101) */
        0x81.toByte(), 0x00, /* Input (Data,Array) */
        0xC0.toByte(), /* End Collection */
    )

    data class KeyStroke(val mods: Int, val key: Int)

    private const val MOD_LSHIFT = 0x02

    /**
     * Existing API: maps a *named* key label to a HID usage id (no modifiers).
     * Keep this for single-key actions (ENTER, TAB, BACKSPACE, etc).
     */
    fun keyCodeFor(label: String): Int? {
        val k = label.trim().uppercase(Locale.US)
        if (k.length == 1) {
            val c = k[0]
            if (c in 'A'..'Z') {
                return 0x04 + (c.code - 'A'.code)
            }
            if (c in '0'..'9') {
                return when (c) {
                    '1' -> 0x1E
                    '2' -> 0x1F
                    '3' -> 0x20
                    '4' -> 0x21
                    '5' -> 0x22
                    '6' -> 0x23
                    '7' -> 0x24
                    '8' -> 0x25
                    '9' -> 0x26
                    '0' -> 0x27
                    else -> null
                }
            }
        }
        return when (k) {
            "ENTER" -> 0x28
            "ESC", "ESCAPE" -> 0x29
            "BACKSPACE" -> 0x2A
            "TAB" -> 0x2B
            "SPACE" -> 0x2C
            "DELETE", "DEL" -> 0x4C
            "UP" -> 0x52
            "DOWN" -> 0x51
            "LEFT" -> 0x50
            "RIGHT" -> 0x4F
            else -> null
        }
    }

    /**
     * New: best-effort US-QWERTY mapping for typing ASCII-ish text.
     * Returns (modifierByte, keyUsage).
     *
     * Notes:
     * - This is not IME/Unicode. It is deliberately limited to common ASCII.
     * - Unsupported chars return null (caller can skip/log).
     */
    fun strokeForChar(ch: Char): KeyStroke? {
        // Control / whitespace
        when (ch) {
            ' ' -> return KeyStroke(0, 0x2C)      // SPACE
            '\n', '\r' -> return KeyStroke(0, 0x28) // ENTER
            '\t' -> return KeyStroke(0, 0x2B)     // TAB
            '\b' -> return KeyStroke(0, 0x2A)     // BACKSPACE
            '\u007F' -> return KeyStroke(0, 0x4C) // DEL
        }

        // Letters
        if (ch in 'a'..'z') {
            val key = 0x04 + (ch.code - 'a'.code)
            return KeyStroke(0, key)
        }
        if (ch in 'A'..'Z') {
            val key = 0x04 + (ch.code - 'A'.code)
            return KeyStroke(MOD_LSHIFT, key)
        }

        // Digits and shifted digits
        when (ch) {
            '1' -> return KeyStroke(0, 0x1E)
            '2' -> return KeyStroke(0, 0x1F)
            '3' -> return KeyStroke(0, 0x20)
            '4' -> return KeyStroke(0, 0x21)
            '5' -> return KeyStroke(0, 0x22)
            '6' -> return KeyStroke(0, 0x23)
            '7' -> return KeyStroke(0, 0x24)
            '8' -> return KeyStroke(0, 0x25)
            '9' -> return KeyStroke(0, 0x26)
            '0' -> return KeyStroke(0, 0x27)

            '!' -> return KeyStroke(MOD_LSHIFT, 0x1E)
            '@' -> return KeyStroke(MOD_LSHIFT, 0x1F)
            '#' -> return KeyStroke(MOD_LSHIFT, 0x20)
            '$' -> return KeyStroke(MOD_LSHIFT, 0x21)
            '%' -> return KeyStroke(MOD_LSHIFT, 0x22)
            '^' -> return KeyStroke(MOD_LSHIFT, 0x23)
            '&' -> return KeyStroke(MOD_LSHIFT, 0x24)
            '*' -> return KeyStroke(MOD_LSHIFT, 0x25)
            '(' -> return KeyStroke(MOD_LSHIFT, 0x26)
            ')' -> return KeyStroke(MOD_LSHIFT, 0x27)
        }

        // Punctuation (US layout)
        return when (ch) {
            '-' -> KeyStroke(0, 0x2D)
            '_' -> KeyStroke(MOD_LSHIFT, 0x2D)
            '=' -> KeyStroke(0, 0x2E)
            '+' -> KeyStroke(MOD_LSHIFT, 0x2E)

            '[' -> KeyStroke(0, 0x2F)
            '{' -> KeyStroke(MOD_LSHIFT, 0x2F)
            ']' -> KeyStroke(0, 0x30)
            '}' -> KeyStroke(MOD_LSHIFT, 0x30)

            '\\' -> KeyStroke(0, 0x31)
            '|' -> KeyStroke(MOD_LSHIFT, 0x31)

            ';' -> KeyStroke(0, 0x33)
            ':' -> KeyStroke(MOD_LSHIFT, 0x33)

            '\'' -> KeyStroke(0, 0x34)
            '"' -> KeyStroke(MOD_LSHIFT, 0x34)

            '`' -> KeyStroke(0, 0x35)
            '~' -> KeyStroke(MOD_LSHIFT, 0x35)

            ',' -> KeyStroke(0, 0x36)
            '<' -> KeyStroke(MOD_LSHIFT, 0x36)

            '.' -> KeyStroke(0, 0x37)
            '>' -> KeyStroke(MOD_LSHIFT, 0x37)

            '/' -> KeyStroke(0, 0x38)
            '?' -> KeyStroke(MOD_LSHIFT, 0x38)

            else -> null
        }
    }
}
