from .weight_views import DailyWeightView
from .photo_views import PhotoUploadView, PhotosByDateView, PhotoCompareView, PhotoDeleteView, PhotoLatestView
from .heatmap_views import HeatmapView
from .dashboard_views import DashboardView
from .goal_views import WeightGoalView, WeightGoalDetailView, WeightGoalHistoryView
from .progress_views import ProgressView
from .stats_views import StatsView

__all__ = [
    'DailyWeightView',
    'PhotoUploadView',
    'PhotosByDateView',
    'PhotoCompareView',
    'HeatmapView',
    'DashboardView',
    'WeightGoalView',
    'WeightGoalDetailView',
    'WeightGoalHistoryView',
    'ProgressView',
    'StatsView',
]
