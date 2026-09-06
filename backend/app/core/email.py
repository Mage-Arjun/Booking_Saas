from app.core.logging import logger


async def send_email(to: str, subject: str, body: str) -> None:
    """Stub email sending - logs intent, no actual SMTP."""
    logger.info("email.send_stub", to=to, subject=subject, body_preview=body[:100])


async def send_verification_email(email: str, token: str) -> None:
    await send_email(
        to=email,
        subject="Verify your email",
        body=f"Your verification token: {token}",
    )


async def send_password_reset_email(email: str, token: str) -> None:
    await send_email(
        to=email,
        subject="Password reset",
        body=f"Your reset token: {token}",
    )


async def send_org_invite_email(email: str, org_name: str, role: str) -> None:
    await send_email(
        to=email,
        subject=f"Invitation to join {org_name}",
        body=f"You have been invited to join {org_name} as {role}.",
    )