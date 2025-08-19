import 'package:flutter/material.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/network/api_source.dart';
import 'package:flutter_application_ar/screens/main_screen.dart';
import 'package:flutter_application_ar/services/local_service.dart';

class PreloadScreen extends StatefulWidget {
  const PreloadScreen({super.key});

  @override
  State<PreloadScreen> createState() => _PreloadScreenState();
}

class _PreloadScreenState extends State<PreloadScreen> {
  final apiDataSource = sl.get<ApiSource>();

  @override
  void initState() {
    super.initState();
    _feetchData();
  }

  Future<void> _feetchData() async {
    final auth = await apiDataSource.login(
      'admin@vietnamdieusu.vn',
      'Abcd1234',
    );
    await sl.get<LocalService>().saveAuth(auth: auth);
    await Future.delayed(const Duration(seconds: 2));
    final arLocation = await apiDataSource.getArLocation();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(arLocation: arLocation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
