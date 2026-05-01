from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from authentication.views import SignupView, FitrackTokenObtainPairView, ChangePasswordView, ProfileView

app_name = 'authentication'

urlpatterns = [
    path('signup/', SignupView.as_view(), name='signup'),
    path('login/', FitrackTokenObtainPairView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('profile/', ProfileView.as_view(), name='profile'),
]
