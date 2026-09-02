from django.conf import settings
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token


class GoogleAuthError(ValueError):
    pass


def verify_google_id_token(token: str) -> dict:
    if not token:
        raise GoogleAuthError("Missing Google ID token.")
    try:
        info = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            clock_skew_in_seconds=10,
        )
    except Exception as exc:
        raise GoogleAuthError("Invalid Google ID token.") from exc

    issuer = info.get("iss")
    if issuer not in ("accounts.google.com", "https://accounts.google.com"):
        raise GoogleAuthError("Invalid Google token issuer.")

    allowed = settings.GOOGLE_CLIENT_IDS
    audience = info.get("aud")
    if allowed and audience not in allowed:
        raise GoogleAuthError(
            "Google token audience does not match iOS/Android/Web client IDs."
        )
    if not info.get("sub"):
        raise GoogleAuthError("Google token is missing subject.")
    return info
