class WeightEntry {
  final int id;
  final String date;
  final double? morningWeight;
  final String? morningWeightTime;
  final double? eveningWeight;
  final String? eveningWeightTime;
  final String notes;

  WeightEntry({
    required this.id,
    required this.date,
    this.morningWeight,
    this.morningWeightTime,
    this.eveningWeight,
    this.eveningWeightTime,
    required this.notes,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'],
      date: json['date'],
      morningWeight: _parseDouble(json['morning_weight']),
      morningWeightTime: json['morning_weight_time'],
      eveningWeight: _parseDouble(json['evening_weight']),
      eveningWeightTime: json['evening_weight_time'],
      notes: json['notes'] ?? '',
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

class PaginatedWeightResponse {
  final int count;
  final String? next;
  final String? previous;
  final List<WeightEntry> results;

  PaginatedWeightResponse({
    required this.count,
    this.next,
    this.previous,
    required this.results,
  });

  factory PaginatedWeightResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedWeightResponse(
      count: json['count'] ?? 0,
      next: json['next'],
      previous: json['previous'],
      results: (json['results'] as List?)
          ?.map((e) => WeightEntry.fromJson(e))
          .toList() ?? [],
    );
  }
}

class WeightAggregate {
  final String period;
  final double? avgMorningWeight;
  final double? avgEveningWeight;

  WeightAggregate({
    required this.period,
    this.avgMorningWeight,
    this.avgEveningWeight,
  });

  factory WeightAggregate.fromJson(Map<String, dynamic> json) {
    return WeightAggregate(
      period: json['period'],
      avgMorningWeight: WeightEntry._parseDouble(json['avg_morning_weight']),
      avgEveningWeight: WeightEntry._parseDouble(json['avg_evening_weight']),
    );
  }
}

class HeatmapEntry {
  final String date;
  final int count;

  HeatmapEntry({
    required this.date,
    required this.count,
  });

  factory HeatmapEntry.fromJson(Map<String, dynamic> json) {
    return HeatmapEntry(
      date: json['date'],
      count: json['count'] ?? 0,
    );
  }
}
