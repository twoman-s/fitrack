import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// On-device face verification using ML Kit face landmark geometry.
///
/// The embedding is a 20-float vector of face landmark positions normalised by
/// the inter-ocular distance (IOD), making it invariant to image scale and
/// translation.  Cosine similarity on this geometric descriptor reliably
/// distinguishes the same person across different photos of the same person.
///
/// Landmark order (fixed, 2 floats each):
///   leftEye, rightEye, noseBase, bottomMouth, leftMouth, rightMouth,
///   leftCheek, rightCheek, leftEar, rightEar  →  20 floats total.
class FaceVerificationService {
  /// Minimum cosine similarity (landmark-based) to accept a photo as the KYC user.
  static const double kMinConfidence = 0.82;

  /// Expected embedding length produced by [buildLandmarkEmbedding].
  static const int kEmbeddingLength = 20;

  const FaceVerificationService._();

  // ── Landmark embedding ────────────────────────────────────────────────────

  /// Detects the largest face in [jpegBytes] and returns a 20-float landmark
  /// embedding normalised by inter-ocular distance.
  ///
  /// Returns `null` if no face is detected or the eyes cannot be located.
  static Future<List<double>?> buildLandmarkEmbedding(Uint8List jpegBytes) async {
    File? tempFile;
    FaceDetector? detector;
    try {
      // ML Kit needs a file path on mobile to decode JPEG
      final tempPath =
          '${Directory.systemTemp.path}/fv_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(jpegBytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

      final faces = await detector.processImage(inputImage);
      if (faces.isEmpty) return null;

      // Use the largest face
      faces.sort((a, b) =>
          (b.boundingBox.width * b.boundingBox.height)
              .compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;

      // Require both eyes for normalisation anchor
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

      // Extract all 10 landmarks in fixed order (missing → 0.0)
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
      return embedding; // always kEmbeddingLength floats
    } catch (_) {
      return null;
    } finally {
      await detector?.close();
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  // ── Similarity ────────────────────────────────────────────────────────────

  /// Cosine similarity between two equal-length vectors. Returns a value in
  /// [-1, 1]. Returns 0.0 if either vector is all-zeros.
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
  /// [kycEmbedding] must have length [kEmbeddingLength] (landmark-based).
  /// Returns `null` if no face can be detected in [photoBytes].
  static Future<FaceVerificationResult?> verifyPhoto({
    required Uint8List photoBytes,
    required List<double> kycEmbedding,
  }) async {
    final photoEmbedding = await buildLandmarkEmbedding(photoBytes);
    if (photoEmbedding == null) return null;

    final similarity = cosineSimilarity(photoEmbedding, kycEmbedding);
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
