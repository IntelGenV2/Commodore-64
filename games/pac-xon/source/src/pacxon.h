#ifndef PACXON_H
#define PACXON_H
#include <stdint.h>
#define REG(a) (*(volatile uint8_t*)(a))
#define SCREEN ((uint8_t*)0xc000)
#define COLOR ((uint8_t*)0xd800)
typedef uint8_t u8;
typedef uint16_t u16;
enum {EMPTY,WALL,EDGE,TRAIL,BURN,REACH,OUTSIDE};
enum {MENU,GUIDE,RECORDS,AUDIO,READY,PLAY,PAUSED,DYING,CLEAR,OVER,ENDING,DIFFICULTY};
enum {EASY,NORMAL,HARD};
enum {RIGHT,DOWN,LEFT,UP,STILL};
enum {DRIFTER,PATROLLER,WISP,CRUSHER,SEEKER,SPINNER,GHOST_TYPES};
enum {ICE,POWER,SPEED,SLOW};
enum {BTN_UP=1,BTN_DOWN=2,BTN_LEFT=4,BTN_RIGHT=8,FIRE=16,PAUSE=32,MUTE=64,BACK=128};
enum {GHOSTS=12, ITEMS=24};
typedef struct {int x,y; signed char vx,vy; u8 kind,active,dir,wait;} Ghost;
extern Ghost ghosts[GHOSTS];
extern const u8 ghost_ink[GHOST_TYPES];
extern u8 board[1000], mode, stage, lives, percent, peak, count, facing, clock30;
extern u8 terrain_art[1000], terrain_color[1000], field_dirty;
extern u8 pickup[1000], held, edge, selected, flash, music, effects;
extern volatile u8 multiplex;
extern u8 contacts[8], joy, ntsc;
extern volatile u8 ticks,cue,request;
extern u8 charset[],sprites[],title_art[];
extern u16 rows[23], filled,trail_len, powers[4], px,py;
extern uint32_t score,best[5];
extern u8 best_level[5],best_skill[5],difficulty;
extern const u8 reserves[3];
extern const u8 stages[20][GHOST_TYPES+2];
void machine(void);
void scan(void);
void __fastcall__ flood(u16 index);
void init_video(void);
void title_screen(void);
void menu_pointer(void);
void page_screen(void);
void field_screen(void);
void tile(u16 cell);
void actors(void);
void hud(void);
void panel(void);
void game_tick(void);
void new_game(void);
void continue_game(void);
void load_level(void);
void start_play(void);
void sound(u8 number);
void start_music(void);
void add_points(u16 points);
void record_run(void);
void read_input(void);
#endif
