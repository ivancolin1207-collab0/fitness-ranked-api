package com.example.apexmetrix_mobile

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "apexmetrix/system"
    private var methodChannel: MethodChannel? = null
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingDeepLink = intent?.dataString

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openExternalUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "URL vacía", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val viewIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(viewIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("LAUNCH_FAILED", e.message, null)
                    }
                }
                "openHealthConnectSettings" -> {
                    try {
                        val hcIntent = if (Build.VERSION.SDK_INT >= 34) {
                            Intent("android.health.connect.action.MANAGE_HEALTH_PERMISSIONS").apply {
                                putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                            }
                        } else {
                            Intent("androidx.health.ACTION_MANAGE_HEALTH_PERMISSIONS").apply {
                                putExtra("android.intent.extra.PACKAGE_NAME", packageName)
                            }
                        }
                        hcIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(hcIntent)
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            val fallback = Intent("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        } catch (inner: Exception) {
                            result.error("HC_SETTINGS_FAILED", inner.message, null)
                        }
                    }
                }
                "consumeInitialDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val dataStr = intent.dataString
        if (!dataStr.isNullOrBlank()) {
            pendingDeepLink = dataStr
            methodChannel?.invokeMethod("onDeepLink", dataStr)
        }
    }
}
