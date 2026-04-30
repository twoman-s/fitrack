from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import DailyWeightEntry, ProgressPhoto, WorkoutCheckin


@receiver(post_save, sender=DailyWeightEntry)
def update_checkin_on_weight_save(sender, instance, **kwargs):
    """Create or update WorkoutCheckin when a weight entry is saved."""
    checkin, _ = WorkoutCheckin.objects.get_or_create(
        user=instance.user,
        date=instance.date,
    )
    if not checkin.weight_logged:
        checkin.weight_logged = True
        checkin.save(update_fields=['weight_logged'])


@receiver(post_save, sender=ProgressPhoto)
def update_checkin_on_photo_save(sender, instance, **kwargs):
    """Create or update WorkoutCheckin when a photo is uploaded."""
    session = instance.session
    checkin, _ = WorkoutCheckin.objects.get_or_create(
        user=session.user,
        date=session.date,
    )
    if not checkin.photo_logged:
        checkin.photo_logged = True
        checkin.save(update_fields=['photo_logged'])
