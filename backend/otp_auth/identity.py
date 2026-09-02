from django.db import transaction
from django.db.models import Q

from .models import User


def _normalize_email(email):
    value = (email or "").strip().lower()
    return value or None


def _normalize_phone(phone):
    value = (phone or "").replace(" ", "")
    return value or None


@transaction.atomic
def resolve_user(
    *,
    email=None,
    phone=None,
    google_sub=None,
    name="",
    photo_url="",
    provider="",
):
    """
    Find one account by google_sub, email, or phone and fill missing identity
    fields. Never steal an email/phone that already belongs to another user.
    """
    email = _normalize_email(email)
    phone = _normalize_phone(phone)
    google_sub = (google_sub or "").strip() or None
    name = (name or "").strip()
    photo_url = (photo_url or "").strip()

    query = Q()
    if google_sub:
        query |= Q(google_sub=google_sub)
    if email:
        query |= Q(email__iexact=email)
    if phone:
        query |= Q(phone=phone)

    user = User.objects.filter(query).order_by("id").first() if query else None

    if user is None:
        return User.objects.create(
            email=email,
            phone=phone,
            google_sub=google_sub,
            name=name,
            photo_url=photo_url,
            last_auth_provider=provider,
        )

    updates = []
    if google_sub and not user.google_sub:
        taken = User.objects.filter(google_sub=google_sub).exclude(pk=user.pk).exists()
        if not taken:
            user.google_sub = google_sub
            updates.append("google_sub")
    if email and not user.email:
        taken = User.objects.filter(email__iexact=email).exclude(pk=user.pk).exists()
        if not taken:
            user.email = email
            updates.append("email")
    if phone and not user.phone:
        taken = User.objects.filter(phone=phone).exclude(pk=user.pk).exists()
        if not taken:
            user.phone = phone
            updates.append("phone")
    if name and not user.name:
        user.name = name
        updates.append("name")
    if photo_url and not user.photo_url:
        user.photo_url = photo_url
        updates.append("photo_url")
    if provider:
        user.last_auth_provider = provider
        updates.append("last_auth_provider")
    if updates:
        user.save(update_fields=updates)
    return user


def user_payload(user):
    return {
        "id": user.id,
        "name": user.name or user.email or user.phone,
        "email": user.email,
        "phone": user.phone,
        "photoUrl": user.photo_url or None,
        "provider": user.last_auth_provider or None,
    }
