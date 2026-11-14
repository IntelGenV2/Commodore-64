#include "game.h"
#include "../assets/generated.h"

static const u8 masks[8]={128,64,32,16,8,4,2,1};
u8 muted=0;
u8 music_enabled=1,sfx_enabled=1;
u8 input,event,command;
u8 typing;
volatile u8 field_mode;
static u8 previous,oldkey,repeat,ntscskip;
const u8 tank_colors[10]={10,3,7,4,8,1,14,13,2,15};
static u8 field_valid,hud_valid,clip_attr;
u8 clip_on,clip_col,clip_row,cell_bits[8];
#define OLD_TERRAIN ((u8*)0xc600)
typedef struct {u16 x;u8 y,alive,angle,arrow;} TankView;
#define OLD_TANKS ((TankView*)0xc740)
#define OLD_HUD ((Player*)0xc780)
#define DIRTY ((u8*)0xcfa0)
static u8 old_selected,old_round,old_phase,old_active;
static s8 old_wind;
static u8 ticker_tick,ticker_offset;
static void scroll_names(void){
    u8 total=count*10,end,owner,n,color;char tail[2];
    if(total<40)total=40;
    if(++ticker_offset>=total)ticker_offset=0;
    end=ticker_offset+39;if(end>=total)end-=total;
    owner=end/10;n=end%10;color=owner<count?tank_colors[owner]<<4:0x10;
    tail[0]=owner<count&&n<strlen(players[owner].name)?players[owner].name[n]:' ';tail[1]=0;
    shift_labels();text(39,24,tail);
    if(SCREEN[999]!=color)SCREEN[999]=color;
}
void poll(void) {
    wait_frame();
    if(video_hz==60 && ++ntscskip==5){wait_frame();ntscskip=0;}
    input=scan_input();
    event=input & ~previous;
    if(input==previous){if(repeat<22)++repeat;else {event|=input&15;repeat=19;}}
    else repeat=0;
    command=key!=oldkey?key:0;
    previous=input;oldkey=key;
    if(command==KEY_F5&&!typing&&phase!=TITLE){muted^=1;silence();}
    rng+=PEEK(0xd012)+1;
    if(field_mode&&++ticker_tick==6){ticker_tick=0;scroll_names();}
}
void release_input(void) { do{poll();}while(input||key);event=command=0; }
void display_invalidate(void){field_valid=hud_valid=0;}
void clear_screen(void) { field_mode=0;POKE(0xd016,8);display_invalidate();memset(BITMAP,0,8000);memset(SCREEN,0x10,1000); }
void ink(u8 x,u8 y,u8 w,u8 h,u8 color) {
    u8 r,c;u8* dest;
    if(color==0x01)color=0x10;else if(color==0x16||color==0x1b)color=0x70;else if(color==0x0f)color=0xf0;
    for(r=0;r<h;r++){dest=SCREEN+(u16)(y+r)*40+x;for(c=0;c<w;c++)if(dest[c]!=color)dest[c]=color;}
}
void text_field(u8 x,u8 y,u8 width,const char* s){
    u8 c,r;const u8* glyph;u8* dest=BITMAP+(u16)y*320+(u16)x*8;
    while(width--&&x<40){c=*s?*s++:' ';if(c>=97&&c<=122)c-=32;
        if(c<32||c>95)c='?';glyph=font+((u16)c-32)*8;
        for(r=0;r<8;r++)if(dest[r]!=glyph[r])dest[r]=glyph[r];dest+=8;++x;}
}
void text(u8 x,u8 y,const char* s){text_field(x,y,strlen(s),s);}
void number(u8 x,u8 y,u16 n,u8 width) {
    char buf[6];u8 i=width;buf[i]=0;
    while(i){buf[--i]='0'+n%10;n/=10;}text(x,y,buf);
}
void pixel(s16 x,s16 y,u8 mode) {
    u8* p;u8 m,v,pair;if(x<0||x>319||y<0||y>199)return;
    if(clip_on){if(x/8!=clip_col||y/8!=clip_row)return;p=cell_bits+(y&7);}
    else p=BITMAP+bitmap_rows[y]+(x&~7);
    v=*p;
    if(field_mode&&y>=56&&y<192){
        m=masks[x&6];pair=m|(m>>1);
        if(mode==2)v^=m;else if(mode==3)v|=pair;else if(mode)v=(v&~pair)|m;else v&=~pair;
    }else{m=masks[x&7];if(mode==2)v^=m;else if(mode)v|=m;else v&=~m;}
    if(*p!=v)*p=v;
}
void hline(s16 x,s16 x2,u8 y,u8 mode) { while(x<=x2)pixel(x++,y,mode); }
#pragma codesize (push, 100)
void setting_box(u8 x,u8 y,u8 width){
    u16 left=(u16)x*8,right=left+(u16)width*8-1;u8 top=y*8-6,bottom=y*8+7;
    hline(left,right,top,1);hline(left,right,bottom,1);
    line(left,top,left,bottom,1);line(right,top,right,bottom,1);
}
void box(u8 x,u8 y,u8 width,u8 height){
    u16 left=(u16)x*8,right=left+(u16)width*8-1;u8 top=y*8,bottom=(y+height)*8-1;
    hline(left,right,top,1);hline(left,right,bottom,1);
    line(left,top,left,bottom,1);line(right,top,right,bottom,1);
}
void line(s16 x,s16 y,s16 x2,s16 y2,u8 mode) {
    s16 dx=abs(x2-x),sx=x<x2?1:-1,dy=-abs(y2-y),sy=y<y2?1:-1,e=dx+dy,e2,lastx=-1,lasty=-1;
    for(;;){if(!field_mode||y<56||y>=192||lastx!=(x&~1)||lasty!=y)pixel(x,y,mode);
        lastx=x&~1;lasty=y;if(x==x2&&y==y2)break;e2=e+e;
        if(e2>=dy){e+=dy;x+=sx;}if(e2<=dx){e+=dx;y+=sy;}}
}
#define ARTBUF ((u8*)0x0540)
void unpack_image(const u8* src,u8* dest,u16 length){
    u8 n,v;while(length){n=*src++;v=n&128;n=(n&127)+1;length-=n;
        if(v){v=*src++;do{*dest++=v;}while(--n);}
        else {do{*dest++=*src++;}while(--n);}
    }
}
void header(const char* title) {
    if(phase==AIM||phase==SALVO)return;
    text_field(1,0,39,title);
    ink(0,0,40,1,0x01);hline(0,319,7,1);
}
void footer(const char* label){text_field(1,24,39,label);ink(0,24,40,1,0x0f);}
void menu_rule(u8 row){
    u8 i;u8* p=BITMAP+(u16)row*320+3;
    for(i=0;i<40;i++,p+=8)*p=0xfc;
    ink(0,row,40,1,0xb0);
}
void menu_page(const char* name){
    clear_screen();text(2,1,"STUDIO 256 / BATTLE TANKS");ink(2,1,25,1,0xf0);
    menu_rule(3);text(4,5,name);ink(4,5,32,1,0x30);
}
#pragma codesize (pop)
static u8 __fastcall__ barrel_tip(u8 a){return a>90?barrel_tips[180-a]|128:barrel_tips[a];}
static void tank_body(u8 i){
    u8 r,c,bits;s16 x=players[i].x&~1,y=players[i].y;
    for(r=0;r<7;r++){
        bits=tank_rows[(i&1)*7+r];
        for(c=0;c<5;c++)if(bits&masks[c])pixel(x-4+c*2,y-6+r,1);
    }
}
void __fastcall__ aim_barrel(u8 oldangle){
    u8 angle=players[active_player].angle;
    if(barrel_tip(angle)!=barrel_tip(oldangle)){
        players[active_player].angle=oldangle;barrel(active_player);
        players[active_player].angle=angle;barrel(active_player);
    }
    OLD_TANKS[active_player].angle=angle;
}
static void draw_tank(u8 i){
    u8 yy,xx,v;u16 index; s16 x,y;
    if(players[i].hp){
        x=players[i].x;y=players[i].y;
        /* The hull uses color 2; terrain keeps its independent color 1. */
        for(yy=(y-20)/8;yy<=y/8;yy++)for(xx=(x-6)/8;xx<=(x+6)/8;xx++){
            if(clip_on){if(yy==clip_row&&xx==clip_col)clip_attr=0x50|tank_colors[i];}
            else {index=(u16)yy*40+xx;v=0x50|tank_colors[i];if(SCREEN[index]!=v)SCREEN[index]=v;}
        }
        barrel(i);
        tank_body(i);
        if(phase==AIM && i==active_player){
            line(x,y-20,x,y-16,1);hline(x-4,x+5,y-16,1);hline(x-2,x+3,y-15,1);pixel(x,y-14,1);
        }
    }
}
void tanks(void){u8 i;for(i=0;i<count;i++)draw_tank(i);}
static void dirty_rect(s16 x,s16 y,s16 right,s16 bottom){
    u8 row,col;u16 index;
    if(x<0)x=0;if(right>319)right=319;if(y<56)y=56;if(bottom>191)bottom=191;
    for(row=y/8;row<=bottom/8;row++)for(col=x/8;col<=right/8;col++){
        index=(u16)(row-7)*40+col;DIRTY[index/8]|=masks[index&7];
    }
}
static void paint_cell(u8 col,u8 row){
    u8 r,c,i,top,y;u16 x=(u16)col*8,index=(u16)row*40+col;u8* dest=BITMAP+(u16)row*320+x;
    memset(cell_bits,0,8);
    for(c=0;c<8;c+=2){
        top=terrain[x+c];if(terrain[x+c+1]<top)top=terrain[x+c+1];
        for(r=0;r<8;r++){y=row*8+r;if(y>=top)cell_bits[r]|=masks[c+1];}
    }
    clip_col=col;clip_row=row;clip_attr=0x57;clip_on=1;
    for(i=0;i<count;i++)if(players[i].hp&&players[i].x+6>=x&&players[i].x<=(x+13)&&players[i].y>=row*8&&players[i].y-22<row*8+8)draw_tank(i);
    clip_on=0;
    for(r=0;r<8;r++)if(dest[r]!=cell_bits[r])dest[r]=cell_bits[r];
    if(SCREEN[index]!=clip_attr)SCREEN[index]=clip_attr;
}
void field(void) {
    u8 b,min,t,arrow;u16 x,index;TankView* old;
    field_mode=1;
    if(!field_valid){
        render_terrain();memset(DIRTY,0,85);
        for(index=280;index<960;index++)SCREEN[index]=0x57;
        tanks();
    }else{
        for(x=0;x<320;x++)if(terrain[x]!=OLD_TERRAIN[x]){
            min=terrain[x]<OLD_TERRAIN[x]?terrain[x]:OLD_TERRAIN[x];
            t=terrain[x]>OLD_TERRAIN[x]?terrain[x]:OLD_TERRAIN[x];dirty_rect(x,min,x,t);
        }
        for(b=0;b<count;b++){
            old=&OLD_TANKS[b];arrow=phase==AIM&&b==active_player;
            if(old->x!=players[b].x||old->y!=players[b].y||old->alive!=!!players[b].hp||old->angle!=players[b].angle||old->arrow!=arrow){
                dirty_rect(old->x-6,old->y-22,old->x+6,old->y);
                dirty_rect(players[b].x-6,players[b].y-22,players[b].x+6,players[b].y);
            }
        }
        for(index=0;index<FIELD_CELLS;index++)if(DIRTY[index/8]&masks[index&7])paint_cell(index%40,7+index/40);
        memset(DIRTY,0,85);
    }
    for(b=0;b<count;b++){
        old=&OLD_TANKS[b];
        old->x=players[b].x;old->y=players[b].y;old->alive=!!players[b].hp;
        old->angle=players[b].angle;old->arrow=phase==AIM&&b==active_player;
    }
    memcpy(OLD_TERRAIN,terrain,320);field_valid=1;player_labels();
}
#define LABELBUF ((char*)0x05c0)
void player_labels(void){
    u8 col,owner,n,len,color,total=count*10;if(total<40)total=40;
    if(ticker_offset>=total)ticker_offset=0;owner=ticker_offset/10;n=ticker_offset%10;
    len=owner<count?strlen(players[owner].name):0;color=owner<count?tank_colors[owner]<<4:0x10;
    for(col=0;col<40;col++){
        LABELBUF[col]=n<len?players[owner].name[n]:' ';
        if(SCREEN[960+col]!=color)SCREEN[960+col]=color;
        if(++n==10){n=0;if(++owner==total/10)owner=0;len=owner<count?strlen(players[owner].name):0;color=owner<count?tank_colors[owner]<<4:0x10;}
    }
    LABELBUF[40]=0;text_field(0,24,40,LABELBUF);
}
void clear_traces(void){u16 i;for(i=0;i<FIELD_CELLS;i++)if(TRAIL_OWNERS[i]&15)DIRTY[i/8]|=masks[i&7];memset((u8*)TRAIL_OWNERS,0,FIELD_CELLS);}
void trace_pixel(u16 x,u8 y,u8 owner){
    (void)owner;
    if(y<terrain[x&~1]&&y<terrain[x|1])pixel(x,y,3);
}
#pragma codesize (push, 100)
static void art32(u8 x,u8 y,const u8* bits,const u8* attrs){
    u8 r;unpack_image(bits,ARTBUF,128);for(r=0;r<4;r++){
        memcpy(BITMAP+(u16)(y+r)*320+(u16)x*8,ARTBUF+r*32,32);
        memcpy(SCREEN+(u16)(y+r)*40+x,attrs+r*4,4);
    }
}
void big_icon(u8 x,u8 y,u8 index){art32(x,y,large_icons+icon_offsets[index],large_attrs+index*16);}
#pragma codesize (pop)
void hud(void) {
    Player* p=&players[active_player];u8 face=(100-p->hp)/26;
    if(!hud_valid){
        ink(0,0,40,7,0x10);text(5,2,"HP");text(18,0,"WIND");text(24,0,"ANGLE");text(33,0,"POWER");
        text(19,4,"AMMO");text(31,4,"ROUND");ink(18,0,4,3,0x70);ink(0,6,40,1,0x0f);
    }
    if(!hud_valid||memcmp(p->name,OLD_HUD->name,9))text_field(5,0,8,p->name);
    if(!hud_valid||old_active!=active_player)ink(5,0,8,1,tank_colors[active_player]<<4);
    if(!hud_valid||p->hp!=OLD_HUD->hp)number(8,2,p->hp,3);
    if(!hud_valid||face!=(100-OLD_HUD->hp)/26)art32(13,0,large_faces+face_offsets[face],large_face_attrs+face*16);
    if(!hud_valid||old_wind!=wind){text_field(18,2,2,wind<0?"<":">");number(20,2,abs(wind),2);}
    if(!hud_valid||p->angle!=OLD_HUD->angle)number(25,2,p->angle,3);
    if(!hud_valid||p->power!=OLD_HUD->power)number(34,2,p->power,3);
    if(!hud_valid||old_selected!=selected){ink(25,2,3,1,selected==0?0x16:0x10);ink(34,2,3,1,selected==1?0x16:0x10);}
    if(!hud_valid||p->weapon!=OLD_HUD->weapon){big_icon(0,0,p->weapon);text_field(0,4,18,weapon_names[p->weapon]);}
    if(!hud_valid||p->weapon!=OLD_HUD->weapon||p->ammo[p->weapon]!=OLD_HUD->ammo[p->weapon]){
        if(p->weapon)number(24,4,p->ammo[p->weapon],3);else text(24,4,"INF");
    }
    if(!hud_valid||old_round!=round_no)number(37,4,round_no,2);
    if(!hud_valid||old_phase!=phase){
        text_field(1,6,38,phase==REVIEW?"CONTINUE? FIRE":phase==SALVO?"SHOTS IN FLIGHT  F1 PAUSE  F5 SOUND":"F1 MENU  F3 INFO  F5 SOUND  F7 HELP");
    }
    memcpy(OLD_HUD,p,sizeof(Player));old_wind=wind;old_round=round_no;old_phase=phase;old_selected=selected;old_active=active_player;hud_valid=1;
}

#pragma codesize (100)
static const char* const weapon_desc[16][2]={
    {"UNLIMITED STANDARD SHELLS.","A SMALL BLAST AND CRATER."},
    {"LARGER BLAST THAN A CANNON.","USES ONE ROCKET PER SHOT."},
    {"HEAVY ROCKET WITH A WIDE", "BLAST AND DEEPER CRATER."},
    {"A POWERFUL NUCLEAR BLAST.","DESTROYS A LARGE AREA."},
    {"THE LARGEST EXPLOSION.","EXTREME DAMAGE AND CRATER."},
    {"ROLLS ALONG THE GROUND", "UNTIL A SLOPE STOPS IT."},
    {"OPENS A CHUTE ON DESCENT.","DRIFTS SLOWLY WITH THE WIND."},
    {"BURROWS UNDER THE GROUND", "TOWARD AN ENEMY TANK."},
    {"FALLS STRAIGHT DOWN AFTER", "REACHING ITS HIGHEST POINT."},
    {"BOUNCES OFF SCREEN EDGES", "BEFORE HITTING THE GROUND."},
    {"POISONS NEARBY TANKS FOR", "DAMAGE OVER THREE VOLLEYS."},
    {"BECOMES A RANDOM WEAPON.","CHEAP BUT UNPREDICTABLE."},
    {"BOUNCES OFF THE TERRAIN", "UP TO THREE TIMES."},
    {"STEERS TOWARD AN ENEMY", "TANK WHILE IN FLIGHT."},
    {"FIRES THREE SMALL ROCKETS", "AT SLIGHTLY DIFFERENT ANGLES."},
    {"RESTORES UP TO 40 HULL", "AND REMOVES POISON."}
};
void weapon_info(void){
    u8 r,w=players[active_player].weapon;
    release_input();
    for(r=0;r<6;r++)text_field(0,r,40,"");
    ink(0,0,40,6,0x10);box(0,0,40,6);big_icon(1,1,w);
    text(6,1,weapon_names[w]);text(6,2,weapon_desc[w][0]);text(6,3,weapon_desc[w][1]);
    text(6,4,"FIRE OR F3 CLOSE");
    do{poll();}while(!(event&FIRE)&&command!=KEY_F3&&command!=KEY_F1);
    release_input();
    for(r=0;r<6;r++)text_field(0,r,40,"");
    hud_valid=0;hud();
}
void help(void){
    u8 old=phase;phase=HELP;release_input();menu_page("FIELD MANUAL");
    text(2,7,"ALL TANKS AIM, THEN FIRE TOGETHER.");
    text(2,8,"LAST TANK STANDING WINS THE ROUND.");
    text(2,11,"LEFT/RIGHT");text(20,11,"AIM BARREL");
    text(2,12,"UP/DOWN");text(20,12,"CHANGE POWER");
    text(2,13,"FIRE");text(20,13,"COMMIT SHOT");
    text(2,14,"FIRE + LEFT/RIGHT");text(20,14,"CYCLE WEAPONS");
    text(2,15,"F3");text(20,15,"WEAPON DETAILS");
    ink(2,11,17,5,0x30);
    text(2,18,"F1 MENU   F5 SOUND   F7 HELP");
    text(2,19,"F2 RENAME   F4 DRAW");
    text(2,20,"F3 SAVES AT ROUND RESULTS");
    footer("F1 OR FIRE TO RETURN");
    do{poll();}while(!(event&FIRE)&&command!=KEY_F7&&command!=KEY_F1);
    phase=old;release_input();
}
