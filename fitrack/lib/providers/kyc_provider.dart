import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/kyc.dart';
import '../repositories/tracker_repository.dart';

/// Fetches KYC status from the backend.
/// autoDispose (no keepAlive) so the cached value is dropped when not watched,
/// meaning the next visit to the photos screen always triggers a fresh API call.
final kycStatusProvider = FutureProvider.autoDispose<KycStatus>((ref) {
  final repo = ref.watch(trackerRepositoryProvider);
  return repo.getKycStatus();
});
