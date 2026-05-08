import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../providers/progress_provider.dart';
import '../screens/weight_history_screen.dart';
import '../widgets/daily_weight_card.dart';
import '../widgets/app_bar.dart';
import '../widgets/app_button.dart';
import '../widgets/weight_chart.dart';
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

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> with RouteAware {

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    try {
      final parts = timeStr.split(':');
      final now = DateTime.now();
      final utcDateTime = DateTime.utc(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final localDateTime = utcDateTime.toLocal();
      return DateFormat('h:mm a').format(localDateTime);
    } catch (e) {
      return timeStr;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data whenever we return to this screen
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      // Small delay to ensure the UI is ready
      Future.microtask(() {
        if (mounted) {
          ref.invalidate(dashboardProvider);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  
                  // Today's Cards: Quote (left) + Weight (right)
                  IntrinsicHeight(
                   child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _QuoteCard(goalType: data.goalType),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _WeightCard(
                          morningWeight: data.latestMorningWeight,
                          morningTime: _formatTime(data.latestMorningTime),
                          eveningWeight: data.latestEveningWeight,
                          eveningTime: _formatTime(data.latestEveningTime),
                        ),
                      ),
                    ],                   ),                  ),
                  const SizedBox(height: 16),

                  // This Week Chart
                  ref.watch(dashboardChartProvider).when(
                    data: (chartData) => chartData.chart.isEmpty
                        ? const SizedBox.shrink()
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Text(
                                        'This Week',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 300,
                                    child: WeightChart(
                                      points: chartData.chart,
                                      showMorning: true,
                                      showEvening: false,
                                      showTrend: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
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

// ── Quote card ────────────────────────────────────────────────────────────────

const _loseQuotes = [
  'Every workout brings you closer to your best self.',
  'Sweat today, shine tomorrow.',
  'Small changes create powerful transformations.',
  'Burn excuses, build confidence.',
  'Discipline weighs less than regret.',
  'Stronger than yesterday, leaner than before.',
  'Fat loss is a journey, strength is the reward.',
  'One healthy choice can change everything.',
  'Confidence is built one workout at a time.',
  'Lose the doubt, gain the strength.',
];

const _gainQuotes = [
  'Every meal is a step closer to the stronger version of you.',
  'Growth happens when consistency meets effort.',
  'Fuel your body today, thank yourself tomorrow.',
  'Strength is built bite by bite, rep by rep.',
  'Bigger goals need bigger dedication.',
  'Confidence grows with every pound of progress.',
  'Eat strong, train stronger, become unstoppable.',
  'Muscle is earned through patience and persistence.',
  'Your body is under construction—keep building.',
  'Progress may be slow, but strength is always worth it.',
];

const _neutralQuotes = [
  'Progress is personal—move at your own pace.',
  'A healthy life starts with small daily choices.',
  'Your journey is yours alone—honor every step.',
  'Consistency matters more than perfection.',
  'Strong habits create lasting results.',
  'Take care of your body—it carries you through life.',
  'Every positive choice adds up over time.',
  'Wellness is built one day at a time.',
  'Focus on feeling better, not being perfect.',
  'The best investment is in your own health.',
];

class _QuoteCard extends StatelessWidget {
  final String? goalType;
  const _QuoteCard({this.goalType});

  @override
  Widget build(BuildContext context) {
    final quotes = goalType == 'LOSE'
        ? _loseQuotes
        : goalType == 'GAIN'
            ? _gainQuotes
            : _neutralQuotes;

    // Pick a consistent daily quote using day-of-year as index.
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final quote = quotes[dayOfYear % quotes.length];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 20,
              color: const Color(0xFF22C55E),
            ),
            const SizedBox(height: 12),
            Text(
              quote,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weight card ───────────────────────────────────────────────────────────────

class _WeightCard extends StatelessWidget {
  final double? morningWeight;
  final String morningTime;
  final double? eveningWeight;
  final String eveningTime;

  const _WeightCard({
    this.morningWeight,
    required this.morningTime,
    this.eveningWeight,
    required this.eveningTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Morning
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Morning',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        morningWeight?.toStringAsFixed(1) ?? '--',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('kg', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(LucideIcons.sun, size: 12, color: Color(0xFF22C55E)),
                      const SizedBox(width: 4),
                      Text(morningTime, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            // Evening — only shown if logged today
            if (eveningWeight != null) ...[
              const VerticalDivider(width: 24, color: Color(0xFF222222)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evening',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          eveningWeight!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text('kg', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(LucideIcons.moon, size: 12, color: Color(0xFF3B82F6)),
                        const SizedBox(width: 4),
                        Text(eveningTime, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
