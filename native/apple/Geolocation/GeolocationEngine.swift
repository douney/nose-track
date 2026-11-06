import Foundation

#if os(iOS)
import CoreLocation
import CoreMotion
import UIKit

/// Acquisition and lifecycle only. The store owns journals and catalogue writes.
final class GeolocationEngine: NSObject, CLLocationManagerDelegate {
  private let recorder: TraceRecorder
  private let queue: DispatchQueue
  private let emit: ([String: Any]) -> Void
  private var manager: CLLocationManager!
  private let motion = CMMotionManager()
  private var observers = [NSObjectProtocol]()
  private var visible = false
  private var running = false
  private var headingRunning = false
  private var mode = "off"
  private var acquisition = "stopped"
  private var issue: [String: Any]?
  private var lastPosition: [String: Any]?
  private var lastTimestamp: Int64 = 0
  private var requestedAt: Int64 = 0
  private var headingAccuracy: Double?
  private var motionHeadingAvailable = false
  private var headingRotation: Double = 0
  private var revision: Int64 = 0

  init(recorder: TraceRecorder, queue: DispatchQueue, emit: @escaping ([String: Any]) -> Void) {
    self.recorder = recorder; self.queue = queue; self.emit = emit
    super.init()
    DispatchQueue.main.sync {
      self.visible = UIApplication.shared.applicationState == .active
      self.manager = CLLocationManager()
      self.manager.delegate = self
      self.manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
      self.manager.distanceFilter = kCLDistanceFilterNone
      self.manager.activityType = .fitness
      self.manager.pausesLocationUpdatesAutomatically = false
      self.manager.showsBackgroundLocationIndicator = true
      self.manager.headingFilter = 2
      for notification in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification] {
        self.observers.append(NotificationCenter.default.addObserver(forName: notification,
          object: nil, queue: .main) { [weak self] event in
          guard let self else { return }
          let active = event.name == UIApplication.didBecomeActiveNotification
          self.queue.async { self.visible = active; self.applyAcquisition(); self.publishState() }
        })
      }
    }
  }

  deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

  func snapshot() -> [String: Any] {
    ["state": state(), "lastPosition": lastPosition ?? NSNull()]
  }

  private func state() -> [String: Any] {
    ["revision": revision, "mode": mode, "acquisitionStatus": acquisition,
     "session": recorder.session() ?? NSNull(), "issue": issue ?? NSNull()]
  }

  private func publishState() { revision += 1; emit(["type": "state", "data": state()]) }

  func setMode(_ next: String, target: [String: Any]?) throws {
    try requireTracking(["off", "foreground", "tracking"].contains(next), "invalidArgument", "Unknown mode")
    try requireTracking((next == "tracking") == (target != nil), "invalidArgument", "Invalid recording target")
    if mode == next {
      if next != "tracking" { return }
      if let target, recorder.target?["trackId"] == target["trackId"] as? String
        && recorder.target?["role"] == target["role"] as? String { return }
      throw TrackingFailure("recordingInProgress", "Stop the current recording before changing target")
    }
    if next == "tracking" || mode == "tracking" {
      let active = DispatchQueue.main.sync { UIApplication.shared.applicationState == .active }
      try requireTracking(active, "foregroundRequired", "Recording transitions require the active app")
    }
    if next != "off" {
      let authorized = DispatchQueue.main.sync { () -> Bool in
        let status = self.manager.authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
      }
      try requireTracking(authorized, "permissionDenied", "Location permission is required")
      try requireTracking(CLLocationManager.locationServicesEnabled(), "locationServicesDisabled", "Location is disabled")
    }
    if next == "tracking" { try recorder.start(target!); requestedAt = trackingNow() }
    if mode == "tracking" { try recorder.finish() }
    mode = next; issue = nil; visible = DispatchQueue.main.sync { UIApplication.shared.applicationState == .active }
    applyAcquisition(); publishState(); emit(["type": "journal"])
  }

  private func applyAcquisition() {
    let wanted = mode == "tracking" || (mode == "foreground" && visible)
    let oldRunning = running
    running = wanted
    if wanted && !oldRunning { requestedAt = trackingNow(); acquisition = "waitingForFix" }
    if !wanted { acquisition = "stopped" }
    let background = mode == "tracking"
    let headingWanted = wanted && visible
    DispatchQueue.main.sync {
      self.manager.allowsBackgroundLocationUpdates = background
      if wanted && !oldRunning { self.manager.startUpdatingLocation() }
      if !wanted && oldRunning { self.manager.stopUpdatingLocation() }
      if headingWanted != self.headingRunning {
        self.headingRunning = headingWanted
        if headingWanted {
          self.motionHeadingAvailable = false
          self.updateOrientation()
          self.manager.startUpdatingHeading()
          if self.motion.isDeviceMotionAvailable,
             CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical) {
            self.motion.deviceMotionUpdateInterval = 0.1
            self.motion.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] data, error in
              guard let self else { return }
              if error != nil {
                self.motionHeadingAvailable = false
                self.motion.stopDeviceMotionUpdates()
                return
              }
              guard let data else { return }
              let raw = data.heading
              self.motionHeadingAvailable = raw >= 0
              if !self.motionHeadingAvailable { return }
              let heading = raw >= 0 && self.headingAccuracy != nil
                ? (raw + self.headingRotation).truncatingRemainder(dividingBy: 360) : nil
              self.sendHeading(heading, accuracy: self.headingAccuracy)
            }
          }
        } else {
          self.manager.stopUpdatingHeading(); self.motion.stopDeviceMotionUpdates()
        }
      }
    }
  }

  private func updateOrientation() {
    let orientation = (UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene)?.interfaceOrientation
    switch orientation {
    case .landscapeLeft: manager.headingOrientation = .landscapeRight; headingRotation = 90
    case .landscapeRight: manager.headingOrientation = .landscapeLeft; headingRotation = 270
    case .portraitUpsideDown: manager.headingOrientation = .portraitUpsideDown; headingRotation = 180
    default: manager.headingOrientation = .portrait; headingRotation = 0
    }
  }

  private func sendHeading(_ heading: Double?, accuracy: Double?) {
    let sample: [String: Any] = ["timestamp": trackingNow(),
      "headingDegrees": heading.map { ($0 + 360).truncatingRemainder(dividingBy: 360) } ?? NSNull(),
      "accuracyDegrees": accuracy ?? NSNull()]
    queue.async { if self.visible && self.mode != "off" { self.emit(["type": "heading", "data": sample]) } }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    updateOrientation()
    headingAccuracy = heading.headingAccuracy >= 0 ? heading.headingAccuracy : nil
    if !motionHeadingAvailable || heading.trueHeading < 0 || headingAccuracy == nil {
      sendHeading(heading.trueHeading >= 0 && headingAccuracy != nil ? heading.trueHeading : nil,
                  accuracy: headingAccuracy)
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
      guard location.horizontalAccuracy >= 0, CLLocationCoordinate2DIsValid(location.coordinate) else { continue }
      let fix: [String: Any] = ["timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
        "latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude,
        "accuracyMeters": location.horizontalAccuracy,
        "altitudeMeters": location.verticalAccuracy >= 0 ? location.ellipsoidalAltitude : NSNull(),
        "speedMetersPerSecond": location.speed >= 0 ? location.speed : NSNull(),
        "courseDegrees": location.course >= 0 ? location.course : NSNull()]
      queue.async { self.receive(fix) }
    }
  }

  private func receive(_ fix: [String: Any]) {
    let time = (fix["timestamp"] as! NSNumber).int64Value
    guard running, time >= requestedAt, time - lastTimestamp >= 1000 else { return }
    do {
      if mode == "tracking", try recorder.append(fix) == nil { return }
      lastTimestamp = time; lastPosition = fix; acquisition = "receiving"; issue = nil
      emit(["type": "position", "data": fix])
      if mode == "tracking" { emit(["type": "journal"]) }
      publishState()
    } catch { fail(error) }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    queue.async { self.acquisition = "unavailable"; self.issue = ["code": "locationUnavailable", "message": error.localizedDescription]; self.publishState() }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let permitted = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
    queue.async {
      if self.mode != "off" {
        self.issue = permitted ? nil : ["code": "permissionDenied", "message": "Location permission is unavailable"]
        if !permitted { self.acquisition = "unavailable" }
        self.publishState()
      }
    }
  }

  private func fail(_ error: Error) {
    let failure = error as? TrackingFailure
    issue = ["code": failure?.code ?? "storageError", "message": failure?.message ?? error.localizedDescription]
    acquisition = "unavailable"
    // Preserve the recording and report failure; never silently finalize it.
    publishState()
  }
}
#else
/// macOS is a storage-capable preview, not a phone GPS target.
final class GeolocationEngine {
  init(recorder: TraceRecorder, queue: DispatchQueue, emit: @escaping ([String: Any]) -> Void) {}
  func snapshot() -> [String: Any] { ["state": ["mode": "off", "acquisitionStatus": "stopped",
    "session": NSNull(), "issue": ["code": "unsupportedPlatform", "message": "Phone GPS is unavailable in the Mac preview"]], "lastPosition": NSNull()] }
  func setMode(_ next: String, target: [String: Any]?) throws {
    if next != "off" { throw TrackingFailure("unsupportedPlatform", "Phone GPS is unavailable in the Mac preview") }
  }
}
#endif
