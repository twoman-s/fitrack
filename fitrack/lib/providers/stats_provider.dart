import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stats.dart';
import '../repositories/tracker_repository.dart';

final statsProvider = FutureProvider.autoDispose<StatsData>((ref) {
  ref.keepAlive();
  return ref.watch(trackerRepositoryProvider).getStats();
});
