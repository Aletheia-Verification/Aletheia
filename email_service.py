"""
email_service.py — Async Email Service for Aletheia Beyond
==========================================================

Provides:
    - SMTP-based email delivery with retry logic
    - Graceful degradation when SMTP is not configured
    - Registration and approval notification emails
    - Non-blocking: never fails registration if email fails

Configuration via environment variables:
    SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, EMAIL_FROM
"""

from __future__ import annotations

import asyncio
import logging
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

logger = logging.getLogger("aletheia-email")

# Graceful import — don't fail if aiosmtplib not installed
try:
    import aiosmtplib
    SMTP_AVAILABLE = True
except ImportError:
    SMTP_AVAILABLE = False
    logger.warning("aiosmtplib not installed — email service disabled")


# ──────────────────────────────────────────────────────────────────────
# EMAIL SERVICE
# ──────────────────────────────────────────────────────────────────────

class EmailService:
    """Async email service with retry logic and graceful fallback."""

    MAX_RETRIES = 3

    def __init__(self) -> None:
        self.smtp_host: str = os.getenv("SMTP_HOST", "smtp.gmail.com")
        self.smtp_port: int = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user: str = os.getenv("SMTP_USER", "")
        self.smtp_password: str = os.getenv("SMTP_PASSWORD", "")
        self.from_address: str = os.getenv(
            "EMAIL_FROM", "noreply@aletheia-beyond.com"
        )
        self.enabled: bool = bool(
            self.smtp_user and self.smtp_password and SMTP_AVAILABLE
        )

        if self.enabled:
            logger.info("Email service enabled (SMTP: %s)", self.smtp_host)
        else:
            logger.warning(
                "Email service disabled (SMTP not configured or "
                "aiosmtplib not installed)"
            )

    # ──────────────────────────────────────────────────────────────────
    # PUBLIC API
    # ──────────────────────────────────────────────────────────────────

    async def send_registration_email(
        self,
        to_email: str,
        username: str,
    ) -> bool:
        """
        Send registration confirmation email.

        Non-blocking: returns True even if email is disabled,
        so registration is never blocked by email failures.
        """
        if not self.enabled:
            logger.info(
                "Email skipped (disabled): registration for %s", username
            )
            return True

        subject = "Welcome to Aletheia Beyond"
        html_body = self._build_registration_html(username)
        return await self._send_with_retry(to_email, subject, html_body)

    async def send_approval_email(
        self,
        to_email: str,
        username: str,
    ) -> bool:
        """Send approval notification email."""
        if not self.enabled:
            return True

        subject = "Aletheia Beyond — Account Approved"
        html_body = self._build_approval_html(username)
        return await self._send_with_retry(to_email, subject, html_body)

    # ──────────────────────────────────────────────────────────────────
    # SEND WITH RETRY
    # ──────────────────────────────────────────────────────────────────

    async def _send_with_retry(
        self,
        to: str,
        subject: str,
        html_body: str,
    ) -> bool:
        """Send email with exponential backoff retry."""
        for attempt in range(self.MAX_RETRIES):
            try:
                msg = MIMEMultipart("alternative")
                msg["Subject"] = subject
                msg["From"] = f"Aletheia Beyond <{self.from_address}>"
                msg["To"] = to
                msg.attach(MIMEText(html_body, "html"))

                await aiosmtplib.send(
                    msg,
                    hostname=self.smtp_host,
                    port=self.smtp_port,
                    username=self.smtp_user,
                    password=self.smtp_password,
                    use_tls=True,
                )

                logger.info("Email sent to %s", to)
                return True

            except Exception as e:
                logger.warning(
                    "Email attempt %d/%d failed: %s",
                    attempt + 1,
                    self.MAX_RETRIES,
                    e,
                )
                if attempt < self.MAX_RETRIES - 1:
                    delay = 2 ** attempt  # 1s, 2s, 4s
                    await asyncio.sleep(delay)

        logger.error(
            "Email to %s permanently failed after %d attempts",
            to,
            self.MAX_RETRIES,
        )
        return False

    # ──────────────────────────────────────────────────────────────────
    # HTML TEMPLATES
    # ──────────────────────────────────────────────────────────────────

    @staticmethod
    def _build_registration_html(username: str) -> str:
        """Build HTML email for registration confirmation."""
        return f"""<!DOCTYPE html>
<html>
<head>
<style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
    .container {{ max-width: 600px; margin: 0 auto; padding: 40px 20px; }}
    .logo {{ font-size: 24px; font-weight: bold; color: #1a1a1a; letter-spacing: 0.1em; }}
    .content {{ margin-top: 30px; line-height: 1.6; color: #333; }}
    .highlight {{ background: #f5f5f5; padding: 20px; border-left: 3px solid #D4AF37; margin: 20px 0; }}
    .footer {{ margin-top: 40px; font-size: 12px; color: #888; border-top: 1px solid #eee; padding-top: 20px; }}
</style>
</head>
<body>
<div class="container">
    <div class="logo">ALETHEIA BEYOND</div>
    <div class="content">
        <p>Welcome, <strong>{username}</strong>.</p>
        <p>Your account has been created. An administrator will review
        and approve your institutional credentials.</p>
        <div class="highlight">
            <strong>Next Steps</strong><br>
            Wait for approval notification, then sign in to access
            the COBOL analysis engine.
        </div>
    </div>
    <div class="footer">
        Aletheia Beyond &mdash; Enterprise Modernization Platform<br>
        This is an automated message. Do not reply.
    </div>
</div>
</body>
</html>"""

    @staticmethod
    def _build_approval_html(username: str) -> str:
        """Build HTML email for approval notification."""
        return f"""<!DOCTYPE html>
<html>
<head>
<style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }}
    .container {{ max-width: 600px; margin: 0 auto; padding: 40px 20px; }}
    .logo {{ font-size: 24px; font-weight: bold; color: #1a1a1a; letter-spacing: 0.1em; }}
    .content {{ margin-top: 30px; line-height: 1.6; color: #333; }}
    .footer {{ margin-top: 40px; font-size: 12px; color: #888; border-top: 1px solid #eee; padding-top: 20px; }}
</style>
</head>
<body>
<div class="container">
    <div class="logo">ALETHEIA BEYOND</div>
    <div class="content">
        <p><strong>{username}</strong>, your account has been approved.</p>
        <p>You now have full access to:</p>
        <ul>
            <li>COBOL code analysis and logic extraction</li>
            <li>Python translation with semantic verification</li>
            <li>Behavioral drift auditing</li>
        </ul>
        <p>Sign in to begin.</p>
    </div>
    <div class="footer">
        Aletheia Beyond &mdash; Enterprise Modernization Platform<br>
        This is an automated message. Do not reply.
    </div>
</div>
</body>
</html>"""


# ──────────────────────────────────────────────────────────────────────
# SINGLETON
# ──────────────────────────────────────────────────────────────────────

email_service = EmailService()
