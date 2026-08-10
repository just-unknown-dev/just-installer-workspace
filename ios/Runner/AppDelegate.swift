import Flutter
import UIKit
import just_downloader

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // UNVERIFIED (see packages/just_downloader/README.md) — required for
  // BackgroundDownloadMode.systemManaged downloads to keep progressing (and
  // to deliver their completion events) after iOS relaunches the app in
  // the background to finish handling a background URLSession's events.
  override func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) {
    BackgroundDownloadManager.shared.backgroundCompletionHandler = completionHandler
  }
}
