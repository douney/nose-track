package com.nosetrack.nose_track.tracking.geolocation

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Surface
import android.view.WindowManager
import com.nosetrack.nose_track.tracking.domain.TraceRecorder
import com.nosetrack.nose_track.tracking.domain.TrackingFailure
import com.nosetrack.nose_track.tracking.domain.requireTracking
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import kotlin.math.PI

/** Mode and OS acquisition only; TrackStore owns the recording format and SQL. */
class GeolocationEngine(private val context: Context, private val recorder: TraceRecorder,
    private val queue: ExecutorService, private val visible: () -> Boolean,
    private val emit: (Map<String, Any?>) -> Unit) : LocationListener, SensorEventListener {
    private val main = Handler(Looper.getMainLooper())
    private val locations = context.getSystemService(LocationManager::class.java)
    private val sensors = context.getSystemService(SensorManager::class.java)
    private var mode = "off"
    private var acquisition = "stopped"
    private var running = false
    private var headingRunning = false
    private var issue: Map<String, Any?>? = null
    private var lastPosition: Map<String, Any?>? = null
    private var lastTimestamp = 0L
    private var requestedAt = 0L
    private var lastHeadingTime = 0L
    private var revision = 0L

    fun snapshot(): Map<String, Any?> = mapOf("state" to state(), "lastPosition" to lastPosition)
    private fun state(): Map<String, Any?> = mapOf("revision" to revision, "mode" to mode, "acquisitionStatus" to acquisition,
        "session" to recorder.session(), "issue" to issue)
    private fun publishState() { revision++; emit(mapOf("type" to "state", "data" to state())) }

    private fun onMain(action: () -> Unit) {
        val done = CountDownLatch(1)
        var error: Exception? = null
        main.post { try { action() } catch (e: Exception) { error = e } finally { done.countDown() } }
        done.await()
        error?.let { throw it }
    }

    fun setMode(next: String, target: Map<String, Any?>?) {
        requireTracking(next in setOf("off", "foreground", "tracking"), "invalidArgument", "Unknown mode")
        requireTracking((next == "tracking") == (target != null), "invalidArgument", "Invalid recording target")
        if (mode == next) {
            if (next != "tracking" || recorder.target == target) return
            throw TrackingFailure("recordingInProgress", "Stop the current recording before changing target")
        }
        if (next == "tracking" || mode == "tracking") {
            requireTracking(visible(), "foregroundRequired", "Recording transitions require the active app")
        }
        if (next != "off") {
            requireTracking(hasPermission(), "permissionDenied", "Location permission is required")
            requireTracking(locationEnabled(), "locationServicesDisabled", "Location is disabled")
        }
        if (next == "tracking") {
            TrackingService.start(context)
            try { recorder.start(target!!) }
            catch (error: Exception) { TrackingService.stop(context); throw error }
            requestedAt = System.currentTimeMillis()
        }
        val wasTracking = mode == "tracking"
        if (wasTracking) recorder.finish()
        mode = next; issue = null
        if (wasTracking) TrackingService.stop(context)
        applyAcquisition(); publishState(); emit(mapOf("type" to "journal"))
    }

    private fun hasPermission() = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
        context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun locationEnabled(): Boolean = if (Build.VERSION.SDK_INT >= 28) locations.isLocationEnabled
        else locations.isProviderEnabled(LocationManager.GPS_PROVIDER) || locations.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

    fun visibilityChanged() { applyAcquisition(); publishState() }

    private fun applyAcquisition() {
        val wanted = mode == "tracking" || (mode == "foreground" && visible())
        val headingWanted = wanted && visible()
        try {
            if (wanted != running) {
                if (wanted) {
                    requireTracking(hasPermission(), "permissionDenied", "Location permission is unavailable")
                    val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val provider = if (fine && locations.isProviderEnabled(LocationManager.GPS_PROVIDER)) LocationManager.GPS_PROVIDER
                        else LocationManager.NETWORK_PROVIDER
                    requireTracking(locations.isProviderEnabled(provider), "locationServicesDisabled", "No location provider is enabled")
                    requestedAt = System.currentTimeMillis()
                    onMain { locations.requestLocationUpdates(provider, 1000L, 0f, this, Looper.getMainLooper()) }
                    running = true; acquisition = "waitingForFix"
                } else {
                    onMain { locations.removeUpdates(this) }
                    running = false; acquisition = "stopped"
                }
            }
            if (headingWanted != headingRunning) {
                onMain {
                    if (headingWanted) {
                        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                            ?: sensors.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
                        if (sensor != null) sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI, main)
                        else emitHeading(null, null, System.currentTimeMillis())
                    } else sensors.unregisterListener(this)
                }
                headingRunning = headingWanted
            }
            if (!wanted) acquisition = "stopped"
        } catch (error: Exception) { fail(error) }
    }

    override fun onLocationChanged(location: Location) {
        if (!location.latitude.isFinite() || !location.longitude.isFinite() ||
            location.latitude !in -90.0..90.0 || location.longitude !in -180.0..180.0) return
        val fix = mapOf<String, Any?>("timestamp" to location.time,
            "latitude" to location.latitude, "longitude" to location.longitude,
            "accuracyMeters" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
            "altitudeMeters" to if (location.hasAltitude()) location.altitude else null,
            "speedMetersPerSecond" to if (location.hasSpeed()) location.speed.toDouble() else null,
            "courseDegrees" to if (location.hasBearing()) location.bearing.toDouble() else null)
        queue.execute {
            val time = (fix["timestamp"] as Number).toLong()
            if (!running || time < requestedAt || time - lastTimestamp < 1000) return@execute
            try {
                if (mode == "tracking" && recorder.append(fix) == null) return@execute
                lastTimestamp = time; lastPosition = fix; acquisition = "receiving"; issue = null
                emit(mapOf("type" to "position", "data" to fix))
                if (mode == "tracking") emit(mapOf("type" to "journal"))
                publishState()
            } catch (error: Exception) { fail(error) }
        }
    }

    override fun onProviderDisabled(provider: String) {
        queue.execute {
            onMain { locations.removeUpdates(this) }; running = false
            applyAcquisition(); publishState()
        }
    }
    override fun onProviderEnabled(provider: String) {
        queue.execute { applyAcquisition(); publishState() }
    }
    @Deprecated("Legacy Android callback")
    override fun onStatusChanged(provider: String?, status: Int, extras: android.os.Bundle?) {}

    @Suppress("DEPRECATION")
    override fun onSensorChanged(event: SensorEvent) {
        if (event.timestamp - lastHeadingTime < 100_000_000) return
        lastHeadingTime = event.timestamp
        val values = event.values.copyOf()
        val accuracy = event.accuracy
        val rotation = context.getSystemService(WindowManager::class.java).defaultDisplay.rotation
        val timestamp = System.currentTimeMillis() - (SystemClock.elapsedRealtimeNanos() - event.timestamp) / 1_000_000
        queue.execute {
            if (!visible() || mode == "off") return@execute
            val fix = lastPosition
            if (accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE || fix == null) {
                emitHeading(null, null, timestamp); return@execute
            }
            val matrix = FloatArray(9)
            val remapped = FloatArray(9)
            SensorManager.getRotationMatrixFromVector(matrix, values)
            val axes = when (rotation) {
                Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
                Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
                Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
                else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
            }
            SensorManager.remapCoordinateSystem(matrix, axes.first, axes.second, remapped)
            val orientation = SensorManager.getOrientation(remapped, FloatArray(3))
            val magnetic = orientation[0] * 180.0 / PI
            val declination = GeomagneticField((fix["latitude"] as Number).toFloat(),
                (fix["longitude"] as Number).toFloat(), (fix["altitudeMeters"] as? Number)?.toFloat() ?: 0f,
                timestamp).declination
            val uncertainty = values.getOrNull(4)?.takeIf { it >= 0 }?.let { it * 180.0 / PI }
            emitHeading((magnetic + declination + 360) % 360, uncertainty, timestamp)
        }
    }

    private fun emitHeading(heading: Double?, accuracy: Double?, timestamp: Long) =
        emit(mapOf("type" to "heading", "data" to mapOf("timestamp" to timestamp,
            "headingDegrees" to heading, "accuracyDegrees" to accuracy)))

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    fun serviceLost() {
        if (mode == "tracking" && !TrackingService.running) {
            acquisition = "unavailable"
            issue = mapOf("code" to "serviceStopped", "message" to "Android stopped the foreground service")
            publishState()
        }
    }

    private fun fail(error: Exception) {
        issue = mapOf("code" to ((error as? TrackingFailure)?.code ?: "nativeError"), "message" to error.message)
        acquisition = "unavailable"; publishState()
    }
}
