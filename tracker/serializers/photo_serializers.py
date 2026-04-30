from rest_framework import serializers

from tracker.models import ProgressPhoto, ProgressPhotoSession


class ProgressPhotoSerializer(serializers.ModelSerializer):
    """Serializer for individual progress photos with absolute URL."""

    image_url = serializers.SerializerMethodField()

    class Meta:
        model = ProgressPhoto
        fields = ['id', 'photo_type', 'image', 'image_url', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None


class ProgressPhotoSessionSerializer(serializers.ModelSerializer):
    """Serializer for a photo session with nested photos."""

    photos = ProgressPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = ProgressPhotoSession
        fields = ['id', 'date', 'notes', 'photos', 'created_at']
        read_only_fields = ['id', 'created_at']


class PhotoUploadSerializer(serializers.Serializer):
    """Validates multipart photo upload input."""

    date = serializers.DateField()
    photo_type = serializers.ChoiceField(choices=ProgressPhoto.PhotoType.choices)
    image = serializers.ImageField()


class PhotoCompareSerializer(serializers.Serializer):
    """Serializer for comparing photos between two dates."""

    from_image = serializers.CharField(allow_null=True)
    to_image = serializers.CharField(allow_null=True)
