from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone


class User(models.Model):
    email = models.EmailField(unique=True, null=True, blank=True)
    phone = models.CharField(max_length=32, unique=True, null=True, blank=True)
    google_sub = models.CharField(max_length=64, unique=True, null=True, blank=True)
    name = models.CharField(max_length=255, blank=True)
    photo_url = models.TextField(blank=True)
    last_auth_provider = models.CharField(max_length=32, blank=True)
    is_active = models.BooleanField(default=True)
    date_joined = models.DateTimeField(auto_now_add=True)
    last_login = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["email"]),
            models.Index(fields=["phone"]),
        ]

    @property
    def is_authenticated(self):
        return True

    @property
    def is_anonymous(self):
        return False

    def __str__(self):
        return self.email or self.phone or f"user-{self.pk}"


class Device(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="devices")
    device_id = models.CharField(max_length=64)
    name = models.CharField(max_length=255, blank=True)
    platform = models.CharField(max_length=32, blank=True)
    os_version = models.CharField(max_length=64, blank=True)
    app_version = models.CharField(max_length=64, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user", "device_id"], name="uniq_user_device_id"
            )
        ]

    def __str__(self):
        return f"{self.user_id}:{self.device_id}"


class AuthSession(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sessions")
    device = models.ForeignKey(
        Device, on_delete=models.CASCADE, related_name="sessions"
    )
    refresh_jti = models.CharField(max_length=64, unique=True)
    refresh_expires_at = models.DateTimeField()
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user", "is_active"]),
            models.Index(fields=["refresh_jti"]),
        ]

    def is_expired(self):
        return timezone.now() >= self.refresh_expires_at

    def __str__(self):
        return f"session {self.pk} user={self.user_id}"


class OtpChallenge(models.Model):
    CHANNEL_EMAIL = "email"
    CHANNEL_PHONE = "phone"
    CHANNEL_CHOICES = (
        (CHANNEL_EMAIL, "Email"),
        (CHANNEL_PHONE, "Phone"),
    )

    channel = models.CharField(max_length=16, choices=CHANNEL_CHOICES)
    destination = models.CharField(max_length=255)
    code = models.CharField(max_length=6)
    session_id = models.CharField(max_length=64, unique=True)
    telegram_chat_id = models.CharField(max_length=64, blank=True)
    contact_verified = models.BooleanField(default=False)
    is_used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["destination", "channel", "is_used"]),
        ]

    def is_expired(self):
        ttl = timedelta(minutes=settings.OTP_TTL_MINUTES)
        return timezone.now() > self.created_at + ttl

    def __str__(self):
        return f"{self.channel}:{self.destination} ({self.session_id[:8]})"
