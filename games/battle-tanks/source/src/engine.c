#include "game.h"

Shot shots[MAXSHOT];
u16 volley_no;
u8 live_shots,terrain_dirty;
static u8 fire_held,weapon_chord;
static u8 root(u16 n);
/* One artillery notebook per CPU, kept only for the current battlefield. */
#define NO_LANDING 999
#define ON_TARGET 1000
static s16 landing[MAXP];
static u8 enemy[MAXP],short_power[MAXP],long_power[MAXP],ridge[MAXP],last_weapon[MAXP];

#pragma codesize(push, 100)
static void redraw(void){clear_screen();header("BATTLE TANKS / PLAN YOUR VOLLEY");field();hud();}

void new_round(void) {
    u16 x,start,end;u8 a,b,i; s16 diff;
    round_no++;if(!round_no)round_no=1;
    volley_no=0;fire_held=weapon_chord=0;memset(TRAILS,0,TRAIL_BYTES);memset((u8*)TRAIL_OWNERS,0,FIELD_CELLS);
    round_draw=0;
    a=80+random8()%96;start=0;
    for(i=0;i<hills;i++){
        end=((u16)(i+1)*320)/hills;b=80+random8()%96;diff=(s16)b-a;
        for(x=start;x<end;x++)terrain[x]=a+(diff*ease[((x-start)*64)/(end-start)])/256;
        start=end;a=b;
    }
    for(i=0;i<count;i++){
        enemy[i]=MAXP;
        players[i].x=16+((u16)i*286)/(count-1);
        players[i].y=terrain[players[i].x]-1;players[i].hp=100;
        players[i].angle=players[i].x<160?45:135;players[i].power=75;
        players[i].weapon=0;players[i].ready=players[i].poison=0;
    }
    wind=(random8()%13)-6;active_player=0;selected=0;phase=AIM;
    redraw();release_input();
}
u8 alive_count(void){u8 i,n=0;for(i=0;i<count;i++)if(players[i].hp)n++;return n;}

static u8 nearest(u8 owner,s16 x){
    u8 i,best=owner;s16 d,bestd=32767;
    for(i=0;i<count;i++)if(i!=owner&&players[i].hp){d=abs((s16)players[i].x-x);if(d<bestd){bestd=d;best=i;}}
    return best;
}

static void computer_aim(void){
    u8 i=active_player,target=enemy[i],a,base,roll,k;
    s16 gap,p,step;
    Player* pl=&players[i];
    if(target==MAXP||!players[target].hp){
        enemy[i]=target=nearest(i,pl->x);
        short_power[i]=long_power[i]=0;
        landing[i]=NO_LANDING;
        base=root(abs((s16)pl->x-players[target].x)*32);
        roll=random8();
        a=48+(roll&15);
        pl->angle=pl->x<players[target].x?a:180-a;
        p=(s16)base-base/4+(roll>>4)-8;
        pl->power=p<20?20:p;
        pl->weapon=0;
        return;
    }
    if(pl->hp<45&&pl->ammo[15]){pl->weapon=15;return;}
    if(landing[i]==ON_TARGET){
        k=last_weapon[i];
        pl->weapon=pl->ammo[k]?k:0;
        return;
    }
    pl->weapon=0;
    for(k=14;k;k--)if(pl->ammo[k]){pl->weapon=k;break;}
    if(landing[i]==NO_LANDING)return;
    gap=(s16)players[target].x-landing[i];
    if(pl->x>players[target].x)gap=-gap;
    p=pl->power;
    a=pl->angle>90?180-pl->angle:pl->angle;
    /* Raise the barrel if the shell ran into a slope on the way up. */
    if(gap>0&&ridge[i]&&a<75){a+=6;short_power[i]=long_power[i]=0;}
    else if(gap>0)short_power[i]=pl->power;
    else long_power[i]=pl->power;
    if(short_power[i]&&long_power[i]&&short_power[i]+1<long_power[i])
        p=(short_power[i]+(u16)long_power[i])/2;
    else{
        /* Adjacent powers straddle the target. Try a slightly different arc. */
        if(short_power[i]&&long_power[i]){
            a=a<70?a+3:a-5;short_power[i]=long_power[i]=0;
        }
        step=1+abs(gap)/8;if(step>24)step=24;
        p+=gap>0?step:-step;
    }
    pl->power=p<12?12:p>150?150:p;
    pl->angle=pl->x<players[target].x?a:180-a;
}

static void change_weapon(s8 dir){
    Player* p=&players[active_player];u8 n=0,slot=0;
    while(weapon_order[slot]!=p->weapon)slot++;
    do {slot=(slot+dir)&15;p->weapon=weapon_order[slot];n++;}while(p->weapon&&!p->ammo[p->weapon]&&n<16);
    selected=2;hud();sound(2);
}

static void commit(void){
    u8 i;Player* p=&players[active_player];
    if(p->weapon&&!p->ammo[p->weapon])return;
    p->ready=1;fire_held=weapon_chord=0;sound(2);
    for(i=0;i<count;i++)if(players[i].hp&&!players[i].ready){
        active_player=i;selected=0;field();hud();return;
    }
    launch();
}

void credit(u8 i,u16 amount){
    players[i].money=players[i].money>60000U-amount?60000U:players[i].money+amount;
}

void end_round(u8 draw){
    u8 i;
    round_draw=draw||!alive_count();
    for(i=0;i<count;i++){
        credit(i,50);
        if(!draw&&players[i].hp){players[i].points+=100;credit(i,5000);}
    }
    phase=RESULTS;
}

void aim_loop(void){
    Player* p=&players[active_player];u8 dirty=0,oldangle=p->angle;
    poll();
    if(command==KEY_F1){pause_menu();if(phase==AIM)redraw();return;}
    if(command==KEY_F4){end_round(1);return;}
    if(command==KEY_F7){help();redraw();}
    if(command==KEY_F2){rename_player();hud();}
    if(p->cpu){computer_aim();hud();commit();return;}
    if(event&FIRE)fire_held=1;
    if((input&(FIRE|UP))==(FIRE|UP)){
        fire_held=weapon_chord=0;pause_menu();if(phase==AIM)redraw();return;
    }
    if(input&FIRE){
        if(event&(LEFT|RIGHT)){weapon_chord=1;change_weapon(event&LEFT?-1:1);}
    }else{
        if(event&LEFT){if(p->angle<180)p->angle++;selected=0;dirty=1;}
        if(event&RIGHT){if(p->angle)p->angle--;selected=0;dirty=1;}
        if(event&UP){if(p->power<255)p->power++;selected=1;dirty=1;}
        if(event&DOWN){if(p->power>10)p->power--;selected=1;dirty=1;}
        if(fire_held){fire_held=0;if(!weapon_chord){commit();return;}weapon_chord=0;}
    }
    if(command==KEY_F3){weapon_info();}
    if(dirty){if(p->angle!=oldangle)aim_barrel(oldangle);hud();}
}

#pragma codesize(pop)
static void shot_pixel(s16 x,s16 y,u8 weapon){
    if(x<1||x>317||y<57||y>189)return;
    pixel(x,y,2);pixel(x,y+1,2);
    if(weapon==6){line(x-3,y-4,x+3,y-4,2);pixel(x-3,y-3,2);pixel(x+3,y-3,2);}
}

static void spawn(u8 owner,u8 weapon,u8 angle,u8 power){
    u8 n;Shot* s;
    for(n=0;n<MAXSHOT;n++)if(!shots[n].active)break;
    if(n==MAXSHOT)return;s=&shots[n];memset(s,0,sizeof(Shot));
    s->active=1;s->owner=owner;s->weapon=weapon;
    s->x=players[owner].x*16+(costab[angle]*7)/8;
    s->y=(s16)(players[owner].y-4)*16-(sintab[angle]*7)/8;
    s->vx=(costab[angle]*(s16)power)/127;
    s->vy=-(sintab[angle]*(s16)power)/127;
    s->oldx=s->x/16;s->oldy=s->y/16;
    s->target=nearest(owner,players[owner].x);
    if(players[owner].cpu&&enemy[owner]<count)s->target=enemy[owner];
    else if(weapon==13){n=random8()%count;if(n!=owner&&players[n].hp)s->target=n;}
    shot_pixel(s->oldx,s->oldy,weapon);live_shots++;
}

static u8 root(u16 n){
    u16 bit=0x4000,result=0;
    while(bit>n)bit>>=2;
    while(bit){if(n>=result+bit){n-=result+bit;result=(result>>1)+bit;}else result>>=1;bit>>=2;}
    return (u8)result;
}
static void ring(s16 cx,s16 cy,u8 radius){
    s16 x=radius,y=0,err=1-radius;
    while(x>=y){
        if(cy+y>=56&&cy+y<192){pixel(cx+x,cy+y,2);pixel(cx-x,cy+y,2);}
        if(y&&cy-y>=56&&cy-y<192){pixel(cx+x,cy-y,2);pixel(cx-x,cy-y,2);}
        if(x!=y){
            if(cy+x>=56&&cy+x<192){pixel(cx+y,cy+x,2);if(y)pixel(cx-y,cy+x,2);}
            if(cy-x>=56&&cy-x<192){pixel(cx+y,cy-x,2);if(y)pixel(cx-y,cy-x,2);}
        }
        y++;if(err<0)err+=2*y+1;else{x--;err+=2*(y-x)+1;}
    }
}

#pragma codesize(push, 100)
static void hurt(u8 i,u8 damage,u8 owner){
    if(!players[i].hp)return;
    if(damage>players[i].hp)damage=players[i].hp;
    players[i].hp-=damage;
    if(i!=owner&&owner<count&&players[owner].cpu&&players[i].hp){
        if(landing[owner]!=ON_TARGET||enemy[owner]>=count||!players[enemy[owner]].hp){
            enemy[owner]=i;landing[owner]=ON_TARGET;
            short_power[owner]=long_power[owner]=0;
        }
    }
    if(i!=owner&&owner<count){players[owner].points+=damage;credit(owner,damage>50?5000:(u16)damage*100);}
    if(!players[i].hp){players[i].ready=1;players[i].poison=0;}
}

void explode(s16 x,s16 y,u8 weapon,u8 owner){
    u8 r=radii[weapon],i,k,depth,damage; s16 dx,dy,xx,ny;u16 d;
    if(x<0)x=0;if(x>319)x=319;if(y<56)y=56;if(y>191)y=191;
    sound(1);
    for(k=3;k<r;k+=5){ring(x,y,k);poll();ring(x,y,k);}
    ring(x,y,r);poll();poll();ring(x,y,r);
    for(i=0;i<count;i++)if(players[i].hp){
        dx=abs((s16)players[i].x-x);dy=abs((s16)players[i].y-y);
        if(dx>r+6||dy>r+6)continue;
        d=dx*dx+dy*dy;
        if(d<(u16)(r+6)*(r+6)){
            depth=root(d);damage=120-(u16)depth*100/(r+6);
            if(weapon==10){players[i].poison=3;damage=30;}
            hurt(i,damage,owner);
        }
    }
    if(weapon!=10){
        for(dx=-(s16)r;dx<=(s16)r;dx++){
            xx=x+dx;if(xx<0||xx>319)continue;
            depth=root((u16)r*r-dx*dx);
            if(y-depth>terrain[xx])continue;
            ny=y+depth;if(ny>190)ny=190;
            if(ny>terrain[xx])terrain[xx]=ny;
        }
    }
    terrain_dirty=1;
}

static void end_flight(Shot* s,s16 x){
    u8 i=s->owner; s16 target_x;
    s->active=0;live_shots--;
    if(!players[i].cpu||enemy[i]>=count||landing[i]==ON_TARGET)return;
    target_x=players[enemy[i]].x;
    /* A spread fires several shells. Range from its closest impact. */
    if(landing[i]==NO_LANDING||abs(x-target_x)<abs(landing[i]-target_x)){
        landing[i]=x;ridge[i]=s->vy<0;
    }
}

static void finish_shot(Shot* s,s16 x,s16 y){
    end_flight(s,x);
    explode(x,y,s->weapon,s->owner);
}
#pragma codesize(pop)

static void remember_trail(s16 x,s16 y,u8 owner){
    u16 index;u8 row;
    if(x>=0&&x<320&&y>=56&&y<192){
        row=(y-56)/3;y=56+row*3;
        TRAILS[(u16)row*20+(x/16)]|=128>>((x/2)&7);
        index=((u16)(y-56)/8)*40+x/8;
        if(!(TRAIL_OWNERS[index]&15))TRAIL_OWNERS[index]=tank_colors[owner];
    }
}

void review_volley(void){
    u8 row,col,b,bits;u16 x;u8 y;
    phase=REVIEW;field();hud();
    for(row=0;row<46;row++)for(col=0;col<20;col++){
        bits=TRAILS[(u16)row*20+col];if(!bits)continue;
        y=56+row*3;
        for(b=0;b<8;b++)if(bits&(128>>b)){
            x=(u16)col*16+b*2;if(y<terrain[x])trace_pixel(x,y,(TRAIL_OWNERS[((u16)(y-56)/8)*40+x/8]&15)-1);
        }
    }
    release_input();do{poll();}while(!(event&FIRE));release_input();
}

/* Every projectile advances before the next simulation tick. The engine
   uses signed 12.4 coordinates and samples the path to avoid tunnelling. */
void step_shots(void){
    u8 n,i,steps,j;Shot* s;s16 px,py,ox,oy,dx,dy,tx,ty;
    for(n=0;n<MAXSHOT;n++){
        s=&shots[n];if(!s->active)continue;
        remember_trail(s->oldx,s->oldy,s->owner);
        shot_pixel(s->oldx,s->oldy,s->weapon);
        ox=s->x/16;oy=s->y/16;s->age++;
        if(s->age>450){end_flight(s,ox);continue;}
        if(s->mode==1){
            px=ox+(s->vx<0?-1:1);
            if(px<1||px>318||s->age>90){finish_shot(s,ox,terrain[ox]);continue;}
            if(terrain[px]<terrain[ox] && s->age>5){finish_shot(s,ox,terrain[ox]);continue;}
            s->x=px*16;s->y=(terrain[px]-2)*16;
        }else if(s->mode==3){
            tx=players[s->target].x;
            px=ox+(ox<tx?1:-1);py=terrain[px]+2;
            s->x=px*16;s->y=py*16;
            if(abs(px-tx)<5||s->age>220){finish_shot(s,px,terrain[px]);continue;}
        }else{
            s->x+=s->vx;s->y+=s->vy;
            if(s->weapon==6 && s->vy>=0){s->vy=10;s->vx=(s->age&3)?0:wind*2;}
            else s->vy+=2;
            if(s->weapon==8 && s->vy>=0)s->vx=0;
            else if((s->age&15)==0 && s->weapon!=6)s->vx+=wind;
            if(s->weapon==13&&players[s->target].hp){
                tx=players[s->target].x*16;
                if(s->x<tx)s->vx+=3;else s->vx-=3;
                if(s->vx>90)s->vx=90;if(s->vx<-90)s->vx=-90;
            }
        }
        px=s->x/16;py=s->y/16;
        if(px<1||px>318){
            if(s->weapon==9&&s->bounces<4){s->bounces++;px=px<1?1:318;s->x=px*16;s->vx=-s->vx;}
            else{end_flight(s,px);continue;}
        }
        if(py>=192){finish_shot(s,px,190);continue;}
        dx=px-ox;dy=py-oy;steps=(u8)(abs(dx)>abs(dy)?abs(dx):abs(dy));if(!steps)steps=1;
        if(steps>24)steps=24;
        for(j=1;j<=steps;j++){
            tx=ox+(dx*j)/steps;ty=oy+(dy*j)/steps;
            if(tx<0||tx>=320||ty<56||ty>=192)continue;
            for(i=0;i<count;i++)if(players[i].hp && !(i==s->owner&&s->age<5)){
                if(abs(tx-(s16)players[i].x)<=3 && abs(ty-(s16)players[i].y+1)<=3){finish_shot(s,tx,ty);break;}
            }
            if(!s->active)break;
            if(s->mode!=3 && s->mode!=1 && ty>=terrain[tx]){
                if(s->weapon==5){
                    s->mode=1;s->age=0;s->x=tx*16;s->y=(terrain[tx]-2)*16;
                    s->vx=terrain[tx>0?tx-1:0]>terrain[tx<319?tx+1:319]?-16:16;break;
                }
                if(s->weapon==7){s->mode=3;s->age=0;s->x=tx*16;s->y=terrain[tx]*16;break;}
                if(s->weapon==12&&s->bounces<3){
                    s->bounces++;s->vy=-abs(s->vy)*3/4;if(s->vy>-20)s->vy=-20;
                    s->y=(terrain[tx]-3)*16;s->x=tx*16;break;
                }
                finish_shot(s,tx,ty);break;
            }
        }
        if(s->active){s->oldx=s->x/16;s->oldy=s->y/16;remember_trail(s->oldx,s->oldy,s->owner);shot_pixel(s->oldx,s->oldy,s->weapon);}
    }
    if(terrain_dirty){
        for(n=0;n<MAXSHOT;n++)if(shots[n].active)shot_pixel(shots[n].oldx,shots[n].oldy,shots[n].weapon);
        for(i=0;i<count;i++)if(players[i].hp){
            j=players[i].y;players[i].y=terrain[players[i].x]-1;
            if(players[i].y>j+8)hurt(i,(players[i].y-j)/2,i);
        }
        field();hud();
        for(n=0;n<MAXSHOT;n++)if(shots[n].active)shot_pixel(shots[n].oldx,shots[n].oldy,shots[n].weapon);
        terrain_dirty=0;
    }
    /* A single whistle follows an airborne shot; impacts have sound priority. */
    i=0;
    for(n=0;n<MAXSHOT;n++)if(shots[n].active&&!shots[n].mode){
        py=shots[n].y/16;if(py<0)py=0;if(py>191)py=191;
        i=18+(191-py)/4;break;
    }
    flight_sound(i);
}

void prepare_volley(void){
    u8 i,w;Player* p;
    phase=SALVO;volley_no++;memset(shots,0,sizeof(shots));memset(TRAILS,0,TRAIL_BYTES);memset((u8*)TRAIL_OWNERS,0,FIELD_CELLS);live_shots=terrain_dirty=0;flight_sound(0);
    header("BATTLE TANKS / SIMULTANEOUS VOLLEY");
    field();hud();
    for(i=0;i<count;i++)if(players[i].hp){
        p=&players[i];w=p->weapon;
        if(w && p->ammo[w])p->ammo[w]--;
        if(w==15){p->hp=p->hp>60?100:p->hp+40;p->poison=0;continue;}
        if(p->cpu){last_weapon[i]=w;landing[i]=NO_LANDING;}
        if(w==11)w=random8()%15;
        if(w==14){
            spawn(i,1,p->angle>7?p->angle-7:0,p->power);
            spawn(i,1,p->angle<173?p->angle+7:180,p->power);
            spawn(i,1,p->angle,p->power);
        }else spawn(i,w,p->angle,p->power);
    }
    sound(0);
}
void finish_volley(void){
    u8 i;
    flight_sound(0);
    for(i=0;i<count;i++){
        if(players[i].poison&&players[i].hp){players[i].poison--;hurt(i,10,i);}
        players[i].ready=0;
        if(players[i].weapon&&!players[i].ammo[players[i].weapon])players[i].weapon=0;
    }
    if(alive_count()<2){end_round(0);return;}
    active_player=0;while(!players[active_player].hp)active_player++;
    phase=AIM;selected=0;clear_traces();field();hud();release_input();
}
void launch(void){
    u8 delay,batch;
    prepare_volley();
    while(live_shots){
        batch=speed==9?3:speed==8?2:1;
        do{step_shots();}while(--batch&&live_shots);
        delay=10-speed;
        do {poll();
            if(command==KEY_F1){
                text_field(1,6,38,"PAUSED - F1 OR FIRE TO RESUME");release_input();
                do{poll();}while(command!=KEY_F1&&!(event&FIRE));
                text_field(1,6,38,"SHOTS IN FLIGHT  F1 PAUSE  F5 SOUND");release_input();
            }
        }while(--delay);
    }
    review_volley();finish_volley();
}
