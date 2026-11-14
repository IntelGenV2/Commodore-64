#include "game.h"

u8 walk,turn,action,fire;
u8 nav;
static u8 old_keys,old_nav;

void read_input(void)
{
    u8 keys=0;
    read_pins();
    walk=turn=0;
    if (contacts[1]&16) walk|=UP;    /* I */
    if (contacts[5]&16) walk|=DOWN;  /* K */
    if (contacts[2]&16) walk|=LEFT;  /* J */
    if (contacts[2]&32) walk|=RIGHT; /* L */
    if (contacts[2]&2) turn|=LEFT;   /* A */
    if (contacts[5]&2) turn|=RIGHT;  /* S */
    fire=(contacts[4]&128)!=0;
    if (contacts[4]&1) keys|=F1;
    if (contacts[5]&1) keys|=F3;
    if (contacts[6]&1) keys|=F5;
    if (contacts[3]&1) keys|=F7;
    action=keys & ~old_keys;
    old_keys=keys;
    keys=0;
    if (contacts[7]&1) keys|=((contacts[7]&2)||(contacts[4]&64))?UP:DOWN;
    if (contacts[2]&1) keys|=((contacts[7]&2)||(contacts[4]&64))?LEFT:RIGHT;
    if ((contacts[1]&1) || fire) keys|=FIRE;
    nav=keys&~old_nav;old_nav=keys;
}

/* Entries follow the displayed rows. F keys remain direct shortcuts. */
static const u8 title[]={F1,F3,F5,F7},pause[]={F1,F3,F5,F7};
static const u8 garage[]={F3,F5,F1,F7},settings[]={F3,F5,F7,F1};
static const u8 defeat[]={F1,F3};
void menu_input(void)
{
    const u8* items=title;
    u8 count=1;
    if (!nav || action) return;
    if (mode==HULL_SHOP || mode==GUN_SHOP) {
        count=mode==GUN_SHOP?GUNS:4;
        if (nav&UP) shop_item=shop_item?shop_item-1:count-1;
        if (nav&DOWN) shop_item=(shop_item+1==count)?0:shop_item+1;
        if (nav&LEFT) action=F1;
        else if (nav&RIGHT && mode==GUN_SHOP) action=F7;
        else if (nav&FIRE) action=F5;
        else {notice=0;draw_screen();}
        return;
    }
    switch (mode) {
    case TITLE:count=4;break;
    case PAUSE:items=pause;count=4;break;
    case GARAGE:items=garage;count=4;break;
    case SETTINGS:items=settings;count=return_mode==TITLE?4:3;break;
    case DEFEAT:items=defeat;count=2;break;
    }
    if (menu_item>=count) menu_item=0;
    if (mode==GARAGE && menu_item==2 && (nav&(LEFT|RIGHT))) {
        if (nav&LEFT && campaign.stage) --campaign.stage;
        if (nav&RIGHT && campaign.stage<campaign.unlocked) ++campaign.stage;
    } else if (nav&(FIRE|RIGHT)) {
        action=items[menu_item];
        if (mode==SETTINGS && count==3 && menu_item==2) action=F1;
        return;
    } else if (nav&LEFT && mode==SETTINGS) {action=F1;return;}
    else if (nav&UP) menu_item=menu_item?menu_item-1:count-1;
    else if (nav&DOWN) menu_item=(menu_item+1==count)?0:menu_item+1;
    notice=0;draw_screen();
}
