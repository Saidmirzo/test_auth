from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import AuthSession, User


class SessionJWTAuthentication(JWTAuthentication):
    def get_user(self, validated_token):
        user_id = validated_token.get("user_id")
        user = User.objects.filter(pk=user_id, is_active=True).first()
        if user is None:
            raise AuthenticationFailed("User not found.")
        session_id = validated_token.get("session_id")
        if not session_id:
            raise AuthenticationFailed("Session is missing from token.")
        session = AuthSession.objects.filter(
            pk=session_id, user=user, is_active=True
        ).first()
        if session is None or session.is_expired():
            raise AuthenticationFailed("Session is no longer active.")
        return user
