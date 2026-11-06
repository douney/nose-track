import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    TrackingBridge.register(with: flutterViewController.registrar(forPlugin: "NoseTrackTracking"))

    title = "NoseTrack · Aperçu mobile"
    contentMinSize = NSSize(width: 620, height: 512)
    setContentSize(NSSize(width: 720, height: 900))
    setFrame(constrainFrameRect(frame, to: screen), display: true)
    center()

    super.awakeFromNib()
  }
}
