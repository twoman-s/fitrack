import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Returns the overlay asset path for a given photo type.
String _overlayAsset(String photoType) {
  if (photoType.toUpperCase() == 'SIDE') {
    return 'assets/camera_overlay/side_overlay.png';
  }
  return 'assets/camera_overlay/front_back_overlay.png';
}

/// Full-screen in-app camera with a semi-transparent pose-guide overlay.
///
/// Pops with the captured [XFile], or `null` if the user cancels.
class InAppCameraScreen extends StatefulWidget {
  final String photoType;

  const InAppCameraScreen({super.key, required this.photoType});

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
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

          // ── Pose-guide overlay ──────────────────────────────────────────
          if (!_isInitializing && _error == null)
            IgnorePointer(
              child: Opacity(
                opacity: 0.45,
                child: Image.asset(
                  _overlayAsset(widget.photoType),
                  fit: BoxFit.contain,
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
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    final size = MediaQuery.of(context).size;
    final scale =
        1 / (controller.value.aspectRatio * size.aspectRatio);

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
