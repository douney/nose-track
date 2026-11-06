package com.nosetrack.nose_track.tracking.domain

import java.util.UUID

class TrackingFailure(val code: String, message: String) : Exception(message)

fun requireTracking(condition: Boolean, code: String, message: String) {
    if (!condition) throw TrackingFailure(code, message)
}

fun trackId(value: Any?): String {
    val text = value as? String ?: throw TrackingFailure("invalidArgument", "Invalid track identifier")
    requireTracking(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(text),
        "invalidArgument", "Invalid track identifier")
    return UUID.fromString(text).toString()
}

fun traceRole(value: Any?): String {
    requireTracking(value == "tracer" || value == "dog", "invalidArgument", "Unknown trace role")
    return value as String
}
