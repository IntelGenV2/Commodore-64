#ifndef LOOPHOLE_SOUND_H
#define LOOPHOLE_SOUND_H

enum { S_JUMP, S_PAD, S_OPEN, S_FALL, S_CLOSE, S_CLEAR };
enum { ROOM_AUDIO, TITLE_MUSIC, CLEAR_MUSIC, VICTORY_MUSIC, SHORT_VICTORY,
       ORCHARD_MUSIC, SHORE_MUSIC, SNOW_MUSIC, BEDTIME_MUSIC };
extern unsigned char muted;
void sound_init(void);
void sound_tick(unsigned char scene);
void sound_effect(unsigned char effect);
void sound_toggle(void);
void sound_suspend(void);

#endif