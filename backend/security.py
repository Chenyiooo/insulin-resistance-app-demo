from __future__ import annotations

import time
from collections import defaultdict, deque
from typing import Callable

from fastapi import Request
from starlette.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from backend.config import settings


def allowed_origins() -> list[str]:
    return list(settings.allowed_origins)


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > settings.max_body_bytes:
            return JSONResponse(status_code=413, content={"detail": "Request body too large."})

        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        response.headers["Cache-Control"] = "no-store"
        return response


class InMemoryAuthRateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        self._attempts: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if request.url.path in {"/auth/login", "/auth/register"}:
            client = request.client.host if request.client else "unknown"
            key = f"{client}:{request.url.path}"
            now = time.time()
            attempts = self._attempts[key]
            while attempts and now - attempts[0] > settings.auth_window_seconds:
                attempts.popleft()
            if len(attempts) >= settings.auth_max_requests:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many authentication attempts. Try again later."},
                )
            attempts.append(now)

        return await call_next(request)
