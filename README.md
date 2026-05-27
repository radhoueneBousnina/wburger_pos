# wburger_pos

A new Flutter project.

## Running against the VPS

The POS API is served through `https://w-burger.com`.

For Flutter Web on a cashier machine with a USB thermal printer, keep the API
on the VPS and run the local hardware print bridge. The bridge only listens on
localhost and only forwards raw ESC/POS bytes to CUPS.
Confirmed POS orders print through this local bridge; the VPS is only used for
the order/payment API.

Use this command for web testing:

```sh
./scripts/run_pos_web_vps.sh
```

It starts the local print bridge and then runs Flutter Web on the localhost port
allowed by the VPS.

Equivalent manual commands:

```sh
python3 scripts/local_print_bridge.py
flutter run -d chrome --web-hostname localhost --web-port 3000 --dart-define=API_BASE_URL=https://w-burger.com --dart-define=PRINT_BRIDGE_BASE_URL=http://127.0.0.1:19100
```

The default web print bridge URL is `http://127.0.0.1:19100`. Override it only if
you run the bridge elsewhere:

```sh
PRINT_BRIDGE_BASE_URL=http://127.0.0.1:19101 PRINT_BRIDGE_PORT=19101 ./scripts/run_pos_web_vps.sh
```

For Flutter Web, use port `3000` unless the backend CORS settings are updated.
Other random Flutter web ports can be blocked by the browser and appear in the
app as "Unable to reach the server".

```sh
WEB_PORT=3000 ./scripts/run_pos_web_vps.sh
```

For the installed Windows build, the app defaults to `https://w-burger.com` and
prints through the Windows spooler on the POS machine. Set the USB receipt
printer as the Windows default printer, then build:

```sh
flutter build windows --release
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
