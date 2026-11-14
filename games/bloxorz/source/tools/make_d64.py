#!/usr/bin/env python3
"""Minimal D64 image writer — single PRG as first file."""
from __future__ import annotations

import sys
from pathlib import Path

# 35 tracks, standard 174848 bytes
TRACK_SECTORS = [
    0,
    21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
    19, 19, 19, 19, 19, 19, 19,
    18, 18, 18, 18, 18, 18,
    17, 17, 17, 17, 17,
]


def track_offset(track: int) -> int:
    off = 0
    for t in range(1, track):
        off += TRACK_SECTORS[t] * 256
    return off


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: make_d64.py input.prg output.d64")
        sys.exit(1)
    prg = Path(sys.argv[1]).read_bytes()
    d64 = bytearray(174848)

    # BAM track 18 sector 0
    bam = track_offset(18)
    d64[bam + 0] = 18  # dir track
    d64[bam + 1] = 1   # dir sector
    d64[bam + 2] = 0x41  # DOS type 'A'
    # free sector counts — mark used as we go; start all free then allocate
    for t in range(1, 36):
        entry = bam + 4 + (t - 1) * 4
        sectors = TRACK_SECTORS[t]
        d64[entry] = sectors
        # bitmask of free sectors
        bits = (1 << sectors) - 1
        d64[entry + 1] = bits & 0xFF
        d64[entry + 2] = (bits >> 8) & 0xFF
        d64[entry + 3] = (bits >> 16) & 0xFF

    disk_name = b"STUDIO256 BLOXORZ"
    d64[bam + 0x90 : bam + 0x90 + len(disk_name)] = disk_name
    for i in range(len(disk_name), 16):
        d64[bam + 0x90 + i] = 0xA0
    d64[bam + 0xA0] = 0xA0
    d64[bam + 0xA1] = 0xA0
    d64[bam + 0xA2] = ord("6")
    d64[bam + 0xA3] = ord("4")
    d64[bam + 0xA4] = 0xA0
    d64[bam + 0xA5] = ord('2')
    d64[bam + 0xA6] = ord('A')
    d64[bam + 0xA7 : bam + 0xAB] = bytes([0xA0])*4

    def alloc_sector(track: int) -> int | None:
        entry = bam + 4 + (track - 1) * 4
        free = d64[entry]
        if free == 0:
            return None
        bits = d64[entry + 1] | (d64[entry + 2] << 8) | (d64[entry + 3] << 16)
        for s in range(TRACK_SECTORS[track]):
            if bits & (1 << s):
                bits &= ~(1 << s)
                d64[entry] = free - 1
                d64[entry + 1] = bits & 0xFF
                d64[entry + 2] = (bits >> 8) & 0xFF
                d64[entry + 3] = (bits >> 16) & 0xFF
                return s
        return None

    # write file data starting track 17
    remaining = prg
    chain: list[tuple[int, int]] = []
    track = 17
    while remaining:
        while track <= 35 and d64[bam + 4 + (track - 1) * 4] == 0:
            track += 1
        if track == 18:
            track = 19
        if track > 35:
            raise SystemExit("Disk full")
        sec = alloc_sector(track)
        if sec is None:
            track += 1
            continue
        chain.append((track, sec))
        off = track_offset(track) + sec * 256
        chunk = remaining[:254]
        remaining = remaining[254:]
        d64[off + 2 : off + 2 + len(chunk)] = chunk
        if not remaining:
            d64[off + 0] = 0
            d64[off + 1] = len(chunk) + 1  # last used byte index
        # link filled later

    for i, (t, s) in enumerate(chain[:-1]):
        off = track_offset(t) + s * 256
        nt, ns = chain[i + 1]
        d64[off + 0] = nt
        d64[off + 1] = ns

    # directory entry track 18 sector 1
    dirt = track_offset(18) + 1 * 256
    d64[dirt + 0] = 0
    d64[dirt + 1] = 0xFF
    d64[dirt + 2] = 0x82  # PRG
    d64[dirt + 3] = chain[0][0]
    d64[dirt + 4] = chain[0][1]
    name = b"BLOXORZ64"
    d64[dirt + 5 : dirt + 5 + len(name)] = name
    for i in range(len(name), 16):
        d64[dirt + 5 + i] = 0xA0
    blocks = len(chain)
    d64[dirt + 0x1E] = blocks & 0xFF
    d64[dirt + 0x1F] = (blocks >> 8) & 0xFF

    # mark BAM track 18 sectors used for BAM+dir
    for s in (0, 1):
        entry = bam + 4 + (18 - 1) * 4
        bits = d64[entry + 1] | (d64[entry + 2] << 8) | (d64[entry + 3] << 16)
        if bits & (1 << s):
            bits &= ~(1 << s)
            d64[entry] -= 1
            d64[entry + 1] = bits & 0xFF
            d64[entry + 2] = (bits >> 8) & 0xFF
            d64[entry + 3] = (bits >> 16) & 0xFF

    Path(sys.argv[2]).write_bytes(d64)
    print(f"Wrote {sys.argv[2]} ({blocks} blocks, {len(prg)} byte PRG)")


if __name__ == "__main__":
    main()

