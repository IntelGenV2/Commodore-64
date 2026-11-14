"""Small forward LZ format with cheap whole-byte tokens for a 6510 decoder."""
from collections import defaultdict,deque

def pack(data):
    history=defaultdict(lambda:deque(maxlen=256));out=bytearray();literal=bytearray();i=0
    while i<len(data):
        best=0;offset=0
        for p in reversed(history[data[i:i+3]]):
            n=0
            while n<130 and i+n<len(data) and data[p+n]==data[i+n]:n+=1
            if n>best:best=n;offset=i-p
            if best==130:break
        if best>=4:
            if literal:out.append(len(literal)-1);out.extend(literal);literal.clear()
            out.extend((128+best-3,offset&255,offset>>8));step=best
        else:
            literal.append(data[i]);step=1
            if len(literal)==128:out.append(127);out.extend(literal);literal.clear()
        for j in range(i,i+step):history[data[j:j+3]].append(j)
        i+=step
    if literal:out.append(len(literal)-1);out.extend(literal)
    assert unpack(out,len(data))==data
    return bytes(out)

def unpack(data,size):
    out=bytearray();i=0
    while len(out)<size:
        token=data[i];i+=1
        if token&128:
            length=(token&127)+3;offset=data[i]+256*data[i+1];i+=2
            for _ in range(length):out.append(out[-offset])
        else:
            length=token+1;out.extend(data[i:i+length]);i+=length
        # Forward in-place decoder reads at $7000 while writing from $0801.
        assert len(out)-i<0x7000-0x0801,'Unread compressed bytes would be overwritten'
    assert len(out)==size and i==len(data)
    return bytes(out)
