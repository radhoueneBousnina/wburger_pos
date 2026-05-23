import shutil


def has_printer():
    return (
        shutil.which("lp") is not None
        and os.system("lpstat -p 80mm-Series > /dev/null 2>&1") == 0
    )


import os
import time


def check_command(name, bytes_list):
    print(f"Testing SPRT: {name}")
    content = f"--- SPRT {name} ---\n".encode("ascii")
    content += bytes(bytes_list)
    content += b"\n\n\n\n\n"
    content += bytes([0x1D, 0x56, 0x00])  # Cut

    with open("test_sprt.bin", "wb") as f:
        f.write(content)

    os.system("lp -d 80mm-Series -o raw test_sprt.bin")
    time.sleep(5)


if has_printer():
    # 1. SPRT Manual suggests m=0, t1=40, t2=80 (hex 0x28, 0x50)
    check_command("m=0, 40, 80", [0x1B, 0x70, 0x00, 0x28, 0x50])

    # 2. SPRT Manual suggests m=48 ('0'), t1=40, t2=80
    check_command("m='0', 40, 80", [0x1B, 0x70, 0x30, 0x28, 0x50])

    # 3. High power pulse (100ms on, 500ms off)
    check_command("High Power", [0x1B, 0x70, 0x00, 0x32, 0xFA])

    # 4. Repeated pulse
    check_command("Triple Pulse", [0x1B, 0x70, 0x00, 0x19, 0xFA] * 3)

    # 5. DLE DC4 m t n (Real-time pulse) - used by some SPRT models
    # m=1, t=1, n=2 (Drawer 1, pulse duration 2*2ms, but actually t and n are usually small)
    check_command("Real-time Pulse", [0x10, 0x14, 0x01, 0x00, 0x05])
