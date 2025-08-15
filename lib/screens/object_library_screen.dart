import 'package:flutter/material.dart';
import '../services/ar_service.dart';

class ObjectLibraryScreen extends StatefulWidget {
  const ObjectLibraryScreen({super.key});

  @override
  State<ObjectLibraryScreen> createState() => _ObjectLibraryScreenState();
}

class _ObjectLibraryScreenState extends State<ObjectLibraryScreen> {
  final ARService _arService = ARService();
  List<Map<String, dynamic>> _objects = [];
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    final objects = await _arService.getPlacedObjects();
    setState(() {
      _objects = objects;
    });
  }

  List<Map<String, dynamic>> get _filteredObjects {
    if (_selectedFilter == 'all') return _objects;
    return _objects.where((obj) => obj['objectType'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Library'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadObjects,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All', Icons.apps),
                  const SizedBox(width: 8),
                  _buildFilterChip('text', 'Text', Icons.text_fields),
                  const SizedBox(width: 8),
                  _buildFilterChip('image', 'Images', Icons.image),
                  const SizedBox(width: 8),
                  _buildFilterChip('model', '3D Models', Icons.view_in_ar),
                  const SizedBox(width: 8),
                  _buildFilterChip('video', 'Videos', Icons.video_library),
                ],
              ),
            ),
          ),
          
          // Objects List
          Expanded(
            child: _filteredObjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No objects found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Place some objects in AR to see them here',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredObjects.length,
                    itemBuilder: (context, index) {
                      final obj = _filteredObjects[index];
                      return _buildObjectCard(obj);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/ar'),
        child: const Icon(Icons.add_location),
        tooltip: 'Go to AR to place objects',
      ),
    );
  }

  Widget _buildFilterChip(String filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[800],
    );
  }

  Widget _buildObjectCard(Map<String, dynamic> obj) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getObjectColor(obj['objectType']),
          child: Icon(
            _getObjectIcon(obj['objectType']),
            color: Colors.white,
          ),
        ),
        title: Text(obj['objectId'] ?? 'Unknown Object'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(obj['content'] ?? obj['objectType'] ?? 'No content'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(obj['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleObjectAction(action, obj),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.copy),
                  SizedBox(width: 8),
                  Text('Duplicate'),
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
        onTap: () => _showObjectDetails(obj),
      ),
    );
  }

  Color _getObjectColor(String? type) {
    switch (type) {
      case 'text':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'model':
        return Colors.purple;
      case 'video':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getObjectIcon(String? type) {
    switch (type) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'model':
        return Icons.view_in_ar;
      case 'video':
        return Icons.video_library;
      default:
        return Icons.help_outline;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showObjectDetails(Map<String, dynamic> obj) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getObjectIcon(obj['objectType'])),
            const SizedBox(width: 8),
            Expanded(child: Text(obj['objectId'] ?? 'Object Details')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', obj['objectType'] ?? 'Unknown'),
            _buildDetailRow('Content', obj['content'] ?? 'No content'),
            _buildDetailRow('Scale', obj['scale']?.toString() ?? '1.0'),
            _buildDetailRow('Position', 
              'X: ${obj['positionX']?.toStringAsFixed(2) ?? '0.00'}, '
              'Y: ${obj['positionY']?.toStringAsFixed(2) ?? '0.00'}, '
              'Z: ${obj['positionZ']?.toStringAsFixed(2) ?? '0.00'}'
            ),
            _buildDetailRow('Rotation',
              'X: ${obj['rotationX']?.toStringAsFixed(2) ?? '0.00'}, '
              'Y: ${obj['rotationY']?.toStringAsFixed(2) ?? '0.00'}, '
              'Z: ${obj['rotationZ']?.toStringAsFixed(2) ?? '0.00'}'
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editObject(obj);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  void _handleObjectAction(String action, Map<String, dynamic> obj) {
    switch (action) {
      case 'edit':
        _editObject(obj);
        break;
      case 'duplicate':
        _duplicateObject(obj);
        break;
      case 'delete':
        _deleteObject(obj);
        break;
    }
  }

  void _editObject(Map<String, dynamic> obj) {
    if (obj['objectType'] == 'text') {
      _editTextObject(obj);
    } else {
      _editObjectProperties(obj);
    }
  }

  Future<void> _editTextObject(Map<String, dynamic> obj) async {
    String newContent = obj['content'] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Text Object'),
        content: TextField(
          controller: TextEditingController(text: newContent),
          onChanged: (value) => newContent = value,
          decoration: const InputDecoration(
            labelText: 'Text Content',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, newContent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      final success = await _arService.updateObject(
        objectId: obj['objectId'],
        content: result,
      );
      if (success) {
        _loadObjects();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Object updated successfully')),
        );
      }
    }
  }

  Future<void> _editObjectProperties(Map<String, dynamic> obj) async {
    double scale = obj['scale']?.toDouble() ?? 1.0;
    double rotationX = obj['rotationX']?.toDouble() ?? 0.0;
    double rotationY = obj['rotationY']?.toDouble() ?? 0.0;
    double rotationZ = obj['rotationZ']?.toDouble() ?? 0.0;

    final result = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Object Properties'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSlider('Scale', scale, 0.1, 3.0, (value) {
                setState(() => scale = value);
              }),
              _buildSlider('Rotation X', rotationX, -180, 180, (value) {
                setState(() => rotationX = value);
              }),
              _buildSlider('Rotation Y', rotationY, -180, 180, (value) {
                setState(() => rotationY = value);
              }),
              _buildSlider('Rotation Z', rotationZ, -180, 180, (value) {
                setState(() => rotationZ = value);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'scale': scale,
                'rotationX': rotationX,
                'rotationY': rotationY,
                'rotationZ': rotationZ,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final success = await _arService.updateObject(
        objectId: obj['objectId'],
        scale: result['scale'],
        rotationX: result['rotationX'],
        rotationY: result['rotationY'],
        rotationZ: result['rotationZ'],
      );
      if (success) {
        _loadObjects();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Object updated successfully')),
        );
      }
    }
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _duplicateObject(Map<String, dynamic> obj) async {
    final newObjectId = 'obj_${DateTime.now().millisecondsSinceEpoch}';
    // Since we now only support video objects, use default video asset
    final success = await _arService.placeObject(
      objectId: newObjectId,
      videoAsset: 'assets/video_(0).mov', // Default video asset
      scale: obj['scale']?.toDouble(),
      rotationX: obj['rotationX']?.toDouble(),
      rotationY: obj['rotationY']?.toDouble(),
      rotationZ: obj['rotationZ']?.toDouble(),
    );

    if (success) {
      _loadObjects();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Object duplicated successfully')),
      );
    }
  }

  Future<void> _deleteObject(Map<String, dynamic> obj) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Object'),
        content: Text('Are you sure you want to delete "${obj['objectId']}"?'),
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
      final success = await _arService.removeObject(obj['objectId']);
      if (success) {
        _loadObjects();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Object deleted successfully')),
        );
      }
    }
  }
}
