import 'package:flutter/material.dart';
import 'package:flutter_application_ar/config/auth_interceptor.dart';
import 'package:flutter_application_ar/config/initialize_dependencies.dart';
import 'package:flutter_application_ar/models/auth_model.dart';
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
  final emailController = TextEditingController(text: 'admin@vietnamdieusu.vn');
  final passwordController = TextEditingController(text: 'Abcd1234');
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
    });
    final auth = await apiDataSource.login(
      'admin@vietnamdieusu.vn',
      'Abcd1234',
    );
    await sl.get<LocalService>().saveAuth(auth: auth);
    sl.get<Oauth2Manager<AuthModel>>().add(auth);
    setState(() {
      isLoading = false;
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    //login
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await _login();
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
