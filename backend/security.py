from __future__ import annotations

import os
import time
from collections import defaultdict, deque
from typing import Callable

from fastapi import Request
from starlette.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response


DEFAULT_ALLOWED_ORIGINS = "http://127.0.0.1:8000,http://localhost:8000"
MAX_BODY_BYTES = int(os.environ.get("IR_MAX_BODY_BYTES", str(512 * 1024)))
AUTH_WINDOW_SECONDS = 60
AUTH_MAX_REQUESTS = 12


def allowed_origins() -> list[str]:
    configured = os.environ.get("IR_ALLOWED_ORIGINS", DEFAULT_ALLOWED_ORIGINS)
    return [origin.strip() for origin in configured.split(",") if origin.strip()]


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > MAX_BODY_BYTES:
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
            while attempts and now - attempts[0] > AUTH_WINDOW_SECONDS:
                attempts.popleft()
            if len(attempts) >= AUTH_MAX_REQUESTS:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many authentication attempts. Try again later."},
                )
            attempts.append(now)

        return await call_next(request)
