#!/usr/bin/env python3
"""Tiny local print bridge for Flutter Web POS testing.

The POS API can stay on the VPS. This process only exposes localhost endpoints
that send raw ESC/POS bytes to the USB printer configured in CUPS.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 19100
PRINT_PATH = "/api/v1/sales/print-proxy/"
DRAWER_STATUS_PATH = "/api/v1/sales/drawer-status-proxy/"
HEALTH_PATHS = {"/", "/health", "/healthz"}


def _run(command: list[str], timeout: int = 8) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=timeout,
    )


def _configured_printers() -> set[str]:
    raw_values = [
        os.environ.get("POS_PRINTER_NAME", ""),
        os.environ.get("POS_PRINTER_NAMES", ""),
        os.environ.get("RAW_PRINT_ALLOWED_PRINTERS", ""),
    ]
    return {
        value.strip()
        for raw_value in raw_values
        for value in raw_value.split(",")
        if value.strip()
    }


def _usb_cups_printers() -> list[str]:
    lpstat_path = shutil.which("lpstat")
    if not lpstat_path:
        return []

    try:
        output = subprocess.check_output(
            [lpstat_path, "-v"],
            stderr=subprocess.STDOUT,
            timeout=4,
        ).decode(errors="ignore")
    except Exception:
        return []

    printers: list[str] = []
    for line in output.splitlines():
        if "device for" not in line or "usb://" not in line:
            continue
        name = line.split("device for ", 1)[1].split(":", 1)[0].strip()
        if name:
            printers.append(name)

    allowed = _configured_printers()
    if allowed:
        printers = [printer for printer in printers if printer in allowed]
    return printers


def _print_raw_bytes(
    *,
    printer: str,
    job_name: str,
    raw_bytes: bytes,
) -> subprocess.CompletedProcess[bytes]:
    lp_path = shutil.which("lp")
    if not lp_path:
        return subprocess.CompletedProcess(
            ["lp"],
            127,
            b"",
            b"The lp command was not found. Install/configure CUPS.",
        )

    with tempfile.NamedTemporaryFile(
        prefix="wburger-ticket-",
        suffix=".bin",
        delete=False,
    ) as payload_file:
        payload_file.write(raw_bytes)
        payload_path = payload_file.name

    try:
        return _run(
            [
                lp_path,
                "-d",
                printer,
                "-o",
                "raw",
                "-o",
                "document-format=application/vnd.cups-raw",
                "-o",
                "job-sheets=none,none",
                "-t",
                job_name[:80] or "W Burger Ticket",
                payload_path,
            ]
        )
    finally:
        try:
            os.unlink(payload_path)
        except OSError:
            pass


def _error_text(completed: subprocess.CompletedProcess[bytes]) -> str:
    stderr = completed.stderr.decode(errors="ignore").strip()
    if stderr:
        return stderr
    stdout = completed.stdout.decode(errors="ignore").strip()
    if stdout:
        return stdout
    return f"lp exited with code {completed.returncode}"


class PrintBridgeHandler(BaseHTTPRequestHandler):
    server_version = "WBurgerLocalPrintBridge/1.0"

    def do_OPTIONS(self) -> None:
        self._send_empty(204)

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path in HEALTH_PATHS:
            printers = _usb_cups_printers()
            self._send_json(
                {
                    "status": "success",
                    "message": "W Burger local print bridge is running.",
                    "detected_printers": printers,
                    "printer_count": len(printers),
                }
            )
            return

        if path != DRAWER_STATUS_PATH:
            self._send_json({"detail": "Not found"}, status=404)
            return

        self._send_json(
            {
                "status": "unsupported",
                "supported": False,
                "message": "Cash drawer status is not available from the local print bridge.",
            }
        )

    def do_POST(self) -> None:
        if self.path.split("?", 1)[0] != PRINT_PATH:
            self._send_json({"detail": "Not found"}, status=404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception as exc:
            self._send_json(
                {
                    "status": "error",
                    "message": f"Invalid JSON payload: {exc}",
                }
            )
            return

        self._handle_print(payload)

    def _handle_print(self, payload: dict[str, Any]) -> None:
        base64_bytes = payload.get("bytes")
        if not base64_bytes:
            self._send_json({"status": "error", "message": "No bytes provided."})
            return

        try:
            raw_bytes = base64.b64decode(base64_bytes)
        except Exception as exc:
            self._send_json(
                {
                    "status": "error",
                    "message": f"Invalid print payload: {exc}",
                }
            )
            return

        requested_printer = str(payload.get("printer") or "").strip()
        printers = [requested_printer] if requested_printer else _usb_cups_printers()
        if not printers:
            self._send_json(
                {
                    "status": "error",
                    "message": (
                        "No USB thermal printer was detected by local CUPS. "
                        "Check lpstat -v and set POS_PRINTER_NAME=80mm-Series if needed."
                    ),
                }
            )
            return

        job_name = str(payload.get("job_name") or "W Burger Ticket").strip()
        errors: list[str] = []
        with ThreadPoolExecutor(max_workers=max(1, len(printers))) as executor:
            futures = {
                executor.submit(
                    _print_raw_bytes,
                    printer=printer,
                    job_name=job_name,
                    raw_bytes=raw_bytes,
                ): printer
                for printer in printers
            }
            for future in as_completed(futures):
                printer = futures[future]
                try:
                    completed = future.result()
                except Exception as exc:
                    errors.append(f"{printer}: {exc}")
                    continue

                if completed.returncode != 0:
                    errors.append(f"{printer}: {_error_text(completed)}")

        printed_count = len(printers) - len(errors)

        if errors:
            self._send_json(
                {
                    "status": "error",
                    "message": "Failed to print on some local printers.",
                    "details": errors,
                    "detected_printers": printers,
                    "printer_count": len(printers),
                    "printed_count": printed_count,
                }
            )
            return

        self._send_json(
            {
                "status": "success",
                "message": f"Ticket queued on {printed_count} local printer(s).",
                "detected_printers": printers,
                "printer_count": len(printers),
                "printed_count": printed_count,
            }
        )

    def _send_empty(self, status: int) -> None:
        self.send_response(status)
        self._send_cors_headers()
        self.end_headers()

    def _send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header(
            "Access-Control-Allow-Headers",
            "authorization, content-type, x-requested-with",
        )
        self.send_header("Access-Control-Max-Age", "86400")

    def log_message(self, format: str, *args: Any) -> None:
        if self.path.split("?", 1)[0] == DRAWER_STATUS_PATH:
            return
        print(f"[local-print-bridge] {self.address_string()} - {format % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="W Burger local USB print bridge")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), PrintBridgeHandler)
    print(
        f"[local-print-bridge] listening on http://{args.host}:{args.port} "
        f"for {PRINT_PATH}"
    )
    print(
        "[local-print-bridge] detected USB CUPS printers: "
        f"{', '.join(_usb_cups_printers()) or 'none'}"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
