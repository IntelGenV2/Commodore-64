#include <string.h>
#include "game.h"

u8 hud_dirty,radar_dirty;
u8 tower_wear;
u8 hull_hit,hull_segments,hull_critical;
void health_meter(void);
u8 overlay_count;
static u8 fx_next;
extern u16 overlay_pos[60];
static u16 fx_x[4],fx_y[4];
extern u8 old_code[60],old_ink[60];
static u8 fx_life[4];
#define radar_pixels ((u8*)0xfe00)
/* Shipped maps end before row 25. The tails of the exploration and
   low-HP planes are available to the radar and are cleared on deployment. */
#define radar_ink ((u8*)0xfd40)
#define dirty_ids ((u8*)0xfd80)
#define terrain_dirty ((u8*)0xfdc0)
#define marked ((u8*)0xc740)
static u8 dirty_count;
static u16 blip[ACTORS+1];
static u8 last_aim,ray_seen[32];
static u16 last_sight;
static u8 button_index;
u8 last_body[ACTORS];
static const char* const gun_names[]={"minigun","shotgun","ricochet","flame","cannon","shock","rockets","laser","railgun","mines"};
static const char* const hull_names[]={"armor","movement speed","turret rotation","sight range"};
static const char* const hull_help[]={"increases maximum hull strength","drives faster in every direction",
    "turns the gun faster with a and s","reveals a wider, longer sight cone"};
static const char* const gun_help[]={
    "fires the minigun more often",
    "fires a widening pellet volley", "hold space to charge, release to fire",
    "sprays a short cone of fire", "fires a heavy shell",
    "arcs to nearby enemy tanks", "blasts a whole cluster of tiles",
    "continuous beam while space is held", "pierces targets, losing 50 per hit", "f7 drops a proximity mine"
};
static void put(u8 x,u8 y,const char* str,u8 ink)
{
    u16 pos=y*40u+x;
    while (*str) {
        u8 c=*str++;
        SCREEN[pos]=(c>=64)?(c&31):c;
        COLOR[pos++]=ink;
    }
}

static void digits(u8 x,u8 y,u16 n,u8 width,u8 ink)
{
    u16 pos=y*40u+x+width;
    while (width--) {
        --pos;
        SCREEN[pos]='0'+(n%10); COLOR[pos]=ink;n/=10;
    }
}

/* Decimal money is formatted only when the wallet changes. */
static void money(u8 x,u8 y,u32 value)
{
    char buf[11];u8 i=10;
    buf[i]=0;
    do {buf[--i]='0'+(u8)(value%10);value/=10;} while (value);
    put(x,y,buf+i,7);
}

static void rule(u8 y,u8 ink)
{
    memset(SCREEN+y*40u,45,40);memset(COLOR+y*40u,ink,40);
}

static void button(u8 y,const char* key,const char* label)
{
    if (menu_item==button_index++) put(2,y,">",13);
    put(4,y,key,7);
    put(9,y,label,1);
}

static void page(const char* title)
{
    put(2,1,"awesome tanks 2",12);
    rule(3,11);put(4,5,title,13);
}

static void garage(void)
{
    page("field garage");
    put(4,7,"next sector",12);digits(16,7,campaign.stage+1,2,1);
    put(23,7,"cash",12);money(28,7,campaign.cash);
    button(10,"f3","hull upgrades");
    button(13,"f5","gun upgrades");
    button(17,"f1","deploy   < > sector");
    button(20,"f7","save to drive 8");
    if (notice) put(4,23,notice,7);
}

static void shop(void)
{
    u8 guns=mode==GUN_SHOP,n=guns?GUNS:4,i,ink;
    u16 cost;
    page(guns?"gun upgrades":"hull upgrades");
    put(25,5,"$",7);money(26,5,campaign.cash);
    put(4,7,"equipment",12);put(23,7,"rank",12);put(31,7,"cost",12);
    for (i=0;i<n;++i) {
        ink=i==shop_item?13:1;
        if (i==shop_item) put(2,8+i,">",7);
        put(4,8+i,guns?gun_names[i]:hull_names[i],ink);
        if (guns && i && !*upgrade_rank(i)) put(22,8+i,"buy",ink);
        else {digits(23,8+i,*upgrade_rank(i)-(guns && i?1:0),1,ink);put(24,8+i,"/5",ink);}
        cost=price(i);
        if (cost) digits(30,8+i,cost,5,7);else put(31,8+i,"max",13);
    }
    put(2,19,guns?gun_help[shop_item]:hull_help[shop_item],12);
    put(2,20,"return buy   up/down select   f1 back",1);
    if (guns && shop_item) {
        put(2,21,"right/f7 ammo $",12);digits(17,21,refill_cost[shop_item],3,7);
        put(22,21,"+",12);digits(23,21,refill[shop_item],3,1);
        put(28,21,"have",12);digits(33,21,campaign.stock[shop_item],4,1);
    }
    if (notice) put(2,23,notice,7);
}

void draw_screen(void)
{
    if (mode==TITLE || mode==GARAGE || mode==DEFEAT) music_track=0;
    if (mode==VICTORY) music_track=2;
    REG(0xd015)=0;REG(0xd016)=8;REG(0xd021)=0;
    memset(SCREEN,32,1000);memset(COLOR,1,1000);
    overlay_count=button_index=0;
    switch (mode) {
    case TITLE:
        show_title_font();
        rule(12,11);
        button(14,"f1","new campaign");
        button(16,"f3","settings");
        button(18,"f5","field manual");
        button(20,"f7","load from drive 8");
        if (notice) put(4,23,notice,7);
        break;
    case SETTINGS:
        page("settings");
        button(10,"f3","music");put(25,10,music_on?"on":"off",13);
        button(13,"f5","effects");put(25,13,sound_on?"on":"off",13);
        if (return_mode==TITLE) {
            button(16,"f7","difficulty");put(25,16,default_difficulty==0?"easy":default_difficulty==1?"medium":"hard",13);
        }
        button(20,"f1","back");
        break;
    case HELP:
        page("field manual");
        put(4,8,"i j k l    drive the hull",1);
        put(4,10,"a / s      turn gun left / right",1);
        put(4,12,"space      shoot (hold for auto)",1);
        put(4,14,"f1 pause   f3 gun   f5 settings",7);
        put(4,17,"destroy the vented spawners,",12);
        put(4,18,"towers and all enemy tanks.",12);
        put(4,19,"shoot crates and collect salvage.",12);
        button(22,"f1","back");
        break;
    case PAUSE:
        page("paused");
        button(9,"f1","resume");
        button(12,"f3","restart sector");
        button(15,"f5","settings");
        button(18,"f7","withdraw to garage");
        break;
    case GARAGE:garage();break;
    case HULL_SHOP:case GUN_SHOP:shop();break;
    case DEFEAT:
        page("tank destroyed");
        put(4,9,"salvage recovered",12);money(26,9,earnings);
        button(14,"f1","retry sector");
        button(17,"f3","visit garage");
        break;
    case VICTORY:
        page("campaign complete");
        put(4,9,"all 15 sectors secured.",1);
        put(4,12,"remaining credits",12);money(25,12,campaign.cash);
        button(18,"f1","return to title");
        break;
    }
    if ((mode==TITLE && !notice) || mode==SETTINGS || mode==PAUSE)
        put(4,23,"cursor up/down   return selects",12);
}

static void hud(void)
{
    static u32 cash;
    static u16 hull_value,rounds;
    static u8 gun,foes,bases;
    u8 full=hud_dirty==2;
    if (full) {
        put(31,1,"sector",3);digits(38,1,campaign.stage+1,2,1);
        put(31,10,"hp",1);put(31,13,"tanks",3);put(31,14,"bunkers",3);
        put(31,16,"credits",3);put(31,20,"weapon",3);
    }
    if (full || hull_value!=hp) {
        hull_value=hp;digits(36,10,hp,4,1);
        hull_segments=((u32)hp*8+max_hp-1)/max_hp;
        hull_critical=hp<=max_hp/3;
    }
    if (full || foes!=targets-bunkers) {foes=targets-bunkers;digits(38,13,foes,2,7);}
    if (full || bases!=bunkers) {bases=bunkers;digits(38,14,bases,2,7);}
    if (full || cash!=campaign.cash+earnings) {
        cash=campaign.cash+earnings;put(31,17,"         ",7);money(31,17,cash);
    }
    if (full || gun!=weapon) {
        put(31,21,"        ",1);put(31,21,gun_names[weapon],1);
        put(31,22,"        ",7);if (!weapon) put(31,22,"inf",7);
    }
    if (weapon && (full || gun!=weapon || rounds!=ammo[weapon])) digits(31,22,ammo[weapon],4,7);
    rounds=ammo[weapon];gun=weapon;
    hud_dirty=0;
}

static u8 camera_axis(u8 cell,u8 origin,u8 width,u8 span)
{
    u8 end=width-span;
    if (origin<=end && cell>=origin+2 && cell<origin+span-2) return origin;
    if (cell<=span/2) return 0;
    cell-=span/2;
    return cell>end?end:cell;
}

static void camera(void)
{
    u8 x=camera_axis(px>>4,view_x,world_w,VIEW_W);
    u8 y=camera_axis(py>>4,view_y,world_h,VIEW_H);
    if (x!=view_x || y!=view_y) {
        view_x=x;view_y=y;
        map_origin=EXPLORED+CELL(x,y);
        paint_view();
        redraw_towers();
    }
}

void draw_tile(u16 pos)
{
    u8 x=(pos&31)-view_x,y=(pos>>5)-view_y;
    u8 code,ink,t;
    if (x>=VIEW_W || y>=VIEW_H) return;
    t=EXPLORED[pos];code=tile_code[t];ink=tile_ink[t];
    if (t>=DEPOT && t<BOSS) {
        tower_wear=bunker_damage(pos);
        if (tower_wear) {code=tower_wear==1?248:252;ink=tower_wear==1?15:10;}
        if (t>=TOWER) code=tower_code(pos);
    }
    pos=y*80u+(x<<1);
    SCREEN[pos]=code;SCREEN[pos+1]=code+1;SCREEN[pos+40]=code+2;SCREEN[pos+41]=code+3;
    COLOR[pos]=COLOR[pos+1]=COLOR[pos+40]=COLOR[pos+41]=ink;
}

static u8 radar_index(u16 p)
{
    return ((p>>7)<<3)+((p&31)>>2);
}

static void mark(u8 idx)
{
    if (!marked[idx]) {marked[idx]=1;dirty_ids[dirty_count++]=idx;}
}

static void radar_chunk(u8 idx)
{
    u8 x,y,t;
    u16 off=(u16)idx*8;
    const u8* row=EXPLORED+CELL((idx&7)*4,(idx>>3)*4);
    static const u8 dot[4]={128,32,8,2};
    static const u8 block[4]={192,48,12,3};
    radar_ink[idx]=1;
    for (y=0;y<4;++y) {
        radar_pixels[off]=radar_pixels[off+1]=0;
        for (x=0;x<4;++x) {
            t=row[x];
            if (t>=DEPOT && t<=30) {
                radar_pixels[off]|=block[x];radar_pixels[off+1]|=block[x];radar_ink[idx]=7;
            } else if (t>=BRICK && t<COIN) radar_pixels[off]|=dot[x];
        }
        row+=32;off+=2;
    }
}

void radar_tile(u16 p)
{
    u8 idx=radar_index(p);
    terrain_dirty[idx]=1;mark(idx);
}

void reset_sight(void)
{
    dirty_count=0;memset(marked,0,56);
    memset(EXPLORED,0,1024);
    last_sight=0xffff;
}

void reveal_tile(u16 p)
{
    if (EXPLORED[p]==world[p]) return;
    if (EXPLORED[p]) last_sight=0xffff; /* A cleared wall opens the view behind it. */
    EXPLORED[p]=world[p];
    if (view_x!=255) draw_tile(p);
    radar_tile(p);
}

static void sight(void)
{
    static const u8 halves[]={4,5,6,8,11,16},length[]={9,10,11,12,13,14};
    u8 half=halves[campaign.sight],angle=(heading-half)&31,rays=half==16?32:half*2+1;
    u8 i,t;
    i8 dx,dy;
    u16 origin=CELL(px>>4,py>>4),p,x,y;
    if (origin==last_sight && (heading==last_aim || half==16)) return;
    if (origin!=last_sight) memset(ray_seen,0,sizeof(ray_seen));
    last_sight=origin;last_aim=heading;
    for (dy=-1;dy<=1;++dy) for (dx=-1;dx<=1;++dx) reveal_tile(origin+dy*32+dx);
    do {
        if (!ray_seen[angle]) {
            ray_seen[angle]=1;
            x=center(px>>4)*2;y=center(py>>4)*2;
            for (i=0;i<length[campaign.sight];++i) {
                x+=vx[angle];y+=vy[angle];p=CELL(x>>5,y>>5);
                t=world[p];
                if (EXPLORED[p]!=t) reveal_tile(p);
                if (t!=DUST && t<COIN) break;
            }
        }
        angle=(angle+1)&31;
    } while (--rays);
}

static void radar(void)
{
    u8 i,idx,mask;
    u16 p,off,attr;
    if (radar_dirty) {
        for (idx=0;idx<56;++idx) {terrain_dirty[idx]=1;mark(idx);}
        memset(blip,255,sizeof(blip));radar_dirty=0;
    }
    if (!dirty_count && (tick&3)) return;
    for (i=0;i<=ACTORS;++i) {
        p=0xffff;
        if (i==ACTORS) p=CELL(px>>4,py>>4);
        else if (actor[i].hp) {
            p=CELL(actor[i].x>>4,actor[i].y>>4);
            if (!EXPLORED[p]) p=0xffff;
        }
        if (blip[i]!=p) {
            if (blip[i]!=0xffff) mark(radar_index(blip[i]));
            if (p!=0xffff) mark(radar_index(p));
            blip[i]=p;
        }
    }
    if (!dirty_count) return;
    while (dirty_count) {
        idx=dirty_ids[--dirty_count];marked[idx]=0;
        if (terrain_dirty[idx]) {radar_chunk(idx);terrain_dirty[idx]=0;}
        off=(u16)idx*8;attr=(3+(idx>>3))*40u+31+(idx&7);
        memcpy(FONT+192*8+off,radar_pixels+off,8);
        SCREEN[attr]=192+idx;COLOR[attr]=radar_ink[idx];
    }
    for (i=0;i<=ACTORS;++i) if (blip[i]!=0xffff) {
        p=blip[i];idx=radar_index(p);off=(u16)idx*8+((p>>4)&6);
        mask=192>>((p&3)*2);
        FONT[192*8+off]|=mask;FONT[192*8+off+1]|=mask;
        COLOR[(3+(idx>>3))*40u+31+(idx&7)]=i==ACTORS?5:2;
    }
}

void burst(u16 x,u16 y)
{
    fx_next=(fx_next+1)&3;
    fx_x[fx_next]=x;fx_y[fx_next]=y;fx_life[fx_next]=8;
}

u8 tracer_col,tracer_row;
u8* tracer_glyph;
void draw_shots(void);
void draw_burning_tanks(void);
void draw_marker(u16 x,u16 y,u8 flame);
void draw_beams(void);
extern u8 tile_burn[6];
extern u16 burning_tile[6];

void render_frame(void)
{
    u8 i;
    sight();camera();
    draw_tanks();
    radar();
    if (hud_dirty) hud();
    health_meter();
    erase_shots();
    draw_shots();
    for (i=0;i<4;++i)
        if (fx_life[i]) { --fx_life[i];draw_marker(fx_x[i],fx_y[i],0); }
    for (i=0;i<6;++i) if (tile_burn[i]) {
        u16 p=burning_tile[i];
        draw_marker(center(p&31),center(p>>5),1);
    }
    draw_burning_tanks();
    draw_beams();
}

void draw_field(void)
{
    u8 i;
    music_track=1;
    show_field_font();
    memset(SCREEN,32,1000);memset(COLOR,1,1000);
    REG(0xd016)=24;REG(0xd021)=0;REG(0xd022)=9;REG(0xd023)=12;
    for (i=0;i<8;++i) FONT[160*8+i]=i==0 || i==7?0:126;
    put(1,24,"f1 pause   f3 gun   f5 setup   f7 mine",1);
    hud_dirty=2;radar_dirty=1;view_x=view_y=255;overlay_count=hull_hit=0;
    memset(fx_life,0,sizeof(fx_life));
    memset(last_body,255,ACTORS);
    render_frame();
}
