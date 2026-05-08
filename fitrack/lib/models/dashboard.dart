class DashboardData {
  final double? latestMorningWeight;
  final String? latestMorningTime;
  final double? latestEveningWeight;
  final String? latestEveningTime;
  final double? weeklyAvg;
  final double? monthlyAvg;
  final int streak;
  final List<DailyWeight> weeklyGraph;
  final PhotoSession? latestPhotos;
  final String? goalType; // 'LOSE', 'GAIN', or null

  DashboardData({
    this.latestMorningWeight,
    this.latestMorningTime,
    this.latestEveningWeight,
    this.latestEveningTime,
    this.weeklyAvg,
    this.monthlyAvg,
    required this.streak,
    this.weeklyGraph = const [],
    this.latestPhotos,
    this.goalType,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      latestMorningWeight: _parseDouble(json['latest_morning_weight']),
      latestMorningTime: json['latest_morning_time'],
      latestEveningWeight: _parseDouble(json['latest_evening_weight']),
      latestEveningTime: json['latest_evening_time'],
      weeklyAvg: _parseDouble(json['weekly_avg']),
      monthlyAvg: _parseDouble(json['monthly_avg']),
      streak: json['streak'] ?? 0,
      weeklyGraph: (json['weekly_graph'] as List?)
          ?.map((e) => DailyWeight.fromJson(e))
          .toList() ?? [],
      latestPhotos: json['latest_photos'] != null 
          ? PhotoSession.fromJson(json['latest_photos']) 
          : null,
      goalType: json['goal_type'] as String?,
    );
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is int) return val.toDouble();
    if (val is double) return val;
    if (val is String) return double.tryParse(val);
    return null;
  }
}

class PhotoSession {
  final int id;
  final String date;
  final String notes;
  final List<ProgressPhoto> photos;

  PhotoSession({
    required this.id,
    required this.date,
    required this.notes,
    required this.photos,
  });

  factory PhotoSession.fromJson(Map<String, dynamic> json) {
    return PhotoSession(
      id: json['id'],
      date: json['date'],
      notes: json['notes'] ?? '',
      photos: (json['photos'] as List?)
          ?.map((e) => ProgressPhoto.fromJson(e))
          .toList() ?? [],
    );
  }
}

class ProgressPhoto {
  final int id;
  final String photoType;
  final String? imageUrl;
  final String? normalizedImageUrl;
  final double? cropScale;
  final double? cropOffsetX;
  final double? cropOffsetY;
  final double? cropAspectRatio;
  final String uploadedAt;

  /// Use the normalized image when available for display, falling back to original.
  String? get displayUrl => normalizedImageUrl ?? imageUrl;

  ProgressPhoto({
    required this.id,
    required this.photoType,
    this.imageUrl,
    this.normalizedImageUrl,
    this.cropScale,
    this.cropOffsetX,
    this.cropOffsetY,
    this.cropAspectRatio,
    required this.uploadedAt,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: json['id'],
      photoType: json['photo_type'],
      imageUrl: json['image_url'],
      normalizedImageUrl: json['normalized_image_url'],
      cropScale: (json['crop_scale'] as num?)?.toDouble(),
      cropOffsetX: (json['crop_offset_x'] as num?)?.toDouble(),
      cropOffsetY: (json['crop_offset_y'] as num?)?.toDouble(),
      cropAspectRatio: (json['crop_aspect_ratio'] as num?)?.toDouble(),
      uploadedAt: json['uploaded_at'],
    );
  }
}

class DailyWeight {
  final String date;
  final String day;
  final double? morningWeight;
  final String? morningWeightTime;
  final double? eveningWeight;
  final String? eveningWeightTime;

  DailyWeight({
    required this.date,
    required this.day,
    this.morningWeight,
    this.morningWeightTime,
    this.eveningWeight,
    this.eveningWeightTime,
  });

  factory DailyWeight.fromJson(Map<String, dynamic> json) {
    return DailyWeight(
      date: json['date'],
      day: json['day'],
      morningWeight: DashboardData._parseDouble(json['morning_weight']),
      morningWeightTime: json['morning_weight_time'],
      eveningWeight: DashboardData._parseDouble(json['evening_weight']),
      eveningWeightTime: json['evening_weight_time'],
    );
  }
}
