"""Split the linked image into startup parts and 21 demand-loaded arenas."""
import json
import struct
from pathlib import Path
from make_d64_multi import D64

ROOT=Path(__file__).resolve().parents[1]
FILES=ROOT/'build/files'


def symbols(name):
    result={}
    for line in (FILES/name).read_text().splitlines():
        _,address,label=line.split()
        result[label.lstrip('.')]=int(address.split(':')[1],16)
    return result


def main():
    labels=symbols('port.vs')
    program=(FILES/'gunmayhem.prg').read_bytes()
    base=int.from_bytes(program[:2],'little')
    def segment(filename,start,end):
        data=struct.pack('<H',start)+program[2+start-base:2+end-base]
        assert len(data)==end-start+2
        (FILES/filename).write_bytes(data)
    segment('logic.prg',0x080d,labels['logic_end'])
    segment('art.prg',0x2000,0x2f00)
    segment('match.prg',0x3000,labels['engine_end'])
    segment('menu-assets.prg',0xa000,labels['menu_assets_end'])
    loader=(FILES/'loader.prg').read_bytes()
    loader_base=int.from_bytes(loader[:2],'little')
    loader_labels=symbols('loader.vs')
    start=loader_labels['loader_image']-loader_base+2
    resident=loader[start:start+4096]
    assert len(resident)==4096
    (FILES/'resident.prg').write_bytes(struct.pack('<H',0x9000)+resident)
    contents=[('GUNMAYHEM','loader.prg'),('LOGIC','logic.prg'),('ART','art.prg'),('ENGINE','match.prg'),('MUSIC','menu-assets.prg')]
    contents += [(f'ARENA{i:02}',f'arena{i:02}.prg') for i in range(1,22)]
    disk=D64()
    manifest=[]
    for name,filename in contents:
        data=(FILES/filename).read_bytes()
        disk.write_file(name,data)
        manifest.append({'name':name,'file':filename,'bytes':len(data),'load_address':int.from_bytes(data[:2],'little')})
        print(f'{name:12} {len(data):5} bytes')
    disk.save(ROOT/'build/gunmayhem64.d64')
    (ROOT/'build/disk-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()
