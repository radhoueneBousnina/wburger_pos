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
import select
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


def _cups_printer_devices() -> dict[str, str]:
    lpstat_path = shutil.which("lpstat")
    if not lpstat_path:
        return {}

    try:
        output = subprocess.check_output(
            [lpstat_path, "-v"],
            stderr=subprocess.STDOUT,
            timeout=4,
        ).decode(errors="ignore")
    except Exception:
        return {}

    printers: dict[str, str] = {}
    for line in output.splitlines():
        if "device for" not in line:
            continue
        raw = line.split("device for ", 1)[1]
        name, _, device_uri = raw.partition(":")
        name = name.strip()
        if name:
            printers[name] = device_uri.strip()
    return printers


def _is_virtual_printer(name: str, device_uri: str) -> bool:
    value = f"{name} {device_uri}".lower()
    return any(
        marker in value
        for marker in (
            "pdf",
            "xps",
            "fax",
            "onenote",
            "cups-pdf",
            "print-to-file",
            "file:/",
        )
    )


def _is_ticket_printer(name: str, device_uri: str) -> bool:
    value = f"{name} {device_uri}".lower()
    return any(
        marker in value
        for marker in (
            "80mm",
            "58mm",
            "thermal",
            "receipt",
            "escpos",
            "esc-pos",
            "esc_pos",
            "pos",
            "sprt",
            "xprinter",
            "xp-",
            "rongta",
            "rp-",
            "zjiang",
            "sunmi",
            "bixolon",
            "star",
            "citizen",
            "epson%20tm",
            "epson tm",
            "tm-t",
            "tm-u",
            "tsp",
            "ct-s",
            "usb",
            "ticket",
        )
    )


def _cups_ticket_printers() -> list[str]:
    devices = _cups_printer_devices()

    allowed = _configured_printers()
    if allowed:
        return sorted(allowed)

    real_printers = [
        name
        for name, device_uri in devices.items()
        if not _is_virtual_printer(name, device_uri)
    ]
    ticket_printers = [
        name
        for name in real_printers
        if _is_ticket_printer(name, devices.get(name, ""))
    ]
    if ticket_printers:
        return sorted(ticket_printers)
    return sorted(real_printers)


def _raw_printer_devices() -> list[str]:
    candidates: list[str] = []
    for directory, names in (
        ("/dev/usb", lambda value: value.startswith("lp")),
        ("/dev", lambda value: value.startswith("lp")),
    ):
        try:
            for name in os.listdir(directory):
                if names(name):
                    candidates.append(os.path.join(directory, name))
        except OSError:
            continue

    seen: set[str] = set()
    devices: list[str] = []
    for path in candidates:
        if path not in seen and os.path.exists(path):
            seen.add(path)
            devices.append(path)
    return sorted(devices)


def _query_status_byte(path: str, command: bytes, timeout: float = 0.35) -> int | None:
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    try:
        os.write(fd, command)
        ready, _, _ = select.select([fd], [], [], timeout)
        if not ready:
            return None
        data = os.read(fd, 1)
        if not data:
            return None
        return data[0]
    finally:
        os.close(fd)


def _bool_env(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _read_drawer_status() -> tuple[dict[str, Any], int]:
    devices = _raw_printer_devices()
    if not devices:
        return (
            {
                "status": "unsupported",
                "supported": False,
                "message": (
                    "Cash drawer status needs a bidirectional raw printer device "
                    "such as /dev/usb/lp0. None was available."
                ),
            },
            200,
        )

    errors: list[str] = []
    closed_payload: dict[str, Any] | None = None
    for device in devices:
        try:
            dle_eot_status = _query_status_byte(device, b"\x10\x04\x01")
            gs_r_status = None
            if dle_eot_status is None:
                gs_r_status = _query_status_byte(device, b"\x1d\x72\x02")
            if dle_eot_status is None and gs_r_status is None:
                raise RuntimeError("No drawer status byte returned.")

            pin3_high = (
                bool(dle_eot_status & 0x04)
                if dle_eot_status is not None
                else bool(gs_r_status & 0x01)
            )
            open_when_high = _bool_env("CASH_DRAWER_OPEN_WHEN_PIN3_HIGH", True)
            is_open = pin3_high if open_when_high else not pin3_high
            payload = {
                "status": "success",
                "supported": True,
                "is_open": is_open,
                "pin3_high": pin3_high,
                "source": device,
            }
            if is_open:
                return (payload, 200)
            if closed_payload is None:
                closed_payload = payload
        except Exception as exc:
            errors.append(f"{device}: {exc}")

    if closed_payload is not None:
        return (closed_payload, 200)

    return (
        {
            "status": "unsupported",
            "supported": False,
            "message": "Cash drawer status was not available from the connected printer.",
            "details": errors,
        },
        200,
    )


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
            printers = _cups_ticket_printers()
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

        payload, status = _read_drawer_status()
        self._send_json(payload, status=status)

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
        printers = [requested_printer] if requested_printer else _cups_ticket_printers()
        if not printers:
            self._send_json(
                {
                    "status": "error",
                    "message": (
                        "No thermal/ticket printer was detected by local CUPS. "
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
                    "status": "partial" if printed_count > 0 else "error",
                    "message": (
                        "Ticket queued on some local printers."
                        if printed_count > 0
                        else "Failed to print on local printers."
                    ),
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
        "[local-print-bridge] detected CUPS ticket printers: "
        f"{', '.join(_cups_ticket_printers()) or 'none'}"
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
