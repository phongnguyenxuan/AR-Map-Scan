# Hướng dẫn lưu và load ARWorldMap với Transform đầy đủ

## Tổng quan

Hệ thống này cho phép lưu và load ARWorldMap với thông tin đầy đủ về transform của video objects, bao gồm:
- **Position**: Vị trí chính xác trong không gian 3D
- **Rotation**: Góc xoay (quaternion)
- **Scale**: Kích thước
- **Anchor Information**: Thông tin về anchor và local transform

## Cấu trúc dữ liệu

### 1. ARWorldMap (.worldmap)
- File chính chứa thông tin về world mapping
- Được lưu bằng `NSKeyedArchiver`

### 2. Object Data (_objects.json)
```json
[
  {
    "objectId": "video_1",
    "objectType": "video",
    "content": "assets/video_(0).mov",
    "anchorPosition": [x, y, z],
    "anchorRotation": [x, y, z, w],
    "localPosition": [x, y, z],
    "localRotation": [x, y, z, w],
    "scale": [x, y, z],
    "worldPosition": [x, y, z]
  }
]
```

### 3. Metadata (_metadata.json)
```json
{
  "mapName": "my_map",
  "timestamp": 1234567890,
  "anchorCount": 5,
  "center": [x, y, z],
  "extent": [x, y, z]
}
```

## Cách sử dụng

### Lưu World Map
```swift
// Lưu world map với transform đầy đủ
arController.saveWorldMap(mapName: "my_map") { result in
    if result {
        print("✅ Đã lưu thành công")
    }
}
```

### Load World Map
```swift
// Load world map và restore objects
arController.loadWorldMap(mapName: "my_map") { result in
    if result {
        print("✅ Đã load thành công")
        // Objects sẽ được restore với transform chính xác
    }
}
```

## Quy trình hoạt động

### 1. Lưu (Save)
1. **Lấy ARWorldMap**: Sử dụng `session.getCurrentWorldMap()`
2. **Lưu WorldMap**: Archive và lưu file .worldmap
3. **Lưu Object Data**: Lưu transform đầy đủ của tất cả objects
4. **Lưu Metadata**: Lưu thông tin bổ sung về world map

### 2. Load (Load)
1. **Load ARWorldMap**: Unarchive từ file .worldmap
2. **Setup ARSession**: Cấu hình với `initialWorldMap`
3. **Relocalization**: Chờ relocalization hoàn thành
4. **Restore Objects**: Tạo lại objects với transform chính xác

## Transform Information

### Anchor Transform
- **Position**: Vị trí world của anchor
- **Rotation**: Góc xoay của anchor (quaternion)

### Entity Transform (Local)
- **Position**: Vị trí relative to anchor
- **Rotation**: Góc xoay relative to anchor
- **Scale**: Kích thước của entity

### World Transform
- **Position**: Vị trí tuyệt đối trong world space
- **Rotation**: Góc xoay tuyệt đối
- **Scale**: Kích thước tuyệt đối

## Debug và Monitoring

### Debug World Positioning
```swift
// Hiển thị thông tin transform của tất cả objects
arController.debugWorldPositioning()
```

### Log Output
```
🔍 === DEBUG WORLD POSITIONING ===
📦 Object: video_1
   📍 Anchor World Position: [1.0, 0.5, 2.0]
   📍 Entity Local Position: [0.0, 0.0, 0.0]
   📍 Entity World Position: [1.0, 0.5, 2.0]
   🔄 Entity Rotation: [0.0, 0.7, 0.0, 0.7]
   📏 Entity Scale: [1.0, 1.0, 1.0]
   🎬 Video Path: assets/video_(0).mov
🔍 === END DEBUG ===
```

## Lưu ý quan trọng

1. **Relocalization**: Cần chờ relocalization hoàn thành trước khi restore objects
2. **Transform Hierarchy**: Anchor transform + Entity local transform = World transform
3. **Quaternion Rotation**: Sử dụng quaternion thay vì Euler angles để tránh gimbal lock
4. **Scale Support**: Hỗ trợ non-uniform scale (x, y, z khác nhau)

## Troubleshooting

### Video không hiển thị đúng vị trí
- Kiểm tra anchor position và rotation
- Verify local transform của entity
- Debug world positioning

### Transform bị mất khi load
- Đảm bảo relocalization hoàn thành
- Kiểm tra file objects.json có đầy đủ data
- Verify quaternion values hợp lệ

### Performance Issues
- Cleanup video resources trước khi load
- Sử dụng background thread cho heavy operations
- Monitor memory usage
