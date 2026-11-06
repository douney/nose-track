import Foundation

/// Boundary between OS acquisition and the app-owned recording implementation.
protocol TraceRecorder: AnyObject {
  var target: [String: String]? { get }
  func start(_ target: [String: Any]) throws
  func append(_ fix: [String: Any]) throws -> [String: Any]?
  func finish() throws
  func session() -> [String: Any]?
}
