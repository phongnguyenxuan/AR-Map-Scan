import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ARPlatformView extends StatefulWidget {
  const ARPlatformView({super.key});

  @override
  State<ARPlatformView> createState() => _ARPlatformViewState();
}

class _ARPlatformViewState extends State<ARPlatformView> {
  int? _platformViewId;

  @override
  void dispose() {
    // Cleanup AR resources when widget is disposed
    if (_platformViewId != null) {
      _disposeARResources();
    }
    super.dispose();
  }

  void _disposeARResources() {
    // Send cleanup command to platform side
    const MethodChannel channel = MethodChannel('ar_persistent_objects');
    channel.invokeMethod('disposeARResources').catchError((error) {
      print('Error disposing AR resources: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is used in the platform side to register the view.
    const String viewType = 'ar_platform_view';

    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    Widget platformView;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        platformView = UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
      case TargetPlatform.android:
        platformView = AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
      default:
        platformView = Container(
          color: const Color(0xFF000000),
          child: const Center(
            child: Text(
              'AR is only supported on iOS and Android',
              style: TextStyle(color: Color(0xFFFFFFFF)),
            ),
          ),
        );
    }

    // Tap handling is now done natively in iOS
    return platformView;
  }

  void _onPlatformViewCreated(int id) {
    _platformViewId = id;
    print('AR Platform View created with ID: $id');
    print('AR session will be started automatically in iOS Platform View');
  }
}
