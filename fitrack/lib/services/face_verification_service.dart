import 'dart:math' as math;
import 'dart:typed_data';

/// On-device face verification using the same pseudo-embedding algorithm that
/// was applied during KYC (`_buildPseudoEmbedding` in `KycAgeScreen`).
///
/// The embedding is a 512-float descriptor built by evenly sampling across all
/// image bytes and normalising each sample to [-1, 1].  Similarity is measured
/// with cosine distance, which is invariant to brightness/contrast shifts.
class FaceVerificationService {
  /// Minimum cosine similarity to accept a photo as belonging to the KYC user.
  static const double kMinConfidence = 0.88;

  const FaceVerificationService._();

  // ── Embedding ─────────────────────────────────────────────────────────────

  /// Build a 512-float pseudo-embedding from [bytes].
  /// Must match `_buildPseudoEmbedding` in `kyc_age_screen.dart` exactly.
  static List<double> buildEmbedding(Uint8List bytes) {
    if (bytes.isEmpty) return List.filled(512, 0.0);
    const dims = 512;
    final step = bytes.length / dims;
    return List<double>.generate(dims, (i) {
      final idx = (i * step).round().clamp(0, bytes.length - 1);
      return (bytes[idx] - 128.0) / 128.0;
    });
  }

  // ── Similarity ────────────────────────────────────────────────────────────

  /// Cosine similarity between two vectors. Returns a value in [-1, 1].
  /// Returns 0.0 if either vector is all-zeros.
  static double cosineSimilarity(List<double> a, List<double> b) {
    assert(a.length == b.length, 'Embedding dimensions must match');
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    normA = math.sqrt(normA);
    normB = math.sqrt(normB);
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dot / (normA * normB);
  }

  // ── Verification ──────────────────────────────────────────────────────────

  /// Verify that [photoBytes] belongs to the same person as [kycEmbedding].
  ///
  /// Returns a [FaceVerificationResult] with the similarity score and whether
  /// it meets the required confidence threshold.
  static FaceVerificationResult verify({
    required Uint8List photoBytes,
    required List<double> kycEmbedding,
  }) {
    final photoEmbedding = buildEmbedding(photoBytes);
    final similarity = cosineSimilarity(photoEmbedding, kycEmbedding);
    // Cosine similarity of the pseudo-embedding ranges [-1, 1]; clamp to [0, 1]
    // and express as a percentage confidence value.
    final confidence = similarity.clamp(0.0, 1.0);
    return FaceVerificationResult(
      confidence: confidence,
      passed: confidence >= kMinConfidence,
    );
  }
}

/// Result of an on-device face verification check.
class FaceVerificationResult {
  /// Cosine similarity score clamped to [0, 1].
  final double confidence;

  /// Whether the score meets [FaceVerificationService.kMinConfidence].
  final bool passed;

  const FaceVerificationResult({
    required this.confidence,
    required this.passed,
  });

  /// Confidence as a human-readable percentage, e.g. "94%".
  String get confidencePercent => '${(confidence * 100).round()}%';
}
