package com.fidevelopment.onerule

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val autofillChannelName = "onerule/autofill_mvp"

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
                        if (!BuildConfig.ONERULE_AUTOFILL_MVP) {
                            result.error(
                                "AUTOFILL_MVP_DISABLED",
                                "Autofill MVP scaffold is disabled by feature flag.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                            result.error(
                                "AUTOFILL_UNSUPPORTED",
                                "Android Autofill requires API 26+.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val serviceComponent = "package:$packageName/.autofill.OneRuleAutofillService"
                        val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                            data = Uri.parse(serviceComponent)
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
