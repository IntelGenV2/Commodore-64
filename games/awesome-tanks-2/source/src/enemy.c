#include <string.h>
#include "game.h"

/* One Flash tile is 52 pixels. The C64 arena uses 16 pixels per tile and
   32 turret headings. SHOCK is unused by enemy guns and denotes a rammer. */
#define RAMMER SHOCK
#define NO_SITE 255
typedef struct {
    u8 gun,memory,visible,bearing,home,recall,wait,step_dir,goal_x,goal_y;
    u8 speed,travel,swivel;
    u16 range;
    u8 padding;
} Brain;
typedef struct {
    u16 pos,ready,scan_due;
    u8 supply,heading,scan,alert,advanced,elite,head_slot,gun,padding[2];
} Site;
Brain brain[ACTORS]; /* The sprite compositor reads each enemy's equipped gun. */
#define sites ((Site*)0xf900)
#define MAX_SITES 16
static u8 count,cursor,seed,tower_count;
static u16 clock_ticks;
static const i8 offsets[]={-32,1,32,-1};
static const u8 tower_guns[]={MINIGUN,SHOTGUN,CANNON,ROCKET,LASER,FLAME,RAIL,RICOCHET};
static const u8 boss_guns[]={SHOTGUN,CANNON,ROCKET,LASER,RICOCHET,FLAME,RAIL};
static const u8 tiers[]={MINIGUN,SHOTGUN,RICOCHET,FLAME,CANNON,ROCKET,RAMMER,LASER,RAIL};
static const u8 view_range[]={62,77,138,108,92,108,108,108,108};
static const u8 gun_range[]={52,62,77,77,62,1,71,71,71};
static const u8 gun_delay[]={8,20,25,2,25,1,30,2,25};
static const u8 tower_delay[]={5,20,5,2,20,1,30,2,28};
static const u8 tolerance[]={1,1,3,3,2,0,3,1,1};

u8 random_byte(void)
{
    seed=(seed>>1)^((seed&1)?0xb8:0);
    return seed;
}

static u8 difference(u8 a,u8 b)
{
    u8 delta=(a-b)&31;
    return delta>16?32-delta:delta;
}

static u8 adjacent_cells(u16 a,u16 b)
{
    i8 x=(a&31)-(b&31),y=(a>>5)-(b>>5);
    return x>=-1 && x<=1 && y>=-1 && y<=1;
}

/* Octagonal distance, with a small error at intermediate bearings. */
u16 target_range(u16 x,u16 y,u16 tx,u16 ty);

static u8 occupied(u16 pos)
{
    u8 i;
    for (i=0;i<ACTORS;++i) if (actor[i].hp &&
        CELL(actor[i].dest_x,actor[i].dest_y)==pos) return 1;
    return 0;
}

/* The Flash obstacle list is used for sight and hearing. Crates, barrels,
   turrets and other tanks belong to its separate friendly-fire test. */
u8 clear_line(u16 from,u16 to,u8 firing);
u8 shot_line(u16 from,u16 to);

static u8 memory_span(u8 gun)
{
    return gun==RAIL?250:gun==RAMMER?150:125;
}

u8 rocket_heading(Shot* s)
{
    u16 x=s->x>>2,y=s->y>>2;
    if (clear_line(cell_at(x,y),cell_at(px,py),0))
        return toward(s->motion,glance(px-x,py-y));
    return s->motion;
}

void enemy_hear(u16 x,u16 y,u8 radius)
{
    u8 i;u16 p=cell_at(x,y),q;
    for (i=0;i<ACTORS;++i) if (actor[i].hp && !brain[i].memory &&
        target_range(x,y,actor[i].x,actor[i].y)<radius &&
        clear_line(p,cell_at(actor[i].x,actor[i].y),0)) brain[i].memory=memory_span(brain[i].gun);
    for (i=0;i<count;++i) {
        q=sites[i].pos;
        if (world[q]>=TOWER && world[q]<BOSS && !sites[i].alert &&
            target_range(x,y,center(q&31),center(q>>5))<radius && clear_line(p,q,0)) sites[i].alert=75;
    }
}

void enemy_reset(void)
{
    memset(brain,0,sizeof(brain));memset(sites,0,MAX_SITES*sizeof(Site));
    clock_ticks=0;count=cursor=tower_count=0;seed=(91+campaign.stage+REG(0xdc04))|1;
}

void enemy_site(u16 pos,u8 type)
{
    Site* s=sites+count++;
    s->pos=pos;s->supply=6;s->scan=random_byte()&3;s->heading=s->scan*8;
    if (type>=TOWER && type<BOSS) {
        s->head_slot=tower_count++;
        s->gun=tower_guns[type-TOWER];
    }
}

u8 site_supply(u16 pos)
{
    u8 i;for (i=0;i<count;++i) if (sites[i].pos==pos) return sites[i].supply;
    return 0;
}

void enemy_site_hit(u16 pos)
{
    u8 i,j;
    for (i=0;i<count;++i) if (sites[i].pos==pos) {
        sites[i].alert=75;
        if (world[pos]<TOWER) for (j=0;j<ACTORS;++j)
            if (actor[j].hp && brain[j].home==i && !brain[j].memory) {
                brain[j].recall=1;brain[j].wait=0;
            }
        return;
    }
}

void enemy_hit(Actor* a)
{
    Brain* b=brain+(a-actor);
    if (!b->memory) enemy_hear(a->x,a->y,62);
    b->memory=memory_span(b->gun);b->wait=0;
}

u8 enemy_is_rammer(Actor* a) {return brain[a-actor].gun==RAMMER;}

static u8 spawn(u16 p,u8 kind,u8 gun,u8 home)
{
    u8 i;
    if (occupied(p) || cell_at(px,py)==p) return 0;
    for (i=0;i<ACTORS;++i) if (!actor[i].hp) {
        Actor* a=actor+i;Brain* b=brain+i;
        reset_burn(i);memset(b,0,sizeof(*b));
        a->dest_x=p&31;a->dest_y=p>>5;
        a->x=center(a->dest_x);a->y=center(a->dest_y);
        {
            static const u16 normal[]={40,80,100,160,200,350,240,320,550};
            if (kind>=BOSS) {
                a->max_hp=boss_strength(kind);
                a->hp=world[p]==kind?tile_value(p):a->max_hp;
                update_boss_bar(a);
            } else {
                a->hp=scaled_hp(normal[gun]);a->bar_segments=0;
            }
        }
        a->kind=kind;a->heading=random_byte()&31;a->cooldown=0;
        b->gun=gun;b->home=home;b->goal_x=a->dest_x;b->goal_y=a->dest_y;
        b->step_dir=(a->heading+4)>>3;b->step_dir&=3;
        refresh_targets();
        return 1;
    }
    return 0;
}

u8 crate_tank(u16 p)
{
    u8 grade=(campaign.stage>>1)+(random_byte()%3),i;
    if (grade>8) grade=8;
    if (!spawn(p,DEPOT,tiers[grade],NO_SITE)) return 0;
    for (i=0;i<ACTORS;++i) if (actor[i].hp && cell_at(actor[i].x,actor[i].y)==p) {
        actor[i].hp/=3;break;
    }
    ++targets;hud_dirty=1;return 1;
}

static void depot(Site* s,u8 slot,u8 tier)
{
    u8 i,total=0,grade=0,kind=DEPOT+tier,r;u16 n;
    if (!s->supply || (i16)(clock_ticks-s->ready)<0) return;
    for (i=0;i<ACTORS;++i) if (actor[i].hp && brain[i].home==slot) ++total;
    if (total>=4) return;
    r=random_byte();
    if (s->supply<=3) {
        if (!s->elite) grade=2;
        else if (s->advanced<2) grade=1;
    } else if (r&1) {
        if (random_byte()>168) {
            if (!s->elite) grade=2;
            else if ((random_byte()&1) && s->advanced<2) grade=1;
            else if (tier==1) kind=BOSS;
        } else if (s->advanced<2) grade=1;
        else if ((random_byte()&1) && !s->elite) grade=2;
    }
    for (i=0;i<4;++i) {
        n=s->pos+offsets[(i+r)&3];
        if (passable(world[n]) && spawn(n,kind,tiers[tier+grade],slot)) {
            --s->supply;
            if (grade==1) ++s->advanced;
            if (grade==2) ++s->elite;
            ++targets;hud_dirty=1;s->ready=clock_ticks+125;return;
        }
    }
}

static void tower(Site* s,u8 gun)
{
    u16 p=s->pos,x=center(p&31),y=center(p>>5),r=target_range(x,y,px,py),player=cell_at(px,py);
    u8 dir=0,sees=0,i,d,old=s->heading,goal;
    if (r<=185 || s->alert) dir=glance(px-x,py-y);
    if (r<=185 && (adjacent_cells(p,player) || (difference(dir,s->heading)<=7 && clear_line(p,player,0)))) sees=1;
    if (sees) s->alert=75;
    else if (s->alert) s->alert=s->alert>4?s->alert-4:0;
    if (sees || (gun==RAIL && s->alert)) {
        goal=dir;
        if (s->alert && ((clock_ticks>>3)&7)==0) enemy_hear(x,y,62);
        if (r<123 && difference(s->heading,dir)<=tolerance[gun] &&
            (i16)(clock_ticks-s->ready)>=0 && clear_line(p,player,1)) {
            enemy_fire(x+(i16)vx[s->heading]*14/16,y+(i16)vy[s->heading]*14/16,s->heading,gun,gun>=CANNON?2:1);
            s->ready=clock_ticks+tower_delay[gun];
        }
    } else {
        if ((i16)(clock_ticks-s->scan_due)>=0) {
            for (i=0;i<4;++i) {
                s->scan=(s->scan+((p&1)?1:3))&3;
                d=(s->scan+1)&3;
                if (passable(world[p+offsets[d]])) break;
            }
            s->scan_due=clock_ticks+(s->alert?10:50)+(random_byte()&7);
        }
        goal=s->scan*8;
    }
    /* Each tower is serviced once in four ticks, including on crowded maps. */
    d=s->alert?4:2;
    while (d-- && s->heading!=goal) s->heading=toward(s->heading,goal);
    if (((old+2)>>2)!=((s->heading+2)>>2) && EXPLORED[p]) draw_tile(p);
}

u8 tower_head(u8 site_offset);
u8 tower_code(u16 p)
{
    u8 i;
    for (i=0;i<count;++i) if (sites[i].pos==p) return tower_head(i<<4);
    return tile_code[TOWER];
}

void redraw_towers(void)
{
    u8 i;
    for (i=0;i<count;++i) if (EXPLORED[sites[i].pos]>=DEPOT && EXPLORED[sites[i].pos]<BOSS)
        draw_tile(sites[i].pos);
}

static void service_sites(void)
{
    Site* s;u8 type,i;
    if (!count) return;
    if (++cursor>=count) cursor=0;
    s=sites+cursor;type=world[s->pos];
    if (type>=DEPOT && type<TOWER) depot(s,cursor,type-DEPOT);
    else if (type>=BOSS && type<WOOD && spawn(s->pos,type,boss_guns[type-BOSS],NO_SITE)) replace(s->pos,DUST);
    for (i=clock_ticks&3;i<count;i+=4) {
        s=sites+i;type=world[s->pos];
        if (type>=TOWER && type<BOSS) tower(s,s->gun);
    }
}

/* Find the first step of a local patrol route. Search the five-by-five
   window used for random destinations. A recall takes successive windows
   toward the tank's parent spawner. Global pursuit uses the flow field. */
u16 patrol_cell;
u8 patrol_x,patrol_y;
u8 patrol_step(void);

static void choose_step(Actor* a,Brain* b,u16 p)
{
    u8 d;u16 q;
    if (b->memory) {
        if (b->visible && target_range(a->x,a->y,px,py)<23 && b->gun!=RAMMER) return;
        if (p==cell_at(px,py)) return;
        d=route[p]&7;
    } else {
        if (b->recall && b->home<count) {
            q=sites[b->home].pos;
            b->goal_x=q&31;b->goal_y=q>>5;
            if (target_range(a->x,a->y,center(b->goal_x),center(b->goal_y))<25) {
                b->recall=0;b->goal_x=p&31;b->goal_y=p>>5;
            }
        }
        if (b->wait) {--b->wait;return;}
        if (b->goal_x==(p&31) && b->goal_y==(p>>5)) {
            i8 gx=a->dest_x+(i8)(random_byte()%5)-2,gy=a->dest_y+(i8)(random_byte()%5)-2;
            if (gx>0 && gy>0 && gx<world_w && gy<world_h && passable(world[CELL(gx,gy)])) {
                b->goal_x=gx;b->goal_y=gy;
            }
            b->wait=18+(random_byte()&31);return;
        }
        patrol_cell=p;patrol_x=b->goal_x;patrol_y=b->goal_y;
        d=patrol_step();
        if (d>=4) {b->goal_x=p&31;b->goal_y=p>>5;b->recall=0;}
    }
    if (d>=4) return;
    q=p+offsets[d];
    if (!passable(world[q]) || occupied(q)) return;
    a->dest_x=q&31;a->dest_y=q>>5;b->step_dir=d;
}

static void mobile(u8 slot,u8 elapsed)
{
    Actor* a=actor+slot;Brain* b=brain+slot;
    u8 gun=b->gun,dir,adjacent,limit,speed,step,turn_goal;
    u16 r=b->range,p=cell_at(a->x,a->y),player=cell_at(px,py),x,y;
    if (((tick+slot)&3)==0 || !r) {
        b->range=r=target_range(a->x,a->y,px,py);
        dir=b->bearing;
        if (r<=(a->kind>=BOSS?108:view_range[gun]) || b->memory) dir=glance(px-a->x,py-a->y);
        adjacent=adjacent_cells(p,player);
        b->bearing=dir;
        b->visible=r<(a->kind>=BOSS?108:view_range[gun]) &&
            (adjacent || ((b->memory || difference(dir,a->heading)<=5) && clear_line(p,player,0)));
        if (b->visible && (!b->memory || ((tick+slot)&15)==0)) enemy_hear(a->x,a->y,62);
    }
    if (b->visible) {b->memory=memory_span(gun);b->recall=0;}
    else if (b->memory) --b->memory;
    if (gun==RAMMER && b->memory && r<16) {hit_actor(a,65535u);return;}
    turn_goal=b->visible?b->bearing:((b->step_dir+3)&3)*8;
    b->swivel+=(a->kind>=BOSS?8:6+(campaign.stage>>1))*elapsed;
    while (b->swivel>=16) {b->swivel-=16;a->heading=toward(a->heading,turn_goal);}
    if (b->visible || (gun==RAIL && b->memory)) {
        limit=gun_range[gun]+campaign.stage*(gun==CANNON||gun==RICOCHET?3:2);
        if (a->kind>=BOSS) limit+=limit/3;
        if (a->cooldown) --a->cooldown;
        else if (gun!=RAMMER && r<limit && difference(a->heading,b->bearing)<=tolerance[gun] &&
                 clear_line(p,player,1)) {
            enemy_fire(a->x,a->y,a->heading,gun,a->kind>=BOSS?2:1);
            a->cooldown=(a->kind>=BOSS && gun==RICOCHET)?8:gun_delay[gun];
        }
    }
    x=center(a->dest_x);y=center(a->dest_y);
    if (a->x==x && a->y==y) {
        if (b->wait>elapsed) {b->wait-=elapsed;return;}
        choose_step(a,b,p);
        x=center(a->dest_x);y=center(a->dest_y);
    }
    if (a->x==x && a->y==y) {b->speed=b->travel=0;return;}
    speed=a->kind>=BOSS?(gun==SHOTGUN?30:39):gun==ROCKET?30:gun==RAMMER?25:21+campaign.stage*2;
    if (b->speed<speed) {b->speed+=elapsed;if (b->speed>speed) b->speed=speed;}
    b->travel+=b->speed*elapsed;step=b->travel>>4;b->travel&=15;
    if (a->x<x) a->x+=step>x-a->x?x-a->x:step;
    else if (a->x>x) a->x-=step>a->x-x?a->x-x:step;
    else if (a->y<y) a->y+=step>y-a->y?y-a->y:step;
    else if (a->y>y) a->y-=step>a->y-y?a->y-y:step;
}

void enemy_tick(void)
{
    u8 i;
    ++clock_ticks;
    service_sites();
    for (i=0;i<ACTORS;++i) if (actor[i].hp) {
        Brain* b=brain+i;
        if (!b->memory && !b->visible && b->range>view_range[b->gun]+16) {
            if (((tick+i)&3)==0) mobile(i,4);
        } else mobile(i,1);
    }
}
