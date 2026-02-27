package com.example.laundry_app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // [FIX] Enable edge-to-edge support to satisfy Play Store requirements for modern Android
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
