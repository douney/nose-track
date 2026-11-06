import Foundation
import SQLite3

/// All methods run on the coordinator's serial queue. No Flutter or GPS dependency.
final class TrackStore: TraceRecorder {
  let root: URL
  private var db: OpaquePointer?
  private var writer: FileHandle?
  private(set) var target: [String: String]?
  private var summary = TraceJournal.Summary()
  private var nextSegment: Int64 = 1

  init(root: URL, schema: String) throws {
    self.root = root
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let status = sqlite3_open_v2(root.appendingPathComponent("tracks.sqlite").path, &db,
      SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
    try requireTracking(status == SQLITE_OK, "storageError", "Cannot open track catalogue")
    try execute("PRAGMA journal_mode=WAL")
    try execute("PRAGMA synchronous=NORMAL")
    let version = (try rows("PRAGMA user_version").first?["user_version"] as? Int64) ?? 0
    if version == 0 {
      try execute("BEGIN IMMEDIATE")
      do { try execute(schema); try execute("COMMIT") }
      catch { try? execute("ROLLBACK"); throw error }
    } else {
      try requireTracking(version == 1, "storageError", "Unsupported catalogue version")
    }
    try recover()
  }

  deinit { try? writer?.close(); sqlite3_close(db) }

  private func statement(_ sql: String, _ args: [Any?]) throws -> OpaquePointer {
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
      throw TrackingFailure("storageError", String(cString: sqlite3_errmsg(db)))
    }
    for (i, value) in args.enumerated() {
      let index = Int32(i + 1)
      switch value {
      case nil, is NSNull: sqlite3_bind_null(stmt, index)
      case let text as String:
        _ = text.withCString { sqlite3_bind_text(stmt, index, $0, -1,
          unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
      case let number as NSNumber:
        if String(cString: number.objCType) == "d" || String(cString: number.objCType) == "f" {
          sqlite3_bind_double(stmt, index, number.doubleValue)
        } else { sqlite3_bind_int64(stmt, index, number.int64Value) }
      default:
        sqlite3_finalize(stmt)
        throw TrackingFailure("invalidArgument", "Unsupported SQL value")
      }
    }
    return stmt
  }

  private func execute(_ sql: String, _ args: [Any?] = []) throws {
    if args.isEmpty {
      guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
        throw TrackingFailure("storageError", String(cString: sqlite3_errmsg(db)))
      }
    } else {
      let stmt = try statement(sql, args)
      defer { sqlite3_finalize(stmt) }
      try requireTracking(sqlite3_step(stmt) == SQLITE_DONE, "storageError",
                          String(cString: sqlite3_errmsg(db)))
    }
  }

  private func rows(_ sql: String, _ args: [Any?] = []) throws -> [[String: Any]] {
    let stmt = try statement(sql, args)
    defer { sqlite3_finalize(stmt) }
    var result = [[String: Any]]()
    var step = sqlite3_step(stmt)
    while step == SQLITE_ROW {
      var row = [String: Any]()
      for i in 0..<sqlite3_column_count(stmt) {
        let key = String(cString: sqlite3_column_name(stmt, i))
        switch sqlite3_column_type(stmt, i) {
        case SQLITE_INTEGER: row[key] = sqlite3_column_int64(stmt, i)
        case SQLITE_FLOAT: row[key] = sqlite3_column_double(stmt, i)
        case SQLITE_TEXT: row[key] = String(cString: sqlite3_column_text(stmt, i))
        default: row[key] = NSNull()
        }
      }
      result.append(row)
      step = sqlite3_step(stmt)
    }
    try requireTracking(step == SQLITE_DONE, "storageError", String(cString: sqlite3_errmsg(db)))
    return result
  }

  func get(_ id: String) throws -> [String: Any]? {
    let id = try trackingID(id)
    return try rows("SELECT * FROM tracks WHERE id=? AND deleted_at IS NULL", [id]).first
  }

  private func required(_ id: String) throws -> [String: Any] {
    guard let row = try get(id) else { throw TrackingFailure("trackNotFound", "Unknown track") }
    return row
  }

  func create(_ values: [String: Any]) throws -> [String: Any] {
    let id = UUID().uuidString.lowercased()
    let name = try checkedName(values["name"])
    let now = trackingNow()
    try execute("INSERT INTO tracks(id,name,description,dog_name,created_at,updated_at) VALUES(?,?,?,?,?,?)",
      [id, name, try optionalText(values["description"]), try optionalText(values["dog_name"]), now, now])
    return try required(id)
  }

  private func checkedName(_ value: Any?) throws -> String {
    guard let name = value as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw TrackingFailure("invalidArgument", "A track name is required")
    }
    return name.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func optionalText(_ value: Any?) throws -> String? {
    if value == nil || value is NSNull { return nil }
    guard let text = value as? String else { throw TrackingFailure("invalidArgument", "Expected text") }
    return text
  }

  func update(_ id: String, changes: [String: Any]) throws -> [String: Any] {
    _ = try required(id)
    try requireTracking(Set(changes.keys).isSubset(of: ["name", "description", "dog_name"]),
      "invalidArgument", "Only user metadata can be edited")
    if changes.isEmpty { return try required(id) }
    var columns = [String]()
    var values = [Any?]()
    for key in changes.keys.sorted() {
      columns.append("\(key)=?")
      values.append(key == "name" ? try checkedName(changes[key]) : try optionalText(changes[key]))
    }
    columns.append("updated_at=?")
    values.append(trackingNow()); values.append(id)
    try execute("UPDATE tracks SET \(columns.joined(separator: ",")) WHERE id=?", values)
    return try required(id)
  }

  func list(_ filter: [String: Any]) throws -> [[String: Any]] {
    var clauses = ["deleted_at IS NULL"]
    var args = [Any?]()
    if let search = filter["search"] as? String, !search.isEmpty {
      clauses.append("instr(lower(name || ' ' || coalesce(description,'') || ' ' || coalesce(dog_name,'')),lower(?))>0")
      args.append(search)
    }
    for (key, op) in [("createdFrom", ">="), ("createdBefore", "<")] {
      if let value = filter[key] as? NSNumber { clauses.append("created_at\(op)?"); args.append(value) }
    }
    for (key, role) in [("hasTracer", "tracer"), ("hasDog", "dog")] {
      if let value = filter[key] as? Bool { clauses.append("\(role)_status IS \(value ? "NOT " : "")NULL") }
    }
    return try rows("SELECT * FROM tracks WHERE \(clauses.joined(separator: " AND ")) ORDER BY created_at DESC,id", args)
  }

  private func file(_ id: String, _ role: String) -> URL {
    root.appendingPathComponent("tracks/\(id)/\(role).jsonl")
  }

  private func save(_ id: String, _ role: String, _ value: TraceJournal.Summary, _ status: String) throws {
    try execute("""
      UPDATE tracks SET \(role)_file_name=?,\(role)_started_at=?,\(role)_ended_at=?,
      \(role)_status=?,\(role)_point_count=?,\(role)_start_latitude=?,
      \(role)_start_longitude=?,updated_at=? WHERE id=?
      """, ["tracks/\(id)/\(role).jsonl", value.startedAt, value.endedAt, status,
      value.count, value.firstLatitude, value.firstLongitude, trackingNow(), id])
  }

  func start(_ value: [String: Any]) throws {
    try requireTracking(target == nil && writer == nil, "recordingInProgress", "A recording is already active")
    do { try startJournal(value) }
    catch {
      try? writer?.close(); writer = nil; target = nil
      try? recover()
      throw error
    }
  }

  private func startJournal(_ value: [String: Any]) throws {
    let id = try trackingID(value["trackId"])
    let role = try trackingRole(value["role"])
    let row = try required(id)
    let url = file(id, role)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: url.path) {
      try requireTracking(row["\(role)_status"] as? String == "interrupted",
        "traceAlreadyExists", "This role already has a trace")
      summary = try TraceJournal.inspect(url)
      try requireTracking(summary.endedAt == nil, "traceAlreadyExists", "This trace is finished")
      writer = try FileHandle(forWritingTo: url)
      try writer!.truncate(atOffset: summary.completeBytes)
      try writer!.seekToEnd()
      nextSegment = summary.segment + 1
    } else {
      try requireTracking(row["\(role)_status"] is NSNull, "storageError", "Missing journal file")
      summary = TraceJournal.Summary()
      summary.startedAt = trackingNow()
      let header: [String: Any] = ["type": "header", "version": 1, "trackId": id,
        "role": role, "startedAt": summary.startedAt]
      try TraceJournal.line(header).write(to: url, options: [.withoutOverwriting])
      writer = try FileHandle(forWritingTo: url)
      try writer!.seekToEnd()
      try writer!.synchronize()
      nextSegment = 1
    }
    target = ["trackId": id, "role": role]
    try save(id, role, summary, "recording")
  }

  private func writeRecord(_ record: [String: Any]) throws {
    guard let writer else { throw TrackingFailure("storageError", "Journal requires recovery") }
    let offset = try writer.offset()
    do {
      try writer.write(contentsOf: TraceJournal.line(record))
      try writer.synchronize()
    } catch {
      // A failed write must not leave a partial line before the next append.
      do { try writer.truncate(atOffset: offset); try writer.seekToEnd(); try writer.synchronize() }
      catch { try? writer.close(); self.writer = nil }
      throw error
    }
  }

  func append(_ fix: [String: Any]) throws -> [String: Any]? {
    guard let target else { return nil }
    let time = (fix["timestamp"] as! NSNumber).int64Value
    if let last = summary.lastTimestamp, time - last < 1000 { return nil }
    // Keep genuine gaps visible; normal stationary fixes remain in one segment.
    if let last = summary.lastTimestamp, time - last > 10000 { nextSegment = max(nextSegment, summary.segment + 1) }
    var point = fix
    point["type"] = "point"; point["sequence"] = summary.count + 1; point["segmentId"] = nextSegment
    try TraceJournal.validPoint(point, sequence: summary.count + 1, segment: summary.segment,
                                previousTimestamp: summary.lastTimestamp)
    try writeRecord(point)
    summary.count += 1; summary.segment = nextSegment; summary.lastTimestamp = time
    if summary.firstLatitude == nil {
      summary.firstLatitude = (fix["latitude"] as! NSNumber).doubleValue
      summary.firstLongitude = (fix["longitude"] as! NSNumber).doubleValue
    }
    try save(target["trackId"]!, target["role"]!, summary, "recording")
    return point
  }

  func finish() throws {
    guard let target else { return }
    if summary.endedAt == nil && writer == nil {
      let url = file(target["trackId"]!, target["role"]!)
      summary = try TraceJournal.inspect(url)
      writer = try FileHandle(forWritingTo: url)
      try writer!.truncate(atOffset: summary.completeBytes); try writer!.seekToEnd()
    }
    if summary.endedAt == nil {
      let ended = trackingNow()
      try writeRecord(["type": "end", "endedAt": ended])
      summary.endedAt = ended
    }
    try writer?.close(); writer = nil
    try save(target["trackId"]!, target["role"]!, summary, "finished")
    self.target = nil
  }

  func session() -> [String: Any]? {
    guard let target else { return nil }
    return ["trackId": target["trackId"]!, "role": target["role"]!,
      "startedAt": summary.startedAt, "endedAt": summary.endedAt ?? NSNull(),
      "status": summary.endedAt == nil ? "recording" : "finished"]
  }

  func delete(_ id: String) throws {
    let id = try trackingID(id)
    try requireTracking(try !rows("SELECT id FROM tracks WHERE id=?", [id]).isEmpty,
                        "trackNotFound", "Unknown track")
    try requireTracking(target?["trackId"] != id, "recordingInProgress", "Stop recording before deletion")
    try execute("UPDATE tracks SET deleted_at=?,updated_at=? WHERE id=?", [trackingNow(), trackingNow(), id])
    try removeDeleted(id)
  }

  private func removeDeleted(_ id: String) throws {
    let directory = root.appendingPathComponent("tracks/\(id)")
    if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    try execute("DELETE FROM tracks WHERE id=?", [id])
  }

  func read(_ id: String, role: String, offset: UInt64, after: Int64) throws -> [String: Any] {
    let role = try trackingRole(role)
    let row = try required(id)
    guard let status = row["\(role)_status"] as? String else {
      throw TrackingFailure("traceNotFound", "This role has no trace")
    }
    let url = file(id, role)
    var points = [[String: Any]]()
    var visited = 0
    let end = try TraceJournal.records(url, offset: offset) { record, _ in
      visited += 1
      if record["type"] as? String == "point", (record["sequence"] as? NSNumber)?.int64Value ?? 0 > after {
        points.append(record)
      }
      return visited < 256
    }
    let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! NSNumber).uint64Value
    return ["points": points, "offset": end, "eof": visited < 256 || end >= size, "status": status]
  }

  func importTrace(_ id: String, role: String, source: String) throws -> [String: Any] {
    let role = try trackingRole(role)
    let row = try required(id)
    try requireTracking(row["\(role)_status"] is NSNull, "traceAlreadyExists", "This role already has a trace")
    let sourceURL = URL(fileURLWithPath: source)
    let destination = file(id, role)
    try requireTracking(!FileManager.default.fileExists(atPath: destination.path), "traceAlreadyExists", "Journal already exists")
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let temporary = destination.appendingPathExtension("import")
    try requireTracking(sourceURL.resolvingSymlinksInPath().standardizedFileURL
      != temporary.resolvingSymlinksInPath().standardizedFileURL,
      "invalidArgument", "The source cannot be the import staging file")
    FileManager.default.createFile(atPath: temporary.path, contents: nil)
    let output = try FileHandle(forWritingTo: temporary)
    do {
      let copied = try TraceJournal.records(sourceURL) { record, _ in
        var record = record
        if record["type"] as? String == "header" { record["trackId"] = id; record["role"] = role }
        try output.write(contentsOf: TraceJournal.line(record))
        return true
      }
      try output.synchronize(); try output.close()
      let size = (try FileManager.default.attributesOfItem(atPath: source)[.size] as! NSNumber).uint64Value
      let inspected = try TraceJournal.inspect(temporary)
      try requireTracking(inspected.endedAt != nil && copied == size,
        "invalidTrace", "Import requires a complete, finalized JSONL journal")
      try FileManager.default.moveItem(at: temporary, to: destination)
      try save(id, role, inspected, "finished")
    } catch {
      try? output.close(); try? FileManager.default.removeItem(at: temporary)
      throw error
    }
    return try required(id)
  }

  private func recover() throws {
    for row in try rows("SELECT * FROM tracks") {
      let id = try trackingID(row["id"])
      if !(row["deleted_at"] is NSNull) { try removeDeleted(id); continue }
      for role in ["tracer", "dog"] {
        let url = file(id, role)
        let temporary = url.appendingPathExtension("import")
        if FileManager.default.fileExists(atPath: temporary.path) { try FileManager.default.removeItem(at: temporary) }
        if (row["\(role)_status"] is NSNull || row["\(role)_status"] as? String == "recording")
          && FileManager.default.fileExists(atPath: url.path) {
          if row["\(role)_status"] is NSNull,
             try TraceJournal.records(url, visit: { _, _ in false }) == 0 {
            // Process died before the new header was complete; no point exists.
            try FileManager.default.removeItem(at: url)
            continue
          }
          let value = try TraceJournal.inspect(url)
          let handle = try FileHandle(forWritingTo: url)
          try handle.truncate(atOffset: value.completeBytes); try handle.synchronize(); try handle.close()
          try save(id, role, value, value.endedAt == nil ? "interrupted" : "finished")
        }
      }
    }
  }
}
