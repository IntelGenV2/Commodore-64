#ifndef GAME_H
#define GAME_H
#include "ascii.h"
#include <string.h>
#include <stdlib.h>
#include <cbm.h>
typedef unsigned char u8;
typedef signed char s8;
typedef unsigned int u16;
typedef signed int s16;
#define POKE(a,v) (*(volatile u8*)(a)=(v))
#define PEEK(a) (*(volatile u8*)(a))
#define BITMAP ((u8*)0xe000)
#define SCREEN ((u8*)0xc000)
/* Bitmap trajectory mask and the battlefield's multicolor attributes. */
#define TRAILS ((u8*)0xcc00)
#define TRAIL_BYTES 920
#define FIELD_CELLS 680
#define TRAIL_OWNERS ((volatile u8*)0xd918)
#define UP 1
#define DOWN 2
#define LEFT 4
#define RIGHT 8
#define FIRE 16
/* Native function keys; shifted physical keys supply the even numbers. */
#define KEY_F1 0x80
#define KEY_F2 0x81
#define KEY_F3 0x82
#define KEY_F4 0x83
#define KEY_F5 0x84
#define KEY_F6 0x85
#define KEY_F7 0x86
#define KEY_F8 0x87
#define TITLE 0
#define SETUP 1
#define AIM 2
#define SALVO 3
#define RESULTS 4
#define SHOP 5
#define HELP 6
#define REVIEW 8
#define NAMES 9
#define MAXP 10
#define MAXSHOT 30
#define GROUND_TOP 56
#define GROUND_BOTTOM 191

typedef struct {
    char name[9];
    u16 x;
    u8 y,hp,angle,power,weapon,ready,cpu,poison;
    u16 points,money;
    u8 ammo[16];
} Player;
typedef struct {
    s16 x,y,vx,vy;
    u16 age;
    u8 active,owner,weapon,bounces,mode,target;
    s16 oldx,oldy;
} Shot;
extern Player players[MAXP];
extern Shot shots[MAXSHOT];
extern u8 terrain[320];
extern volatile u8 phase;
extern u8 count,humans,hills,speed,round_no,active_player,selected,muted;
extern u8 music_enabled,sfx_enabled;
extern s8 wind;
extern u8 key,video_hz,input,event,command;
extern u8 typing,round_draw;
extern volatile u8 field_mode;
#define font ((const u8*)0xc400)
extern const u8 menu_bitmap[],menu_inks[],radii[];
extern const u16 prices[];
extern const u8 ease[];
extern const u8 weapon_order[];
extern const u8 tank_colors[];
extern const s8 sintab[],costab[];
extern const u16 bitmap_rows[];
extern const char* const weapon_names[];
void hw_init(void);
void render_terrain(void);
void wait_frame(void);
u8 scan_input(void);
void poll(void);
void release_input(void);
void __fastcall__ sound(u8 kind);
void __fastcall__ flight_sound(u8 pitch);
void silence(void);
void audio_init(void);
void audio_suspend(void);
void audio_resume(void);
void clear_screen(void);
void display_invalidate(void);
void text(u8 x,u8 y,const char* s);
void text_field(u8 x,u8 y,u8 width,const char* s);
void number(u8 x,u8 y,u16 n,u8 width);
void ink(u8 x,u8 y,u8 w,u8 h,u8 color);
void setting_box(u8 x,u8 y,u8 width);
void box(u8 x,u8 y,u8 width,u8 height);
void player_labels(void);
void shift_labels(void);
void unpack_image(const u8* src,u8* dest,u16 length);
void __fastcall__ unpack_banner(const u8* src,u8* dest);
void menu_page(const char* name);
void menu_rule(u8 row);
void pixel(s16 x,s16 y,u8 mode);
void hline(s16 x,s16 x2,u8 y,u8 mode);
void line(s16 x,s16 y,s16 x2,s16 y2,u8 mode);
void header(const char* title);
void footer(const char* label);
void field(void);
void clear_traces(void);
void trace_pixel(u16 x,u8 y,u8 owner);
void tanks(void);
void __fastcall__ barrel(u8 i);
void __fastcall__ aim_barrel(u8 oldangle);
void hud(void);
void help(void);
void rename_player(void);
void weapon_info(void);
void pause_menu(void);
void sound_menu(void);
void big_icon(u8 x,u8 y,u8 index);
void start_match(void);
void credit(u8 i,u16 amount);
void new_round(void);
void aim_loop(void);
void launch(void);
void prepare_volley(void);
void finish_volley(void);
void review_volley(void);
void end_round(u8 draw);
void step_shots(void);
void explode(s16 x,s16 y,u8 weapon,u8 owner);
u8 alive_count(void);
void results(void);
void shop(void);
u8 disk_save(void);
u8 disk_load(void);
u8 random8(void);
extern u16 rng;
#endif
