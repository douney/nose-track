package com.nosetrack.nose_track.tracking.storage

import com.nosetrack.nose_track.tracking.domain.TraceRecorder
import com.nosetrack.nose_track.tracking.domain.TrackingFailure
import com.nosetrack.nose_track.tracking.domain.requireTracking
import com.nosetrack.nose_track.tracking.domain.trackId
import com.nosetrack.nose_track.tracking.domain.traceRole
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.util.UUID

/** Serial-queue-owned persistence. No Activity, Flutter or sensor dependency. */
class TrackStore(val root: File, schema: String) : TraceRecorder {
    private val db: SQLiteDatabase
    private var writer: FileOutputStream? = null
    override var target: Map<String, String>? = null
        private set
    private var summary = TraceJournal.Summary()
    private var nextSegment = 1L

    init {
        root.mkdirs()
        db = SQLiteDatabase.openOrCreateDatabase(File(root, "tracks.sqlite"), null)
        db.enableWriteAheadLogging()
        db.execSQL("PRAGMA synchronous=NORMAL")
        if (db.version == 0) {
            db.beginTransaction()
            try {
                schema.split(';').map { it.trim() }.filter { it.isNotEmpty() }.forEach { db.execSQL(it) }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
        requireTracking(db.version == 1, "storageError", "Unsupported catalogue version")
        recover()
    }

    private fun rows(sql: String, args: List<Any?> = emptyList()): List<Map<String, Any?>> =
        db.rawQuery(sql, args.map { it?.toString() ?: "" }.toTypedArray()).use { cursor ->
            buildList {
                while (cursor.moveToNext()) add(cursor.columnNames.withIndex().associate { (i, key) ->
                    key to when (cursor.getType(i)) {
                        Cursor.FIELD_TYPE_INTEGER -> cursor.getLong(i)
                        Cursor.FIELD_TYPE_FLOAT -> cursor.getDouble(i)
                        Cursor.FIELD_TYPE_STRING -> cursor.getString(i)
                        else -> null
                    }
                })
            }
        }

    fun get(id: String): Map<String, Any?>? =
        rows("SELECT * FROM tracks WHERE id=? AND deleted_at IS NULL", listOf(trackId(id))).firstOrNull()

    private fun required(id: String) = get(id) ?: throw TrackingFailure("trackNotFound", "Unknown track")

    private fun name(value: Any?): String {
        requireTracking(value is String && value.trim().isNotEmpty(), "invalidArgument", "A track name is required")
        return (value as String).trim()
    }

    private fun text(value: Any?): String? {
        requireTracking(value == null || value is String, "invalidArgument", "Expected text")
        return value as String?
    }

    fun create(values: Map<String, Any?>): Map<String, Any?> {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        db.execSQL("INSERT INTO tracks(id,name,description,dog_name,created_at,updated_at) VALUES(?,?,?,?,?,?)",
            arrayOf<Any?>(id, name(values["name"]), text(values["description"]), text(values["dog_name"]), now, now))
        return required(id)
    }

    fun update(id: String, changes: Map<String, Any?>): Map<String, Any?> {
        required(id)
        requireTracking(changes.keys.all { it in setOf("name", "description", "dog_name") },
            "invalidArgument", "Only user metadata can be edited")
        if (changes.isEmpty()) return required(id)
        val keys = changes.keys.sorted()
        val args: List<Any?> = keys.map { if (it == "name") name(changes[it]) else text(changes[it]) } +
            listOf<Any?>(System.currentTimeMillis(), id)
        db.execSQL("UPDATE tracks SET ${keys.joinToString(",") { "$it=?" }},updated_at=? WHERE id=?", args.toTypedArray())
        return required(id)
    }

    fun list(filter: Map<String, Any?>): List<Map<String, Any?>> {
        val clauses = mutableListOf("deleted_at IS NULL")
        val args = mutableListOf<Any?>()
        (filter["search"] as? String)?.takeIf { it.isNotEmpty() }?.let {
            clauses.add("instr(lower(name || ' ' || coalesce(description,'') || ' ' || coalesce(dog_name,'')),lower(?))>0")
            args.add(it)
        }
        for ((key, op) in listOf("createdFrom" to ">=", "createdBefore" to "<")) {
            (filter[key] as? Number)?.let { clauses.add("created_at$op?"); args.add(it.toLong()) }
        }
        for ((key, role) in listOf("hasTracer" to "tracer", "hasDog" to "dog")) {
            (filter[key] as? Boolean)?.let { clauses.add("${role}_status IS ${if (it) "NOT " else ""}NULL") }
        }
        return rows("SELECT * FROM tracks WHERE ${clauses.joinToString(" AND ")} ORDER BY created_at DESC,id", args)
    }

    private fun file(id: String, role: String) = File(root, "tracks/$id/$role.jsonl")

    private fun save(id: String, role: String, value: TraceJournal.Summary, status: String) {
        db.execSQL("""UPDATE tracks SET ${role}_file_name=?,${role}_started_at=?,${role}_ended_at=?,
            ${role}_status=?,${role}_point_count=?,${role}_start_latitude=?,${role}_start_longitude=?,
            updated_at=? WHERE id=?""", arrayOf<Any?>("tracks/$id/$role.jsonl", value.startedAt, value.endedAt,
            status, value.count, value.firstLatitude, value.firstLongitude, System.currentTimeMillis(), id))
    }

    override fun start(value: Map<String, Any?>) {
        requireTracking(target == null && writer == null, "recordingInProgress", "A recording is already active")
        try { startJournal(value) }
        catch (error: Exception) {
            runCatching { writer?.close() }; writer = null; target = null
            runCatching { recover() }
            throw error
        }
    }

    private fun startJournal(value: Map<String, Any?>) {
        val id = trackId(value["trackId"])
        val role = traceRole(value["role"])
        val row = required(id)
        val destination = file(id, role)
        destination.parentFile!!.mkdirs()
        if (destination.exists()) {
            requireTracking(row["${role}_status"] == "interrupted", "traceAlreadyExists", "This role already has a trace")
            summary = TraceJournal.inspect(destination)
            requireTracking(summary.endedAt == null, "traceAlreadyExists", "This trace is finished")
            RandomAccessFile(destination, "rw").use { it.setLength(summary.completeBytes) }
            writer = FileOutputStream(destination, true)
            nextSegment = summary.segment + 1
        } else {
            requireTracking(row["${role}_status"] == null, "storageError", "Missing journal file")
            requireTracking(destination.createNewFile(), "traceAlreadyExists", "Journal already exists")
            summary = TraceJournal.Summary(startedAt = System.currentTimeMillis())
            writer = FileOutputStream(destination, true)
            writer!!.write(TraceJournal.line(mapOf("type" to "header", "version" to 1, "trackId" to id,
                "role" to role, "startedAt" to summary.startedAt)))
            writer!!.fd.sync()
            nextSegment = 1
        }
        target = mapOf("trackId" to id, "role" to role)
        save(id, role, summary, "recording")
    }

    private fun writeRecord(record: Map<String, Any?>) {
        val stream = writer ?: throw TrackingFailure("storageError", "Journal requires recovery")
        val offset = stream.channel.position()
        try { stream.write(TraceJournal.line(record)); stream.fd.sync() }
        catch (error: Exception) {
            try { stream.channel.truncate(offset); stream.channel.position(offset); stream.fd.sync() }
            catch (_: Exception) { runCatching { stream.close() }; writer = null }
            throw error
        }
    }

    override fun append(fix: Map<String, Any?>): Map<String, Any?>? {
        val target = target ?: return null
        val time = (fix["timestamp"] as Number).toLong()
        summary.lastTimestamp?.let {
            if (time - it < 1000) return null
            if (time - it > 10000) nextSegment = maxOf(nextSegment, summary.segment + 1)
        }
        val point = fix + mapOf("type" to "point", "sequence" to summary.count + 1, "segmentId" to nextSegment)
        TraceJournal.validPoint(point, summary.count + 1, summary.segment, summary.lastTimestamp)
        writeRecord(point)
        summary.count++; summary.segment = nextSegment; summary.lastTimestamp = time
        if (summary.firstLatitude == null) {
            summary.firstLatitude = (fix["latitude"] as Number).toDouble()
            summary.firstLongitude = (fix["longitude"] as Number).toDouble()
        }
        save(target.getValue("trackId"), target.getValue("role"), summary, "recording")
        return point
    }

    override fun finish() {
        val target = target ?: return
        if (summary.endedAt == null && writer == null) {
            val source = file(target.getValue("trackId"), target.getValue("role"))
            summary = TraceJournal.inspect(source)
            RandomAccessFile(source, "rw").use { it.setLength(summary.completeBytes) }
            writer = FileOutputStream(source, true)
        }
        if (summary.endedAt == null) {
            val ended = System.currentTimeMillis()
            writeRecord(mapOf("type" to "end", "endedAt" to ended))
            writer?.close(); writer = null; summary.endedAt = ended
        }
        writer?.close(); writer = null
        save(target.getValue("trackId"), target.getValue("role"), summary, "finished")
        this.target = null
    }

    override fun session(): Map<String, Any?>? = target?.let { it + mapOf("startedAt" to summary.startedAt,
        "endedAt" to summary.endedAt, "status" to if (summary.endedAt == null) "recording" else "finished") }

    fun delete(id: String) {
        trackId(id)
        requireTracking(rows("SELECT id FROM tracks WHERE id=?", listOf(id)).isNotEmpty(), "trackNotFound", "Unknown track")
        requireTracking(target?.get("trackId") != id, "recordingInProgress", "Stop recording before deletion")
        db.execSQL("UPDATE tracks SET deleted_at=?,updated_at=? WHERE id=?",
            arrayOf<Any?>(System.currentTimeMillis(), System.currentTimeMillis(), id))
        removeDeleted(id)
    }

    private fun removeDeleted(id: String) {
        val directory = File(root, "tracks/$id")
        requireTracking(!directory.exists() || directory.deleteRecursively(), "storageError", "Cannot delete journal directory")
        db.execSQL("DELETE FROM tracks WHERE id=?", arrayOf<Any?>(id))
    }

    fun read(id: String, roleValue: String, offset: Long, after: Long): Map<String, Any?> {
        val role = traceRole(roleValue)
        val row = required(id)
        val status = row["${role}_status"] ?: throw TrackingFailure("traceNotFound", "This role has no trace")
        val source = file(id, role)
        val points = mutableListOf<Map<String, Any?>>()
        var visited = 0
        val end = TraceJournal.records(source, offset) { record, _ ->
            visited++
            if (record["type"] == "point" && ((record["sequence"] as? Number)?.toLong() ?: 0) > after) points.add(record)
            visited < 256
        }
        return mapOf("points" to points, "offset" to end,
            "eof" to (visited < 256 || end >= source.length()), "status" to status)
    }

    fun importTrace(id: String, roleValue: String, source: String): Map<String, Any?> {
        val role = traceRole(roleValue)
        val row = required(id)
        requireTracking(row["${role}_status"] == null, "traceAlreadyExists", "This role already has a trace")
        val original = File(source)
        val destination = file(id, role)
        requireTracking(!destination.exists(), "traceAlreadyExists", "Journal already exists")
        destination.parentFile!!.mkdirs()
        val temporary = File(destination.path + ".import")
        requireTracking(original.canonicalFile != temporary.canonicalFile,
            "invalidArgument", "The source cannot be the import staging file")
        try {
            var copied = 0L
            FileOutputStream(temporary).use { output ->
                copied = TraceJournal.records(original) { record, _ ->
                    val value = if (record["type"] == "header") record + mapOf("trackId" to id, "role" to role) else record
                    output.write(TraceJournal.line(value)); true
                }
                output.fd.sync()
            }
            val inspected = TraceJournal.inspect(temporary)
            requireTracking(inspected.endedAt != null && copied == original.length(),
                "invalidTrace", "Import requires a complete, finalized JSONL journal")
            requireTracking(temporary.renameTo(destination), "storageError", "Cannot install imported journal")
            save(id, role, inspected, "finished")
        } finally { temporary.delete() }
        return required(id)
    }

    private fun recover() {
        for (row in rows("SELECT * FROM tracks")) {
            val id = trackId(row["id"])
            if (row["deleted_at"] != null) { removeDeleted(id); continue }
            for (role in listOf("tracer", "dog")) {
                val source = file(id, role)
                File(source.path + ".import").delete()
                if ((row["${role}_status"] == null || row["${role}_status"] == "recording") && source.exists()) {
                    if (row["${role}_status"] == null && TraceJournal.records(source) { _, _ -> false } == 0L) {
                        requireTracking(source.delete(), "storageError", "Cannot remove incomplete header")
                        continue
                    }
                    val value = TraceJournal.inspect(source)
                    RandomAccessFile(source, "rw").use { it.setLength(value.completeBytes); it.fd.sync() }
                    save(id, role, value, if (value.endedAt == null) "interrupted" else "finished")
                }
            }
        }
    }
}
