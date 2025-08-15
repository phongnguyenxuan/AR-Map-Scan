/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Contains the application's delegate.
*/

import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Ensure Flutter plugins are registered
        GeneratedPluginRegistrant.register(with: self)

        // Get the FlutterViewController and its messenger
        guard let controller = window?.rootViewController as? FlutterViewController else {
            assertionFailure("RootViewController is not FlutterViewController")
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        let messenger = controller.binaryMessenger

        // Register PlatformView factory so Flutter can embed native AR view via UiKitView
        let factory = ARPlatformViewFactory(messenger: messenger)
        self.registrar(forPlugin: "ARPlatformView")?.register(factory, withId: "ar_platform_view")

        // Setup MethodChannel to control AR from Flutter
        // Must match the channel name used on the Flutter side
        let arChannel = FlutterMethodChannel(name: "ar_persistent_objects", binaryMessenger: messenger)
        arChannel.setMethodCallHandler { call, result in
            ARController.shared.handleMethodCall(call: call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
