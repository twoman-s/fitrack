from django.contrib import admin

from .models import (
    DailyWeightEntry,
    ProgressPhoto,
    ProgressPhotoSession,
    WorkoutCheckin,
)


@admin.register(DailyWeightEntry)
class DailyWeightEntryAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'morning_weight', 'evening_weight', 'updated_at')
    list_filter = ('date', 'user')
    search_fields = ('user__username',)
    ordering = ('-date',)
    date_hierarchy = 'date'


@admin.register(ProgressPhotoSession)
class ProgressPhotoSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'created_at')
    list_filter = ('date', 'user')
    search_fields = ('user__username',)
    ordering = ('-date',)
    date_hierarchy = 'date'


@admin.register(ProgressPhoto)
class ProgressPhotoAdmin(admin.ModelAdmin):
    list_display = ('session', 'photo_type', 'uploaded_at')
    list_filter = ('photo_type', 'uploaded_at')
    search_fields = ('session__user__username',)
    ordering = ('-uploaded_at',)


@admin.register(WorkoutCheckin)
class WorkoutCheckinAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'weight_logged', 'photo_logged', 'count')
    list_filter = ('weight_logged', 'photo_logged', 'date')
    search_fields = ('user__username',)
    ordering = ('-date',)
    date_hierarchy = 'date'

    @admin.display(description='Activity Count')
    def count(self, obj):
        return obj.count
