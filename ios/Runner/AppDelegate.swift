import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var isScreenSecurityEnabled = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let controller = engineBridge.pluginRegistry.window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let channel = FlutterMethodChannel(name: "com.example.safe_bloom/screen_security", binaryMessenger: messenger)
      channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "setScreenSecurityEnabled" {
          if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
            self?.isScreenSecurityEnabled = enabled
            result(true)
          } else {
            result(false)
          }
        } else if call.method == "isScreenSecurityEnabled" {
          result(self?.isScreenSecurityEnabled ?? false)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}

