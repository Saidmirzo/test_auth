import json
import time
import urllib.error
import urllib.request

from django.conf import settings
from django.core.management.base import BaseCommand

from otp_auth.models import OtpChallenge
from otp_auth.ssl_utils import ssl_context


class Command(BaseCommand):
    help = "Long-poll Telegram and send OTP codes for /start SESSION_ID"

    def handle(self, *args, **options):
        token = settings.TELEGRAM_BOT_TOKEN
        if not token:
            self.stderr.write("Set TELEGRAM_BOT_TOKEN before running the bot.")
            return

        self._ssl_context = ssl_context(settings.TELEGRAM_SSL_VERIFY)
        if not settings.TELEGRAM_SSL_VERIFY:
            self.stderr.write("Telegram SSL verification is disabled.")

        offset = 0
        self.stdout.write("Telegram OTP bot is polling…")
        while True:
            try:
                payload = self._api("getUpdates", offset=offset, timeout=30)
                for update in payload.get("result", []):
                    offset = update["update_id"] + 1
                    message = update.get("message") or {}
                    text = message.get("text") or ""
                    chat = message.get("chat") or {}
                    chat_id = chat.get("id")
                    if chat_id and text.startswith("/start"):
                        parts = text.split(maxsplit=1)
                        session_id = parts[1].strip() if len(parts) > 1 else ""
                        self._send_otp(chat_id, session_id)
            except Exception as exc:
                self.stderr.write(str(exc))
                time.sleep(3)

    def _api(self, method, **params):
        url = f"https://api.telegram.org/bot{settings.TELEGRAM_BOT_TOKEN}/{method}"
        request = urllib.request.Request(
            url,
            data=json.dumps(params).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        try:
            return self._read(request)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Telegram API {exc.code}: {body}") from exc
        except urllib.error.URLError as exc:
            reason = str(getattr(exc, "reason", exc))
            if "CERTIFICATE_VERIFY_FAILED" not in reason:
                raise
            self.stderr.write(
                "Telegram SSL verify failed (self-signed cert in chain). "
                "Continuing without verification for local development."
            )
            self._ssl_context = ssl_context(verify=False)
            return self._read(request)

    def _read(self, request):
        with urllib.request.urlopen(
            request, timeout=35, context=self._ssl_context
        ) as response:
            return json.loads(response.read().decode("utf-8"))

    def _send_otp(self, chat_id, session_id):
        if not session_id:
            self._api(
                "sendMessage",
                chat_id=chat_id,
                text="Open the app, request a phone code, then tap the Telegram redirect again.",
            )
            return
        challenge = OtpChallenge.objects.filter(
            session_id=session_id, is_used=False
        ).first()
        if challenge is None:
            self._api(
                "sendMessage",
                chat_id=chat_id,
                text="This session was not found or the code was already used.",
            )
            return
        if challenge.is_expired():
            self._api(
                "sendMessage",
                chat_id=chat_id,
                text="This code expired. Request a new one in the app.",
            )
            return
        challenge.telegram_chat_id = str(chat_id)
        challenge.save(update_fields=["telegram_chat_id"])
        self._api(
            "sendMessage",
            chat_id=chat_id,
            text=(
                f"Your verification code:\n\n{challenge.code}\n\n"
                "Return to the app and enter it. It expires in 5 minutes."
            ),
        )
