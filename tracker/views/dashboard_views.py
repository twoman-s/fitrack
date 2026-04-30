from datetime import date, timedelta

from django.db.models import Avg
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import DailyWeightEntry, ProgressPhotoSession, WorkoutCheckin
from tracker.serializers import ProgressPhotoSessionSerializer


class DashboardView(APIView):
    """Aggregate dashboard data for the authenticated user."""

    def get(self, request):
        user = request.user
        today = date.today()

        # Latest weights
        latest_morning_obj = (
            DailyWeightEntry.objects
            .filter(user=user, morning_weight__isnull=False)
            .order_by('-date')
            .first()
        )
        latest_morning = latest_morning_obj.morning_weight if latest_morning_obj else None
        latest_morning_time = latest_morning_obj.morning_weight_time if latest_morning_obj else None

        latest_evening_obj = (
            DailyWeightEntry.objects
            .filter(user=user, evening_weight__isnull=False)
            .order_by('-date')
            .first()
        )
        latest_evening = latest_evening_obj.evening_weight if latest_evening_obj else None
        latest_evening_time = latest_evening_obj.evening_weight_time if latest_evening_obj else None

        # Weekly average (last 7 days)
        week_ago = today - timedelta(days=7)
        weekly = DailyWeightEntry.objects.filter(
            user=user, date__gte=week_ago,
        ).aggregate(avg=Avg('morning_weight'))
        weekly_avg = weekly['avg']

        # Monthly average (last 30 days)
        month_ago = today - timedelta(days=30)
        monthly = DailyWeightEntry.objects.filter(
            user=user, date__gte=month_ago,
        ).aggregate(avg=Avg('morning_weight'))
        monthly_avg = monthly['avg']

        # Streak: consecutive days with any check-in, counting backwards
        streak = 0
        check_day = today
        while True:
            exists = WorkoutCheckin.objects.filter(
                user=user, date=check_day,
            ).exists()
            if not exists:
                break
            streak += 1
            check_day -= timedelta(days=1)

        # Weekly graph (Sunday to Saturday for current week)
        idx = (today.weekday() + 1) % 7 # weekday() is Monday=0, Sunday=6
        sunday = today - timedelta(days=idx)
        weekly_graph = []
        for i in range(7):
            d = sunday + timedelta(days=i)
            entry = DailyWeightEntry.objects.filter(user=user, date=d).first()
            weekly_graph.append({
                'date': d.strftime('%Y-%m-%d'),
                'day': d.strftime('%a'),
                'morning_weight': entry.morning_weight if entry else None,
                'morning_weight_time': entry.morning_weight_time if entry else None,
                'evening_weight': entry.evening_weight if entry else None,
                'evening_weight_time': entry.evening_weight_time if entry else None,
            })

        # Latest photo session
        latest_session = (
            ProgressPhotoSession.objects
            .filter(user=user)
            .order_by('-date')
            .first()
        )
        latest_photos = None
        if latest_session:
            latest_photos = ProgressPhotoSessionSerializer(
                latest_session, context={'request': request},
            ).data

        data = {
            'latest_morning_weight': latest_morning,
            'latest_morning_time': latest_morning_time,
            'latest_evening_weight': latest_evening,
            'latest_evening_time': latest_evening_time,
            'weekly_avg': weekly_avg,
            'monthly_avg': monthly_avg,
            'streak': streak,
            'weekly_graph': weekly_graph,
            'latest_photos': latest_photos,
        }

        return Response(data)
