#include "pacxon.h"
#include <string.h>

const u8 stages[20][GHOST_TYPES+2]={
#include "../assets/levels.inc"
};
Ghost ghosts[GHOSTS];
u8 board[1000],pickup[1000],stage,lives,percent,peak,count,facing,clock30,field_dirty;
u16 rows[23],filled,trail_len,powers[4],px,py;
uint32_t score;
/* A closed trail is marked on the board. Flood may reuse its list until the next cut. */
u16 trail[672];
static u16 fire_front,fire_back,bonus_points,life_points;
const u8 reserves[3]={5,3,1};
static u8 rail_speed,hunt_x,hunt_y;
static u8 burning,fire_phase;
static u16 rng=0x9137;
static const signed char dx[4]={1,0,-1,0},dy[4]={0,1,0,-1};
static const u8 eaten[GHOST_TYPES]={100,80,150,50,125,110}, pickup_score[4]={50,100,25,25};

static u8 random8(void)
{
    rng ^= rng<<7; rng ^= rng>>9; rng ^= rng<<8;
    return (u8)rng;
}
static u16 at(int x,int y) { return rows[(u16)y>>5]+((u16)x>>5); }
static u8 solid(u8 c) { return c==EDGE || c==WALL; }
static void extra_life(void) { if(lives<99) ++lives; }
static const u8 quadrant[]={0,1,40,41};

static void stamp_item(u16 anchor,u8 first)
{
    u8 q;
    for(q=0;q<4;++q) {
        u16 p=anchor+quadrant[q];
        pickup[p]=first?first+q:0;
        tile(p);
    }
}
static void remove_item(u16 p)
{
    stamp_item(p-quadrant[(pickup[p]-1)&3],0);
}

void add_points(u16 points)
{
    u8 roll,kind,attempt;
    u16 p;
    score+=points;
    if(score>9999999UL) score=9999999UL;
    bonus_points+=points; life_points+=points;
    while(bonus_points>=500) {
        bonus_points-=500;
        roll=random8()%100;
        kind=roll<20?ICE:roll<30?POWER:roll<65?SLOW:SPEED;
        for(attempt=0;attempt<16;++attempt) {
            p=rows[1+random8()%20]+1+random8()%31;
            if(!pickup[p] && !pickup[p+1] && !pickup[p+40] && !pickup[p+41] &&
               board[p]<=WALL && board[p+1]<=WALL && board[p+40]<=WALL && board[p+41]<=WALL) {
                stamp_item(p,1+kind*4);break;
            }
        }
    }
    while(life_points>=3000) {
        life_points-=3000;
        extra_life();
        sound(16);
    }
}

static u8 ghost_speed(u8 base)
{
    u8 change=(base+2)>>2;
    if(difficulty==EASY)return base-change;
    if(difficulty==HARD)return base+change;
    return base;
}

static void spawn(Ghost* g)
{
    u8 x,y,i,kind=g->kind;
    u8 v=(kind==DRIFTER?5:kind==WISP || kind==SEEKER?3:kind==SPINNER?4:2)+stage/10;
    for(i=0;i<(kind==WISP?15:160);++i) {
        x=1+(random8()&31); y=1+random8()%21;
        if(kind==PATROLLER) {
            switch(random8()&3) {
                case 0:y=1;g->dir=RIGHT;break;
                case 1:x=32;g->dir=DOWN;break;
                case 2:y=21;g->dir=LEFT;break;
                default:x=1;g->dir=UP;
            }
        }
        if(x<3 && y<3) continue;
        if(board[rows[y]+x]==(kind==WISP?WALL:EMPTY)) break;
    }
    if(i==(kind==WISP?15:160)) {g->active=0;g->wait=147;return;}
    g->x=((u16)x<<5)+16;g->y=((u16)y<<5)+16;
    g->vx=ghost_speed((v*9+2)/5);g->vy=ghost_speed((v*6+3)/7);
    if(random8()&1) g->vx=-g->vx;
    if(random8()&1) g->vy=-g->vy;
    g->active=1;g->wait=0;
    if(kind>=SEEKER)g->wait=12+(random8()&15);
}

void load_level(void)
{
    u8 x,y,i,k;
    u16 p;
    mode=READY;
    rail_speed=ghost_speed(4+stage/5);
    hunt_x=ghost_speed(6);hunt_y=ghost_speed(5);
    memset(board,OUTSIDE,sizeof(board));
    memset(pickup,0,sizeof(pickup));memset(powers,0,sizeof(powers));
    for(y=0;y<23;++y) {
        rows[y]=(u16)(y+2)*40+3;
        for(x=0;x<34;++x) {
            p=rows[y]+x;
            board[p]=(!x || x==33 || !y || y==22)?EDGE:EMPTY;
        }
    }
    px=py=16; facing=RIGHT; count=0; clock30=0;
    trail_len=filled=burning=percent=peak=0;
    for(k=0;k<GHOST_TYPES;++k) for(i=0;i<stages[stage][k];++i) {
        ghosts[count].kind=k;spawn(&ghosts[count++]);
    }
    field_screen();
    panel();
}
void new_game(void)
{
    rng^=(u16)ticks<<8;
    if(!rng) rng=0x9137;
    score=0;stage=0;lives=reserves[difficulty];bonus_points=life_points=0;
    load_level(); sound(8);
}
void continue_game(void)
{
    score=0;lives=reserves[difficulty]+1;bonus_points=life_points=0;load_level();sound(8);
}
void start_play(void)
{
    mode=PLAY; field_screen(); actors();
}
static void die(void)
{
    if(mode!=PLAY) return;
    mode=DYING;flash=0; sound(13);
}
static void respawn(void)
{
    u8 i;
    while(trail_len) {u16 p=trail[--trail_len];board[p]=EMPTY;tile(p);}
    burning=0;px=py=16;facing=RIGHT;
    if(!lives) {mode=OVER; record_run(); panel();return;}
    --lives;
    for(i=0;i<count;++i) if(ghosts[i].active && ghosts[i].x<65 && ghosts[i].y<65) spawn(&ghosts[i]);
    start_play();
}
static void statistics(void)
{
    /* 100/672 reduces to 25/168, fitting in unsigned 16 bits. */
    percent=(u8)((filled*25)/168);
    if(percent>peak) {
        add_points((percent-peak)*stages[stage][GHOST_TYPES]);peak=percent;
    }
    hud();
}

static void capture(void)
{
    u16 p;
    u8 i;
    for(i=0;i<count;++i)
        if(ghosts[i].active && ghosts[i].kind!=WISP) flood(at(ghosts[i].x,ghosts[i].y));
    for(p=rows[0];p<rows[22]+34;++p) {
        if(board[p]==REACH) board[p]=EMPTY;
        else if(board[p]==EMPTY || board[p]==TRAIL || board[p]==BURN) {
            board[p]=WALL; ++filled; tile(p);
        }
    }
    trail_len=0;burning=0;sound(3);statistics();
    if(percent>=stages[stage][GHOST_TYPES+1]) {
        mode=CLEAR;flash=0;sound(4);panel();
    }
}
static void collect(u16 p)
{
    u8 k;
    static const u8 on[4]={1,10,5,14};
    if(!pickup[p]) return;
    k=(pickup[p]-1)>>2;
    remove_item(p);
    if(!powers[k]) {powers[k]=235;sound(on[k]);}
    add_points(pickup_score[k]);hud();
}
static void move_player(void)
{
    u8 dir=STILL,open,speed=powers[SPEED]?24:12;
    u16 old=at(px,py),p;
    int x,y;
    open=board[old]==EMPTY;
    if(held&BTN_RIGHT) dir=RIGHT;
    if(held&BTN_LEFT) dir=LEFT;
    if(held&BTN_UP) dir=UP;
    if(held&BTN_DOWN) dir=DOWN;
    if(open && (dir==STILL || dir==(facing^2))) dir=facing;
    if(dir==STILL) return;
    if(dir!=facing) {px=(px&~31u)+16;py=(py&~31u)+16;}
    facing=dir;
    x=px;y=py;
    switch(dir){case RIGHT:x+=speed;break;case DOWN:y+=speed;break;case LEFT:x-=speed;break;default:y-=speed;}
    if(x<16)x=16;if(x>1072)x=1072;if(y<16)y=16;if(y>720)y=720;
    if(x==(int)px && y==(int)py) return;
    px=x;py=y;p=at(x,y);
    if(p!=old) {
        if(board[p]==TRAIL || board[p]==BURN) {die();return;}
        if(open) {
            board[old]=TRAIL;trail[trail_len++]=old;tile(old);
            if(solid(board[p])) capture();
        }
        if(pickup[p]) collect(p);
        if(mode==PLAY && effects && (!cue || cue==11) && !request && !(clock30&3)) sound(11);
    }
}
static void ignite(u16 p)
{
    u16 i;
    if(powers[POWER] || board[p]!=TRAIL) return;
    for(i=0;i<trail_len;++i) if(trail[i]==p) {
        if(!burning) {fire_front=fire_back=i;burning=1;fire_phase=0;sound(6);}
        else {if(i>fire_front)fire_front=i;if(i<fire_back)fire_back=i;}
        board[p]=BURN;tile(p);return;
    }
}
static void advance_fire(void)
{
    if(!burning || powers[POWER]) return;
    fire_phase+=14;
    if(fire_phase<16)return;
    fire_phase-=16;
    if(fire_back) {u16 p=trail[--fire_back];board[p]=BURN;tile(p);}
    if(++fire_front>=trail_len) {die();return;}
    board[trail[fire_front]]=BURN;tile(trail[fire_front]);
}

static u8 barrier(Ghost* g,int x,int y)
{
    u16 p;
    u8 c;
    if(x<0 || y<0 || x>=1088 || y>=736) return 1;
    p=at(x,y);c=board[p];
    if(c==TRAIL) ignite(p);
    if(g->kind==CRUSHER && c==WALL && !powers[POWER]) {
        board[p]=EMPTY;--filled;tile(p);statistics();
    }
    return g->kind==WISP ? !solid(c) : c!=EMPTY;
}
static u8 open_next(Ghost* g,u8 d)
{
    int x=(g->x>>5)+dx[d],y=(g->y>>5)+dy[d];
    if(x<0 || x>=34 || y<0 || y>=23) return 0;
    return board[rows[y]+x]==EMPTY;
}
static void contour(Ghost* g)
{
    u8 speed=rail_speed, d=g->dir;
    if(powers[SLOW])speed=(speed+1)>>1;
    while(speed) {
        u8 step;
        if(!g->wait) {
            if(open_next(g,(d+3)&3)) d=(d+3)&3;
            else if(!open_next(g,d)) {
                if(open_next(g,(d+1)&3))d=(d+1)&3;
                else if(open_next(g,d^2))d^=2;
                else return;
            }
            g->dir=d;g->wait=32;
        }
        step=speed<g->wait?speed:g->wait;
        switch(d) {
            case RIGHT:g->x+=step;break;case DOWN:g->y+=step;break;
            case LEFT:g->x-=step;break;default:g->y-=step;
        }
        g->wait-=step;speed-=step;
    }
}
static void contact(Ghost* g)
{
    int x=g->x-(int)px,y=g->y-(int)py;
    int r=(g->kind==CRUSHER)?29:23;
    if(x<=-r || x>=r || y<=-r || y>=r) return;
    if(powers[POWER]) {add_points(eaten[g->kind]);sound(6);spawn(g);hud();}
    else die();
}
void move_ghost(Ghost* g)
{
    int x,y,vx,vy;
    u16 p;
    if(!g->active) {
        if(!--g->wait) spawn(g);
        return;
    }
    if(!powers[ICE]) {
        if(g->kind==PATROLLER) contour(g);
        else {
            if(g->kind>=SEEKER && !--g->wait) {
                if(g->kind==SEEKER) {
                    g->wait=36;
                    if(!powers[POWER] && !solid(board[at(px,py)])) {
                        g->vx=(g->x<(int)px)?hunt_x:-hunt_x;
                        g->vy=(g->y<(int)py)?hunt_y:-hunt_y;
                        if(g->x==(int)px)g->vx=0;
                        if(g->y==(int)py)g->vy=0;
                    }
                } else {
                    signed char old_x=g->vx;
                    g->wait=22;g->vx=-g->vy;g->vy=old_x;
                }
            }
            vx=g->vx;vy=g->vy;
            if(powers[SLOW]) {vx/=2;vy/=2;}
            x=g->x+vx;y=g->y+vy;
            if(barrier(g,x,g->y)) {g->vx=-g->vx;x=g->x;}
            if(barrier(g,x,y)) {g->vy=-g->vy;y=g->y;}
            g->x=x;g->y=y;
        }
    }
    p=at(g->x,g->y);
    if(pickup[p])remove_item(p);
    contact(g);
}
void bump_ghosts(void);
void fast_ghosts(void);
void game_tick(void)
{
    u8 i;
    static const u8 off[4]={7,9,2,15};
    ++clock30;
    if(mode==DYING) {if(++flash>=44) respawn();else actors();return;}
    move_player();
    if(mode!=PLAY)return;
    fast_ghosts();
    if(mode!=PLAY)return;
    if(!powers[ICE])bump_ghosts();
    advance_fire();
    for(i=0;i<4;++i) if(powers[i] && !--powers[i]) {sound(off[i]);hud();}
    actors();
}
