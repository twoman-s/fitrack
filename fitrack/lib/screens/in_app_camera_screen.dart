import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../repositories/tracker_repository.dart';

/// Full-screen in-app camera.
/// Shows the last uploaded photo of the same [photoType] at 20% opacity as a
/// positioning guide. If no prior photo exists, no overlay is shown.
///
/// Pops with the captured [XFile], or `null` if the user cancels.
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

  /// URL of the last photo for this type — null means no prior photo.
  String? _ghostImageUrl;
  bool _ghostLoaded = false;
  double _ghostOpacity = 0.20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadGhost();
  }

  Future<void> _loadGhost() async {
    final repo = ref.read(trackerRepositoryProvider);
    final url = await repo.getLatestPhoto(photoType: widget.photoType);
    if (mounted) {
      setState(() {
        _ghostImageUrl = url;
        _ghostLoaded = true;
      });
    }
  }

  Future<void> _initCamera() async {
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
      if (mounted) setState(() => _controller = null);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);
    try {
      final xFile = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(xFile);
    } catch (_) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture photo. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraReady = !_isInitializing && _error == null && _controller != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          if (_isInitializing)
            const Center(child: CircularProgressIndicator(color: Colors.white))
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

          // ── Ghost overlay: last photo at variable opacity ─────────────
          if (cameraReady && _ghostLoaded && _ghostImageUrl != null)
            IgnorePointer(
              child: Opacity(
                opacity: _ghostOpacity,
                child: CachedNetworkImage(
                  imageUrl: _ghostImageUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          // ── Close button ────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _CircleIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ── Pose label ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_labelFor(widget.photoType)} Pose',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ── Shutter button ──────────────────────────────────────────────
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

          // ── Ghost opacity slider ────────────────────────────────────────
          if (cameraReady && _ghostLoaded && _ghostImageUrl != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 110,
              left: 24,
              right: 24,
              child: Row(
                children: [
                  const Icon(Icons.layers, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: _ghostOpacity,
                        min: 0.0,
                        max: 0.6,
                        onChanged: (v) =>
                            setState(() => _ghostOpacity = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    final size = MediaQuery.of(context).size;
    final scale = 1 / (controller.value.aspectRatio * size.aspectRatio);
    return Transform.scale(
      scale: scale < 1 ? 1 : scale,
      child: Center(child: CameraPreview(controller)),
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
          color: Colors.black.withValues(alpha: 0.45),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
