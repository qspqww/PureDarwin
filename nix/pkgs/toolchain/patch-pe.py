#!/usr/bin/env python3
"""Fix up the PE header of an objcopy-produced EFI image.

binutils >= 2.39 removed the efi-app-* BFD output targets, so the loader is
converted with -O pei-aarch64-little instead. That backend leaves several
OptionalHeader fields zeroed (Subsystem, alignments, SizeOfHeaders), which
EDK2's loader refuses ("Unsupported"). Fill them in the same way the efi-app
target used to: Subsystem 10 (EFI application), 4K section / 512 byte file
alignment, and a computed SizeOfHeaders/SizeOfImage/SizeOfCode.
"""
import struct
import sys


def main(path: str) -> None:
    with open(path, "rb") as f:
        d = bytearray(f.read())

    pe = struct.unpack("<I", d[0x3C:0x40])[0]
    assert d[pe:pe + 4] == b"PE\0\0", "not a PE image"
    nsec = struct.unpack("<H", d[pe + 6:pe + 8])[0]
    optsz = struct.unpack("<H", d[pe + 20:pe + 22])[0]
    opt = pe + 24
    assert struct.unpack("<H", d[opt:opt + 2])[0] == 0x20B, "not PE32+"

    sec = opt + optsz
    code = 0
    vaddr_end = 0
    raddr_end = 0
    for i in range(nsec):
        s = d[sec + i * 40:sec + (i + 1) * 40]
        chars = struct.unpack("<I", s[36:40])[0]
        vsize, vaddr, rsize, raddr = struct.unpack("<IIII", s[8:24])
        if chars & 0x20:  # IMAGE_SCN_CNT_CODE
            code += rsize
        vaddr_end = max(vaddr_end, vaddr + vsize)
        raddr_end = max(raddr_end, raddr + rsize)

    struct.pack_into("<H", d, opt + 68, 10)        # Subsystem = EFI application
    struct.pack_into("<I", d, opt + 32, 0x1000)    # SectionAlignment
    struct.pack_into("<I", d, opt + 36, 0x200)     # FileAlignment
    struct.pack_into("<I", d, opt + 4, code)       # SizeOfCode

    # Headers cover everything before the first section's raw data.
    first_raw = min(
        struct.unpack("<I", d[sec + i * 40 + 20:sec + i * 40 + 24])[0]
        for i in range(nsec)
        if struct.unpack("<I", d[sec + i * 40 + 16:sec + i * 40 + 20])[0]
    )
    size_of_headers = (first_raw + 0x1FF) & ~0x1FF
    struct.pack_into("<I", d, opt + 60, size_of_headers)  # SizeOfHeaders

    size_of_image = (max(vaddr_end, size_of_headers) + 0xFFF) & ~0xFFF
    struct.pack_into("<I", d, opt + 56, size_of_image)    # SizeOfImage

    with open(path, "wb") as f:
        f.write(d)
    print(
        f"patch-pe: subsystem=10 secalign=0x1000 filealign=0x200 "
        f"code={code} headers={size_of_headers} image=0x{size_of_image:x}"
    )


if __name__ == "__main__":
    main(sys.argv[1])
