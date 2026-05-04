import base64
import json
from datetime import date, datetime

from django.utils import timezone
from rest_framework import status
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import UserConsent, UserKYC


def _get_client_ip(request):
    x_forwarded = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded:
        return x_forwarded.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


class KYCStatusView(APIView):
    """GET /kyc/status/  — return current KYC state for the authenticated user."""

    def get(self, request):
        user = request.user
        kyc = getattr(user, 'kyc', None)

        if kyc is None:
            return Response({
                'kyc_completed': False,
                'kyc_status': 'pending',
                'upload_enabled': False,
            })

        return Response({
            'kyc_completed': kyc.is_completed,
            'kyc_status': kyc.status,
            'upload_enabled': kyc.is_completed,
            # Return embedding so the client can verify uploaded photos on-device
            # without a round-trip.  Only included when KYC is complete.
            'face_embedding': kyc.face_embedding if kyc.is_completed else None,
        })


class KYCConsentView(APIView):
    """POST /kyc/consent/  — record user consent declarations."""

    parser_classes = [JSONParser]

    def post(self, request):
        data = request.data
        required = [
            'terms_accepted',
            'privacy_accepted',
            'photo_processing_accepted',
            'sensitive_data_accepted',
            'adult_confirmed',
            'self_photo_confirmed',
        ]
        for field in required:
            if not data.get(field):
                return Response(
                    {'error': f'{field} is required and must be true.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        UserConsent.objects.create(
            user=request.user,
            terms_accepted=True,
            privacy_accepted=True,
            photo_processing_accepted=True,
            sensitive_data_accepted=True,
            adult_confirmed=True,
            self_photo_confirmed=True,
            ip_address=_get_client_ip(request),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
            consent_version=data.get('consent_version', 'v1'),
        )

        return Response({'detail': 'Consent recorded.'}, status=status.HTTP_201_CREATED)


class KYCCompleteView(APIView):
    """POST /kyc/complete/  — submit liveness result, DOB and face embedding."""

    parser_classes = [JSONParser, MultiPartParser]

    def post(self, request):
        user = request.user
        data = request.data

        # Parse DOB
        dob_str = data.get('dob')
        if not dob_str:
            return Response(
                {'error': 'dob is required (YYYY-MM-DD).'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            dob = date.fromisoformat(str(dob_str))
        except ValueError:
            return Response(
                {'error': 'Invalid dob format. Use YYYY-MM-DD.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Age check (must be 18+)
        today = date.today()
        age_years = (today - dob).days // 365
        if age_years < 18:
            return Response(
                {'error': 'You must be at least 18 years old to use this feature.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Face embedding (list of floats sent by client, or null)
        face_embedding = None
        raw_embedding = data.get('face_embedding')
        if raw_embedding:
            if isinstance(raw_embedding, str):
                try:
                    face_embedding = json.loads(raw_embedding)
                except (ValueError, TypeError):
                    face_embedding = None
            elif isinstance(raw_embedding, list):
                face_embedding = raw_embedding

        # Upsert KYC record
        kyc, _ = UserKYC.objects.get_or_create(user=user)
        kyc.status = UserKYC.Status.APPROVED
        kyc.is_completed = True
        kyc.age_confirmed = True
        kyc.dob = dob
        kyc.face_embedding = face_embedding
        kyc.completed_at = timezone.now()
        kyc.save()

        return Response({
            'kyc_completed': True,
            'kyc_status': 'approved',
            'upload_enabled': True,
        }, status=status.HTTP_200_OK)
