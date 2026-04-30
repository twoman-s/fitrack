from django.utils import timezone
from django.db.models import Avg, Max, Min, Count
from django.db.models.functions import TruncWeek, TruncMonth, TruncYear
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import DailyWeightEntry
from tracker.serializers import DailyWeightEntrySerializer, WeightAggregateSerializer


class DailyWeightView(APIView):
    """
    POST: Add or update daily weight (upsert by user + date).
    GET:  Retrieve weight history with optional aggregation.
    """

    def post(self, request):
        serializer = DailyWeightEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        entry = DailyWeightEntry.objects.filter(user=request.user, date=data['date']).first()
        
        defaults = {}

        # Handle morning weight - allow explicit null to clear
        if 'morning_weight' in request.data:
            if request.data['morning_weight'] is None or request.data['morning_weight'] == '':
                defaults['morning_weight'] = None
                defaults['morning_weight_time'] = None
            else:
                defaults['morning_weight'] = data.get('morning_weight')
                if data.get('morning_weight_time'):
                    defaults['morning_weight_time'] = data['morning_weight_time']
                elif not entry or not entry.morning_weight_time:
                    defaults['morning_weight_time'] = timezone.now().time()

        # Handle evening weight - allow explicit null to clear
        if 'evening_weight' in request.data:
            if request.data['evening_weight'] is None or request.data['evening_weight'] == '':
                defaults['evening_weight'] = None
                defaults['evening_weight_time'] = None
            else:
                defaults['evening_weight'] = data.get('evening_weight')
                if data.get('evening_weight_time'):
                    defaults['evening_weight_time'] = data['evening_weight_time']
                elif not entry or not entry.evening_weight_time:
                    defaults['evening_weight_time'] = timezone.now().time()

        # Handle time overrides (allow clearing time independently)
        if 'morning_weight_time' in request.data and request.data['morning_weight_time'] is None:
            defaults['morning_weight_time'] = None
        if 'evening_weight_time' in request.data and request.data['evening_weight_time'] is None:
            defaults['evening_weight_time'] = None
        
        if 'notes' in data:
            defaults['notes'] = data['notes'] or ''

        entry, created = DailyWeightEntry.objects.update_or_create(
            user=request.user,
            date=data['date'],
            defaults=defaults,
        )

        return Response(
            DailyWeightEntrySerializer(entry).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    def get(self, request):
        range_param = request.query_params.get('range', 'daily')
        qs = DailyWeightEntry.objects.filter(user=request.user).order_by('-date')

        # Filtering
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        month = request.query_params.get('month')
        year = request.query_params.get('year')

        if start_date:
            qs = qs.filter(date__gte=start_date)
        if end_date:
            qs = qs.filter(date__lte=end_date)
        if month:
            qs = qs.filter(date__month=month)
        if year:
            qs = qs.filter(date__year=year)

        if range_param == 'daily':
            from rest_framework.pagination import LimitOffsetPagination
            paginator = LimitOffsetPagination()
            paginator.default_limit = 30
            page = paginator.paginate_queryset(qs, request)
            if page is not None:
                serializer = DailyWeightEntrySerializer(page, many=True)
                return paginator.get_paginated_response(serializer.data)
            
            serializer = DailyWeightEntrySerializer(qs, many=True)
            return Response(serializer.data)

        # Determine truncation function
        trunc_map = {
            'weekly': TruncWeek,
            'monthly': TruncMonth,
            'yearly': TruncYear,
        }
        trunc_fn = trunc_map.get(range_param)
        if trunc_fn is None:
            return Response(
                {'detail': 'Invalid range. Choose daily, weekly, monthly, or yearly.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        aggregated = (
            qs
            .annotate(period=trunc_fn('date'))
            .values('period')
            .annotate(
                avg_morning_weight=Avg('morning_weight'),
                avg_evening_weight=Avg('evening_weight'),
                min_morning_weight=Min('morning_weight'),
                max_morning_weight=Max('morning_weight'),
                entry_count=Count('id'),
            )
            .order_by('-period')
        )

        # Convert period datetime to string for JSON serialization
        results = []
        for row in aggregated:
            period_val = row['period']
            if hasattr(period_val, 'date'):
                period_val = period_val.date()
            results.append({
                'period': str(period_val),
                'avg_morning_weight': row['avg_morning_weight'],
                'avg_evening_weight': row['avg_evening_weight'],
                'min_morning_weight': row['min_morning_weight'],
                'max_morning_weight': row['max_morning_weight'],
                'entry_count': row['entry_count'],
            })

        serializer = WeightAggregateSerializer(results, many=True)
        return Response(serializer.data)

    def delete(self, request):
        date_str = request.query_params.get('date')
        if not date_str:
            return Response({'detail': 'Date parameter is required for deletion.'}, status=status.HTTP_400_BAD_REQUEST)
        
        deleted, _ = DailyWeightEntry.objects.filter(user=request.user, date=date_str).delete()
        if deleted:
            return Response({'detail': 'Entry deleted successfully.'}, status=status.HTTP_204_NO_CONTENT)
        return Response({'detail': 'No entry found for the specified date.'}, status=status.HTTP_404_NOT_FOUND)
