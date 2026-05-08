import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme.dart';
import '../models/crop_transform.dart';
import '../services/crop_transform_service.dart';
import '../repositories/tracker_repository.dart';

/// Result returned by [CropNormalizationEditor] when the user confirms.
class CropResult {
  final Uint8List originalBytes;
  final Uint8List normalizedBytes;
  final CropTransform cropTransform;

  const CropResult({
    required this.originalBytes,
    required this.normalizedBytes,
    required this.cropTransform,
  });
}

/// Post-capture crop editor.
///
/// Shows the captured image inside a fixed 3:4 frame. The user can
/// pinch-to-zoom and drag to align. A ghost overlay of the previous
/// normalised image is shown at ~20 % opacity to help the user match
/// framing across sessions.
class CropNormalizationEditor extends ConsumerStatefulWidget {
  final XFile? imageFile;
  final Uint8List? imageBytes;
  final String photoType;
  final String? excludeDate;

  const CropNormalizationEditor({
    super.key,
    this.imageFile,
    this.imageBytes,
    required this.photoType,
    this.excludeDate,
  }) : assert(imageFile != null || imageBytes != null);

  @override
  ConsumerState<CropNormalizationEditor> createState() =>
      _CropNormalizationEditorState();
}

class _CropNormalizationEditorState
    extends ConsumerState<CropNormalizationEditor> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _isSaving = false;

  // Transform state
  double _scale = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  // Previous image ghost
  String? _ghostUrl;
  bool _showGhost = true;
  double _splitPosition = 0.5; // For sliding comparison

  // Frame size for normalization
  double _frameW = 0.0;
  double _frameH = 0.0;

  // Track if we need to apply the initial transform
  CropTransform? _pendingTransform;

  // Interactive viewer tracking
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load captured image bytes
    final bytes = widget.imageBytes ?? await widget.imageFile!.readAsBytes();
    if (!mounted) return;

    // Load previous crop transform + ghost image
    final service = ref.read(cropTransformServiceProvider);
    final prevTransform = await service.getLastTransform(widget.photoType);

    // Load ghost URL
    final repo = ref.read(trackerRepositoryProvider);
    final latestData = await repo.getLatestPhotoWithCrop(
      photoType: widget.photoType,
      excludeDate: widget.excludeDate,
    );
    final ghostUrl = latestData?['normalized_image_url'] as String? ??
        latestData?['image_url'] as String?;

    if (!mounted) return;

    setState(() {
      _imageBytes = bytes;
      _isLoading = false;
      if (ghostUrl != null) {
        _ghostUrl = '$ghostUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Store transform to apply once frame size is known
      if (prevTransform != null) {
        _pendingTransform = prevTransform;
      }
    });
  }

  void _applyTransformToController() {
    final matrix = Matrix4.identity()
      ..translate(_offsetX, _offsetY)
      ..scale(_scale);
    _transformController.value = matrix;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    // Extract current transform from the controller
    final matrix = _transformController.value;
    _scale = matrix.getMaxScaleOnAxis();
    _offsetX = matrix.getTranslation().x;
    _offsetY = matrix.getTranslation().y;
  }

  Future<void> _save() async {
    if (_imageBytes == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {

      // Normalize offset to 1080x1440 space
      final normOffsetX = _frameW > 0 ? _offsetX * (kNormalizedWidth / _frameW) : 0.0;
      final normOffsetY = _frameH > 0 ? _offsetY * (kNormalizedHeight / _frameH) : 0.0;

      final transform = CropTransform(
        scale: _scale,
        offsetX: normOffsetX,
        offsetY: normOffsetY,
      );

      // Apply the crop transform to produce normalised image
      final service = ref.read(cropTransformServiceProvider);
      final normalizedBytes =
          await service.applyTransform(_imageBytes!, transform);

      // Cache the transform locally
      await service.saveTransform(widget.photoType, transform);

      if (!mounted) return;

      Navigator.of(context).pop(CropResult(
        originalBytes: _imageBytes!,
        normalizedBytes: normalizedBytes,
        cropTransform: transform,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildEditor()),
                  _buildBottomBar(),
                ],
              ),
            ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.x, color: Colors.white, size: 18),
            ),
          ),
          const Expanded(
            child: Text(
              'Align Your Photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Ghost toggle
          if (_ghostUrl != null)
            GestureDetector(
              onTap: () => setState(() => _showGhost = !_showGhost),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _showGhost
                      ? AppTheme.primary.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.layers,
                  color: _showGhost ? AppTheme.primary : Colors.white54,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ── Crop editor area ─────────────────────────────────────────────────────

  Widget _buildEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the 3:4 frame size that fits the available space
        final maxW = constraints.maxWidth - 32; // 16px padding each side
        final maxH = constraints.maxHeight - 32;
        final frameW = min(maxW, maxH * 0.75); // 3:4 ratio
        final frameH = frameW / 0.75;

        final actualW = frameW > maxW ? maxW : frameW;
        final actualH = actualW / 0.75 > maxH ? maxH : actualW / 0.75;
        final finalW = actualH * 0.75 > maxW ? maxW : actualH * 0.75;
        final finalH = finalW / 0.75;

        // Schedule saving of frame size for _save()
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          bool sizeChanged = false;
          if (_frameW != finalW || _frameH != finalH) {
            _frameW = finalW;
            _frameH = finalH;
            sizeChanged = true;
          }

          if (sizeChanged && _pendingTransform != null && _frameW > 0 && _frameH > 0) {
            // Un-normalize offset from 1080x1440 space to screen space
            _scale = _pendingTransform!.scale;
            _offsetX = _pendingTransform!.offsetX * (_frameW / kNormalizedWidth);
            _offsetY = _pendingTransform!.offsetY * (_frameH / kNormalizedHeight);
            _applyTransformToController();
            _pendingTransform = null; // Only apply once
            setState(() {});
          }
        });

        return Center(
          child: SizedBox(
            width: finalW,
            height: finalH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background
                  Container(color: const Color(0xFF0A0A0A)),

                  // Interactive current image
                  InteractiveViewer(
                    transformationController: _transformController,
                    onInteractionUpdate: _onInteractionUpdate,
                    minScale: 0.5,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(200),
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                  // Ghost overlay (previous normalized image sliding comparison)
                  if (_showGhost && _ghostUrl != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRect(
                          clipper: _SplitClipper(_splitPosition),
                          child: Image.network(
                            _ghostUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),

                  // Divider line for sliding comparison
                  if (_showGhost && _ghostUrl != null)
                    Positioned(
                      left: finalW * _splitPosition - 20, // 40px hit area
                      top: 0,
                      bottom: 0,
                      width: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            _splitPosition += details.delta.dx / finalW;
                            _splitPosition = _splitPosition.clamp(0.0, 1.0);
                          });
                        },
                        child: Center(
                          child: Container(
                            width: 2,
                            color: AppTheme.primary,
                            child: Center(
                              child: Container(
                                width: 2,
                                height: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Frame border
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Corner markers
                  ..._buildCornerMarkers(finalW, finalH),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildCornerMarkers(double w, double h) {
    const markerLen = 20.0;
    const markerThickness = 2.5;
    final color = AppTheme.primary.withOpacity(0.6);

    Widget corner(Alignment alignment) {
      final isTop = alignment.y < 0;
      final isLeft = alignment.x < 0;

      return Positioned(
        top: isTop ? 0 : null,
        bottom: isTop ? null : 0,
        left: isLeft ? 0 : null,
        right: isLeft ? null : 0,
        child: IgnorePointer(
          child: SizedBox(
            width: markerLen,
            height: markerLen,
            child: CustomPaint(
              painter: _CornerPainter(
                color: color,
                thickness: markerThickness,
                isTop: isTop,
                isLeft: isLeft,
              ),
            ),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ghost sliding comparison slider
          if (_showGhost && _ghostUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.arrowLeftRight, color: Colors.white38, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6),
                        overlayShape: SliderComponentShape.noOverlay,
                        activeTrackColor: AppTheme.primary.withOpacity(0.6),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: AppTheme.primary,
                      ),
                      child: Slider(
                        value: _splitPosition,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (v) =>
                            setState(() => _splitPosition = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Split',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

          // Instruction text
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Pinch to zoom  •  Drag to align with previous photo',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Reset + Save buttons
          Row(
            children: [
              // Reset button
              GestureDetector(
                onTap: () {
                  _transformController.value = Matrix4.identity();
                  setState(() {
                    _scale = 1.0;
                    _offsetX = 0.0;
                    _offsetY = 0.0;
                  });
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.rotateCcw,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Save button
              Expanded(
                child: GestureDetector(
                  onTap: _isSaving ? null : _save,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _isSaving
                          ? AppTheme.primary.withOpacity(0.5)
                          : AppTheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.check,
                                    color: Colors.black, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Save & Continue',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Corner marker painter ──────────────────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop;
  final bool isLeft;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => false;
}

// ── Split clipper ─────────────────────────────────────────────────────────────

class _SplitClipper extends CustomClipper<Rect> {
  final double split;

  _SplitClipper(this.split);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * split, size.height);
  }

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) {
    return oldClipper.split != split;
  }
}
