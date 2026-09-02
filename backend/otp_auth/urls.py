from django.urls import path

from . import views

urlpatterns = [
    path("api/auth/email/request-otp/", views.request_email_otp),
    path("api/auth/email/verify-otp/", views.verify_email_otp),
    path("api/auth/phone/request-otp/", views.request_phone_otp),
    path("api/auth/phone/verify-otp/", views.verify_phone_otp),
    path("api/auth/google/", views.google_auth),
    path("api/auth/token/refresh/", views.refresh_tokens),
    path("api/auth/me/", views.me),
    path("api/auth/logout/", views.logout),
    path("api/auth/sessions/", views.list_sessions),
    path("api/auth/sessions/<int:session_id>/revoke/", views.revoke_session),
    path(
        "auth/telegram-redirect/<str:session_id>/",
        views.telegram_redirect,
        name="telegram-redirect",
    ),
]
