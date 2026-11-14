"""Combine Studio 256's Eclipse animation and the current game in one RAM load."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
STUDIO = ROOT / "assets/eclipse"
BUILD = ROOT / "build"
sys.path.insert(0, str(STUDIO / "tools"))
from fastpack import pack


def main():
    native = (BUILD / "battletanks-native.prg").read_bytes()
    assert native[:2] == b"\x01\x08"
    game_end = 0x801 + len(native) - 2
    packed = pack(native[2:])
    # The last part of the motion-table window is free until color data at $3800.
    motion = (STUDIO / "build/v1-motion.bin").read_bytes()
    motion_end = 0x2000 + len(motion)
    extra = 0x3800 - motion_end
    low_banks = ((0x4800,4096), (0x5a40,1472), (motion_end,extra), (0x0e00,512))
    low_size = sum(size for _,size in low_banks)
    if not 0 < extra or not low_size < len(packed) <= low_size+0xff00-0xa700:
        raise ValueError(f"Packed game exceeds the intro RAM layout: {len(packed)} bytes")
    kick = Path(os.environ["KICKASS_JAR"]).resolve()
    exo = "exomizer"
    with TemporaryDirectory(dir=BUILD) as tmp:
        work = Path(tmp)
        src, art, ref = (work / name for name in ("src", "build", "ref"))
        for folder in (src, art, ref):folder.mkdir()
        for name in ("intro.asm", "chainloader.asm"):
            shutil.copyfile(STUDIO / "src" / name, src / name)
        shutil.copyfile(ROOT / "src/studio256_handoff.asm", src / "resident_handoff.asm")
        shutil.copyfile(STUDIO / "ref/Nightshift.sid", ref / "Nightshift.sid")
        for name in ("motion", "stream"):
            shutil.copyfile(STUDIO / f"build/v1-{name}.bin", art / f"current-{name}.bin")
        shutil.copyfile(STUDIO / "build/stars.bin", art / "stars.bin")
        for name in ("screen", "color"):
            shutil.copyfile(STUDIO / f"art.{name}", art / f"art.{name}")
        banks=(*low_banks,(0xa700,len(packed)-low_size))
        targets=[];position=0
        for _,size in banks:
            targets.append(0x7000+position);position+=size
        def asm_list(name,values):
            return f".var {name}=List().add(" + ",".join(map(str,values)) + ")\n"
        (art / "config.asm").write_text(
            ".const total_frames=400\n.const game_mode=2\n.var game_file=\"\"\n"
            ".var game_caption=\"\"\n.const game_entry=$080d\n.const game_packed_address=$a700\n"
            f".const game_packed_size={len(packed)}\n.const game_end={game_end}\n" +
            asm_list("resident_from",(a for a,_ in banks)) + asm_list("resident_to",targets) +
            asm_list("resident_sizes",(n for _,n in banks)))
        intro = work / "intro.prg"
        java = "java"
        subprocess.run([java, "-jar", kick, src / "intro.asm", "-o", intro, "-symbolfile"], check=True,timeout=45)
        assert 0x801 + intro.stat().st_size - 2 <= 0xa700
        chunks = [];position=0
        for address,size in banks:
            part = work / f"bank-{address:x}.prg"
            part.write_bytes(struct.pack("<H", address) + packed[position:position+size])
            chunks.append(part);position+=size
        program = work / "battletanks.prg"
        subprocess.run([exo, "sfx", "2061", intro, *chunks, "-n", "-o", program], check=True)
        shutil.copyfile(src / "intro.sym", BUILD / "studio256.sym")
        program.replace(BUILD / program.name)
    print(f"Packed Eclipse and {len(packed)} bytes of resident game data.")


if __name__ == "__main__":
    main()
