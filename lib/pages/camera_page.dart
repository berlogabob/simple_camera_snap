import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:flutter/services.dart';
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

  int _debugTransformMode = 0; // 0-3 for debugging rotation/flip

  void _cycleTransformMode() {
    setState(() {
      _debugTransformMode = (_debugTransformMode + 1) % 4;
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
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

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
    });
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
        final double thumbToWrist = (thumbTip.x - wrist.x).abs() + (thumbTip.y - wrist.y).abs();

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

    if (_stableCount >= _requiredStable) {
      if (mounted) {
        setState(() {
          _gestureX = candidateX;
          _gestureY = candidateY;
          _currentLandmarks = candidateLandmarks;
        });
      }
    }
  }

  Offset _transformLandmark(double x, double y) {
    double tx = x;
    double ty = y;

    final int orientation = _controller!.description.sensorOrientation;

    // Base sensor rotation
    if (orientation == 270) {
      tx = y;
      ty = x;
    } else if (orientation == 90) {
      tx = 1.0 - y;
      ty = x;
    }

    // 4 debug modes - start all the same
    switch (_debugTransformMode) {
      case 0: // Main vertical
        break;
      case 1: // CW horizontal
        final double temp = tx;
        tx = ty;
        ty = 1.0 - temp;
        break;
      case 2: // CCW horizontal
        final double temp = tx;
        tx = 1.0 - ty;
        ty = temp;
        break;
      case 3: // 180 vertical
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Your current full-fill preview here (LayoutBuilder or FittedBox)
          LayoutBuilder(
            builder: (context, constraints) {
              final Size screen = Size(constraints.maxWidth, constraints.maxHeight);
              final Size preview = _controller!.value.previewSize!;
              final double screenAspect = screen.width / screen.height;
              final double previewAspect = preview.width / preview.height;

              double scale;
              if (screenAspect > previewAspect) {
                scale = screen.height / preview.height;
              } else {
                scale = screen.width / preview.width;
              }

              return Center(
                child: Transform.scale(
                  scale: scale,
                  child: CameraPreview(_controller!),
                ),
              );
            },
          ),

          // Debug mode indicator - tap to cycle
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
                  'Debug Mode: $_debugTransformMode (tap to cycle 0-3)',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
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
                _debugTransformMode, // pass mode
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
    // ... same as before
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