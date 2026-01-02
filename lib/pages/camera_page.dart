import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import '../painters/gesture_painter.dart';
import '../painters/landmark_painter.dart';
import '../utils/gesture_recognizer.dart';

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
  double _gestureX = 0;
  double _gestureY = 0;
  List<Landmark> _currentLandmarks = [];
  int _frameSkip = 0;

  int _transformMode = 3;
  int _gestureDebugMode = 0; // 0=AUTO, 1=FORCE 👍, 2=FORCE 👎, 3=FORCE warmup

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

    _landmarker = HandLandmarkerPlugin.create(
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
          newMode = 3;
          break;
        case NativeDeviceOrientation.landscapeRight:
          newMode = 1;
          break;
        case NativeDeviceOrientation.landscapeLeft:
          newMode = 2;
          break;
        case NativeDeviceOrientation.portraitDown:
          newMode = 2;
          break;
        default:
          newMode = 3;
      }
      if (newMode != _transformMode && mounted) {
        setState(() => _transformMode = newMode);
      }
    });
  }

  void _cycleTransformMode() {
    setState(() {
      _transformMode = (_transformMode + 1) % 4;
    });
  }

  void _cycleGestureDebugMode() {
    setState(() {
      _gestureDebugMode = (_gestureDebugMode + 1) % 4;
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
        _gestureX = 0;
        _gestureY = 0;
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

      candidate = GestureRecognizer().recognize(candidateLandmarks, _transformMode);

      if (candidate == GestureStatus.thumbsUp || candidate == GestureStatus.thumbsDown) {
        final Landmark thumbTip = candidateLandmarks[4];
        final Offset transformed = _transformLandmark(thumbTip.x, thumbTip.y);
        candidateX = transformed.dx;
        candidateY = transformed.dy;
      }
    }

    // Дебаг-режим жестов
    GestureStatus finalCandidate = candidate;
    List<Landmark> finalLandmarks = candidateLandmarks;
    double finalX = candidateX;
    double finalY = candidateY;

    if (_gestureDebugMode == 1) {
      finalCandidate = GestureStatus.thumbsUp;
      if (candidateLandmarks.isNotEmpty) {
        final Landmark thumbTip = candidateLandmarks[4];
        final Offset t = _transformLandmark(thumbTip.x, thumbTip.y);
        finalX = t.dx;
        finalY = t.dy;
        finalLandmarks = candidateLandmarks;
      }
    } else if (_gestureDebugMode == 2) {
      finalCandidate = GestureStatus.thumbsDown;
      if (candidateLandmarks.isNotEmpty) {
        final Landmark thumbTip = candidateLandmarks[4];
        final Offset t = _transformLandmark(thumbTip.x, thumbTip.y);
        finalX = t.dx;
        finalY = t.dy;
        finalLandmarks = candidateLandmarks;
      }
    } else if (_gestureDebugMode == 3) {
      finalCandidate = GestureStatus.warmup;
      finalLandmarks = [];
      finalX = 0;
      finalY = 0;
    }

    if (finalCandidate == _status) {
      _stableCount++;
    } else {
      _stableCount = 1;
      _status = finalCandidate;
    }

    if (_stableCount >= GestureRecognizer.requiredStableFrames && mounted) {
      setState(() {
        _gestureX = finalX;
        _gestureY = finalY;
        _currentLandmarks = finalLandmarks;
      });
    }
  }

  Offset _transformLandmark(double x, double y) {
    double tx = x;
    double ty = y;

    final int sensorOrientation = _controller!.description.sensorOrientation;

    if (sensorOrientation == 270) {
      tx = y;
      ty = x;
    } else if (sensorOrientation == 90) {
      tx = 1.0 - y;
      ty = x;
    }

    switch (_transformMode) {
      case 0:
        break;
      case 1:
        final temp = tx;
        tx = ty;
        ty = 1.0 - temp;
        break;
      case 2:
        final temp = tx;
        tx = 1.0 - ty;
        ty = temp;
        break;
      case 3:
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
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),

          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _cycleTransformMode,
              child: Container(
                color: Colors.black.withAlpha(153),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'Mode: $_transformMode (auto • tap to override)',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),

          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: _cycleGestureDebugMode,
              child: Container(
                color: Colors.black.withAlpha(153),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  _gestureDebugMode == 0
                      ? 'Gesture: AUTO'
                      : _gestureDebugMode == 1
                          ? 'Gesture: FORCE 👍'
                          : _gestureDebugMode == 2
                              ? 'Gesture: FORCE 👎'
                              : 'Gesture: FORCE WARMUP',
                  style: const TextStyle(color: Colors.orange, fontSize: 16),
                ),
              ),
            ),
          ),

          Center(child: _buildStatusOverlay()),

          if (_status == GestureStatus.thumbsUp || _status == GestureStatus.thumbsDown)
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
            Text('Show your hand', style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      case GestureStatus.warmup:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_fish_eye, size: 100, color: Colors.yellow),
            SizedBox(height: 20),
            Text('Hand detected', style: TextStyle(fontSize: 24, color: Colors.white)),
          ],
        );
      default:
        return const SizedBox();
    }
  }
}