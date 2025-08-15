import UIKit
import Flutter
import ARKit
import RealityKit

class ARPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return ARPlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class ARPlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var arView: ARView
    private var arController: ARController

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        // Create AR view
        arView = ARView(frame: frame)
        _view = arView
        arController = ARController.shared

        super.init()

        // Configure AR view
        setupARView()

        // Connect to shared AR controller
        arController.setARView(arView)
    }

    func view() -> UIView {
        return _view
    }

    private func setupARView() {
        // Configure RealityKit AR view
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
        arView.renderOptions.remove(.disablePersonOcclusion)

        // Clean AR view without debug visualization
        arView.debugOptions = [.showFeaturePoints]

        // Set delegates (RealityKit doesn't need ARSCNViewDelegate)
        arView.session.delegate = arController

        // Start AR session immediately when view is set up
        startARSession()
    }

    private func startARSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARKit not supported on this device")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic

        // iOS version compatibility checks
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
        }

        if #available(iOS 13.0, *) {
            if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                configuration.frameSemantics = [.personSegmentationWithDepth]
            }
        }

        arView.session.run(configuration)
        print("AR Session started in Platform View")
    }
}
