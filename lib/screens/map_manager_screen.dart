import 'package:flutter/material.dart';
import '../services/ar_service.dart';

class MapManagerScreen extends StatefulWidget {
  const MapManagerScreen({super.key});

  @override
  State<MapManagerScreen> createState() => _MapManagerScreenState();
}

class _MapManagerScreenState extends State<MapManagerScreen> {
  final ARService _arService = ARService();
  List<String> _availableMaps = [];
  String? _currentMap;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    final maps = await _arService.getAvailableMaps();
    setState(() {
      _availableMaps = maps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Manager'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _openExportedMapsInFiles,
            tooltip: 'Open in Files App',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMaps),
        ],
      ),
      body: Column(
        children: [
          // Current Map Info
          if (_currentMap != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Map',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_currentMap!),
                ],
              ),
            ),

          // Maps List
          Expanded(
            child: _availableMaps.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No saved maps',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create maps in AR view to see them here',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableMaps.length,
                    itemBuilder: (context, index) {
                      final mapName = _availableMaps[index];
                      return _buildMapCard(mapName);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/ar'),
        tooltip: 'Go to AR to create maps',
        child: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildMapCard(String mapName) {
    final isCurrentMap = _currentMap == mapName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentMap ? Colors.purple : Colors.grey[300],
          child: Icon(
            Icons.map,
            color: isCurrentMap ? Colors.white : Colors.grey[600],
          ),
        ),
        title: Text(
          mapName,
          style: TextStyle(
            fontWeight: isCurrentMap ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          children: [
            if (isCurrentMap) ...[
              Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              const Text('Currently loaded'),
            ] else
              const Text('Tap to load'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleMapAction(action, mapName),
          itemBuilder: (context) => [
            if (!isCurrentMap)
              const PopupMenuItem(
                value: 'load',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Load Map'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info),
                  SizedBox(width: 8),
                  Text('Map Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 8),
                  Text('Export'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: isCurrentMap ? null : () => _loadMap(mapName),
      ),
    );
  }

  void _handleMapAction(String action, String mapName) {
    switch (action) {
      case 'load':
        _loadMap(mapName);
        break;
      case 'info':
        _showMapInfo(mapName);
        break;
      case 'rename':
        _renameMap(mapName);
        break;
      case 'export':
        _exportMap(mapName);
        break;
      case 'delete':
        _deleteMap(mapName);
        break;
    }
  }

  Future<void> _loadMap(String mapName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading map...'),
          ],
        ),
      ),
    );

    final success = await _arService.loadWorldMap(mapName);
    Navigator.pop(context); // Close loading dialog

    if (success) {
      setState(() {
        _currentMap = mapName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Map "$mapName" loaded successfully')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load map "$mapName"')));
    }
  }

  void _showMapInfo(String mapName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Map Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', mapName),
            _buildInfoRow(
              'Status',
              _currentMap == mapName ? 'Loaded' : 'Available',
            ),
            _buildInfoRow(
              'Created',
              'Unknown',
            ), // Would need to store this info
            _buildInfoRow('Size', 'Unknown'), // Would need to calculate this
            _buildInfoRow('Objects', 'Unknown'), // Would need to count objects
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _renameMap(String oldName) async {
    String newName = oldName;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Map'),
        content: TextField(
          controller: TextEditingController(text: oldName),
          onChanged: (value) => newName = value,
          decoration: const InputDecoration(
            labelText: 'Map Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, newName),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result != oldName && result.isNotEmpty) {
      // Note: This would require implementing a rename function in the AR service
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map rename functionality not implemented yet'),
        ),
      );
    }
  }

  void _exportMap(String mapName) async {
    // Check map status first
    final availableMaps = await _arService.getAvailableMaps();
    final mapExists = availableMaps.contains(mapName);

    print("🔍 Debug: Available maps: $availableMaps");
    print("🔍 Debug: Looking for map: '$mapName'");
    print("🔍 Debug: Map exists: $mapExists");

    if (!mapExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Map "$mapName" not found. Available maps: ${availableMaps.join(", ")}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export "$mapName"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Map is ready for export',
                    style: TextStyle(color: Colors.green[700], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.file_copy),
              title: const Text('ARWorldMap File'),
              subtitle: const Text('Native iOS format'),
              onTap: () {
                Navigator.pop(context);
                _performExport(mapName, 'arworldmap');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON Data'),
              subtitle: const Text('Cross-platform format'),
              onTap: () {
                Navigator.pop(context);
                _performExport(mapName, 'json');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performExport(String mapName, String format) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Check if map exists first
      final availableMaps = await _arService.getAvailableMaps();
      if (!availableMaps.contains(mapName)) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Map "$mapName" not found. Please save the map first.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Export map
      String? exportPath = await _arService.exportWorldMap(mapName);
      if (exportPath != null) {
        print("✅ Map exported to: $exportPath");

        // Get export info
        Map<String, dynamic>? fileInfo = await _arService.getExportFileInfo(
          mapName,
        );
        if (fileInfo != null) {
          print("📊 File size: ${fileInfo['formattedSize']}");

          // Show success dialog
          Navigator.pop(context); // Close loading dialog
          _showExportSuccessDialog(mapName, fileInfo);
        } else {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Map exported but could not get file info'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export map "$mapName"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting map: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showExportSuccessDialog(String mapName, Map<String, dynamic> fileInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Map "$mapName" exported successfully!'),
            const SizedBox(height: 8),
            Text('File: ${fileInfo['fileName']}'),
            Text('Size: ${fileInfo['formattedSize']}'),
            Text('Location: ${fileInfo['filePath']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _shareExportedMap(mapName);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExportedMap(String mapName) async {
    try {
      bool shared = await _arService.shareExportedMap(mapName);
      if (shared) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sharing map "$mapName"...'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share map "$mapName"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing map: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openExportedMapsInFiles() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Try to open Files app directly first, fallback to sharing files
      bool opened = await _arService.openFilesAppDirectly();
      if (!opened) {
        opened = await _arService.openExportedMapsInFiles();
      }

      // Close loading dialog
      Navigator.pop(context);

      if (opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Files app with exported maps...'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open Files app'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening Files app: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMap(String mapName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$mapName"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All objects in this map will also be removed.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _arService.deleteWorldMap(mapName);
      if (success) {
        if (_currentMap == mapName) {
          setState(() {
            _currentMap = null;
          });
        }
        _loadMaps();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Map "$mapName" deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete map "$mapName"')),
        );
      }
    }
  }
}
