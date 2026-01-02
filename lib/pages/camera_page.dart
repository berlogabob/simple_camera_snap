import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import '../painters/gesture_painter.dart';
import '../painters/landmark_painter.dart';
import '../utils/gesture_recognizer.dart';
import '../utils/transform_utils.dart';
import '../utils/constants.dart';
import '../widgets/status_overlay.dart';
import '../widgets/detection_controls.dart';
import '../models/gesture_status.dart';

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

  int _transformMode = 3;
  int _frameSkip = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startOrientationListener();
  }

  Future<void> _initializeCamera() async {
    final frontCamera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);

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
      int newMode = switch (orientation) {
        NativeDeviceOrientation.portraitUp => 3,
        NativeDeviceOrientation.landscapeRight => 1,
        NativeDeviceOrientation.landscapeLeft => 2,
        NativeDeviceOrientation.portraitDown => 2,
        _ => 3,
      };
      if (newMode != _transformMode && mounted) {
        setState(() => _transformMode = newMode);
      }
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
        _gestureX = _gestureY = 0;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (++_frameSkip % (AppConstants.frameSkipCount + 1) != 0) return;
    if (!_isDetecting || !mounted || _landmarker == null) return;

    final hands = _landmarker!.detect(image, _controller!.description.sensorOrientation);

    GestureStatus candidate = GestureStatus.empty;
    double candidateX = 0, candidateY = 0;
    List<Landmark> candidateLandmarks = [];

    if (hands.isNotEmpty) {
      final hand = hands.first;
      candidateLandmarks = hand.landmarks;

      candidate = GestureRecognizer().recognize(candidateLandmarks, _transformMode);

      if (candidate != GestureStatus.empty && candidate != GestureStatus.warmup) {
        final wrist = candidateLandmarks[0];
        final thumbTip = candidateLandmarks[4];
        final indexTip = candidateLandmarks[8];

        final centerX = (wrist.x + thumbTip.x + indexTip.x) / 3;
        final centerY = (wrist.y + thumbTip.y + indexTip.y) / 3;

        final transformed = transformLandmark(
          x: centerX,
          y: centerY,
          sensorOrientation: _controller!.description.sensorOrientation,
          transformMode: _transformMode,
          screenSize: MediaQuery.of(context).size,
        );
        candidateX = transformed.dx;
        candidateY = transformed.dy + AppConstants.gestureYOffset;
      }
    }

    if (candidate == _status) {
      _stableCount++;
    } else {
      _stableCount = 1;
      _status = candidate;
    }

    if (_stableCount >= AppConstants.requiredStableFrames && mounted) {
      setState(() {
        _gestureX = candidateX;
        _gestureY = candidateY;
        _currentLandmarks = candidateLandmarks;
      });
    } else if (_status == GestureStatus.warmup || candidate == GestureStatus.warmup) {
      // Always update landmarks during warmup to show skeleton
      if (mounted && candidateLandmarks.isNotEmpty) {
        setState(() {
          _currentLandmarks = candidateLandmarks;
        });
      }
    }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: CameraPreview(_controller!),
          ),

          // Hand skeleton + dots (always shown when hand is visible)
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

          Center(child: StatusOverlay(_status)),

          // Final gesture emoji
          if (_status == GestureStatus.thumbsUp ||
              _status == GestureStatus.thumbsDown ||
              _status == GestureStatus.ok)
            CustomPaint(
              painter: GesturePainter(
                _status == GestureStatus.thumbsUp
                    ? '👍'
                    : _status == GestureStatus.thumbsDown
                        ? '👎'
                        : '👌',
                _gestureX,
                _gestureY,
                _status == GestureStatus.thumbsUp || _status == GestureStatus.ok
                    ? Colors.green
                    : Colors.red,
              ),
              child: const SizedBox.expand(),
            ),

          DetectionControls(
            isDetecting: _isDetecting,
            onToggle: _toggleDetection,
          ),
        ],
      ),
    );
  }
}