from collections import defaultdict, deque
from pathlib import Path
import shutil
import subprocess

SRC = Path(__file__).resolve().parent
BASE = 0x0801

TRACK_SIZES = [0] + [21] * 17 + [19] * 7 + [18] * 6 + [17] * 5

def directory(disk):
    def block(track, sector):
        assert 1 <= track <= 35 and sector < TRACK_SIZES[track]
        start = (sum(TRACK_SIZES[:track]) + sector) * 256
        return disk[start:start + 256]

    track, sector = 18, 1
    files = {}
    used = {(18, 0)}
    while track:
        assert (track, sector) not in used
        used.add((track, sector))
        page = block(track, sector)
        for offset in range(0, 256, 32):
            entry = page[offset + 2:offset + 32]
            if not entry[0]:
                continue
            name = entry[3:19].rstrip(b"\xa0").decode("ascii")
            t, s = entry[1:3]
            chunks = []
            chain = []
            while t:
                assert (t, s) not in used
                chain.append((t, s))
                used.add((t, s))
                data = block(t, s)
                t, s = data[:2]
                chunks.append(data[2:256 if t else s + 1])
            assert len(chain) == int.from_bytes(entry[28:30], "little")
            files[name] = (b"".join(chunks), entry, chain)
        track, sector = page[:2]
    return files


def pack(data, compact=False):
    """Literal runs and overlapping back references as read by resident-game.asm."""
    positions = defaultdict(lambda: deque(maxlen=96))
    # Keep the best preceding match at every position. A shorter match can
    # lead into a much longer one, so choose the cheapest token path below.
    size = len(data)
    longest = bytearray(size)
    distances = [0] * size
    for pos in range(size):
        key = data[pos:pos + 3]
        limit = min(130, size - pos)
        if len(key) == 3:
            for earlier in reversed(positions[key]):
                length = 3
                while length < limit and data[earlier + length] == data[pos + length]:
                    length += 1
                if length > longest[pos]:
                    longest[pos], distances[pos] = length, pos - earlier
                if length == limit:
                    break
        positions[key].append(pos)

    tokens = [0] * size
    if compact:
        costs = [0] * (size + 1)
        for pos in range(size - 1, -1, -1):
            best, token = 2 * size + 1, 0
            for n in range(1, min(127, size-pos) + 1):
                cost = 1 + n + costs[pos+n]
                if cost < best:
                    best, token = cost, n
            for n in range(3, longest[pos] + 1):
                cost = 3 + costs[pos+n]
                if cost < best:
                    best, token = cost, -n
            costs[pos], tokens[pos] = best, token

    else:
        # Preserve the smaller games' original streams and literal runs.
        pos = 0
        while pos < size:
            if longest[pos] >= 4:
                tokens[pos] = -longest[pos]
            else:
                end = pos + 1
                while end < size and end-pos < 127 and longest[end] < 4:
                    end += 1
                tokens[pos] = end-pos
            pos += abs(tokens[pos])

    result = bytearray()
    pos = 0
    while pos < size:
        token = tokens[pos]
        if token > 0:
            result.append(token)
            result.extend(data[pos:pos+token])
        else:
            result.append(0x80 | (-token-3))
            result.extend(distances[pos].to_bytes(2, "little"))
        pos += abs(token)
    result.append(0)
    return bytes(result)


def verify_expansion(memory, source, expected):
    # Model both expansions in the same RAM, including overlap with the source.
    dest = BASE
    while token := memory[source]:
        source += 1
        if token & 128:
            count = (token & 127) + 3
            read = dest - int.from_bytes(memory[source:source + 2], "little")
            source += 2
        else:
            count, read = token, source
            source += count
        for offset in range(count):
            memory[dest + offset] = memory[read + offset]
        dest += count
    assert dest == BASE + len(expected) and memory[BASE:dest] == expected


def tanks_inner(game, compressed):
    """Reuse the native game's verified SFX stream and animate its second pass."""
    from py65.devices.mpu6502 import MPU
    data = bytearray(compressed.read_bytes())
    # $36 leaves RAM at $a000 and colour RAM visible. The decruncher and
    # the entire native game are below $d000. Restore the normal map on exit.
    replacements = [
        ("a0 21 78 e6 01 ba", "a0 21 78 c6 01 ba"),
        ("ce 1a 01 ce 19 01 ad", "20 a7 02 ce 19 01 ad"),
        ("c6 01 58 4c 0d 08", "e6 01 58 4c aa 02"),
    ]
    for before, after in replacements:
        pattern = bytes.fromhex(before)
        if data.count(pattern) != 1:
            raise ValueError("Unrecognised native Tanks decruncher")
        data = data.replace(pattern, bytes.fromhex(after))
    cpu = MPU(pc=0x080d)
    cpu.memory[BASE:BASE + len(data) - 2] = data[2:]
    cpu.sp = 0xf5
    cpu.memory[1] = 0x37
    # Model the two public hooks. The real loader also updates the glyph.
    cpu.memory[0x02a7:0x02aa] = bytes.fromhex("4c b0 02")
    cpu.memory[0x02b0:0x02b4] = bytes.fromhex("ce 1a 01 60")
    for _ in range(5_000_000):
        if cpu.pc == 0x02aa:
            break
        cpu.step()
    else:
        raise ValueError("Native Tanks decrunch did not finish")
    if bytes(cpu.memory[BASE:BASE + len(game) - 2]) != game[2:] or cpu.memory[1] != 0x37:
        raise ValueError("Native Tanks stream does not match the current game")
    return bytes(data)


def resident(intro, game, work, java, jar, inner_game=False):
    film, native = intro[2:], game[2:]
    a, b = pack(film, compact=inner_game), pack(native, compact=inner_game)
    # The aligned stream starts at $0a00. Choose shorter game tokens when
    # the combined PRG would otherwise LOAD into the C64 I/O window.
    if not inner_game and len(a) + len(b) > 0xd000 - 0x0a00:
        b = pack(native, compact=True)
    pages = (len(a) + len(b) + 255) // 256
    game_source = 0xff00 - len(b)
    intro_source = game_source - len(a)
    assert game_source >= BASE + len(film), "Resident game overlaps the film"
    streams = (a + b).rjust(pages * 256, b"\0")
    ram = bytearray(65536)
    ram[0xff00-len(streams):0xff00] = streams
    verify_expansion(ram, intro_source, film)
    verify_expansion(ram, game_source, native)
    (work / "streams.bin").write_bytes(streams)
    (work / "layout.asm").write_text(
        f".const pages={pages}\n.const introSource={intro_source}\n.const gameSource={game_source}\n"
        f".const innerGame={'true' if inner_game else 'false'}\n")
    shutil.copyfile(SRC / "resident-game.asm", work / "resident-game.asm")
    shutil.copyfile(SRC / "loading-colors.asm", work / "loading-colors.asm")
    subprocess.run([java, "-jar", jar, "resident-game.asm", "-o", "combined.prg"],
                   cwd=work, check=True, stdout=subprocess.PIPE)
    combined = (work / "combined.prg").read_bytes()
    if BASE + len(combined) - 2 > 0xd000:
        raise ValueError("Initial LOAD would write into the C64 I/O window")
    return combined


