from django.contrib import admin

from .models import AuthSession, Device, OtpChallenge, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "email",
        "phone",
        "name",
        "last_auth_provider",
        "is_active",
        "date_joined",
        "last_login",
    )
    search_fields = ("email", "phone", "name", "google_sub")
    list_filter = ("last_auth_provider", "is_active")


@admin.register(Device)
class DeviceAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "device_id",
        "name",
        "platform",
        "is_active",
        "last_seen_at",
    )
    list_filter = ("platform", "is_active")
    search_fields = ("device_id", "name", "user__email", "user__phone")


@admin.register(AuthSession)
class AuthSessionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "user",
        "device",
        "is_active",
        "ip_address",
        "created_at",
        "last_seen_at",
        "refresh_expires_at",
    )
    list_filter = ("is_active",)
    search_fields = ("refresh_jti", "user__email", "user__phone", "device__device_id")


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
