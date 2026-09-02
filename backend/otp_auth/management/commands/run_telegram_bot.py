import json
import re
import time
import urllib.error
import urllib.request

from django.conf import settings
from django.core.management.base import BaseCommand

from otp_auth.models import OtpChallenge
from otp_auth.ssl_utils import ssl_context

SHARE_CONTACT_TEXT = "Share contact"


def normalize_phone(value):
    return re.sub(r"\D", "", value or "")


class Command(BaseCommand):
    help = "Long-poll Telegram and send OTP only after matching Share contact"

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
                    self._handle_message(update.get("message") or {})
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

    def _handle_message(self, message):
        chat = message.get("chat") or {}
        chat_id = chat.get("id")
        if not chat_id:
            return

        text = (message.get("text") or "").strip()
        contact = message.get("contact")

        if text.startswith("/start"):
            parts = text.split(maxsplit=1)
            session_id = parts[1].strip() if len(parts) > 1 else ""
            self._handle_start(chat_id, session_id)
            return

        if contact:
            self._handle_contact(chat_id, message, contact)
            return

        if self._looks_like_phone(text):
            self._ask_share_contact(
                chat_id,
                "Do not type a number. Use the Share contact button so I can "
                "confirm this Telegram account belongs to the phone entered in the app.",
            )
            return

        challenge = self._pending_challenge(chat_id)
        if challenge is None:
            self._send(
                chat_id,
                "Press Start from the Telegram account opened with the same "
                "phone number you entered in the app. I cannot send a code "
                "until you start the bot from that account.",
            )
            return

        self._ask_share_contact(
            chat_id,
            "Share the contact for this Telegram account to get your code. "
            "Typing another number will not work.",
        )

    def _handle_start(self, chat_id, session_id):
        if not session_id:
            self._send(
                chat_id,
                "Open the app, enter your phone, then Start this bot from the "
                "Telegram account that uses that exact number. I will not send "
                "a code until you do that and share your contact.",
            )
            return

        challenge = OtpChallenge.objects.filter(
            session_id=session_id,
            channel=OtpChallenge.CHANNEL_PHONE,
            is_used=False,
        ).first()
        if challenge is None:
            self._send(
                chat_id,
                "This session was not found or the code was already used. "
                "Request a new code in the app, then Start the bot from the "
                "Telegram account of that same number.",
            )
            return
        if challenge.is_expired():
            self._send(
                chat_id,
                "This request expired. Request a new one in the app, then "
                "Start the bot from the Telegram account of that number.",
            )
            return

        challenge.telegram_chat_id = str(chat_id)
        challenge.contact_verified = False
        challenge.save(update_fields=["telegram_chat_id", "contact_verified"])
        self._ask_share_contact(
            chat_id,
            "Confirm this Telegram account is opened with "
            f"{challenge.destination}.\n\n"
            "Tap Share contact below. If you type a different number, "
            "you will not get a code.",
        )

    def _handle_contact(self, chat_id, message, contact):
        sender_id = (message.get("from") or {}).get("id")
        contact_user_id = contact.get("user_id")
        if sender_id is None or contact_user_id != sender_id:
            self._ask_share_contact(
                chat_id,
                "Share YOUR Telegram contact with the button. "
                "Someone else's contact will not be accepted.",
            )
            return

        challenge = self._pending_challenge(chat_id)
        if challenge is None:
            self._send(
                chat_id,
                "Press Start first from the Telegram account of the number you "
                "entered in the app. I will not send a code until then.",
            )
            return
        if challenge.is_expired():
            self._send(
                chat_id,
                "This request expired. Request a new one in the app.",
            )
            return

        shared = normalize_phone(contact.get("phone_number"))
        expected = normalize_phone(challenge.destination)
        if not shared or shared != expected:
            self._ask_share_contact(
                chat_id,
                "This Telegram account is not opened with "
                f"{challenge.destination}.\n\n"
                "Start the bot from the account that uses that exact number. "
                "A different number will not receive a code.",
            )
            return

        challenge.contact_verified = True
        challenge.save(update_fields=["contact_verified"])
        self._api(
            "sendMessage",
            chat_id=chat_id,
            text=(
                f"Your verification code:\n\n{challenge.code}\n\n"
                "Return to the app and enter it. It expires in 5 minutes."
            ),
            reply_markup={"remove_keyboard": True},
        )

    def _pending_challenge(self, chat_id):
        return (
            OtpChallenge.objects.filter(
                telegram_chat_id=str(chat_id),
                channel=OtpChallenge.CHANNEL_PHONE,
                is_used=False,
            )
            .order_by("-created_at")
            .first()
        )

    def _looks_like_phone(self, text):
        digits = normalize_phone(text)
        return 7 <= len(digits) <= 15 and bool(re.search(r"\d", text or ""))

    def _ask_share_contact(self, chat_id, text):
        self._api(
            "sendMessage",
            chat_id=chat_id,
            text=text,
            reply_markup={
                "keyboard": [[{"text": SHARE_CONTACT_TEXT, "request_contact": True}]],
                "resize_keyboard": True,
                "one_time_keyboard": True,
            },
        )

    def _send(self, chat_id, text):
        self._api("sendMessage", chat_id=chat_id, text=text)
