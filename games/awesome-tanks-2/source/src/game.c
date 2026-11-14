#include <string.h>
#include "game.h"

Campaign campaign;

u8 view_x,view_y,world_w,world_h;
u16 px,py,hp,max_hp,ammo[GUNS];
u32 earnings;
u8 heading,hull,weapon,cooldown,targets,bunkers,iframes,tick;
#define tile_low ((u8*)0xc400)
#define tile_high ((u8*)0xf400)
static u16 collected,loose,flash_time,ice_pos,bomb_pos;
static u8 frozen,loot_row,loot_active;
u8 player_burn;
static void explode(u16 x,u16 y,u16 power,u8 radius,u8 harmful);
u8 frame_steps=2;
static u16 durability(u8 t);
void clear_route_tags(void);
u8 generation;
u16 *path_read,*path_write;
#define queue ((u16*)0xf200)
static u16 route_root;
static u8 route_dirty;
void path_slice(void);
static u16 explosions[32];
static u8 blast_count;
static u8 aim_clock,drive_fraction;
static const i8 step[4]={-32,1,32,-1};
/* Indexed by U/D/L/R pins. Zero on the angle wheel points east. */
static const u8 aim_dir[16]={0,24,8,0,16,20,12,16,0,28,4,0,0,24,8,0};

u8 passable(u8 t)
{
    return t==DUST || t>=COIN;
}

static u8 distance(u16 a,u16 b,u16 limit)
{
    return a>b ? a-b<=limit : b-a<=limit;
}

u8 toward(u8 current,u8 goal)
{
    u8 d=(goal-current)&31;
    if (!d) return current;
    return (current+(d<=16?1:31))&31;
}

static void set_value(u16 p,u16 n) {tile_low[p]=n;tile_high[p]=n>>8;}
static void collect(u16 n)
{
    static const u32 coin_rate[3][15]={
        {8400000UL,15596280UL,22792560UL,29988840UL,37185120UL,44381400UL,51577680UL,58773960UL,65970240UL,73166520UL,100453500UL,109448850UL,118444200UL,127439550UL,136434900UL},
        {10200000UL,18938340UL,27676680UL,36415020UL,45153360UL,53891700UL,62630040UL,71368380UL,80106720UL,88845060UL,121979250UL,132902175UL,143825100UL,154748025UL,165670950UL},
        {12000000UL,22280400UL,32560800UL,42841200UL,53121600UL,63402000UL,73682400UL,83962800UL,94243200UL,104523600UL,143505000UL,156355500UL,169206000UL,182056500UL,194907000UL}
    };
    u32 rate=coin_rate[campaign.difficulty][campaign.stage];
    collected+=n;
    earnings=(rate/1000000UL)*collected+((rate%1000000UL)*collected)/1000000UL;
    hud_dirty=1;
}
/* Pickups use ten quantity bits and a six-bit deadline in 32-frame units.
   Ordinary loot lives for roughly ten seconds in the Flash game. */
static u16 quantity(u16 p) {return tile_value(p)&1023;}
static void pickup(u16 p,u8 kind,u16 amount)
{
    u8 due=(flash_time+610+(random_byte()%50))>>5;
    replace(p,kind);set_value(p,(amount&1023)|((u16)due<<10));loot_active=1;
}
static void pile(u16 p,u8 n)
{
    u16 old=world[p]==COIN?quantity(p):0;
    if (world[p]==ICE) ice_pos=0;
    if (world[p]==BOMB_BONUS) bomb_pos=0;
    pickup(p,COIN,old+n);loose+=n;
}
static u8 crate_drop(u16 p,u8* ammo_kind)
{
    u8 i,n=0,choice=0,r=random_byte();
    if (player_burn) return MEDKIT;
    if (hp>=max_hp/4 && r>247 && crate_tank(p)) return DUST;
    for (i=1;i<GUNS;++i) if (campaign.gear[i] && ammo[i]<capacity[i]*3/4) {
        if (!(random_byte()%++n)) choice=i;
    }
    if (hp<max_hp/4 && random_byte()>84) return MEDKIT;
    if (choice && random_byte()<77) {*ammo_kind=choice;return SHELLS;}
    r=random_byte();
    if (hp>max_hp-max_hp/10) choice=r<26?BOMB_BONUS:r<141?ICE:COIN;
    else choice=r<79?MEDKIT:r<158?COIN:r<237?ICE:BOMB_BONUS;
    if (!targets) choice=COIN;
    if (choice==ICE) {
        if (frozen || ice_pos) return COIN;
        ice_pos=p;
    }
    if (choice==BOMB_BONUS) {
        if (bomb_pos) return COIN;
        bomb_pos=p;
    }
    return choice;
}
u16 scaled_hp(u16 raw)
{
    if (campaign.difficulty==2) return raw;
    return campaign.difficulty==0?(raw/10)*7+(raw%10)*7/10:(raw/20)*17+(raw%20)*17/20;
}
u16 boss_strength(u8 kind)
{
    static const u16 strength[]={300,800,2000,3000,4000,4000,4000};
    return scaled_hp(strength[(u8)(kind-BOSS)]);
}
void update_boss_bar(Actor* a)
{
    a->bar_segments=(a->hp*8+a->max_hp-1)/a->max_hp;
}
u8 bunker_damage(u16 p)
{
    u16 max=durability(world[p]),left=tile_value(p);
    if (left<=max/3) return 2;
    return left<max/2;
}
static void goal_removed(void)
{
    if (targets) --targets;
    hud_dirty=1;
}

void replace(u16 pos,u8 t)
{
    world[pos]=t;
    if (passable(t)) set_value(pos,0);
    if (EXPLORED[pos]) reveal_tile(pos);
    route_dirty=1;
}

void hurt_player(u16 strength)
{
    if (!hp) return;
    hp=hp>strength?hp-strength:0;
    hull_hit=5;
    iframes=2;
    hud_dirty=1;
    sound(HIT_SOUND);
}

void hit_actor(Actor* a,u16 strength)
{
    u16 p;
    enemy_hit(a);
    reveal_tile(cell_at(a->x,a->y));
    if (a->hp>strength) {
        a->hp-=strength;
        if (a->kind>=BOSS) update_boss_bar(a);
        sound(HIT_SOUND);
        return;
    }
    a->hp=0;
    if (enemy_is_rammer(a) && blast_count<32) explosions[blast_count++]=cell_at(a->x,a->y);
    goal_removed();
    p=cell_at(a->x,a->y);
    if (passable(world[p]) && !(enemy_is_rammer(a) && strength==65535u)) pile(p,(a->kind>=BOSS?14:4)+random_byte()%3);
    burst(a->x,a->y);
    sound(BOOM_SOUND);
}

static void hit_tile(u16 pos,u16 power)
{
    u8 t=world[pos],drop=DUST,n=0,i;
    u16 left=tile_value(pos);
    if (!left || passable(t)) return;
    if (t>=DEPOT && t<=30) {enemy_site_hit(pos);reveal_tile(pos);}
    if (left>power) {
        set_value(pos,left-power);
        if (t>=DEPOT && t<BOSS) draw_tile(pos);
        sound(HIT_SOUND);
        return;
    }
    set_value(pos,0);
    if (t==BARREL && blast_count<32) explosions[blast_count++]=pos;
    if (t>=DEPOT && t<=30) {
        goal_removed();
        if (t<BOSS) --bunkers;
        if (t<TOWER) {
            n=7+random_byte()%3;
            for (i=site_supply(pos);i;--i) n+=4+random_byte()%3;
        } else n=(t>=BOSS?14:4)+random_byte()%3;
    } else if (t==CRATE) {
        drop=crate_drop(pos,&i);if (drop==COIN) n=15;
    }
    if (n) pile(pos,n);
    else if (drop==BOMB_BONUS) {replace(pos,drop);set_value(pos,flash_time+60);}
    else if (drop!=DUST) pickup(pos,drop,drop==SHELLS?i:0);
    else replace(pos,DUST);
    burst(center(pos&31),center(pos>>5));
    sound(t==WOOD || t==BRICK || t==GATE?HIT_SOUND:BOOM_SOUND);
    /* Linked gates fall together, using a temporary tile to mark the group. */
    if (t==GATE) {
        u8 expanded=1,col;
        u16 p;
        world[pos]=START;   /* Temporary flood mark, never a live level tile. */
        while (expanded) {
            expanded=0;
            for (p=32;p<CELL(0,world_h-1);++p) if (world[p]==GATE) {
                for (col=0;col<4;++col) if (world[p+step[col]]==START) {
                    world[p]=START;
                    expanded=1;
                    break;
                }
            }
        }
        for (p=32;p<CELL(0,world_h-1);++p) if (world[p]==START) {
            set_value(p,0);
            replace(p,DUST);
        }
    }
}

/* Weapon energy, lifetime and cooldown are expressed in the SWF's 59 Hz
   frames. The independently clocked SID interrupt supplies elapsed time. */
extern i16 ray_x,ray_y;
extern i8 ray_dx,ray_dy;
extern u16 ray_cell,ray_ignore;
extern u8 ray_owner,ray_steps,ray_skip;
u8 trace(void);
extern u16 target_range(u16 x,u16 y,u16 tx,u16 ty);
extern u8 shot_line(u16 from,u16 to);
static u8 gun_clock,fraction,last_fire,charge,rocket_slot=255;
static u8 fire_timer[GUNS];
u8 burn[ACTORS],tile_burn[6];
u16 burning_tile[6];
u8 beam_count;
u16 beam_x[8],beam_y[8];
static const u16 damage[GUNS][6]={
    {4,4,4,4,4,5},{25,22,22,22,22,22},{75,110,145,180,215,249},
    {20,24,28,32,36,40},{457,569,681,793,905,1017},{2,3,4,5,6,7},
    {1000,1300,1600,1900,2200,2500},{8,12,16,20,24,28},
    {500,550,600,650,700,750},{457,569,681,793,905,1017}};
static const u8 pellets[]={4,5,6,8,9,10};
static const u8 mini_cd[]={7,6,5,4,3,3};
static const u8 wide_cd[]={60,56,52,48,44,40},cannon_cd[]={55,51,47,43,39,35};
/* A live round reaches the arena perimeter through the same swept collision
   trace as a nearby wall. Flames still have a short burn time. */
#define UNTIL_IMPACT 65535u
#define TRACE_EDGE 253
static const u8 quarter_sine[]={0,2,3,5,6,8,9,11,12,14,16,17,19,20,22,23,24,26,27,29,30,32,33,34,36,37,38,39,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,56,57,58,59,59,60,60,61,61,62,62,62,63,63,63,64,64,64,64,64,64};
static i8 component(u8 angle,u8 speed)
{
    u8 q=angle&63;
    i16 v=(quarter_sine[angle&64?64-q:q]*speed+32)>>6;
    return angle&128?-v:v;
}
static void vector(Shot* s,u8 angle,u8 speed)
{
    s->dx=component(angle+64,speed);s->dy=component(angle,speed);
}
void reset_gun_clock(void) {gun_clock=clock50;fraction=0;}
static void elapsed(void)
{
    u8 now=clock50,d=now-gun_clock;
    gun_clock=now;
    if (!d) {frame_steps=1;return;}
    if (d>8) d=8;
    fraction+=9*d;frame_steps=d;
    while (fraction>=50) {fraction-=50;++frame_steps;}
}
static void ignite(u16 p)
{
    u8 i,oldest=0;
    for (i=0;i<6;++i) {
        if (!tile_burn[i] || burning_tile[i]==p) {oldest=i;break;}
        if (tile_burn[i]<tile_burn[oldest]) oldest=i;
    }
    burning_tile[oldest]=p;tile_burn[oldest]=100;
}
static void heat(void)
{
    u8 i,n;
    for (i=0;i<ACTORS;++i) if (burn[i]) {
        n=burn[i]<frame_steps?burn[i]:frame_steps;burn[i]-=n;
        if (actor[i].hp) hit_actor(actor+i,2*n);else burn[i]=0;
    }
    for (i=0;i<6;++i) if (tile_burn[i]) {
        u16 p=burning_tile[i];
        n=tile_burn[i]<frame_steps?tile_burn[i]:frame_steps;tile_burn[i]-=n;
        if (passable(world[p])) tile_burn[i]=0;
        else if (world[p]>=TOWER && world[p]<BOSS) hit_tile(p,4*n);
        else if ((tick&3)==0) hit_tile(p,2*n);
    }
}
void reset_burn(u8 i) {burn[i]=0;}
static u16 falloff(u16 power,u8 radius,u8 d)
{
    /* Divide first without losing the fractional remainder or overflowing. */
    return (power/radius)*(radius-d)+((power%radius)*(radius-d))/radius;
}
static void explode(u16 x,u16 y,u16 power,u8 radius,u8 harmful)
{
    u16 p=cell_at(x,y),q,d;u8 i; i8 dx,dy;
    burst(x,y);sound(BOOM_SOUND);enemy_hear(x,y,39);
    d=target_range(x,y,px,py);
    if (harmful && d<radius && shot_line(p,cell_at(px,py))) hurt_player(falloff(power,radius,d));
    for (i=0;i<ACTORS;++i) if (actor[i].hp) {
        d=target_range(x,y,actor[i].x,actor[i].y);
        if (d<radius && shot_line(p,cell_at(actor[i].x,actor[i].y))) hit_actor(actor+i,falloff(power,radius,d));
    }
    for (dy=-2;dy<=2;++dy) for (dx=-2;dx<=2;++dx) {
        q=p+dy*32+dx;
        if (q>=832 || passable(world[q]) || !tile_value(q)) continue;
        d=target_range(x,y,center(q&31),center(q>>5));
        if (d<radius && shot_line(p,q)) {
            u16 loss=falloff(power,radius,d);
            if (world[q]!=CRATE && world[q]!=BARREL && !(world[q]>=TOWER && world[q]<WOOD)) loss/=3;
            hit_tile(q,loss);
        }
    }
}
static void blast(void)
{
    while (blast_count) {
        u16 p=explosions[--blast_count];
        explode(center(p&31),center(p>>5),200,30,1);
    }
}
static Shot* launch(u8 first,u8 end,u16 x,u16 y,u8 kind,u16 power,u16 life)
{
    u8 i;
    for (i=first;i<end;++i) if (!shot[i].life) {
        Shot* s=shot+i;
        s->x=x<<2;s->y=y<<2;s->kind=kind;s->power=power;s->life=life;
        s->hostile=first!=0;s->motion=0;s->last_hit=0;
        return s;
    }
    return 0;
}
void enemy_fire(u16 x,u16 y,u8 dir,u8 gun,u8 unused)
{
    static const u16 enemy_power[]={10,15,80,1,200,1,180,6,333};
    u8 i,count=gun==SHOTGUN?6:1;
    (void)unused;
    for (i=0;i<count;++i) {
        Shot* s=launch(PLAYER_SHOTS,SHOTS,x,y,gun,enemy_power[gun],gun==FLAME?50:UNTIL_IMPACT);
        if (!s) break;
        s->motion=gun==ROCKET?dir:3;s->last_hit=dir;
        vector(s,dir*8+(gun==SHOTGUN?((26*i)/6)-13:0),
               gun==MINIGUN?31:gun==ROCKET?5:gun==CANNON?18:gun==FLAME?6:gun==SHOTGUN?7+(random_byte()&3):10);
    }
    reveal_tile(cell_at(x,y));
}
static void end_rocket(Shot* s)
{
    explode((u16)s->x>>2,(u16)s->y>>2,s->power,s->kind==CANNON || s->kind==MINES?23:26,s->hostile);
    if (!s->hostile && s->kind==ROCKET) rocket_slot=255;
    s->life=0;
}
static void beam(u16 power,u8 rank)
{
    u8 hit,limit=weapon==SHOCK?rank+2:1,j,best;
    u16 d,nearest,x=px,y=py;
    ray_dx=vx[heading];ray_dy=vy[heading];
    ray_x=(px<<2)+ray_dx;ray_y=(py<<2)+ray_dy;
    beam_count=1;beam_x[0]=px;beam_y[0]=py;
    refresh_targets();
    ray_steps=255;ray_owner=ray_skip=0;ray_ignore=65535u;
    while (ray_steps) {
        hit=trace();x=(u16)ray_x>>2;y=(u16)ray_y>>2;
        if (hit==255 || hit==TRACE_EDGE) break;
        if (hit==254) {
            if (!tile_value(ray_cell)) break;
            hit_tile(ray_cell,power);ray_ignore=ray_cell;
        } else {
            hit_actor(actor+hit,power);ray_skip|=1<<hit;
            if (weapon==SHOCK) {
                if (beam_count<7) {beam_x[beam_count]=x;beam_y[beam_count++]=y;}
                if (!--limit) break;
                best=255;nearest=62;
                for (j=0;j<ACTORS;++j) if (!(ray_skip&(1<<j)) && actor[j].hp) {
                    d=target_range(x,y,actor[j].x,actor[j].y);
                    if (d<nearest) {nearest=d;best=j;}
                }
                if (best==255) break;
                j=glance(actor[best].x-x,actor[best].y-y);
                ray_dx=vx[j];ray_dy=vy[j];ray_steps=70;continue;
            }
        }
        if (weapon!=RAIL) break;
        power=power>100?power-50:50;
    }
    beam_x[beam_count]=x;beam_y[beam_count++]=y;
}
static u8 fire_round(u8 rank,u16 power)
{
    u8 i,n=weapon==SHOTGUN?pellets[rank]:1,speed,angle;
    u16 life=weapon==FLAME?45+rank*5:UNTIL_IMPACT;
    if (weapon==LASER || weapon==SHOCK || weapon==RAIL) beam(power,rank);
    else {
        for (i=0;i<n;++i) {
            Shot* s=launch(0,PLAYER_SHOTS,px,py,weapon,power,life);
            if (!s) return i!=0;
            /* The trace takes its first step from the barrel, in quarter pixels. */
            s->x+=vx[heading]*(weapon==FLAME?1:2);
            s->y+=vy[heading]*(weapon==FLAME?1:2);
            angle=heading*8;speed=28;
            if (weapon==SHOTGUN) {angle=angle-13+(26*i)/n;speed=7+((random_byte()&3)*5)/4;}
            if (weapon==FLAME) {angle+=((random_byte()&15)-7);speed=6;}
            if (weapon==RICOCHET) {speed=10;s->motion=3;}
            if (weapon==CANNON) speed=18;
            if (weapon==ROCKET) {rocket_slot=s-shot;s->motion=heading;speed=3;}
            vector(s,angle,speed);
        }
    }
    if (weapon!=LASER && weapon!=SHOCK) sound(SHOT_SOUND);
    if (weapon!=LASER && weapon!=SHOCK || !(tick&7)) enemy_hear(px,py,weapon==CANNON?46:weapon==LASER?15:31);
    return 1;
}
void place_mine(void)
{
    Shot* s;u8 i;
    if (!campaign.gear[MINES] || !ammo[MINES]) return;
    for (i=0;i<PLAYER_SHOTS;++i) if (shot[i].life && shot[i].kind==MINES &&
        distance((u16)shot[i].x>>2,px,8) && distance((u16)shot[i].y>>2,py,8)) return;
    s=launch(0,PLAYER_SHOTS,px,py,MINES,damage[MINES][campaign.gear[MINES]-1],UNTIL_IMPACT);
    if (s) {s->dx=s->dy=0;--ammo[MINES];sound(SHOT_SOUND);}
}
void change_weapon(void)
{
    charge=0;
    do {if (++weapon==MINES) weapon=0;} while (weapon && (!campaign.gear[weapon] || !ammo[weapon]));
    hud_dirty=1;
}
static void trigger(void)
{
    u8 rank=campaign.gear[weapon]-(weapon!=MINIGUN),n=frame_steps,units;
    u16 power=damage[weapon][rank],amount;
    if (weapon==RICOCHET) {
        if (fire && (ammo[weapon] || charge)) {
            amount=(power/59)*n;
            if (amount>power-charge) amount=power-charge;
            if (amount>ammo[weapon]) amount=ammo[weapon];
            charge+=amount;ammo[weapon]-=amount;hud_dirty=1;
        } else if (!fire && charge) {
            if (fire_round(rank,charge)) charge=0;
        } else if (fire) {weapon=MINIGUN;hud_dirty=1;}
    } else if (weapon==ROCKET && rocket_slot!=255) {
        if (fire && !last_fire) end_rocket(shot+rocket_slot);
    } else if (fire && (weapon!=ROCKET || !last_fire)) {
        while (n) {
            if (fire_timer[weapon]) {
                units=fire_timer[weapon]<n?fire_timer[weapon]:n;
                fire_timer[weapon]-=units;n-=units;continue;
            }
            if (weapon && !ammo[weapon]) {weapon=MINIGUN;hud_dirty=1;break;}
            units=(weapon==LASER || weapon==SHOCK)?n:1;
            if (weapon && units>ammo[weapon]) units=ammo[weapon];
            if (!fire_round(rank,power*units)) break;
            if (weapon) {ammo[weapon]-=units;hud_dirty=1;}
            n-=units;
            fire_timer[weapon]=weapon==MINIGUN?mini_cd[rank]:weapon==SHOTGUN || weapon==RAIL?wide_cd[rank]:
                weapon==CANNON?cannon_cd[rank]:weapon==FLAME?5:0;
            if (weapon==ROCKET) break;
        }
    } else {
        for (n=0;n<MINES;++n) fire_timer[n]=fire_timer[n]>frame_steps?fire_timer[n]-frame_steps:0;
    }
    cooldown=fire_timer[weapon];last_fire=fire;
}
void steer_rocket(Shot* s)
{
    u8 dir;
    dir=s->hostile?rocket_heading(s):s->motion;
    if (!s->hostile && ((tick&1) || campaign.gear[ROCKET]>1)) dir=toward(dir,heading);
    s->motion=dir;
    if (!s->hostile && s->last_hit<60) s->last_hit+=ray_steps;
    vector(s,dir*8,s->hostile?5:1+s->last_hit/15);
}

void hostile_beam(Shot* s)
{
    u8 hit;
    ray_dx=vx[s->last_hit];ray_dy=vy[s->last_hit];ray_steps=255;
    do {
        hit=trace();
        if (hit!=254) {if (hit==0) hurt_player(s->power);break;}
        if (!tile_value(ray_cell)) break;
        if (world[ray_cell]<DEPOT || world[ray_cell]>=WOOD) hit_tile(ray_cell,s->power);
        ray_ignore=ray_cell;
    } while (s->kind==RAIL && ray_steps);
    if (!beam_count) {
        beam_x[0]=(u16)s->x>>2;beam_y[0]=(u16)s->y>>2;
        beam_x[1]=(u16)ray_x>>2;beam_y[1]=(u16)ray_y>>2;beam_count=2;
    }
    s->life=0;
}

u8 shot_hit;
void shot_impact(Shot* s)
{
    u8 hit=shot_hit;
    u16 old,p=ray_cell;
    if (s->kind==CANNON || s->kind==ROCKET || s->kind==MINES) {end_rocket(s);return;}
    if (hit==TRACE_EDGE) {s->life=0;return;}
    if (hit==254) {
        if (!s->hostile || world[p]<DEPOT || world[p]>=WOOD) {
            if (s->kind==FLAME && tile_value(p)) {
                if (world[p]==BRICK || world[p]==HEAVY) {hit_tile(p,1);s->life=0;return;}
                ignite(p);
            }
            hit_tile(p,s->power);
        }
        if (s->kind==RICOCHET && s->motion) {
            --s->motion;s->x-=s->dx;s->y-=s->dy;
            old=cell_at((u16)s->x>>2,(u16)s->y>>2);
            if ((p&31)!=(old&31)) s->dx=-s->dx;
            if ((p>>5)!=(old>>5)) s->dy=-s->dy;
            return;
        }
    } else if (s->hostile) {hurt_player(s->power);if (s->kind==FLAME) player_burn=100;}
    else {
        if (s->kind==FLAME) burn[hit]=100;
        hit_actor(actor+hit,s->power);
        if (s->kind==RICOCHET && s->motion) {--s->motion;return;}
    }
    s->life=0;
}
void advance_shots(void);
static u8 fits(u16 x,u16 y)
{
    return passable(world[cell_at(x-5,y-5)]) && passable(world[cell_at(x+5,y-5)])
        && passable(world[cell_at(x-5,y+5)]) && passable(world[cell_at(x+5,y+5)]);
}

static void drive(void)
{
    static const u8 straight[]={32,34,37,38,41,43},diagonal[]={23,24,26,27,29,31};
    u8 bits=walk,speed,t;
    u16 x=px,y=py,p;
    if ((bits&3)==3) bits&=~3;
    if ((bits&12)==12) bits&=~12;
    if (bits) {
        hull=aim_dir[bits]>>2;
        drive_fraction+=((bits&3) && (bits&12))?diagonal[campaign.movement]:straight[campaign.movement];
        speed=drive_fraction>>4;
        drive_fraction&=15;
        if (bits&UP) y-=speed;
        if (bits&DOWN) y+=speed;
        if (bits&LEFT) x-=speed;
        if (bits&RIGHT) x+=speed;
        if (x!=px && fits(x,py)) px=x;
        if (y!=py && fits(px,y)) py=y;
    }
    if (turn==LEFT || turn==RIGHT) {
        aim_clock+=4+campaign.rotation;
        speed=aim_clock>>3;
        aim_clock&=7;
        heading=(heading+(turn==RIGHT?speed:-speed))&31;
    } else aim_clock=4;
    trigger();
    p=cell_at(px,py);
    /* The original draws pickups within 75 Flash pixels toward the player. */
    {
        static const i8 nearby[]={0,-1,1,-32,32,-33,-31,31,33};
        static const u16 bonus[]={0,31,600,50,31,300,9,300,31,18};
        u8 i,w,picked=0;
        for (i=0;i<9;++i) {
            u16 q=p+nearby[i],amount;
            t=world[q];
            if (t!=ICE && (t<COIN || t>SHELLS)) continue;
            if (!distance(px,center(q&31),20) || !distance(py,center(q>>5),20)) continue;
            amount=quantity(q);
            if (t==COIN) {collect(amount);loose-=amount;}
            else if (t==ICE) {frozen=200;ice_pos=0;}
            else if (t==MEDKIT) {player_burn=0;hp+=max_hp/4;if (hp>max_hp) hp=max_hp;}
            else {w=(u8)amount;ammo[w]+=bonus[w];if (ammo[w]>capacity[w]) ammo[w]=capacity[w];}
            replace(q,DUST);picked=1;
        }
        if (picked) {hud_dirty=1;sound(CASH_SOUND);}
    }
}

/* Build a flow field outwards from the player over several game ticks.
   Tanks keep using the previous valid directions during a rebuild. */
static void paths(void)
{
    u16 root=cell_at(px,py);
    if (path_read==path_write && (root!=route_root || route_dirty)) {
        route_root=root;
        route_dirty=0;
        generation+=8;
        if (generation==248) {clear_route_tags();generation=8;}
        queue[0]=root;path_read=queue;path_write=queue+1;
        route[root]=generation|4;
    }
    if (path_read!=path_write) path_slice();
}

static u16 durability(u8 t)
{
    static const u16 depot[]={75,250,400,600,800,1000,1000};
    static const u16 tower[]={400,400,500,800,1250,1250,1500,2000};
    u8 level=campaign.stage+1;
    if (t>=DEPOT && t<TOWER) return scaled_hp(t==DEPOT && level>2?150:depot[t-DEPOT]);
    if (t>=TOWER && t<BOSS) return tower[t-TOWER];
    if (t>=BOSS && t<=30) return boss_strength(t);
    switch (t) {
    case HEAVY:return 75+level*30;
    case BRICK:case WOOD:case GATE:return 25+level*10;
    case CRATE:return 20+8*campaign.stage;
    case BARREL:return 25+4*campaign.stage;
    }
    return 0;
}

void start_stage(void)
{
    const u8* src=(const u8*)queue;
    u8 w,h,x,y,t,run=0,tile=1,left=1,top=1;
    u16 p;
    load_arena(campaign.stage);w=*src++;h=*src++;
    world_w=w+2;world_h=h+2;
    if (world_w<VIEW_W) {left+=(VIEW_W-world_w)/2;world_w=VIEW_W;}
    if (world_h<VIEW_H) {top+=(VIEW_H-world_h)/2;world_h=VIEW_H;}
    memset(world,0,sizeof(world)); memset(tile_low,0,1024);memset(tile_high,0,832);
    memset(actor,0,sizeof(actor));memset(shot,0,sizeof(shot));
    memset(route,255,sizeof(route));
    memset(fire_timer,0,sizeof(fire_timer));memset(burn,0,sizeof(burn));memset(tile_burn,0,sizeof(tile_burn));
    rocket_slot=255;beam_count=charge=last_fire=0;
    enemy_reset();targets=bunkers=0;
    for (y=top-1;y<=top+h;++y) for (x=left-1;x<=left+w;++x) {
        p=CELL(x,y);
        if (x<left || y<top || x>=left+w || y>=top+h) {world[p]=STONE;continue;}
        if (!run) {tile=*src++;run=1;if (tile&128) {tile&=127;run=*src++;}}
        --run;t=tile;
        if (t==START) {px=center(x);py=center(y);t=DUST;}
        if (t>=DEPOT && t<=30) {
            enemy_site(p,t);++targets;if (t<BOSS) ++bunkers;
        }
        if (t==DUST && ((x^y)&1)) t=DUST2;
        world[p]=t;set_value(p,durability(t));
    }
    max_hp=hull_hp[campaign.armor];
    if (campaign.difficulty<2) max_hp=(u32)max_hp*100/(campaign.difficulty?85:70);
    hp=max_hp;
    heading=24;hull=6;iframes=40;cooldown=0;memcpy(ammo,campaign.stock,sizeof(ammo));
    tick=aim_clock=drive_fraction=weapon=generation=blast_count=0;
    earnings=loose=collected=flash_time=ice_pos=bomb_pos=0;
    loot_row=loot_active=frozen=player_burn=0;path_read=path_write=queue;route_root=0;route_dirty=1;
    view_x=view_y=255;
    reset_sight();
    mode=FIELD;
    draw_field();reset_gun_clock();
}

void sync_ammo(void) {memcpy(campaign.stock,ammo,sizeof(ammo));}

void new_campaign(void)
{
    memset(&campaign,0,sizeof(campaign));
    campaign.difficulty=default_difficulty;menu_item=0;start_stage();
}

static void update_loot(void)
{
    u8 now,t;u16 p,end;
    flash_time+=frame_steps;
    if (player_burn) {
        u8 n=player_burn<frame_steps?player_burn:frame_steps;
        player_burn-=n;hurt_player(2*n);
    }
    if (bomb_pos && (i16)(flash_time-tile_value(bomb_pos))>=0) {
        p=bomb_pos;bomb_pos=0;
        if (world[p]==BOMB_BONUS) {
            replace(p,DUST);
            explode(center(p&31),center(p>>5),1000,46,0);
            if (target_range(px,py,center(p&31),center(p>>5))<46) hurt_player(200);
        }
    }
    if (!loot_active) return;
    if (++loot_row>=world_h) loot_row=0;
    p=CELL(0,loot_row);end=p+world_w;now=flash_time>>5;
    while (p<end) {
        t=world[p];
        if ((t==COIN || t==MEDKIT || t==SHELLS || t==ICE) &&
            ((now-(tile_high[p]>>2))&63)<32) {
            if (t==COIN) loose-=quantity(p);
            if (t==ICE) ice_pos=0;
            replace(p,DUST);
        }
        ++p;
    }
}

void play_tick(void)
{
    ++tick;
    if (iframes) --iframes;
    elapsed();beam_count=0;
    drive();
    paths();
    if (frozen) frozen=frozen>frame_steps?frozen-frame_steps:0;
    else enemy_tick();
    advance_shots();heat();
    blast();update_loot();
    if (!hp || !targets) {
        if (hp) {if (loose) collect(loose);sync_ammo();}
        campaign.cash+=earnings;menu_item=0;
        if (!hp) { mode=DEFEAT;sound(BOOM_SOUND); }
        else {
            ++campaign.stage;
            if (campaign.stage>campaign.unlocked) campaign.unlocked=campaign.stage;
            mode=campaign.stage==15?VICTORY:GARAGE;
            sound(CLEAR_SOUND);
        }
        notice=0;
        draw_screen();
    } else render_frame();
}
