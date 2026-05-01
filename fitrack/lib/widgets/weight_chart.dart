import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/progress.dart';

// ── Colour constants ─────────────────────────────────────────────────────────
const _morningColor = AppTheme.primary; // green
const _eveningColor = Color(0xFF60A5FA); // blue
const _trendColor = Color(0xFFA78BFA); // purple

/// Interactive line chart that renders morning weight, evening weight, and a
/// linear-regression trend line.  Tapping any point shows a tooltip.
class WeightChart extends StatefulWidget {
  final List<ProgressChartPoint> points;

  const WeightChart({super.key, required this.points});

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return const Center(
        child: Text(
          'No weight data for this period',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    // Build per-series FlSpot lists.
    // x = chart-point index (shared across all series for correct alignment).
    final morningSpots = <FlSpot>[];
    final eveningSpots = <FlSpot>[];
    final trendSpots = <FlSpot>[];

    for (int i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final x = i.toDouble();
      if (p.morningWeight != null) morningSpots.add(FlSpot(x, p.morningWeight!));
      if (p.eveningWeight != null) eveningSpots.add(FlSpot(x, p.eveningWeight!));
      if (p.trend != null) trendSpots.add(FlSpot(x, p.trend!));
    }

    // Y-axis bounds with ±2 kg padding, snapped to even numbers.
    final allYValues = [
      ...morningSpots.map((s) => s.y),
      ...eveningSpots.map((s) => s.y),
    ];
    if (allYValues.isEmpty) {
      return const Center(
        child: Text(
          'No weight data for this period',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }
    final rawMin = allYValues.reduce((a, b) => a < b ? a : b);
    final rawMax = allYValues.reduce((a, b) => a > b ? a : b);
    final minY = ((rawMin - 2).floorToDouble() ~/ 2 * 2).toDouble();
    final maxY = ((rawMax + 2).ceilToDouble() ~/ 2 * 2 + 2).toDouble();
    final yInterval = _niceInterval(maxY - minY);

    final n = widget.points.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Legend(),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (n - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),

              // ── Grid ─────────────────────────────────────────────────────
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppTheme.divider,
                  strokeWidth: 0.5,
                ),
              ),

              // ── Border ───────────────────────────────────────────────────
              borderData: FlBorderData(show: false),

              // ── Titles ───────────────────────────────────────────────────
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == minY || value == maxY) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final idx = value.round();
                      if (idx < 0 || idx >= n) return const SizedBox.shrink();
                      if (!_shouldShowXLabel(idx, n)) {
                        return const SizedBox.shrink();
                      }
                      final dt =
                          DateTime.tryParse(widget.points[idx].date);
                      final label = dt != null
                          ? DateFormat('MMM d').format(dt)
                          : widget.points[idx].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Touch / tooltip ──────────────────────────────────────────
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: true,
                touchSpotThreshold: 24,
                getTouchedSpotIndicator:
                    (barData, spotIndexes) => spotIndexes.map((i) {
                  return TouchedSpotIndicatorData(
                    const FlLine(
                      color: Colors.white24,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    FlDotData(
                      getDotPainter: (spot, pct, bar, index) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: bar.color ?? Colors.white,
                        strokeWidth: 1.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: const Color(0xFF1E2532),
                  tooltipRoundedRadius: 10,
                  tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  getTooltipItems: (touchedSpots) {
                    if (touchedSpots.isEmpty) return [];

                    // Date header from the first touched spot's x-index.
                    final di = touchedSpots.first.x.round();
                    final dt = (di >= 0 && di < n)
                        ? DateTime.tryParse(widget.points[di].date)
                        : null;
                    final dateLabel =
                        dt != null ? DateFormat('MMM d').format(dt) : '';

                    return touchedSpots.asMap().entries.map((entry) {
                      final isFirst = entry.key == 0;
                      final spot = entry.value;

                      String value;
                      Color color;
                      switch (spot.barIndex) {
                        case 0:
                          value =
                              'Morning: ${spot.y.toStringAsFixed(1)} kg';
                          color = _morningColor;
                          break;
                        case 1:
                          value =
                              'Evening: ${spot.y.toStringAsFixed(1)} kg';
                          color = _eveningColor;
                          break;
                        case 2:
                          value =
                              'Trend: ${spot.y.toStringAsFixed(1)} kg';
                          color = _trendColor;
                          break;
                        default:
                          return null;
                      }

                      if (isFirst) {
                        return LineTooltipItem(
                          '$dateLabel\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(
                              text: value,
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }
                      return LineTooltipItem(
                        value,
                        TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),

              // ── Lines ────────────────────────────────────────────────────
              lineBarsData: [
                // 0: Morning (green)
                LineChartBarData(
                  spots: morningSpots,
                  color: _morningColor,
                  barWidth: 2,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: n <= 30,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: _morningColor,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                ),
                // 1: Evening (blue)
                LineChartBarData(
                  spots: eveningSpots,
                  color: _eveningColor,
                  barWidth: 2,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: n <= 30,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: _eveningColor,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                ),
                // 2: Trend (dashed purple)
                LineChartBarData(
                  spots: trendSpots,
                  color: _trendColor,
                  barWidth: 1.5,
                  isCurved: false,
                  isStrokeCapRound: false,
                  dotData: const FlDotData(show: false),
                  dashArray: const [6, 4],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Show x-axis labels at first, last, and ~2 intermediate points.
  bool _shouldShowXLabel(int idx, int total) {
    if (total <= 1) return idx == 0;
    if (idx == 0 || idx == total - 1) return true;
    final step = total ~/ 4;
    return step > 0 && idx % step == 0;
  }

  /// Pick a y-interval that gives 4–6 gridlines.
  double _niceInterval(double range) {
    if (range <= 0) return 2;
    for (final i in [1.0, 2.0, 4.0, 5.0, 10.0]) {
      if (range / i <= 6) return i;
    }
    return (range / 5).ceilToDouble();
  }
}

// ── Chart legend ──────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: _morningColor, label: 'Morning'),
        const SizedBox(width: 12),
        _LegendDot(color: _eveningColor, label: 'Evening'),
        const SizedBox(width: 12),
        _LegendLine(color: _trendColor, label: 'Trend'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _LegendLine extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendLine({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          child: CustomPaint(painter: _DashLinePainter(color: color)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _DashLinePainter extends CustomPainter {
  final Color color;
  const _DashLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    double x = 0;
    const dashLen = 4.0;
    const gapLen = 3.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, y), Offset((x + dashLen).clamp(0, size.width), y), paint);
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _DashLinePainter old) => old.color != color;
}
