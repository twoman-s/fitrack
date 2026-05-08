/// Data class representing crop transform coordinates.
///
/// Persisted server-side per photo and cached locally so the next capture
/// can re-use the same framing.
class CropTransform {
  final double scale;
  final double offsetX;
  final double offsetY;
  final double aspectRatio;

  const CropTransform({
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.aspectRatio = 0.75, // 3:4 portrait
  });

  CropTransform copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
    double? aspectRatio,
  }) {
    return CropTransform(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'scale': scale,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'aspectRatio': aspectRatio,
      };

  factory CropTransform.fromJson(Map<String, dynamic> json) {
    return CropTransform(
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 0.75,
    );
  }

  @override
  String toString() =>
      'CropTransform(scale: $scale, offsetX: $offsetX, offsetY: $offsetY, ar: $aspectRatio)';
}
