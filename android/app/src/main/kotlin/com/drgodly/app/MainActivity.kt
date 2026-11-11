package com.drgodly.app

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

// FlutterFragmentActivity (a ComponentActivity) is required by the `health`
// plugin: it registers the Health Connect permission launcher via
// registerForActivityResult, which plain FlutterActivity does not support.
class MainActivity : FlutterFragmentActivity() {

    private val okHttpClient: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .followRedirects(true)
            .followSslRedirects(true)
            .build()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The FHIR backend needs the Better Auth JWT, which IAM only issues
        // for a session cookie (GET /api/auth/token). Sign-in runs in an
        // in-app WebView, so the cookie lands in this app's WebView cookie
        // store. This returns ONLY the IAM session cookie, never the rest of
        // the cookie jar. Temporary: see docs/backend_request_option_b.md.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IAM_SESSION_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getSessionCookie") {
                    try {
                        val cookieManager = CookieManager.getInstance()
                        cookieManager.flush()

                        fun findSession(): String? {
                            val urls = listOf("https://iam.drgodly.com", "https://drgodly.com", "iam.drgodly.com")
                            for (url in urls) {
                                val raw = cookieManager.getCookie(url)
                                val found = raw?.split(";")?.map { it.trim() }?.firstOrNull { cookie ->
                                    SESSION_COOKIE_NAMES.any { cookie.startsWith("$it=") }
                                }
                                if (found != null) return found
                            }
                            return null
                        }

                        var session = findSession()
                        if (session == null) {
                            try { Thread.sleep(150) } catch (_: Exception) {}
                            cookieManager.flush()
                            session = findSession()
                        }
                        android.util.Log.i("DrGodly", "getSessionCookie returned: ${if (session != null) "found (${session.substring(0, Math.min(session.length, 30))}...)" else "null"}")
                        result.success(session)
                    } catch (e: Exception) {
                        android.util.Log.e("DrGodly", "getSessionCookie failed", e)
                        result.error("COOKIE_ERROR", "Could not read the sign-in session", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Native HTTP Channel (uses OkHttp with HTTP/2 and HPACK compression)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_HTTP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "request") {
                    Thread {
                        try {
                            val urlStr = call.argument<String>("url")!!
                            val method = call.argument<String>("method") ?: "GET"
                            val headersMap = call.argument<Map<String, String>>("headers") ?: emptyMap()
                            val bodyBytes = call.argument<ByteArray>("body")

                            val reqBuilder = Request.Builder().url(urlStr)
                            for ((k, v) in headersMap) {
                                reqBuilder.header(k, v)
                            }

                            val contentType = headersMap.entries.firstOrNull {
                                it.key.equals("content-type", ignoreCase = true)
                            }?.value?.toMediaTypeOrNull()

                            val requestBody = if (method in listOf("POST", "PUT", "PATCH")) {
                                bodyBytes?.toRequestBody(contentType) ?: ByteArray(0).toRequestBody(contentType)
                            } else {
                                null
                            }

                            reqBuilder.method(method, requestBody)
                            val request = reqBuilder.build()

                            okHttpClient.newCall(request).execute().use { response ->
                                val statusCode = response.code
                                val statusMessage = response.message
                                val respHeaders = mutableMapOf<String, List<String>>()
                                for (name in response.headers.names()) {
                                    respHeaders[name] = response.headers.values(name)
                                }
                                val responseBytes = response.body?.bytes() ?: ByteArray(0)
                                val protocol = response.protocol.toString()
                                android.util.Log.i("DrGodlyHttp", "[$protocol] $method $urlStr -> $statusCode (bytes: ${responseBytes.size})")

                                runOnUiThread {
                                    result.success(mapOf(
                                        "statusCode" to statusCode,
                                        "statusMessage" to statusMessage,
                                        "headers" to respHeaders,
                                        "data" to responseBytes,
                                        "protocol" to protocol
                                    ))
                                }
                            }
                        } catch (e: Exception) {
                            android.util.Log.e("DrGodlyHttp", "Native HTTP call failed", e)
                            runOnUiThread {
                                result.error("HTTP_EXCEPTION", e.message ?: e.toString(), null)
                            }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }

    companion object {
        private const val IAM_SESSION_CHANNEL = "com.drgodly.app/iam_session"
        private const val NATIVE_HTTP_CHANNEL = "com.drgodly.app/native_http"
        private const val IAM_ORIGIN = "https://iam.drgodly.com"
        private val SESSION_COOKIE_NAMES = listOf(
            "__Secure-better-auth.session_token",
            "better-auth.session_token",
        )
    }
}
