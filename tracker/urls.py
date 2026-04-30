from django.urls import path

from tracker.views import (
    DailyWeightView,
    PhotoUploadView,
    PhotosByDateView,
    PhotoCompareView,
    HeatmapView,
    DashboardView,
)

app_name = 'tracker'

urlpatterns = [
    # Weight
    path('weights/', DailyWeightView.as_view(), name='daily_weight'),

    # Photos
    path('photos/upload/', PhotoUploadView.as_view(), name='photo_upload'),
    path('photos/', PhotosByDateView.as_view(), name='photos_by_date'),
    path('photos/compare/', PhotoCompareView.as_view(), name='photo_compare'),

    # Heatmap
    path('heatmap/', HeatmapView.as_view(), name='heatmap'),

    # Dashboard
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
]
