"""Three-voice SID arrangements. Durations are in sixteenths; ~ carries a note."""
from pathlib import Path

NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
         "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
SPECIAL = {"-": 0, "~": None, "kick": 128, "rim": 129, "tom": 130, "snare": 131}
TEMPOS = (96, 164, 149)
IRQ_HZ = 50

def phase_increment(bpm):
    return round(bpm * 4 * 65536 / (60 * IRQ_HZ))

def loop_seconds(song, bpm):
    return len(song[0]) * 4 * 60 / bpm

# Two clipped B pickups open the E-minor hook. A sustained upper-register
# refrain gives the running bass room, then a four-bar break rebuilds it.
def battle_score():
    hook = [
        "B4:3 -:1 B4:2 D5:2 E5:3 -:1 G5:2 E5:2",
        "D5:2 B4:2 A4:3 G4:1 B4:4 -:2 E4:2",
        "B4:3 -:1 B4:2 D5:2 E5:3 G5:1 A5:2 G5:2",
        "F#5:4 D5:3 B4:1 A4:2 -:2 D5:4",
    ]
    answer = [
        "G5:4 E5:2 D5:2 C5:3 -:1 E5:4",
        "D5:3 B4:1 G4:2 A4:2 B4:4 D5:4",
        "C5:3 -:1 E5:2 G5:2 F#5:3 E5:1 D5:2 C5:2",
        "B4:6 -:2 F#4:2 A4:2 B4:2 D#5:2",
    ]
    refrain = [
        "E5:6 B4:2 G5:4 F#5:2 E5:2",
        "D5:4 A4:2 D5:2 F#5:6 -:2",
        "G5:6 E5:2 C5:3 D5:1 E5:4",
        "B4:4 D5:2 E5:2 G5:4 B4:4",
        "A5:4 G5:2 E5:2 C5:4 E5:4",
        "F#5:3 E5:1 D5:4 A4:2 D5:2 F#5:4",
        "G5:4 E5:2 B4:2 D5:4 G4:2 B4:2",
        "F#5:6 -:2 D#5:2 B4:2 A4:2 F#4:2",
    ]
    breakdown = [
        "E4:2 -:2 G4:2 A4:2 B4:4 -:4",
        "D5:2 -:2 B4:2 A4:2 G4:4 -:4",
        "A4:2 C5:2 E5:4 D5:2 C5:2 A4:4",
        "B4:2 D#5:2 F#5:4 -:2 B4:2 D#5:2 F#5:2",
    ]
    turnaround = [
        "G5:4 E5:2 D5:2 C5:4 E5:2 G5:2",
        "A5:3 G5:1 F#5:4 D5:4 A4:4",
        "B4:3 -:1 D5:2 E5:2 G5:3 F#5:1 E5:4",
        "D#5:4 B4:2 F#4:2 E4:4 -:2 G4:1 A4:1",
    ]
    melody = hook + answer + hook + turnaround + refrain + breakdown + hook[:2] + turnaround[2:]
    bass = {
        "e": "E2:2 E3:1 -:1 B2:2 E2:1 E3:2 -:1 D3:2 B2:2 G2:2",
        "g": "G2:2 G3:1 -:1 D3:2 G2:1 G3:2 -:1 B2:2 D3:2 F#2:2",
        "d": "D2:2 D3:1 -:1 A2:2 D2:1 D3:2 -:1 F#2:2 A2:2 D3:2",
        "c": "C2:2 C3:1 -:1 G2:2 C2:1 C3:2 -:1 E2:2 G2:2 B2:2",
        "a": "A2:2 E3:2 A2:1 -:1 C3:2 A2:2 E3:2 G2:2 A2:2",
        "b": "B1:2 B2:2 F#2:2 B1:2 B2:2 A2:2 F#2:2 D#2:2",
        "p": "E2:3 -:1 E2:2 B2:2 E3:3 -:1 D3:2 B2:2",
        "q": "G2:3 -:1 G2:2 D3:2 G3:3 -:1 D3:2 B2:2",
    }
    # The third oscillator plays chord stabs between the backbeats. An m or
    # M after a pitch selects a frame-arpeggiated minor or major triad.
    backing = {
        "e": "-:2 E3m:2 snare:3 -:1 E3m:2 -:2 snare:2 B3:2",
        "g": "-:2 G3M:2 snare:3 -:1 G3M:3 -:1 snare:4",
        "c": "C3M:3 -:1 snare:2 C3M:2 -:2 C3M:2 snare:4",
        "d": "-:2 D3M:2 snare:3 -:1 D3M:2 -:2 snare:2 A3:2",
        "a": "A3m:3 -:1 snare:2 A3m:2 -:2 E3:2 snare:4",
        "f": "B3M:3 -:1 snare:3 -:1 tom:2 snare:2 tom:2 snare:2",
        "k": "kick:4 snare:4 -:2 kick:2 snare:4",
        "t": "kick:4 snare:2 tom:2 -:2 tom:2 snare:2 tom:2",
    }
    return (melody, bass, "eged cgab eged cdeb edcg adeb pqab egeb",
            backing, "eged cgaf eged cdet edcg adef kkkt eget")

BATTLE = battle_score()

MENU = (
    [
        "B3:6 D4:2 F#4:6 -:2",
        "E4:4 D4:4 B3:6 -:2",
        "B3:6 D4:2 F#4:4 A4:4",
        "G4:6 F#4:2 D4:6 -:2",
        "E4:6 F#4:2 G4:6 -:2",
        "F#4:4 D4:4 B3:8",
        "C#4:6 E4:2 D4:4 C#4:4",
        "B3:12 -:4",
        "D4:4 F#4:4 B4:6 A4:2",
        "G4:8 D4:6 -:2",
        "E4:4 G4:4 A4:6 G4:2",
        "F#4:8 C#4:6 -:2",
        "B3:6 D4:2 F#4:6 -:2",
        "E4:4 D4:4 B3:6 -:2",
        "D4:4 E4:4 C#4:6 A#3:2",
        "B3:12 -:4",
    ],
    {
        "b": "B2:6 -:2 F#2:4 A2:2 A#2:2",
        "g": "G2:6 -:2 D3:4 A2:4",
        "e": "E2:6 -:2 B2:4 G2:4",
        "f": "F#2:6 -:2 C#3:4 F#2:4",
        "r": "B2:8 F#2:4 A2:2 A#2:2",
    }, "bgbg ebfr bgef bgfr",
    {
        "a": "-:8 D3:6 -:2",
        "b": "-:8 B3:4 A3:2 -:2",
        "c": "kick:8 G3:6 -:2",
        "d": "-:8 A#3:6 -:2",
        "e": "D3:8 -:4 F#3:4",
        "f": "kick:8 -:8",
    }, "abab cadf abcd aadf",
)

VICTORY = (
    [
        "B4:4 E5:6 D#5:2 B4:4",
        "C#5:6 B4:2 G#4:6 -:2",
        "A4:4 C#5:4 E5:6 F#5:2",
        "D#5:8 B4:6 -:2",
        "G#4:4 B4:4 E5:8",
        "C#5:4 A4:4 F#4:6 A4:2",
        "B4:4 D#5:4 F#5:4 D#5:4",
        "E5:12 -:4",
    ],
    {
        "e": "E2:6 B2:2 E3:8",
        "c": "C#2:6 G#2:2 C#3:8",
        "a": "A2:6 E3:2 A2:8",
        "b": "B2:6 F#2:2 B2:8",
        "r": "E2:12 -:4",
    }, "ecab eabr",
    {
        "e": "kick:8 G#3:8",
        "c": "-:4 E4:8 -:4",
        "a": "kick:8 A3:8",
        "b": "-:4 F#3:8 tom:4",
        "r": "G#3:12 -:4",
    }, "ecab eabr",
)

def encode_bar(bar):
    mask = 0
    events = []
    step = 0
    for token in bar.split():
        name, duration = token.split(":")
        if name in SPECIAL:
            event = SPECIAL[name]
        else:
            chord = name[-1] in ("m", "M")
            pitch = name[:-1] if chord else name
            midi = (int(pitch[-1]) + 1) * 12 + NAMES[pitch[:-1]]
            event = midi - 22   # B1 is 13; table begins at MIDI 23.
            assert 1 <= event <= 60, name
            if chord:
                assert event + 7 <= 60, name
                event |= 0x40 if name.endswith("m") else 0xc0
        if event is not None:
            mask |= 1 << step
            events.append(event)
        assert int(duration) > 0
        step += int(duration)
    assert step == 16, bar
    return bytes([mask & 255, mask >> 8, *events])

def write_score(out: Path):
    bars = {}
    orders = []
    for melody, bass, progression, third, groove in (MENU, BATTLE, VICTORY):
        progression = progression.replace(" ", "")
        groove = groove.replace(" ", "")
        assert len(melody) == len(progression) == len(groove)
        order = []
        for lead, root, beat in zip(melody, progression, groove):
            for part in (third[beat], bass[root], lead):
                data = encode_bar(part)
                order.append(bars.setdefault(data, len(bars)))
        orders.append(order)

    def db(label, values):
        return label + ": .byte " + ",".join(map(str, values))
    incs = [phase_increment(bpm) for bpm in TEMPOS]
    lines = [db("tempo_lo", (v & 255 for v in incs)), db("tempo_hi", (v >> 8 for v in incs)),
             db("order_len", map(len, orders))]
    for i, order in enumerate(orders):
        lines.append(db(f"order{i}", order))
    ptrs = ",".join(f"bar{i}" for i in range(len(bars)))
    lines += ["bar_lo: .lobytes " + ptrs, "bar_hi: .hibytes " + ptrs]
    for data, i in bars.items():
        lines.append(db(f"bar{i}", data))

    for name, clock in [("pal",985248),("ntsc",1022727)]:
        freqs = [round(440*2**((m-69)/12)*2**24/clock) for m in range(23,83)]
        lines.extend([db(name+"_lo", (v & 255 for v in freqs)),
                      db(name+"_hi", (v >> 8 for v in freqs))])
    (out / "score.inc").write_text("\n".join(lines) + "\n")
