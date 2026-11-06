import Foundation
import SQLite3

@main
struct StorageChecks {
  static func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw TrackingFailure("testFailed", message) }
  }

  static func rejects(_ code: String, _ body: () throws -> Void) throws {
    do { try body(); throw TrackingFailure("testFailed", "Expected \(code)") }
    catch let error as TrackingFailure { try check(error.code == code, "Expected \(code), got \(error.code)") }
  }

  static func fix(_ time: Int64, _ latitude: Double = 48.1) -> [String: Any] {
    ["timestamp": time, "latitude": latitude, "longitude": 2.3, "accuracyMeters": 3.0,
     "altitudeMeters": NSNull(), "speedMetersPerSecond": 1.2, "courseDegrees": NSNull()]
  }

  static func execute(_ root: URL, _ sql: String) throws {
    var db: OpaquePointer?
    try check(sqlite3_open(root.appendingPathComponent("tracks.sqlite").path, &db) == SQLITE_OK,
              "Fault injection connection")
    defer { sqlite3_close(db) }
    try check(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "Fault injection statement")
  }

  static func main() throws {
    let schema = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("nose-track-tests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: root) }
    var store: TrackStore? = try TrackStore(root: root, schema: schema)
    let row = try store!.create(["name": "Parcours forêt 🐕", "dog_name": "Nala"])
    let id = row["id"] as! String
    try check(row["dog_name"] as? String == "Nala", "Dog name persisted")
    let updated = try store!.update(id, changes: ["description": "Sous-bois", "dog_name": NSNull()])
    try check(updated["dog_name"] is NSNull && updated["name"] as? String == row["name"] as? String, "Patch preserves omitted fields and clears null")
    try rejects("invalidArgument") { _ = try store!.update(id, changes: ["tracer_status": "finished"]) }
    try check(try store!.list(["search": "forêt"]).count == 1, "Unicode metadata/search")

    try store!.start(["trackId": id, "role": "tracer"])
    let start = trackingNow()
    _ = try store!.append(fix(start))
    try check(try store!.append(fix(start + 500)) == nil, "Rate limit")
    _ = try store!.append(fix(start + 1000))
    try rejects("recordingInProgress") { try store!.delete(id) }
    let partial = try store!.read(id, role: "tracer", offset: 0, after: 1)
    try check((partial["points"] as! [[String: Any]]).count == 1, "Exclusive sequence and live reads")
    store = nil // Simulates process death without normal recording finalization.
    let path = root.appendingPathComponent("tracks/\(id)/tracer.jsonl")
    let damaged = try FileHandle(forWritingTo: path)
    try damaged.seekToEnd(); try damaged.write(contentsOf: Data("{\"type\":\"point\"".utf8)); try damaged.close()
    store = try TrackStore(root: root, schema: schema)
    let recovered = try store!.get(id)!
    try check(recovered["tracer_status"] as? String == "interrupted", "Crash marks interrupted")
    try check(recovered["tracer_point_count"] as? Int64 == 2, "Crash preserves complete points")
    try store!.start(["trackId": id, "role": "tracer"])
    let resumed = try store!.append(fix(start + 2000))!
    try check(resumed["sequence"] as? Int64 == 3 && resumed["segmentId"] as? Int64 == 2, "Explicit resume preserves sequence and starts segment")
    try execute(root, """
      CREATE TRIGGER reject_finish BEFORE UPDATE OF tracer_status ON tracks
      WHEN NEW.tracer_status='finished' BEGIN SELECT RAISE(FAIL, 'test finish failure'); END;
      """)
    try rejects("storageError") { try store!.finish() }
    try check(store!.session()?["status"] as? String == "finished", "Session reflects the committed footer after SQL failure")
    let ended = try TraceJournal.inspect(path).endedAt
    try execute(root, "DROP TRIGGER reject_finish")
    try store!.finish()
    try check(try TraceJournal.inspect(path).endedAt == ended, "Retry updates SQL without duplicating the footer")
    try rejects("traceAlreadyExists") { try store!.start(["trackId": id, "role": "tracer"]) }
    let bytes = try Data(contentsOf: path)

    _ = try store!.importTrace(id, role: "dog", source: path.path)
    try check(try Data(contentsOf: path) == bytes, "Import preserves original")
    try check(try store!.list(["hasTracer": true, "hasDog": true]).count == 1, "Two roles in one row")
    try rejects("traceAlreadyExists") { _ = try store!.importTrace(id, role: "dog", source: path.path) }
    let other = try store!.create(["name": "Longue trace"])
    let otherID = other["id"] as! String
    try store!.start(["trackId": otherID, "role": "dog"])
    for i in 0..<600 { _ = try store!.append(fix(start + Int64(i) * 1000)) }
    try store!.finish()
    var offset: UInt64 = 0
    var sequences = [Int64]()
    repeat {
      let chunk = try store!.read(otherID, role: "dog", offset: offset, after: 125)
      sequences += (chunk["points"] as! [[String: Any]]).map { ($0["sequence"] as! NSNumber).int64Value }
      offset = (chunk["offset"] as! NSNumber).uint64Value
      if chunk["eof"] as! Bool { break }
    } while true
    try check(sequences == Array(126...600).map(Int64.init), "Paged reads have no gaps or duplicates")
    // Fault injection between filesystem and SQL commits, using the actual DB.
    let empty = try store!.create(["name": "Header interrompu"])
    let emptyID = empty["id"] as! String
    let emptyFile = root.appendingPathComponent("tracks/\(emptyID)/tracer.jsonl")
    try FileManager.default.createDirectory(at: emptyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    let importSource = emptyFile.appendingPathExtension("import")
    try bytes.write(to: importSource)
    try rejects("invalidArgument") { _ = try store!.importTrace(emptyID, role: "tracer", source: importSource.path) }
    try check(try Data(contentsOf: importSource) == bytes, "Import never truncates its own source")
    try FileManager.default.removeItem(at: importSource)
    try Data("{\"type\":\"header\"".utf8).write(to: emptyFile)
    store = nil
    try execute(root, "UPDATE tracks SET dog_status='recording',dog_ended_at=NULL WHERE id='\(otherID)'")
    try execute(root, "UPDATE tracks SET deleted_at=1 WHERE id='\(id)'")
    store = try TrackStore(root: root, schema: schema)
    try check(!FileManager.default.fileExists(atPath: emptyFile.path), "Incomplete orphan header is removed")
    try check(try store!.get(otherID)?["dog_status"] as? String == "finished", "Footer repairs SQL finalization")
    try check(try store!.get(id) == nil && !FileManager.default.fileExists(atPath: path.path), "Interrupted deletion resumes")
    let replacement = try store!.create(["name": "Suppression normale"])
    let replacementID = replacement["id"] as! String
    try store!.start(["trackId": replacementID, "role": "tracer"])
    try rejects("recordingInProgress") { try store!.start(["trackId": replacementID, "role": "dog"]) }
    _ = try store!.append(fix(start))
    try store!.finish()
    try store!.delete(replacementID)
    try check(try store!.get(replacementID) == nil, "Normal deletion")
    try rejects("invalidArgument") { _ = try store!.get("../../outside") }
    print("Storage checks passed: metadata, two roles, immutable import, 1 Hz, live reads, crash recovery, explicit resume, pagination, deletion.")
  }
}
