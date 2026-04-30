import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard.dart';
import '../repositories/tracker_repository.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final repository = ref.watch(trackerRepositoryProvider);
  return repository.getDashboard();
});
