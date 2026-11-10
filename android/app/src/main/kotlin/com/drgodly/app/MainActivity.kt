package com.drgodly.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (a ComponentActivity) is required by the `health`
// plugin: it registers the Health Connect permission launcher via
// registerForActivityResult, which plain FlutterActivity does not support.
//
// The old cookie-reading and calendar MethodChannels were removed: login now
// runs in Custom Tabs (no WebView cookies to read) and nothing in Dart called
// the calendar channel.
class MainActivity : FlutterFragmentActivity()
