#include "game.h"

u8 mode,sound_on=1,return_mode,shop_item;
const char* notice;
u8 menu_item,default_difficulty=1;

u8* upgrade_rank(u8 item)
{
    if (mode==GUN_SHOP) return &campaign.gear[item];
    switch (item) {
    case 0:return &campaign.armor;
    case 1:return &campaign.movement;
    case 2:return &campaign.rotation;
    default:return &campaign.sight;
    }
}

/* Flash globalSettings and upgradesController index the starter gun at
   level zero. The other gun entries include their initial purchase. */
const u16 initial_ammo[]={0,28,800,63,28,400,12,400,28,4};
const u16 refill[]={0,21,600,48,21,300,9,300,21,4};
const u16 refill_cost[]={0,50,100,200,200,200,200,300,400,300};
const u16 capacity[]={0,105,3000,236,105,1500,45,1500,105,20};
const u16 hull_hp[]={700,1260,2100,3220,4900,6300};
u8 max_rank(u8 item) {return mode==GUN_SHOP && item!=MINIGUN?6:5;}
u16 price(u8 item)
{
    static const u16 costs[][6]={
        {200,300,400,500,600,0}, {2750,500,900,1300,1700,2100},
        {8000,2500,3000,3500,4000,4500}, {10000,3000,4000,5000,6000,7000},
        {28000,11000,12000,13000,14000,15000},
        {2000,4000,8000,16000,20000,0}, {500,600,700,800,900,0}};
    static const u8 group[]={0,1,2,3,3,3,3,4,4,2};
    u8 owned=*upgrade_rank(item);
    if (owned>=max_rank(item)) return 0;
    return costs[mode==GUN_SHOP?group[item]:(item?6:5)][owned];
}
void shop_buy(void)
{
    u16 cost=price(shop_item);
    if (!cost) notice="upgrade already at maximum";
    else if (campaign.cash<cost) notice="more credits needed";
    else {
        campaign.cash-=cost;
        if (mode==GUN_SHOP && shop_item && !*upgrade_rank(shop_item))
            campaign.stock[shop_item]=initial_ammo[shop_item];
        ++*upgrade_rank(shop_item);
        sound(CASH_SOUND);notice="upgrade installed";
    }
}
static void buy_ammo(void)
{
    u8 w=shop_item;
    if (!w) notice="minigun has unlimited ammunition";
    else if (!campaign.gear[w]) notice="buy this weapon first";
    else if (campaign.stock[w]>=capacity[w]) notice="ammunition full";
    else if (campaign.cash<refill_cost[w]) notice="more credits needed";
    else {
        campaign.cash-=refill_cost[w];campaign.stock[w]+=refill[w];
        if (campaign.stock[w]>capacity[w]) campaign.stock[w]=capacity[w];
        sound(CASH_SOUND);notice="ammunition loaded";
    }
}
static void menu(u8 next)
{
    mode=next;menu_item=0;notice=0;draw_screen();
}

static void settings(void)
{
    return_mode=mode;menu(SETTINGS);
}

static void dispatch(void)
{
    if (mode!=FIELD) menu_input();
    switch (mode) {
    case TITLE:
        if (action&F1) new_campaign();
        else if (action&F3) settings();
        else if (action&F5) menu(HELP);
        else if (action&F7) {
            if (disk_load()) menu(GARAGE);
            else {notice="no readable tanks save on drive 8";draw_screen();}
        }
        break;
    case FIELD:
        if (action&F1) menu(PAUSE);
        else if (action&F5) settings();
        else {
            if (action&F3) change_weapon();
            if (action&F7) place_mine();
            play_tick();
        }
        break;
    case PAUSE:
        if (action&F1) {mode=FIELD;draw_field();reset_gun_clock();}
        else if (action&F3) start_stage();
        else if (action&F5) settings();
        else if (action&F7) {sync_ammo();menu(GARAGE);}
        break;
    case SETTINGS:
        if (action&F1) {
            mode=return_mode;
            if (mode==FIELD) {draw_field();reset_gun_clock();}else draw_screen();
        } else if (action&F3) {music_on^=1;draw_screen();}
        else if (action&F5) {sound_on^=1;silence();draw_screen();}
        else if ((action&F7) && return_mode==TITLE) {default_difficulty=(default_difficulty+1)%3;draw_screen();}
        break;
    case HELP:case VICTORY:
        if (action&F1) menu(TITLE);
        break;
    case DEFEAT:
        if (action&F1) start_stage();
        else if (action&F3) menu(GARAGE);
        break;
    case GARAGE:
        if (action&F1) start_stage();
        else if (action&(F3|F5)) {shop_item=0;menu((action&F3)?HULL_SHOP:GUN_SHOP);}
        else if (action&F7) {notice=disk_save()?"campaign saved":"save failed - check drive 8";draw_screen();}
        break;
    case HULL_SHOP:case GUN_SHOP:
        if (action&F1) menu(GARAGE);
        else if (action&F3) {
            if (++shop_item==(mode==GUN_SHOP?GUNS:4)) shop_item=0;
            notice=0;draw_screen();
        } else if (action&F5) {shop_buy();draw_screen();}
        else if (action&F7 && mode==GUN_SHOP) {buy_ammo();draw_screen();}
        break;
    }
}

int main(void)
{
    video_init();
    silence();
    music_irq_on();
    menu(TITLE);
    while (1) {
        wait_frame();
        read_input();
        audio_tick();
        dispatch();
    }
}
