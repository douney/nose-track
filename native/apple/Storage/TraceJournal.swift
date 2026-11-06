import Foundation
import CoreFoundation

/// Version 1: UTF-8 JSONL, header, ordered points, optional final end record.
/// The journal is authoritative; incomplete trailing bytes are never published.
final class TraceJournal {
  struct Summary {
    var startedAt: Int64 = 0
    var endedAt: Int64?
    var count: Int64 = 0
    var segment: Int64 = 0
    var lastTimestamp: Int64?
    var firstLatitude: Double?
    var firstLongitude: Double?
    var completeBytes: UInt64 = 0
  }

  static func line(_ object: [String: Any]) throws -> Data {
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    data.append(10)
    return data
  }

  static func validPoint(_ point: [String: Any], sequence: Int64, segment: Int64,
                         previousTimestamp: Int64?) throws {
    guard let seq = point["sequence"] as? NSNumber,
          let seg = point["segmentId"] as? NSNumber,
          let time = point["timestamp"] as? NSNumber,
          let lat = point["latitude"] as? NSNumber,
          let lon = point["longitude"] as? NSNumber else {
      throw TrackingFailure("invalidTrace", "Missing point fields")
    }
    try requireTracking([seq, seg, time, lat, lon].allSatisfy { CFGetTypeID($0) != CFBooleanGetTypeID() },
                        "invalidTrace", "Coordinates and counters must be numbers")
    try requireTracking(seq.doubleValue == Double(sequence) && seg.int64Value >= max(1, segment)
      && seg.doubleValue == Double(seg.int64Value), "invalidTrace", "Invalid point sequence or segment")
    try requireTracking(time.doubleValue.isFinite && time.doubleValue == Double(time.int64Value)
      && time.int64Value >= 0 && (previousTimestamp == nil || time.int64Value > previousTimestamp!),
      "invalidTrace", "Invalid measurement timestamp")
    try requireTracking(lat.doubleValue.isFinite && lon.doubleValue.isFinite
      && (-90...90).contains(lat.doubleValue) && (-180...180).contains(lon.doubleValue),
      "invalidTrace", "Invalid coordinates")
    for key in ["accuracyMeters", "altitudeMeters", "speedMetersPerSecond", "courseDegrees"] {
      if let value = point[key], !(value is NSNull) {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else {
          throw TrackingFailure("invalidTrace", "Invalid \(key)")
        }
        if key != "altitudeMeters" {
          try requireTracking(number.doubleValue >= 0, "invalidTrace", "Negative \(key)")
        }
        if key == "courseDegrees" {
          try requireTracking(number.doubleValue < 360, "invalidTrace", "Invalid course")
        }
      }
    }
  }

  /// Reads bounded blocks and reports byte offsets, including UTF-8 correctly.
  static func records(_ url: URL, offset: UInt64 = 0,
                      visit: ([String: Any], UInt64) throws -> Bool) throws -> UInt64 {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    try handle.seek(toOffset: offset)
    var pending = Data()
    var consumed = offset
    while true {
      let block = try handle.read(upToCount: 65536) ?? Data()
      if block.isEmpty { return consumed }
      pending.append(block)
      while let end = pending.firstIndex(of: 10) {
        let length = pending.distance(from: pending.startIndex, to: end)
        try requireTracking(length <= 65536, "invalidTrace", "Oversized JSONL record")
        let record = pending.prefix(length)
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: record) }
        catch { throw TrackingFailure("invalidTrace", "Malformed JSONL record") }
        guard let object = value as? [String: Any] else {
          throw TrackingFailure("invalidTrace", "A JSONL record must be an object")
        }
        consumed += UInt64(length + 1)
        pending.removeFirst(length + 1)
        if try !visit(object, consumed) { return consumed }
      }
      try requireTracking(pending.count <= 65536, "invalidTrace", "Oversized JSONL record")
    }
  }

  static func inspect(_ url: URL) throws -> Summary {
    var summary = Summary()
    var header = false
    summary.completeBytes = try records(url) { record, _ in
      try requireTracking(summary.endedAt == nil, "invalidTrace", "Records after end")
      switch record["type"] as? String {
      case "header":
        let version = record["version"] as? NSNumber
        try requireTracking(!header && version?.doubleValue == 1
          && CFGetTypeID(version!) != CFBooleanGetTypeID(),
          "invalidTrace", "Invalid JSONL header")
        _ = try trackingID(record["trackId"])
        _ = try trackingRole(record["role"])
        guard let started = record["startedAt"] as? NSNumber,
              CFGetTypeID(started) != CFBooleanGetTypeID(), started.doubleValue.isFinite,
              started.doubleValue == Double(started.int64Value), started.int64Value >= 0 else {
          throw TrackingFailure("invalidTrace", "Missing recording start")
        }
        header = true
        summary.startedAt = started.int64Value
      case "point":
        try requireTracking(header, "invalidTrace", "Missing header")
        try validPoint(record, sequence: summary.count + 1, segment: summary.segment,
                       previousTimestamp: summary.lastTimestamp)
        summary.count += 1
        summary.segment = (record["segmentId"] as! NSNumber).int64Value
        summary.lastTimestamp = (record["timestamp"] as! NSNumber).int64Value
        if summary.firstLatitude == nil {
          summary.firstLatitude = (record["latitude"] as! NSNumber).doubleValue
          summary.firstLongitude = (record["longitude"] as! NSNumber).doubleValue
        }
      case "end":
        try requireTracking(header, "invalidTrace", "Missing header")
        guard let ended = record["endedAt"] as? NSNumber,
              CFGetTypeID(ended) != CFBooleanGetTypeID(), ended.doubleValue.isFinite,
              ended.doubleValue == Double(ended.int64Value), ended.int64Value >= 0 else {
          throw TrackingFailure("invalidTrace", "Missing recording end")
        }
        summary.endedAt = ended.int64Value
      default: throw TrackingFailure("invalidTrace", "Unknown JSONL record")
      }
      return true
    }
    try requireTracking(header, "invalidTrace", "Missing header")
    return summary
  }
}
