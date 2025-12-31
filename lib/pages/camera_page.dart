import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import '../painters/gesture_painter.dart';
import '../painters/landmark_painter.dart';

enum GestureStatus { empty, warmup, thumbsUp, thumbsDown }

class CameraHomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraHomePage({super.key, required this.cameras});

  @override
  State<CameraHomePage> createState() => _CameraHomePageState();
}

class _CameraHomePageState extends State<CameraHomePage> {
  CameraController? _controller;
  HandLandmarkerPlugin? _landmarker;
  bool _isDetecting = false;
  GestureStatus _status = GestureStatus.empty;
  int _stableCount = 0;
  final int _requiredStable = 10;
  double _gestureX = 0;
  double _gestureY = 0;
  List<Landmark> _currentLandmarks = [];
  int _frameSkip = 0;

  int _transformMode = 3; // Default to mode 3 (perfect for portrait up)

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startOrientationListener();
  }

  Future<void> _initializeCamera() async {
    final CameraDescription frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();

    _landmarker = await HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );

    if (mounted) setState(() {});
  }

  void _startOrientationListener() {
    NativeDeviceOrientationCommunicator()
        .onOrientationChanged(useSensor: true)
        .listen((orientation) {
      int newMode;
      switch (orientation) {
        case NativeDeviceOrientation.portraitUp:
          newMode = 3; // Your tested perfect for main vertical
          break;
        case NativeDeviceOrientation.landscapeRight: // Home button right = rotated CW
          newMode = 1; // Your tested perfect for CW
          break;
        case NativeDeviceOrientation.landscapeLeft: // Home button left = rotated CCW
          newMode = 2; // Your tested perfect for CCW
          break;
        case NativeDeviceOrientation.portraitDown:
          newMode = 2; // Your tested perfect for 180°
          break;
        default:
          newMode = 3;
      }

      if (newMode != _transformMode && mounted) {
        setState(() => _transformMode = newMode);
      }
    });
  }

  // Optional: manual cycle for testing (tap the debug indicator)
  void _cycleTransformMode() {
    setState(() {
      _transformMode = (_transformMode + 1) % 4;
    });
  }

  void _toggleDetection() {
    setState(() => _isDetecting = !_isDetecting);
    if (_isDetecting) {
      _controller!.startImageStream(_processCameraImage);
    } else {
      _controller!.stopImageStream();
      setState(() {
        _status = GestureStatus.empty;
        _currentLandmarks = [];
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _frameSkip++;
    if (_frameSkip % 2 != 0) return;
    if (!_isDetecting || !mounted || _landmarker == null) return;

    final List<Hand> hands = _landmarker!.detect(
      image,
      _controller!.description.sensorOrientation,
    );

    GestureStatus candidate = GestureStatus.empty;
    double candidateX = 0;
    double candidateY = 0;
    List<Landmark> candidateLandmarks = [];

    if (hands.isNotEmpty) {
      final Hand hand = hands.first;
      candidateLandmarks = hand.landmarks;

      if (candidateLandmarks.length >= 21) {
        final Landmark thumbTip = candidateLandmarks[4];
        final Landmark indexTip = candidateLandmarks[8];
        final Landmark wrist = candidateLandmarks[0];

        final double thumbToWrist =
            (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();

        if (thumbToWrist < 0.1) {
          candidate = GestureStatus.warmup;
        } else {
          final double yDiff = thumbTip.y - indexTip.y;
          if (yDiff > 0.05) {
            candidate = GestureStatus.thumbsUp;
          } else if (yDiff < -0.05) {
            candidate = GestureStatus.thumbsDown;
          } else {
            candidate = GestureStatus.warmup;
          }

          final Offset transformed = _transformLandmark(indexTip.x, indexTip.y);
          candidateX = transformed.dx;
          candidateY = transformed.dy;
        }
      } else {
        candidate = GestureStatus.warmup;
      }
    }

    if (candidate == _status) {
      _stableCount++;
    } else {
      _stableCount = 1;
      _status = candidate;
    }

    if (_stableCount >= _requiredStable && mounted) {
      setState(() {
        _gestureX = candidateX;
        _gestureY = candidateY;
        _currentLandmarks = candidateLandmarks;
      });
    }
  }

  Offset _transformLandmark(double x, double y) {
    double tx = x;
    double ty = y;

    final int sensorOrientation = _controller!.description.sensorOrientation;

    // Base sensor rotation correction
    if (sensorOrientation == 270) {
      tx = y;
      ty = x;
    } else if (sensorOrientation == 90) {
      tx = 1.0 - y;
      ty = x;
    }

    // Apply your proven transform mode
    switch (_transformMode) {
      case 0:
        break;
      case 1: // CW horizontal
        final temp = tx;
        tx = ty;
        ty = 1.0 - temp;
        break;
      case 2: // CCW horizontal OR 180° vertical
        final temp = tx;
        tx = 1.0 - ty;
        ty = temp;
        break;
      case 3: // Main vertical (portrait up)
        tx = 1.0 - tx;
        ty = 1.0 - ty;
        break;
    }

    final Size screen = MediaQuery.of(context).size;
    return Offset(tx * screen.width, ty * screen.height);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _landmarker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // FIXED PREVIEW: Perfect alignment, no cropping/zoom issues
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),

          // Optional debug indicator (tap to cycle manually)
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _cycleTransformMode,
              child: Container(
                color: Colors.black.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'Mode: $_transformMode (auto from rotation • tap to override)',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

          Center(child: _buildStatusOverlay()),

          if (_status == GestureStatus.thumbsUp ||
              _status == GestureStatus.thumbsDown)
            CustomPaint(
              painter: GesturePainter(
                _status == GestureStatus.thumbsUp ? '👍' : '👎',
                _gestureX,
                _gestureY,
                _status == GestureStatus.thumbsUp ? Colors.green : Colors.red,
              ),
              child: const SizedBox.expand(),
            ),

          if (_isDetecting && _currentLandmarks.isNotEmpty)
            CustomPaint(
              painter: LandmarkPainter(
                _currentLandmarks,
                MediaQuery.of(context).size,
                _controller!.description.sensorOrientation,
                _transformMode,
              ),
              child: const SizedBox.expand(),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _toggleDetection,
                  child: Text(
                    _isDetecting ? 'Stop Detecting' : 'Start Detecting',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    switch (_status) {
      case GestureStatus.empty:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_fish_eye, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text('Show your hand',
                style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      case GestureStatus.warmup:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_fish_eye, size: 100, color: Colors.yellow),
            SizedBox(height: 20),
            Text('Hand detected',
                style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}