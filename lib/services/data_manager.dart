import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ar_object.dart';

class DataManager {
  static const String _objectsKey = 'ar_objects';
  static const String _mapsKey = 'ar_maps';
  static const String _currentMapKey = 'current_map';

  // Singleton pattern
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // Cache
  List<ARObject> _cachedObjects = [];
  List<String> _cachedMaps = [];
  String? _currentMap;

  // Initialize data manager
  Future<void> initialize() async {
    await _loadObjectsFromStorage();
    await _loadMapsFromStorage();
    await _loadCurrentMap();
  }

  // MARK: - AR Objects Management

  Future<List<ARObject>> getObjects({String? mapName}) async {
    if (_cachedObjects.isEmpty) {
      await _loadObjectsFromStorage();
    }
    
    if (mapName != null) {
      return _cachedObjects.where((obj) => obj.id.startsWith('${mapName}_')).toList();
    }
    
    return List.from(_cachedObjects);
  }

  Future<void> saveObject(ARObject object) async {
    final index = _cachedObjects.indexWhere((obj) => obj.id == object.id);
    if (index >= 0) {
      _cachedObjects[index] = object;
    } else {
      _cachedObjects.add(object);
    }
    
    await _saveObjectsToStorage();
  }

  Future<void> removeObject(String objectId) async {
    _cachedObjects.removeWhere((obj) => obj.id == objectId);
    await _saveObjectsToStorage();
  }

  Future<void> updateObject(ARObject object) async {
    final index = _cachedObjects.indexWhere((obj) => obj.id == object.id);
    if (index >= 0) {
      _cachedObjects[index] = object.copyWith(updatedAt: DateTime.now());
      await _saveObjectsToStorage();
    }
  }

  Future<ARObject?> getObject(String objectId) async {
    if (_cachedObjects.isEmpty) {
      await _loadObjectsFromStorage();
    }
    
    try {
      return _cachedObjects.firstWhere((obj) => obj.id == objectId);
    } catch (e) {
      return null;
    }
  }

  Future<int> getObjectCount({String? mapName}) async {
    final objects = await getObjects(mapName: mapName);
    return objects.length;
  }

  // MARK: - Maps Management

  Future<List<String>> getMaps() async {
    if (_cachedMaps.isEmpty) {
      await _loadMapsFromStorage();
    }
    return List.from(_cachedMaps);
  }

  Future<void> saveMap(String mapName) async {
    if (!_cachedMaps.contains(mapName)) {
      _cachedMaps.add(mapName);
      await _saveMapsToStorage();
    }
  }

  Future<void> removeMap(String mapName) async {
    _cachedMaps.remove(mapName);
    
    // Remove all objects associated with this map
    _cachedObjects.removeWhere((obj) => obj.id.startsWith('${mapName}_'));
    
    await _saveMapsToStorage();
    await _saveObjectsToStorage();
    
    // Clear current map if it was deleted
    if (_currentMap == mapName) {
      await setCurrentMap(null);
    }
  }

  Future<int> getMapCount() async {
    final maps = await getMaps();
    return maps.length;
  }

  Future<String?> getCurrentMap() async {
    if (_currentMap == null) {
      await _loadCurrentMap();
    }
    return _currentMap;
  }

  Future<void> setCurrentMap(String? mapName) async {
    _currentMap = mapName;
    final prefs = await SharedPreferences.getInstance();
    if (mapName != null) {
      await prefs.setString(_currentMapKey, mapName);
    } else {
      await prefs.remove(_currentMapKey);
    }
  }

  // MARK: - Export/Import

  Future<Map<String, dynamic>> exportMapData(String mapName) async {
    final objects = await getObjects(mapName: mapName);
    return {
      'mapName': mapName,
      'exportDate': DateTime.now().toIso8601String(),
      'objectCount': objects.length,
      'objects': objects.map((obj) => obj.toJson()).toList(),
    };
  }

  Future<bool> importMapData(Map<String, dynamic> mapData) async {
    try {
      final mapName = mapData['mapName'] as String;
      final objectsData = mapData['objects'] as List;
      
      // Save map
      await saveMap(mapName);
      
      // Import objects
      for (final objectData in objectsData) {
        final object = ARObject.fromJson(objectData as Map<String, dynamic>);
        await saveObject(object);
      }
      
      return true;
    } catch (e) {
      print('Error importing map data: $e');
      return false;
    }
  }

  // MARK: - File Operations

  Future<String> exportToFile(String mapName) async {
    final mapData = await exportMapData(mapName);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${mapName}_export.json');
    
    await file.writeAsString(jsonEncode(mapData));
    return file.path;
  }

  Future<bool> importFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final mapData = jsonDecode(content) as Map<String, dynamic>;
      
      return await importMapData(mapData);
    } catch (e) {
      print('Error importing from file: $e');
      return false;
    }
  }

  // MARK: - Statistics

  Future<Map<String, dynamic>> getStatistics() async {
    final objects = await getObjects();
    final maps = await getMaps();
    
    final objectsByType = <String, int>{};
    for (final obj in objects) {
      objectsByType[obj.type] = (objectsByType[obj.type] ?? 0) + 1;
    }
    
    return {
      'totalObjects': objects.length,
      'totalMaps': maps.length,
      'objectsByType': objectsByType,
      'currentMap': _currentMap,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  // MARK: - Private Methods

  Future<void> _loadObjectsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final objectsJson = prefs.getString(_objectsKey);
      
      if (objectsJson != null) {
        final objectsList = jsonDecode(objectsJson) as List;
        _cachedObjects = objectsList
            .map((obj) => ARObject.fromJson(obj as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading objects from storage: $e');
      _cachedObjects = [];
    }
  }

  Future<void> _saveObjectsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final objectsJson = jsonEncode(_cachedObjects.map((obj) => obj.toJson()).toList());
      await prefs.setString(_objectsKey, objectsJson);
    } catch (e) {
      print('Error saving objects to storage: $e');
    }
  }

  Future<void> _loadMapsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapsJson = prefs.getString(_mapsKey);
      
      if (mapsJson != null) {
        final mapsList = jsonDecode(mapsJson) as List;
        _cachedMaps = mapsList.cast<String>();
      }
    } catch (e) {
      print('Error loading maps from storage: $e');
      _cachedMaps = [];
    }
  }

  Future<void> _saveMapsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapsJson = jsonEncode(_cachedMaps);
      await prefs.setString(_mapsKey, mapsJson);
    } catch (e) {
      print('Error saving maps to storage: $e');
    }
  }

  Future<void> _loadCurrentMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentMap = prefs.getString(_currentMapKey);
    } catch (e) {
      print('Error loading current map: $e');
      _currentMap = null;
    }
  }

  // MARK: - Cleanup

  Future<void> clearAllData() async {
    _cachedObjects.clear();
    _cachedMaps.clear();
    _currentMap = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_objectsKey);
    await prefs.remove(_mapsKey);
    await prefs.remove(_currentMapKey);
  }
}
