import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)
    if AppDelegate.isScreenSecurityEnabled {
      AppDelegate.showBlurOverlay()
    }
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    AppDelegate.hideBlurOverlay()
  }
}

