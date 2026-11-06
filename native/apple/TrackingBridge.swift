import Foundation
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif

final class TrackingBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let shared = TrackingBridge()
  private let queue = DispatchQueue(label: "com.nosetrack.tracking")
  private var sink: FlutterEventSink?
  private var store: TrackStore?
  private var engine: GeolocationEngine?

  static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let methods = FlutterMethodChannel(name: "nose_track/tracking", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(shared, channel: methods)
    FlutterEventChannel(name: "nose_track/tracking/events", binaryMessenger: messenger).setStreamHandler(shared)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { sink = nil; return nil }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    queue.async {
      do {
        let value = try self.perform(call.method, args)
        DispatchQueue.main.async { result(value) }
      } catch {
        let failure = error as? TrackingFailure
        DispatchQueue.main.async { result(FlutterError(code: failure?.code ?? "storageError",
          message: failure?.message ?? error.localizedDescription, details: nil)) }
      }
    }
  }

  private func perform(_ method: String, _ args: [String: Any]) throws -> Any? {
    if method == "initialize" {
      if store == nil {
        guard let schema = args["schema"] as? String else { throw TrackingFailure("invalidArgument", "Missing schema") }
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true).appendingPathComponent("NoseTrack")
        store = try TrackStore(root: root, schema: schema)
        engine = GeolocationEngine(recorder: store!, queue: queue, emit: emit)
      }
      return engine!.snapshot()
    }
    guard let store, let engine else { throw TrackingFailure("notInitialized", "Initialize tracking first") }
    switch method {
    case "getSnapshot": return engine.snapshot()
    case "setMode":
      try engine.setMode(args["mode"] as? String ?? "", target: args["target"] as? [String: Any]); return nil
    case "createTrack": return try store.create(args)
    case "listTracks": return try store.list(args)
    case "getTrack": return try store.get(trackingID(args["trackId"]))
    case "updateTrack": return try store.update(trackingID(args["trackId"]), changes: args["changes"] as? [String: Any] ?? [:])
    case "deleteTrack": try store.delete(trackingID(args["trackId"])); emit(["type": "journal"]); return nil
    case "importTrace":
      guard let source = args["source"] as? String else { throw TrackingFailure("invalidArgument", "Missing source file") }
      let row = try store.importTrace(trackingID(args["trackId"]), role: trackingRole(args["role"]), source: source)
      emit(["type": "journal"]); return row
    case "readTrack":
      let offset = (args["offset"] as? NSNumber)?.int64Value ?? 0
      let after = (args["afterSequence"] as? NSNumber)?.int64Value ?? 0
      try requireTracking(offset >= 0 && after >= 0, "invalidArgument", "Negative read cursor")
      return try store.read(trackingID(args["trackId"]), role: trackingRole(args["role"]), offset: UInt64(offset), after: after)
    default: throw TrackingFailure("invalidArgument", "Unknown tracking method")
    }
  }
}
