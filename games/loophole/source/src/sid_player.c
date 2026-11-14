#include "sound.h"

/* The PSID host passes the zero-based subtune to init and calls play at VBI. */
static unsigned char scene;

void __fastcall__ init_track(unsigned char subtune)
{
#ifdef WORLD_ALBUM
    scene = ORCHARD_MUSIC + (subtune & 3);
#else
    scene = subtune == 1 ? SHORT_VICTORY : VICTORY_MUSIC;
#endif
    sound_init();
}

void play_track(void)
{
    sound_tick(scene);
}