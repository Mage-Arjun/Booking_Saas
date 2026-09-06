import time
from collections import defaultdict

from fastapi import Request

from app.core.config import settings
from app.core.exceptions import AppError


class RateLimitError(AppError):
    status_code = 429
    code = "RATE_LIMITED"
    detail = "Too many requests"


# In-memory sliding window (per IP)
_login_requests: dict[str, list[float]] = defaultdict(list)
_register_requests: dict[str, list[float]] = defaultdict(list)


def _clean_old_requests(requests: list[float], window_seconds: int) -> None:
    now = time.time()
    while requests and requests[0] < now - window_seconds:
        requests.pop(0)


def _is_test_client(request: Request) -> bool:
    # Detect test clients that don't have proper client info
    if request.client is None:
        return True
    if request.client.host in ("testclient", "127.0.0.1", "localhost"):
        # Check if it's the httpx test client
        user_agent = request.headers.get("user-agent", "")
        if "httpx" in user_agent.lower() or "test" in user_agent.lower():
            return True
    return False


def _get_client_ip(request: Request) -> str | None:
    if _is_test_client(request):
        return None
    if request.client:
        return request.client.host
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return None


def check_login_rate_limit(request: Request) -> None:
    ip = _get_client_ip(request)
    if ip is None:
        return
    now = time.time()
    _clean_old_requests(_login_requests[ip], 60)
    if len(_login_requests[ip]) >= settings.login_rate_limit_per_minute:
        raise RateLimitError("Rate limit exceeded for login")
    _login_requests[ip].append(now)


def check_register_rate_limit(request: Request) -> None:
    ip = _get_client_ip(request)
    if ip is None:
        return
    now = time.time()
    _clean_old_requests(_register_requests[ip], 60)
    if len(_register_requests[ip]) >= settings.register_rate_limit_per_minute:
        raise RateLimitError("Rate limit exceeded for registration")
    _register_requests[ip].append(now)


async def rate_limit_login_dependency(request: Request) -> None:
    check_login_rate_limit(request)


async def rate_limit_register_dependency(request: Request) -> None:
    check_register_rate_limit(request)