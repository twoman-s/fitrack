import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    // If not set, fallback to localhost
    return dotenv.env['API_BASE_URL'] ?? 'https://fitrack.oopsops.in/api';
  }

  // Auth endpoints
  static const String login = '/auth/login/';
  static const String signup = '/auth/signup/';
  static const String refresh = '/auth/token/refresh/';
  static const String changePassword = '/auth/change-password/';
  static const String profile = '/auth/profile/';

  // Tracker endpoints
  static const String dashboard = '/dashboard/';
  static const String weights = '/weights/';
  static const String photos = '/photos/';
  static const String photosUpload = '/photos/upload/';
  static const String photosCompare = '/photos/compare/';
  static String photoDetail(int id) => '/photos/$id/';
  static const String heatmap = '/heatmap/';
  static const String goal = '/goal/';
  static const String goalHistory = '/goal/history/';
  static String goalDetail(int id) => '/goal/$id/';
  static const String progress = '/progress/';
  static const String stats = '/stats/';
}
