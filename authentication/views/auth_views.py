from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView

from authentication.serializers import SignupSerializer, FitrackTokenObtainPairSerializer


class SignupView(generics.CreateAPIView):
    """Register a new user with username and password."""

    serializer_class = SignupSerializer
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(
            {'username': user.username, 'message': 'Account created successfully.'},
            status=status.HTTP_201_CREATED,
        )


class FitrackTokenObtainPairView(TokenObtainPairView):
    """Login view that returns tokens + show_onboarding flag."""
    serializer_class = FitrackTokenObtainPairSerializer


class ProfileView(APIView):
    """GET / PATCH the authenticated user's profile."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            'username': user.username,
            'name': user.name,
            'email': user.email,
        })

    def patch(self, request):
        user = request.user
        name = request.data.get('name')
        email = request.data.get('email')
        if name is not None:
            user.name = name.strip()
        if email is not None:
            user.email = email.strip()
        user.save()
        return Response({
            'username': user.username,
            'name': user.name,
            'email': user.email,
        })


class ChangePasswordView(APIView):
    """Change password for the authenticated user."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        current = request.data.get('current_password', '')
        new_pass = request.data.get('new_password', '')

        if not user.check_password(current):
            return Response(
                {'detail': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new_pass) < 8:
            return Response(
                {'detail': 'New password must be at least 8 characters.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(new_pass)
        user.save()
        return Response({'detail': 'Password changed successfully.'}, status=status.HTTP_200_OK)
