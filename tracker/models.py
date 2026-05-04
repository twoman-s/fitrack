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


# ---------------------------------------------------------------------------
# KYC
# ---------------------------------------------------------------------------

class UserKYC(models.Model):
    """One KYC record per user — tracks identity verification state."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        FAILED = 'failed', 'Failed'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='kyc',
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING,
    )
    is_completed = models.BooleanField(default=False)
    age_confirmed = models.BooleanField(default=False)
    dob = models.DateField(null=True, blank=True)
    face_embedding = models.JSONField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'user_kyc'

    def __str__(self):
        return f"{self.user.username} – KYC {self.status}"


class UserConsent(models.Model):
    """Audit trail of user consent declarations."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='consents',
    )
    terms_accepted = models.BooleanField(default=False)
    privacy_accepted = models.BooleanField(default=False)
    photo_processing_accepted = models.BooleanField(default=False)
    sensitive_data_accepted = models.BooleanField(default=False)
    adult_confirmed = models.BooleanField(default=False)
    self_photo_confirmed = models.BooleanField(default=False)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    consent_version = models.CharField(max_length=20, default='v1')
    accepted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'user_consents'
        ordering = ['-accepted_at']

    def __str__(self):
        return f"{self.user.username} – consent {self.consent_version} @ {self.accepted_at:%Y-%m-%d}"
