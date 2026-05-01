from rest_framework import serializers

from tracker.models import WeightGoal


class WeightGoalSerializer(serializers.ModelSerializer):

    class Meta:
        model = WeightGoal
        fields = [
            'id', 'goal_type', 'target_weight',
            'start_date', 'target_date', 'is_active',
            'completed_at', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'completed_at', 'created_at', 'updated_at']
