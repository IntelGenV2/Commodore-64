"""Build native multicolor turret poses. One art pixel is two VIC pixels wide."""
from math import cos, floor, sin, tau


# East-facing blueprints. The centre of the bearing is between columns 5 and 6.
# Dots are transparent, # is black, o is the tank's ink and + is silver.
HEADS = (
    ("Minigun", (
        "....###.....",
        "...#oo+#....",
        "...#o+oo+o+#",
        "...#ooo#+#++",
        "....###.....",
    )),
    ("Shotgun", (
        "...######+..",
        "...#oo+++++.",
        "...#oo#.....",
        "...#oo+++++.",
        "...######+..",
    )),
    ("Ricochet", (
        ".....####...",
        "....#o++o#..",
        "...#o+##+o+#",
        "....#o++o#..",
        ".....####...",
    )),
    ("Flame", (
        "...#+#...#+.",
        "...#o##.#o+.",
        "...#oo+++o+#",
        "...#o##.#o+.",
        "...#+#...#+.",
    )),
    ("Cannon", (
        "....###..###",
        "...#ooo##o++",
        "...#o++++oo+",
        "...#ooo##oo#",
        "....###..###",
    )),
    ("Shock", (
        ".....##..++.",
        "....#o+#+...",
        "...#o++.....",
        "....#o+#+...",
        ".....##..++.",
    )),
    ("Rockets", (
        "...#oooo+#..",
        "...#++++oo+.",
        "....###.....",
        "...#++++oo+.",
        "...#oooo+#..",
    )),
    ("Laser", (
        ".....+#.....",
        "....#o+#....",
        "...#++o+++++",
        "....#oo#....",
        ".....+#.....",
    )),
    ("Railgun", (
        "...###......",
        "...#o+++++++",
        "....#o#.....",
        "...#o+++++++",
        "...###......",
    )),
    ("Rammer", (
        "......+#....",
        "....#oo+#...",
        "...#oooo+#..",
        "....#oo+#...",
        "......+#....",
    )),
)


def pose_rows(art, heading):
    angle = tau * heading / 32
    c, s = cos(angle), sin(angle)
    rows = []
    for y in range(11):
        pixels = []
        for x in range(12):
            dx, dy = x - 5.5, y - 5
            sx = floor(6 + c * dx + s * dy + 1e-8)
            sy = floor(2.5 - s * dx + c * dy + 1e-8)
            pixels.append(".#o+".index(art[sy][sx]) if 0 <= sy < 5 and 0 <= sx < 12 else 0)
        rows.append(bytes(sum(pixels[col + i] << (6 - 2*i) for i in range(4))
                          for col in (0, 4, 8)))
    return rows


def sprite_pixels(gun, heading):
    """Expected 24 x 21 multicolor sprite bytes, including quadrant reflections."""
    quadrant, step = divmod(heading, 8)
    rows = pose_rows(HEADS[gun][1], 8-step if quadrant & 1 else step)
    if quadrant >= 2:
        rows.reverse()
    if quadrant in (1, 2):
        def flip(byte):
            return sum(((byte >> (2*i)) & 3) << (6-2*i) for i in range(4))
        rows = [bytes(flip(byte) for byte in reversed(row)) for row in rows]
    return b"".join(row * 2 for row in rows)[:63]


def turret_atlas(start):
    """Store nine headings per gun. The VIC renderer reflects the other quadrants."""
    payload = bytearray()
    tables = {name: [] for name in ("head_maps", "head_left", "head_mid", "head_right")}
    for group in (HEADS[:6], HEADS[6:]):
        poses = [[row for h in range(9) for row in pose_rows(art, h)] for _, art in group]
        unique = list(dict.fromkeys(row for pose in poses for row in pose))
        assert len(unique) <= 256
        for column, name in enumerate(("head_left", "head_mid", "head_right")):
            tables[name].append(start + len(payload))
            payload.extend(row[column] for row in unique)
        for pose in poses:
            tables["head_maps"].append(start + len(payload))
            payload.extend(unique.index(row) for row in pose)
    asm = []
    for name, pointers in tables.items():
        for suffix, shift in (("lo", 0), ("hi", 8)):
            asm.append(f"{name}_{suffix}: .byte " +
                       ",".join(f"${(address >> shift) & 255:02x}" for address in pointers))
    return payload, "\n".join(asm) + "\n"
