import os
import time

from django.conf import settings
from django.db import models


# ---------------------------------------------------------------------------
# Daily Weight Entry
# ---------------------------------------------------------------------------

class DailyWeightEntry(models.Model):
    """Stores morning and evening weight readings for a single day."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='weight_entries',
    )
    date = models.DateField()
    morning_weight = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
    )
    morning_weight_time = models.TimeField(null=True, blank=True)
    evening_weight = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True,
    )
    evening_weight_time = models.TimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'daily_weight_entries'
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'date'],
                name='unique_weight_per_user_per_date',
            ),
        ]
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} – {self.date}"


# ---------------------------------------------------------------------------
# Progress Photo Session & Photo
# ---------------------------------------------------------------------------

def progress_photo_upload_path(instance, filename):
    """Generate upload path: progress_photos/<username>/<year>/<month>/<date>_<type>_<unix_ts>.<ext>
    The Unix timestamp ensures every upload has a unique filename/URL, preventing
    stale images being served from HTTP or in-memory caches.
    """
    session = instance.session
    username = session.user.username
    year = session.date.strftime('%Y')
    month = session.date.strftime('%m')
    date_str = session.date.strftime('%Y%m%d')
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else 'jpg'
    photo_type = getattr(instance, 'photo_type', 'photo').lower()
    ts = int(time.time())
    new_filename = f"{date_str}_{photo_type}_{ts}.{ext}"
    return os.path.join('progress_photos', username, year, month, new_filename)


def normalized_photo_upload_path(instance, filename):
    """Upload path for normalized (cropped) images:
    progress_photos/<username>/<year>/<month>/normalized/<date>_<type>_norm_<ts>.<ext>
    """
    session = instance.session
    username = session.user.username
    year = session.date.strftime('%Y')
    month = session.date.strftime('%m')
    date_str = session.date.strftime('%Y%m%d')
    ext = filename.rsplit('.', 1)[-1].lower() if '.' in filename else 'jpg'
    photo_type = getattr(instance, 'photo_type', 'photo').lower()
    ts = int(time.time())
    new_filename = f"{date_str}_{photo_type}_norm_{ts}.{ext}"
    return os.path.join('progress_photos', username, year, month, 'normalized', new_filename)



class ProgressPhotoSession(models.Model):
    """One photo session per user per day."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='photo_sessions',
    )
    date = models.DateField()
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'progress_photo_sessions'
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'date'],
                name='unique_session_per_user_per_date',
            ),
        ]
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} – {self.date}"


class ProgressPhoto(models.Model):
    """Individual photo within a session, one per angle type."""

    class PhotoType(models.TextChoices):
        FRONT = 'FRONT', 'Front'
        SIDE = 'SIDE', 'Side'
        BACK = 'BACK', 'Back'

    session = models.ForeignKey(
        ProgressPhotoSession,
        on_delete=models.CASCADE,
        related_name='photos',
    )
    photo_type = models.CharField(max_length=5, choices=PhotoType.choices)
    image = models.ImageField(upload_to=progress_photo_upload_path)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    # ── Normalized capture fields ──────────────────────────────────────────
    normalized_image = models.ImageField(
        upload_to=normalized_photo_upload_path,
        null=True,
        blank=True,
    )
    crop_scale = models.FloatField(null=True, blank=True)
    crop_offset_x = models.FloatField(null=True, blank=True)
    crop_offset_y = models.FloatField(null=True, blank=True)
    crop_aspect_ratio = models.FloatField(default=0.75)  # 3:4 portrait

    class Meta:
        db_table = 'progress_photos'
        constraints = [
            models.UniqueConstraint(
                fields=['session', 'photo_type'],
                name='unique_photo_type_per_session',
            ),
        ]

    def __str__(self):
        return f"{self.session} – {self.photo_type}"


# ---------------------------------------------------------------------------
# Workout Check-in (heatmap)
# ---------------------------------------------------------------------------

class WorkoutCheckin(models.Model):
    """Tracks daily activity for heatmap visualization."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='checkins',
    )
    date = models.DateField()
    weight_logged = models.BooleanField(default=False)
    photo_logged = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'workout_checkins'
        constraints = [
            models.UniqueConstraint(
                fields=['user', 'date'],
                name='unique_checkin_per_user_per_date',
            ),
        ]
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} – {self.date}"

    @property
    def count(self):
        """Activity count: 0=none, 1=weight only, 2=photo only, 3=both."""
        if self.weight_logged and self.photo_logged:
            return 3
        if self.weight_logged:
            return 1
        if self.photo_logged:
            return 2
        return 0


# ---------------------------------------------------------------------------
# Weight Goal
# ---------------------------------------------------------------------------

class WeightGoal(models.Model):
    """User weight goals — multiple per user, at most one active at a time."""

    class GoalType(models.TextChoices):
        LOSE = 'LOSE', 'Lose Weight'
        GAIN = 'GAIN', 'Gain Weight'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='weight_goals',
    )
    goal_type = models.CharField(max_length=4, choices=GoalType.choices)
    current_weight = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    target_weight = models.DecimalField(max_digits=5, decimal_places=2)
    start_date = models.DateField()
    target_date = models.DateField()
    is_active = models.BooleanField(default=True, db_index=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'weight_goals'
        ordering = ['-created_at']

    def __str__(self):
        status = 'active' if self.is_active else 'completed'
        return f"{self.user.username} – {self.goal_type} → {self.target_weight} kg ({status})"
