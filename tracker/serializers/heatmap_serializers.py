from rest_framework import serializers


class HeatmapEntrySerializer(serializers.Serializer):
    """Serializer for a single day's heatmap data."""

    date = serializers.DateField()
    count = serializers.IntegerField()
