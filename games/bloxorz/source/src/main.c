#include "game.h"
#include "assets.h"
#include "branding.h"
#include "menu_art.h"
#include "music.h"
const u8 *source,*blit_source;
u8 *destination;
u8 blit_x,blit_y,blit_erase;
volatile u8 phase,command;
static u8 old_key,old_joy,ox,oy,sprbuf;
static u8 buffered_dir=255,sampled_dir=255,release_dir=255,tracking_move;
static u8 last_stage,have_continue;
static u16 falls;
static u8 oldpx,oldpy,oldqx,oldqy,oldo,olda;
static u16 oldbridges;
static u8 frame_index,anim_dir,anim_frame;
static u8 collapse=255;
u8 visible_tiles[150],patch_width,patch_rows;
extern u8 patch_pixels[64];
u8 sprite_priority;
static u8 cached_frame[4]={255,255,255,255};
int sprx[8];u8 spry[8],sprp[8],sprc[8],sprmask;
static u8 inputkey,inputjoy;
static u8 f8_held;
static u8 password_len;static char password[7];
static u8 menu_frame,menu_clock,menu_pose,menu_pointer;
static const u8 joystick_bits[4]={4,1,8,2};

static void palette(u8 a,u8 b,u8 c){
    memset((void*)0xc400,(a<<4)|b,1000);memset((void*)0xd800,c,1000);
}
static void clear(void){
    REG(0xd015)=0;REG(0xd017)=0;REG(0xd01d)=0;REG(0xd016)=0x18;REG(0xd026)=7;
    memset((void*)0xe000,0,8000);
}
static void put(u8 x,u8 y,const char *s){
    u8 c;u8 *p=(u8*)0xe000+(u16)y*320+(u16)x*8;
    while(*s && x<40){c=*s++;
        if(c<32||c>95)c=63;
        memcpy(p,small_font+(u16)(c-32)*8,8);p+=8;++x;
    }
}
static void number(u8 x,u8 y,u16 v,u8 digits){
    char b[6];u8 i;b[digits]=0;i=digits;
    while(i){--i;b[i]='0'+v%10;v/=10;}put(x,y,b);
}
static void center(u8 y,const char *s){put((40-strlen(s))/2,y,s);}
static void paint_bar(u8 row,u8 color){memset((void*)(0xc400+(u16)row*40),(11<<4)|color,40);}
static const char audio_labels[][16]={
    "MUSIC + EFFECTS", "EFFECTS ONLY   ", "MUSIC ONLY     ", "OFF            "
};
static void show_audio_setting(void){
    u8 x=phase==3?12:10,y=phase==3?16:23;
    if(phase==1){
        source=menu_mix_data+menu_mix_offsets[audio_mix];
        destination=(u8*)(0xe000+23*320+4*8);menu_unpack();return;
    }
    put(x,y,"F8");put(x+4,y,audio_labels[audio_mix]);paint_bar(y,3);
}
static void check_audio_key(u8 k){
    if(k==KEY_F8 && !f8_held){
        audio_mix=(audio_mix+1)&3;
        if(phase!=0)show_audio_setting();
    }
    f8_held=k==KEY_F8;
}
static void bottom(const char *s){
    memset((void*)(0xe000+23*320),0,640);center(24,s);
    paint_bar(24,12);
    show_audio_setting();
}
static void poll(void){inputjoy=scan_input();inputkey=key;check_audio_key(inputkey);}
static u8 direction(u8 joy,u8 k){
    if((joy&4)||k=='A')return 0;
    if((joy&1)||k=='W')return 1;
    if((joy&8)||k=='D')return 2;
    if((joy&2)||k=='S')return 3;
    return 255;
}
static u8 edgekey(u8 c){return inputkey==c&&old_key!=c;}
static u8 swap_pressed(void){return edgekey(' ')||((inputjoy&16)&&!(old_joy&16));}
static void remember(void){old_key=inputkey;old_joy=inputjoy;}
static void delay(u8 n){while(n--){wait_frame();}}
static void flush_input(void){poll();remember();}
void sprite_commit(void){
    u8 joy,d;
    wait_frame();
    publish_sprites();
    joy=scan_input();check_audio_key(key);
    if(tracking_move){
        d=direction(joy,key);
        if(d!=255&&d!=sampled_dir)buffered_dir=d;
        sampled_dir=d;
    }
}
static int worldx(s8 x,s8 y){return ox+(int)x*7+(int)y*3;}
static int worldy(s8 x,s8 y){return oy-(int)x*3+(int)y*8;}
static void object(u8 slot,s8 x,s8 y,u8 idx,s8 sink){
    u8 i,ptr,at,cache=sprbuf*2+(slot>>2);int sx,sy;
    if(cached_frame[cache]!=idx){
        source=sprite_stream+sprite_offset[idx];destination=(u8*)(0xc800+(u16)sprbuf*512+(u16)slot*64);unpack();
        cached_frame[cache]=idx;
    }
    sx=24+(worldx(x,y)+(s8)sprite_dx[idx])*2;sy=50+worldy(x,y)+(s8)sprite_dy[idx]+sink;
    ptr=32+sprbuf*8+slot;
    for(i=0;i<4;++i){
        at=slot+i;
        sprx[at]=sx+(i&1)*24;spry[at]=sy+(i>>1)*21;sprp[at]=ptr+i;sprc[at]=8;
        if(sprx[at]>=0 && sprx[at]<344 && sy+(i>>1)*21>=50 && sy+(i>>1)*21<250)sprmask|=1<<at;
    }
}
static void dim(u8 slot){u8 i;for(i=0;i<4;++i)sprc[slot+i]=12;}
static void prepare_blocks(void){
    sprbuf^=1;sprmask=0;sprite_priority=0;
    if(orient==3){
        /* Foreground cube owns lower sprite numbers, preserving occlusion. */
        if(worldy(px,py)>=worldy(qx,qy)){object(0,px,py,108,0);object(4,qx,qy,108,0);dim(active?0:4);}
        else{object(4,px,py,108,0);object(0,qx,qy,108,0);dim(active?4:0);}
    }else object(0,px,py,orient*36,0);
}
void show_blocks(void){prepare_blocks();sprite_commit();}
static void tile(u8 x,u8 y,u8 t){
    blit_x=worldx(x,y);blit_y=worldy(x,y)-3;
    blit_source=tile_data+((u16)t*4+(blit_x&3))*128;blit_tile();
}
static void align_board(void){
    u8 x,y;int minx=300,maxx=0,miny=300,maxy=-300,sx,sy;
    for(y=0;y<10;++y)for(x=0;x<15;++x)if(board[y*15+x]){
        sx=x*7+y*3;sy=(int)y*8-(int)x*3;
        if(sx<minx)minx=sx;if(sx+11>maxx)maxx=sx+11;
        if(sy-28<miny)miny=sy-28;if(sy+13>maxy)maxy=sy+13;
    }
    ox=(160-maxx-minx)/2;oy=(198-maxy-miny)/2;
}
static void board_draw(void){
    u8 y,x,t;blit_erase=0;
    for(y=0;y<10;++y){x=15;while(x){--x;if(y*15+x==collapse)continue;t=visible_tiles[y*15+x];if(t)tile(x,y,t);}}
}
/* Recompose a four-byte by sixteen-line window offscreen. An isometric
   tile can overlap this window only within two board cells on each axis.
   Visit them in exactly the same back-to-front order as board_draw. */
void __fastcall__ repaint_cell(u8 pos){
    s8 x=pos%15,y=pos/15,xx,yy,dx,dy;u8 t,sx,sy,col,row;
    u8 x0=worldx(x,y),y0=worldy(x,y)-3;
    memset(patch_pixels,0,sizeof(patch_pixels));
    for(yy=y-2;yy<=y+2;++yy){
        if(yy<0||yy>=10)continue;
        for(xx=x+2;xx>=x-2;--xx){
            if(xx<0||xx>=15)continue;
            t=visible_tiles[(u8)yy*15+(u8)xx];if(!t)continue;
            sx=worldx(xx,yy);sy=worldy(xx,yy)-3;
            dx=(s8)(sx>>2)-(s8)(x0>>2);dy=(s8)(sy-y0);
            if(dx<=-4||dx>=4||dy<=-16||dy>=16)continue;
            col=dx<0?-dx:0;row=dy<0?-dy:0;
            blit_source=tile_data+((u16)t*4+(sx&3))*128+(u16)row*8+col;
            destination=patch_pixels+(dy>0?(u8)dy*4:0)+(dx>0?dx:0);
            patch_width=4-(dx<0?-dx:dx);patch_rows=16-(dy<0?-dy:dy);
            blend_patch();
        }
    }
    blit_x=x0;blit_y=y0;commit_patch();
}
static void split_hud(void){
    if(orient==3){put(1,22,"SPLIT");put(7,22,active?"B":"A");put(13,22,"SPACE OR FIRE : SWAP");paint_bar(22,7);}
    else memset((void*)(0xe000+22*320),0,320);
}
static void hud(void){
    put(1,0,"BLOXORZ");put(14,0,"STAGE");number(20,0,stage+1,2);put(27,0,"CODE");put(32,0,level_codes[stage]);
    put(1,2,"MOVES");number(7,2,moves,5);put(28,2,"FALLS");number(34,2,falls,4);
    paint_bar(0,3);paint_bar(2,12);
    split_hud();
}
void gameplay(void){
    u8 i;for(i=0;i<150;++i)visible_tiles[i]=tile_at(i);
    phase=2;music_mode=SOUND_SCORE;clear();palette(11,15,8);align_board();board_draw();hud();
    bottom("WASD/CURSORS/JOY2   F1 PAUSE   F3 RETRY");tracking_move=0;buffered_dir=255;
    show_blocks();flush_input();release_dir=direction(inputjoy,inputkey);
}
void start_stage(void){collapse=255;load_level();last_stage=stage;have_continue=1;gameplay();}
typedef struct {u8 pos,side,open;int sx,sy;} Hinge;
static Hinge hinges[2];
static void draw_hinge(u8 leaf,u8 frame){
    u8 j,part,second,slot=4+leaf*2,bank=(frame&1)*8+leaf*4;
    u8 art=hinges[leaf].side+(hinges[leaf].open?8-frame:frame);
    int sx=hinges[leaf].sx+(s8)sprite_dx[165+art]*2;
    int sy=hinges[leaf].sy+(s8)sprite_dy[165+art];
    source=sprite_stream+sprite_offset[165+art];destination=(u8*)(0xcc00+(u16)bank*64);unpack();
    second=hinge_second[art];
    for(j=0;j<(second?2:1);++j){
        part=j?second:0;sprx[slot]=sx+(part&1)*24;spry[slot]=sy+(part>>1)*21;
        sprp[slot]=48+bank+part;sprc[slot]=15;sprmask|=1<<slot;sprite_priority|=1<<slot;++slot;
    }
}
static void animate_hinges(u8 count){
    u8 i,f,rest,from;
    prepare_blocks();
    if(orient==3){
        /* A resting cube uses only its left column. Pack the two columns
           into the four frontmost hardware sprites, keeping their depth order. */
        rest=0;
        for(i=0;i<4;++i){from=i*2;sprx[i]=sprx[from];spry[i]=spry[from];
            sprp[i]=sprp[from];sprc[i]=sprc[from];if(sprmask&(1<<from))rest|=1<<i;}
    }else rest=sprmask&15;
    for(f=0;f<9;++f){
        sprmask=rest;sprite_priority=0;
        for(i=0;i<count;++i)draw_hinge(i,f);
        sprite_commit();
        if(f==0){
            /* The hardware hinges are already visible while their resting
               bitmap tiles are removed. The final handoff is the reverse. */
            for(i=0;i<count;++i)visible_tiles[hinges[i].pos]=0;
            for(i=0;i<count;++i)repaint_cell(hinges[i].pos);
        }
    }
    for(i=0;i<count;++i)visible_tiles[hinges[i].pos]=hinges[i].open?7:8;
    for(i=0;i<count;++i)repaint_cell(hinges[i].pos);
    sprmask=rest;sprite_priority=0;sprite_commit();
}
static void bridge_change(void){
    u8 i,pos,x,y,n=0;u16 changed=oldbridges^bridges;
    if(!changed)return;
    for(i=0;i<bridge_count;++i){
        pos=bridge_cells[i*2];if(!(changed&((u16)1<<bridge_cells[i*2+1])))continue;
        x=pos%15;y=pos/15;hinges[n].pos=pos;hinges[n].side=board[pos]>=9?9:0;
        hinges[n].open=tile_at(pos)==7;hinges[n].sx=24+worldx(x,y)*2;hinges[n].sy=50+worldy(x,y);
        if(++n==2){
            if(hinges[1].sy>hinges[0].sy){Hinge temp;temp=hinges[0];hinges[0]=hinges[1];hinges[1]=temp;}
            animate_hinges(2);n=0;
        }
    }
    if(n)animate_hinges(n);
}
void __fastcall__ rotation(u8 d){
    u8 f,slot; s8 x,y;u8 moving=oldo==3?3:oldo;
    for(f=1;f<=8;++f){
        anim_frame=f;sprbuf^=1;sprmask=0;slot=0;
        x=(oldo==3&&olda)?oldqx:oldpx;y=(oldo==3&&olda)?oldqy:oldpy;
        if(oldo==3){
            if(worldy(x,y)<worldy(olda?oldpx:oldqx,olda?oldpy:oldqy))slot=4;
            object(4-slot,olda?oldpx:oldqx,olda?oldpy:oldqy,108,0);
            dim(4-slot);
        }
        frame_index=moving*36+d*9+f;object(slot,x,y,frame_index,0);sprite_commit();
    }
}
static void fall_animation(u8 win){
    u8 f; s8 x,y;u8 o;
    x=oldo==3&&olda?qx:px;y=oldo==3&&olda?qy:py;o=orient==3?3:orient;
    sfx=win?3:1;
    if(!win&&orient==0&&px<15&&py<10&&board[py*15+px]==3){
        collapse=py*15+px;visible_tiles[collapse]=0;
    }
    for(f=0;f<20;++f){
        sprbuf^=1;sprmask=0;
        if(win)object(0,x,y,144+f,0);
        else if(collapse!=255){object(0,x,y,o*36,(f*f)/6);object(4,x,y,164,(f*f)/6);}
        else object(0,x,y,o*36+anim_dir*9+(f>8?8:f),(f*f)/6);
        if(oldo==3){object(4,olda?oldpx:oldqx,olda?oldpy:oldqy,108,0);dim(4);}
        sprite_commit();
        if(f==0&&collapse!=255)repaint_cell(collapse);
    }
    REG(0xd015)=0;
}
/* The six sprites form one pose. Unpack into another slot while the VIC
   scans the current pose, then switch all six pointers in the border. */
static void prepare_menu_pose(void){
    u8 pose=menu_sequence[menu_frame],slot=pose_slot[pose];
    if(pose==menu_pose)return;
    menu_pose=pose;
    menu_pointer=32+slot*6;
    destination=(u8*)(0xc000+(u16)menu_pointer*64);
    if(pose_source[pose]<4096){
        source=(const u8*)(0xd000+pose_source[pose]);menu_unpack_banked();
    }else{
        source=menu_extra+(pose_source[pose]-4096);menu_unpack();
    }
}
static void advance_menu(void){
    u8 i;
    for(i=0;i<6;++i)REG(0xc7f8+i)=menu_pointer+i;
    menu_clock+=36;
    if(menu_clock>=50){
        menu_clock-=50;
        if(++menu_frame==sizeof(menu_sequence))menu_frame=MENU_LOOP;
        prepare_menu_pose();
    }
}
static void menu(void){
    u8 i;
    phase=1;music_mode=SOUND_SCORE;REG(0xd011)=0x2b;REG(0xd015)=0;
    REG(0xd016)=8;source=menu_bitmap;destination=(u8*)0xe000;menu_unpack();
    source=menu_ink;destination=(u8*)0xc400;menu_unpack();
    if(!have_continue)for(i=15;i<18;++i)memset((void*)(0xc400+(u16)i*40+21),0xb0,12);
    show_audio_setting();
    menu_frame=menu_clock=0;menu_pose=255;prepare_menu_pose();
    memset(cached_frame,255,sizeof(cached_frame));
    sprmask=63;sprite_priority=0;
    for(i=0;i<6;++i){
        sprx[i]=253+(i%3)*24;spry[i]=56+(i/3)*42;sprp[i]=menu_pointer+i;sprc[i]=8;
    }
    wait_frame();REG(0xd017)=63;REG(0xd01d)=0;REG(0xd026)=15;
    publish_sprites();REG(0xd011)=0x3b;
    flush_input();
}
static void instructions(void){
    phase=4;clear();palette(11,15,8);center(1,"HOW TO PLAY");paint_bar(1,3);
    put(2,4,"ROLL THE BLOCK UPRIGHT INTO THE HOLE.");
    put(2,6,"CIRCLE  ANY BLOCK PRESSES THIS SWITCH");
    put(2,8,"X       ONLY THE UPRIGHT BLOCK WORKS");
    put(2,10,"ORANGE  COLLAPSES UNDER UPRIGHT WEIGHT");
    put(2,12,"DIAMOND SPLITS THE BLOCK INTO CUBES");
    put(2,14,"SPACE / FIRE SELECTS THE OTHER CUBE");
    put(2,16,"BRING THE CUBES TOGETHER TO REJOIN");
    put(2,18,"WASD / CURSOR KEYS / JOYSTICK PORT 2");
    put(2,20,"F1 PAUSE   F3 RETRY");
    bottom("F7 BACK");flush_input();
}
static void password_screen(void){
    phase=5;clear();palette(11,15,8);center(3,"ENTER STAGE PASSCODE");
    center(8,"USE THE ORIGINAL SIX DIGIT CODE");
    password_len=0;memset(password,0,7);center(13,"------");
    bottom("F1 ACCEPT   F3 ERASE   F7 BACK");flush_input();
}
static void pause_screen(void){
    phase=3;REG(0xd015)=0;clear();palette(11,15,8);center(3,"PAUSED");
    put(12,7,"F1   RESUME");put(12,10,"F3   RESTART");
    put(12,13,"F7   MAIN MENU");show_audio_setting();
    put(12,20,"STAGE");number(18,20,stage+1,2);put(22,20,level_codes[stage]);
    flush_input();
}
static void completed(void){
    phase=7;music_mode=SOUND_EFFECTS_ONLY;clear();palette(11,3,8);center(3,"ALL 33 STAGES COMPLETE");
    center(7,"YOU FOUND EVERY WAY DOWN.");put(10,11,"TOTAL MOVES");number(25,11,moves,5);
    put(10,13,"TOTAL FALLS");number(25,13,falls,4);center(17,"THANK YOU FOR PLAYING");
    center(20,"STUDIO 256");bottom("F7 MAIN MENU");flush_input();
}
void __fastcall__ move_block(u8 d){
    oldpx=px;oldpy=py;oldqx=qx;oldqy=qy;oldo=orient;olda=active;oldbridges=bridges;anim_dir=d;
    sfx=1;step(d);
    if(d==4){put(7,22,active?"B":"A");show_blocks();return;}
    tracking_move=result!=1&&result!=2;sampled_dir=direction(inputjoy,inputkey);
    rotation(d);bridge_change();
    if(result==1){phase=8;fall_animation(0);if(falls<9999)++falls;delay(6);start_stage();return;}
    if(result==2){
        phase=6;fall_animation(1);bottom("STAGE CLEAR");delay(22);
        if(stage==32){completed();return;}++stage;start_stage();return;
    }
    if(result==3){
        u8 f;REG(0xd015)=0;sfx=3;
        for(f=20;f>0;f-=2){sprbuf^=1;sprmask=0;object(0,px,py,108,-(s8)f);object(4,qx,qy,108,-(s8)f);dim(4);sprite_commit();}
    }
    number(7,2,moves,5);if((oldo==3)!=(orient==3))split_hud();
    show_blocks();tracking_move=0;
}
void intro(void){
    u16 f;u8 cursor;
    phase=0;music_mode=SOUND_EFFECTS_ONLY;clear();palette(0,0,0);
    source=circuit_bitmap;destination=(u8*)0xe000;menu_unpack();
    source=circuit_screen;destination=(u8*)0xc800;menu_unpack();
    source=circuit_color;destination=(u8*)0xcc00;menu_unpack();
    source=circuit_reveal;destination=(u8*)0x0400;menu_unpack();
    memset((void*)0xc380,0,64);
    REG(0xc39b)=REG(0xc39e)=0x3f;REG(0xc39c)=REG(0xc39f)=255;REG(0xc39d)=REG(0xc3a0)=0xfc;
    REG(0xc7f8)=14;REG(0xd01c)=0xfe;REG(0xd027)=1;REG(0xd001)=205;
    for(f=0;f<400;++f){
        wait_frame();
        if(f<=236)circuit_tick((u8)f);
        cursor=0;
        if(f>=160&&f<180)cursor=100;else if(f>=187&&f<208)cursor=176;
        else if(f>=215&&f<236)cursor=250;
        REG(0xd000)=cursor+13;REG(0xd010)=cursor==250;REG(0xd015)=cursor&&((f&15)<12);
        if(f==180||f==208||f==236)sfx=2;
        poll();if(edgekey(KEY_F1)){remember();break;}remember();
    }
    REG(0xd015)=0;REG(0xd01c)=255;
}
void main(void){
    u8 d,codeidx;
    hw_init();intro();menu();
    while(1){
        if(phase!=2||buffered_dir==255)wait_frame();poll();
        if(phase==1){
            if(edgekey(KEY_F1)){stage=0;moves=falls=0;start_stage();}
            else if(edgekey(KEY_F3)&&have_continue){stage=last_stage;start_stage();}
            else if(edgekey(KEY_F5))password_screen();
            else if(edgekey(KEY_F7))instructions();
            else advance_menu();
        }else if(phase==4||phase==7){if(edgekey(KEY_F7))menu();}
        else if(phase==5){
            if(inputkey!=old_key){
                if(inputkey>='0'&&inputkey<='9'&&password_len<6){password[password_len++]=inputkey;password[password_len]=0;}
                if(inputkey==KEY_F3&&password_len)password[--password_len]=0;
                if(inputkey==KEY_F7)menu();
                if(inputkey==KEY_F1&&password_len==6){
                    for(codeidx=0;codeidx<33;++codeidx)if(!strcmp(password,level_codes[codeidx]))break;
                    if(codeidx<33){stage=codeidx;moves=falls=0;start_stage();}
                    else center(17,"CODE NOT FOUND");
                }
                if(phase==5){center(13,"------");put(17,13,password);}
            }
        }else if(phase==3){
            if(edgekey(KEY_F1))gameplay();
            else if(edgekey(KEY_F7))menu();else if(edgekey(KEY_F3))start_stage();
        }else if(phase==2){
            if(edgekey(KEY_F1)){pause_screen();}
            else if(edgekey(KEY_F3))start_stage();
            else{
                d=direction(inputjoy,inputkey);
                if(d==release_dir)d=255;else release_dir=255;
                if(buffered_dir!=255){if(d==255||d==sampled_dir)d=buffered_dir;buffered_dir=255;}
                else if((inputjoy&32)&&d!=255)d=direction(0,inputkey);
                if(swap_pressed()&&orient==3)d=4;
                if(d!=255){
                    if(d<4)joy_used=joystick_bits[d];
                    move_block(d);
                }
                /* A memory-only command mailbox supports deterministic VICE regression. */
                if(command){d=command-1;command=0;move_block(d);}
            }
        }
        remember();
    }
}
