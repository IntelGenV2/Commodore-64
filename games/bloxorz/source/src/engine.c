#include "game.h"
#include "levels.h"
u8 stage,px,py,orient,qx,qy,active,result,board[150],groups[150];
u16 bridges,moves;
const u8 *bridge_cells;
u8 bridge_count;
static const u8 *switches,*splits;
static u8 switch_count,split_count;
static u16 word(const u8 *p){return p[0]|((u16)p[1]<<8);}
void load_level(void){
    const u8 *p;u8 i,n,t;
    p=level_maps+(u16)stage*75;
    for(i=0;i<75;++i){t=*p++;board[i*2]=t&15;board[i*2+1]=t>>4;}
    memset(groups,255,150);
    p=level_spec+level_offset[stage];px=*p++;py=*p++;bridges=word(p);p+=2;n=*p++;
    bridge_cells=p;bridge_count=n;
    for(i=0;i<n;++i){t=*p++;groups[t]=*p++;}
    switch_count=*p++;switches=p;p+=(u16)switch_count*7;split_count=*p++;splits=p;
    orient=qx=qy=active=result=0;
}
u8 __fastcall__ tile_at(u8 pos){
    u8 t;if(pos>=150)return 0;t=board[pos];
    if(t>=7)return (bridges&((u16)1<<groups[pos]))?7:8;
    return t;
}
static u8 support(s8 x,s8 y){
    u8 t;if(x<0||x>=15||y<0||y>=10)return 0;t=tile_at(y*15+x);return t&&t!=8;
}
static void press(u8 x,u8 y,u8 upright){
    const u8 *p;u8 i,pos,t;pos=y*15+x;t=board[pos];
    if(t!=2 && !(t==5&&upright))return;
    p=switches;
    for(i=0;i<switch_count;++i){
        if(p[0]==pos){bridges=((bridges&~word(p+1))|word(p+3))^word(p+5);sfx=2;}
        p+=7;
    }
}
void __fastcall__ step(u8 d){
    s8 x,y;u8 t,i;const u8 *p;
    result=0;
    if(d==4){if(orient==3)active^=1;return;}
    if(d>3)return;
    if(moves<65535u)++moves;
    if(orient==3){
        x=active?qx:px;y=active?qy:py;
        if(d==0)--x;if(d==1)--y;if(d==2)++x;if(d==3)++y;
        if(active){qx=x;qy=y;}else{px=x;py=y;}
        if(!support(x,y)){result=1;return;}
        press(x,y,0);
        if(py==qy && (px+1==qx || qx+1==px)){
            if(qx<px)px=qx;orient=1;
        }else if(px==qx && (py+1==qy || qy+1==py)){
            if(qy<py)py=qy;orient=2;
        }
        if(orient!=3){qx=qy=active=0;result=4;}
        return;
    }
    x=px;y=py;
    if(orient==0){
        if(d==0){x-=2;orient=1;}if(d==1){y-=2;orient=2;}
        if(d==2){++x;orient=1;}if(d==3){++y;orient=2;}
    }else if(orient==1){
        if(d==0){--x;orient=0;}if(d==2){x+=2;orient=0;}
        if(d==1)--y;if(d==3)++y;
    }else{
        if(d==1){--y;orient=0;}if(d==3){y+=2;orient=0;}
        if(d==0)--x;if(d==2)++x;
    }
    px=x;py=y;
    if(!support(x,y)||(orient==1&&!support(x+1,y))||(orient==2&&!support(x,y+1))){result=1;return;}
    t=board[y*15+x];
    if(!orient){
        if(t==3){result=1;return;}
        if(t==4){result=2;return;}
        if(t==6){
            p=splits;
            for(i=0;i<split_count;++i){
                if(p[0]==y*15+x){px=p[1];py=p[2];qx=p[3];qy=p[4];active=0;orient=3;result=3;return;}p+=5;
            }
        }
    }
    if(orient==2)press(x,y+1,0);
    press(x,y,!orient);
    if(orient==1)press(x+1,y,0);
}
