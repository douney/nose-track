package com.nosetrack.nose_track.tracking.domain

/** Acquisition has no dependency on SQL or product metadata. */
interface TraceRecorder {
    val target: Map<String, String>?
    fun start(value: Map<String, Any?>)
    fun append(fix: Map<String, Any?>): Map<String, Any?>?
    fun finish()
    fun session(): Map<String, Any?>?
}
