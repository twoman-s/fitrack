from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class SignupSerializer(serializers.Serializer):
    """Validates and creates a new user with username + password."""

    username = serializers.CharField(max_length=150)
    password = serializers.CharField(min_length=6, write_only=True)

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Username already taken.')
        return value

    def create(self, validated_data):
        user = User(username=validated_data['username'])
        user.set_password(validated_data['password'])
        user.save()
        return user


class FitrackTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Extends the JWT login response with show_onboarding flag."""

    def validate(self, attrs):
        data = super().validate(attrs)
        # Show onboarding when the user has no active weight goal.
        has_active_goal = self.user.weight_goals.filter(is_active=True).exists()
        data['show_onboarding'] = not has_active_goal
        return data
