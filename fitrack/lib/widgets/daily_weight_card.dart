import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DailyWeightCard extends StatelessWidget {
  final String date;
  final double? morningWeight;
  final String? morningWeightTime;
  final double? eveningWeight;
  final String? eveningWeightTime;
  final VoidCallback onTap;

  const DailyWeightCard({
    super.key,
    required this.date,
    this.morningWeight,
    this.morningWeightTime,
    this.eveningWeight,
    this.eveningWeightTime,
    required this.onTap,
  });

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    try {
      final parts = timeStr.split(':');
      final entryDate = DateTime.parse(date);
      final utcDateTime = DateTime.utc(
        entryDate.year, entryDate.month, entryDate.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      final localDateTime = utcDateTime.toLocal();
      return DateFormat('h:mm a').format(localDateTime);
    } catch (e) {
      return timeStr;
    }
  }

  String _formatDate() {
    try {
      final d = DateTime.parse(date);
      return DateFormat('MMM dd, yyyy').format(d);
    } catch (e) {
      return date;
    }
  }

  String _getPrimaryWeight() {
    if (morningWeight != null && eveningWeight != null) {
      return '${morningWeight!.toStringAsFixed(1)} / ${eveningWeight!.toStringAsFixed(1)} kg';
    } else if (morningWeight != null) {
      return '${morningWeight!.toStringAsFixed(1)} kg';
    } else if (eveningWeight != null) {
      return '${eveningWeight!.toStringAsFixed(1)} kg';
    }
    return '-- kg';
  }

  String _getSubtitle() {
    final parts = <String>[];
    if (morningWeight != null) {
      final time = _formatTime(morningWeightTime);
      parts.add('Morning${time.isNotEmpty ? ' at $time' : ''}');
    }
    if (eveningWeight != null) {
      final time = _formatTime(eveningWeightTime);
      parts.add('Evening${time.isNotEmpty ? ' at $time' : ''}');
    }
    return parts.isEmpty ? 'No data recorded' : parts.join('  •  ');
  }

  IconData _getIcon() {
    if (morningWeight != null && eveningWeight != null) {
      return LucideIcons.activity;
    } else if (morningWeight != null) {
      return LucideIcons.sun;
    } else if (eveningWeight != null) {
      return LucideIcons.moon;
    }
    return LucideIcons.minus;
  }

  Color _getIconColor() {
    if (eveningWeight != null && morningWeight == null) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFF22C55E);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Left icon
            Icon(
              _getIcon(),
              color: _getIconColor(),
              size: 22,
            ),
            const SizedBox(width: 16),

            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPrimaryWeight(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getSubtitle(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right chevron
            Icon(
              LucideIcons.chevronRight,
              color: Colors.white.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
