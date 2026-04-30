from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    """Custom user model – only username, password, and date_joined."""

    first_name = None
    last_name = None
    email = None

    REQUIRED_FIELDS = []

    class Meta:
        db_table = 'users'

    def __str__(self):
        return self.username
