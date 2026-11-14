from collections import defaultdict, deque
from pathlib import Path
import shutil
import subprocess

SRC = Path(__file__).resolve().parent
BASE = 0x0801

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


