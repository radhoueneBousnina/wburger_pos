# wburger_pos

A new Flutter project.

## Running against the VPS

The POS API is served through `https://w-burger.com`.

For Flutter Web on a cashier machine with USB thermal printers, keep the API
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

To print the same ticket to a cashier printer and a kitchen printer during web
testing, configure both CUPS printer names before starting the bridge. The bridge
queues the same RAW ticket to both printers at the same time:

```sh
POS_PRINTER_NAMES="CashierPrinter,KitchenPrinter" ./scripts/run_pos_web_vps.sh
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
prints through the Windows spooler on the POS machine. To target both cashier
and kitchen printers, set a Windows environment variable on the POS machine:

```sh
setx POS_PRINTER_NAMES "CashierPrinter,KitchenPrinter"
```

Restart the app after changing the variable. You can also bake both printer
names into the release at build time:

```sh
flutter build windows --release --dart-define=POS_PRINTER_NAMES=CashierPrinter,KitchenPrinter
```

If `POS_PRINTER_NAMES` is not provided, the app prints to all detected thermal
ticket printers. If only one printer should be used, set it as the Windows
default printer, then build:

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
