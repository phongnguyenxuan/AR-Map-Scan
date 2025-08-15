import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/ar_service.dart';
import 'screens/ar_screen.dart';
import 'screens/object_library_screen.dart';
import 'screens/map_manager_screen.dart';

void main() {
  runApp(const ARPersistentApp());
}

class ARPersistentApp extends StatelessWidget {
  const ARPersistentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Persistent Objects',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MainScreen(),
      routes: {
        '/ar': (context) => const ARScreen(),
        '/objects': (context) => const ObjectLibraryScreen(),
        '/maps': (context) => const MapManagerScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ARService _arService = ARService();
  String _arStatus = 'Not Started';
  int _objectCount = 0;
  int _mapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final status = await _arService.getARStatus();
      final objects = await _arService.getObjectCount();
      final maps = await _arService.getMapCount();

      setState(() {
        _arStatus = status;
        _objectCount = objects;
        _mapCount = maps;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Persistent Objects'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AR Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Status: $_arStatus'),
                    Text('Objects: $_objectCount'),
                    Text('Maps: $_mapCount'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Main Actions
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    'Start AR',
                    Icons.camera_alt,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/ar'),
                  ),
                  _buildActionCard(
                    'Object Library',
                    Icons.inventory,
                    Colors.orange,
                    () => Navigator.pushNamed(context, '/objects'),
                  ),
                  _buildActionCard(
                    'Map Manager',
                    Icons.map,
                    Colors.purple,
                    () => Navigator.pushNamed(context, '/maps'),
                  ),
                  _buildActionCard(
                    'Settings',
                    Icons.settings,
                    Colors.grey,
                    () => _showSettings(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadStats,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About'),
              subtitle: Text('AR Persistent Objects v1.0'),
            ),
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
}
