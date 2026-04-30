from rest_framework import serializers

from tracker.models import DailyWeightEntry


class DailyWeightEntrySerializer(serializers.ModelSerializer):
    """Serializer for individual daily weight entries."""

    class Meta:
        model = DailyWeightEntry
        fields = [
            'id', 'date', 'morning_weight', 'morning_weight_time',
            'evening_weight', 'evening_weight_time',
            'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class WeightAggregateSerializer(serializers.Serializer):
    """Serializer for aggregated weight data (weekly / monthly / yearly)."""

    period = serializers.CharField()
    avg_morning_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    avg_evening_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    min_morning_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    max_morning_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    entry_count = serializers.IntegerField()
