import Flutter
import UIKit
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, WCSessionDelegate {
  private var watchChannel: FlutterMethodChannel?
  private let pendingCommandKey = "rally.pendingWatchCommands"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "rally/watch",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DEALLOCATED", message: nil, details: nil))
        return
      }
      switch call.method {
      case "state":
        self.sendToWatch(call.arguments as? [String: Any] ?? [:])
        result(["connected": WCSession.isSupported() && WCSession.default.isReachable])
      case "status":
        result(["connected": WCSession.isSupported() && WCSession.default.isReachable])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    watchChannel = channel
    drainPendingCommands()

    let deviceChannel = FlutterMethodChannel(
      name: "rally/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    deviceChannel.setMethodCallHandler { call, result in
      guard call.method == "health" else {
        result(FlutterMethodNotImplemented)
        return
      }
      UIDevice.current.isBatteryMonitoringEnabled = true
      let battery = UIDevice.current.batteryLevel
      let rootURL = URL(fileURLWithPath: NSHomeDirectory())
      let values = try? rootURL.resourceValues(
        forKeys: [.volumeAvailableCapacityForImportantUsageKey]
      )
      let available = values?.volumeAvailableCapacityForImportantUsage
      var payload: [String: Any] = [:]
      if let available {
        payload["availableBytes"] = available
      }
      if battery >= 0 {
        payload["batteryPercent"] = Int(battery * 100)
      }
      result(payload)
    }

    if WCSession.isSupported() {
      let session = WCSession.default
      session.delegate = self
      session.activate()
    }
  }

  private func sendToWatch(_ state: [String: Any]) {
    guard WCSession.isSupported(), WCSession.default.isReachable else { return }
    WCSession.default.sendMessage(state, replyHandler: nil, errorHandler: nil)
  }

  private func deliverWatchCommand(_ message: [String: Any]) {
    guard let value = message["value"] as? String,
          ["start", "pause", "resume", "stop", "marker"].contains(value) else {
      return
    }
    guard let channel = watchChannel else {
      var pending = UserDefaults.standard.stringArray(forKey: pendingCommandKey) ?? []
      pending.append(value)
      UserDefaults.standard.set(pending, forKey: pendingCommandKey)
      return
    }
    DispatchQueue.main.async {
      channel.invokeMethod("command", arguments: ["value": value])
    }
  }

  private func drainPendingCommands() {
    let pending = UserDefaults.standard.stringArray(forKey: pendingCommandKey) ?? []
    UserDefaults.standard.removeObject(forKey: pendingCommandKey)
    for value in pending {
      deliverWatchCommand(["value": value])
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    deliverWatchCommand(message)
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
