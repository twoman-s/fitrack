from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from tracker.models import ProgressPhoto, ProgressPhotoSession
from tracker.serializers import (
    PhotoCompareSerializer,
    PhotoUploadSerializer,
    ProgressPhotoSerializer,
    ProgressPhotoSessionSerializer,
)


class PhotoUploadView(APIView):
    """Upload a progress photo (multipart form)."""

    def post(self, request):
        serializer = PhotoUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        # Get or create session for the date
        session, _ = ProgressPhotoSession.objects.get_or_create(
            user=request.user,
            date=data['date'],
        )

        # Create or replace photo for the given type
        photo, created = ProgressPhoto.objects.update_or_create(
            session=session,
            photo_type=data['photo_type'],
            defaults={'image': data['image']},
        )

        return Response(
            ProgressPhotoSerializer(photo, context={'request': request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class PhotosByDateView(APIView):
    """Get all photos for a specific date."""

    def get(self, request):
        date_str = request.query_params.get('date')
        if not date_str:
            return Response(
                {'detail': 'date query parameter is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            session = ProgressPhotoSession.objects.get(
                user=request.user,
                date=date_str,
            )
        except ProgressPhotoSession.DoesNotExist:
            return Response(
                {'detail': 'No photo session found for this date.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = ProgressPhotoSessionSerializer(
            session, context={'request': request},
        )
        return Response(serializer.data)


class PhotoCompareView(APIView):
    """Compare photos between two dates for a given type."""

    def get(self, request):
        from_date = request.query_params.get('from')
        to_date = request.query_params.get('to')
        photo_type = request.query_params.get('type', 'FRONT')

        if not from_date or not to_date:
            return Response(
                {'detail': 'Both "from" and "to" query parameters are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from_image = self._get_photo_url(request, from_date, photo_type)
        to_image = self._get_photo_url(request, to_date, photo_type)

        serializer = PhotoCompareSerializer({
            'from_image': from_image,
            'to_image': to_image,
        })
        return Response(serializer.data)

    def _get_photo_url(self, request, date_str, photo_type):
        """Resolve a photo URL for a given date and type, or None."""
        try:
            session = ProgressPhotoSession.objects.get(
                user=request.user,
                date=date_str,
            )
            photo = ProgressPhoto.objects.get(
                session=session,
                photo_type=photo_type,
            )
            return request.build_absolute_uri(photo.image.url)
        except (ProgressPhotoSession.DoesNotExist, ProgressPhoto.DoesNotExist):
            return None
