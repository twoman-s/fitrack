from rest_framework import serializers

from tracker.serializers.photo_serializers import ProgressPhotoSessionSerializer


class DashboardSerializer(serializers.Serializer):
    """Serializer for the aggregated dashboard response."""

    latest_morning_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    latest_evening_weight = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    weekly_avg = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    monthly_avg = serializers.DecimalField(
        max_digits=5, decimal_places=2, allow_null=True,
    )
    streak = serializers.IntegerField()
    latest_photos = ProgressPhotoSessionSerializer(allow_null=True)
