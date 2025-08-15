import 'package:flutter/services.dart';
import 'dart:async';

class ARService {
  static const MethodChannel _channel = MethodChannel('ar_persistent_objects');

  // AR Session Management
  Future<bool> startARSession() async {
    try {
      final result = await _channel.invokeMethod('startARSession');
      return result ?? false;
    } catch (e) {
      print('Error starting AR session: $e');
      return false;
    }
  }

  Future<bool> pauseARSession() async {
    try {
      final result = await _channel.invokeMethod('pauseARSession');
      return result ?? false;
    } catch (e) {
      print('Error pausing AR session: $e');
      return false;
    }
  }

  Future<bool> resetARSession() async {
    try {
      final result = await _channel.invokeMethod('resetARSession');
      return result ?? false;
    } catch (e) {
      print('Error resetting AR session: $e');
      return false;
    }
  }

  // World Map Management
  Future<bool> saveWorldMap(String mapName) async {
    try {
      final result = await _channel.invokeMethod('saveWorldMap', {
        'mapName': mapName,
      });
      return result ?? false;
    } catch (e) {
      print('Error saving world map: $e');
      return false;
    }
  }

  Future<bool> loadWorldMap(String mapName) async {
    try {
      final result = await _channel.invokeMethod('loadWorldMap', {
        'mapName': mapName,
      });
      return result ?? false;
    } catch (e) {
      print('Error loading world map: $e');
      return false;
    }
  }

  Future<List<String>> getAvailableMaps() async {
    try {
      final result = await _channel.invokeMethod('getAvailableMaps');
      return List<String>.from(result ?? []);
    } catch (e) {
      print('Error getting available maps: $e');
      return [];
    }
  }

  Future<bool> deleteWorldMap(String mapName) async {
    try {
      final result = await _channel.invokeMethod('deleteWorldMap', {
        'mapName': mapName,
      });
      return result ?? false;
    } catch (e) {
      print('Error deleting world map: $e');
      return false;
    }
  }

  // AR Object Management - Video from Assets
  Future<bool> placeObject({
    required String objectId,
    String? videoAsset,
    double? scale,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? tapX,
    double? tapY,
  }) async {
    try {
      // Default to first video if no specific asset is provided
      final String selectedVideo = videoAsset ?? 'assets/video_(0).mov';

      // Validate that the video asset exists in our available videos
      final List<String> availableVideos = [
        'assets/video_(-1).mov',
        'assets/video_(0).mov',
        'assets/video_(1).mov',
      ];

      if (!availableVideos.contains(selectedVideo)) {
        print(
          'Warning: Video asset $selectedVideo not found. Using default video.',
        );
      }

      final result = await _channel.invokeMethod('placeObject', {
        'objectType': 'video',
        'objectId': objectId,
        'videoPath': selectedVideo,
        'scale': scale ?? 1.0,
        'rotationX': rotationX ?? 0.0,
        'rotationY': rotationY ?? 0.0,
        'rotationZ': rotationZ ?? 0.0,
        'tapX': tapX ?? 0.5, // Default to center if not provided
        'tapY': tapY ?? 0.5, // Default to center if not provided
      });
      return result ?? false;
    } catch (e) {
      print('Error placing video object: $e');
      return false;
    }
  }

  // Helper method to get available video assets
  List<String> getAvailableVideoAssets() {
    return [
      'assets/video_(-1).mov',
      'assets/video_(0).mov',
      'assets/video_(1).mov',
    ];
  }

  // Method to place specific video by index (0, 1, or -1)
  Future<bool> placeVideoByIndex({
    required String objectId,
    required int videoIndex,
    double? scale,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? tapX,
    double? tapY,
  }) async {
    final String videoAsset = 'assets/video_($videoIndex).mov';
    return placeObject(
      objectId: objectId,
      videoAsset: videoAsset,
      scale: scale,
      rotationX: rotationX,
      rotationY: rotationY,
      rotationZ: rotationZ,
      tapX: tapX,
      tapY: tapY,
    );
  }

  // Enable dynamic video switching based on camera angle
  Future<bool> enableAngleBasedVideoSwitching({
    required String objectId,
    bool enabled = true,
  }) async {
    try {
      final result = await _channel.invokeMethod(
        'enableAngleBasedVideoSwitching',
        {'objectId': objectId, 'enabled': enabled},
      );
      return result ?? false;
    } catch (e) {
      print('Error enabling angle-based video switching: $e');
      return false;
    }
  }

  // Switch video for existing object based on angle
  Future<bool> switchVideoByAngle({
    required String objectId,
    required int videoIndex, // -1 (left), 0 (center), 1 (right)
  }) async {
    try {
      final String videoAsset = 'assets/video_($videoIndex).mov';
      final result = await _channel.invokeMethod('switchVideoByAngle', {
        'objectId': objectId,
        'videoPath': videoAsset,
        'videoIndex': videoIndex,
      });
      return result ?? false;
    } catch (e) {
      print('Error switching video by angle: $e');
      return false;
    }
  }

  Future<bool> removeObject(String objectId) async {
    try {
      final result = await _channel.invokeMethod('removeObject', {
        'objectId': objectId,
      });
      return result ?? false;
    } catch (e) {
      print('Error removing object: $e');
      return false;
    }
  }

  Future<bool> updateObject({
    required String objectId,
    String? content,
    double? scale,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
  }) async {
    try {
      final result = await _channel.invokeMethod('updateObject', {
        'objectId': objectId,
        'content': content,
        'scale': scale,
        'rotationX': rotationX,
        'rotationY': rotationY,
        'rotationZ': rotationZ,
      });
      return result ?? false;
    } catch (e) {
      print('Error updating object: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPlacedObjects() async {
    try {
      final result = await _channel.invokeMethod('getPlacedObjects');
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      print('Error getting placed objects: $e');
      return [];
    }
  }

  // Status and Statistics
  Future<String> getARStatus() async {
    try {
      final result = await _channel.invokeMethod('getARStatus');
      return result ?? 'Unknown';
    } catch (e) {
      print('Error getting AR status: $e');
      return 'Error';
    }
  }

  Future<int> getObjectCount() async {
    try {
      final result = await _channel.invokeMethod('getObjectCount');
      return result ?? 0;
    } catch (e) {
      print('Error getting object count: $e');
      return 0;
    }
  }

  Future<int> getMapCount() async {
    try {
      final result = await _channel.invokeMethod('getMapCount');
      return result ?? 0;
    } catch (e) {
      print('Error getting map count: $e');
      return 0;
    }
  }

  // Camera and Detection
  Future<bool> enablePlaneDetection() async {
    try {
      final result = await _channel.invokeMethod('enablePlaneDetection');
      return result ?? false;
    } catch (e) {
      print('Error enabling plane detection: $e');
      return false;
    }
  }

  Future<bool> disablePlaneDetection() async {
    try {
      final result = await _channel.invokeMethod('disablePlaneDetection');
      return result ?? false;
    } catch (e) {
      print('Error disabling plane detection: $e');
      return false;
    }
  }

  // Event Stream for AR updates
  Stream<Map<String, dynamic>> get arEventStream {
    return _channel.invokeMethod('getAREventStream').asStream().map((event) {
      return Map<String, dynamic>.from(event ?? {});
    });
  }

  // MARK: - Map Export/Import Features

  /// Export a world map to a shareable file
  /// Returns the file path where the exported map is saved
  Future<String?> exportWorldMap(String mapName) async {
    try {
      final result = await _channel.invokeMethod('exportWorldMap', {
        'mapName': mapName,
      });
      return result;
    } catch (e) {
      print('Error exporting world map: $e');
      return null;
    }
  }

  /// Import a world map from a file
  /// Returns the imported map name
  Future<String?> importWorldMap(String filePath) async {
    try {
      final result = await _channel.invokeMethod('importWorldMap', {
        'filePath': filePath,
      });
      return result;
    } catch (e) {
      print('Error importing world map: $e');
      return null;
    }
  }

  /// Get export file info (size, creation date, etc.)
  Future<Map<String, dynamic>?> getExportFileInfo(String mapName) async {
    try {
      final result = await _channel.invokeMethod('getExportFileInfo', {
        'mapName': mapName,
      });
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      print('Error getting export file info: $e');
      return null;
    }
  }

  /// Share exported map file
  /// Returns success status
  Future<bool> shareExportedMap(String mapName) async {
    try {
      final result = await _channel.invokeMethod('shareExportedMap', {
        'mapName': mapName,
      });
      return result ?? false;
    } catch (e) {
      print('Error sharing exported map: $e');
      return false;
    }
  }

  /// Get all exported map files
  Future<List<Map<String, dynamic>>> getExportedMaps() async {
    try {
      final result = await _channel.invokeMethod('getExportedMaps');
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      print('Error getting exported maps: $e');
      return [];
    }
  }

  /// Open exported maps in Files app
  Future<bool> openExportedMapsInFiles() async {
    try {
      final result = await _channel.invokeMethod('openExportedMapsInFiles');
      return result ?? false;
    } catch (e) {
      print('Error opening exported maps in Files: $e');
      return false;
    }
  }

  /// Get exported maps directory path
  Future<String?> getExportedMapsDirectory() async {
    try {
      final result = await _channel.invokeMethod('getExportedMapsDirectory');
      return result;
    } catch (e) {
      print('Error getting exported maps directory: $e');
      return null;
    }
  }

  /// Open Files app directly
  Future<bool> openFilesAppDirectly() async {
    try {
      final result = await _channel.invokeMethod('openFilesAppDirectly');
      return result ?? false;
    } catch (e) {
      print('Error opening Files app directly: $e');
      return false;
    }
  }

  /// Delete exported map file
  Future<bool> deleteExportedMap(String fileName) async {
    try {
      final result = await _channel.invokeMethod('deleteExportedMap', {
        'fileName': fileName,
      });
      return result ?? false;
    } catch (e) {
      print('Error deleting exported map: $e');
      return false;
    }
  }
}
