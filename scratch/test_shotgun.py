import shutil


def has_printer():
    return (
        shutil.which("lp") is not None
        and os.system("lpstat -p 80mm-Series > /dev/null 2>&1") == 0
    )


import os


def check_shotgun():
    print("Testing SHOTGUN Pulse")
    # Exact sequence from my new code
    shotgun = [
        0x1B,
        0x40,  # Initialize
        0x1B,
        0x70,
        0x00,
        0x19,
        0xFA,  # Pin 2 (0)
        0x1B,
        0x70,
        0x01,
        0x19,
        0xFA,  # Pin 5 (1)
        0x1B,
        0x70,
        0x30,
        0x19,
        0xFA,  # Pin 2 ('0')
        0x1B,
        0x70,
        0x31,
        0x19,
        0xFA,  # Pin 5 ('1')
    ]

    with open("test_shotgun.bin", "wb") as f:
        f.write(bytes(shotgun))

    os.system("lp -d 80mm-Series -o raw test_shotgun.bin")


if has_printer():
    check_shotgun()
