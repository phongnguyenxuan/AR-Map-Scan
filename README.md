# flutter_application_ar

# AR Persistent Objects App

A Flutter application that allows users to place AR objects (text notes, images, 3D models, videos) at real-world locations and persist them using ARKit's World Mapping capabilities.

## Features

### Core Functionality
- **World Mapping & Persistence**: Uses ARKit's World Tracking to create and save world maps
- **AR Object Placement**: Place various types of objects in AR space:
  - Text notes with 3D rendering
  - Images as AR planes
  - 3D models (placeholder implementation)
  - Video content (placeholder implementation)
- **Object Customization**: Adjust size, rotation, and position of placed objects
- **Multiple Map Support**: Save and load different AR environments
- **Local Storage**: All data persisted locally on device

### User Interface
- **Main Dashboard**: Overview of AR status, object count, and map count
- **AR View**: Live camera feed with AR object placement and interaction
- **Object Library**: Browse, edit, and manage all placed objects
- **Map Manager**: Create, load, delete, and export AR world maps

## Technical Architecture

### Flutter (Dart) Layer
- **ARService**: Method channel communication with iOS ARKit
- **DataManager**: Local data persistence using SharedPreferences
- **ARObject Model**: Data structure for AR objects
- **UI Screens**: Main, AR, Object Library, Map Manager screens

### iOS (Swift) Layer
- **ARController**: ARKit integration and world mapping
- **ARSCNView**: SceneKit rendering of AR objects
- **World Map Persistence**: Save/load ARWorldMap files
- **Object Management**: Create, update, delete AR objects

## Requirements

- iOS 13.0 or later
- Device with ARKit support (iPhone 6s or later)
- Camera permissions
- Sufficient storage for world maps and object data

## Installation

1. Clone the repository
2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
3. Install iOS dependencies:
   ```bash
   cd ios && pod install
   ```
4. Run the application:
   ```bash
   flutter run
   ```

## Usage

### Getting Started
1. Launch the app and grant camera permissions
2. Tap "Start AR" to begin AR session
3. Move device to scan environment for plane detection
4. Select object type (Text, Image, 3D Model, Video)
5. Tap "Place Object" to add objects to the AR scene

### Saving and Loading Maps
1. In AR view, tap menu → "Save Map"
2. Enter a name for your map
3. To load a saved map, tap menu → "Load Map"
4. Select from available saved maps

### Managing Objects
1. Use "Object Library" to view all placed objects
2. Edit object properties (scale, rotation, content)
3. Delete unwanted objects
4. Filter objects by type

### Map Management
1. Use "Map Manager" to view all saved maps
2. Load different maps to switch environments
3. Delete maps you no longer need
4. Export maps for backup (future feature)

## Development

### Project Structure
```
lib/
├── main.dart                 # App entry point
├── models/
│   └── ar_object.dart       # AR object data model
├── services/
│   ├── ar_service.dart      # Flutter-iOS communication
│   └── data_manager.dart    # Local data persistence
└── screens/
    ├── ar_screen.dart       # AR camera view
    ├── object_library_screen.dart
    └── map_manager_screen.dart

ios/Runner/
├── AppDelegate.swift        # Flutter app delegate
└── ARController.swift       # ARKit implementation
```

### Key Technologies
- **Flutter**: Cross-platform UI framework
- **ARKit**: iOS augmented reality framework
- **SceneKit**: 3D graphics rendering
- **Method Channels**: Flutter-iOS communication
- **SharedPreferences**: Local data storage

## Future Enhancements

- [ ] Cloud synchronization of maps and objects
- [ ] Real image and 3D model loading
- [ ] Video playback in AR
- [ ] Collaborative AR sessions
- [ ] Object animations and interactions
- [ ] Map sharing between users
- [ ] Advanced object physics
- [ ] Voice notes as AR objects

## Troubleshooting

### Common Issues
- **Camera not working**: Check camera permissions in Settings
- **AR not starting**: Ensure device supports ARKit
- **Objects not persisting**: Check storage permissions
- **Poor tracking**: Ensure good lighting and textured surfaces

### Debug Information
- Check console logs for AR session status
- Verify world map save/load operations
- Monitor object placement and anchor creation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on physical iOS device
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
