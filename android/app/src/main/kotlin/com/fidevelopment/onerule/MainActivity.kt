package com.fidevelopment.onerule

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import com.fidevelopment.onerule.autofill.AutofillSecureStore
import com.fidevelopment.onerule.autofill.OneRuleAutofillService
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.system.exitProcess

class MainActivity : FlutterFragmentActivity() {
    private val autofillChannelName = "onerule/autofill_mvp"
    private val logFileName = "onerule_debug.log"
    private val maxLogBytes = 2L * 1024L * 1024L
    private val trimTargetBytes = 1536 * 1024
    private val truncateNotice =
        "[log-truncated] older lines removed to keep local ring buffer within limit.\n"
    private val autofillStore by lazy { AutofillSecureStore(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        installNativeUncaughtExceptionLogger()

        super.onCreate(savedInstanceState)

        // Allow screenshots/screen recording in DEBUG builds only.
        // Keep FLAG_SECURE on in release to protect sensitive content.
        if (BuildConfig.DEBUG) {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, autofillChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPlatformAutofillSupported" -> {
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    }

                    "isAutofillMvpEnabled" -> {
                        result.success(BuildConfig.ONERULE_AUTOFILL_MVP)
                    }

                    "openAutofillSettings" -> {
                        if (!validateAutofillAvailability(result)) return@setMethodCallHandler
                        openAutofillSettings()
                        result.success(true)
                    }

                    "isAutofillEnabled" -> {
                        if (!BuildConfig.ONERULE_AUTOFILL_MVP ||
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O
                        ) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        result.success(isOneRuleAutofillEnabled())
                    }

                    "syncAutofillCredentialSnapshot" -> {
                        if (!validateAutofillAvailability(result)) return@setMethodCallHandler
                        val payload = call.argument<String>("payload")
                        if (payload.isNullOrBlank()) {
                            result.error(
                                "INVALID_PAYLOAD",
                                "Missing credential snapshot payload.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        autofillStore.saveCredentialSnapshot(payload)
                        result.success(true)
                    }

                    "setAutofillSessionKey" -> {
                        if (!validateAutofillAvailability(result)) return@setMethodCallHandler
                        val sessionKeyBase64 = call.argument<String>("sessionKeyBase64")
                        if (sessionKeyBase64.isNullOrBlank()) {
                            result.error(
                                "INVALID_SESSION_KEY",
                                "Missing session key payload.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        autofillStore.saveSessionKey(sessionKeyBase64)
                        result.success(true)
                    }

                    "clearAutofillSessionKey" -> {
                        if (!BuildConfig.ONERULE_AUTOFILL_MVP ||
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O
                        ) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        autofillStore.clearSessionKey()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun installNativeUncaughtExceptionLogger() {
        val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                appendNativeCrash(thread, throwable)
            } catch (_: Throwable) {
                // Never crash while trying to log a crash.
            }

            if (previousHandler != null) {
                previousHandler.uncaughtException(thread, throwable)
            } else {
                android.os.Process.killProcess(android.os.Process.myPid())
                exitProcess(10)
            }
        }
    }

    private fun appendNativeCrash(thread: Thread, throwable: Throwable) {
        val logFile = getLocalLogFile()
        logFile.parentFile?.mkdirs()

        val timestamp = SimpleDateFormat(
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
            Locale.US
        ).format(Date())

        val stack = Log.getStackTraceString(throwable)
        val payload = buildString {
            append("[$timestamp] source=AndroidUncaughtException\n")
            append("thread=${sanitize(thread.name)}\n")
            append("error=${sanitize(throwable.toString())}\n")
            append("stack=${sanitize(stack)}\n")
            append("---\n")
        }

        logFile.appendText(payload)
        truncateIfNeeded(logFile)
    }

    private fun getLocalLogFile(): File {
        return File(filesDir, logFileName)
    }

    private fun truncateIfNeeded(file: File) {
        val currentSize = file.length()
        if (currentSize <= maxLogBytes) return

        val bytes = file.readBytes()
        if (bytes.size <= trimTargetBytes) return

        val trimmed = bytes.copyOfRange(bytes.size - trimTargetBytes, bytes.size)
        val prefix = truncateNotice.toByteArray(Charsets.UTF_8)
        file.writeBytes(prefix + trimmed)
    }

    private fun sanitize(input: String): String {
        var value = input

        val secretKeyPattern =
            "(password|passphrase|secret|token|pin|masterPin|backupPassphrase|cipherText|ciphertext|nonce|iv|mac|tag|salt|plaintext|decrypted|entryContent|content)"

        value = Regex(
            "$secretKeyPattern\\s*[:=]\\s*([^\\s,}\\]]+)",
            RegexOption.IGNORE_CASE
        ).replace(value) { match ->
            "${match.groupValues[1]}=[REDACTED]"
        }

        value = Regex(
            "(\"?$secretKeyPattern\"?\\s*:\\s*\")([^\"]*)(\")",
            RegexOption.IGNORE_CASE
        ).replace(value) { match ->
            "${match.groupValues[1]}[REDACTED]${match.groupValues[3]}"
        }

        value = Regex(
            "(\"?(title|username|url|category|createdDate|lastModified|id)\"?\\s*:\\s*\")([^\"]*)(\")",
            RegexOption.IGNORE_CASE
        ).replace(value) { match ->
            "${match.groupValues[1]}[REDACTED]${match.groupValues[4]}"
        }

        value = Regex(
            "\\b(title|username|url|category|createdDate|lastModified|id)\\s*[:=]\\s*([^\\s,}\\]]+)",
            RegexOption.IGNORE_CASE
        ).replace(value) { match ->
            "${match.groupValues[1]}=[REDACTED]"
        }

        value = Regex(
            "or1:v\\d+:(gcm|cbc):[A-Za-z0-9+/_\\-=:.]+",
            RegexOption.IGNORE_CASE
        ).replace(value, "[REDACTED_ENVELOPE]")

        value = Regex("[A-Za-z0-9+/_-]{64,}={0,2}")
            .replace(value, "[REDACTED_BLOB]")
        value = Regex("\\b[a-fA-F0-9]{64,}\\b")
            .replace(value, "[REDACTED_HEX]")

        return value
    }

    private fun validateAutofillAvailability(result: MethodChannel.Result): Boolean {
        if (!BuildConfig.ONERULE_AUTOFILL_MVP) {
            result.error(
                "AUTOFILL_MVP_DISABLED",
                "Autofill integration is disabled by feature flag.",
                null
            )
            return false
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error(
                "AUTOFILL_UNSUPPORTED",
                "Android Autofill requires API 26+.",
                null
            )
            return false
        }
        return true
    }

    private fun openAutofillSettings() {
        val serviceComponent = "package:$packageName/.autofill.OneRuleAutofillService"
        val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
            data = Uri.parse(serviceComponent)
        }
        startActivity(intent)
    }

    private fun isOneRuleAutofillEnabled(): Boolean {
        val expectedComponent = ComponentName(
            this,
            OneRuleAutofillService::class.java
        ).flattenToString()

        val current = Settings.Secure.getString(
            contentResolver,
            "autofill_service"
        ) ?: return false

        return current == expectedComponent || current.endsWith("/.autofill.OneRuleAutofillService")
    }
}