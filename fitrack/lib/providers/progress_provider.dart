import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress.dart';
import '../repositories/tracker_repository.dart';

/// The currently selected time period for the progress chart.
/// Values: '7d', '30d', '3m', '1y', 'all'
final selectedPeriodProvider = StateProvider<String>((ref) => '30d');

/// Fetches progress data for the selected period.
final progressDataProvider = FutureProvider.autoDispose<ProgressData>((ref) {
  ref.keepAlive();
  final period = ref.watch(selectedPeriodProvider);
  final repo = ref.watch(trackerRepositoryProvider);
  return repo.getProgress(period);
});
