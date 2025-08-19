import 'package:flutter/material.dart';

class CheckDownloadedScreen extends StatefulWidget {
  final int culturalSiteId;
  final int arLocationId;
  const CheckDownloadedScreen({
    super.key,
    required this.culturalSiteId,
    required this.arLocationId,
  });

  @override
  State<CheckDownloadedScreen> createState() => _CheckDownloadedScreenState();
}

class _CheckDownloadedScreenState extends State<CheckDownloadedScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Check Downloaded')),
      body: Center(child: Text('Check Downloaded')),
    );
  }
}
