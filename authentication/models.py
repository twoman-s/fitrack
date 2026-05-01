from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom user model – username, password, and optional name/email."""

    first_name = None
    last_name = None

    name = models.CharField(max_length=150, blank=True, default='')
    email = models.EmailField(blank=True, default='')

    REQUIRED_FIELDS = []

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.username
