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
    content = f"--- {name} ---\n".encode("ascii")
    content += b"\n\n\n\n\n"
    content += bytes([0x1D, 0x56, 0x00])  # Cut
    content += bytes(bytes_list)  # Pulse AFTER cut

    with open("test_pulse_after.bin", "wb") as f:
        f.write(content)

    os.system("lp -d 80mm-Series -o raw test_pulse_after.bin")
    time.sleep(3)


if has_printer():
    # 1. Standard Epson (Pin 2, m=0)
    check_command("Pin 2 After Cut", [0x1B, 0x70, 0x00, 0x32, 0xFA])

    # 2. Pin 5 (m=1)
    check_command("Pin 5 After Cut", [0x1B, 0x70, 0x01, 0x32, 0xFA])
