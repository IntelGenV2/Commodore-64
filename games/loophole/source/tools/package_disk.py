"""Update a staging copy of the 1541 disk, preserving player save files."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
RELEASE=ROOT/"release"
TRACKS=[21]*17+[19]*7+[18]*6+[17]*5

def chain(image, track, sector):
    seen=set()
    while track:
        if (track,sector) in seen or not 1<=track<=35 or sector>=TRACKS[track-1]:
            raise ValueError("Invalid disk sector chain")
        seen.add((track,sector))
        at=(sum(TRACKS[:track-1])+sector)*256
        block=image[at:at+256]
        yield block
        track,sector=block[0],block[1]

def files(path):
    image=path.read_bytes()
    result={}
    for block in chain(image,18,1):
        for at in range(0,256,32):
            if not block[at+2]&7:
                continue
            name=block[at+5:at+21].rstrip(b"\xa0").decode("latin1")
            data=bytearray()
            for part in chain(image,block[at+3],block[at+4]):
                data.extend(part[2:(part[1]+1 if part[0]==0 else 256)])
            result[name]=bytes(data)
    return result

def package(tool):
    disk=RELEASE/"loophole.d64"
    targets={"LOOPHOLE":RELEASE/"loophole.prg"}
    retired=("VICTORY.SID","WORLDS.SID")
    with tempfile.TemporaryDirectory(dir=ROOT/"build") as temp:
        stage=Path(temp)/disk.name
        if disk.exists():
            original=files(disk)
            shutil.copyfile(disk,stage)
        else:
            original={}
            subprocess.run([tool,"-format","loophole,lp","d64",str(stage)],check=True)
        command=[tool,"-attach",str(stage)]
        for name in (*targets,*retired):
            if name in original: command.extend(("-delete",name.lower()))
        for name,source in targets.items():
            command.extend(("-write",str(source),name.lower()))
        subprocess.run(command,check=True)
        expected={name:data for name,data in original.items() if name not in retired}
        expected.update({name:path.read_bytes() for name,path in targets.items()})
        actual=files(stage)
        if actual!=expected or next(iter(actual))!="LOOPHOLE":
            raise ValueError("Disk verification failed; the existing disk was preserved")
        os.replace(stage,disk)

if __name__=="__main__":
    package(sys.argv[1])
