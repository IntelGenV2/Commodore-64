"""Refresh the game on each disk, keeping the newest valid campaign on that disk."""
import os
from pathlib import Path
import subprocess
import sys
from tempfile import NamedTemporaryFile, TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
from resident import directory

PROGRAM = "AWESOME TANKS 2"
SLOTS = ("TANKS A", "TANKS B")


def valid_save(data):
    if len(data) < 6 or data[0] != 0xa2 or {1:19, 2:22, 3:47}.get(data[1]) != len(data):
        return False
    check = 0x73
    for byte in data[:-1]:
        check = ((check << 1 | check >> 7) & 255) ^ byte
    if check != data[-1] or data[4] > 1 or data[5] >= 15 or data[6] > 5:
        return False
    if data[1] < 3:
        return max(data[7:16]) <= 3 and (data[1] == 1 or (data[3] <= 1 and max(data[18:21]) <= 5))
    ranks = data[7:17]
    caps = (0,105,3000,236,105,1500,45,1500,105,20)
    return (data[3] <= 1 and ranks[0] <= 5 and max(ranks[1:]) <= 6 and
            all(int.from_bytes(data[21+2*i:23+2*i], "little") <= cap for i,cap in enumerate(caps)) and
            data[41] <= 2 and data[5] <= data[42] < 15 and max(data[43:46]) <= 5)


def newest(entries):
    present = [name for name in SLOTS if name in entries]
    valid = [name for name in present if valid_save(entries[name][0])]
    if present and not valid:
        raise ValueError("No readable campaign in the existing save files; disk left intact")
    if len(valid) < 2:
        return next(iter(valid), None)
    a,b = valid
    return b if 0 < (entries[b][0][2] - entries[a][0][2]) % 256 < 128 else a


def update(target, tool):
    if not target.parent.is_dir():
        raise OSError(f"Studio 256 disk folder is unavailable: {target.parent}")
    program = ROOT / "release/tanks.prg"
    def read_target():
        try:
            return target.read_bytes()
        except FileNotFoundError:
            return None

    original = read_target()
    before = directory(original) if original is not None else {}
    keep = newest(before)
    expected = {name:(entry[0],entry[1][0]) for name,entry in before.items()
                if name not in SLOTS or name == keep}
    expected[PROGRAM] = (program.read_bytes(), 0x82)

    def verify(image):
        entries = directory(image)
        return (next(iter(entries), None) == PROGRAM and
                {name:(entry[0],entry[1][0]) for name,entry in entries.items()} == expected)

    if original is None or not verify(original):
        with TemporaryDirectory(dir=ROOT / "build") as temp:
            stage = Path(temp) / "working.d64"
            if original is None:
                subprocess.run([tool,"-format","awesome tanks,at","d64",stage],check=True,capture_output=True)
            else:
                stage.write_bytes(original)
            command = [tool,"-attach",stage]
            for name in before:
                if name == PROGRAM or (name in SLOTS and name != keep):
                    command.extend(("-delete",name.lower()))
            command.extend(("-write",program,PROGRAM.lower()))
            subprocess.run(command,check=True,capture_output=True)
            updated = stage.read_bytes()
            if not verify(updated):
                raise ValueError("Staged disk failed program or save verification")
            pending = None
            try:
                with NamedTemporaryFile(dir=target.parent,prefix=".tanks-",suffix=".tmp",delete=False) as f:
                    pending = Path(f.name)
                    f.write(updated)
                    f.flush()
                    os.fsync(f.fileno())
                if pending.read_bytes() != updated or read_target() != original:
                    raise OSError("Disk changed during staging; retry with the disk idle")
                os.replace(pending,target)
            finally:
                if pending:
                    pending.unlink(missing_ok=True)
    if not verify(target.read_bytes()):
        raise OSError("Installed disk failed verification")
    detail = f"{keep}, save sequence {before[keep][0][2]}, sector {before[keep][0][5]+1}" if keep else "no campaign yet"
    print(f"Verified {target} ({detail})")


if __name__ == "__main__":
    update(ROOT / "release/tanks.d64", sys.argv[1])
