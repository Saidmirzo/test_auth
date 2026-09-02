from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone


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
