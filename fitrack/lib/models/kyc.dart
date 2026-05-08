class KycStatus {
  final bool kycCompleted;
  final String kycStatus;
  final bool uploadEnabled;
  /// Face embedding vector returned by the backend after successful KYC.
  /// Null when KYC is not yet completed.
  final List<double>? faceEmbedding;

  const KycStatus({
    required this.kycCompleted,
    required this.kycStatus,
    required this.uploadEnabled,
    this.faceEmbedding,
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    List<double>? embedding;
    final raw = json['face_embedding'];
    if (raw is List) {
      embedding = raw.map((e) => (e as num).toDouble()).toList();
    }
    return KycStatus(
      kycCompleted: json['kyc_completed'] as bool? ?? false,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      uploadEnabled: json['upload_enabled'] as bool? ?? false,
      faceEmbedding: embedding,
    );
  }

  bool get isPending => kycStatus == 'pending';
  bool get isApproved => kycStatus == 'approved';
}
