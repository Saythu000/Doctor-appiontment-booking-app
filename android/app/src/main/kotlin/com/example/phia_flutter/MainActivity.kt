package com.example.phia_flutter

import android.content.Intent
import android.provider.CalendarContract
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CALENDAR_CHANNEL = "com.example.phia_flutter/calendar"
    private val COOKIE_CHANNEL = "com.example.phia_flutter/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "addToCalendar") {
                val title = call.argument<String>("title")
                val description = call.argument<String>("description")
                val location = call.argument<String>("location")
                val beginTime = call.argument<Long>("beginTime") ?: 0L
                val endTime = call.argument<Long>("endTime") ?: 0L

                try {
                    val intent = Intent(Intent.ACTION_INSERT).apply {
                        data = CalendarContract.Events.CONTENT_URI
                        putExtra(CalendarContract.Events.TITLE, title)
                        putExtra(CalendarContract.Events.DESCRIPTION, description)
                        putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginTime)
                        putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endTime)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CALENDAR_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCookies") {
                val url = call.argument<String>("url") ?: "https://iam.drgodly.com"
                try {
                    val cookieManager = CookieManager.getInstance()
                    val cookies = cookieManager.getCookie(url)
                    result.success(cookies)
                } catch (e: Exception) {
                    result.error("COOKIE_ERROR", e.message, null)
                }
            } else if (call.method == "clearCookies") {
                try {
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.removeAllCookies { result.success(true) }
                } catch (e: Exception) {
                    result.error("COOKIE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

