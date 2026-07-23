import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // App-icon badge: Flutter mirrors the unread-notification count onto the
    // launcher icon via this channel (iOS only; Android shows its launcher
    // dot automatically while a notification is posted).
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "dalali/app_badge", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "setBadgeCount",
                let args = call.arguments as? [String: Any],
                let count = args["count"] as? Int
          else {
            result(FlutterMethodNotImplemented)
            return
          }
          UIApplication.shared.applicationIconBadgeNumber = count
          result(nil)
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
