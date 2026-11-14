#ifndef GAME_H
#define GAME_H

typedef unsigned char u8;
typedef signed char i8;
typedef unsigned int u16;
typedef signed int i16;
typedef unsigned long u32;

#define REG(a) (*(volatile u8*)(a))
#define SCREEN ((u8*)0xc000)
#define COLOR ((u8*)0xd800)
#define FONT ((u8*)0xc800)
/* The exploration map occupies RAM beneath the KERNAL ROM during play. */
#define EXPLORED ((u8*)0xfa00)
#define ACTORS 6
#define PLAYER_SHOTS 14
#define SHOTS 22
#define VIEW_W 15
#define VIEW_H 12
#define CELL(x,y) (((u16)(y)<<5)+(x))
#define UP 1
#define DOWN 2
#define LEFT 4
#define RIGHT 8
#define FIRE 16
#define F1 1
#define F3 2
#define F5 4
#define F7 8

enum {TITLE, FIELD, PAUSE, SETTINGS, HELP, GARAGE, DEFEAT, VICTORY, HULL_SHOP, GUN_SHOP};
enum {MINIGUN, SHOTGUN, RICOCHET, FLAME, CANNON, SHOCK, ROCKET, LASER, RAIL, MINES, GUNS};
enum {SHOT_SOUND=1, HIT_SOUND, CASH_SOUND, BOOM_SOUND, CLEAR_SOUND};
enum {VOID, DUST, BRICK, HEAVY, STONE, CRATE, START, GATE, BARREL,
      DEPOT=9, TOWER=16, BOSS=24, WOOD=31, CRACK, COIN, MEDKIT, SHELLS, DUST2, ICE, BOMB_BONUS};

typedef struct {
    u16 x,y;
    u16 hp;
    u8 heading,kind,cooldown;
    u8 dest_x,dest_y;
    u16 max_hp;
    u8 bar_segments,padding[2]; /* Keep the 16-byte stride used by the 6510. */
} Actor;

typedef struct {
    i16 x,y;                 /* quarter pixels */
    i8 dx,dy;
    u16 life,power;
    u8 hostile,kind;
    u8 motion;               /* Remaining ricochets or smart rocket heading. */
    u8 last_hit;
    u8 padding[2];
} Shot;

typedef struct {
    u8 stage,armor,gear[GUNS];
    u32 cash;
    u16 stock[GUNS];
    u8 difficulty,unlocked;
    u8 movement,rotation,sight;
} Campaign;

extern Campaign campaign;
extern Actor actor[ACTORS];
extern Shot shot[SHOTS];
extern u8 world[32*32], view_x,view_y,world_w,world_h;
extern u16 px,py;
extern u8 mode,sound_on,heading,hull,weapon,cooldown;
extern u8 contacts[8],walk,turn,action,fire,tick,targets,iframes,bunkers;
extern u16 hp,max_hp,ammo[GUNS];
extern u8 nav,menu_item,pickup_ticks;
extern volatile u8 clock50;
void place_mine(void);
void reset_burn(u8 i);
void refresh_targets(void);
u8 crate_tank(u16 pos);
extern u8 beam_count;
extern u16 beam_x[8],beam_y[8];
void sync_ammo(void);
void reset_gun_clock(void);
u8 bunker_damage(u16 pos);
extern const u16 initial_ammo[],refill[],refill_cost[],capacity[],hull_hp[];
u8 max_rank(u8 item);
u16 scaled_hp(u16 raw);
u16 boss_strength(u8 kind);
u16 tile_value(u16 p);
void update_boss_bar(Actor* a);
u8 site_supply(u16 pos);
u8 random_byte(void);
void menu_input(void);
extern u8 default_difficulty;
extern u32 earnings;
extern u8 hud_dirty,radar_dirty,shop_item,return_mode;
extern u8 hull_hit;
extern const u8 tile_code[],tile_ink[];
extern const i8 vx[],vy[];
void load_arena(u8 stage);
extern u8 *map_origin;
extern const char* notice;

void video_init(void);
void wait_frame(void);
void read_pins(void);
void paint_view(void);
void show_title_font(void);
void show_field_font(void);
void read_input(void);
void new_campaign(void);
void start_stage(void);
void play_tick(void);
void change_weapon(void);
extern u8 route[1024];
u8 passable(u8 tile);
u16 cell_at(u16 x,u16 y);
u16 center(u8 cell);
u8 glance(i16 dx,i16 dy);
u8 toward(u8 current,u8 goal);
void replace(u16 pos,u8 tile);
void hurt_player(u16 strength);
void hit_actor(Actor* a,u16 strength);
void enemy_fire(u16 x,u16 y,u8 dir,u8 gun,u8 power);
void enemy_reset(void);
void enemy_site(u16 pos,u8 type);
void enemy_site_hit(u16 pos);
void enemy_hit(Actor* a);
u8 enemy_is_rammer(Actor* a);
u8 rocket_heading(Shot* s);
void enemy_hear(u16 x,u16 y,u8 radius);
void enemy_tick(void);
u8 tower_code(u16 p);
void redraw_towers(void);
void draw_tanks(void);
void draw_tile(u16 pos);
void radar_tile(u16 pos);
void draw_field(void);
void reset_sight(void);
void reveal_tile(u16 pos);
void draw_screen(void);
void render_frame(void);
void erase_shots(void);
void burst(u16 x,u16 y);
void sound(u8 which);
void audio_tick(void);
void silence(void);
extern u8 music_on,music_track;
void music_irq_on(void);
void music_irq_off(void);
void shop_buy(void);
u8* upgrade_rank(u8 item);
u16 price(u8 item);
u8 disk_save(void);
u8 disk_load(void);
#endif
