#!/usr/bin/env python3
"""Write a multi-file C64 D64 image."""
from __future__ import annotations

import sys
from pathlib import Path

TRACK_SECTORS = [0] + [21] * 17 + [19] * 7 + [18] * 6 + [17] * 5


def track_offset(track: int) -> int:
    return sum(TRACK_SECTORS[t] * 256 for t in range(1, track))


class D64:
    def __init__(self, name: bytes = b"GUN MAYHEM 64"):
        self.data = bytearray(174848)
        bam = track_offset(18)
        self.bam = bam
        self.data[bam + 0] = 18
        self.data[bam + 1] = 1
        self.data[bam + 2] = 0x41
        for t in range(1, 36):
            entry = bam + 4 + (t - 1) * 4
            sectors = TRACK_SECTORS[t]
            bits = (1 << sectors) - 1
            self.data[entry] = sectors
            self.data[entry + 1] = bits & 0xFF
            self.data[entry + 2] = (bits >> 8) & 0xFF
            self.data[entry + 3] = (bits >> 16) & 0xFF
        # Reserve the BAM and first directory sector; extend the chain as needed.
        for s in range(0, 2):
            self._mark_used(18, s)
        nm = name[:16]
        self.data[bam + 0x90 : bam + 0x90 + len(nm)] = nm
        for i in range(len(nm), 16):
            self.data[bam + 0x90 + i] = 0xA0
        self.data[bam + 0xA0 : bam + 0xAB] = b"\xa0\xa064\xa02A\xa0\xa0\xa0\xa0"
        self.dir_sector = 1
        self.dir_index = 0  # entry slot 0..7

    def _mark_used(self, track: int, sector: int) -> None:
        entry = self.bam + 4 + (track - 1) * 4
        bits = self.data[entry + 1] | (self.data[entry + 2] << 8) | (self.data[entry + 3] << 16)
        if bits & (1 << sector):
            bits &= ~(1 << sector)
            self.data[entry] -= 1
            self.data[entry + 1] = bits & 0xFF
            self.data[entry + 2] = (bits >> 8) & 0xFF
            self.data[entry + 3] = (bits >> 16) & 0xFF

    def alloc(self) -> tuple[int, int]:
        for track in list(range(1, 18)) + list(range(19, 36)):
            entry = self.bam + 4 + (track - 1) * 4
            if self.data[entry] == 0:
                continue
            bits = self.data[entry + 1] | (self.data[entry + 2] << 8) | (self.data[entry + 3] << 16)
            for s in range(TRACK_SECTORS[track]):
                if bits & (1 << s):
                    self._mark_used(track, s)
                    return track, s
        raise RuntimeError("Disk full")

    def write_file(self, name: str, payload: bytes, file_type: int = 0x82) -> None:
        """payload includes 2-byte load address for PRG."""
        chain: list[tuple[int, int]] = []
        remaining = payload
        while remaining:
            t, s = self.alloc()
            chain.append((t, s))
            off = track_offset(t) + s * 256
            chunk = remaining[:254]
            remaining = remaining[254:]
            self.data[off + 2 : off + 2 + len(chunk)] = chunk
            if not remaining:
                self.data[off + 0] = 0
                self.data[off + 1] = len(chunk) + 1
        for i, (t, s) in enumerate(chain[:-1]):
            off = track_offset(t) + s * 256
            nt, ns = chain[i + 1]
            self.data[off] = nt
            self.data[off + 1] = ns

        # directory entry
        if self.dir_index >= 8:
            # allocate new dir sector
            # link previous
            prev = track_offset(18) + self.dir_sector * 256
            found = None
            entry = self.bam + 4 + (18 - 1) * 4
            bits = self.data[entry + 1] | (self.data[entry + 2] << 8) | (self.data[entry + 3] << 16)
            for s in range(TRACK_SECTORS[18]):
                if bits & (1 << s):
                    found = s
                    break
            if found is None:
                raise RuntimeError("Dir full")
            self._mark_used(18, found)
            self.data[prev] = 18
            self.data[prev + 1] = found
            self.dir_sector = found
            self.dir_index = 0
            dirt = track_offset(18) + found * 256
            self.data[dirt] = 0
            self.data[dirt + 1] = 0xFF

        dirt = track_offset(18) + self.dir_sector * 256
        if self.dir_index == 0 and self.dir_sector == 1:
            self.data[dirt] = 0
            self.data[dirt + 1] = 0xFF
        slot = 2 + self.dir_index * 32
        self.data[dirt + slot] = file_type
        self.data[dirt + slot + 1] = chain[0][0]
        self.data[dirt + slot + 2] = chain[0][1]
        raw = name.upper().encode("ascii")[:16]
        self.data[dirt + slot + 3 : dirt + slot + 3 + len(raw)] = raw
        for i in range(len(raw), 16):
            self.data[dirt + slot + 3 + i] = 0xA0
        blocks = len(chain)
        self.data[dirt + slot + 0x1C] = blocks & 0xFF
        self.data[dirt + slot + 0x1D] = (blocks >> 8) & 0xFF
        self.dir_index += 1

    def save(self, path: Path) -> None:
        path.write_bytes(self.data)


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: make_d64_multi.py out.d64 name=file.prg ...")
        sys.exit(1)
    out = Path(sys.argv[1])
    d = D64()
    for arg in sys.argv[2:]:
        name, path = arg.split("=", 1)
        data = Path(path).read_bytes()
        d.write_file(name, data)
        print(f"  + {name} ({len(data)} bytes)")
    d.save(out)
    print("Wrote", out, "size", out.stat().st_size)


if __name__ == "__main__":
    main()
