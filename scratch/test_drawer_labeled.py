import shutil


def has_printer():
    return (
        shutil.which("lp") is not None
        and os.system("lpstat -p 80mm-Series > /dev/null 2>&1") == 0
    )


import os
import time


def check_command(name, bytes_list):
    print(f"Testing: {name}")
    content = f"--- TESTING {name} ---\n".encode("ascii")
    content += bytes(bytes_list)
    content += b"\n\n\n\n\n"
    content += bytes([0x1D, 0x56, 0x00])  # Cut

    with open("test_pulse_text.bin", "wb") as f:
        f.write(content)

    os.system("lp -d 80mm-Series -o raw test_pulse_text.bin")
    time.sleep(3)


if has_printer():
    # 1. Standard Epson (Pin 2, m=0)
    check_command("Epson Pin 2 (m=0)", [0x1B, 0x70, 0x00, 0x32, 0xFA])

    # 2. ASCII '0' (m=48)
    check_command("Epson Pin 2 (m='0')", [0x1B, 0x70, 0x30, 0x32, 0xFA])

    # 3. Standard Epson (Pin 5, m=1)
    check_command("Epson Pin 5 (m=1)", [0x1B, 0x70, 0x01, 0x32, 0xFA])

    # 4. FS g (Drawer pulse)
    check_command("FS g command", [0x1C, 0x67, 0x00])

    # 5. Some printers use ESC p m t1 (no t2)
    check_command("ESC p m t1", [0x1B, 0x70, 0x00, 0x32])
