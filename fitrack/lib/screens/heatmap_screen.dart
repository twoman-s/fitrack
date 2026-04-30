import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../repositories/tracker_repository.dart';
import '../models/weight.dart';

final heatmapProvider = FutureProvider.family<List<HeatmapEntry>, DateTime>((ref, date) {
  final repo = ref.watch(trackerRepositoryProvider);
  final monthStr = DateFormat('yyyy-MM').format(date);
  return repo.getHeatmap(monthStr);
});

class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final heatmapAsync = ref.watch(heatmapProvider(_focusedDay));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Heatmap'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: heatmapAsync.when(
                  data: (data) {
                    final dataMap = {
                      for (var e in data) e.date: e.count
                    };

                    return TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.now(),
                      focusedDay: _focusedDay,
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final dateStr = DateFormat('yyyy-MM-dd').format(day);
                          final count = dataMap[dateStr] ?? 0;
                          return _buildHeatmapCell(day, count);
                        },
                        todayBuilder: (context, day, focusedDay) {
                          final dateStr = DateFormat('yyyy-MM-dd').format(day);
                          final count = dataMap[dateStr] ?? 0;
                          return _buildHeatmapCell(day, count, isToday: true);
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          return const SizedBox.shrink();
                        },
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF22C55E))),
                  ),
                  error: (err, stack) => SizedBox(
                    height: 300,
                    child: Center(child: Text('Error loading heatmap: $err')),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('No data', 0),
                const SizedBox(width: 16),
                _buildLegendItem('Weight only', 1),
                const SizedBox(width: 16),
                _buildLegendItem('Photo only', 2),
                const SizedBox(width: 16),
                _buildLegendItem('Both', 3),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCell(DateTime day, int count, {bool isToday = false}) {
    Color color;
    switch (count) {
      case 3:
        color = const Color(0xFF22C55E); // Bright green (both)
        break;
      case 2:
        color = const Color(0xFF22C55E).withOpacity(0.6); // Photo only
        break;
      case 1:
        color = const Color(0xFF22C55E).withOpacity(0.3); // Weight only
        break;
      default:
        color = const Color(0xFF1A1A1A); // Empty
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isToday ? Border.all(color: Colors.white, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: count > 1 ? Colors.black : Colors.white,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, int level) {
    Color color;
    switch (level) {
      case 3: color = const Color(0xFF22C55E); break;
      case 2: color = const Color(0xFF22C55E).withOpacity(0.6); break;
      case 1: color = const Color(0xFF22C55E).withOpacity(0.3); break;
      default: color = const Color(0xFF1A1A1A);
    }
    
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ],
    );
  }
}
