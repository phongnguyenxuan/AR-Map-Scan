# Hướng dẫn sử dụng Gesture Control cho Zoom và Rotate

## Tổng quan

Hệ thống gesture control cho phép người dùng zoom và rotate video objects trong AR bằng cách sử dụng gesture recognizers:
- **Pinch Gesture**: Zoom in/out video
- **Rotation Gesture**: Rotate video

## Cách hoạt động

### 1. Gesture Recognizers
- `UIPinchGestureRecognizer`: Xử lý pinch để zoom
- `UIRotationGestureRecognizer`: Xử lý rotation để xoay

### 2. Video Selection
- Chỉ có thể zoom/rotate một video tại một thời điểm
- Cần select video trước khi sử dụng gesture

## Cách sử dụng

### 1. Setup Gesture Recognizers
```swift
// Tự động setup khi start AR session
arController.startARSession()
```

### 2. Enable/Disable Gesture Control
```dart
// Enable gesture control
await arService.enableGestureControl(true);

// Disable gesture control
await arService.enableGestureControl(false);
```

### 3. Select Video cho Gesture Control
```dart
// Select video để có thể zoom/rotate
await arService.selectVideoForGestureControl("video_1");
```

### 4. Sử dụng Gesture
- **Pinch**: Zoom in/out video (scale từ 0.1 đến 6.0)
- **Rotate**: Xoay video quanh trục Y

## Implementation Details

### iOS (ARController.swift)

#### Gesture Setup
```swift
func setupGestureRecognizers(for arView: ARView) {
    // Setup rotation gesture
    rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
    arView.addGestureRecognizer(rotationGestureRecognizer!)
    
    // Setup pinch gesture for zoom
    pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
    arView.addGestureRecognizer(pinchGestureRecognizer!)
}
```

#### Handle Rotation
```swift
@objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
    guard let entity = currentVideoEntity, gesture.state == .changed else { return }

    let rotation = Float(-gesture.rotation)
    entity.orientation *= simd_quatf(angle: rotation, axis: [0, 1, 0])
    gesture.rotation = 0
}
```

#### Handle Pinch
```swift
@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    guard let entity = currentVideoEntity, gesture.state == .changed else { return }

    let scale = Float(gesture.scale)
    let currentScale = entity.transform.scale
    let newScale = currentScale * scale

    entity.transform.scale = SIMD3<Float>(repeating: min(max(newScale.x, 0.1), 6.0))
    gesture.scale = 1
}
```

### Flutter (ARService.dart)

#### Setup Gesture Recognizers
```dart
Future<bool> setupGestureRecognizers() async {
  try {
    final result = await _channel.invokeMethod('setupGestureRecognizers');
    return result ?? false;
  } catch (e) {
    print('Error setting up gesture recognizers: $e');
    return false;
  }
}
```

#### Enable/Disable Control
```dart
Future<bool> enableGestureControl(bool enabled) async {
  try {
    final result = await _channel.invokeMethod('enableGestureControl', {
      'enabled': enabled,
    });
    return result ?? false;
  } catch (e) {
    print('Error enabling gesture control: $e');
    return false;
  }
}
```

#### Select Video
```dart
Future<bool> selectVideoForGestureControl(String objectId) async {
  try {
    final result = await _channel.invokeMethod('selectVideoForGestureControl', {
      'objectId': objectId,
    });
    return result ?? false;
  } catch (e) {
    print('Error selecting video for gesture control: $e');
    return false;
  }
}
```

## Workflow hoàn chỉnh

### 1. Start AR Session
```dart
await arService.startARSession();
// Gesture recognizers sẽ được setup tự động
```

### 2. Place Video Object
```dart
await arService.placeObject(
  objectId: "video_1",
  videoAsset: "assets/video_(0).mov",
);
```

### 3. Select Video cho Gesture Control
```dart
await arService.selectVideoForGestureControl("video_1");
```

### 4. Sử dụng Gesture
- Pinch để zoom in/out
- Rotate để xoay video

### 5. Disable khi cần
```dart
await arService.enableGestureControl(false);
```

## Lưu ý quan trọng

### 1. Video Selection
- Chỉ có thể select một video tại một thời điểm
- Nếu không select video, gesture sẽ không hoạt động

### 2. Scale Limits
- Zoom scale được giới hạn từ 0.1 đến 6.0
- Prevents video quá nhỏ hoặc quá lớn

### 3. Rotation Axis
- Rotation chỉ xoay quanh trục Y (vertical)
- Để xoay các trục khác, sử dụng `updateObject` với rotationX, rotationY, rotationZ

### 4. Performance
- Gesture recognizers được enable/disable để tối ưu performance
- Disable khi không cần thiết

## Troubleshooting

### Gesture không hoạt động
1. Kiểm tra AR session đã start chưa
2. Verify video đã được select cho gesture control
3. Check gesture control đã được enable chưa

### Video không zoom/rotate
1. Kiểm tra `currentVideoEntity` có được set đúng không
2. Verify gesture state là `.changed`
3. Check console logs để debug

### Performance Issues
1. Disable gesture control khi không sử dụng
2. Select video cụ thể thay vì để tất cả
3. Monitor memory usage

## Debug Logs

Hệ thống có detailed logging:
```
✅ Đã setup gesture recognizers cho zoom và rotate
🎯 Đã set current video entity: video_1
🔄 Đã rotate video: video_1 với góc: 0.5
📏 Đã zoom video: video_1 với scale: [1.2, 1.2, 1.2]
🎮 Gesture control: enabled
```
