from datetime import date, timedelta

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import DailyWeightEntry, WeightGoal


def _period_start(today: date, period: str) -> date:
    if period == '7d':
        return today - timedelta(days=7)
    if period == '30d':
        return today - timedelta(days=30)
    if period == '3m':
        return today - timedelta(days=90)
    if period == '1y':
        return today - timedelta(days=365)
    return date(2000, 1, 1)  # 'all'


def _primary(entry) -> float | None:
    """Morning weight preferred; fallback to evening; None if both absent."""
    if entry.morning_weight is not None:
        return float(entry.morning_weight)
    # if entry.evening_weight is not None:
    #     return float(entry.evening_weight)
    return None


def _linear_regression(xs: list, ys: list):
    """Return (slope m, intercept b) for y = m*x + b."""
    n = len(xs)
    sum_x = sum(xs)
    sum_y = sum(ys)
    sum_xx = sum(x * x for x in xs)
    sum_xy = sum(x * y for x, y in zip(xs, ys))
    denom = n * sum_xx - sum_x ** 2
    if denom == 0:
        return 0.0, sum_y / n
    m = (n * sum_xy - sum_x * sum_y) / denom
    b = (sum_y - m * sum_x) / n
    return m, b


class ProgressView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        period = request.query_params.get('period', '30d')
        today = date.today()
        from_date = _period_start(today, period)

        # ── Chart data ──────────────────────────────────────────────────────
        entries = (
            DailyWeightEntry.objects
            .filter(user=user, date__gte=from_date, date__lte=today)
            .order_by('date')
        )

        chart = []
        for entry in entries:
            primary = _primary(entry)
            if primary is None:
                continue  # skip dates with no readings
            chart.append({
                'date': entry.date.strftime('%Y-%m-%d'),
                'morning_weight': (
                    float(entry.morning_weight)
                    if entry.morning_weight is not None else None
                ),
                'evening_weight': (
                    float(entry.evening_weight)
                    if entry.evening_weight is not None else None
                ),
                'primary_weight': primary,
            })

        # ── Trend: simple linear regression on primary weights ───────────────
        #   x = sequential index (0-based); y = primary_weight
        n = len(chart)
        if n >= 2:
            xs = list(range(n))
            ys = [p['primary_weight'] for p in chart]
            m, b = _linear_regression(xs, ys)
            for i, p in enumerate(chart):
                p['trend'] = round(m * i + b, 2)
        elif n == 1:
            chart[0]['trend'] = chart[0]['primary_weight']

        # ── Goal progress ────────────────────────────────────────────────────
        goal_progress = None
        goal = WeightGoal.objects.filter(user=user, is_active=True).first()
        if goal is not None:
            # Start weight: use goal.current_weight if the user set it;
            # otherwise fall back to the first recorded weight on/after
            # goal.start_date, then to the latest weight before it.
            start_weight = None
            if goal.current_weight is not None:
                start_weight = float(goal.current_weight)

            if start_weight is None:
                for e in DailyWeightEntry.objects.filter(
                    user=user, date__gte=goal.start_date
                ).order_by('date'):
                    pw = _primary(e)
                    if pw is not None:
                        start_weight = pw
                        break

            if start_weight is None:
                for e in DailyWeightEntry.objects.filter(
                    user=user, date__lt=goal.start_date
                ).order_by('-date'):
                    pw = _primary(e)
                    if pw is not None:
                        start_weight = pw
                        break

            # Current weight: most recent primary reading overall
            current_weight = None
            for e in DailyWeightEntry.objects.filter(user=user).order_by('-date'):
                pw = _primary(e)
                if pw is not None:
                    current_weight = pw
                    break

            if start_weight is not None and current_weight is not None:
                target = float(goal.target_weight)
                is_lose = goal.goal_type == 'LOSE'

                if is_lose:
                    changed = round(start_weight - current_weight, 1)
                    total_needed = start_weight - target
                else:
                    changed = round(current_weight - start_weight, 1)
                    total_needed = target - start_weight

                if total_needed > 0:
                    raw_pct = changed / total_needed * 100
                else:
                    raw_pct = 100.0

                percentage = round(max(0.0, min(100.0, raw_pct)), 1)

                goal_progress = {
                    'goal_type': goal.goal_type,
                    'start_weight': round(start_weight, 1),
                    'current_weight': round(current_weight, 1),
                    'target_weight': round(target, 1),
                    'changed': changed,
                    'percentage': percentage,
                    'remaining': round(abs(current_weight - target), 1),
                }

        return Response({
            'period': period,
            'chart': chart,
            'goal_id': goal.pk if goal is not None else None,
            'goal_progress': goal_progress,
        })
