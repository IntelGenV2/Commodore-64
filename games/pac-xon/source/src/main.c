#include "pacxon.h"

u8 mode,held,edge,selected,flash,music=1,effects=1,guide_page;
uint32_t best[5];
u8 best_level[5],best_skill[5],difficulty=NORMAL;
static u8 aux,old_aux,previous,music_restore;
void record_run(void)
{
    u8 i,j;
    if(!score)return;
    for(i=0;i<5;++i)if(score>best[i]) {
        for(j=4;j>i;--j){best[j]=best[j-1];best_level[j]=best_level[j-1];best_skill[j]=best_skill[j-1];}
        best[i]=score;best_level[i]=stage+1;best_skill[i]=difficulty;return;
    }
}
void sound(u8 n) {if(effects)request=n;else request=255;}
void start_music(void)
{
    if(!music)request=255;
    else if(cue!=12 || request==255)request=12;
}
/* Port 2 shares CIA pins with the keyboard. Debounce only the physical stick,
   with independent histories so a turn cannot retrigger the fire button. */
static u8 stick_direction,stick_candidate,stick_fire,previous_fire;
static u8 filter_stick(u8 pins)
{
    u8 vertical=pins&3,horizontal=pins&12,fire=pins&FIRE,direction;
    if(vertical==3)vertical=0;
    if(horizontal==12)horizontal=0;
    if(vertical && horizontal)
        direction=(stick_direction&(vertical|horizontal))?stick_direction:horizontal;
    else direction=vertical|horizontal;
    if(direction==stick_candidate)stick_direction=direction;
    if(fire==previous_fire)stick_fire=fire;
    stick_candidate=direction;previous_fire=fire;
    return stick_direction|stick_fire;
}
void read_input(void)
{
    u8 k,shift;
    scan();k=filter_stick(joy);
    shift=(contacts[1]&128)|(contacts[6]&16);
    if(contacts[0]&128)k|=shift?BTN_UP:BTN_DOWN;
    if(contacts[0]&4)k|=shift?BTN_LEFT:BTN_RIGHT;
    if((contacts[1]|contacts[4])&2)k|=BTN_UP;          /* W / I */
    if((contacts[1]|contacts[4])&32)k|=BTN_DOWN;       /* S / K */
    if((contacts[1]|contacts[4])&4)k|=BTN_LEFT;        /* A / J */
    if((contacts[2]|contacts[5])&4)k|=BTN_RIGHT;       /* D / L */
    if((contacts[7]&16)||(contacts[0]&2))k|=FIRE;
    if(contacts[0]&16)k|=BACK;                         /* F1 */
    if(contacts[5]&2)k|=PAUSE;                         /* P */
    if(contacts[0]&8)k|=MUTE;                          /* F7 */
    aux=(contacts[0]>>5)&3;                            /* F3 / F5 */
    edge=k&~previous;previous=held=k;
}
static void title(void) {mode=MENU;selected=0;title_screen();}
static void choose(u8 pick)
{
    selected=0;
    switch(pick) {
        case 0:new_game();break;
        case 1:mode=GUIDE;guide_page=0;page_screen();break;
        case 2:mode=RECORDS;page_screen();break;
        case 3:mode=DIFFICULTY;selected=difficulty;page_screen();break;
        default:mode=AUDIO;page_screen();
    }
}
static void navigate(u8 n)
{
    if(edge&BTN_UP)selected=selected?selected-1:n-1;
    if(edge&BTN_DOWN)selected=selected+1==n?0:selected+1;
}
static void toggle(void)
{
    if(music || effects) { music_restore=music|(effects<<1);music=effects=0;request=255;}
    else {if(!music_restore)music_restore=3;music=music_restore&1;effects=music_restore>>1;
          if(mode<=AUDIO || mode==DIFFICULTY)start_music();}
    if(mode==AUDIO)page_screen();
}
static void input_tick(void)
{
    u8 shortcut=aux&~old_aux;old_aux=aux;
    if(edge&MUTE)toggle();
    switch(mode) {
        case MENU:
            navigate(5);menu_pointer();
            if(edge&BACK)choose(0);
            else if(shortcut&1)choose(1);
            else if(shortcut&2)choose(4);
            else if(edge&FIRE)choose(selected);
            break;
        case GUIDE:
            if(edge&BACK)title();
            else if(edge&(FIRE|BTN_RIGHT)) {if(guide_page==2)title();else{++guide_page;page_screen();}}
            else if((edge&BTN_LEFT)&&guide_page){--guide_page;page_screen();}
            break;
        case RECORDS:
            if(edge&(BACK|FIRE))title();
            break;
        case DIFFICULTY:
            navigate(3);
            if(edge&BACK)title();
            else if(edge&FIRE){difficulty=selected;title();}
            else if(edge&(BTN_UP|BTN_DOWN))menu_pointer();
            break;
        case AUDIO:
            navigate(3);
            if(edge&BACK)title();
            else if(edge&(FIRE|BTN_RIGHT|BTN_LEFT)) {
                if(selected==2){title();break;}
                if(!selected){music^=1;start_music();}else effects^=1;
                page_screen();
            }
            else if(edge&(BTN_UP|BTN_DOWN))menu_pointer();
            break;
        case READY:
            if(edge&(15|FIRE|BACK))start_play();
            break;
        case PLAY:
            if(edge&(BACK|PAUSE)){mode=PAUSED;request=255;panel();}
            break;
        case PAUSED:
            if(edge&BACK){record_run();title();}
            else if(edge&(FIRE|PAUSE))start_play();
            break;
        case CLEAR:
            if(++flash>=250)flash=249;
            if(flash>=50 && (edge&(FIRE|15|BACK))) {
                if(lives<99)++lives;
                if(stage==19){mode=ENDING;record_run();panel();}
                else {++stage;load_level();}
            }
            break;
        case OVER:
            if(edge&BACK)title();
            else if(edge&FIRE)continue_game();
            break;
        case ENDING:if(edge&(FIRE|BACK))title();break;
    }
}
void main(void)
{
    u8 last,phase=0,dt;
    machine();init_video();title();last=ticks;
    for(;;) {
        while(ticks==last){}
        dt=ticks-last;last=ticks;
        read_input();input_tick();
        if(mode!=PLAY && mode!=DYING){phase=0;continue;}
        /* 34 ms per Flash heartbeat, with fractional timing on both TV systems. */
        if(dt>3)dt=1;
        phase+=dt*10;
        if(phase>=17){phase-=17;game_tick();}
    }
}
