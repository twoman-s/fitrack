import calendar
import math
from datetime import date, timedelta

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import DailyWeightEntry, WeightGoal


def _primary(e) -> float | None:
    if e.morning_weight is not None:
        return float(e.morning_weight)
    if e.evening_weight is not None:
        return float(e.evening_weight)
    return None


def _fmt_date(d) -> str:
    """Linux-safe date format without zero-padding, e.g. 'Apr 5'."""
    return d.strftime('%b %-d')


class StatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        today = date.today()

        # All entries sorted by date
        all_entries = list(
            DailyWeightEntry.objects.filter(user=user).order_by('date')
        )
        dated_weights = [
            (e.date, _primary(e)) for e in all_entries
        ]
        dated_weights = [(d, w) for d, w in dated_weights if w is not None]

        # Active goal
        goal = WeightGoal.objects.filter(user=user, is_active=True).first()
        is_lose = (goal.goal_type != 'GAIN') if goal else True

        # ── Avg change per week ─────────────────────────────────────────────
        def calc_avg_per_week(points):
            """Positive = good direction (losing if is_lose, gaining otherwise)."""
            if len(points) < 2:
                return None
            days = (points[-1][0] - points[0][0]).days
            weeks = max(days / 7, 1 / 7)
            delta = (
                (points[0][1] - points[-1][1]) if is_lose
                else (points[-1][1] - points[0][1])
            )
            return round(delta / weeks, 2)

        month_ago = today - timedelta(days=30)
        two_months_ago = today - timedelta(days=60)
        recent = [(d, w) for d, w in dated_weights if d >= month_ago]
        avg_per_week = calc_avg_per_week(recent if len(recent) >= 2 else dated_weights)

        last_month = [
            (d, w) for d, w in dated_weights if two_months_ago <= d < month_ago
        ]
        last_month_avg = calc_avg_per_week(last_month)

        vs_last_month_pct = None
        if avg_per_week is not None and last_month_avg and last_month_avg != 0:
            vs_last_month_pct = round(
                (avg_per_week - last_month_avg) / abs(last_month_avg) * 100
            )

        # ── Best weight ─────────────────────────────────────────────────────
        best_weight = None
        best_weight_date = None
        best_weight_label = 'Lowest Weight' if is_lose else 'Highest Weight'
        if dated_weights:
            best = (
                min(dated_weights, key=lambda x: x[1]) if is_lose
                else max(dated_weights, key=lambda x: x[1])
            )
            best_weight = round(best[1], 1)
            best_weight_date = best[0].strftime('%b %-d, %Y')

        # ── Best streak ─────────────────────────────────────────────────────
        best_streak = 0
        best_streak_start = None
        best_streak_end = None
        cur_streak = 0
        cur_start = None
        prev_d = None
        streak_dates = sorted(
            {e.date for e in all_entries if _primary(e) is not None}
        )
        for d in streak_dates:
            if prev_d is not None and (d - prev_d).days == 1:
                cur_streak += 1
            else:
                cur_streak = 1
                cur_start = d
            if cur_streak > best_streak:
                best_streak = cur_streak
                best_streak_start = cur_start
                best_streak_end = d
            prev_d = d

        # ── Days logged this month ───────────────────────────────────────────
        month_start = today.replace(day=1)
        days_logged_month = DailyWeightEntry.objects.filter(
            user=user, date__gte=month_start, date__lte=today
        ).count()
        days_in_full_month = calendar.monthrange(today.year, today.month)[1]

        # ── Milestones ───────────────────────────────────────────────────────
        milestones = []
        if goal is not None and dated_weights:
            # Determine start weight
            start_weight = None
            for d, w in dated_weights:
                if d >= goal.start_date:
                    start_weight = w
                    break
            if start_weight is None:
                before = [(d, w) for d, w in dated_weights if d < goal.start_date]
                if before:
                    start_weight = before[-1][1]

            if start_weight is not None:
                target = float(goal.target_weight)
                total_needed = abs(start_weight - target)
                current_w = dated_weights[-1][1]
                current_changed = (
                    (start_weight - current_w) if is_lose
                    else (current_w - start_weight)
                )

                # Build milestone definitions: (label, threshold_kg)
                defs = []

                # 1. First 1 kg
                if total_needed >= 1:
                    defs.append(('First 1 kg', 1.0))

                # 2. Round-number checkpoint (first 5-multiple in the right direction)
                if is_lose:
                    rnd = math.floor((start_weight - 0.01) / 5) * 5
                    rnd_kg = start_weight - rnd
                else:
                    rnd = math.ceil((start_weight + 0.01) / 5) * 5
                    rnd_kg = rnd - start_weight

                existing_thresholds = [t for _, t in defs]
                if (
                    1.5 < rnd_kg < total_needed * 0.95
                    and all(abs(rnd_kg - t) > 1.0 for t in existing_thresholds)
                ):
                    direction = 'Below' if is_lose else 'Above'
                    defs.append((f'{direction} {round(rnd)} kg', round(rnd_kg, 1)))

                # 3. 5 kg milestone
                if total_needed >= 4.5:
                    existing_thresholds = [t for _, t in defs]
                    if all(abs(5.0 - t) > 1.0 for t in existing_thresholds):
                        verb = 'Down' if is_lose else 'Up'
                        defs.append((f'5 kg {verb}', 5.0))

                # 4. Halfway There
                halfway = total_needed / 2
                existing_thresholds = [t for _, t in defs]
                if (
                    total_needed >= 3
                    and all(abs(halfway - t) > 1.0 for t in existing_thresholds)
                ):
                    defs.append(('Halfway There', round(halfway, 1)))

                # 5. Goal
                direction = 'Under' if is_lose else 'Over'
                defs.append((f'{direction} {round(target, 1)} kg', round(total_needed, 1)))

                # Sort by threshold and deduplicate within 0.5 kg
                defs.sort(key=lambda x: x[1])
                deduped = []
                for item in defs:
                    if not deduped or abs(item[1] - deduped[-1][1]) > 0.5:
                        deduped.append(item)

                # Resolve achieved dates
                found_next = False
                for label, threshold in deduped:
                    achieved_date = None
                    for d, w in dated_weights:
                        if d < goal.start_date:
                            continue
                        changed = (
                            (start_weight - w) if is_lose else (w - start_weight)
                        )
                        if changed >= threshold:
                            achieved_date = d
                            break

                    achieved = achieved_date is not None
                    is_next = not achieved and not found_next
                    if is_next:
                        found_next = True

                    milestones.append({
                        'label': label,
                        'achieved': achieved,
                        'date': _fmt_date(achieved_date) if achieved_date else None,
                        'progress': round(current_changed, 1) if is_next else None,
                        'total': round(threshold, 1) if is_next else None,
                        'remaining': (
                            round(threshold - current_changed, 1)
                            if not achieved and not is_next else None
                        ),
                        'is_next': is_next,
                    })

        return Response({
            'avg_change_per_week': avg_per_week,
            'vs_last_month_pct': vs_last_month_pct,
            'best_weight': best_weight,
            'best_weight_date': best_weight_date,
            'best_weight_label': best_weight_label,
            'best_streak': best_streak,
            'best_streak_start': _fmt_date(best_streak_start) if best_streak_start else None,
            'best_streak_end': _fmt_date(best_streak_end) if best_streak_end else None,
            'days_logged_month': days_logged_month,
            'days_in_month': days_in_full_month,
            'goal_type': goal.goal_type if goal else None,
            'milestones': milestones,
        })
