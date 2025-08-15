import SwiftUI
import RealityKit
import ARKit
import AVFoundation
import ReplayKit

struct ContentView: View {
    @State private var videoEntity: ModelEntity?
    @State private var isPlaced = false
    @State private var isRecording = false
    @State private var arView: ARView?
    @State private var debugInfo: String = ""

    @State private var currentVideoIndex = 0
    @State private var showControls = false
    @State private var controlsTimer: Timer?
    
    // Map scanning functionality
    @StateObject var mapManager = ARMapManager()
    @State private var showMapControls = false

    private let videoNames: [String]
    private var availableVideos: [String] {
        let available = videoNames.filter { videoName in
            let url = Bundle.main.url(forResource: videoName, withExtension: "mov")
            let exists = url != nil
            print("🎥 Checking video: '\(videoName)' - Found: \(exists)")
            if let url = url {
                print("📁 Video path: \(url.path)")
            }
            return exists
        }
        print("✅ Total available videos: \(available.count) out of \(videoNames.count)")
        print("📋 Available videos: \(available)")
        return available.isEmpty ? ["video_(0)"] : available // Fallback to prevent crashes
    }
    
    // Default initializer
    init() {
        self.videoNames = ["video_(-1)", "video_(0)", "video_(1)"]
    }
    
    // Custom initializer for Flutter integration
    init(videoNames: [String]) {
        self.videoNames = videoNames
    }

    var body: some View {
        ZStack {
            if #available(iOS 14.0, *) {
                ARViewContainer(
                    videoEntity: $videoEntity,
                    isPlaced: $isPlaced,
                    arView: $arView,
                    isRecording: $isRecording,
                    debugInfo: $debugInfo,
                    currentVideoIndex: $currentVideoIndex,
                    videos: availableVideos,
                    mapManager: mapManager
                )
                .ignoresSafeArea()
                .onTapGesture {
                    if isRecording {
                        stopRecording()
                    } else if isPlaced {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showControls = true
                        }
                        startControlsTimer()
                    }
                }
                .onAppear {
                    configureAudioSession()
                }
            }

            if !isRecording {
                VStack {
                    if isPlaced {
                        Text(debugInfo)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(.top)
                    }

                    if isPlaced {
                        HStack {
                            // Map scanning button
                            Button(action: toggleMapScanning) {
                                Image(systemName: mapManager.isScanningMap ? "stop.circle.fill" : "map.circle")
                                    .font(.title2)
                                    .foregroundColor(mapManager.isScanningMap ? .red : .white)
                                    .padding(12)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(.leading)
                            
                            Spacer()
                            
                            // Map controls toggle
                            Button(action: { showMapControls.toggle() }) {
                                Image(systemName: "folder.circle")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: resetScene) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.black.opacity(0.7))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing)
                        }
                    }

                   // Spacer()

//                    if isPlaced {
//                        HStack {
//                            if currentVideoIndex > 0 {
//                                Button(action: previousVideo) {
//                                    Image(systemName: "chevron.left.circle.fill")
//                                        .font(.system(size: 40))
//                                        .foregroundColor(.white.opacity(0.8))
//                                }
//                            }
//
//                            Spacer()
//
//                            if currentVideoIndex < availableVideos.count - 1 {
//                                Button(action: nextVideo) {
//                                    Image(systemName: "chevron.right.circle.fill")
//                                        .font(.system(size: 40))
//                                        .foregroundColor(.white.opacity(0.8))
//                                }
//                            }
//                        }
//                        .padding(.horizontal, 30)
//                        .transition(.opacity.combined(with: .scale))
//                    }

//                    Spacer()
//
//                    if !isPlaced {
//                        Text("Tap anywhere to place video")
//                            .foregroundStyle(.white)
//                            .padding()
//                            .background(.black.opacity(0.7))
//                            .clipShape(RoundedRectangle(cornerRadius: 10))
//                            .padding(.bottom, 50)
//                    } else {
//                        Button(action: startRecording) {
//                            Circle()
//                                .stroke(Color.white, lineWidth: 3)
//                                .frame(width: 65, height: 65)
//                                .overlay(
//                                    Circle()
//                                        .fill(Color.white)
//                                        .frame(width: 50, height: 50)
//                                )
//                        }
//                        .padding(.bottom, 30)
//                    }
                }
            }
            
            // Map scanning status overlay
            if mapManager.isScanningMap {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Text(mapManager.scanStatus)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: mapManager.mapScanProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 200)
                        
                        Text("\(Int(mapManager.mapScanProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .padding(.bottom, 100)
                }
            }
            
            // Map controls overlay
            if showMapControls {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showMapControls = false
                    }
                
                VStack(spacing: 20) {
                    Text("Map Controls")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        Button(action: saveCurrentMap) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Current Map")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: { showMapControls = false }) {
                            Text("View Saved Maps")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { showMapControls = false }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(30)
                .background(Color.black.opacity(0.9))
                .cornerRadius(15)
                .padding(.horizontal, 40)
            }
        }
    }

     func startControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

     func previousVideo() {
        guard availableVideos.count > 0, currentVideoIndex > 0 else { 
            print("⚠️ Cannot go to previous video - currentIndex: \(currentVideoIndex), availableCount: \(availableVideos.count)")
            return 
        }
        print("🔄 Previous video: \(currentVideoIndex) -> \(currentVideoIndex - 1)")
        currentVideoIndex -= 1  // This should trigger handleVideoIndexChange automatically
        print("✅ Updated currentVideoIndex to: \(currentVideoIndex)")
        startControlsTimer()
    }

     func nextVideo() {
        guard availableVideos.count > 0, currentVideoIndex < availableVideos.count - 1 else { 
            print("⚠️ Cannot go to next video - currentIndex: \(currentVideoIndex), availableCount: \(availableVideos.count)")
            return 
        }
        print("🔄 Next video: \(currentVideoIndex) -> \(currentVideoIndex + 1)")
        currentVideoIndex += 1  // This should trigger handleVideoIndexChange automatically
        print("✅ Updated currentVideoIndex to: \(currentVideoIndex)")
        startControlsTimer()
    }

     func startRecording() {
        RPScreenRecorder.shared().startRecording { error in
            if let error = error {
                print("Error starting recording: \(error)")
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                isRecording = true
            }
        }
    }

     func stopRecording() {
        RPScreenRecorder.shared().stopRecording { (previewController, error) in
            withAnimation(.easeInOut(duration: 0.3)) {
                isRecording = false
            }

            if let error = error {
                print("Error stopping recording: \(error)")
                return
            }

            if let previewController = previewController {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    previewController.modalPresentationStyle = .fullScreen
                    previewController.previewControllerDelegate = RPPreviewViewControllerProxy.shared
                    rootVC.present(previewController, animated: true)
                }
            }
        }
    }

    // MARK: - Map Scanning Functions
    func toggleMapScanning() {
        if mapManager.isScanningMap {
            mapManager.stopMapScanning()
        } else {
            mapManager.startMapScanning()
        }
    }
    
    func saveCurrentMap() {
        let success = mapManager.saveMapToLocal()
        if success {
            showMapControls = false
        }
    }
    
    // Public methods for ARControlsHandler access
    func saveMapToLocal() -> Bool {
        return mapManager.saveMapToLocal()
    }
    
    func getSavedMaps() -> [String] {
        return mapManager.getSavedMaps()
    }
    
    func loadMapFromLocal(fileName: String, completion: @escaping (Bool) -> Void) {
        mapManager.loadMapFromLocal(fileName: fileName) { success, videoAnchors in
            if success, let videoAnchors = videoAnchors, !videoAnchors.isEmpty {
                // Restore videos at their saved positions
                self.restoreVideosFromAnchors(videoAnchors)
            }
            completion(success)
        }
    }
    
    func deleteMap(fileName: String) -> Bool {
        return mapManager.deleteMap(fileName: fileName)
    }
    
    func getMapFileSize(fileName: String) -> Int64 {
        return mapManager.getMapFileSize(fileName: fileName)
    }
    
    // MARK: - Video Anchor Management
    func captureCurrentVideoAnchor() {
        guard let videoEntity = videoEntity else {
            print("⚠️ No video entity to capture")
            return
        }
        
        // Get the entity's transform matrix
        let transform = videoEntity.transform.matrix
        let videoName = availableVideos[currentVideoIndex]
        let anchorId = UUID().uuidString // Generate unique ID
        
        mapManager.addVideoAnchor(
            videoIndex: currentVideoIndex,
            videoName: videoName,
            transform: transform,
            anchorIdentifier: anchorId
        )
        
        print("📍 Captured video anchor: \(videoName) at index \(currentVideoIndex)")
    }
    
    func restoreVideosFromAnchors(_ videoAnchors: [VideoAnchorData]) {
        guard let arView = arView else {
            print("❌ ARView not available for video restoration")
            return
        }
        
        print("🔄 Restoring \(videoAnchors.count) video(s) from anchors...")
        
        for (index, anchorData) in videoAnchors.enumerated() {
            // Create anchor at saved position
            let anchor = ARAnchor(transform: anchorData.getTransform())
            arView.session.add(anchor: anchor)
            
            // Create video entity at anchor position
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                self.createVideoEntityAtAnchor(anchor, videoIndex: anchorData.videoIndex, videoName: anchorData.videoName)
            }
        }
    }
    
    private func createVideoEntityAtAnchor(_ anchor: ARAnchor, videoIndex: Int, videoName: String) {
        guard let arView = arView else { return }
        
        // Create video entity similar to existing video creation logic
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mov") else {
            print("❌ Video file not found: \(videoName)")
            return
        }
        
        let player = AVPlayer(url: videoURL)
        let videoMaterial = VideoMaterial(avPlayer: player)
        
        // Create mesh for video
        var descriptor = MeshDescriptor(name: "videoPlane")
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(-1.0, 0.0, 0.0),
            SIMD3<Float>(1.0, 0.0, 0.0),
            SIMD3<Float>(-1.0, 2.0, 0.0),
            SIMD3<Float>(1.0, 2.0, 0.0)
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
            
            // Anchor the entity
            let anchorEntity = AnchorEntity(anchor: anchor)
            anchorEntity.addChild(entity)
            arView.scene.addAnchor(anchorEntity)
            
            // Update state if this is the first restored video
            if !isPlaced {
                self.videoEntity = entity
                self.isPlaced = true
                self.currentVideoIndex = videoIndex
            }
            
            player.play()
            print("✅ Restored video: \(videoName) at saved position")
            
        } catch {
            print("❌ Error creating video entity: \(error)")
        }
    }
    
     func resetScene() {
        controlsTimer?.invalidate()
        DispatchQueue.main.async {
            // STOP ALL PLAYERS BEFORE RESET
            if let entity = self.videoEntity,
               let currentMaterial = entity.model?.materials.first as? VideoMaterial,
               let currentPlayer = currentMaterial.avPlayer {
                currentPlayer.pause()
                currentPlayer.replaceCurrentItem(with: nil)
                print("🛑 Stopped player during reset")
            }

            self.arView?.scene.anchors.removeAll()
            self.isPlaced = false
            self.videoEntity = nil

            if let arView = self.arView {
                print("🔄 Resetting and rescanning AR world...")

                // Create fresh full tracking configuration (same as app startup)
                let fullConfig = ARWorldTrackingConfiguration()
                fullConfig.planeDetection = .horizontal

                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    fullConfig.sceneReconstruction = .mesh
                }

                if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .personSegmentationWithDepth]) {
                    fullConfig.frameSemantics = [.sceneDepth, .personSegmentationWithDepth]
                }

                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    fullConfig.sceneReconstruction = .meshWithClassification
                }

                // Enable full AR environment (same as startup)
                arView.environment.sceneUnderstanding.options = [.occlusion, .physics]
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
        }
    }

     func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("Audio session configured successfully")

            // Start thermal monitoring
            startThermalMonitoring()
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

     func startThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let thermalState = ProcessInfo.processInfo.thermalState
            print("🌡️ Thermal state: \(thermalState.rawValue)")

            switch thermalState {
            case .critical, .serious:
                print("🔥 High thermal state detected - consider reducing video quality")
            case .fair:
                print("⚠️ Moderate thermal state")
            case .nominal:
                print("❄️ Normal thermal state")
            @unknown default:
                break
            }
        }
    }
    
    // Public method for Flutter integration
    func handleTap() {
        if isRecording {
            stopRecording()
        } else if isPlaced {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = true
            }
            startControlsTimer()
        }
    }
}

class RPPreviewViewControllerProxy: NSObject, RPPreviewViewControllerDelegate {
    static let shared = RPPreviewViewControllerProxy()

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var videoEntity: ModelEntity?
    @Binding var isPlaced: Bool
    @Binding var arView: ARView?
    @Binding var isRecording: Bool
    @Binding var debugInfo: String
    @Binding var currentVideoIndex: Int
    let videos: [String]
    let mapManager: ARMapManager

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)

        DispatchQueue.main.async {
            self.arView = view
            // Connect map manager to ARView
            self.mapManager.setARView(view)
        }

        // THERMAL OPTIMIZATION: Configure rendering options
        view.renderOptions.insert(.disableMotionBlur)
        view.renderOptions.insert(.disableDepthOfField)

        // Start with full configuration for placement
        if let fullConfig = context.coordinator.fullConfig {
            // Check device occlusion capabilities and configure accordingly
            if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth]) ||
               ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                view.environment.sceneUnderstanding.options = [.occlusion, .physics]
                view.renderOptions.remove(.disablePersonOcclusion)
                print("✅ Initial setup: Occlusion enabled")
            } else {
                view.environment.sceneUnderstanding.options = [.physics]
                print("❌ Initial setup: No occlusion support")
            }

            view.debugOptions = [.showFeaturePoints]
            view.session.run(fullConfig)
        }

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        let rotationGesture = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotation))
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))

        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(rotationGesture)
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(tapGesture)

        context.coordinator.setupGestures([panGesture, rotationGesture, pinchGesture, tapGesture])
        context.coordinator.arView = view
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateGestureStates(isRecording: isRecording)
        context.coordinator.handleVideoIndexChange(newIndex: currentVideoIndex)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(videoEntity: $videoEntity, isPlaced: $isPlaced, isRecording: $isRecording, debugInfo: $debugInfo, currentVideoIndex: $currentVideoIndex, videos: videos)
    }

    @MainActor
    class Coordinator: NSObject {
        @Binding var videoEntity: ModelEntity?
        @Binding var isPlaced: Bool
        @Binding var isRecording: Bool
        @Binding var debugInfo: String
        @Binding var currentVideoIndex: Int
        let videos: [String]
        weak var arView: ARView?

        private var gestures: [UIGestureRecognizer] = []
        private var debugUpdateTask: Task<Void, Never>?
        private var videoObserver: NSObjectProtocol?
        private var lastVideoIndex: Int = 0
        var fullConfig: ARWorldTrackingConfiguration?
        var minimalConfig: ARWorldTrackingConfiguration?

        private var localVideoEntity: ModelEntity?

        init(videoEntity: Binding<ModelEntity?>, isPlaced: Binding<Bool>, isRecording: Binding<Bool>, debugInfo: Binding<String>, currentVideoIndex: Binding<Int>, videos: [String]) {
            _videoEntity = videoEntity
            _isPlaced = isPlaced
            _isRecording = isRecording
            _debugInfo = debugInfo
            _currentVideoIndex = currentVideoIndex
            self.videos = videos
            self.lastVideoIndex = currentVideoIndex.wrappedValue
            super.init()
            setupConfigurations()
        }

        func setupConfigurations() {
            // Full scanning configuration
            let fullConfig = ARWorldTrackingConfiguration()
            fullConfig.planeDetection = .horizontal

            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                fullConfig.sceneReconstruction = .mesh
                print("✅ Scene reconstruction enabled")
            }

            if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .personSegmentationWithDepth]) {
                fullConfig.frameSemantics = [.sceneDepth, .personSegmentationWithDepth]
                print("✅ Scene depth + person segmentation enabled")
            } else if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                fullConfig.frameSemantics = [.personSegmentationWithDepth]
                print("✅ Person segmentation enabled")
            } else {
                print("❌ Person segmentation not supported")
            }

            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                fullConfig.sceneReconstruction = .meshWithClassification
                print("✅ Scene reconstruction with classification enabled")
            }

            self.fullConfig = fullConfig

            // Minimal configuration for after placement
            let minimalConfig = ARWorldTrackingConfiguration()
            minimalConfig.planeDetection = [] // No plane detection
            self.minimalConfig = minimalConfig
        }

         func switchToMinimalTracking() {
            guard let arView = self.arView else { return }

            print("🔄 Switching to minimal AR tracking mode (with occlusion)")
            print("🔍 VideoEntity before minimal switch: \(videoEntity != nil)")

            // Minimal config but keep some tracking features for better SLAM
            let minimalConfig = ARWorldTrackingConfiguration()
            minimalConfig.planeDetection = [] // Still no plane detection
            minimalConfig.isLightEstimationEnabled = true // Re-enable for better tracking

            // Keep depth for better SLAM quality
            if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .personSegmentationWithDepth]) {
                minimalConfig.frameSemantics = [.sceneDepth, .personSegmentationWithDepth]
                print("✅ Person segmentation with depth enabled for occlusion")
            } else if ARWorldTrackingConfiguration.supportsFrameSemantics([.personSegmentationWithDepth]) {
                minimalConfig.frameSemantics = [.personSegmentationWithDepth]
                print("✅ Person segmentation enabled for occlusion")
            } else {
                print("❌ Person segmentation not supported on this device")
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

            // Stop debug updates
            debugUpdateTask?.cancel()

            // Set static debug info
            self.debugInfo = "🔋 Power Save + 👤 Occlusion\nVideo: \(currentVideoIndex + 1)/\(videos.count)"

            print("🔍 VideoEntity after minimal switch: \(videoEntity != nil)")
            print("✅ Minimal mode with occlusion activated")
        }

        func switchToFullTracking() {
            guard let arView = self.arView, let config = fullConfig else { return }

            print("🔄 Switching to full AR tracking mode")
            arView.session.run(config)
            arView.debugOptions = [.showFeaturePoints]

            // Cancel minimal debug task
            debugUpdateTask?.cancel()
        }

         func showDebugInfoOnDemand() {
            guard let entity = videoEntity,
                  let arView = self.arView,
                  let camera = arView.session.currentFrame?.camera else { return }

            let contentPosition = entity.position(relativeTo: nil)
            let cameraPosition = SIMD3<Float>(camera.transform.columns.3.x,
                                            camera.transform.columns.3.y,
                                            camera.transform.columns.3.z)

            let deltaX = cameraPosition.x - contentPosition.x
            let deltaZ = cameraPosition.z - contentPosition.z
            let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)

            let isVisible = distance >= 1.0 && distance <= 10.0

            // POWER SAVING: Pause video when too far away
            if let currentMaterial = entity.model?.materials.first as? VideoMaterial,
               let player = currentMaterial.avPlayer {
                if isVisible && player.timeControlStatus != .playing {
                    player.play()
                    print("▶️ Resumed video (back in range)")
                } else if !isVisible && player.timeControlStatus == .playing {
                    player.pause()
                    print("⏸️ Paused video (out of range - saving power)")
                }
            }

            self.debugInfo = String(format: "🔋 Power Save Mode\nDistance: %.2fm\nVisible: %@\nVideo: %@\nVideo: %d/%d\nTap for refresh",
                                 distance,
                                 isVisible ? "Yes" : "No",
                                 isVisible ? "Playing" : "Paused",
                                 currentVideoIndex + 1,
                                 videos.count)

            entity.isEnabled = isVisible

            // Auto-hide debug info after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.debugInfo = "🔋 Power Save Mode\nTap screen for info\nVideo: \(self.currentVideoIndex + 1)/\(self.videos.count)"
            }
        }

        func setupGestures(_ gestureRecognizers: [UIGestureRecognizer]) {
            self.gestures = gestureRecognizers
        }

        func updateGestureStates(isRecording: Bool) {
            gestures.forEach { $0.isEnabled = !isRecording }
        }

        func cleanup() {
            debugUpdateTask?.cancel()

            // STOP ANY PLAYING VIDEOS
            if let entity = videoEntity,
               let currentMaterial = entity.model?.materials.first as? VideoMaterial,
               let currentPlayer = currentMaterial.avPlayer {
                currentPlayer.pause()
                currentPlayer.replaceCurrentItem(with: nil)
                print("🛑 Stopped player during cleanup")
            }

            if let observer = videoObserver {
                NotificationCenter.default.removeObserver(observer)
                videoObserver = nil
            }
        }

        func createVideoEntity(at position: SIMD3<Float>) async throws {
            guard let videoURL = Bundle.main.url(forResource: videos[currentVideoIndex], withExtension: "mov") else {
                throw VideoError.fileNotFound
            }

            let player = AVPlayer(url: videoURL)
            player.actionAtItemEnd = .none

            let asset = AVURLAsset(url: videoURL)
            let dimensions: CGSize
            do {
                let track = try await asset.loadTracks(withMediaType: .video).first
                dimensions = try await track?.load(.naturalSize) ?? CGSize(width: 16, height: 9)
            } catch {
                dimensions = CGSize(width: 16, height: 9)
            }

            // Dynamic sizing based on aspect ratio
            let videoRatio = Float(dimensions.width / dimensions.height)
            let maxDimension: Float = 2.0 // Maximum size for either width or height

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

            videoObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main) { [weak player] _ in
                    print("🔄 Video ended - looping back to start")
                    player?.seek(to: .zero)
                    player?.play()
                    print("✅ Video restarted for loop")
            }

            let videoMaterial = VideoMaterial(avPlayer: player)

            // NOTE: VideoMaterial doesn't expose mipmap controls in RealityKit
            // The Metal pipeline errors are likely due to H.265+Alpha complexity
            print("📹 Created VideoMaterial for H.265+Alpha video")

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

            // Update BOTH the binding AND local reference
            self.videoEntity = entity
            self.localVideoEntity = entity
            print("✅ VideoEntity created and stored in both binding and local reference")

            player.play()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard !isPlaced, let arView = arView else { return }

            let location = gesture.location(in: arView)
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)

            guard let result = results.first else { return }

            let position = simd_make_float3(result.worldTransform.columns.3)

            Task { @MainActor in
                do {
                    try await createVideoEntity(at: position)
                    isPlaced = true

                    // Switch to minimal tracking after placement
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.switchToMinimalTracking()
                    }
                } catch {
                    print("Error creating video entity: \(error)")
                }
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let entity = videoEntity,
                  let arView = self.arView,
                  gesture.state == .changed else { return }

            let translation = gesture.translation(in: arView)

            guard let camera = arView.session.currentFrame?.camera else { return }

            let forward = SIMD3<Float>(
                camera.transform.columns.2[0],
                camera.transform.columns.2[1],
                camera.transform.columns.2[2]
            )

            let up = SIMD3<Float>(0, 1, 0)
            let right = normalize(cross(forward, up))

            let rightOnPlane = normalize(SIMD3<Float>(right.x, 0, right.z))
            let forwardOnPlane = normalize(SIMD3<Float>(forward.x, 0, forward.z))

            let currentScale = entity.transform.scale.x
            let baseSpeed: Float = 0.003
            let speedMultiplier = max(currentScale, 0.1)
            let adjustedSpeed = baseSpeed * speedMultiplier

            let movement = rightOnPlane * Float(-translation.x) * adjustedSpeed +
                         forwardOnPlane * Float(translation.y) * adjustedSpeed

            entity.position += movement
            gesture.setTranslation(.zero, in: gesture.view)
        }

        @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
            guard let entity = videoEntity, gesture.state == .changed else { return }

            let rotation = Float(-gesture.rotation)
            entity.orientation *= simd_quatf(angle: rotation, axis: [0, 1, 0])
            gesture.rotation = 0
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let entity = videoEntity, gesture.state == .changed else { return }

            let scale = Float(gesture.scale)
            let currentScale = entity.transform.scale
            let newScale = currentScale * scale

            entity.transform.scale = SIMD3<Float>(repeating: min(max(newScale.x, 0.1), 6.0))
            gesture.scale = 1
        }

        func handleVideoIndexChange(newIndex: Int) {
            print("🎯 handleVideoIndexChange called: \(lastVideoIndex) -> \(newIndex)")
            print("🔍 Debug - binding videoEntity exists: \(videoEntity != nil)")
            print("🔍 Debug - local videoEntity exists: \(localVideoEntity != nil)")

            guard newIndex != lastVideoIndex else {
                print("❌ Same index, no change needed")
                return
            }

            // Use local reference instead of binding
            guard let entity = localVideoEntity else {
                print("❌ No local videoEntity found - this should not happen!")
                lastVideoIndex = newIndex
                return
            }

            guard let anchor = entity.parent as? AnchorEntity else {
                print("❌ Entity has no anchor parent")
                lastVideoIndex = newIndex
                return
            }

            print("✅ Proceeding with video switch from index \(lastVideoIndex) to \(newIndex)")

            print("Switching video from index \(lastVideoIndex) to \(newIndex)")

            guard let newVideoURL = Bundle.main.url(forResource: videos[newIndex], withExtension: "mov") else {
                print("Could not find video file for index \(newIndex)")
                return
            }

            Task { @MainActor in
                print("🎬 Starting video switch task...")

                // PROPERLY STOP CURRENT PLAYER
                let currentMaterial = entity.model?.materials.first as? VideoMaterial
                let currentPlayer = currentMaterial?.avPlayer

                if let player = currentPlayer {
                    player.pause()
                    player.replaceCurrentItem(with: nil) // Important: Remove the item
                    print("🛑 Stopped previous player in coordinator")
                } else {
                    print("⚠️ No current player found to stop")
                }

                // Remove old observer
                if let observer = videoObserver {
                    NotificationCenter.default.removeObserver(observer)
                    videoObserver = nil
                    print("🔄 Removed old video observer")
                } else {
                    print("⚠️ No video observer to remove")
                }

                print("📁 Looking for video file: \(videos[newIndex])")

                // Get the new video dimensions
                let asset = AVURLAsset(url: newVideoURL)
                let dimensions: CGSize
                do {
                    let track = try await asset.loadTracks(withMediaType: .video).first
                    dimensions = try await track?.load(.naturalSize) ?? CGSize(width: 16, height: 9)
                    print("📏 Video dimensions: \(dimensions)")
                } catch {
                    dimensions = CGSize(width: 16, height: 9)
                    print("❌ Failed to get video dimensions: \(error)")
                }

                let newVideoRatio = Float(dimensions.width / dimensions.height)
                print("📐 Video ratio: \(newVideoRatio)")

                var needsMeshUpdate = true

                // Check if we need to update the mesh (different aspect ratio)
                if let currentItem = currentPlayer?.currentItem,
                   let currentAsset = currentItem.asset as? AVURLAsset {

                    let currentDimensions: CGSize
                    do {
                        let currentTrack = try await currentAsset.loadTracks(withMediaType: .video).first
                        currentDimensions = try await currentTrack?.load(.naturalSize) ?? CGSize(width: 16, height: 9)
                        let currentRatio = Float(currentDimensions.width / currentDimensions.height)

                        // Only update mesh if aspect ratio changed significantly
                        needsMeshUpdate = abs(currentRatio - newVideoRatio) > 0.1
                        print("🔄 Mesh update needed: \(needsMeshUpdate)")
                    } catch {
                        needsMeshUpdate = true
                    }
                }

                // Create new player
                let newPlayer = AVPlayer(url: newVideoURL)
                newPlayer.actionAtItemEnd = .none

                // Add new observer
                videoObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: newPlayer.currentItem,
                    queue: .main) { [weak newPlayer] _ in
                        print("🔄 Video ended - looping back to start (switched video)")
                        newPlayer?.seek(to: .zero)
                        newPlayer?.play()
                        print("✅ Video restarted for loop (switched video)")
                }

                if needsMeshUpdate {
                    print("Updating mesh for new aspect ratio: \(newVideoRatio)")

                    // Calculate new dimensions
                    let maxDimension: Float = 2.0
                    let width: Float
                    let height: Float

                    if newVideoRatio > 1.0 {
                        // Landscape video
                        width = maxDimension
                        height = maxDimension / newVideoRatio
                    } else {
                        // Portrait video or square
                        height = maxDimension
                        width = maxDimension * newVideoRatio
                    }

                    let halfWidth = width / 2

                    // Create new mesh with updated dimensions
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
                        let newVideoMesh = try MeshResource.generate(from: [descriptor])
                        let newVideoMaterial = VideoMaterial(avPlayer: newPlayer)

                        // Update both mesh and material
                        entity.model = ModelComponent(mesh: newVideoMesh, materials: [newVideoMaterial])
                    } catch {
                        print("Error creating new mesh: \(error)")
                        // Fallback to just updating material
                        let newVideoMaterial = VideoMaterial(avPlayer: newPlayer)
                        entity.model?.materials = [newVideoMaterial]
                    }
                } else {
                    // Just update the material if aspect ratio is similar
                    let newVideoMaterial = VideoMaterial(avPlayer: newPlayer)
                    entity.model?.materials = [newVideoMaterial]
                }

                newPlayer.play()
                print("✅ Successfully switched to video index \(newIndex) with aspect ratio \(newVideoRatio)")
            }

            lastVideoIndex = newIndex
        }

        deinit {
            Task { @MainActor in
                cleanup()
            }
        }
    }
}

enum VideoError: Error {
    case fileNotFound
}
