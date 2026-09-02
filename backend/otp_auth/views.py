import json
import random
import re
import secrets

from django.conf import settings
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from otp_auth.google_auth import GoogleAuthError, verify_google_id_token
from otp_auth.identity import resolve_user, user_payload
from otp_auth.services.email_service import EmailSendError, EmailService
from otp_auth.tokens import (
    issue_tokens,
    parse_device,
    rotate_refresh,
    session_payload,
)

from .models import AuthSession, OtpChallenge

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
PHONE_RE = re.compile(r"^\+\d{7,15}$")


def _json_body(request):
    if not request.body:
        return {}
    try:
        payload = json.loads(request.body.decode("utf-8"))
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def _error(message, status=400):
    return JsonResponse({"error": message}, status=status)


def _auth_response(user, request, payload, provider):
    tokens = issue_tokens(user, request, parse_device(payload or {}))
    return JsonResponse({"ok": True, "user": user_payload(user), **tokens})


def _create_challenge(channel, destination):
    OtpChallenge.objects.filter(
        channel=channel, destination=destination, is_used=False
    ).update(is_used=True)
    return OtpChallenge.objects.create(
        channel=channel,
        destination=destination,
        code=f"{random.randint(0, 999999):06d}",
        session_id=secrets.token_urlsafe(24),
    )


def _telegram_url(session_id):
    username = (settings.TELEGRAM_BOT_USERNAME or "").lstrip("@")
    if not username or username == "YourAuthBot":
        return None
    return f"https://t.me/{username}?start={session_id}"


@csrf_exempt
@require_POST
def request_email_otp(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    email = str(payload.get("email") or "").strip().lower()
    if not EMAIL_RE.match(email):
        return _error("Enter a valid email address.")
    challenge = _create_challenge(OtpChallenge.CHANNEL_EMAIL, email)
    try:
        EmailService.send_otp(email, challenge.code)
    except EmailSendError as exc:
        challenge.delete()
        return _error(str(exc), status=502)
    return JsonResponse({"ok": True, "channel": "email"})


@csrf_exempt
@require_POST
def verify_email_otp(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    email = str(payload.get("email") or "").strip().lower()
    code = str(payload.get("code") or "").strip()
    return _verify(request, payload, OtpChallenge.CHANNEL_EMAIL, email, code)


@csrf_exempt
@require_POST
def request_phone_otp(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    phone = str(payload.get("phone") or "").replace(" ", "")
    if not PHONE_RE.match(phone):
        return _error("Enter a phone number with country code, e.g. +998901234567.")
    challenge = _create_challenge(OtpChallenge.CHANNEL_PHONE, phone)
    telegram_url = _telegram_url(challenge.session_id)
    body = {
        "ok": True,
        "channel": "phone",
        "session_id": challenge.session_id,
        "redirect_path": f"/auth/telegram-redirect/{challenge.session_id}/",
        "telegram_url": telegram_url,
    }
    if settings.DEBUG and not settings.TELEGRAM_BOT_TOKEN:
        challenge.contact_verified = True
        challenge.save(update_fields=["contact_verified"])
        body["debug_code"] = challenge.code
    return JsonResponse(body)


@csrf_exempt
@require_POST
def verify_phone_otp(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    phone = str(payload.get("phone") or "").replace(" ", "")
    code = str(payload.get("code") or "").strip()
    return _verify(request, payload, OtpChallenge.CHANNEL_PHONE, phone, code)


def _verify(request, payload, channel, destination, code):
    if not destination or not re.fullmatch(r"\d{6}", code or ""):
        return _error("Invalid verification code.")
    challenge = (
        OtpChallenge.objects.filter(
            channel=channel, destination=destination, is_used=False, code=code
        )
        .order_by("-created_at")
        .first()
    )
    if challenge is None:
        return _error("Invalid or already used code.", status=401)
    if challenge.is_expired():
        return _error("This code has expired. Request a new one.", status=401)
    if channel == OtpChallenge.CHANNEL_PHONE and not challenge.contact_verified:
        return _error(
            "Share your Telegram contact from the same number first. "
            "Codes are only sent after that.",
            status=401,
        )
    challenge.is_used = True
    challenge.save(update_fields=["is_used"])
    if channel == OtpChallenge.CHANNEL_EMAIL:
        user = resolve_user(email=destination, provider="email")
    else:
        user = resolve_user(phone=destination, provider="phone")
    return _auth_response(user, request, payload, user.last_auth_provider)


@csrf_exempt
@require_POST
def google_auth(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    token = str(
        payload.get("id_token")
        or payload.get("idToken")
        or payload.get("credential")
        or ""
    ).strip()
    try:
        info = verify_google_id_token(token)
    except GoogleAuthError as exc:
        return _error(str(exc), status=401)
    email = info.get("email") if info.get("email_verified", True) else None
    user = resolve_user(
        email=email,
        google_sub=info.get("sub"),
        name=info.get("name") or "",
        photo_url=info.get("picture") or "",
        provider="google",
    )
    return _auth_response(user, request, payload, "google")


@csrf_exempt
@require_POST
def refresh_tokens(request):
    payload = _json_body(request)
    if payload is None:
        return _error("Invalid JSON body.")
    raw = str(payload.get("refresh") or payload.get("refresh_token") or "").strip()
    if not raw:
        return _error("Refresh token is required.", status=401)
    try:
        refresh = RefreshToken(raw)
        tokens = rotate_refresh(refresh, request)
    except (TokenError, ValueError):
        return _error("Refresh token is invalid or expired.", status=401)
    return JsonResponse(
        {
            "ok": True,
            "access": tokens["access"],
            "refresh": tokens["refresh"],
            "access_expires_in": tokens["access_expires_in"],
            "refresh_expires_in": tokens["refresh_expires_in"],
        }
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    return JsonResponse({"ok": True, "user": user_payload(request.user)})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def list_sessions(request):
    sessions = (
        AuthSession.objects.filter(user=request.user, is_active=True)
        .select_related("device")
        .order_by("-last_seen_at")
    )
    return JsonResponse(
        {
            "ok": True,
            "sessions": [session_payload(item) for item in sessions],
        }
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout(request):
    payload = _json_body(request) or {}
    session_id = request.auth.get("session_id") if request.auth else None
    raw_refresh = str(payload.get("refresh") or "").strip()
    if raw_refresh:
        try:
            refresh = RefreshToken(raw_refresh)
            session_id = refresh.get("session_id") or session_id
        except TokenError:
            pass
    AuthSession.objects.filter(
        user=request.user, pk=session_id, is_active=True
    ).update(is_active=False)
    return JsonResponse({"ok": True})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def revoke_session(request, session_id):
    updated = AuthSession.objects.filter(
        user=request.user, pk=session_id, is_active=True
    ).update(is_active=False)
    if not updated:
        return _error("Session not found.", status=404)
    return JsonResponse({"ok": True})


@require_GET
def telegram_redirect(request, session_id):
    challenge = OtpChallenge.objects.filter(session_id=session_id).first()
    if challenge is None:
        return render(
            request,
            "otp_auth/telegram_redirect.html",
            {"missing": True},
            status=404,
        )
    telegram_url = _telegram_url(challenge.session_id)
    show_code = settings.DEBUG and not settings.TELEGRAM_BOT_TOKEN
    return render(
        request,
        "otp_auth/telegram_redirect.html",
        {
            "missing": False,
            "expired": challenge.is_expired() or challenge.is_used,
            "telegram_url": telegram_url,
            "code": challenge.code if show_code else None,
            "phone": challenge.destination,
        },
    )
