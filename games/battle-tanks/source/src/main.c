#include "game.h"

/* Menu and disk code favors size to leave RAM for the title artwork. */
#pragma codesize (100)

volatile u8 phase;
u8 count=2,humans=2,hills=6,speed=9,round_no,active_player,selected;
u16 rng=0xace1;
s8 wind;
const char* const weapon_names[16]={
    "CANNONBALL","SMALL ROCKET","LARGE ROCKET","MINOR NUKE",
    "OVERSIZED NUKE","ROLLING BOMB","PARACHUTE BOMB","MOLE BOMB",
    "DROP BOMB","WALL BOUNDER","SARINE BOMB","RANDOM BOMB",
    "GROUND BOUNDER","HOMING BOMB","TRIPLE BOMB","MEDICAL KIT"};
/* Mac CODE 2, $0528-$059A; reordered from ICON IDs into our weapon IDs. */
const u16 prices[16]={0,500,1000,5000,10000,2000,1000,2000,1000,2000,5000,50,2000,2000,3000,5000};
const u8 radii[16]={6,9,14,20,28,12,13,12,15,10,23,15,12,11,10,0};
const u8 weapon_order[16]={0,1,2,3,4,6,7,8,9,10,11,12,5,13,14,15};
#define savebuf ((u8*)0xc600)
u8 round_draw;
static u8 main_choice;

u8 random8(void) { rng=(rng>>1)^((0-(rng&1))&0xb400);return (u8)rng; }

static void notice(const char* s){footer(s);release_input();do{poll();}while(!(event&FIRE));release_input();}

/* Each row already contains a chevron. Changing focus costs two color bytes. */
static void marker(u8 x,u8 row,u8 on){
    u8* cell=SCREEN+(u16)row*40+x;u8 color=on?0x70:0;
    if(*cell!=color)*cell=color;
}
static void menu_key(u8 x,u8 y,const char* key){text(x,y,key);ink(x,y,2,1,0x30);}
static void select_hint(void){footer("JOY UP/DOWN     FIRE/RETURN SELECT");}
static void title(void) {
    static const char* const items[]={"NEW BATTLE","SOUND SETTINGS","FIELD MANUAL","LOAD FROM DRIVE 8"};
    static const char* const keys[]={"F1","F3","F5","F7"};
    u8 i,y;
    phase=TITLE;clear_screen();unpack_banner(menu_bitmap,BITMAP);unpack_banner(menu_inks,SCREEN);
    text(15,0,"STUDIO 256");ink(15,0,10,1,0x70);menu_rule(12);
    for(i=0;i<4;i++){
        y=14+2*i;text(2,y,">");marker(2,y,i==main_choice);
        menu_key(4,y,keys[i]);text(9,y,items[i]);
    }
    select_hint();release_input();
}

/* Keep a border around each setting, with room for the value at the right. */
static void menu_panel(u8 y,u8 rows){
    u8 i;
    box(3,y-1,34,rows*2+1);
    for(i=1;i<rows;i++)hline(24,295,(y+2*i-1)*8+3,1);
    ink(3,y-1,34,rows*2+1,0xb0);
}
static void panel_item(u8 y,const char* label,u8 on){
    text(4,y,">");marker(4,y,on);text(7,y,label);ink(7,y,25,1,0x10);
}
static u8 panel_row(u8 item,u8 last){return item==last?20:8+2*item;}

void pause_menu(void){
    static const char* const items[7]={"RESUME BATTLE","HOW TO PLAY","RENAME TANK","GAME SPEED","SOUND","CALL IT A DRAW","RETURN TO TITLE"};
    u8 i,row=0,dirty=2;phase=HELP;release_input();
    for(;;){
        if(dirty){
            if(dirty==2){
                menu_page("COMMAND MENU");menu_panel(8,7);
                for(i=0;i<7;i++)panel_item(8+i*2,items[i],i==row);
                ink(30,14,3,1,0x70);ink(30,16,3,1,0x70);
            }
            number(30,14,speed,1);text_field(30,16,3,muted?"OFF":"ON");
            for(i=0;i<7;i++)marker(4,8+i*2,i==row);
            footer("JOYSTICK CHOOSE/CHANGE  FIRE SELECT");dirty=0;
        }
        poll();if(command==KEY_F1){phase=AIM;break;}
        if(command==KEY_F5)dirty=1;
        if(event&UP){row=row?row-1:6;dirty=1;}
        if(event&DOWN){row=(row+1)%7;dirty=1;}
        if(row==3 && event&(LEFT|RIGHT)){if(event&RIGHT){if(speed<9)speed++;}else if(speed>1)speed--;dirty=1;}
        if(event&FIRE){
            if(row==0){phase=AIM;break;}
            if(row==1){help();dirty=2;}
            if(row==2){rename_player();phase=AIM;break;}
            if(row==3){speed=speed%9+1;dirty=1;}
            if(row==4){sound_menu();dirty=2;}
            if(row==5){end_round(1);break;}
            if(row==6){phase=TITLE;break;}
            release_input();
        }
    }
    release_input();
}

void sound_menu(void){
    static const char* const items[]={"MASTER SOUND","MUSIC","EFFECTS","BACK"};
    static const char* const keys[]={"F5","F3","F7","F1"};
    u8 i,y,row=0,old=phase,dirty=1;phase=HELP;release_input();
    menu_page("SOUND SETTINGS");menu_panel(8,3);
    for(i=0;i<4;i++){
        y=panel_row(i,3);text(4,y,">");marker(4,y,i==0);
        menu_key(7,y,keys[i]);text(12,y,items[i]);ink(12,y,12,1,0x10);ink(30,y,3,1,0x70);
    }
    select_hint();
    for(;;){
        if(dirty){
            for(i=0;i<4;i++)marker(4,panel_row(i,3),i==row);
            text(30,8,muted?"OFF":"ON ");text(30,10,music_enabled?"ON ":"OFF");text(30,12,sfx_enabled?"ON ":"OFF");dirty=0;
        }
        poll();if(command==KEY_F1)break;
        if(command==KEY_F5)dirty=1;
        if(command==KEY_F3){music_enabled^=1;silence();dirty=1;}
        if(command==KEY_F7){sfx_enabled^=1;silence();dirty=1;}
        if(event&UP){row=row?row-1:3;dirty=1;}
        if(event&DOWN){row=(row+1)&3;dirty=1;}
        if(event&(LEFT|RIGHT|FIRE)){
            if(row==3){if(event&FIRE)break;}
            else {if(row==0)muted^=1;else if(row==1)music_enabled^=1;else sfx_enabled^=1;silence();dirty=1;}
            release_input();
        }
    }
    phase=old;release_input();
}

static void setup_screen(u8 row) {
    static const char* const labels[]={"TANKS IN BATTLE","HUMAN PLAYERS","HILLS (2-20)","GAME SPEED (1-9)","NAME PLAYERS"};
    u8 i,y;
    menu_page("NEW BATTLE");menu_panel(8,4);
    for(i=0;i<5;i++){y=panel_row(i,4);panel_item(y,labels[i],row==i);ink(30,y,2,1,0x70);}
    number(30,8,count,2);number(30,10,humans,2);number(30,12,hills,2);number(30,14,speed,2);
    text(4,17,"EXTRA TANKS ARE CPU OPPONENTS.");
    footer("JOY SELECT/CHANGE   FIRE NEXT   F1 BACK");
}
static u8 setup(void) {
    u8 row=0,oldrow;
    phase=SETUP;release_input();setup_screen(row);
    for(;;){
        oldrow=row;poll();
        if(command==KEY_F1)return 0;
        if(event&UP)row=row?row-1:4;
        if(event&DOWN)row=(row+1)%5;
        if(row!=oldrow){marker(4,panel_row(oldrow,4),0);marker(4,panel_row(row,4),1);}
        if(event&(LEFT|RIGHT)){
            if(row==0){if(event&RIGHT){if(count<10)count++;}else if(count>2)count--;if(humans>count)humans=count;}
            if(row==1){if(event&RIGHT){if(humans<count)humans++;}else if(humans)humans--;}
            if(row==2){if(event&RIGHT){if(hills<20)hills++;}else if(hills>2)hills--;}
            if(row==3){if(event&RIGHT){if(speed<9)speed++;}else if(speed>1)speed--;}
            number(30,8,count,2);number(30,10,humans,2);number(30,12,hills,2);number(30,14,speed,2);
        }
        if(event&FIRE)return 1;
    }
}

void start_match(void) {
    u8 i;memset(players,0,sizeof(players));round_no=0;
    for(i=0;i<count;i++){
        strcpy(players[i].name,"TANK 00");players[i].name[5]='0'+(i+1)/10;players[i].name[6]='0'+(i+1)%10;
        players[i].cpu=i>=humans;players[i].money=100;
        players[i].ammo[1]=5;
    }
}

void rename_player(void){
    char name[9];u8 n=0,k,x=phase==NAMES?16:phase==AIM?5:8,y=phase==NAMES?2+active_player*2:phase==AIM?0:22;
    memset(name,0,9);typing=1;release_input();
    if(phase==AIM)text_field(1,6,38,"TYPE NAME. RETURN KEEP. F1 CANCEL.");
    else footer("TYPE NAME. RETURN KEEP. F1 CANCEL.");
    for(;;){
        text_field(x,y,8,name);poll();k=command;
        if(k==13||((event&FIRE)&&!k))break;
        if(k==KEY_F1){n=0;break;}
        if(k==8){if(n)name[--n]=0;}
        else if(n<8&&((k>='A'&&k<='Z')||(k>='0'&&k<='9')||k==' ')){name[n++]=k;name[n]=0;}
    }
    if(n)strcpy(players[active_player].name,name);
    text_field(x,y,8,players[active_player].name);
    if(phase==AIM){player_labels();text_field(1,6,38,"F1 MENU  F3 INFO  F5 SOUND  F7 HELP");}
    typing=0;release_input();
}

static void name_players(void){
    u8 i,row=0,oldrow;phase=NAMES;clear_screen();header("BATTLE TANKS / NAME YOUR PLAYERS");
    for(i=0;i<count;i++){
        text(5,2+i*2,"PLAYER");number(12,2+i*2,i+1,2);
        text_field(16,2+i*2,8,players[i].name);if(players[i].cpu)text(26,2+i*2,"CPU");
        setting_box(3,2+i*2,34);
    }
    text(12,2+count*2,"START BATTLE");setting_box(3,2+count*2,34);
    ink(3,1,34,2,0x16);release_input();
    for(;;){
        footer("JOYSTICK SELECT  FIRE EDIT  F1 START");oldrow=row;poll();
        if(command==KEY_F1)break;
        if(event&UP)row=row?row-1:count;if(event&DOWN)row=row==count?0:row+1;
        if(row!=oldrow){ink(3,1+oldrow*2,34,2,0x01);ink(3,1+row*2,34,2,0x16);}
        if(event&FIRE){if(row==count)break;active_player=row;rename_player();}
    }
    active_player=0;new_round();
}

/* A small versioned campaign save, written only between rounds. Runtime
   coordinates and pending projectiles are deliberately not a save format. */
u8 disk_save(void) {
    u8 i,w,e;u16 n=16,sum=0;
    display_invalidate();memset(savebuf,0,512);memcpy(savebuf,"BT64",4);
    savebuf[4]=2;savebuf[5]=count;savebuf[6]=humans;savebuf[7]=hills;
    savebuf[8]=speed;savebuf[9]=round_no;
    for(i=0;i<count;i++){
        memcpy(savebuf+n,players[i].name,9);n+=9;
        savebuf[n++]=players[i].cpu;
        savebuf[n++]=players[i].points;savebuf[n++]=players[i].points>>8;
        savebuf[n++]=players[i].money;savebuf[n++]=players[i].money>>8;
        for(w=0;w<16;w++)savebuf[n++]=players[i].ammo[w];
    }
    for(n=0;n<510;n++)sum+=savebuf[n];savebuf[510]=sum;savebuf[511]=sum>>8;
    audio_suspend();POKE(1,0x36);e=cbm_save("@:BATTLETANKS.SAV",8,savebuf,512);POKE(1,0x35);audio_resume();
    return e==0;
}
u8 disk_load(void) {
    u8 i,w;u16 n,sum=0;
    display_invalidate();
    audio_suspend();POKE(1,0x36);
    /* Use a bounded SEQ read, including the two PRG load-address bytes.
       A malformed disk file cannot overwrite arbitrary C64 RAM. */
    i=cbm_open(2,8,2,"BATTLETANKS.SAV,P,R");
    if(!i){cbm_read(2,savebuf,2);n=cbm_read(2,savebuf,512);}else n=0;
    cbm_close(2);POKE(1,0x35);audio_resume();
    if(n!=512||memcmp(savebuf,"BT64",4)||savebuf[4]!=2)return 0;
    for(n=0;n<510;n++)sum+=savebuf[n];
    if(sum!=(savebuf[510]|((u16)savebuf[511]<<8)))return 0;
    if(savebuf[5]<2||savebuf[5]>10||savebuf[6]>savebuf[5]||savebuf[7]<2||savebuf[7]>20||savebuf[8]<1||savebuf[8]>9)return 0;
    count=savebuf[5];humans=savebuf[6];hills=savebuf[7];speed=savebuf[8];round_no=savebuf[9];n=16;
    memset(players,0,sizeof(players));
    for(i=0;i<count;i++){
        memcpy(players[i].name,savebuf+n,9);players[i].name[8]=0;n+=9;
        players[i].cpu=savebuf[n++]?1:0;
        players[i].points=savebuf[n]|((u16)savebuf[n+1]<<8);n+=2;
        players[i].money=savebuf[n]|((u16)savebuf[n+1]<<8);n+=2;
        for(w=0;w<16;w++)players[i].ammo[w]=savebuf[n++];
    }
    return 1;
}

void results(void) {
    u8 i,y;phase=RESULTS;silence();clear_screen();header("BATTLE TANKS / ROUND RESULTS");
    sound(round_draw?2:3);
    text(2,2,"PLAYER        HULL   POINTS   CREDITS");
    for(i=0;i<count;i++){
        y=4+i;text(2,y,players[i].name);number(16,y,players[i].hp,3);
        number(24,y,players[i].points,4);number(31,y,players[i].money,5);
        if(players[i].hp)ink(1,y,37,1,0x1b);
    }
    text(3,16,round_draw?"DRAW. NO SURVIVOR BONUS THIS ROUND.":"SURVIVOR +100 POINTS / +5000 CREDITS");
    text(3,18,"EVERY TANK EARNS 50 SUPPLY CREDITS.");
    text(2,20,"F3 SAVE  JOYSTICK PLAYERS  F7 HILLS");
    text(2,21,"F1 MENU. NEW PLAYERS JOIN AS HUMANS.");
    footer("FIRE TO BUY SUPPLIES AND PLAY ON");release_input();
    for(;;){poll();if(command==KEY_F3){notice(disk_save()?"CAMPAIGN SAVED. FIRE TO CONTINUE.":"DISK ERROR. FIRE TO CONTINUE.");footer("FIRE SUPPLIES   F3 SAVE   F1 MENU");}
        if(event&RIGHT){
            if(count<10){
                i=count++;memset(&players[i],0,sizeof(Player));
                strcpy(players[i].name,"TANK 00");players[i].name[5]='0'+(i+1)/10;players[i].name[6]='0'+(i+1)%10;
                players[i].money=150;
                players[i].ammo[1]=5;
                humans++;
            }
            footer("PLAYERS NEXT ROUND:");number(21,24,count,2);
        }
        if(event&LEFT){
            if(count>2){if(!players[count-1].cpu&&humans)humans--;count--;}
            footer("PLAYERS NEXT ROUND:");number(21,24,count,2);
        }
        if(command==KEY_F7){
            hills++;if(hills>20)hills=2;footer("HILLS NEXT ROUND:");number(20,24,hills,2);
        }
        if(command==KEY_F1){phase=TITLE;return;}
        if(event&FIRE){shop();return;}}
}

static u8 another_buyer(void){
    u8 i;for(i=active_player+1;i<count;i++)if(!players[i].cpu)return 1;return 0;
}
static void shop_preview(u8 w){
    u8 y;
    for(y=5;y<10;y++)text_field(32,y,7,"");
    ink(32,5,7,5,0x10);
    if(w<16)big_icon(33,5,weapon_order[w]);
    text_field(32,18,7,"FIRE");
    text_field(32,19,7,w<16?"BUY":"NEXT");
}
static void shop_highlight(u8 w,u8 on){
    ink(1,w<16?5+w:22,29,1,on?0x70:0x10);
}
static void shop_screen(u8 w,u8 rebuild){
    u8 k,id;Player* p=&players[active_player];
    if(rebuild){
        clear_screen();header("STUDIO 256 / SUPPLY STORE");
        box(0,3,31,21);box(31,3,9,21);
        text(2,3,"WEAPON");text(18,3,"PRICE");text(25,3,"OWN");
        hline(0,247,4*8,1);line(17*8-2,3*8,17*8-2,21*8-1,1);line(24*8-2,3*8,24*8-2,21*8-1,1);
        for(k=0;k<16;k++){id=weapon_order[k];text(2,5+k,weapon_names[id]);number(18,5+k,prices[id],5);}
        text(32,12,"CREDITS");hline(0,247,21*8,1);
    }
    text_field(2,1,8,p->name);number(32,14,p->money,5);
    for(k=0;k<16;k++){id=weapon_order[k];if(id)number(25,5+k,p->ammo[id],3);else text(25,5+k,"INF");}
    text_field(8,22,17,another_buyer()?"NEXT PLAYER":"NEXT ROUND");
    shop_highlight(w,1);shop_preview(w);
}
void shop(void){
    u8 w=1,oldw,id,i,drawn=0;Player* p;phase=SHOP;
    for(active_player=0;active_player<count;active_player++){
        p=&players[active_player];
        if(p->cpu){
            for(i=0;i<3;i++){id=1+random8()%15;if(p->money>=prices[id]&&p->ammo[id]<99){p->money-=prices[id];p->ammo[id]++;}}
            continue;
        }
        if(drawn)shop_highlight(w,0);
        w=1;release_input();shop_screen(w,!drawn);drawn=1;
        for(;;){
            oldw=w;poll();
            if(event&UP)w=w?w-1:16;
            if(event&DOWN)w=w==16?0:w+1;
            if(w!=oldw){shop_highlight(oldw,0);shop_highlight(w,1);shop_preview(w);}
            if((event&FIRE)&&!(input&15)){
                if(w==16)break;
                id=weapon_order[w];
                if(id&&p->money>=prices[id]&&p->ammo[id]<99){
                    p->money-=prices[id];p->ammo[id]++;sound(2);
                    number(32,14,p->money,5);number(25,5+w,p->ammo[id],3);
                }
                release_input();
            }
        }
    }
    new_round();
}

int main(void) {
    u8 old_choice,action;
    hw_init();audio_init();
    for(;;){
        title();
        for(;;){
            old_choice=main_choice;poll();
            if(event&UP)main_choice=main_choice?main_choice-1:3;
            if(event&DOWN)main_choice=(main_choice+1)%4;
            if(main_choice!=old_choice){marker(2,14+old_choice*2,0);marker(2,14+main_choice*2,1);}
            if(command==KEY_F1)action=0;
            else if(command==KEY_F3)action=1;
            else if(command==KEY_F5)action=2;
            else if(command==KEY_F7)action=3;
            else if(event&FIRE)action=main_choice;
            else continue;
            if(action==0){if(setup()){start_match();name_players();break;}}
            else if(action==1)sound_menu();
            else if(action==2)help();
            else if(disk_load()){shop();break;}
            else {notice("NO VALID SAVE ON DRIVE 8. FIRE RETURN.");select_hint();continue;}
            title();
        }
        while(phase!=TITLE){
            if(phase==AIM)aim_loop();
            if(phase==RESULTS)results();
        }
    }
}
