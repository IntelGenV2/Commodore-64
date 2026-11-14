#include "pacxon.h"
#include <string.h>

u8 terrain_art[1000],terrain_color[1000];
extern const u8 sky[],death_art[];
static u16 overflow[2][GHOSTS];
static u8 overflow_count[2],overflow_bank;
extern const u8 ghost_frame[];
/* Field and guide use identical 16-pixel glyphs. All inks are hi-res colours. */
static const u8 item_ink[]={3,3,7,3, 1,7,7,7, 5,5,2,2, 7,7,7,7};
static const char* const power_word[]={"ICE","EAT","FAST","SLOW"};
static const u8 word_column[]={23,27,31,36}, word_ink[]={3,1,2,7};
static const char* const skill_name[]={"EASY","NORMAL","HARD"};
static u8* text_color=COLOR;
static u8 menu_bank=0xd0;
volatile u8 cursor_visible,menu_y;
void __fastcall__ copy_menu_matrix(u8 high);
void menu_border(void);
void publish_colors(void);
void guide_sprites(void);
void title_cursor(void);

static u8 ink(u8 color)
{
    static const u8 single[16]={0,1,2,3,4,5,6,7,7,2,4,6,6,5,3,1};
    return text_color==COLOR ? single[color] : color;
}
static void text(u8 x,u8 y,const char* s,u8 color)
{
    u16 p=(u16)y*40+x;
    while(*s) {
        u8 c=*s++;
        if(c>=0xc1 && c<=0xda)c-=0xc0;
        else if(c>=65 && c<=90)c-=64;
        SCREEN[p]=c;text_color[p++]=ink(color);
    }
}
static void number(u8 x,u8 y,uint32_t value,u8 digits,u8 color)
{
    u16 p=(u16)y*40+x+digits;
    while(digits--) {--p;SCREEN[p]=48+value%10;text_color[p]=ink(color);value/=10;}
}
static void small(u8 x,u8 y,u8 value,u8 color)
{
    u16 p=(u16)y*40+x;
    SCREEN[p]=48+value/10;SCREEN[p+1]=48+value%10;text_color[p]=text_color[p+1]=ink(color);
}
static void blank(void)
{
    cursor_visible=0;multiplex=0;REG(0xd015)=0;REG(0xd011)=0x0b;
    memset(SCREEN,32,1000);memset(COLOR,14,1000);
}
void init_video(void)
{
    memcpy((void*)0xc800,charset,1264);
    memcpy((void*)0xc400,sprites,1024);
    memcpy((void*)0xcf00,sprites+1024,256);
    memcpy((void*)0xcd00,death_art,512);
    memcpy((void*)0xe000,title_art,8000);
    memcpy(SCREEN,title_art+8000,1000);
    copy_menu_matrix(0xd8);
    REG(0xd022)=11;REG(0xd023)=14;
    REG(0xd025)=8;REG(0xd026)=1;REG(0xd01c)=255;
}
void menu_pointer(void)
{
    if(mode==MENU)menu_y=146+selected*15;
    else if(mode==AUDIO)menu_y=115+selected*24;
    else menu_y=107+selected*32;
}
void title_screen(void)
{
    menu_pointer();menu_border();multiplex=0;
    REG(0xd018)=0x68;REG(0xd016)=0x08;REG(0xd011)=0x3b;
    title_cursor();REG(0xd000)=27;REG(0xd010)=0;REG(0xd027)=7;REG(0xd015)=1;
    cursor_visible=1;start_music();
}
static void chars(void)
{
    REG(0xd018)=2;REG(0xd016)=0x18;REG(0xd011)=0x1b;
}
static void rule(u8 y,u8 color)
{
    memset(SCREEN+(u16)y*40+2,77,36);memset(text_color+(u16)y*40+2,color,36);
}
static void menu_header(const char* name)
{
    text_color=terrain_color;
    memset(SCREEN,32,1000);memset(text_color,14,1000);
    text(2,1,"PAC-XON",7);text(28,1,"STUDIO 256",3);rule(3,6);
    text(3,5,name,1);rule(21,6);
}
extern u8 guide_page;
static void guide_item(u8 x,u8 y,u8 kind,const char* name,const char* effect)
{
    u8 q,art=kind*4;
    u16 p=(u16)y*40+x;
    for(q=0;q<4;++q) {
        u16 cell=p+(q&1)+(q>=2?40:0);
        SCREEN[cell]=136+art+q;text_color[cell]=item_ink[art+q];
    }
    text(x+3,y,name,word_ink[kind]);text(x+3,y+1,effect,1);
}
void page_screen(void)
{
    u8 i;
    if(mode==GUIDE) {
        menu_header(guide_page==2?"GHOST FIELD GUIDE":guide_page?"POWER-UPS":"HOW TO PLAY");
        if(!guide_page) {
            text(3,8,"LEAVE THE BLUE WALL TO DRAW A LINE.",3);
            text(3,10,"REJOIN IT TO SEAL YOUR CUT.",1);
            text(3,12,"POCKETS WITHOUT GHOSTS FILL IN.",1);
            text(3,14,"CLAIM 80% TO ADVANCE.",7);
            text(3,16,"IN OPEN SPACE YOU KEEP MOVING.",1);
            text(3,18,"BEAT THE SPARK BACK TO A WALL.",10);
            text(3,20,"P OR F1 PAUSES THE GAME.",3);
            text(3,23,"FIRE  NEXT",7);
        } else if(guide_page==1) {
            text(3,8,"TOUCH ANY PART OF A PICKUP.",3);
            text(3,10,"WATCH THE HUD FOR ACTIVE POWERS.",1);
            guide_item(3,12,ICE,"ICE POP","FREEZE GHOSTS");
            guide_item(22,12,POWER,"POWER ORB","EAT GHOSTS");
            guide_item(3,16,SPEED,"CHERRIES","MOVE FASTER");
            guide_item(22,16,SLOW,"BANANA","SLOW GHOSTS");
            text(3,19,"FRUIT LASTS EIGHT SECONDS.",3);
            text(3,23,"FIRE  NEXT",7);
        } else {
            static const char* const entry[]={"DRIFTER   BOUNCES IN OPEN SPACE",
                "PATROLLER FOLLOWS THE CONTOUR","WISP      ROAMS CLAIMED GROUND",
                "CRUSHER   BREAKS YOUR WALLS","SEEKER    TRACKS EXPOSED PLAYERS",
                "SPINNER   TURNS IN RIGHT ANGLES"};
            memcpy(SCREEN+1016,ghost_frame,GHOST_TYPES);
            for(i=0;i<GHOST_TYPES;++i) {
                u8 row=7+2*i;
                text(7,row,entry[i],1);
            }
            text(3,20,"COLOR AND SHAPE SHOW GHOST TYPE.",3);
            text(3,23,"FIRE  MENU",7);
        }
        text(24,23,"F1  BACK",14);
    } else if(mode==AUDIO) {
        menu_header("AUDIO");
        text(6,9,"TITLE MUSIC",1);text(27,9,music?"ON ":"OFF",music?13:10);
        text(6,12,"GAME SOUNDS",1);text(27,12,effects?"ON ":"OFF",effects?13:10);
        text(6,15,"BACK TO TITLE",3);
        text(3,23,"UP / DOWN     FIRE TO SELECT",14);
    } else if(mode==DIFFICULTY) {
        static const char* const pace[]={"SLOWER GHOSTS","ORIGINAL PACE","FASTER GHOSTS"};
        menu_header("DIFFICULTY");
        for(i=0;i<3;++i){
            u8 row=8+i*4;
            text(6,row,skill_name[i],i==difficulty?7:1);
            if(i==difficulty)text(26,row,"CURRENT",7);
            number(6,row+1,reserves[i],1,3);text(8,row+1,reserves[i]==1?"RESERVE":"RESERVES",3);
            text(19,row+1,pace[i],14);
        }
        text(3,23,"FIRE  APPLY",7);text(24,23,"F1  BACK",14);
    } else {
        menu_header("HIGH SCORES");
        text(3,7,"RANK      SCORE    LEVEL   SKILL",3);
        for(i=0;i<5;++i) {
            small(5,9+i*2,i+1,14);
            if(best[i]) {number(11,9+i*2,best[i],7,7);small(23,9+i*2,best_level[i],1);text(30,9+i*2,skill_name[best_skill[i]],3);}
            else text(11,9+i*2,"-------     --     --",12);
        }
        text(3,23,"FIRE  MENU",14);
    }
    text_color=COLOR;
    if(mode==AUDIO || mode==DIFFICULTY)SCREEN[1016]=0x10;
    menu_bank^=4;
    copy_menu_matrix(menu_bank);
    menu_border();cursor_visible=0;REG(0xd015)=0;
    REG(0xd018)=menu_bank==0xd0?0x42:0x52;
    REG(0xd016)=8;REG(0xd011)=0x1b;
    if(mode==GUIDE && guide_page==2)guide_sprites();
    if(mode==AUDIO || mode==DIFFICULTY) {
        menu_pointer();REG(0xd000)=40;REG(0xd001)=menu_y;REG(0xd010)=0;
        REG(0xd027)=7;REG(0xd015)=1;cursor_visible=1;
    }
    publish_colors();
}
void tile(u16 p)
{
    u8 a,c;
    switch(board[p]) {
        case WALL:a=65;c=14;break;
        case EDGE:a=64;c=14;break;
        case TRAIL:a=66;c=3;break;
        case BURN:a=67;c=7;break;
        default:a=sky[p];c=14;
    }
    if(pickup[p]) {
        u8 part=pickup[p]-1;
        a=136+part;c=item_ink[part];
    }
    SCREEN[p]=terrain_art[p]=a;COLOR[p]=terrain_color[p]=c;
}
void hud(void)
{
    u8 i;
    text(1,0,"LV",14);small(4,0,stage+1,1);
    text(8,0,"LIVES",14);small(14,0,lives,7);
    text(21,0,"SCORE",14);number(28,0,score,7,1);
    text(1,1,"CLAIM",3);small(7,1,percent==100?99:percent,1);
    text(9,1,"%",3);if(percent==100)text(6,1,"100",1);
    for(i=0;i<8;++i){SCREEN[51+i]=77;COLOR[51+i]=i<(percent/10)?3:6;}
    text(19,1,"80%",14);
    for(i=0;i<4;++i)text(word_column[i],1,powers[i]?power_word[i]:"    ",word_ink[i]);
}
void field_screen(void)
{
    u8 x,y;
    blank();overflow_count[0]=overflow_count[1]=0;
    for(y=0;y<23;++y)for(x=0;x<34;++x)tile(rows[y]+x);
    for(y=3;y<24;y+=3) {
        u16 p=(u16)y*40;
        SCREEN[p+1]=69;COLOR[p+1]=14;SCREEN[p+38]=69;COLOR[p+38]=6;
    }
    hud();chars();
}
static void box(void)
{
    u8 y;
    multiplex=0;REG(0xd015)=0;
    for(y=9;y<=17;++y) {
        u16 p=(u16)y*40+5;
        memset(SCREEN+p,(y==9||y==17)?77:32,30);
        memset(COLOR+p,(y==9||y==17)?14:1,30);
    }
}
void panel(void)
{
    box();
    if(mode==READY) {
        text(9,11,"LEVEL",3);small(15,11,stage+1,7);
        text(23,11,skill_name[difficulty],7);
        text(9,13,"CLAIM 80% OF THE FIELD",1);
        text(9,15,"FIRE OR MOVE TO START",14);
    } else if(mode==PAUSED) {
        text(9,11,"PAUSED",7);text(9,13,"FIRE  RESUME",1);text(9,15,"F1    RETURN TO TITLE",14);
    } else if(mode==CLEAR) {
        text(9,11,"LEVEL CLEAR",7);text(9,13,"TERRITORY",3);
        if(percent==100)text(20,13,"100%",1);
        else {small(20,13,percent,1);text(22,13,"%",3);}
        text(9,15,"FIRE  CONTINUE",14);
    } else if(mode==OVER) {
        text(9,11,"GAME OVER",10);text(9,13,"FIRE  TRY THIS LEVEL",1);text(9,15,"F1    RETURN TO TITLE",14);
    } else {
        text(8,11,"ALL 20 LEVELS CLEARED!",7);
        text(8,13,"FINAL SCORE",3);number(21,13,score,7,1);
        text(8,15,"FIRE  RETURN TO TITLE",14);
    }
}
void __fastcall__ spill(u8 i)
{
    static const u8 alternate[]={78,79,72,73,74,75};
    Ghost* g=&ghosts[i];
    u16 p=rows[(u16)g->y>>5]+((u16)g->x>>5);
    overflow[overflow_bank][overflow_count[overflow_bank]++]=p;
    SCREEN[p]=(clock30&4) && !powers[ICE]?alternate[g->kind]:152+g->kind;
    COLOR[p]=ghost_ink[g->kind];
}
void sprite_frame(void);
void actors(void)
{
    u8 i,j,previous=overflow_bank;
    REG(0xd026)=powers[POWER]?(powers[POWER]<50 && (clock30&4)?1:14):powers[ICE]?3:1;
    overflow_bank^=1;overflow_count[overflow_bank]=0;
    sprite_frame();
    for(i=0;i<overflow_count[previous];++i) {
        u16 p=overflow[previous][i];
        for(j=0;j<overflow_count[overflow_bank];++j)
            if(overflow[overflow_bank][j]==p)break;
        if(j==overflow_count[overflow_bank]) {
            SCREEN[p]=terrain_art[p];COLOR[p]=terrain_color[p];
        }
    }
}
