#include <cbm.h>
#include <string.h>
#include <stddef.h>
#include "game.h"

/* Write into the spare name and reread it before retiring the older save. */
typedef struct {
    u8 magic,version,serial,music,audio;
    Campaign run;
    u8 sum;
} Checkpoint;
/* The arena map is idle on both screens that access drive 8. */
#define saves ((Checkpoint*)world)
#define pending (*(Checkpoint*)(world+128))
static u8 good[2];
static const char* const read_name[]={"0:tanks a,s,r","0:tanks b,s,r"};
static const char* const write_name[]={"@:tanks a,s,w","@:tanks b,s,w"};
static const char* const retire_name[]={"s0:tanks a","s0:tanks b"};

static u8 checksum(const Checkpoint* s,u8 len)
{
    const u8* data=(const u8*)s;
    u8 i,c=0x73;
    for (i=0;i<len;++i) c=((c<<1)|(c>>7))^data[i];
    return c;
}

static u8 valid(const Checkpoint* s)
{
    u8 i;
    for (i=0;i<GUNS;++i) if (s->run.gear[i]>(i?6:5) || s->run.stock[i]>capacity[i]) return 0;
    return s->magic==0xa2 && s->music<2 && s->audio<2 && s->run.stage<15 && s->run.armor<=5 &&
        s->run.difficulty<=2 && s->run.unlocked>=s->run.stage && s->run.unlocked<15 && s->run.movement<=5 && s->run.rotation<=5 && s->run.sight<=5;
}

static void read_slot(u8 id)
{
    int n=0;
    Checkpoint *s=saves+id;
    u8 *raw=(u8*)s;
    u8 i;
    if (!cbm_open(2,8,2,read_name[id])) n=cbm_read(2,s,sizeof(Checkpoint));
    cbm_close(2);
    good[id]=0;
    if ((s->version==1 && n==19) || (s->version==2 && n==22)) {
        Campaign run;
        if (raw[n-1]!=checksum(s,n-1)) return;
        memset(&run,0,sizeof(run));
        run.stage=run.unlocked=raw[5];run.armor=raw[6];run.difficulty=1;
        for (i=0;i<9;++i) {
            run.gear[i]=raw[7+i];
            if (run.gear[i]>3) return;
            if (run.gear[i]) run.stock[i]=initial_ammo[i];
        }
        run.cash=raw[16]+((u16)raw[17]<<8);
        if (s->version==2) {run.movement=raw[18];run.rotation=raw[19];run.sight=raw[20];}
        else s->music=s->audio;
        s->run=run;
    } else if (n!=sizeof(*s) || s->version!=3 || s->sum!=checksum(s,sizeof(*s)-1)) return;
    good[id]=valid(s);
}

static u8 begin(void)
{
    music_irq_off();
    REG(0xd011)=0x0b;
    REG(1)=0x36; /* KERNAL serial routines, RAM at $a000. */
    read_slot(0);read_slot(1);
    if (!good[0]) return 1;
    return good[1] && (i8)(saves[1].serial-saves[0].serial)>0;
}

static void end(void)
{
    __asm__("sei");
    REG(1)=0x35;REG(0xd011)=0x1b;
    music_irq_on();
}

u8 disk_load(void)
{
    u8 id=begin();
    end();
    if (!good[id]) return 0;
    campaign=saves[id].run;
    sound_on=saves[id].audio;music_on=saves[id].music;
    return 1;
}

u8 disk_save(void)
{
    u8 id=begin(),ok;
    pending.magic=0xa2;pending.version=3;
    pending.serial=good[id]?saves[id].serial+1:0;
    pending.music=music_on;pending.audio=sound_on;
    pending.run=campaign;pending.sum=checksum(&pending,sizeof(pending)-1);
    id^=1;
    if (!cbm_open(2,8,2,write_name[id])) cbm_write(2,&pending,sizeof(pending));
    cbm_close(2);
    read_slot(id);
    ok=good[id] && !memcmp(&pending,saves+id,sizeof(pending));
    if (ok) {
        char status[2];
        ok=!cbm_open(15,8,15,retire_name[id^1]) && cbm_read(15,status,2)==2 &&
            status[0]=='0' && (status[1]=='0' || status[1]=='1');
        cbm_close(15);
    }
    end();
    return ok;
}
