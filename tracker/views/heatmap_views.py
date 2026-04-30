import calendar
from datetime import date

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import WorkoutCheckin
from tracker.serializers import HeatmapEntrySerializer


class HeatmapView(APIView):
    """Return daily activity counts for a given month."""

    def get(self, request):
        month_str = request.query_params.get('month')
        if not month_str:
            return Response(
                {'detail': 'month query parameter is required (YYYY-MM).'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            year, month = map(int, month_str.split('-'))
        except (ValueError, AttributeError):
            return Response(
                {'detail': 'Invalid month format. Use YYYY-MM.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        _, days_in_month = calendar.monthrange(year, month)

        # Fetch all check-ins for the month in a single query
        checkins = WorkoutCheckin.objects.filter(
            user=request.user,
            date__year=year,
            date__month=month,
        )
        checkin_map = {c.date: c.count for c in checkins}

        # Build full month response (including days with 0 activity)
        results = []
        for day in range(1, days_in_month + 1):
            d = date(year, month, day)
            results.append({
                'date': d,
                'count': checkin_map.get(d, 0),
            })

        serializer = HeatmapEntrySerializer(results, many=True)
        return Response(serializer.data)
