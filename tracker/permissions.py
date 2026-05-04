from rest_framework.permissions import BasePermission


class IsKYCCompleted(BasePermission):
    """Allow access only to users who have completed KYC verification."""

    message = {
        'error': 'KYC_REQUIRED',
        'message': 'Complete identity verification before uploading photos.',
    }

    def has_permission(self, request, view):
        user = request.user
        return (
            user
            and user.is_authenticated
            and hasattr(user, 'kyc')
            and user.kyc.is_completed
        )
