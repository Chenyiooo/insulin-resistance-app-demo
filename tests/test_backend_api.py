import importlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

import pytest


def test_api_handlers_confirmed_health_checkin_roundtrip():
    with tempfile.TemporaryDirectory() as tmpdir:
        previous_db_path = os.environ.get("IR_APP_DB_PATH")
        os.environ["IR_APP_DB_PATH"] = os.path.join(tmpdir, "handler-test.db")
        try:
            from backend import main

            app_module = importlib.reload(main)
            ready = app_module.ready()
            assert ready["status"] == "ready"

            auth = app_module.register(
                app_module.AuthRequest(
                    email="handler@example.com",
                    password="password123",
                    name="Handler Tester",
                )
            )
            current = app_module.require_user(f"Bearer {auth['token']}")

            checkin = app_module.save_my_checkin(
                app_module.CheckInRequest(
                    checkin_date="2026-08-18",
                    source="apple_health_confirmed",
                    provenance={
                        "source": "apple_health",
                        "confirmation": "user_confirmed",
                        "imported_fields": "sleep_hours,physical_activity",
                    },
                    data={
                        "sleepHours": "7",
                        "activityPerformed": "Yes",
                    },
                ),
                current=current,
            )
            assert checkin["source"] == "apple_health_confirmed"
            assert checkin["provenance"]["confirmation"] == "user_confirmed"

            exported = app_module.export_my_data(current=current)
            assert exported["checkins"][0]["source"] == "apple_health_confirmed"
            assert exported["audit_events"]
        finally:
            if previous_db_path is None:
                os.environ.pop("IR_APP_DB_PATH", None)
            else:
                os.environ["IR_APP_DB_PATH"] = previous_db_path


def test_api_ready_and_confirmed_health_checkin_roundtrip():
    with tempfile.TemporaryDirectory() as tmpdir:
        try:
            port = _free_port()
        except PermissionError:
            pytest.skip("Current sandbox does not allow binding a local test port.")
        base_url = f"http://127.0.0.1:{port}"
        env = os.environ.copy()
        env["IR_APP_DB_PATH"] = os.path.join(tmpdir, "api-test.db")

        process = subprocess.Popen(
            [
                sys.executable,
                "-m",
                "uvicorn",
                "backend.main:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(port),
                "--log-level",
                "warning",
            ],
            cwd=os.getcwd(),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            ready = _wait_for_json(f"{base_url}/ready", process)
            assert ready["status"] == "ready"

            register = _request_json(
                f"{base_url}/auth/register",
                {
                    "email": "api@example.com",
                    "password": "password123",
                    "name": "API Tester",
                },
            )
            token = register["token"]

            checkin = _request_json(
                f"{base_url}/me/checkins",
                {
                    "checkin_date": "2026-08-18",
                    "source": "apple_health_confirmed",
                    "provenance": {
                        "source": "apple_health",
                        "confirmation": "user_confirmed",
                        "imported_fields": "sleep_hours,physical_activity",
                    },
                    "data": {
                        "sleepHours": "7",
                        "activityPerformed": "Yes",
                    },
                },
                token=token,
            )
            assert checkin["source"] == "apple_health_confirmed"
            assert checkin["provenance"]["confirmation"] == "user_confirmed"

            exported = _request_json(f"{base_url}/me/export", token=token)
            assert exported["checkins"][0]["source"] == "apple_health_confirmed"
            assert exported["audit_events"]
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def _wait_for_json(url: str, process: subprocess.Popen, timeout: float = 10.0) -> dict:
    deadline = time.time() + timeout
    last_error: Exception | None = None
    while time.time() < deadline:
        if process.poll() is not None:
            _, stderr = process.communicate(timeout=1)
            raise AssertionError(f"API server exited early: {stderr}")
        try:
            return _request_json(url)
        except (urllib.error.URLError, json.JSONDecodeError) as exc:
            last_error = exc
            time.sleep(0.2)
    raise AssertionError(f"API server did not become ready: {last_error}")


def _request_json(url: str, payload: dict | None = None, token: str | None = None) -> dict:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))
