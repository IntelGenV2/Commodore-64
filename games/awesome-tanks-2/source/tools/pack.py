"""Install banked arena and sprite data before cc65 clears its BSS."""
from pathlib import Path
from struct import pack

root = Path(__file__).resolve().parents[1]
build = root / "build"
labels = {s.split()[2]: int(s.split()[1],16) for s in
          (build/"tanks.lbl").read_text().splitlines() if s.startswith("al ")}
prg = bytearray((build/"runtime.prg").read_bytes())
load = int.from_bytes(prg[:2],"little")
entry = labels[".__MAIN_START__"]
offset = entry-load+2
original = prg[offset:offset+5]
assert original[:3] == bytes((0xa5,1,0x8d)), "unexpected startup prologue"
def append(data):
    addr = load+len(prg)-2
    prg.extend(data)
    return addr
maps = (build/"arenas.bin").read_bytes()
source = append(maps)
sprites = append((build/"sprites.bin").read_bytes())
# Disable interrupts, save the CPU port, and enable RAM beneath I/O.
stub = bytearray((0x08,0x78,0xa5,1,0x48,0xa9,0x34,0x85,1,0xa2,0))
# Copy a page per pair of indexed instructions in the shared X loop.
loop = len(stub)
for page in range(len(maps)//256):
    stub.extend(bytes([0xbd])+pack("<H", source+256*page))
    stub.extend(bytes([0x9d])+pack("<H", 0xd000+256*page))
stub.extend((0xe8,0xd0,(loop-len(stub)-3)&255))
tail = len(maps)%256
if tail:
    offset_in_bank = len(maps)-tail
    loop = len(stub)
    stub.extend(bytes([0xbd])+pack("<H",source+offset_in_bank))
    stub.extend(bytes([0x9d])+pack("<H",0xd000+offset_in_bank))
    stub.extend((0xe8,0xe0,tail,0xd0,(loop-len(stub)-5)&255))
stub.extend((0xa9,sprites&255,0x85,0xfb,0xa9,sprites>>8,0x85,0xfc,0x20))
stub.extend(pack("<H",labels["._inflate"]))
stub.extend((0x68,0x85,1,0x28))
stub.extend(original)
stub.extend(bytes([0x4c])+pack("<H",entry+5))
start = append(stub)
assert load+len(prg)-2 <= 0xd000, "boot image crosses hardware registers"
prg[offset:offset+3] = bytes([0x4c])+pack("<H",start)
(build/"native.prg").write_bytes(prg)
