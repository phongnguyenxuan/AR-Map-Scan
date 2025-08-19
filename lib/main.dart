import 'package:flutter/material.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/preload_screen.dart';
import 'package:flutter_application_ar/screens/list_ar_location.dart';
import 'screens/object_library_screen.dart';
import 'screens/map_manager_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDependencies();
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
      home: const PreloadScreen(),
      routes: {
        '/objects': (context) => const ObjectLibraryScreen(),
        '/maps': (context) => const MapManagerScreen(),
        '/list-ar-location': (context) => const ListArLocationScreen(),
      },
    );
  }
}
