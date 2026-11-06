package com.nosetrack.nose_track.tracking

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.nosetrack.nose_track.tracking.geolocation.GeolocationEngine
import com.nosetrack.nose_track.tracking.storage.TrackStore
import com.nosetrack.nose_track.tracking.domain.TrackingFailure
import com.nosetrack.nose_track.tracking.domain.requireTracking
import com.nosetrack.nose_track.tracking.domain.trackId
import com.nosetrack.nose_track.tracking.domain.traceRole
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Process-owned runtime. Detaching Flutter never stops an active recording. */
object TrackingRuntime : EventChannel.StreamHandler {
    private val queue = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var visible = false
    private var sink: EventChannel.EventSink? = null
    private var store: TrackStore? = null
    private var engine: GeolocationEngine? = null

    fun register(context: Context, messenger: BinaryMessenger) {
        EventChannel(messenger, "nose_track/tracking/events").setStreamHandler(this)
        MethodChannel(messenger, "nose_track/tracking").setMethodCallHandler { call, result ->
            queue.execute {
                try {
                    val value = perform(context.applicationContext, call)
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    main.post { result.error((error as? TrackingFailure)?.code ?: "storageError", error.message, null) }
                }
            }
        }
    }

    fun setVisible(value: Boolean) {
        visible = value
        queue.execute { engine?.visibilityChanged() }
    }

    fun serviceLost() { queue.execute { engine?.serviceLost() } }

    private fun emit(event: Map<String, Any?>) { main.post { sink?.success(event) } }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    @Suppress("UNCHECKED_CAST")
    private fun perform(context: Context, call: MethodCall): Any? {
        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
        if (call.method == "initialize") {
            if (store == null) {
                val schema = args["schema"] as? String ?: throw TrackingFailure("invalidArgument", "Missing schema")
                store = TrackStore(File(context.filesDir, "NoseTrack"), schema)
                engine = GeolocationEngine(context, store!!, queue, { visible }, ::emit)
            }
            return engine!!.snapshot()
        }
        val store = store ?: throw TrackingFailure("notInitialized", "Initialize tracking first")
        val engine = engine!!
        return when (call.method) {
            "getSnapshot" -> engine.snapshot()
            "setMode" -> { engine.setMode(args["mode"] as? String ?: "", args["target"] as? Map<String, Any?>); null }
            "createTrack" -> store.create(args)
            "listTracks" -> store.list(args)
            "getTrack" -> store.get(trackId(args["trackId"]))
            "updateTrack" -> store.update(trackId(args["trackId"]), args["changes"] as? Map<String, Any?> ?: emptyMap())
            "deleteTrack" -> { store.delete(trackId(args["trackId"])); emit(mapOf("type" to "journal")); null }
            "importTrace" -> {
                val row = store.importTrace(trackId(args["trackId"]), traceRole(args["role"]),
                    args["source"] as? String ?: throw TrackingFailure("invalidArgument", "Missing source file"))
                emit(mapOf("type" to "journal")); row
            }
            "readTrack" -> {
                val offset = (args["offset"] as? Number)?.toLong() ?: 0
                val after = (args["afterSequence"] as? Number)?.toLong() ?: 0
                requireTracking(offset >= 0 && after >= 0, "invalidArgument", "Negative read cursor")
                store.read(trackId(args["trackId"]), traceRole(args["role"]), offset, after)
            }
            else -> throw TrackingFailure("invalidArgument", "Unknown tracking method")
        }
    }
}
