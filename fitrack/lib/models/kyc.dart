class KycStatus {
  final bool kycCompleted;
  final String kycStatus;
  final bool uploadEnabled;

  const KycStatus({
    required this.kycCompleted,
    required this.kycStatus,
    required this.uploadEnabled,
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) => KycStatus(
        kycCompleted: json['kyc_completed'] as bool? ?? false,
        kycStatus: json['kyc_status'] as String? ?? 'pending',
        uploadEnabled: json['upload_enabled'] as bool? ?? false,
      );

  bool get isPending => kycStatus == 'pending';
  bool get isApproved => kycStatus == 'approved';
}
