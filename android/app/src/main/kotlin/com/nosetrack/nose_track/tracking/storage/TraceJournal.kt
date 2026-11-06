package com.nosetrack.nose_track.tracking.storage

import com.nosetrack.nose_track.tracking.domain.TrackingFailure
import com.nosetrack.nose_track.tracking.domain.requireTracking
import com.nosetrack.nose_track.tracking.domain.trackId
import com.nosetrack.nose_track.tracking.domain.traceRole
import org.json.JSONObject
import org.json.JSONArray
import org.json.JSONException
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream

private fun jsonValue(value: Any?): Any? = when (value) {
    JSONObject.NULL -> null
    is JSONObject -> value.asMap()
    is JSONArray -> (0 until value.length()).map { jsonValue(value.get(it)) }
    else -> value
}

fun JSONObject.asMap(): Map<String, Any?> = keys().asSequence().associateWith { jsonValue(get(it)) }

object TraceJournal {
    data class Summary(var startedAt: Long = 0, var endedAt: Long? = null,
        var count: Long = 0, var segment: Long = 0, var lastTimestamp: Long? = null,
        var firstLatitude: Double? = null, var firstLongitude: Double? = null,
        var completeBytes: Long = 0)

    fun line(value: Map<String, Any?>): ByteArray = (JSONObject(value).toString() + "\n").toByteArray(Charsets.UTF_8)

    fun validPoint(point: Map<String, Any?>, sequence: Long, segment: Long, previous: Long?) {
        fun number(key: String): Double = (point[key] as? Number)?.toDouble()
            ?: throw TrackingFailure("invalidTrace", "Missing $key")
        val seq = number("sequence")
        val seg = number("segmentId")
        val time = number("timestamp")
        val lat = number("latitude")
        val lon = number("longitude")
        requireTracking(seq == sequence.toDouble() && seg >= maxOf(1, segment) && seg == seg.toLong().toDouble(),
            "invalidTrace", "Invalid point sequence or segment")
        requireTracking(time.isFinite() && time >= 0 && time == time.toLong().toDouble()
            && (previous == null || time.toLong() > previous), "invalidTrace", "Invalid measurement timestamp")
        requireTracking(lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0,
            "invalidTrace", "Invalid coordinates")
        for (key in listOf("accuracyMeters", "altitudeMeters", "speedMetersPerSecond", "courseDegrees")) {
            if (point[key] != null) {
                val value = number(key)
                requireTracking(value.isFinite() && (key == "altitudeMeters" || value >= 0)
                    && (key != "courseDegrees" || value < 360), "invalidTrace", "Invalid $key")
            }
        }
    }

    /** Bounded UTF-8 records; returns the offset after the last complete line. */
    fun records(file: File, offset: Long = 0, visit: (Map<String, Any?>, Long) -> Boolean): Long {
        FileInputStream(file).use { input ->
            input.channel.position(offset)
            BufferedInputStream(input).use { buffered ->
                val pending = ByteArrayOutputStream()
                var consumed = offset
                while (true) {
                    val byte = buffered.read()
                    if (byte == -1) return consumed
                    if (byte == 10) {
                        val bytes = pending.toByteArray()
                        consumed += bytes.size + 1
                        pending.reset()
                        val record = try { JSONObject(String(bytes, Charsets.UTF_8)).asMap() }
                        catch (_: JSONException) { throw TrackingFailure("invalidTrace", "Malformed JSONL record") }
                        if (!visit(record, consumed)) return consumed
                    } else {
                        pending.write(byte)
                        requireTracking(pending.size() <= 65536, "invalidTrace", "Oversized JSONL record")
                    }
                }
            }
        }
    }

    fun inspect(file: File): Summary {
        val summary = Summary()
        var header = false
        summary.completeBytes = records(file) { record, _ ->
            requireTracking(summary.endedAt == null, "invalidTrace", "Records after end")
            when (record["type"]) {
                "header" -> {
                    requireTracking(!header && (record["version"] as? Number)?.toDouble() == 1.0,
                        "invalidTrace", "Invalid JSONL header")
                    trackId(record["trackId"]); traceRole(record["role"])
                    summary.startedAt = (record["startedAt"] as? Number)?.toLong()
                        ?: throw TrackingFailure("invalidTrace", "Missing recording start")
                    requireTracking((record["startedAt"] as Number).toDouble() == summary.startedAt.toDouble()
                        && summary.startedAt >= 0, "invalidTrace", "Invalid recording start")
                    header = true
                }
                "point" -> {
                    requireTracking(header, "invalidTrace", "Missing header")
                    validPoint(record, summary.count + 1, summary.segment, summary.lastTimestamp)
                    summary.count++
                    summary.segment = (record["segmentId"] as Number).toLong()
                    summary.lastTimestamp = (record["timestamp"] as Number).toLong()
                    if (summary.firstLatitude == null) {
                        summary.firstLatitude = (record["latitude"] as Number).toDouble()
                        summary.firstLongitude = (record["longitude"] as Number).toDouble()
                    }
                }
                "end" -> {
                    requireTracking(header, "invalidTrace", "Missing header")
                    summary.endedAt = (record["endedAt"] as? Number)?.toLong()
                        ?: throw TrackingFailure("invalidTrace", "Missing recording end")
                    requireTracking((record["endedAt"] as Number).toDouble() == summary.endedAt!!.toDouble()
                        && summary.endedAt!! >= 0, "invalidTrace", "Invalid recording end")
                }
                else -> throw TrackingFailure("invalidTrace", "Unknown JSONL record")
            }
            true
        }
        requireTracking(header, "invalidTrace", "Missing header")
        return summary
    }
}
