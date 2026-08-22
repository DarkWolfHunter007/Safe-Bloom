import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  public static var isScreenSecurityEnabled = false
  private static let blurOverlayTag = 998877

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
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "setScreenSecurityEnabled" {
          if let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool {
            AppDelegate.isScreenSecurityEnabled = enabled
            result(true)
          } else {
            result(false)
          }
        } else if call.method == "isScreenSecurityEnabled" {
          result(AppDelegate.isScreenSecurityEnabled)
        } else if call.method == "getLocalTimezone" {
          result(TimeZone.current.identifier)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    if AppDelegate.isScreenSecurityEnabled {
      AppDelegate.showBlurOverlay()
    }
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    AppDelegate.hideBlurOverlay()
  }

  public static func showBlurOverlay() {
    guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first else {
      return
    }
    if window.viewWithTag(blurOverlayTag) != nil {
      return
    }

    let blurEffect = UIBlurEffect(style: .extraLight)
    let blurEffectView = UIVisualEffectView(effect: blurEffect)
    blurEffectView.frame = window.bounds
    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurEffectView.tag = blurOverlayTag

    window.addSubview(blurEffectView)
    window.bringSubviewToFront(blurEffectView)
  }

  public static func hideBlurOverlay() {
    for window in UIApplication.shared.windows {
      if let overlay = window.viewWithTag(blurOverlayTag) {
        UIView.animate(withDuration: 0.15, animations: {
          overlay.alpha = 0.0
        }) { _ in
          overlay.removeFromSuperview()
        }
      }
    }
  }
}


