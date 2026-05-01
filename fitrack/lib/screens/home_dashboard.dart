import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../screens/weight_history_screen.dart';
import '../widgets/daily_weight_card.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
import '../models/weight.dart';
import '../widgets/skeleton.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';
  return 'Good night';
}

String _greetingEmoji() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return '☀️';
  if (hour >= 12 && hour < 17) return '👋';
  if (hour >= 17 && hour < 21) return '🌆';
  return '🌙';
}

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      final now = DateTime.now();
      final utcDateTime = DateTime.utc(
        now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      final localDateTime = utcDateTime.toLocal();
      return DateFormat('h:mm a').format(localDateTime);
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: const FitrackAppBar(isHome: true),
      body: dashboardAsync.when(
        data: (data) {
          final todayStr = DateFormat('MMM d, yyyy').format(DateTime.now());
          
          return RefreshIndicator(
            color: const Color(0xFF22C55E),
            onRefresh: () async {
              return ref.refresh(dashboardProvider.future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey there, ',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_greeting()}! ${_greetingEmoji()}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    todayStr,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Today's Weight Cards
                  Row(
                    children: [
                      Expanded(
                        child: _WeightCard(
                          title: 'Morning Weight',
                          weight: data.latestMorningWeight,
                          time: _formatTime(data.latestMorningTime),
                          icon: LucideIcons.sun,
                          iconColor: const Color(0xFF22C55E),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _WeightCard(
                          title: 'Evening Weight',
                          weight: data.latestEveningWeight,
                          time: _formatTime(data.latestEveningTime),
                          icon: LucideIcons.moon,
                          iconColor: const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Overview Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progress Overview',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'This Week',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              final allWeights = data.weeklyGraph
                                  .map((g) => [g.morningWeight, g.eveningWeight])
                                  .expand((e) => e)
                                  .whereType<double>()
                                  .toList();
                              final highest = allWeights.isNotEmpty ? allWeights.reduce((a, b) => a > b ? a : b) : null;
                              final lowest = allWeights.isNotEmpty ? allWeights.reduce((a, b) => a < b ? a : b) : null;

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Avg. Weight', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      Text(
                                        data.weeklyAvg != null ? '${data.weeklyAvg!.toStringAsFixed(1)} kg' : '-- kg',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Highest', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      Text(
                                        highest != null ? '${highest.toStringAsFixed(1)} kg' : '-- kg',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Lowest', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      Text(
                                        lowest != null ? '${lowest.toStringAsFixed(1)} kg' : '-- kg',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(height: 24),
                          // Weekly Graph Section
                          Builder(
                            builder: (context) {
                              final hasData = data.weeklyGraph.any((g) => g.morningWeight != null || g.eveningWeight != null);
                              
                              if (!hasData) {
                                return Container(
                                  height: 100,
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.lineChart, color: Color(0xFF1A1A1A), size: 32),
                                      SizedBox(height: 8),
                                      Text('No data for this week', style: TextStyle(color: Color(0xFF94A3B8))),
                                    ],
                                  ),
                                );
                              }

                              final morningSpots = <FlSpot>[];
                              final eveningSpots = <FlSpot>[];
                              double minY = 999;
                              double maxY = 0;

                              for (int i = 0; i < data.weeklyGraph.length; i++) {
                                final g = data.weeklyGraph[i];
                                if (g.morningWeight != null) {
                                  morningSpots.add(FlSpot(i.toDouble(), g.morningWeight!));
                                  if (g.morningWeight! < minY) minY = g.morningWeight!;
                                  if (g.morningWeight! > maxY) maxY = g.morningWeight!;
                                }
                                if (g.eveningWeight != null) {
                                  eveningSpots.add(FlSpot(i.toDouble(), g.eveningWeight!));
                                  if (g.eveningWeight! < minY) minY = g.eveningWeight!;
                                  if (g.eveningWeight! > maxY) maxY = g.eveningWeight!;
                                }
                              }

                              return SizedBox(
                                height: 120,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 40,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                              final int index = value.toInt();
                                              if (index >= 0 && index < data.weeklyGraph.length) {
                                                final g = data.weeklyGraph[index];
                                                final parts = g.date.split('-');
                                                if (parts.length == 3) {
                                                  final dayDateStr = '${g.day}\n${parts[2]}/${parts[1]}';
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 8.0),
                                                    child: Text(
                                                      dayDateStr,
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                                    ),
                                                  );
                                                }
                                              }
                                              return const SizedBox();
                                            },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return Text('${value.toInt()}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10));
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    minY: minY - 4,
                                    maxY: maxY + 4,
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      handleBuiltInTouches: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipBgColor: const Color(0xFF1A1A1A),
                                        tooltipRoundedRadius: 8,
                                        getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                                          return lineBarsSpot.map((lineBarSpot) {
                                            final isMorning = lineBarSpot.barIndex == 0;
                                            return LineTooltipItem(
                                              '${isMorning ? "Morning" : "Evening"}: ${lineBarSpot.y.toStringAsFixed(1)} kg',
                                              TextStyle(
                                                color: lineBarSpot.bar.color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                    lineBarsData: [
                                      if (morningSpots.isNotEmpty)
                                        LineChartBarData(
                                          spots: morningSpots,
                                          showingIndicators: morningSpots.map((s) => morningSpots.indexOf(s)).toList(),
                                          isCurved: true,
                                          color: const Color(0xFF22C55E),
                                          barWidth: 1.5,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: true),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                          ),
                                        ),
                                      if (eveningSpots.isNotEmpty)
                                        LineChartBarData(
                                          spots: eveningSpots,
                                          showingIndicators: eveningSpots.map((s) => eveningSpots.indexOf(s)).toList(),
                                          isCurved: true,
                                          color: const Color(0xFF3B82F6),
                                          barWidth: 1.5,
                                          isStrokeCapRound: true,
                                          dashArray: [5, 5],
                                          dotData: const FlDotData(show: true),
                                          belowBarData: BarAreaData(show: false),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      AppButton.ghost(
                        label: 'View All',
                        expand: false,
                        onPressed: () => context.push('/history'),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final recent = data.weeklyGraph.where((g) => g.morningWeight != null || g.eveningWeight != null).toList().reversed.take(3).toList();
                      
                      if (recent.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No recent entries', style: TextStyle(color: Color(0xFF94A3B8)))),
                        );
                      }
                      
                      return Column(
                        children: recent.map((entry) {
                          return DailyWeightCard(
                            date: entry.date,
                            morningWeight: entry.morningWeight,
                            morningWeightTime: entry.morningWeightTime,
                            eveningWeight: entry.eveningWeight,
                            eveningWeightTime: entry.eveningWeightTime,
                            onTap: () {
                              final weightEntry = WeightEntry(
                                id: 0,
                                date: entry.date,
                                morningWeight: entry.morningWeight,
                                morningWeightTime: entry.morningWeightTime,
                                eveningWeight: entry.eveningWeight,
                                eveningWeightTime: entry.eveningWeightTime,
                                notes: '',
                              );
                              context.push('/add-weight', extra: weightEntry).then((_) {
                                ref.invalidate(weightHistoryProvider);
                                ref.invalidate(dashboardProvider);
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const _DashboardSkeleton(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Retry',
                onPressed: () => ref.refresh(dashboardProvider.future),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final String title;
  final double? weight;
  final String time;
  final IconData icon;
  final Color iconColor;

  const _WeightCard({
    required this.title,
    this.weight,
    required this.time,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  weight?.toStringAsFixed(1) ?? '--',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('kg', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard skeleton ────────────────────────────────────────────────────────
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            const SkeletonBox(width: 90, height: 14),
            const SizedBox(height: 8),
            const SkeletonBox(width: 200, height: 24),
            const SizedBox(height: 8),
            const SkeletonBox(width: 100, height: 13),
            const SizedBox(height: 24),

            // Weight cards row
            Row(
              children: const [
                Expanded(child: SkeletonBox(height: 110, radius: 14)),
                SizedBox(width: 16),
                Expanded(child: SkeletonBox(height: 110, radius: 14)),
              ],
            ),
            const SizedBox(height: 16),

            // Progress overview card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 130, height: 16),
                      SkeletonBox(width: 70, height: 26, radius: 8),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 70, height: 32),
                      SkeletonBox(width: 70, height: 32),
                      SkeletonBox(width: 70, height: 32),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Chart area
                  const SkeletonBox(height: 140, radius: 8),
                  const SizedBox(height: 12),
                  // X-axis labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 36, height: 10),
                      SkeletonBox(width: 36, height: 10),
                      SkeletonBox(width: 36, height: 10),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent History heading
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 120, height: 18),
                SkeletonBox(width: 56, height: 14),
              ],
            ),
            const SizedBox(height: 16),

            // History rows
            ...List.generate(3, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SkeletonBox(width: 40, height: 40, radius: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 15),
                        SizedBox(height: 6),
                        SkeletonBox(width: 120, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SkeletonBox(width: 20, height: 20, radius: 10),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}
