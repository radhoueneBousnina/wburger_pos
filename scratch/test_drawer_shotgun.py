import shutil


def has_printer():
    return (
        shutil.which("lp") is not None
        and os.system("lpstat -p 80mm-Series > /dev/null 2>&1") == 0
    )


import os
import time


def check_command(name, bytes_list):
    print(f"Testing: {name} ({' '.join(hex(b) for b in bytes_list)})")
    with open("test_pulse.bin", "wb") as f:
        f.write(bytes(bytes_list))

    # Try sending via lp -o raw
    os.system("lp -d 80mm-Series -o raw test_pulse.bin")
    time.sleep(2)


if has_printer():
    # 1. Standard Epson (Pin 2, 100ms on, 500ms off)
    check_command("Epson Pin 2 (m=0)", [0x1B, 0x70, 0x00, 0x32, 0xFA])

    # 2. Standard Epson (Pin 5, 100ms on, 500ms off)
    check_command("Epson Pin 5 (m=1)", [0x1B, 0x70, 0x01, 0x32, 0xFA])

    # 3. ASCII '0' (m=48)
    check_command("Epson Pin 2 (m='0')", [0x1B, 0x70, 0x30, 0x32, 0xFA])

    # 4. ASCII '1' (m=49)
    check_command("Epson Pin 5 (m='1')", [0x1B, 0x70, 0x31, 0x32, 0xFA])

    # 5. BEL command (used by some old printers)
    check_command("BEL command", [0x07])

    # 6. Star Micronis variant
    check_command("Star pulse", [0x1B, 0x07, 0x0B, 0x32, 0x01])

    # 7. FS g (Drawer pulse on some Chinese printers)
    check_command("FS g command", [0x1C, 0x67, 0x00])

    # 8. Some printers need a reset BEFORE the pulse
    check_command("Reset + Pulse", [0x1B, 0x40, 0x1B, 0x70, 0x00, 0x32, 0xFA])
