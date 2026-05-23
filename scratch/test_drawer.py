import shutil


def has_printer():
    return (
        shutil.which("lp") is not None
        and os.system("lpstat -p 80mm-Series > /dev/null 2>&1") == 0
    )


import os


def check_pulse(pin_byte):
    # ESC p m t1 t2
    # m = pin_byte
    # t1 = 25 (50ms)
    # t2 = 250 (500ms)
    pulse = bytes([0x1B, 0x70, pin_byte, 0x19, 0xFA])

    with open("pulse.bin", "wb") as f:
        f.write(pulse)

    print(f"Testing pulse with pin byte: {hex(pin_byte)}")
    os.system("lp -d 80mm-Series -o raw pulse.bin")


if has_printer():
    print("Testing Drawer 1 (Pin 2) with 0x00")
    check_pulse(0x00)

    print("Testing Drawer 1 (Pin 2) with 0x30 ('0')")
    check_pulse(0x30)

    print("Testing Drawer 2 (Pin 5) with 0x01")
    check_pulse(0x01)

    print("Testing Drawer 2 (Pin 5) with 0x31 ('1')")
    check_pulse(0x31)
