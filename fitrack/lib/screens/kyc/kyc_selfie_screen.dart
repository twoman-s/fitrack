import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme.dart';

/// Liveness steps the user must complete in order.
enum _LivenessStep { blink, turnLeft, turnRight, done }

class KycSelfieScreen extends StatefulWidget {
  const KycSelfieScreen({super.key});

  @override
  State<KycSelfieScreen> createState() => _KycSelfieScreenState();
}

class _KycSelfieScreenState extends State<KycSelfieScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;

  _LivenessStep _step = _LivenessStep.blink;
  bool _processing = false;
  bool _faceFound = false;
  Uint8List? _capturedImage;

  // Blink detection state
  bool _eyesWereClosed = false;

  // Track which steps have been completed for the progress chips
  final Set<_LivenessStep> _completedSteps = {};

  @override
  void initState() {
    super.initState();
    // ML Kit is native-only; skip on web.
    if (!kIsWeb) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      // NV21 is Android-only; use jpeg on iOS/web.
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android && !kIsWeb
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    // Image streaming is not supported on web.
    if (!kIsWeb) {
      _controller!.startImageStream(_processFrame);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _step == _LivenessStep.done) return;
    _processing = true;

    try {
      final inputImage = _cameraImageToInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;
      setState(() => _faceFound = faces.isNotEmpty);
      if (faces.isEmpty) return;

      final face = faces.first;

      switch (_step) {
        case _LivenessStep.blink:
          final leftOpen = face.leftEyeOpenProbability ?? 1.0;
          final rightOpen = face.rightEyeOpenProbability ?? 1.0;
          final eyesClosed = leftOpen < 0.3 && rightOpen < 0.3;
          if (eyesClosed) {
            _eyesWereClosed = true;
          } else if (_eyesWereClosed && leftOpen > 0.7 && rightOpen > 0.7) {
            setState(() {
              _completedSteps.add(_LivenessStep.blink);
              _step = _LivenessStep.turnLeft;
            });
            _eyesWereClosed = false;
          }
          break;

        case _LivenessStep.turnLeft:
          final yaw = face.headEulerAngleY ?? 0;
          if (yaw < -15) {
            setState(() {
              _completedSteps.add(_LivenessStep.turnLeft);
              _step = _LivenessStep.turnRight;
            });
          }
          break;

        case _LivenessStep.turnRight:
          final yaw = face.headEulerAngleY ?? 0;
          if (yaw > 15) {
            setState(() => _completedSteps.add(_LivenessStep.turnRight));
            await _captureAndFinish();
          }
          break;

        case _LivenessStep.done:
          break;
      }
    } catch (_) {
      // ignore individual frame errors
    } finally {
      _processing = false;
    }
  }

  Future<void> _captureAndFinish() async {
    await _controller?.stopImageStream();
    try {
      final xFile = await _controller?.takePicture();
      if (xFile != null) {
        _capturedImage = await xFile.readAsBytes();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _step = _LivenessStep.done);
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    final camera = _controller?.description;
    if (camera == null || image.planes.isEmpty) return null;

    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
        ?? InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // NV21 (Android) has 2 planes: Y then interleaved UV.
    // Both must be concatenated into a single buffer for ML Kit to work.
    int totalLength = 0;
    for (final plane in image.planes) {
      totalLength += plane.bytes.length;
    }
    final allBytes = Uint8List(totalLength);
    int offset = 0;
    for (final plane in image.planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: allBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _proceed() {
    context.push('/kyc/age', extra: _capturedImage);
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (!kIsWeb) _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Liveness Check'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: kIsWeb ? _buildWebBody() : _buildNativeBody(),
    );
  }

  // ── Web fallback: simple capture button, no liveness ─────────────────────
  bool _webCapturing = false;

  Widget _buildWebBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null && _controller!.value.isInitialized)
          CameraPreview(_controller!),
        CustomPaint(painter: const _OvalOverlayPainter(faceDetected: false)),
        Positioned(
          bottom: 48,
          left: 24,
          right: 24,
          child: _step != _LivenessStep.done
              ? Column(
                  children: [
                    const Text(
                      'Position your face in the oval,\nthen tap Capture Selfie.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _webCapturing ? null : _webCapture,
                        icon: _webCapturing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(LucideIcons.camera, color: Colors.black),
                        label: Text(
                          _webCapturing ? 'Capturing…' : 'Capture Selfie',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildDoneOverlay(),
        ),
      ],
    );
  }

  Future<void> _webCapture() async {
    setState(() => _webCapturing = true);
    try {
      final xFile = await _controller?.takePicture();
      if (xFile != null) {
        _capturedImage = await xFile.readAsBytes();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _webCapturing = false;
      _step = _LivenessStep.done;
    });
  }

  // ── Native body: full liveness flow ──────────────────────────────────────
  Widget _buildNativeBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller != null && _controller!.value.isInitialized)
          CameraPreview(_controller!),
        CustomPaint(
          painter: _OvalOverlayPainter(
            faceDetected: _faceFound && _step != _LivenessStep.done,
          ),
        ),
        if (_step != _LivenessStep.done)
          Positioned(
            top: 16,
            left: 24,
            right: 24,
            child: _StepChips(
              current: _step,
              completed: _completedSteps,
            ),
          ),
        if (_step != _LivenessStep.done)
          Positioned(
            bottom: 100,
            left: 24,
            right: 24,
            child: _InstructionCard(
              step: _step,
              faceFound: _faceFound,
            ),
          ),
        if (_step == _LivenessStep.done)
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: _buildDoneOverlay(),
          ),
      ],
    );
  }

  // ── Shared done overlay ───────────────────────────────────────────────────
  Widget _buildDoneOverlay() {
    return Column(
      children: [
        if (_capturedImage != null)
          ClipOval(
            child: Image.memory(
              _capturedImage!,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Selfie captured ✓',
          style: TextStyle(
            color: AppTheme.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _proceed,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Instruction card ──────────────────────────────────────────────────────────

class _InstructionCard extends StatelessWidget {
  final _LivenessStep step;
  final bool faceFound;

  const _InstructionCard({required this.step, required this.faceFound});

  String get _instruction {
    if (!faceFound) return 'Position your face inside the oval';
    switch (step) {
      case _LivenessStep.blink:
        return 'Blink once slowly';
      case _LivenessStep.turnLeft:
        return 'Slowly turn your head to the left';
      case _LivenessStep.turnRight:
        return 'Slowly turn your head to the right';
      case _LivenessStep.done:
        return '';
    }
  }

  IconData get _icon {
    if (!faceFound) return LucideIcons.scanFace;
    switch (step) {
      case _LivenessStep.blink:
        return LucideIcons.eye;
      case _LivenessStep.turnLeft:
        return LucideIcons.arrowLeft;
      case _LivenessStep.turnRight:
        return LucideIcons.arrowRight;
      case _LivenessStep.done:
        return LucideIcons.checkCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Oval overlay painter ──────────────────────────────────────────────────────

class _OvalOverlayPainter extends CustomPainter {
  final bool faceDetected;
  const _OvalOverlayPainter({this.faceDetected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: size.width * 0.65,
      height: size.height * 0.42,
    );

    // Darken outside oval
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(ovalRect);
    final clippedPath = Path.combine(PathOperation.difference, outerPath, ovalPath);

    canvas.drawPath(
      clippedPath,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    // Oval border — green when face detected, white otherwise
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = faceDetected ? AppTheme.primary : Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalOverlayPainter old) =>
      old.faceDetected != faceDetected;
}

// ── Step progress chips ───────────────────────────────────────────────────────

class _StepChips extends StatelessWidget {
  final _LivenessStep current;
  final Set<_LivenessStep> completed;

  const _StepChips({required this.current, required this.completed});

  static const _steps = [
    (_LivenessStep.blink, 'Blink', LucideIcons.eye),
    (_LivenessStep.turnLeft, 'Turn Left', LucideIcons.arrowLeft),
    (_LivenessStep.turnRight, 'Turn Right', LucideIcons.arrowRight),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _steps.map((entry) {
        final (step, label, icon) = entry;
        final isDone = completed.contains(step);
        final isActive = current == step;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.primary.withValues(alpha: 0.9)
                  : isActive
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? AppTheme.primary
                    : isActive
                        ? Colors.white54
                        : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDone ? LucideIcons.checkCircle : icon,
                  size: 14,
                  color: isDone ? Colors.black : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDone ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
