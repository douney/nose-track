import Foundation

struct TrackingFailure: Error {
  let code: String
  let message: String
  init(_ code: String, _ message: String) { self.code = code; self.message = message }
}

func requireTracking(_ condition: Bool, _ code: String, _ message: String) throws {
  if !condition { throw TrackingFailure(code, message) }
}

func trackingNow() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

func trackingRole(_ value: Any?) throws -> String {
  guard let role = value as? String, ["tracer", "dog"].contains(role) else {
    throw TrackingFailure("invalidArgument", "Unknown trace role")
  }
  return role
}

func trackingID(_ value: Any?) throws -> String {
  guard let id = value as? String, UUID(uuidString: id) != nil else {
    throw TrackingFailure("invalidArgument", "Invalid track identifier")
  }
  return id.lowercased()
}
