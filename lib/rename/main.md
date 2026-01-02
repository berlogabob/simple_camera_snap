import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'pages/camera_page.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hand Gesture Cam',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: CameraHomePage(cameras: _cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}