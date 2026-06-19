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
prints directly through the Windows spooler on the POS machine. No local print
bridge is used on Windows. By default, the app sends the RAW ESC/POS ticket to
all connected real, non-virtual printers that Windows reports. To target only
specific cashier/kitchen printers, set a Windows environment variable on the POS
machine:

```sh
setx POS_PRINTER_NAMES "CashierPrinter,KitchenPrinter"
```

Restart the app after changing the variable. You can also bake both printer
names into the release at build time:

```sh
flutter build windows --release --dart-define=POS_PRINTER_NAMES=CashierPrinter,KitchenPrinter
```

If `POS_PRINTER_NAMES` is not provided, the app prints to all detected
thermal/ticket printers, and falls back to every real non-virtual Windows
printer if the printers have generic names. If only one printer should be used,
set `POS_PRINTER_NAMES` to that exact Windows printer name, then restart the app
or bake it into the build:

```sh
flutter build windows --release --dart-define=POS_PRINTER_NAMES=CashierPrinter
```

Cash drawer opening is sent through the printer using ESC/POS drawer-pulse
commands. The POS sends that pulse when the Cash Drawer button is used and at
the start of a paid cash receipt. Manual button openings send the hardware pulse
first, then save the log entry after the printer accepts the drawer job.
If the drawer cable plugs into the receipt printer and the printer is connected
to Windows by USB, leave `CASH_DRAWER_PRINTER_HOST` empty. The drawer pulse is
sent to the USB printer through the Windows RAW spooler, and the printer opens
the drawer through its drawer port. For Ethernet/Wi-Fi receipt printers only,
the Windows app can send cash receipts that include a drawer pulse, and manual
drawer pulses, directly to the printer's raw TCP port. If Windows installed an
Ethernet/Wi-Fi printer as a WSD port, set the cash drawer printer IP explicitly:

```sh
setx CASH_DRAWER_PRINTER_HOST 192.168.1.50
```

or bake it into the Windows build:

```sh
flutter build windows --release --dart-define=CASH_DRAWER_PRINTER_HOST=192.168.1.50
```

Physical key-open logging needs a drawer-status signal from the printer/drawer.
On Linux web testing, the bridge polls raw bidirectional printer devices such as
`/dev/usb/lp0` when the OS exposes them. On Windows, configure the status COM
port only if the printer exposes one:

```sh
setx CASH_DRAWER_STATUS_PORT COM3
```

or bake it into the Windows build:

```sh
flutter build windows --release --dart-define=CASH_DRAWER_STATUS_PORT=COM3
```

If the printer does not expose drawer status, printing and drawer opening still
work; only automatic physical-key-open logging remains unavailable.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
