import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/crop_transform.dart';
import '../repositories/tracker_repository.dart';

/// Fixed output dimensions for all normalized progress photos.
const int kNormalizedWidth = 1080;
const int kNormalizedHeight = 1440; // 3:4

final cropTransformServiceProvider = Provider((ref) {
  return CropTransformService(ref);
});

/// Service that loads, applies, and caches crop transforms per photo type.
class CropTransformService {
  final Ref _ref;

  CropTransformService(this._ref);

  // ── Local cache key ──────────────────────────────────────────────────────

  String _cacheKey(String photoType) => 'crop_transform_${photoType.toLowerCase()}';

  /// Get the last crop transform for [photoType].
  /// Tries API first, falls back to local cache.
  Future<CropTransform?> getLastTransform(String photoType) async {
    try {
      final repo = _ref.read(trackerRepositoryProvider);
      final data = await repo.getLatestPhotoWithCrop(photoType: photoType);
      if (data != null && data['crop_scale'] != null) {
        final transform = CropTransform(
          scale: (data['crop_scale'] as num).toDouble(),
          offsetX: (data['crop_offset_x'] as num?)?.toDouble() ?? 0.0,
          offsetY: (data['crop_offset_y'] as num?)?.toDouble() ?? 0.0,
          aspectRatio: (data['crop_aspect_ratio'] as num?)?.toDouble() ?? 0.75,
        );
        // Cache locally
        await _saveLocal(photoType, transform);
        return transform;
      }
    } catch (_) {
      // Fall through to local cache
    }

    return _loadLocal(photoType);
  }

  /// Save a transform to local cache.
  Future<void> _saveLocal(String photoType, CropTransform transform) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_cacheKey(photoType), jsonEncode(transform.toJson()));
  }

  /// Load a transform from local cache.
  Future<CropTransform?> _loadLocal(String photoType) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(photoType));
    if (raw == null) return null;
    try {
      return CropTransform.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Save transform locally (called after crop editor finishes).
  Future<void> saveTransform(String photoType, CropTransform transform) async {
    await _saveLocal(photoType, transform);
  }

  /// Apply a crop transform to raw image bytes and return the normalized image.
  ///
  /// The output is always [kNormalizedWidth] × [kNormalizedHeight] JPEG.
  Future<Uint8List> applyTransform(
    Uint8List imageBytes,
    CropTransform transform,
  ) async {
    // Decode the source image
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;

    final srcW = sourceImage.width.toDouble();
    final srcH = sourceImage.height.toDouble();

    // The crop viewport in normalised coordinates:
    // scale=1.0 means the image fills the 3:4 frame exactly (cover fit).
    // offsetX/offsetY are pixel offsets from center.
    final outW = kNormalizedWidth.toDouble();
    final outH = kNormalizedHeight.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outW, outH));

    // Calculate how the source fits into the output at scale=1 (cover)
    final coverScale = (outW / srcW).clamp(0.0, double.infinity);
    final coverScaleH = outH / srcH;
    final baseFit = coverScale > coverScaleH ? coverScale : coverScaleH;

    final effectiveScale = baseFit * transform.scale;

    final drawW = srcW * effectiveScale;
    final drawH = srcH * effectiveScale;

    // Center the image then apply offset
    final dx = (outW - drawW) / 2 + transform.offsetX;
    final dy = (outH - drawH) / 2 + transform.offsetY;

    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(0, 0, srcW, srcH),
      Rect.fromLTWH(dx, dy, drawW, drawH),
      Paint()..filterQuality = FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final outputImage = await picture.toImage(kNormalizedWidth, kNormalizedHeight);
    final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);

    sourceImage.dispose();
    outputImage.dispose();

    if (byteData == null) throw Exception('Failed to encode normalized image');
    return byteData.buffer.asUint8List();
  }
}
