import 'package:flutter/material.dart';
import '../services/ar_service.dart';
import '../widgets/ar_platform_view.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  final ARService _arService = ARService();
  final bool _isARActive = true; // AR will be started by platform view
  bool _isPlaneDetectionEnabled = true;
  String _currentMapName = '';

  String get currentMapName => _currentMapName;
  List<Map<String, dynamic>> _placedObjects = [];

  @override
  void initState() {
    super.initState();
    // AR session will be started automatically by ARPlatformView
    _loadPlacedObjects();
  }

  @override
  void dispose() {
    // Cleanup AR resources when screen is disposed
    _arService.pauseARSession();
    _arService.resetARSession(); // This will cleanup all resources
    super.dispose();
  }

  // AR session is now started automatically by ARPlatformView
  // when the platform view is created

  Future<void> _loadPlacedObjects() async {
    final objects = await _arService.getPlacedObjects();
    setState(() {
      _placedObjects = objects;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('AR View'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isPlaneDetectionEnabled ? Icons.grid_on : Icons.grid_off,
            ),
            onPressed: _togglePlaneDetection,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'save_map', child: Text('Save Map')),
              const PopupMenuItem(value: 'load_map', child: Text('Load Map')),
              const PopupMenuItem(value: 'reset', child: Text('Reset Session')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // AR View - Native iOS ARKit Platform View
          _isARActive
              ? const ARPlatformView(
                  // Tap handling now done natively in iOS
                )
              : Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _togglePlaneDetection() async {
    if (_isPlaneDetectionEnabled) {
      await _arService.disablePlaneDetection();
    } else {
      await _arService.enablePlaneDetection();
    }
    setState(() {
      _isPlaneDetectionEnabled = !_isPlaneDetectionEnabled;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'save_map':
        _showSaveMapDialog();
        break;
      case 'load_map':
        _showLoadMapDialog();
        break;
      case 'reset':
        _resetARSession();
        break;
    }
  }

  Future<void> _showSaveMapDialog() async {
    String mapName = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save World Map'),
        content: TextField(
          onChanged: (value) => mapName = value,
          decoration: const InputDecoration(hintText: 'Enter map name...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, mapName),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _arService.saveWorldMap(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Map saved successfully' : 'Failed to save map',
          ),
        ),
      );
    }
  }

  Future<void> _showLoadMapDialog() async {
    final maps = await _arService.getAvailableMaps();
    if (maps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved maps available')));
      return;
    }
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load World Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: maps
              .map(
                (map) => ListTile(
                  title: Text(map),
                  onTap: () => Navigator.pop(context, map),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await _arService.loadWorldMap(result);
      if (success) {
        setState(() {
          _currentMapName = result;
        });
        _loadPlacedObjects();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Map loaded successfully' : 'Failed to load map',
          ),
        ),
      );
    }
  }

  Future<void> _resetARSession() async {
    final success = await _arService.resetARSession();
    if (success) {
      setState(() {
        _placedObjects.clear();
        _currentMapName = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AR session reset')));
    }
  }
}
