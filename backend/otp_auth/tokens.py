import uuid

from django.conf import settings
from django.utils import timezone
from rest_framework_simplejwt.tokens import RefreshToken

from .models import AuthSession, Device


def parse_device(payload):
    raw = payload.get("device") if isinstance(payload, dict) else None
    if not isinstance(raw, dict):
        raw = {}
    device_id = str(raw.get("device_id") or raw.get("deviceId") or "").strip()
    return {
        "device_id": device_id or "unknown",
        "name": str(raw.get("name") or raw.get("device_name") or "")[:255],
        "platform": str(raw.get("platform") or "")[:32],
        "os_version": str(raw.get("os_version") or raw.get("osVersion") or "")[:64],
        "app_version": str(raw.get("app_version") or raw.get("appVersion") or "")[:64],
    }


def client_ip(request):
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.META.get("REMOTE_ADDR")


def upsert_device(user, device_data):
    device, _ = Device.objects.update_or_create(
        user=user,
        device_id=device_data["device_id"],
        defaults={
            "name": device_data["name"],
            "platform": device_data["platform"],
            "os_version": device_data["os_version"],
            "app_version": device_data["app_version"],
            "is_active": True,
        },
    )
    return device


def _build_tokens(user, session):
    refresh = RefreshToken()
    refresh["user_id"] = user.pk
    refresh["session_id"] = session.pk
    access = refresh.access_token
    access["user_id"] = user.pk
    access["session_id"] = session.pk
    session.refresh_jti = str(refresh["jti"])
    session.save(update_fields=["refresh_jti"])
    return refresh, access


def issue_tokens(user, request, device_data):
    device = upsert_device(user, device_data)
    AuthSession.objects.filter(user=user, device=device, is_active=True).update(
        is_active=False
    )

    refresh_expires = timezone.now() + settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"]
    session = AuthSession.objects.create(
        user=user,
        device=device,
        refresh_jti=uuid.uuid4().hex,
        refresh_expires_at=refresh_expires,
        ip_address=client_ip(request),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:2000],
        is_active=True,
    )
    refresh, access = _build_tokens(user, session)
    user.last_login = timezone.now()
    user.save(update_fields=["last_login"])
    return {
        "access": str(access),
        "refresh": str(refresh),
        "access_expires_in": int(
            settings.SIMPLE_JWT["ACCESS_TOKEN_LIFETIME"].total_seconds()
        ),
        "refresh_expires_in": int(
            settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"].total_seconds()
        ),
    }


def rotate_refresh(refresh_token: RefreshToken, request):
    session_id = refresh_token.get("session_id")
    jti = str(refresh_token.get("jti") or "")
    session = (
        AuthSession.objects.select_related("user", "device")
        .filter(pk=session_id, is_active=True, refresh_jti=jti)
        .first()
    )
    if session is None or session.is_expired():
        if session is not None:
            session.is_active = False
            session.save(update_fields=["is_active"])
        raise ValueError("Refresh token is invalid or expired.")

    session.is_active = False
    session.save(update_fields=["is_active"])

    user = session.user
    device = session.device
    refresh_expires = timezone.now() + settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"]
    new_session = AuthSession.objects.create(
        user=user,
        device=device,
        refresh_jti=uuid.uuid4().hex,
        refresh_expires_at=refresh_expires,
        ip_address=client_ip(request),
        user_agent=request.META.get("HTTP_USER_AGENT", "")[:2000],
        is_active=True,
    )
    new_refresh, access = _build_tokens(user, new_session)
    device.last_seen_at = timezone.now()
    device.save(update_fields=["last_seen_at"])
    return {
        "access": str(access),
        "refresh": str(new_refresh),
        "access_expires_in": int(
            settings.SIMPLE_JWT["ACCESS_TOKEN_LIFETIME"].total_seconds()
        ),
        "refresh_expires_in": int(
            settings.SIMPLE_JWT["REFRESH_TOKEN_LIFETIME"].total_seconds()
        ),
        "session": new_session,
    }


def session_payload(session: AuthSession):
    device = session.device
    return {
        "id": session.pk,
        "is_active": session.is_active and not session.is_expired(),
        "created_at": session.created_at.isoformat(),
        "last_seen_at": session.last_seen_at.isoformat(),
        "ip_address": session.ip_address,
        "device": {
            "id": device.pk,
            "device_id": device.device_id,
            "name": device.name,
            "platform": device.platform,
            "os_version": device.os_version,
            "app_version": device.app_version,
            "is_active": device.is_active,
            "last_seen_at": device.last_seen_at.isoformat(),
        },
    }
