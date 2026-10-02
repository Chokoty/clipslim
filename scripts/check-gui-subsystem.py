#!/usr/bin/env python3

import pathlib
import struct
import sys

GUI = 2


def subsystem(path: pathlib.Path) -> int:
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise SystemExit(f"not a PE: {path}")
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew : e_lfanew + 4] != b"PE\0\0":
        raise SystemExit(f"not a PE: {path}")
    magic = struct.unpack_from("<H", data, e_lfanew + 24)[0]
    if magic not in (0x10B, 0x20B):
        raise SystemExit(f"unknown optional header magic {magic:#x}")
    return struct.unpack_from("<H", data, e_lfanew + 24 + 68)[0]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} clipslim.exe")
    path = pathlib.Path(sys.argv[1])
    value = subsystem(path)
    if value != GUI:
        raise SystemExit(f"console subsystem {value}, want {GUI} (WINDOWS_GUI)")
    print(f"ok gui subsystem {value} {path}")


if __name__ == "__main__":
    main()
