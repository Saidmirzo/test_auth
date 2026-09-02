import json
import random
import re
import secrets

from django.conf import settings
from django.http import JsonResponse
from django.shortcuts import render
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

from otp_auth.services.email_service import EmailSendError, EmailService

from .models import OtpChallenge

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
    return _verify(OtpChallenge.CHANNEL_EMAIL, email, code)


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
    return _verify(OtpChallenge.CHANNEL_PHONE, phone, code)


def _verify(channel, destination, code):
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
    challenge.is_used = True
    challenge.save(update_fields=["is_used"])
    if channel == OtpChallenge.CHANNEL_EMAIL:
        return JsonResponse({"ok": True, "email": destination, "name": destination})
    return JsonResponse({"ok": True, "phone": destination, "name": destination})


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
