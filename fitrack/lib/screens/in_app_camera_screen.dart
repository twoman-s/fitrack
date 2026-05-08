import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/kyc_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/face_verification_service.dart';
import '../widgets/camera_guide_overlay.dart';
import 'crop_normalization_editor.dart';

/// In-app camera with fixed 3:4 aspect ratio preview and lightweight
/// framing guides. For FRONT photos, runs live ML Kit face detection
/// and overlays a bounding box + identity confidence on the preview.
///
/// Pops with a [CropResult], or `null` if the user cancels.
class InAppCameraScreen extends ConsumerStatefulWidget {
  final String photoType;

  const InAppCameraScreen({super.key, required this.photoType});

  @override
  ConsumerState<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends ConsumerState<InAppCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;
  bool _showGuides = true;

  // ── Live face detection (FRONT only) ──────────────────────────────────────
  FaceDetector? _faceDetector;

  /// Normalized bounding box [0,1] in display-image space. Null = no face.
  Rect? _faceRect;

  /// Cosine similarity against KYC embedding. Null = KYC not available.
  double? _similarity;

  bool _isProcessing = false;
  int _frameCount = 0;
  List<double>? _kycEmbedding;
  String? _displayName;

  bool get _isFrontPhoto => widget.photoType == 'FRONT';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    if (_isFrontPhoto) _loadKycData();
  }

  /// Fetches KYC face embedding and user display name for the live overlay.
  Future<void> _loadKycData() async {
    try {
      final kycStatus = await ref.read(kycStatusProvider.future);
      final profile = await ref.read(userProfileProvider.future);
      if (!mounted) return;
      setState(() {
        _kycEmbedding = kycStatus.faceEmbedding;
        _displayName = profile.displayName;
      });
    } catch (_) {
      // Non-critical — detection still works, just without similarity score.
    }
  }

  Future<void> _initCamera() async {
    // Close any existing face detector before re-initialising.
    await _faceDetector?.close();
    _faceDetector = null;

    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = 'Unable to access camera.';
        });
      }
      return;
    }

    if (cameras.isEmpty) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = 'No camera found on this device.';
        });
      }
      return;
    }

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = 'Camera could not be initialized.';
        });
      }
      return;
    }

    // Start image stream for live face detection (FRONT only).
    if (_isFrontPhoto) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      try {
        await controller.startImageStream(_onCameraFrame);
      } catch (_) {
        // Non-fatal — preview still works without the stream.
      }
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _isInitializing = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _faceDetector?.close();
      _faceDetector = null;
      if (mounted) setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      if (_isFrontPhoto) _loadKycData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  // ── Image stream processing ────────────────────────────────────────────────

  /// Called for every camera frame. Throttled to ~1 fps for ML Kit.
  void _onCameraFrame(CameraImage image) {
    _frameCount++;
    if (_frameCount % 20 != 0) return; // ~1.5 fps at 30 fps camera
    if (_isProcessing || _isCapturing || !mounted) return;
    _isProcessing = true;
    _detectFace(image);
  }

  Future<void> _detectFace(CameraImage image) async {
    File? tempFile;
    try {
      // Camera stream with ImageFormatGroup.jpeg gives JPEG bytes directly.
      final jpegBytes = Uint8List.fromList(image.planes.first.bytes);
      final tempPath =
          '${Directory.systemTemp.path}/lfd_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(jpegBytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _faceRect = null;
          _similarity = null;
        });
        return;
      }

      // Use the largest detected face.
      faces.sort((a, b) =>
          (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;

      // Determine display-space image dimensions (after EXIF/sensor rotation).
      final controller = _controller;
      if (controller == null || !mounted) return;
      final previewSize = controller.value.previewSize!;
      final sensorOrientation = controller.description.sensorOrientation;
      final Size displaySize;
      if (sensorOrientation == 90 || sensorOrientation == 270) {
        displaySize = Size(previewSize.height, previewSize.width);
      } else {
        displaySize = Size(previewSize.width, previewSize.height);
      }

      // Normalise bounding box to [0, 1] in display space.
      final normRect = Rect.fromLTWH(
        face.boundingBox.left / displaySize.width,
        face.boundingBox.top / displaySize.height,
        face.boundingBox.width / displaySize.width,
        face.boundingBox.height / displaySize.height,
      );

      // Compute similarity from the already-detected landmarks — avoids a
      // second full detection pass that verifyPhoto() would require.
      double? similarity;
      final kyc = _kycEmbedding;
      if (kyc != null && kyc.length == FaceVerificationService.kEmbeddingLength) {
        final embedding = _embeddingFromFace(face);
        if (embedding != null) {
          similarity = FaceVerificationService.cosineSimilarity(embedding, kyc)
              .clamp(0.0, 1.0);
        }
      }

      if (mounted) {
        setState(() {
          _faceRect = normRect;
          _similarity = similarity;
        });
      }
    } catch (_) {
      // Best-effort — silently ignore detection errors.
    } finally {
      _isProcessing = false;
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  /// Builds the same 20-float landmark embedding as [FaceVerificationService]
  /// directly from an already-detected [Face], skipping a second ML Kit pass.
  List<double>? _embeddingFromFace(Face face) {
    final leftEyeLm = face.landmarks[FaceLandmarkType.leftEye];
    final rightEyeLm = face.landmarks[FaceLandmarkType.rightEye];
    if (leftEyeLm == null || rightEyeLm == null) return null;

    final cx = (leftEyeLm.position.x + rightEyeLm.position.x) / 2.0;
    final cy = (leftEyeLm.position.y + rightEyeLm.position.y) / 2.0;
    final iod = math.sqrt(
      math.pow(rightEyeLm.position.x - leftEyeLm.position.x, 2) +
          math.pow(rightEyeLm.position.y - leftEyeLm.position.y, 2),
    );
    if (iod < 1e-6) return null;

    const order = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
    ];

    final embedding = <double>[];
    for (final type in order) {
      final lm = face.landmarks[type];
      if (lm != null) {
        embedding.add((lm.position.x - cx) / iod);
        embedding.add((lm.position.y - cy) / iod);
      } else {
        embedding
          ..add(0.0)
          ..add(0.0);
      }
    }
    return embedding;
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      // Stop image stream before capture — some camera HALs don't allow both
      // simultaneously. Clear the face overlay while the crop editor is open.
      if (_isFrontPhoto && controller.value.isStreamingImages) {
        await controller.stopImageStream();
        if (mounted) setState(() { _faceRect = null; _similarity = null; });
      }

      final xFile = await controller.takePicture();

      if (!mounted) return;

      // Open the crop normalization editor on the root Navigator so it doesn't
      // sit inside GoRouter's Navigator. This prevents GoRouter from
      // reconciling its page list while the editor's Navigator.pop() is in
      // progress, which would trigger the !_debugLocked assertion.
      final result = await Navigator.of(context, rootNavigator: true).push<CropResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CropNormalizationEditor(
            imageFile: xFile,
            photoType: widget.photoType,
          ),
        ),
      );

      if (!mounted) return;

      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        // User cancelled crop editor — resume stream and return to camera.
        if (_isFrontPhoto) {
          _frameCount = 0;
          try {
            await controller.startImageStream(_onCameraFrame);
          } catch (_) {}
        }
        setState(() => _isCapturing = false);
      }
    } catch (_) {
      if (mounted) {
        // Try to resume stream on error.
        if (_isFrontPhoto) {
          _frameCount = 0;
          try {
            await _controller?.startImageStream(_onCameraFrame);
          } catch (_) {}
        }
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture photo. Try again.')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cameraReady =
        !_isInitializing && _error == null && _controller != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview (+ face overlay for FRONT) ───────────────
          if (_isInitializing)
            const Center(
                child: CircularProgressIndicator(color: Colors.white))
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.cameraOff,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (_controller != null)
            _buildPreview(_controller!),

          // ── Framing guide overlay ───────────────────────────────────
          if (cameraReady && _showGuides)
            Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: IgnorePointer(
                  child: CameraGuideOverlay(photoType: widget.photoType),
                ),
              ),
            ),

          // ── Close button ────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Guide toggle ────────────────────────────────────────────
          if (cameraReady)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: _CircleIconButton(
                icon: _showGuides ? Icons.grid_3x3 : Icons.grid_off,
                onTap: () => setState(() => _showGuides = !_showGuides),
              ),
            ),

          // ── Pose label ──────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_labelFor(widget.photoType)} Pose',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Distance instruction ────────────────────────────────────
          if (cameraReady)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Stand ~2m away  •  Phone at chest height',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // ── Shutter button ──────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: (_isCapturing || _controller == null) ? null : _capture,
                child: _ShutterButton(isCapturing: _isCapturing),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fixed 3:4 aspect ratio preview with an optional face detection overlay
  /// rendered as a [CustomPaint] sibling of the FittedBox camera feed.
  Widget _buildPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    final faceRect = _faceRect;

    return Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera feed
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize!.height,
                  height: controller.value.previewSize!.width,
                  child: CameraPreview(controller),
                ),
              ),

              // Face detection overlay (FRONT only, when a face is detected)
              if (faceRect != null && previewSize != null)
                IgnorePointer(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final sensorOrientation =
                          controller.description.sensorOrientation;
                      final displaySize =
                          (sensorOrientation == 90 || sensorOrientation == 270)
                              ? Size(previewSize.height, previewSize.width)
                              : Size(previewSize.width, previewSize.height);
                      return CustomPaint(
                        painter: _FaceOverlayPainter(
                          normalizedFaceRect: faceRect,
                          imageDisplaySize: displaySize,
                          containerSize: constraints.biggest,
                          similarity: _similarity,
                          displayName: _displayName,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _labelFor(String photoType) {
  switch (photoType.toUpperCase()) {
    case 'FRONT':
      return 'Front';
    case 'BACK':
      return 'Back';
    case 'SIDE':
      return 'Side';
    default:
      return photoType;
  }
}

// ── Shutter button ─────────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  final bool isCapturing;

  const _ShutterButton({required this.isCapturing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCapturing ? Colors.white60 : Colors.white,
        ),
        child: isCapturing
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : null,
      ),
    );
  }
}

// ── Circle icon button ─────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.45),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Face detection overlay painter ────────────────────────────────────────────

/// Draws a bounding box around the detected face in the live camera preview.
///
/// The face rect is normalised [0,1] in the "display-image" coordinate space
/// (i.e. after EXIF/sensor rotation). The painter receives both the image
/// display size and the container size so it can replicate the
/// [FittedBox.cover] transform and place the box accurately on screen.
///
/// Box colour:
/// - Blue   — no KYC embedding (cannot compare)
/// - Green  — similarity ≥ [FaceVerificationService.kMinConfidence]
/// - Amber  — similarity < threshold (different person / bad angle)
class _FaceOverlayPainter extends CustomPainter {
  final Rect normalizedFaceRect;
  final Size imageDisplaySize;
  final Size containerSize;
  final double? similarity;
  final String? displayName;

  const _FaceOverlayPainter({
    required this.normalizedFaceRect,
    required this.imageDisplaySize,
    required this.containerSize,
    this.similarity,
    this.displayName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Replicate FittedBox.cover: scale image to fill container, centred.
    final scale = math.max(
      containerSize.width / imageDisplaySize.width,
      containerSize.height / imageDisplaySize.height,
    );
    final offsetX = (containerSize.width - imageDisplaySize.width * scale) / 2;
    final offsetY =
        (containerSize.height - imageDisplaySize.height * scale) / 2;

    // Map normalised face rect → container (screen) coordinates.
    final screenRect = Rect.fromLTWH(
      normalizedFaceRect.left * imageDisplaySize.width * scale + offsetX,
      normalizedFaceRect.top * imageDisplaySize.height * scale + offsetY,
      normalizedFaceRect.width * imageDisplaySize.width * scale,
      normalizedFaceRect.height * imageDisplaySize.height * scale,
    );

    final hasSimilarity = similarity != null;
    final isMatch = hasSimilarity &&
        similarity! >= FaceVerificationService.kMinConfidence;

    final Color boxColor;
    if (!hasSimilarity) {
      boxColor = Colors.blue;
    } else if (isMatch) {
      boxColor = const Color(0xFF22C55E); // green
    } else {
      boxColor = const Color(0xFFF59E0B); // amber
    }

    // Bounding box.
    final boxPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(screenRect, boxPaint);

    // Corner accent lines (thicker than the box).
    final cornerPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    final cornerLen = math.min(screenRect.width, screenRect.height) * 0.14;
    _drawCornerAccents(canvas, screenRect, cornerPaint, cornerLen);

    // Label pill: "Alex   94%"
    final parts = <String>[];
    if (displayName != null && displayName!.isNotEmpty) parts.add(displayName!);
    if (hasSimilarity) parts.add('${(similarity! * 100).round()}%');
    final label = parts.join('   ');

    if (label.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final pillRect = Rect.fromLTWH(
        screenRect.left,
        screenRect.bottom + 6,
        tp.width + 12,
        tp.height + 8,
      );

      // Pill background.
      canvas.drawRRect(
        RRect.fromRectAndRadius(pillRect, const Radius.circular(5)),
        Paint()..color = boxColor.withOpacity(0.85),
      );

      tp.paint(canvas, Offset(pillRect.left + 6, pillRect.top + 4));
    }
  }

  void _drawCornerAccents(
      Canvas canvas, Rect rect, Paint paint, double len) {
    // top-left
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, len), paint);
    // top-right
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, len), paint);
    // bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(len, 0), paint);
    canvas.drawLine(
        rect.bottomLeft, rect.bottomLeft + Offset(0, -len), paint);
    // bottom-right
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + Offset(-len, 0), paint);
    canvas.drawLine(
        rect.bottomRight, rect.bottomRight + Offset(0, -len), paint);
  }

  @override
  bool shouldRepaint(_FaceOverlayPainter old) =>
      old.normalizedFaceRect != normalizedFaceRect ||
      old.similarity != similarity ||
      old.displayName != displayName;
}
