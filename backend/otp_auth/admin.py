from django.contrib import admin

from .models import OtpChallenge


@admin.register(OtpChallenge)
class OtpChallengeAdmin(admin.ModelAdmin):
    list_display = (
        "channel",
        "destination",
        "code",
        "contact_verified",
        "is_used",
        "created_at",
    )
    list_filter = ("channel", "is_used", "contact_verified")
    search_fields = ("destination", "session_id")
