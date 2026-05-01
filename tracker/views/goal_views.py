from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import WeightGoal
from tracker.serializers import WeightGoalSerializer


def _active_goal(user):
    """Return the user's current active goal or None."""
    return WeightGoal.objects.filter(user=user, is_active=True).first()


class WeightGoalView(APIView):
    """
    GET  /goal/         → active goal (null if none)
    POST /goal/         → create new goal (blocked if one is already active)
    GET  /goal/history/ → all goals for the user (paginated by ?page)
    """

    def get(self, request):
        goal = _active_goal(request.user)
        if goal is None:
            return Response(None, status=status.HTTP_200_OK)
        return Response(WeightGoalSerializer(goal).data)

    def post(self, request):
        # Block creation if there is already an active goal.
        existing = _active_goal(request.user)
        if existing is not None:
            return Response(
                {
                    'detail': (
                        'You already have an active goal. '
                        'Complete or deactivate it before creating a new one.'
                    ),
                    'active_goal': WeightGoalSerializer(existing).data,
                },
                status=status.HTTP_409_CONFLICT,
            )

        serializer = WeightGoalSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user, is_active=True)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class WeightGoalDetailView(APIView):
    """
    GET   /goal/<id>/  → retrieve single goal
    PATCH /goal/<id>/  → update fields (use is_active=false to complete)
    """

    def _get_goal(self, request, pk):
        try:
            return WeightGoal.objects.get(pk=pk, user=request.user)
        except WeightGoal.DoesNotExist:
            return None

    def get(self, request, pk):
        goal = self._get_goal(request, pk)
        if goal is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(WeightGoalSerializer(goal).data)

    def patch(self, request, pk):
        goal = self._get_goal(request, pk)
        if goal is None:
            return Response(status=status.HTTP_404_NOT_FOUND)

        # If caller is deactivating the goal, stamp completed_at.
        deactivating = (
            'is_active' in request.data
            and not request.data['is_active']
            and goal.is_active
        )

        serializer = WeightGoalSerializer(goal, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        instance = serializer.save()

        if deactivating:
            instance.completed_at = timezone.now()
            instance.save(update_fields=['completed_at'])
            return Response(WeightGoalSerializer(instance).data)

        return Response(serializer.data)


class WeightGoalHistoryView(APIView):
    """GET /goal/history/ → all goals, newest first."""

    def get(self, request):
        goals = WeightGoal.objects.filter(user=request.user).order_by('-created_at')
        return Response(WeightGoalSerializer(goals, many=True).data)
