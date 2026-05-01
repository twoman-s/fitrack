from django.urls import path

from tracker.views import (
    DailyWeightView,
    PhotoUploadView,
    PhotosByDateView,
    PhotoCompareView,
    PhotoDeleteView,
    PhotoLatestView,
    HeatmapView,
    DashboardView,
    WeightGoalView,
    WeightGoalDetailView,
    WeightGoalHistoryView,
    ProgressView,
    StatsView,
)

app_name = 'tracker'

urlpatterns = [
    # Weight
    path('weights/', DailyWeightView.as_view(), name='daily_weight'),

    # Photos
    path('photos/upload/', PhotoUploadView.as_view(), name='photo_upload'),
    path('photos/', PhotosByDateView.as_view(), name='photos_by_date'),
    path('photos/compare/', PhotoCompareView.as_view(), name='photo_compare'),
    path('photos/latest/', PhotoLatestView.as_view(), name='photo_latest'),
    path('photos/<int:pk>/', PhotoDeleteView.as_view(), name='photo_delete'),

    # Heatmap
    path('heatmap/', HeatmapView.as_view(), name='heatmap'),

    # Dashboard
    path('dashboard/', DashboardView.as_view(), name='dashboard'),

    # Goal
    path('goal/', WeightGoalView.as_view(), name='weight_goal'),
    path('goal/history/', WeightGoalHistoryView.as_view(), name='weight_goal_history'),
    path('goal/<int:pk>/', WeightGoalDetailView.as_view(), name='weight_goal_detail'),

    # Progress
    path('progress/', ProgressView.as_view(), name='progress'),

    # Stats
    path('stats/', StatsView.as_view(), name='stats'),
]
