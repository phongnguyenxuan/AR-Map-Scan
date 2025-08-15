import UIKit
import ARKit
import RealityKit
import Flutter
import AVFoundation

class ARController: NSObject {
    static let shared = ARController()

    private var arView: ARView?
    private var arSession: ARSession?
    private var currentWorldMap: ARWorldMap?
    private var placedObjects: [String: ModelEntity] = [:]
    private var anchors: [String: AnchorEntity] = [:]
    private var activePlayers: [AVPlayer] = []
    private var isSessionRunning = false
    private var virtualObjectAnchor: ARAnchor?
    private let virtualObjectAnchorName = "virtualObject"
    private var isRelocalizingMap = false
    private var pendingMapNameToLoadObjects: String?
    private var pendingObjectArgs: [String: Any]?
    
    // Video management (simplified - no angle switching)
    private var videoNodes: [String: ModelEntity] = [:]
    
    // Memory management properties
    private var currentPlayer: AVPlayer?
    private var videoObservers: [NSObjectProtocol] = []
    private var isVideoPlaying = false
    
    // MARK: - World Mapping Status Properties
    private var worldMappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    private var trackingState: ARCamera.TrackingState = .notAvailable
    private var mappingStatusText: String = "Not Available"
    private var trackingStatusText: String = "Not Available"
    private var statusUpdateTimer: Timer?
    private var isARControllerActive: Bool = false
    
    // MARK: - UI Status Display
    private var statusOverlayView: UIView?
    private var mappingStatusLabel: UILabel?
    private var trackingStatusLabel: UILabel?
    private var relocalizingLabel: UILabel?
    private var toggleStatusButton: UIButton?

    // Storage for world maps and objects
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private var worldMapsPath: URL {
        return documentsPath.appendingPathComponent("WorldMaps")
    }
    private var objectsDataPath: URL {
        return documentsPath.appendingPathComponent("objects.json")
    }
    
    // MARK: - Export/Import Paths
    private var exportedMapsPath: URL {
        return documentsPath.appendingPathComponent("ExportedMaps")
    }

    override init() {
        super.init()
        setupDirectories()
    }
    
    deinit {
        cleanupVideoResources()
    }
    
    // MARK: - App Lifecycle Management
    
    func pauseVideoPlayback() {
        currentPlayer?.pause()
        isVideoPlaying = false
        print("⏸️ Video playback paused")
    }
    
    func resumeVideoPlayback() {
        if !isVideoPlaying {
            currentPlayer?.play()
            isVideoPlaying = true
            print("▶️ Video playback resumed")
        }
        
        // Resume status updates
        startStatusUpdates()
    }
    
    func cleanupOnBackground() {
        // Pause video to save battery and memory
        pauseVideoPlayback()
        
        // Stop status updates to save battery
        stopStatusUpdates()
        
        // Clear video cache
        URLCache.shared.removeAllCachedResponses()
        
        print("🔋 Cleaned up resources for background")
    }
    
    func disposeARResources() {
        print("🧹 Disposing AR resources...")
        
        // Stop status updates FIRST (before stopping AR session)
        stopStatusUpdates()
        
        // Stop AR session
        arSession?.pause()
        
        // Cleanup video resources
        cleanupVideoResources()
        
        // Remove all placed objects
        for (_, entity) in placedObjects {
            entity.removeFromParent()
        }
        placedObjects.removeAll()
        
        // Remove all anchors
        for (_, anchor) in anchors {
            arView?.scene.removeAnchor(anchor)
        }
        anchors.removeAll()
        
        // Clear current world map
        currentWorldMap = nil
        
        // Reset relocalization state
        isRelocalizingMap = false
        pendingMapNameToLoadObjects = nil
        
        // Clear video nodes
        videoNodes.removeAll()
        
        // Clear video observers
        videoObservers.removeAll()
        
        // Clear active players
        activePlayers.removeAll()
        currentPlayer = nil
        
        // Reset session state
        isSessionRunning = false
        isVideoPlaying = false
        
        // Set AR controller as inactive
        isARControllerActive = false
        
        print("✅ AR resources disposed successfully")
    }

    func setARView(_ view: ARView) {
        arView = view
        arSession = view.session

        // Configure the view for RealityKit with performance optimization
        view.environment.sceneUnderstanding.options = [.occlusion] // Remove physics for better performance
        view.renderOptions.remove(.disablePersonOcclusion)
        
        // Optimize rendering for better performance
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableGroundingShadows)

        // Set delegates
        view.session.delegate = self
        
        // Add native tap gesture recognizer for video placement
        setupNativeTapGesture(for: view)
        
        // Setup status overlay
        setupStatusOverlay()
        
        // Set AR controller as active
        isARControllerActive = true
        
        // Start world mapping status updates
        startStatusUpdates()
    }
    
    private func setupNativeTapGesture(for view: ARView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleNativeTap(_:)))
        view.addGestureRecognizer(tapGesture)
        print("✅ Native tap gesture recognizer added to ARView")
    }
    
    @objc private func handleNativeTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = self.arView else { return }
        
        let location = gesture.location(in: arView)
        print("🎯 Native tap detected at location: \(location)")
        
        // Use the existing handleTap function to display videos
        handleTap(at: location, in: arView)
    }
    
    @objc private func toggleStatusButtonTapped() {
        toggleWorldMappingStatus()
        
        // Update button title based on visibility
        if let overlay = statusOverlayView {
            let buttonTitle = overlay.isHidden ? "📊 Status" : "❌ Hide"
            toggleStatusButton?.setTitle(buttonTitle, for: .normal)
        }
    }

    private func setupDirectories() {
        try? FileManager.default.createDirectory(at: worldMapsPath, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: exportedMapsPath, withIntermediateDirectories: true)
    }

    func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startARSession":
            startARSession(result: result)
        case "pauseARSession":
            pauseARSession(result: result)
        case "resetARSession":
            resetARSession(result: result)
        case "saveWorldMap":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                saveWorldMap(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "loadWorldMap":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                loadWorldMap(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "getAvailableMaps":
            getAvailableMaps(result: result)
        case "deleteWorldMap":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                deleteWorldMap(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "placeObject":
            if let args = call.arguments as? [String: Any] {
                placeObject(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Object arguments required", details: nil))
            }
        case "removeObject":
            if let args = call.arguments as? [String: Any],
               let objectId = args["objectId"] as? String {
                removeObject(objectId: objectId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Object ID required", details: nil))
            }
        case "updateObject":
            if let args = call.arguments as? [String: Any] {
                updateObject(args: args, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Update arguments required", details: nil))
            }
        case "getPlacedObjects":
            getPlacedObjects(result: result)
        case "getARStatus":
            getARStatus(result: result)
        case "getObjectCount":
            getObjectCount(result: result)
        case "getMapCount":
            getMapCount(result: result)
        case "enablePlaneDetection":
            enablePlaneDetection(result: result)
        case "disablePlaneDetection":
            disablePlaneDetection(result: result)
        case "createVideoEntity":
            if let args = call.arguments as? [String: Any],
               let x = args["x"] as? Double,
               let y = args["y"] as? Double,
               let z = args["z"] as? Double,
               let videoPath = args["videoPath"] as? String {
                let position = SIMD3<Float>(Float(x), Float(y), Float(z))
                let videoNode = createVideoEntity(at: position, videoPath: videoPath)
                let objectId = "video_\(Date().timeIntervalSince1970)"
                placedObjects[objectId] = videoNode
                result(objectId)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Position and video path required", details: nil))
            }
        // Removed handleTapAt - now handled natively
        case "handlePanGesture":
            if let args = call.arguments as? [String: Any],
               let objectId = args["objectId"] as? String,
               let dx = args["dx"] as? Double,
               let dy = args["dy"] as? Double {
                let translation = CGPoint(x: dx, y: dy)
                handlePan(translation: translation, for: objectId)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Object ID and translation required", details: nil))
            }
        case "showWorldMappingStatus":
            showWorldMappingStatus()
            result(true)
        case "hideWorldMappingStatus":
            hideWorldMappingStatus()
            result(true)
        case "toggleWorldMappingStatus":
            toggleWorldMappingStatus()
            result(true)
        case "getWorldMappingStatus":
            let status = getCurrentWorldMappingStatus()
            result(status)
        case "exportWorldMap":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                exportWorldMap(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "importWorldMap":
            if let args = call.arguments as? [String: Any],
               let filePath = args["filePath"] as? String {
                importWorldMap(filePath: filePath, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "File path required", details: nil))
            }
        case "getExportFileInfo":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                getExportFileInfo(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "shareExportedMap":
            if let args = call.arguments as? [String: Any],
               let mapName = args["mapName"] as? String {
                shareExportedMap(mapName: mapName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Map name required", details: nil))
            }
        case "getExportedMaps":
            getExportedMaps(result: result)
        case "deleteExportedMap":
            if let args = call.arguments as? [String: Any],
               let fileName = args["fileName"] as? String {
                deleteExportedMap(fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "File name required", details: nil))
            }
        case "disposeARResources":
            disposeARResources()
            result(true)
        case "openExportedMapsInFiles":
            openExportedMapsInFiles(result: result)
        case "getExportedMapsDirectory":
            getExportedMapsDirectory(result: result)
        case "openFilesAppDirectly":
            openFilesAppDirectly(result: result)
        // Removed angle-based video switching methods
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func spawnNode(from args: [String: Any], at transform: simd_float4x4) {
        let videoPath = args["videoPath"] as? String ?? "assets/video_(0).mov"
        let pos = transform.columns.3
        let position = SIMD3<Float>(pos.x, pos.y, pos.z)
        let objectEntity = self.createVideoEntity(at: position, videoPath: videoPath)

        if let scale = args["scale"] as? Double { 
            objectEntity.transform.scale = SIMD3<Float>(Float(scale), Float(scale), Float(scale)) 
        }
        if let rx = args["rotationX"] as? Double { 
            objectEntity.transform.rotation = simd_quatf(angle: Float(rx * .pi / 180), axis: [1, 0, 0]) 
        }
        if let ry = args["rotationY"] as? Double { 
            objectEntity.transform.rotation = simd_quatf(angle: Float(ry * .pi / 180), axis: [0, 1, 0]) 
        }
        if let rz = args["rotationZ"] as? Double { 
            objectEntity.transform.rotation = simd_quatf(angle: Float(rz * .pi / 180), axis: [0, 0, 1]) 
        }

        let objectId = (args["objectId"] as? String) ?? self.virtualObjectAnchorName
        self.placedObjects[objectId] = objectEntity
        if let anchor = self.virtualObjectAnchor {
            // Create AnchorEntity from ARAnchor
            let anchorEntity = AnchorEntity(anchor: anchor)
            self.anchors[objectId] = anchorEntity
        }
        print("Spawned deferred entity at position: \(objectEntity.position)")
    }

    // MARK: - AR Session Management

    private func startARSession(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.isSupported else {
            result(FlutterError(code: "AR_NOT_SUPPORTED", message: "ARKit not supported on this device", details: nil))
            return
        }

        if arView == nil {
            setupARView()
        }

        // Full scanning configuration - match ContentView.swift approach exactly
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        // iOS version compatibility checks
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
                print("✅ Scene reconstruction enabled")
            }
        }

        if #available(iOS 13.0, *) {
            if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                configuration.frameSemantics = [.personSegmentationWithDepth]
                print("✅ Person segmentation enabled")
            } else {
                print("❌ Person segmentation not supported")
            }
        }

        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                configuration.sceneReconstruction = .meshWithClassification
                print("✅ Scene reconstruction with classification enabled")
            }
        }

        // Enable full AR environment (same as ContentView.swift startup)
        if let arView = arView {
            arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
            arView.renderOptions.remove(.disablePersonOcclusion)
            
            // Show feature points for plane detection
            arView.debugOptions = [.showFeaturePoints]
        }

        arSession?.run(configuration)
        isSessionRunning = true
        result(true)
    }

    private func setupARView() {
        // AR View is now set up via Platform View
        // This method is kept for compatibility but ARView setup is handled in setARView
        guard arView == nil else { return }

        // Fallback setup if no platform view is available
        arView = ARView()
        arSession = arView?.session
        arSession?.delegate = self

        // Configure for RealityKit
        arView?.environment.sceneUnderstanding.options = [.occlusion, .physics]
        arView?.renderOptions.remove(.disablePersonOcclusion)
    }

    private func pauseARSession(result: @escaping FlutterResult) {
        arSession?.pause()
        isSessionRunning = false
        result(true)
    }

    private func resetARSession(result: @escaping FlutterResult) {
        arSession?.pause()

        // Cleanup video resources first
        cleanupVideoResources()

        // STOP ALL PLAYERS BEFORE RESET - match ContentView.swift approach
        for (_, entity) in placedObjects {
            entity.removeFromParent()
        }
        placedObjects.removeAll()
        anchors.removeAll()

        // Reset session - match ContentView.swift resetScene approach
        if let arView = arView {
            print("🔄 Resetting and rescanning AR world...")

            // Create optimized tracking configuration for better performance
            let fullConfig = ARWorldTrackingConfiguration()
            fullConfig.planeDetection = .horizontal
            
            // Disable heavy features for better performance
            fullConfig.isLightEstimationEnabled = false
            
            // iOS version compatibility checks with performance optimization
            if #available(iOS 13.4, *) {
                // Use simpler scene reconstruction for better performance
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    fullConfig.sceneReconstruction = .mesh
                }
            }

            if #available(iOS 13.0, *) {
                // Only enable person segmentation if needed
                if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                    fullConfig.frameSemantics = [.personSegmentationWithDepth]
                }
            }

            // Enable optimized AR environment for better performance
            arView.environment.sceneUnderstanding.options = [.occlusion] // Remove physics for better performance
            arView.renderOptions.remove(.disablePersonOcclusion)

            // Show feature points for plane detection
            arView.debugOptions = [.showFeaturePoints]

            // IMPORTANT: Use reset options to completely restart world tracking
            arView.session.run(fullConfig, options: [
                .resetTracking,           // Reset tracking state
                .removeExistingAnchors,   // Remove all existing anchors
                .resetSceneReconstruction // Reset scene understanding
            ])

            print("✅ AR world reset complete - ready for new placement")
        }

        isSessionRunning = true
        result(true)
    }

    // MARK: - World Map Management

    private func saveWorldMap(mapName: String, result: @escaping FlutterResult) {
        guard let session = arSession else {
            result(FlutterError(code: "NO_SESSION", message: "AR session not active", details: nil))
            return
        }

        session.getCurrentWorldMap { [weak self] worldMap, error in
            DispatchQueue.main.async {
                if let error = error {
                    result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                    return
                }

                guard let worldMap = worldMap else {
                    result(FlutterError(code: "NO_WORLD_MAP", message: "Could not get current world map", details: nil))
                    return
                }

                // Append a snapshot anchor like ViewController.saveExperience
                if let view = self?.arView,
                   let snapshotAnchorClass = NSClassFromString("SnapshotAnchor") as? NSObject.Type,
                   let snapshotAnchor = (snapshotAnchorClass as? AnyObject)?.perform(NSSelectorFromString("capturing:"), with: view)?.takeUnretainedValue() as? ARAnchor {
                    worldMap.anchors.append(snapshotAnchor)
                }

                do {
                    let mapData = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
                    let mapURL = self?.worldMapsPath.appendingPathComponent("\(mapName).worldmap")
                    try mapData.write(to: mapURL!, options: [.atomic])

                    // Save object data
                    self?.saveObjectData(for: mapName)

                    result(true)
                } catch {
                    result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    private func loadWorldMap(mapName: String, result: @escaping FlutterResult) {
        let mapURL = worldMapsPath.appendingPathComponent("\(mapName).worldmap")

        guard FileManager.default.fileExists(atPath: mapURL.path) else {
            result(FlutterError(code: "MAP_NOT_FOUND", message: "World map not found", details: nil))
            return
        }

        do {
            let mapData = try Data(contentsOf: mapURL)
            let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: mapData)

            guard let worldMap = worldMap else {
                result(FlutterError(code: "LOAD_ERROR", message: "Could not load world map", details: nil))
                return
            }

            // Remove any SnapshotAnchor before running, like ViewController.loadExperience
            worldMap.anchors.removeAll(where: { String(describing: type(of: $0)) == "SnapshotAnchor" })

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal, .vertical]
            configuration.initialWorldMap = worldMap

            // Clear existing objects before loading new map
            cleanupVideoResources()
            for (_, entity) in placedObjects {
                entity.removeFromParent()
            }
            for (_, anchor) in anchors {
                arView?.scene.removeAnchor(anchor)
            }
            placedObjects.removeAll()
            anchors.removeAll()

            arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            currentWorldMap = worldMap

            // Set up relocalization tracking
            isRelocalizingMap = true
            pendingMapNameToLoadObjects = mapName
            
            print("🔄 Starting relocalization for map: \(mapName)")
            print("🌍 Waiting for world mapping status: Mapped")
            print("📱 Waiting for tracking state: Normal")
            print("✅ World map loaded successfully with VideoCameraKit: \(mapName)")
            result(true)
        } catch {
            result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    private func getAvailableMaps(result: @escaping FlutterResult) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: worldMapsPath, includingPropertiesForKeys: nil)
            let mapNames = files.compactMap { url -> String? in
                // Only check for .worldmap extension
                guard url.pathExtension == "worldmap" else { return nil }
                return url.deletingPathExtension().lastPathComponent
            }
            
            // Filter maps that have both worldmap and objects files
            let validMapNames = mapNames.filter { mapName in
                let worldMapURL = worldMapsPath.appendingPathComponent("\(mapName).worldmap")
                let objectsURL = worldMapsPath.appendingPathComponent("\(mapName)_objects.json")
                return FileManager.default.fileExists(atPath: worldMapURL.path) &&
                       FileManager.default.fileExists(atPath: objectsURL.path)
            }
            
            print("🔍 Debug: Found \(mapNames.count) total maps, \(validMapNames.count) valid maps")
            print("🔍 Debug: Valid maps: \(validMapNames)")
            
            result(validMapNames)
        } catch {
            print("❌ Error getting available maps: \(error)")
            result([])
        }
    }

    private func deleteWorldMap(mapName: String, result: @escaping FlutterResult) {
        let mapURL = worldMapsPath.appendingPathComponent("\(mapName).worldmap")

        do {
            try FileManager.default.removeItem(at: mapURL)
            result(true)
        } catch {
            result(FlutterError(code: "DELETE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Object Management

    private func placeObject(args: [String: Any], result: @escaping FlutterResult) {
        // This method is now replaced by native tap handling
        // All video placement is handled via handleNativeTap
        result(FlutterError(code: "DEPRECATED", message: "Use native tap handling instead", details: nil))
    }

    // This function is no longer needed as we use RealityKit's createVideoEntity
    
    // This function is no longer needed as we use RealityKit's VideoMaterial

    private func removeObject(objectId: String, result: @escaping FlutterResult) {
        guard let entity = placedObjects[objectId] else {
            result(FlutterError(code: "OBJECT_NOT_FOUND", message: "Object not found", details: nil))
            return
        }

        entity.removeFromParent()
        placedObjects.removeValue(forKey: objectId)

        if let anchor = anchors[objectId] {
            arView?.scene.removeAnchor(anchor)
            anchors.removeValue(forKey: objectId)
        }

        result(true)
    }

    private func updateObject(args: [String: Any], result: @escaping FlutterResult) {
        guard let objectId = args["objectId"] as? String,
              let entity = placedObjects[objectId] else {
            result(FlutterError(code: "OBJECT_NOT_FOUND", message: "Object not found", details: nil))
            return
        }

        if let scale = args["scale"] as? Double {
            entity.transform.scale = SIMD3<Float>(Float(scale), Float(scale), Float(scale))
        }

        if let rotationX = args["rotationX"] as? Double {
            entity.transform.rotation = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
        }

        if let rotationY = args["rotationY"] as? Double {
            entity.transform.rotation = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
        }

        if let rotationZ = args["rotationZ"] as? Double {
            entity.transform.rotation = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
        }

        result(true)
    }

    private func getPlacedObjects(result: @escaping FlutterResult) {
        var objectsData: [[String: Any]] = []

        for (objectId, entity) in placedObjects {
            var objectData: [String: Any] = [
                "objectId": objectId,
                "positionX": entity.position.x,
                "positionY": entity.position.y,
                "positionZ": entity.position.z,
                "rotationX": entity.transform.rotation.angle * 180 / .pi,
                "rotationY": entity.transform.rotation.angle * 180 / .pi,
                "rotationZ": entity.transform.rotation.angle * 180 / .pi,
                "scale": entity.transform.scale.x,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]

            // Add type-specific data
            if entity.model?.materials.first is VideoMaterial {
                objectData["objectType"] = "video"
                let name = entity.name ?? ""
                if !name.isEmpty {
                    objectData["content"] = name
                }
            } else {
                objectData["objectType"] = "model"
            }

            objectsData.append(objectData)
        }

        result(objectsData)
    }

    // MARK: - Status and Statistics

    private func getARStatus(result: @escaping FlutterResult) {
        if isSessionRunning {
            result("Running")
        } else {
            result("Stopped")
        }
    }

    private func getObjectCount(result: @escaping FlutterResult) {
        result(placedObjects.count)
    }

    private func getMapCount(result: @escaping FlutterResult) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: worldMapsPath, includingPropertiesForKeys: nil)
            let mapCount = files.filter { $0.pathExtension == "arworldmap" }.count
            result(mapCount)
        } catch {
            result(0)
        }
    }

    private func enablePlaneDetection(result: @escaping FlutterResult) {
        guard let session = arSession else {
            result(false)
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration)
        result(true)
    }

    private func disablePlaneDetection(result: @escaping FlutterResult) {
        guard let session = arSession else {
            result(false)
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        session.run(configuration)
        result(true)
    }
    
    // MARK: - Tracking Mode Management (like ContentView.swift)
    
    private func switchToMinimalTracking() {
        guard let arView = self.arView else { return }

        print("🔄 Switching to minimal AR tracking mode (with occlusion)")
        
        // Minimal config but keep some tracking features for better SLAM
        let minimalConfig = ARWorldTrackingConfiguration()
        minimalConfig.planeDetection = [] // No plane detection
        minimalConfig.isLightEstimationEnabled = true // Re-enable for better tracking

        // Keep depth for better SLAM quality
        if #available(iOS 13.0, *) {
            if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                minimalConfig.frameSemantics = [.personSegmentationWithDepth]
                print("✅ Person segmentation enabled for occlusion")
            } else {
                print("❌ Person segmentation not supported on this device")
            }
        }

        arView.session.run(minimalConfig, options: [])

        // Remove debug options but keep occlusion
        arView.debugOptions = []

        // CRITICAL: Enable occlusion and person occlusion
        arView.environment.sceneUnderstanding.options = [.occlusion]
        arView.renderOptions.remove(.disablePersonOcclusion)

        print("🔍 Occlusion settings:")
        print("   - Scene understanding: \(arView.environment.sceneUnderstanding.options)")
        print("   - Person occlusion enabled: \(!arView.renderOptions.contains(.disablePersonOcclusion))")

        print("✅ Minimal mode with occlusion activated")
    }
    
    private func switchToFullTracking() {
        guard let arView = self.arView else { return }

        print("🔄 Switching to full AR tracking mode")
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
        }

        arView.session.run(configuration)
        arView.debugOptions = [.showFeaturePoints]
        
        print("✅ Full tracking mode activated")
    }
    
    // MARK: - Enhanced Video Entity Creation (RealityKit-style)
    
    private func createVideoEntity(at position: SIMD3<Float>, videoPath: String) -> ModelEntity {
        // Load video from Flutter assets instead of Bundle.main
        let videoFileName = videoPath.replacingOccurrences(of: "assets/", with: "")
        guard let videoURL = getFlutterAssetURL(for: videoFileName) else {
            print("❌ Video asset not found: \(videoPath)")
            return createFallbackVideoEntity(at: position)
        }
        
        // Create player - match ContentView.swift approach exactly
        print("🎬 Creating AVPlayer with URL: \(videoURL)")
        
        // Cleanup previous player if exists
        cleanupVideoResources()
        
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .none
        
        // Store current player for cleanup
        currentPlayer = player
        activePlayers.append(player)
        
        // Get video dimensions with memory optimization
        let asset = AVURLAsset(url: videoURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        var dimensions = CGSize(width: 16, height: 9) // Default
        
        // Try to get actual video dimensions with timeout
        let semaphore = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            defer { semaphore.signal() }
            
            if let track = asset.tracks(withMediaType: .video).first {
                dimensions = track.naturalSize
                print("📐 Video dimensions: \(dimensions)")
            } else {
                print("⚠️ Could not get video track, using default dimensions")
            }
        }
        
        // Wait for dimensions with timeout (max 1 second for better performance)
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        // Dynamic sizing based on aspect ratio with performance optimization
        let videoRatio = Float(dimensions.width / dimensions.height)
        let maxDimension: Float = 1.5 // Reduced for better performance
        
        let width: Float
        let height: Float
        
        if videoRatio > 1.0 {
            // Landscape video (16:9, etc.)
            width = maxDimension
            height = maxDimension / videoRatio
        } else {
            // Portrait video (9:16, etc.) or square
            height = maxDimension
            width = maxDimension * videoRatio
        }
        
        let halfWidth = width / 2
        
        // Add video looping observer using memory management
        addVideoObserver(for: player)
        
        let videoMaterial = VideoMaterial(avPlayer: player)
        
        // VideoMaterial is already optimized for video playback
        // No additional parameters needed for RealityKit VideoMaterial
        // RealityKit automatically handles video optimization
        
        print("📹 Created optimized VideoMaterial for H.265+Alpha video")
        
        var descriptor = MeshDescriptor(name: "videoPlane")
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-halfWidth, 0.0, 0.0),
            SIMD3<Float>(halfWidth, 0.0, 0.0),
            SIMD3<Float>(-halfWidth, height, 0.0),
            SIMD3<Float>(halfWidth, height, 0.0)
        ]
        
        let textureCoords: [SIMD2<Float>] = [
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(1.0, 1.0),
            SIMD2<Float>(0.0, 1.0)
        ]
        
        descriptor.positions = MeshBuffer(vertices)
        descriptor.textureCoordinates = MeshBuffer(textureCoords)
        descriptor.primitives = .triangles([0, 2, 1, 1, 2, 3])
        
        do {
            let videoMesh = try MeshResource.generate(from: [descriptor])
            let entity = ModelEntity(mesh: videoMesh, materials: [videoMaterial])
            let anchor = AnchorEntity(world: position)
            
            if let arView = self.arView,
               let camera = arView.session.currentFrame?.camera {
                let cameraPosition = camera.transform.columns.3
                let direction = normalize(SIMD3<Float>(
                    cameraPosition.x - position.x,
                    0,
                    cameraPosition.z - position.z
                ))
                let angle = atan2(direction.x, direction.z)
                entity.setOrientation(simd_quatf(angle: angle + .pi, axis: [0, 1, 0]), relativeTo: anchor)
            }
            
            anchor.addChild(entity)
            arView?.scene.addAnchor(anchor)
            
            // Track anchor and entity for proper management
            let objectId = "currentVideo"
            anchors[objectId] = anchor
            placedObjects[objectId] = entity
            
            // Store video path for reference
            entity.name = videoPath
            
            // Start playback with memory optimization
            print("▶️ Starting video playback")
            player.play()
            isVideoPlaying = true
            
            // Set video quality for better performance
            player.currentItem?.preferredForwardBufferDuration = 1.0
            
            // Optimize video playback settings
            player.automaticallyWaitsToMinimizeStalling = false
            
                    print("✅ Optimized video entity created at position: \(position) with aspect ratio: \(videoRatio)")
        print("📹 Video dimensions: \(dimensions), calculated size: \(width)x\(height)")
        print("🔗 Anchor created with ID: \(objectId)")
        print("📦 Video entity stored in placedObjects")
        print("🎬 Video playback started with memory optimization")
        print("🎯 Video URL: \(videoURL)")
        print("⚡ Performance optimizations applied")
        print("🔋 Battery and memory optimized")
        print("🎯 VideoMaterial optimized for RealityKit")
            
            return entity
            
        } catch {
            print("❌ Error creating video entity: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            return createFallbackVideoEntity(at: position)
        }
    }
    
    private func createFallbackVideoEntity(at position: SIMD3<Float>) -> ModelEntity {
        // Fallback to original method if video loading fails
        print("🔄 Using fallback video entity")
        let fallbackEntity = createVideoEntity(at: position, videoPath: "assets/video_(0).mov")
        return fallbackEntity
    }
    
    private func createVideoEntityWithoutAnchor(videoPath: String) -> ModelEntity {
        // Create video entity without anchor for restoration purposes
        guard let videoURL = getFlutterAssetURL(for: videoPath.replacingOccurrences(of: "assets/", with: "")) else {
            print("❌ Video asset not found: \(videoPath)")
            return createFallbackVideoEntityWithoutAnchor()
        }
        
        // Create player - match ContentView.swift approach exactly
        print("🎬 Creating AVPlayer with URL: \(videoURL)")
        
        // Cleanup previous player if exists
        cleanupVideoResources()
        
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .none
        
        // Store current player for cleanup
        currentPlayer = player
        activePlayers.append(player)
        
        // Get video dimensions with memory optimization
        let asset = AVURLAsset(url: videoURL, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        var dimensions = CGSize(width: 16, height: 9) // Default
        
        // Try to get actual video dimensions with timeout
        let semaphore = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            defer { semaphore.signal() }
            
            if let track = asset.tracks(withMediaType: .video).first {
                dimensions = track.naturalSize
                print("📐 Video dimensions: \(dimensions)")
            } else {
                print("⚠️ Could not get video track, using default dimensions")
            }
        }
        
        // Wait for dimensions with timeout (max 1 second for better performance)
        _ = semaphore.wait(timeout: .now() + 1.0)
        
        // Dynamic sizing based on aspect ratio with performance optimization
        let videoRatio = Float(dimensions.width / dimensions.height)
        let maxDimension: Float = 1.5 // Reduced for better performance
        
        let width: Float
        let height: Float
        
        if videoRatio > 1.0 {
            // Landscape video (16:9, etc.)
            width = maxDimension
            height = maxDimension / videoRatio
        } else {
            // Portrait video (9:16, etc.) or square
            height = maxDimension
            width = maxDimension * videoRatio
        }
        
        let halfWidth = width / 2
        
        // Add video looping observer using memory management
        addVideoObserver(for: player)
        
        let videoMaterial = VideoMaterial(avPlayer: player)
        
        // VideoMaterial is already optimized for video playback
        // No additional parameters needed for RealityKit VideoMaterial
        // RealityKit automatically handles video optimization
        
        print("📹 Created optimized VideoMaterial for H.265+Alpha video")
        
        var descriptor = MeshDescriptor(name: "videoPlane")
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-halfWidth, 0.0, 0.0),
            SIMD3<Float>(halfWidth, 0.0, 0.0),
            SIMD3<Float>(-halfWidth, height, 0.0),
            SIMD3<Float>(halfWidth, height, 0.0)
        ]
        
        let textureCoords: [SIMD2<Float>] = [
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(1.0, 1.0),
            SIMD2<Float>(0.0, 1.0)
        ]
        
        descriptor.positions = MeshBuffer(vertices)
        descriptor.textureCoordinates = MeshBuffer(textureCoords)
        descriptor.primitives = .triangles([0, 2, 1, 1, 2, 3])
        
        do {
            let videoMesh = try MeshResource.generate(from: [descriptor])
            let entity = ModelEntity(mesh: videoMesh, materials: [videoMaterial])
            
            // Store video path for reference
            entity.name = videoPath
            
            // Start playback with memory optimization
            print("▶️ Starting video playback")
            player.play()
            isVideoPlaying = true
            
            // Set video quality for better performance
            player.currentItem?.preferredForwardBufferDuration = 1.0
            
            // Optimize video playback settings
            player.automaticallyWaitsToMinimizeStalling = false
            
            print("✅ Optimized video entity created without anchor")
            print("📹 Video dimensions: \(dimensions), calculated size: \(width)x\(height)")
            print("🎬 Video playback started with memory optimization")
            print("🎯 Video URL: \(videoURL)")
            print("⚡ Performance optimizations applied")
            print("🔋 Battery and memory optimized")
            print("🎯 VideoMaterial optimized for RealityKit")
            
            return entity
            
        } catch {
            print("❌ Error creating video entity: \(error)")
            print("🔍 Error details: \(error.localizedDescription)")
            return createFallbackVideoEntityWithoutAnchor()
        }
    }
    
    private func createFallbackVideoEntityWithoutAnchor() -> ModelEntity {
        // Fallback to create a simple video entity without anchor
        print("🔄 Using fallback video entity without anchor")
        return createVideoEntityWithoutAnchor(videoPath: "assets/video_(0).mov")
    }
    
    // MARK: - VideoCameraKit Approach (Original Working Version)
    
    private func createVideoEntityWithVideoCameraKit(at position: SIMD3<Float>, videoPath: String) -> ModelEntity {
        // Create video entity using VideoCameraKit approach for precise positioning
        guard let videoURL = getFlutterAssetURL(for: videoPath.replacingOccurrences(of: "assets/", with: "")) else {
            print("❌ Video asset not found: \(videoPath)")
            return createFallbackVideoEntityWithVideoCameraKit(at: position)
        }
        
        // Create player with VideoCameraKit optimization
        print("🎬 Creating AVPlayer with VideoCameraKit approach: \(videoURL)")
        
        // Cleanup previous player if exists
        cleanupVideoResources()
        
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .none
        
        // Store current player for cleanup
        currentPlayer = player
        activePlayers.append(player)
        
        // Get video dimensions with VideoCameraKit approach
        let asset = AVURLAsset(url: videoURL)
        var dimensions = CGSize(width: 16, height: 9) // Default
        
        // Get video dimensions synchronously for VideoCameraKit
        if let track = asset.tracks(withMediaType: .video).first {
            dimensions = track.naturalSize
            print("📐 Video dimensions: \(dimensions)")
        }
        
        // Dynamic sizing based on aspect ratio - VideoCameraKit approach
        let videoRatio = Float(dimensions.width / dimensions.height)
        let maxDimension: Float = 2.0 // VideoCameraKit uses larger size for better visibility
        
        let width: Float
        let height: Float
        
        if videoRatio > 1.0 {
            // Landscape video (16:9, etc.)
            width = maxDimension
            height = maxDimension / videoRatio
        } else {
            // Portrait video (9:16, etc.) or square
            height = maxDimension
            width = maxDimension * videoRatio
        }
        
        let halfWidth = width / 2
        
        // Add video looping observer using VideoCameraKit approach
        addVideoObserver(for: player)
        
        let videoMaterial = VideoMaterial(avPlayer: player)
        
        print("📹 Created VideoMaterial with VideoCameraKit optimization")
        
        var descriptor = MeshDescriptor(name: "videoPlane")
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-halfWidth, 0.0, 0.0),
            SIMD3<Float>(halfWidth, 0.0, 0.0),
            SIMD3<Float>(-halfWidth, height, 0.0),
            SIMD3<Float>(halfWidth, height, 0.0)
        ]
        
        let textureCoords: [SIMD2<Float>] = [
            SIMD2<Float>(1.0, 0.0),
            SIMD2<Float>(0.0, 0.0),
            SIMD2<Float>(1.0, 1.0),
            SIMD2<Float>(0.0, 1.0)
        ]
        
        descriptor.positions = MeshBuffer(vertices)
        descriptor.textureCoordinates = MeshBuffer(textureCoords)
        descriptor.primitives = .triangles([0, 2, 1, 1, 2, 3])
        
        do {
            let videoMesh = try MeshResource.generate(from: [descriptor])
            let entity = ModelEntity(mesh: videoMesh, materials: [videoMaterial])
            
            // Create anchor at world position for VideoCameraKit (entity will be at origin relative to anchor)
            let anchor = AnchorEntity(world: position)
            
            // Entity should be at origin relative to anchor (not set position again)
            // This ensures the entity appears exactly at the anchor's world position
            
            if let arView = self.arView,
               let camera = arView.session.currentFrame?.camera {
                let cameraPosition = camera.transform.columns.3
                let direction = normalize(SIMD3<Float>(
                    cameraPosition.x - position.x,
                    0,
                    cameraPosition.z - position.z
                ))
                let angle = atan2(direction.x, direction.z)
                entity.setOrientation(simd_quatf(angle: angle + .pi, axis: [0, 1, 0]), relativeTo: anchor)
            }
            
            anchor.addChild(entity)
            arView?.scene.addAnchor(anchor)
            
            // Store video path for reference
            entity.name = videoPath
            
            // Start playback with VideoCameraKit optimization
            print("▶️ Starting video playback with VideoCameraKit")
            player.play()
            isVideoPlaying = true
            
            // VideoCameraKit optimized settings
            player.currentItem?.preferredForwardBufferDuration = 2.0
            player.automaticallyWaitsToMinimizeStalling = true
            
            print("✅ VideoCameraKit video entity created at world position: \(position)")
            print("📹 Video dimensions: \(dimensions), calculated size: \(width)x\(height)")
            print("🎬 Video playback started with VideoCameraKit optimization")
            print("🎯 Video positioned at exact saved world coordinates")
            print("⚡ VideoCameraKit approach for precise positioning")
            print("📍 Anchor world position: \(position)")
            print("📍 Entity local position: \(entity.position) (should be near origin)")
            
            return entity
            
        } catch {
            print("❌ Error creating VideoCameraKit video entity: \(error)")
            return createFallbackVideoEntityWithVideoCameraKit(at: position)
        }
    }
    
    private func createFallbackVideoEntityWithVideoCameraKit(at position: SIMD3<Float>) -> ModelEntity {
        // Fallback to create a simple video entity with VideoCameraKit approach
        print("🔄 Using fallback VideoCameraKit video entity")
        return createVideoEntityWithVideoCameraKit(at: position, videoPath: "assets/video_(0).mov")
    }
    
    // MARK: - Debug World Positioning
    
    private func debugWorldPositioning() {
        print("🔍 === DEBUG WORLD POSITIONING ===")
        for (objectId, entity) in placedObjects {
            let localPosition = entity.position
            let worldPosition = entity.position(relativeTo: nil)
            
            if let anchor = entity.parent as? AnchorEntity {
                let anchorWorldPosition = anchor.position(relativeTo: nil)
                print("🎯 Object \(objectId):")
                print("   Local position: \(localPosition)")
                print("   Entity world position: \(worldPosition)")
                print("   Anchor world position: \(anchorWorldPosition)")
            } else {
                print("🎯 Object \(objectId):")
                print("   Local position: \(localPosition)")
                print("   World position: \(worldPosition)")
            }
        }
        print("🔍 === END DEBUG ===")
    }
    
    // MARK: - World Mapping Status Display
    
    private func updateWorldMappingStatus(_ frame: ARFrame) {
        // Only update status if AR controller is active
        guard isARControllerActive else {
            return
        }
        
        let newMappingStatus = frame.worldMappingStatus
        let newTrackingState = frame.camera.trackingState
        
        // Update status texts
        mappingStatusText = getMappingStatusText(newMappingStatus)
        trackingStatusText = getTrackingStatusText(newTrackingState)
        
        // Update stored values
        worldMappingStatus = newMappingStatus
        trackingState = newTrackingState
        
        // Update UI
        updateStatusUI()
        
        // Send status to Flutter
        sendStatusToFlutter()
        
        // Log status changes
        print("🌍 World Mapping Status: \(mappingStatusText)")
        print("📱 Tracking Status: \(trackingStatusText)")
    }
    
    private func getMappingStatusText(_ status: ARFrame.WorldMappingStatus) -> String {
        switch status {
        case .notAvailable:
            return "Not Available"
        case .limited:
            return "Limited"
        case .extending:
            return "Extending"
        case .mapped:
            return "Mapped"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func getTrackingStatusText(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .notAvailable:
            return "Not Available"
        case .limited(let reason):
            switch reason {
            case .initializing:
                return "Initializing"
            case .excessiveMotion:
                return "Excessive Motion"
            case .insufficientFeatures:
                return "Insufficient Features"
            case .relocalizing:
                return "Relocalizing"
            @unknown default:
                return "Limited (Unknown)"
            }
        case .normal:
            return "Normal"
        }
    }
    
    private func sendStatusToFlutter() {
        let statusData: [String: Any] = [
            "mappingStatus": mappingStatusText,
            "trackingStatus": trackingStatusText,
            "isRelocalizing": isRelocalizingMap,
            "hasWorldMap": currentWorldMap != nil
        ]
        
        // Send to Flutter via method channel
        if let methodChannel = getMethodChannel() {
            methodChannel.invokeMethod("onWorldMappingStatusUpdate", arguments: statusData)
        }
        
        print("📡 Sent status to Flutter: \(statusData)")
    }
    
    private func getMethodChannel() -> FlutterMethodChannel? {
        // Get the method channel from Flutter
        // This assumes you have a way to access the method channel
        // You might need to store it as a property or pass it through
        return nil // Placeholder - implement based on your Flutter setup
    }
    
    // MARK: - Public Status Methods for Flutter
    
    func getCurrentWorldMappingStatus() -> [String: Any] {
        return [
            "mappingStatus": mappingStatusText,
            "trackingStatus": trackingStatusText,
            "isRelocalizing": isRelocalizingMap,
            "hasWorldMap": currentWorldMap != nil,
            "placedObjectsCount": placedObjects.count
        ]
    }
    
    func startWorldMappingStatusUpdates() {
        startStatusUpdates()
    }
    
    func stopWorldMappingStatusUpdates() {
        stopStatusUpdates()
    }
    
    // MARK: - UI Status Control
    
    func showWorldMappingStatus() {
        showStatusOverlay()
    }
    
    func hideWorldMappingStatus() {
        hideStatusOverlay()
    }
    
    func toggleWorldMappingStatus() {
        if let overlay = statusOverlayView {
            overlay.isHidden.toggle()
        }
    }
    
    private func startStatusUpdates() {
        // Only start updates if AR controller is active
        guard isARControllerActive else {
            print("⚠️ Cannot start status updates - AR controller not active")
            return
        }
        
        // Start timer to update status every 1 second
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isARControllerActive else {
                // Stop timer if controller is no longer active
                self?.statusUpdateTimer?.invalidate()
                self?.statusUpdateTimer = nil
                return
            }
            
            if let arView = self.arView,
               let frame = arView.session.currentFrame {
                self.updateWorldMappingStatus(frame)
            }
        }
        print("🔄 Started world mapping status updates")
    }
    
    // MARK: - UI Status Display
    
    private func setupStatusOverlay() {
        guard let arView = self.arView else { return }
        
        // Create overlay view
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.layer.cornerRadius = 12
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create mapping status label
        let mappingLabel = UILabel()
        mappingLabel.textColor = .white
        mappingLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        mappingLabel.text = "🌍 Mapping: Not Available"
        mappingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create tracking status label
        let trackingLabel = UILabel()
        trackingLabel.textColor = .white
        trackingLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        trackingLabel.text = "📱 Tracking: Not Available"
        trackingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create relocalizing label
        let relocalizingLabel = UILabel()
        relocalizingLabel.textColor = .yellow
        relocalizingLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        relocalizingLabel.text = "🔄 Relocalizing..."
        relocalizingLabel.isHidden = true
        relocalizingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to overlay
        overlayView.addSubview(mappingLabel)
        overlayView.addSubview(trackingLabel)
        overlayView.addSubview(relocalizingLabel)
        
        // Add overlay to AR view
        arView.addSubview(overlayView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Overlay constraints
            overlayView.topAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.topAnchor, constant: 20),
            overlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor, constant: 20),
            overlayView.trailingAnchor.constraint(lessThanOrEqualTo: arView.trailingAnchor, constant: -20),
            
            // Mapping label constraints
            mappingLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 12),
            mappingLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            mappingLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12),
            
            // Tracking label constraints
            trackingLabel.topAnchor.constraint(equalTo: mappingLabel.bottomAnchor, constant: 4),
            trackingLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            trackingLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12),
            
            // Relocalizing label constraints
            relocalizingLabel.topAnchor.constraint(equalTo: trackingLabel.bottomAnchor, constant: 4),
            relocalizingLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 12),
            relocalizingLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -12),
            relocalizingLabel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -12)
        ])
        
        // Create toggle button
        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle("📊 Status", for: .normal)
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toggleButton.layer.cornerRadius = 8
        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.addTarget(self, action: #selector(toggleStatusButtonTapped), for: .touchUpInside)
        
        // Add toggle button to AR view
        arView.addSubview(toggleButton)
        
        // Setup toggle button constraints
        NSLayoutConstraint.activate([
            toggleButton.topAnchor.constraint(equalTo: arView.safeAreaLayoutGuide.topAnchor, constant: 20),
            toggleButton.trailingAnchor.constraint(equalTo: arView.trailingAnchor, constant: -20),
            toggleButton.widthAnchor.constraint(equalToConstant: 80),
            toggleButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Store references
        self.statusOverlayView = overlayView
        self.mappingStatusLabel = mappingLabel
        self.trackingStatusLabel = trackingLabel
        self.relocalizingLabel = relocalizingLabel
        self.toggleStatusButton = toggleButton
        
        print("✅ Status overlay setup completed")
    }
    
    private func updateStatusUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update mapping status
            self.mappingStatusLabel?.text = "🌍 Mapping: \(self.mappingStatusText)"
            
            // Update tracking status
            self.trackingStatusLabel?.text = "📱 Tracking: \(self.trackingStatusText)"
            
            // Update relocalizing status
            if self.isRelocalizingMap {
                self.relocalizingLabel?.isHidden = false
                self.relocalizingLabel?.text = "🔄 Relocalizing..."
            } else {
                self.relocalizingLabel?.isHidden = true
            }
            
            // Update colors based on status
            self.updateStatusColors()
        }
    }
    
    private func updateStatusColors() {
        // Update mapping status color
        switch worldMappingStatus {
        case .notAvailable:
            mappingStatusLabel?.textColor = .red
        case .limited:
            mappingStatusLabel?.textColor = .orange
        case .extending:
            mappingStatusLabel?.textColor = .yellow
        case .mapped:
            mappingStatusLabel?.textColor = .green
        @unknown default:
            mappingStatusLabel?.textColor = .white
        }
        
        // Update tracking status color
        switch trackingState {
        case .notAvailable:
            trackingStatusLabel?.textColor = .red
        case .limited:
            trackingStatusLabel?.textColor = .orange
        case .normal:
            trackingStatusLabel?.textColor = .green
        }
    }
    
    private func showStatusOverlay() {
        statusOverlayView?.isHidden = false
    }
    
    private func hideStatusOverlay() {
        statusOverlayView?.isHidden = true
    }
    
    private func stopStatusUpdates() {
        if let timer = statusUpdateTimer {
            timer.invalidate()
            statusUpdateTimer = nil
            print("⏹️ Stopped world mapping status updates")
        }
    }
    
    // MARK: - Memory Management
    
    private func cleanupVideoResources() {
        // Stop and cleanup current player
        currentPlayer?.pause()
        currentPlayer = nil
        
        // Remove all observers
        for observer in videoObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        videoObservers.removeAll()
        
        // Clear active players
        for player in activePlayers {
            player.pause()
        }
        activePlayers.removeAll()
        
        isVideoPlaying = false
        print("🧹 Cleaned up video resources")
        print("👁️ Removed \(videoObservers.count) video observers")
    }
    
    private func addVideoObserver(for player: AVPlayer) {
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main) { [weak self, weak player] _ in
                guard let self = self, let player = player else { return }
                
                print("🔄 Video ended - looping back to start")
                player.seek(to: .zero)
                player.play()
                print("✅ Video restarted for loop")
        }
        
        videoObservers.append(observer)
        print("👁️ Added video loop observer")
    }
    
    // MARK: - Helper Methods
    
    private func getFlutterAssetURL(for fileName: String) -> URL? {
        // Try multiple possible Flutter assets paths
        let possiblePaths = [
            Bundle.main.path(forResource: "Frameworks/App.framework/flutter_assets", ofType: nil),
            Bundle.main.path(forResource: "flutter_assets", ofType: nil),
            Bundle.main.path(forResource: "App.framework/flutter_assets", ofType: nil)
        ]
        
        var flutterAssetsPath: String?
        for path in possiblePaths {
            if let path = path, FileManager.default.fileExists(atPath: path) {
                flutterAssetsPath = path
                print("✅ Found Flutter assets at: \(path)")
                break
            }
        }
        
        guard let flutterAssetsPath = flutterAssetsPath else {
            print("❌ Flutter assets path not found")
            return nil
        }
        
        // Construct the full path to the video file
        let videoPath = "\(flutterAssetsPath)/assets/\(fileName)"
        let videoURL = URL(fileURLWithPath: videoPath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: videoPath) else {
            print("❌ Video file not found at path: \(videoPath)")
            // Try to list files in assets directory for debugging
            let assetsDir = "\(flutterAssetsPath)/assets"
            if let files = try? FileManager.default.contentsOfDirectory(atPath: assetsDir) {
                print("📁 Available files in assets: \(files)")
            }
            return nil
        }
        
        print("✅ Found video at: \(videoPath)")
        return videoURL
    }
    
    private func removeAllPlacedObjects() {
        // Cleanup video resources first
        cleanupVideoResources()
        
        // Remove all existing video objects (single placement like ContentView.swift)
        for (_, entity) in placedObjects {
            entity.removeFromParent()
        }
        
        // Remove all anchors
        for (_, anchor) in anchors {
            arView?.scene.removeAnchor(anchor)
        }
        
        // Clear tracking dictionaries
        placedObjects.removeAll()
        anchors.removeAll()
        
        print("🗑️ Removed all placed objects for single video placement")
    }
    
    // MARK: - Enhanced Gesture Handling
    private func handleTap(at location: CGPoint, in view: ARView) {
        // Match ContentView.swift approach exactly - simple and clean
        guard let arView = self.arView else { return }
        
        // Convert ARView raycast to match ContentView.swift raycast approach
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
        
        guard let result = results.first else {
            print("❌ No plane detected for video placement")
            return
        }
        
        // Extract position exactly like ContentView.swift: simd_make_float3(result.worldTransform.columns.3)
        let position = simd_make_float3(result.worldTransform.columns.3)
        
        print("🎯 Placing video at position: \(position)")
        
        // Remove existing video if any (single placement like ContentView.swift)
        removeAllPlacedObjects()
        
        // Create video entity using VideoCameraKit approach
        print("🎯 Creating video entity with VideoCameraKit approach")
        let videoEntity = createVideoEntityWithVideoCameraKit(at: position, videoPath: "assets/video_(0).mov")
        
        // Track the entity with a unique ID
        let objectId = UUID().uuidString
        placedObjects[objectId] = videoEntity
        
        print("✅ Video placed successfully")
        print("📍 Video world position: \(position)")
        print("🎯 Video entity tracked with ID: \(objectId)")
        
        // Switch to minimal tracking after placement (like ContentView.swift)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.switchToMinimalTracking()
        }
    }
    
    private func handlePan(translation: CGPoint, for objectId: String) {
        // Match ContentView.swift pan handling approach exactly
        guard let videoEntity = placedObjects[objectId],
              let arView = self.arView else { return }
        
        // Get camera transform for relative movement (exact match to ContentView.swift)
        guard let camera = arView.session.currentFrame?.camera else { return }
        
        // Calculate camera-relative movement vectors (exact match to ContentView.swift)
        let forward = simd_float3(
            camera.transform.columns.2[0],
            camera.transform.columns.2[1],
            camera.transform.columns.2[2]
        )
        
        let up = simd_float3(0, 1, 0)
        let right = normalize(cross(forward, up))
        
        // Project movement onto horizontal plane (exact match to ContentView.swift)
        let rightOnPlane = normalize(simd_float3(right.x, 0, right.z))
        let forwardOnPlane = normalize(simd_float3(forward.x, 0, forward.z))
        
        // Calculate movement based on scale (exact match to ContentView.swift approach)
        let currentScale = videoEntity.transform.scale.x
        let baseSpeed: Float = 0.003 // Match ContentView.swift baseSpeed exactly
        let speedMultiplier = max(currentScale, 0.1) // Match ContentView.swift speedMultiplier exactly
        let adjustedSpeed = baseSpeed * speedMultiplier
        
        // Apply movement (exact match to ContentView.swift calculation)
        let movement = rightOnPlane * Float(-translation.x) * adjustedSpeed +
                      forwardOnPlane * Float(translation.y) * adjustedSpeed
        
        // Update entity position (RealityKit approach)
        videoEntity.position += movement
        
        print("📱 Pan gesture applied - movement: \(movement)")
        print("📍 New video local position: \(videoEntity.position)")
        
        // If entity has an anchor parent, also update anchor position
        if let anchor = videoEntity.parent as? AnchorEntity {
            anchor.position += movement
            print("📍 New anchor world position: \(anchor.position)")
        }
    }

    // MARK: - Data Persistence

    private func saveObjectData(for mapName: String) {
   
        var objectsArray: [[String: Any]] = []

        for (objectId, objectEntity) in placedObjects {
            // Get the world position of the entity (not local position)
            let worldPosition: SIMD3<Float>
            if let parent = objectEntity.parent as? AnchorEntity {
                // If entity has an anchor parent, get the anchor's world position
                worldPosition = parent.position(relativeTo: nil)
            } else {
                // Otherwise use entity's position
                worldPosition = objectEntity.position(relativeTo: nil)
            }
            
            var objectInfo: [String: Any] = [
                "objectId": objectId,
                "position": [worldPosition.x, worldPosition.y, worldPosition.z],
                "scale": objectEntity.transform.scale.x, // Assuming uniform scale
                "rotation": [objectEntity.transform.rotation.angle, objectEntity.transform.rotation.angle, objectEntity.transform.rotation.angle]
            ]

            // Only video objects are supported now
            objectInfo["objectType"] = "video"
            let name = objectEntity.name ?? ""
            if !name.isEmpty {
                objectInfo["content"] = name // store asset path
            }

            objectsArray.append(objectInfo)
        }

        do {
            let objectData = try JSONSerialization.data(withJSONObject: objectsArray, options: .prettyPrinted)
            let objectsURL = worldMapsPath.appendingPathComponent("\(mapName)_objects.json")
            try objectData.write(to: objectsURL)

            print("Successfully saved \(objectsArray.count) objects for map: \(mapName)")
            print("✅ VideoCameraKit positioning data saved")
            print("📁 Saved to: \(objectsURL.path)")
        } catch {
            print("Error saving object data: \(error.localizedDescription)")
        }
    }

    private func loadObjectData(for mapName: String) {
        // Load object data from JSON
        let objectsURL = worldMapsPath.appendingPathComponent("\(mapName)_objects.json")

        guard FileManager.default.fileExists(atPath: objectsURL.path) else {
            print("No object data found for map: \(mapName)")
            return
        }

        do {
            let objectData = try Data(contentsOf: objectsURL)
            let objectsArray = try JSONSerialization.jsonObject(with: objectData) as? [[String: Any]]

            guard let objects = objectsArray else {
                print("Could not parse object data")
                return
            }

            // Clear existing objects
            placedObjects.removeAll()
            anchors.removeAll()

            // Restore objects from saved data using VideoCameraKit approach
            for objectInfo in objects {
                guard let objectId = objectInfo["objectId"] as? String,
                      let objectType = objectInfo["objectType"] as? String,
                      let positionArray = objectInfo["position"] as? [Float],
                      positionArray.count == 3 else {
                    continue
                }

                // Convert to SIMD3<Float> for anchor transform
                let position = SIMD3<Float>(positionArray[0], positionArray[1], positionArray[2])

                // Create video entity using VideoCameraKit approach
                let videoPath = objectInfo["content"] as? String ?? "assets/video_(0).mov"
                print("🔄 Restoring video entity with VideoCameraKit approach: \(videoPath)")
                
                // Create video entity at the exact saved position
                let objectEntity = createVideoEntityWithVideoCameraKit(at: position, videoPath: videoPath)

                // Apply saved transformations
                if let scale = objectInfo["scale"] as? Float {
                    objectEntity.transform.scale = SIMD3<Float>(scale, scale, scale)
                }

                if let rotationArray = objectInfo["rotation"] as? [Float], rotationArray.count == 3 {
                    objectEntity.transform.rotation = simd_quatf(angle: rotationArray[0], axis: [0, 1, 0])
                }

                // Track entity directly (no separate anchor needed with VideoCameraKit)
                placedObjects[objectId] = objectEntity

                print("✅ Restored object: \(objectId) at position: \(position)")
                print("🎯 Using VideoCameraKit for precise positioning")
                print("🎯 Video should appear at exact saved coordinates")
            }

            print("Successfully loaded \(objects.count) objects for map: \(mapName)")
            print("✅ All videos positioned using VideoCameraKit approach")
            
            // Debug world positioning after loading
            debugWorldPositioning()

        } catch {
            print("Error loading object data: \(error.localizedDescription)")
        }
    }
}

// MARK: - RealityKit doesn't need ARSCNViewDelegate as it handles anchoring automatically

// MARK: - ARSessionDelegate

extension ARController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error.localizedDescription)")
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update world mapping status display
        updateWorldMappingStatus(frame)
        
        // Check for relocalization completion
        if isRelocalizingMap,
           let mapName = pendingMapNameToLoadObjects,
           frame.worldMappingStatus == .mapped,
           frame.camera.trackingState == .normal {
            
            print("✅ Relocalization successful - loading objects for map: \(mapName)")
            isRelocalizingMap = false
            pendingMapNameToLoadObjects = nil
            
            // Load objects after successful relocalization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadObjectData(for: mapName)
            }
        }
    }
}

// MARK: - Map Export/Import Functions

extension ARController {
    
    private func exportWorldMap(mapName: String, result: @escaping FlutterResult) {
        // Check if map exists - only use .worldmap extension
        let worldMapURL = worldMapsPath.appendingPathComponent("\(mapName).worldmap")
        let objectsURL = worldMapsPath.appendingPathComponent("\(mapName)_objects.json")
        
        print("🔍 Debug: Checking map files for '\(mapName)'")
        print("🔍 Debug: World map path: \(worldMapURL.path)")
        print("🔍 Debug: Objects path: \(objectsURL.path)")
        print("🔍 Debug: World map exists: \(FileManager.default.fileExists(atPath: worldMapURL.path))")
        print("🔍 Debug: Objects exists: \(FileManager.default.fileExists(atPath: objectsURL.path))")
        
        // Check if both files exist
        let worldMapExists = FileManager.default.fileExists(atPath: worldMapURL.path)
        let objectsExists = FileManager.default.fileExists(atPath: objectsURL.path)
        
        guard worldMapExists && objectsExists else {
            var missingFiles: [String] = []
            if !worldMapExists { missingFiles.append("worldmap") }
            if !objectsExists { missingFiles.append("objects") }
            
            let errorMessage = "Map '\(mapName)' missing files: \(missingFiles.joined(separator: ", "))"
            print("❌ \(errorMessage)")
            result(FlutterError(code: "MAP_NOT_FOUND", message: errorMessage, details: nil))
            return
        }
        
        do {
            // Create export directory if needed
            try FileManager.default.createDirectory(at: exportedMapsPath, withIntermediateDirectories: true)
            
            // Create export filename with timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            let exportFileName = "\(mapName)_export_\(timestamp).arworldmap"
            let exportURL = exportedMapsPath.appendingPathComponent(exportFileName)
            
            // Create export package (zip-like structure)
            let exportData = try createExportPackage(mapName: mapName, worldMapURL: worldMapURL, objectsURL: objectsURL)
            
            // Write export file
            try exportData.write(to: exportURL)
            
            print("✅ Successfully exported map: \(mapName)")
            print("📁 Export file: \(exportURL.path)")
            print("📊 File size: \(exportData.count) bytes")
            
            result(exportURL.path)
            
        } catch {
            print("❌ Error exporting map: \(error)")
            result(FlutterError(code: "EXPORT_FAILED", message: "Failed to export map: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func createExportPackage(mapName: String, worldMapURL: URL, objectsURL: URL) throws -> Data {
        // Read world map data
        let worldMapData = try Data(contentsOf: worldMapURL)
        
        // Read objects data
        let objectsData = try Data(contentsOf: objectsURL)
        
        // Create export metadata
        let metadata: [String: Any] = [
            "mapName": mapName,
            "exportDate": Date().timeIntervalSince1970,
            "version": "1.0",
            "worldMapSize": worldMapData.count,
            "objectsSize": objectsData.count,
            "deviceInfo": [
                "model": UIDevice.current.model,
                "systemVersion": UIDevice.current.systemVersion,
                "systemName": UIDevice.current.systemName
            ]
        ]
        
        // Convert binary data to base64 strings for JSON compatibility
        let worldMapBase64 = worldMapData.base64EncodedString()
        let objectsBase64 = objectsData.base64EncodedString()
        
        // Create export package structure with base64 encoded data
        let exportPackage: [String: Any] = [
            "metadata": metadata,
            "worldMap": worldMapBase64,
            "objects": objectsBase64
        ]
        
        return try JSONSerialization.data(withJSONObject: exportPackage, options: .prettyPrinted)
    }
    
    private func importWorldMap(filePath: String, result: @escaping FlutterResult) {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "Import file not found: \(filePath)", details: nil))
            return
        }
        
        do {
            // Read export package
            let exportData = try Data(contentsOf: fileURL)
            let exportPackage = try JSONSerialization.jsonObject(with: exportData) as? [String: Any]
            
            guard let package = exportPackage,
                  let metadata = package["metadata"] as? [String: Any],
                  let worldMapBase64 = package["worldMap"] as? String,
                  let objectsBase64 = package["objects"] as? String else {
                result(FlutterError(code: "INVALID_EXPORT_FILE", message: "Invalid export file format", details: nil))
                return
            }
            
            // Decode base64 data
            guard let worldMapData = Data(base64Encoded: worldMapBase64),
                  let objectsData = Data(base64Encoded: objectsBase64) else {
                result(FlutterError(code: "INVALID_EXPORT_FILE", message: "Invalid base64 data in export file", details: nil))
                return
            }
            
            let originalMapName = metadata["mapName"] as? String ?? "imported_map"
            
            // Generate unique map name
            let timestamp = Int(Date().timeIntervalSince1970)
            let newMapName = "\(originalMapName)_imported_\(timestamp)"
            
            // Save world map
            let worldMapURL = worldMapsPath.appendingPathComponent("\(newMapName).worldmap")
            try worldMapData.write(to: worldMapURL)
            
            // Save objects data
            let objectsURL = worldMapsPath.appendingPathComponent("\(newMapName)_objects.json")
            try objectsData.write(to: objectsURL)
            
            print("✅ Successfully imported map: \(newMapName)")
            print("📁 Original map: \(originalMapName)")
            print("📊 World map size: \(worldMapData.count) bytes")
            print("📊 Objects data size: \(objectsData.count) bytes")
            
            result(newMapName)
            
        } catch {
            print("❌ Error importing map: \(error)")
            result(FlutterError(code: "IMPORT_FAILED", message: "Failed to import map: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func getExportFileInfo(mapName: String, result: @escaping FlutterResult) {
        let exportFileName = "\(mapName)_export_*.arworldmap"
        let exportURL = exportedMapsPath.appendingPathComponent(exportFileName)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: exportedMapsPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            let matchingFiles = files.filter { $0.lastPathComponent.hasPrefix("\(mapName)_export_") }
            
            if let latestFile = matchingFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first {
                let attributes = try FileManager.default.attributesOfItem(atPath: latestFile.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                
                let fileInfo: [String: Any] = [
                    "fileName": latestFile.lastPathComponent,
                    "filePath": latestFile.path,
                    "fileSize": fileSize,
                    "creationDate": creationDate.timeIntervalSince1970,
                    "formattedSize": ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                ]
                
                result(fileInfo)
            } else {
                result(FlutterError(code: "EXPORT_NOT_FOUND", message: "No export file found for map: \(mapName)", details: nil))
            }
            
        } catch {
            result(FlutterError(code: "FILE_INFO_ERROR", message: "Error getting file info: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func shareExportedMap(mapName: String, result: @escaping FlutterResult) {
        let exportFileName = "\(mapName)_export_*.arworldmap"
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: exportedMapsPath, includingPropertiesForKeys: nil)
            let matchingFiles = files.filter { $0.lastPathComponent.hasPrefix("\(mapName)_export_") }
            
            if let latestFile = matchingFiles.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first {
                // Use UIActivityViewController to share the file
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(activityItems: [latestFile], applicationActivities: nil)
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                }
                
                result(true)
            } else {
                result(FlutterError(code: "EXPORT_NOT_FOUND", message: "No export file found for map: \(mapName)", details: nil))
            }
            
        } catch {
            result(FlutterError(code: "SHARE_ERROR", message: "Error sharing file: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func getExportedMaps(result: @escaping FlutterResult) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: exportedMapsPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            let exportFiles = files.filter { $0.pathExtension == "arworldmap" }
            
            var exportedMaps: [[String: Any]] = []
            
            for file in exportFiles {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                
                let mapInfo: [String: Any] = [
                    "fileName": file.lastPathComponent,
                    "filePath": file.path,
                    "fileSize": fileSize,
                    "creationDate": creationDate.timeIntervalSince1970,
                    "formattedSize": ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                ]
                
                exportedMaps.append(mapInfo)
            }
            
            // Sort by creation date (newest first)
            exportedMaps.sort { ($0["creationDate"] as? Double ?? 0) > ($1["creationDate"] as? Double ?? 0) }
            
            result(exportedMaps)
            
        } catch {
            result(FlutterError(code: "EXPORT_LIST_ERROR", message: "Error getting exported maps: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func deleteExportedMap(fileName: String, result: @escaping FlutterResult) {
        let fileURL = exportedMapsPath.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Successfully deleted exported map: \(fileName)")
            result(true)
        } catch {
            print("❌ Error deleting exported map: \(error)")
            result(FlutterError(code: "DELETE_ERROR", message: "Error deleting file: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func openExportedMapsInFiles(result: @escaping FlutterResult) {
        // Get all exported map files
        do {
            let files = try FileManager.default.contentsOfDirectory(at: exportedMapsPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            let exportFiles = files.filter { $0.pathExtension == "arworldmap" }
            
            if exportFiles.isEmpty {
                result(FlutterError(code: "NO_FILES", message: "No exported maps found", details: nil))
                return
            }
            
            // Use UIActivityViewController to share the files
            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: exportFiles, applicationActivities: nil)
                
                // Configure for Files app
                activityVC.excludedActivityTypes = [
                    .assignToContact,
                    .addToReadingList,
                    .openInIBooks,
                    .markupAsPDF
                ]
                
                // Present the activity view controller
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true) {
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "PRESENTATION_ERROR", message: "Could not present Files app", details: nil))
                }
            }
            
        } catch {
            result(FlutterError(code: "FILE_ACCESS_ERROR", message: "Error accessing exported maps: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func getExportedMapsDirectory(result: @escaping FlutterResult) {
        result(exportedMapsPath.path)
    }
    
    private func openFilesAppDirectly(result: @escaping FlutterResult) {
        // Try to open Files app directly using URL scheme
        if let filesAppURL = URL(string: "shortcuts://run-shortcut?name=Files") {
            if UIApplication.shared.canOpenURL(filesAppURL) {
                UIApplication.shared.open(filesAppURL) { success in
                    DispatchQueue.main.async {
                        if success {
                            result(true)
                        } else {
                            result(FlutterError(code: "FILES_APP_ERROR", message: "Could not open Files app", details: nil))
                        }
                    }
                }
            } else {
                // Fallback: try to open Files app with a different approach
                let activityVC = UIActivityViewController(activityItems: ["Exported Maps Directory"], applicationActivities: nil)
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.present(activityVC, animated: true) {
                        result(true)
                    }
                } else {
                    result(FlutterError(code: "PRESENTATION_ERROR", message: "Could not present Files app", details: nil))
                }
            }
        } else {
            result(FlutterError(code: "URL_ERROR", message: "Invalid Files app URL", details: nil))
        }
    }
}
