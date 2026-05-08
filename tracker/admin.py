from django.contrib import admin

from .models import (
    DailyWeightEntry,
    ProgressPhoto,
    ProgressPhotoSession,
    UserConsent,
    UserKYC,
    WeightGoal,
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


@admin.register(WeightGoal)
class WeightGoalAdmin(admin.ModelAdmin):
    list_display = ('user', 'goal_type', 'current_weight', 'target_weight', 'start_date', 'target_date', 'is_active')
    list_filter = ('goal_type', 'is_active')
    search_fields = ('user__username',)
    ordering = ('-created_at',)
    date_hierarchy = 'start_date'


@admin.register(UserKYC)
class UserKYCAdmin(admin.ModelAdmin):
    list_display = ('user', 'status', 'is_completed', 'age_confirmed', 'dob', 'completed_at', 'updated_at')
    list_filter = ('status', 'is_completed', 'age_confirmed')
    search_fields = ('user__username',)
    ordering = ('-updated_at',)
    readonly_fields = ('face_embedding', 'created_at', 'updated_at', 'completed_at')


@admin.register(UserConsent)
class UserConsentAdmin(admin.ModelAdmin):
    list_display = ('user', 'consent_version', 'terms_accepted', 'privacy_accepted', 'photo_processing_accepted', 'accepted_at')
    list_filter = ('consent_version', 'terms_accepted', 'privacy_accepted')
    search_fields = ('user__username',)
    ordering = ('-accepted_at',)
    readonly_fields = ('accepted_at', 'ip_address', 'user_agent')
