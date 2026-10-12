package com.soberbuddy.rider

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 12+ system splash — must run before super.onCreate.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
