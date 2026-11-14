"""Reassemble the supplied Black Signal player in the game's free RAM bank."""
from pathlib import Path
import hashlib,json,subprocess,struct
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/menu/black'
OUT=ROOT/'build/menu-theme'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    subprocess.run(['ca65','-D','FILTER_BASE=100','player.s','-o',str(OUT/'black.o')],cwd=SOURCE,check=True)
    outputs={}
    for base in (0x1000,0xa000):
        cfg=OUT/f'black-{base:04x}.cfg'
        cfg.write_text(f'MEMORY {{ RAM: start=${base:04x}, size=$2000, file=%O; }}\nSEGMENTS {{ CODE: load=RAM, type=rw; }}\n')
        target=OUT/f'black-{base:04x}.bin'
        subprocess.run(['ld65','-C',str(cfg),str(OUT/'black.o'),'-o',str(target),'-Ln',str(OUT/f'black-{base:04x}.lbl')],check=True)
        outputs[base]=target.read_bytes()
    sid=(SOURCE/'BLACK.sid').read_bytes();offset=int.from_bytes(sid[6:8],'big')
    assert outputs[0x1000]==sid[offset:],'Source must reproduce the supplied SID exactly'
    assert len(outputs[0xa000])==len(outputs[0x1000]) and len(outputs[0xa000])<0x2000
    (ROOT/'build/files/menu-music.prg').write_bytes(struct.pack('<H',0xa000)+outputs[0xa000])
    (OUT/'build.json').write_text(json.dumps(dict(title='Black Signal',author='Original C64 Menu Sessions',source_sid_sha256=hashlib.sha256(sid).hexdigest(),source_reproduced_exactly=True,load_address=0xa000,init_address=0xa000,play_address=0xa003,stop_address=0xa006,bytes=len(outputs[0xa000]),tick_hz=100),indent=2))
    print('Black Signal: original reproduced exactly; relocated to $A000; 100 Hz CIA playback')

if __name__=='__main__':main()
