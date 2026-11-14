#ifndef GAME_H
#define GAME_H
#include "ascii.h"
#include <string.h>
#include <stdint.h>
#define REG(a) (*(volatile unsigned char*)(a))
typedef unsigned char u8;
typedef signed char s8;
typedef unsigned int u16;
/* C64 PETSCII function-key values returned by the native matrix scanner. */
enum { KEY_F1=0x85, KEY_F3, KEY_F5, KEY_F7, KEY_F8=0x8c };
enum { SOUND_SCORE=1, SOUND_EFFECTS_ONLY=2 };
extern u8 stage,px,py,orient,qx,qy,active,result,board[150],groups[150],key,video_hz;
extern u16 bridges,moves;
extern const u8 *bridge_cells;
extern u8 bridge_count;
extern const char level_codes[33][7];
extern volatile u8 ticks,music_mode,audio_mix,sfx;
extern volatile u8 joy_used;
extern const u8 *source,*blit_source;
extern u8 *destination;
extern u8 blit_x,blit_y,blit_erase;
void hw_init(void);
void wait_frame(void);
u8 scan_input(void);
void unpack(void);
void menu_unpack(void);
void menu_unpack_banked(void);
void __fastcall__ circuit_tick(u8 frame);
void blit_tile(void);
void blend_patch(void);
void commit_patch(void);
void publish_sprites(void);
void load_level(void);
void __fastcall__ step(u8 direction);
u8 __fastcall__ tile_at(u8 pos);
void main(void);
#endif
