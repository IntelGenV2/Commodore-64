#include "game.h"

static u8 effect;
u8 pickup_ticks;
u8 sfx_busy,music_on=1;
static const u8 pitch[] = {0,32,30,64,25,48};
static const u8 duration[] = {0,3,4,8,12,20};

void silence(void)
{
    REG(0xd404)=0;
    sfx_busy=pickup_ticks=0;
}

void sound(u8 which)
{
    if (!sound_on || (which==CASH_SOUND && pickup_ticks) || (which!=CASH_SOUND && which<effect && sfx_busy>2)) return;
    __asm__("sei");
    effect=which;
    pickup_ticks=which==CASH_SOUND?5:0;
    sfx_busy=duration[which];
    REG(0xd404)=0;
    REG(0xd405)=0x03;
    /* A short minigun transient leaves the melody audible during autofire. */
    REG(0xd406)=which==SHOT_SOUND?0x14:0x92;
    REG(0xd400)=0;
    REG(0xd401)=pitch[which];
    REG(0xd404)=which==CASH_SOUND || which==CLEAR_SOUND ? 0x11 : 0x81;
    __asm__("cli");
}

void audio_tick(void)
{
    if (!sfx_busy || effect==CASH_SOUND) return;
    __asm__("sei");
    --sfx_busy;
    if (!sfx_busy) REG(0xd404)=0;
    else if (effect==CLEAR_SOUND) REG(0xd401)=30+((20-sfx_busy)>>2)*9;
    else REG(0xd401)=pitch[effect]/4+sfx_busy*3;
    __asm__("cli");
}
