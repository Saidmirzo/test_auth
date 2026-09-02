from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.core.mail.backends.smtp import EmailBackend
from django.template.loader import render_to_string

from otp_auth.ssl_utils import ssl_context


class EmailSendError(Exception):
    pass


class EmailService:
    @staticmethod
    def is_configured() -> bool:
        return bool(settings.EMAIL_HOST_USER and settings.EMAIL_HOST_PASSWORD)

    @classmethod
    def send_otp(cls, email: str, code: str) -> None:
        if not cls.is_configured():
            raise EmailSendError(
                "Email service is not configured. Set EMAIL_HOST_USER and "
                "EMAIL_HOST_PASSWORD in backend/.env."
            )

        context = {
            "code": code,
            "minutes": settings.OTP_TTL_MINUTES,
        }
        text_body = (
            f"Your verification code is {code}. "
            f"It expires in {settings.OTP_TTL_MINUTES} minutes."
        )
        html_body = render_to_string("otp_auth/email_otp.html", context)
        message = EmailMultiAlternatives(
            subject="Your login code",
            body=text_body,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[email],
        )
        message.attach_alternative(html_body, "text/html")
        try:
            sent = cls._deliver(message, verify_ssl=True)
        except Exception as exc:
            if "CERTIFICATE_VERIFY_FAILED" not in str(exc):
                raise EmailSendError(f"Could not send email: {exc}") from exc
            try:
                sent = cls._deliver(message, verify_ssl=False)
            except Exception as retry_exc:
                raise EmailSendError(f"Could not send email: {retry_exc}") from retry_exc
        if not sent:
            raise EmailSendError("Email provider did not accept the message.")

    @staticmethod
    def _deliver(message: EmailMultiAlternatives, verify_ssl: bool) -> int:
        backend = EmailBackend(
            host=settings.EMAIL_HOST,
            port=settings.EMAIL_PORT,
            username=settings.EMAIL_HOST_USER,
            password=settings.EMAIL_HOST_PASSWORD,
            use_tls=settings.EMAIL_USE_TLS,
            use_ssl=settings.EMAIL_USE_SSL,
            timeout=settings.EMAIL_TIMEOUT,
            fail_silently=False,
        )
        backend.ssl_context = ssl_context(verify=verify_ssl)
        return backend.send_messages([message]) or 0
