#include <cbm.h>
#include <string.h>
#include "passes.h"
#include "state.h"

/* One SEQ file holds the latest snapshot followed by the previous good one. */
typedef unsigned char byte;
struct Record {
    byte magic[3], version;
    unsigned serial;
    struct RunState state;
    unsigned crc;
};
static struct Record slots[2], pending;
static byte valid[2], port, display, sprites;
static const char *const legacy[] = {"0:loop save a,s,r","0:loop save b,s,r"};
static const char *const scratch[] = {"s0:loop save a","s0:loop save b"};

static unsigned checksum(const struct Record *r)
{
    const byte *p=(const byte *)r;
    unsigned crc=0xffff;
    byte i,j;
    for (i=0;i<sizeof(*r)-2;++i) {
        crc^=(unsigned)*p++<<8;
        for (j=0;j<8;++j) crc=crc&0x8000 ? (crc<<1)^0x1021 : crc<<1;
    }
    return crc;
}

static byte status(void)
{
    byte i,c,code=0,st;
    if (cbm_k_chkin(15)) return 99;
    for (i=0;i<64;++i) {
        c=cbm_k_chrin();
        st=cbm_k_readst();
        if (st & 0xbf) { code=99; break; }
        if (i<2) code=(c>='0' && c<='9') ? code*10+c-'0' : 99;
        if (c==13 || (st&64)) break;
    }
    cbm_k_clrch();
    return i>=2 ? code : 99;
}

static byte valid_record(const struct Record *r)
{
    return r->magic[0]==76 && r->magic[1]==80 && r->magic[2]==83 &&
        (r->version>=1 && r->version<=4) && r->crc==checksum(r) &&
        r->state.pass<PASSES && r->state.player_x>=16 && r->state.player_x<=302 &&
        r->state.feet<=152 && r->state.height8>=32*8 &&
        (r->state.height8>>3)==r->state.feet &&
        (r->version==1 ? r->state.hint_ticks<=1 :
         (r->state.hint_ticks<=HINT_DURATION || r->state.hint_ticks==HINT_READY));
}

/* Read either the current two-record file or a single legacy record. */
static byte read_records(const char *name, byte first, byte records)
{
    byte dos, opened, i;
    int count=0;
    opened=cbm_open(2,8,2,name);
    dos=status();
    if (!opened && !dos) count=cbm_read(2,&slots[first],records*sizeof(slots[0]));
    cbm_close(2);
    if (dos==62) return DISK_EMPTY;
    if (opened || dos || count<0) return DISK_ERROR;
    for (i=first;i<first+records && count>=(int)sizeof(slots[0]);++i) {
        valid[i]=valid_record(&slots[i]);
        count-=sizeof(slots[0]);
    }
    return (valid[0] || valid[1]) ? DISK_OK : DISK_EMPTY;
}

static byte scan(void)
{
    byte result;
    valid[0]=valid[1]=0;
    if (cbm_open(15,8,15,"")) return DISK_ERROR;
    status(); /* Consume the power-on message or an earlier DOS status. */
    result=read_records("0:loop save,s,r",0,2);
    if (result!=DISK_EMPTY) return result;
    if (read_records(legacy[0],0,1)==DISK_ERROR ||
        read_records(legacy[1],1,1)==DISK_ERROR) return DISK_ERROR;
    if (valid[0] || valid[1]) return DISK_OK;
    return DISK_EMPTY;
}

static byte newest(void)
{
    if (!valid[0]) return 1;
    return valid[1] && (int)(slots[1].serial-slots[0].serial)>0;
}

static void begin_io(void)
{
    port=*(volatile byte *)1;
    sprites=*(volatile byte *)0xd015;
    display=*(volatile byte *)0xd011 & 0x7f;
    /* Serial bit timing on a stock 1541 needs uninterrupted CPU cycles. */
    *(volatile byte *)0xd015=0;
    *(volatile byte *)0xd011=display & 0xef;
    *(volatile byte *)1=0x36; /* KERNAL and I/O, with the C stack in RAM at $a000. */
}

static byte end_io(byte result)
{
    cbm_close(15);
    __asm__("sei");
    *(volatile byte *)1=port;
    *(volatile byte *)0xd011=display;
    *(volatile byte *)0xd015=sprites;
    return result;
}

byte load_run(struct RunState *run)
{
    byte result,n;
    begin_io();
    result=scan();
    if (result==DISK_OK) {
        n=newest();
        *run=slots[n].state;
        /* The orchard keeps the first three rooms, holding, mirror and leave-it. */
        if (slots[n].version<4 && run->pass>THREE && run->pass!=HOLD &&
            run->pass!=MIRROR && run->pass!=CYCLE) result=DISK_NEW_RULE;
        if (slots[n].version==1)
            run->hint_ticks=run->hint_ticks ? HINT_DURATION : HINT_READY;
    }
    return end_io(result);
}

byte save_run(const struct RunState *run)
{
    byte result, n, last, dos;
    int count;
    begin_io();
    result=scan();
    if (result==DISK_ERROR) return end_io(result);
    last=newest();
    pending.magic[0]=76; pending.magic[1]=80; pending.magic[2]=83;
    pending.version=4;
    pending.serial=result==DISK_EMPTY ? 1 : slots[last].serial+1;
    pending.state=*run;
    pending.crc=checksum(&pending);
    if (result==DISK_OK) slots[1]=slots[last]; else slots[1]=pending;
    slots[0]=pending;
    result=cbm_open(2,8,2,"@0:loop save,s,w");
    dos=status();
    count=(!result && !dos) ? cbm_write(2,slots,sizeof(slots)) : -1;
    cbm_close(2);
    if (status() || count!=sizeof(slots)) return end_io(DISK_ERROR);
    valid[0]=valid[1]=0;
    if (read_records("0:loop save,s,r",0,2)!=DISK_OK || !valid[0] || !valid[1] ||
        memcmp(&pending,&slots[0],sizeof(pending)))
        return end_io(DISK_ERROR);
    /* Retire old-format files only after the new file has passed readback.
       The exact names also make interrupted migrations safe to retry. */
    for (n=0;n<2;++n) {
        if (cbm_write(15,scratch[n],strlen(scratch[n]))<0) return end_io(DISK_ERROR);
        dos=status();
        if (dos!=0 && dos!=1 && dos!=62) return end_io(DISK_ERROR);
    }
    return end_io(DISK_OK);
}