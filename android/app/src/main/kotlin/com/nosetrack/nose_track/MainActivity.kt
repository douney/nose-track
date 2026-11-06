package com.nosetrack.nose_track

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.nosetrack.nose_track.tracking.TrackingRuntime

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TrackingRuntime.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        TrackingRuntime.setVisible(true)
    }

    override fun onPause() {
        TrackingRuntime.setVisible(false)
        super.onPause()
    }
}
