from django.urls import path

from . import views

urlpatterns = [
    path("api/auth/email/request-otp/", views.request_email_otp),
    path("api/auth/email/verify-otp/", views.verify_email_otp),
    path("api/auth/phone/request-otp/", views.request_phone_otp),
    path("api/auth/phone/verify-otp/", views.verify_phone_otp),
    path(
        "auth/telegram-redirect/<str:session_id>/",
        views.telegram_redirect,
        name="telegram-redirect",
    ),
]
