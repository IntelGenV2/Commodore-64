#include <string.h>
#include "sound.h"
#include "state.h"
#include "passes.h"

typedef unsigned char byte;
#define VIC ((volatile byte *)0xd000)
#define BITMAP ((byte *)0xe000)
#define SCREEN ((byte *)0xcc00)
#define SPRPTR ((volatile byte *)0xcff8)

enum { LEFT=1, RIGHT=2, JUMP=4, HINT=8, RETRY=16, MUTE=32, JOY_DOWN=64, PAUSE=128 };
enum { TITLE, PLAY, DYING, LEAVING, ENDING };
enum { METER_REDRAW = 254, METER_HIDDEN = 255 };

extern const byte title_art[], room_art[], door_art[], plate_art[], font[], sprite_art[];
extern const byte retry_art[];
extern const byte room_shore[], room_snow[], room_bedtime[];
extern byte disk_keys, joy_pins;
static byte old_pins, pin_edge;
enum { CYCLE_ARMED=1, CYCLE_OPEN, CYCLE_LOCKED };
#include "../build/ledges.h"
static const byte *const rooms[] = {room_art, room_shore, room_snow, room_bedtime};
static const byte *bounds;
static byte night_inks[640], dimmed;
void init_machine(void);
void wait_frame(void);
byte read_controls(void);
void __fastcall__ load_scene(const byte *source);

byte mode, controls, pressed, game_clock;
struct RunState run;
static byte old_controls, delay, painted_plate, painted_gate;
static byte painted_lift;
static byte retry_flash, painted_retry, painted_hint_seconds;
static byte jumped, was_grounded, message_ticks;
static byte old_disk_keys, zone_on_screen = 255;

/* One glyph occupies one VIC-II color cell, including its right bearing. */
static void label(byte col, byte row, const char *s, byte width, byte ink)
{
    unsigned n = row*40u+col;
    byte *pixels = BITMAP+(n<<3);
    byte *colors = SCREEN+n;
    byte ch;
    while (width--) {
        ch = *s ? (*s++ & 0x7f) : 32;
        memcpy(pixels, font+((unsigned)(ch-32)<<3), 8);
        pixels += 8;
        *colors++ = ink << 4;
    }
}

static void screen(const byte *scene)
{
    sound_suspend();
    VIC[0x15] = 0;
    VIC[0x17] = VIC[0x1d] = 0;
    VIC[0x11] = 0x2b;
    load_scene(scene);
}

static byte hint_visible(void)
{
    return run.hint_ticks && run.hint_ticks != HINT_READY;
}

static void hint_meter(void)
{
    byte seconds = METER_HIDDEN;
    char time_left[] = "0S LEFT";
    if (controls & HINT)
        seconds = run.hint_ticks==HINT_READY ? 5 : (run.hint_ticks+49u)/50u;
    if (seconds == painted_hint_seconds) return;
    painted_hint_seconds = seconds;
    if (seconds != METER_HIDDEN) time_left[0] += seconds;
    label(19,23,seconds==METER_HIDDEN ? "" : time_left,7,3);
}

static void note(void)
{
    const char *line;
    byte hint;
    if (message_ticks) return;
    hint = hint_visible();
    line = hint ? pass_text[run.pass].hint : pass_text[run.pass].clue;
    switch (run.pass) {
        case HANDS_OFF: if (!run.gate) line="THE DOOR SHUT. F3 TO TRY AGAIN."; break;
        case CYCLE:
            if (run.progress==CYCLE_ARMED) line=hint ? "NOW FALL INTO THE SPIKES." : "A CLICK UNDERFOOT.";
            if (run.progress==CYCLE_OPEN) line=hint ? "DOOR OPEN. LEAVE RED ALONE." : "THE DOOR IS STILL OPEN.";
            if (run.progress==CYCLE_LOCKED) line=hint ? "YOU PRESSED IT TWICE. F3 TO RETRY." : "THE LATCH IS STUCK. F3 TO RETRY.";
            break;
        case BUDGET: if (!run.gate && run.progress==2 && run.grounded && !run.on_plate)
            line="BOTH JUMPS USED. F3 TO TRY AGAIN."; break;
        case TIMER: if (run.gate) line=hint ? "RUN FOR THE DOOR!" : "TICK, TICK, TICK."; break;
        case PICTURE: if (run.armed && !run.gate)
            line=hint ? "JOIN THE ROOF. L/R PICK. FIRE TURN." : "LEFT/RIGHT SELECT. FIRE TURNS.";
            break;
        case FAINT: if (dimmed && !run.gate)
            line=hint ? "WIGGLE LEFT AND RIGHT TO WAKE UP." : "MY EYELIDS FEEL HEAVY.";
            break;
    }
    label(1,24,line,38,hint ? 3 : 15);
}

static void hud(void)
{
    char number[] = "PASS 00/40";
    byte i, local = run.pass%10;
    number[5] = '0'+(run.pass+1)/10;
    number[6] = '0'+(run.pass+1)%10;
    label(29,0,number,10,3);
    label(24,1,"F5 SAVE F7 LOAD",15,12);
    for (i=0; i<10; ++i) {
        byte *pixel = BITMAP+((unsigned)(14+i)<<3);
        pixel[3] = pixel[4] = 0x7e;
        SCREEN[14+i] = i < local ? 0x30 : (i == local ? 0xa0 : 0xb0);
    }
    label(1,22,pass_text[run.pass].name,17,1);
    label(19,22,"F1:HINT",7,run.hint_ticks ? 3 : 12);
    hint_meter();
    note();
}

/* Packed patch = all bitmap cells, followed by their screen-color bytes. */
static void patch(const byte *art, byte col, byte row, byte width, byte rows)
{
    unsigned n = row*40u+col;
    byte *pixels = BITMAP+(n<<3);
    byte *colors = SCREEN+n;
    byte count = width<<3;
    const byte *inks = art+count*rows;
    while (rows--) {
        memcpy(pixels,art,count);
        memcpy(colors,inks,width);
        art += count;
        inks += width;
        pixels += 320;
        colors += 40;
    }
}

static void retry_button(void)
{
    byte active = retry_flash!=0;
    if (active != painted_retry) {
        patch(retry_art+active*216u,27,22,12,2);
        painted_retry = active;
    }
}

static void fixtures(void)
{
    byte plate_down=run.on_plate || (run.pass==WEIGHT && run.gate);
    if (run.gate != painted_gate) {
        patch(door_art+((run.gate && run.pass!=ILLUSION) ? 270 : 0),33,14,6,5);
        painted_gate = run.gate;
        if (hint_visible()) note();
    }
    if (plate_down != painted_plate) {
        patch(plate_art+(plate_down ? 36 : 0),16,10,4,1);
        painted_plate = plate_down;
    }
}

/* Three small lamps below the platform report puzzle progress. */
static void lamps(byte count)
{
    byte i;
    if (count == run.lamp_count) return;
    run.lamp_count = count;
    for (i=0; i<3; ++i) {
        SCREEN[12*40+16+i] = i<count ? 0x30 : 0xc0;
    }
}

/* Three separately turnable picture strips meet to make a house. */
static const byte house[3][8] = {
    {0,0,0,0,1,3,7,15}, {0,0,24,60,126,255,255,255}, {0,0,0,0,128,192,224,240}
};
static void picture(void)
{
    byte x,y,i,part,flip;
    byte *cell;
    for (part=0;part<3;++part) {
        flip=run.parts & (1<<part);
        i=part+17;
        cell=BITMAP+(4*40u+i)*8;
        for (y=0;y<8;++y) {
            x=flip ? 7-y : y;
            cell[y]=house[part][x];
            cell[320+y]=flip ? house[part][y] : (part==1 ? 0xc3 : (part ? 0x20 : 4));
        }
        SCREEN[4*40+i]=SCREEN[5*40+i]=part==run.charge ? 0x70 : 0xf0;
    }
}

static void robot(unsigned x, byte y, byte ptr)
{
    byte i;
    for (i=0; i<5; ++i) {
        VIC[i*2] = (byte)x;
        VIC[i*2+1] = y;
        SPRPTR[i] = ptr+i;
    }
    VIC[0x10] = x>=256 ? 31 : 0;
    VIC[0x15] = 31;
}

static void player(void)
{
    byte pose = !run.grounded ? 3 : ((controls & (LEFT|RIGHT)) ? 1+((run.stride>>2)&1) : 0);
    robot(run.player_x+16,run.feet+50-18,(pose+(run.facing_left ? 4 : 0))*5);
}

/* Props use the three spare hardware sprites. */
static void marker(byte slot, unsigned x, byte y, byte shape, byte color)
{
    byte sprite=5+slot;
    unsigned vx=x+24;
    VIC[sprite*2]=(byte)vx;
    VIC[sprite*2+1]=y+50;
    if (vx>=256) VIC[0x10] |= 1<<sprite;
    VIC[0x27+sprite]=color;
    SPRPTR[sprite]=shape;
    VIC[0x15] |= 1<<sprite;
}

static byte touching(unsigned x, byte y)
{
    return run.player_x+10>=x && run.player_x<=x+10 &&
           run.feet+3>=y && run.feet<=y+19;
}

static byte lift_y(void)
{
    return run.charge>64 ? 152-(run.charge-64) : 88+run.charge;
}

static void items(void)
{
    switch (run.pass) {
        case DROP: marker(0,88,64,43,13); marker(1,107,64,43,13); break;
        case FERRY: marker(0,104+run.charge,132,43,7); break;
        case WIND: marker(0,224,78,run.phase_ticks&64 ? 41 : 42,7); break;
        case UNDERSIDE: marker(0,139,88,46,9); break;
        case TRAP:
            marker(0,268,64+run.charge,run.charge==86 ? 43 : 45,10);
            break;
        case DRAW:
            if (run.charge) marker(0,108+run.charge,151,43,1);
            if (run.charge>=16) marker(1,124,151,43,1);
            if (run.charge==28) marker(2,147,151,43,1);
            break;
        case WEIGHT:
            marker(1,108,69,43,15);
            marker(2,116,69,43,15);
            marker(0,116+(run.charge>24 ? 24 : run.charge),
                     62+(run.charge>24 ? run.charge-24 : 0),40,1); break;
        case CURSOR:
            if (!run.gate) marker(0,2u*run.charge,run.launch_dir,47,1);
            break;
        case WAKE: if (!run.armed) marker(0,36,125,44,1); break;
        case WATCH: marker(0,254,112,40,run.armed && (run.phase_ticks&32) ? 2 : 5); break;
        case RIDE: if (run.armed) marker(0,224,lift_y(),43,7); break;
    }
}

static void cover_robot(void)
{
    VIC[0x17] = VIC[0x1d] = 31;
    robot(24+238,50+50,15);
}

static void spawn(void)
{
    run.player_x = 28;
    run.feet = 152;
    run.height8 = 152*8;
    run.velocity = run.facing_left = run.stride = run.on_plate = 0;
    run.jump_buffer = 0;
    run.coyote = 4;
    run.grounded = 1;
}

static void draw_pass(byte lights)
{
    byte zone = run.pass/10;
    /* A pass can paint signs, a picture or a sliding door into the scenery. */
    screen(rooms[zone]);
    zone_on_screen = zone;
    bounds=ledges[zone];
    dimmed=0;
    if (run.pass==FAINT) memcpy(night_inks,SCREEN+3*40,sizeof(night_inks));
    if (run.pass==GAP) { label(16,6,"H ME",4,7); }
    if (run.pass==PICTURE && run.armed) picture();
    painted_lift=255;
    message_ticks = 0;
    retry_flash = 0;
    painted_retry = 255;
    painted_hint_seconds = METER_REDRAW;
    run.lamp_count = painted_plate = painted_gate = 255;
    fixtures();
    lamps(lights);
    hud();
    retry_button();
    player();
    items();
    VIC[0x11] = 0x3b;
}

static void start_pass(byte hint_ticks)
{
    byte selected = run.pass;
    mode = PLAY;
    memset(&run,0,sizeof(run));
    run.pass = selected;
    run.hint_ticks = hint_ticks;
    run.gate = selected == HANDS_OFF;
    spawn();
    if (selected==CURSOR) { run.charge=14; run.launch_dir=135; }
    if (selected==PICTURE) run.parts=7;
    draw_pass(0);
}

static void open_gate(void)
{
    if (!run.gate) sound_effect(S_OPEN);
    run.gate = 1;
}

static void arm(void)
{
    if (!run.armed) {
        run.armed = 1;
        lamps(2);
        sound_effect(S_PAD);
        if (hint_visible()) note();
    }
}

static void title(void)
{
    mode = TITLE;
    zone_on_screen = 255;
    screen(title_art);
    cover_robot();
    VIC[0x11] = 0x3b;
}

static void ending(void)
{
    mode = ENDING;
    zone_on_screen = 255;
    screen(title_art);
    memset(BITMAP+15*320,0,10*320);
    memset(SCREEN+15*40,0,10*40);
    label(3,16,"YOU MADE IT HOME.",27,3);
    label(3,19,"FORTY DOORS. TIME FOR BED.",34,15);
    label(3,23,"PRESS FIRE TO PLAY AGAIN",30,1);
    cover_robot();
    VIC[0x11] = 0x3b;
}

static void land(byte surface)
{
    run.feet = surface;
    run.height8 = (int)surface<<3;
    run.velocity = 0;
    run.grounded = 1;
}

static byte at_door(void)
{
    return run.player_x>=274 && run.feet==152 && run.grounded;
}

static void step_side(byte direction, byte speed)
{
    if (direction!=LEFT && direction!=RIGHT) return;
    run.facing_left=(direction==LEFT);
    if (run.facing_left) run.player_x=run.player_x<16+speed ? 16 : run.player_x-speed;
    else run.player_x=run.player_x>302-speed ? 302 : run.player_x+speed;
    ++run.stride;
}

/* The echo stores four input samples inside the saved state. */
static byte echoed(byte input)
{
    byte first=run.charge>>4;
    run.charge=(run.charge<<4)|(run.parts>>4);
    run.parts=(run.parts<<4)|input;
    return first;
}

static void move_player(void)
{
    byte old=run.feet, direction=controls&(LEFT|RIGHT), takeoff=pressed&JUMP;
    byte speed=2,gravity=3, boat=104+run.charge, y, sample;
    signed char thrust=-49;
    jumped=0;
    was_grounded=run.grounded;
    if ((!run.gate && (run.pass==CURSOR || (run.pass==PICTURE && run.armed))) ||
        (run.pass==WAKE && !run.armed)) return;
    switch (run.pass) {
        case MIRROR: direction=((direction&LEFT)<<1)|((direction&RIGHT)>>1); break;
        case FAST: speed=6; break;
        case MOON: gravity=2; thrust=-54; break;
        case WIND:
            if (!(run.phase_ticks&3)) step_side(run.phase_ticks&64 ? LEFT : RIGHT,1);
            break;
        case FERRY:
            if (run.grounded && old==132 && !takeoff && direction) {
                if (direction==RIGHT && run.charge<64) { ++run.charge; ++run.player_x; }
                else if (direction==LEFT && run.charge) { --run.charge; --run.player_x; }
                if (run.charge!=64 && run.charge!=0) direction=0;
            }
            break;
        case BUDGET: if (run.progress>=2) takeoff=0; break;
        case ONE:
            if ((controls&JUMP) && direction) { direction=takeoff=0; }
            break;
        case INVERT:
            if (run.armed && !run.gate) {
                step_side(direction,2);
                run.feet=run.feet>34 ? run.feet-2 : 32;
                run.height8=(int)run.feet<<3;
                run.grounded=run.velocity=0;
                return;
            }
            break;
        case DRAW:
            if (!run.armed && run.grounded && old==152 && run.player_x>=104 &&
                run.player_x<=123 && (controls&JOY_DOWN) && direction==RIGHT) {
                if (run.charge<28) ++run.charge;
                direction=0;
            }
            break;
        case SKID:
            if (pressed&(LEFT|RIGHT)) {
                if (run.launch_dir && run.launch_dir!=direction) run.launch_dir=0;
                else run.launch_dir=direction;
            }
            direction=run.launch_dir;
            break;
        case CARRY:
            if (pin_edge&16) run.armed=!run.armed;
            if (run.armed) {
                step_side(direction,2);
                if (joy_pins&1 && run.feet>33) run.feet-=2;
                if (joy_pins&2 && run.feet<151) run.feet+=2;
                run.height8=(int)run.feet<<3;
                run.grounded=run.velocity=0;
                return;
            }
            takeoff=0; direction=0;
            break;
        case AUTO:
            if (run.player_x<=16) run.launch_dir=0;
            if (run.player_x>=302) run.launch_dir=1;
            direction=run.launch_dir ? LEFT : RIGHT;
            break;
        case LATE: sample=echoed(direction|takeoff); direction=sample&3; takeoff=sample&JUMP; break;
        case POGO: if (run.grounded) takeoff=1; break;
        case KNOCK: case LIFT: if (at_door()) takeoff=0; break;
    }
    step_side(direction,speed);
    if (takeoff) run.jump_buffer=5;
    if (run.grounded) run.coyote=4;
    if (run.jump_buffer && run.coyote) {
        run.velocity=thrust;
        run.jump_buffer=run.coyote=0;
        jumped=1;
        if (run.pass==BUDGET) ++run.progress;
        sound_effect(S_JUMP);
    }
    if (run.velocity<48) run.velocity+=gravity;
    run.height8+=run.velocity;
    if (run.height8<32*8) { run.height8=32*8; run.velocity=0; }
    run.feet=(byte)(run.height8>>3);
    run.grounded=0;
    if (run.velocity>=0) {
        y=lift_y();
        if (run.pass==DROP && old<=64 && run.feet>=64 && run.player_x>=87 && run.player_x<=126) land(64);
        else if (run.pass==RIDE && run.armed && old<=y && run.feet>=y &&
                 run.player_x>=224 && run.player_x<=245) land(y);
        else if (old<=88 && run.feet>=88 && run.player_x>=bounds[2] && run.player_x<=bounds[3]) land(88);
        else if (old<=112 && run.feet>=112 && run.player_x>=bounds[4] && run.player_x<=bounds[5]) land(112);
        else if (old<=120 && run.feet>=120 && run.player_x>=bounds[0] && run.player_x<=bounds[1]) land(120);
        else if (run.pass==FERRY && old<=132 && run.feet>=132 &&
                 run.player_x+4>=boat && run.player_x<=boat+20) land(132);
        else if (old<=152 && run.feet>=152 && (run.player_x<=123 || run.player_x>=167 ||
                 (run.pass==DRAW && run.charge==28))) land(152);
    }
    if (run.coyote) --run.coyote;
    if (run.jump_buffer) --run.jump_buffer;
}

static void pointer(void)
{
    if (joy_pins&4 && run.charge>2) --run.charge;
    if (joy_pins&8 && run.charge<155) ++run.charge;
    if (joy_pins&1 && run.launch_dir>20) run.launch_dir-=2;
    if (joy_pins&2 && run.launch_dir<158) run.launch_dir+=2;
    if ((pin_edge&16) && run.charge>=65 && run.charge<=78 &&
        run.launch_dir>=79 && run.launch_dir<=88) open_gate();
}

static void sleepy(void)
{
    byte dark;
    if (run.countdown<100) ++run.countdown;
    if ((pin_edge&12) && (pin_edge&12)!=run.launch_dir) {
        run.launch_dir=pin_edge&12;
        if (++run.progress>=2) { run.countdown=run.progress=0; arm(); }
    }
    dark=run.countdown>=75 && !run.gate;
    if (dark==dimmed) return;
    dimmed=dark;
    if (dark) memset(SCREEN+3*40,0,sizeof(night_inks));
    else memcpy(SCREEN+3*40,night_inks,sizeof(night_inks));
    painted_plate=painted_gate=255;
    run.lamp_count=255;
    lamps(run.gate ? 3 : 0);
    note();
}

static void slide_door(void)
{
    byte step=run.charge/7;
    if (step!=painted_lift && !run.gate) {
        patch(door_art,33,14,6,5);
        if (step) {
            memset(BITMAP+(19u-step)*320+34*8,0,32);
            if (step>1) memset(BITMAP+18u*320+34*8,0,32);
            if (step>2) memset(BITMAP+17u*320+34*8,0,32);
        }
        painted_lift=step;
    }
}

static void play_picture(void)
{
    if (pressed&LEFT && run.charge) --run.charge;
    if (pressed&RIGHT && run.charge<2) ++run.charge;
    if (pin_edge&16) run.parts^=1<<run.charge;
    if ((pressed&(LEFT|RIGHT)) || (pin_edge&16)) {
        picture();
        if (!run.parts) open_gate();
    }
}
static void puzzle(void)
{
    byte was_on=run.on_plate, tapped, x, y;
    run.on_plate=run.grounded && run.feet==88 && run.player_x>=130 && run.player_x<=158;
    if (run.pass==CARRY && run.armed)
        run.on_plate=run.player_x>=130 && run.player_x<=158 && run.feet>=80 && run.feet<=90;
    tapped=run.on_plate && !was_on;
    if (tapped) sound_effect(S_PAD);
    ++run.phase_ticks;
    switch (run.pass) {
        case CONTACT: case MIRROR: case WIND: case MOON: case ONE: case FAST:
        case AUTO: case LATE: case POGO: case WAKE: case CARRY:
            if (run.pass==WAKE && (pin_edge&16)) arm();
            if (tapped) open_gate();
            break;
        case HANDS_OFF: if (tapped) { run.gate=0; sound_effect(S_CLOSE); note(); } break;
        case THREE:
            if (tapped && run.progress<3) { lamps(++run.progress); if (run.progress==3) open_gate(); }
            break;
        case BACK: if (run.player_x==16) open_gate(); break;
        case HOLD:
            if (!run.gate) {
                if (run.on_plate) ++run.progress; else run.progress=0;
                lamps(run.progress/25);
                if (run.progress>=75) open_gate();
            }
            break;
        case DROP:
            if (run.grounded && run.feet==64) arm();
            if (tapped && run.armed && !was_grounded) open_gate();
            if (run.grounded && run.feet>88) run.armed=0;
            break;
        case TIMER:
            if (run.on_plate && (pressed&JOY_DOWN)) {
                if (run.progress<3) ++run.progress;
                lamps(run.progress);
                if (run.progress==3) { open_gate(); run.countdown=112; note(); }
            }
            if (run.countdown && !--run.countdown) {
                run.gate=run.progress=0; lamps(0); sound_effect(S_CLOSE); note();
            }
            break;
        case RETREAT:
            if (at_door()) arm();
            if (run.armed && run.player_x<242) open_gate();
            break;
        case CYCLE:
            if (tapped && !run.progress) { run.progress=CYCLE_ARMED; lamps(1); note(); }
            else if (tapped && run.progress==CYCLE_OPEN) {
                run.progress=CYCLE_LOCKED; run.gate=0; lamps(0); sound_effect(S_CLOSE); note();
            }
            break;
        case KNOCK:
            if (at_door() && (pin_edge&16) && !run.gate) {
                lamps(++run.progress); sound_effect(S_PAD); if (run.progress==2) open_gate();
            }
            break;
        case UNDERSIDE:
            if (run.velocity<0 && run.feet>=100 && run.feet<=107 &&
                run.player_x>=130 && run.player_x<=158) { run.velocity=0; open_gate(); }
            break;
        case FERRY: if (run.charge==64) arm(); if (run.armed && tapped) open_gate(); break;
        case BUDGET: if (tapped) open_gate(); if (run.grounded && !was_grounded) note(); break;
        case INVERT:
            if (was_on && jumped) arm();
            if (run.armed && run.feet==32 && run.player_x>=280) open_gate();
            break;
        case TRAP:
            if (run.player_x>=254 && !run.armed) arm();
            if (run.armed && run.charge<86) {
                if (run.player_x>268) run.player_x=268;
                if (run.progress<22) ++run.progress;
                else {
                    run.charge+=2;
                    if (touching(268,64+run.charge)) run.feet=154;
                    if (run.charge==86) open_gate();
                }
            }
            break;
        case ILLUSION: if (tapped) arm(); if (run.armed && at_door()) open_gate(); break;
        case DRAW:
            if (run.charge==28 && run.grounded && run.feet==152 && run.player_x>=132 && run.player_x<=157)
                run.progress=1;
            if (run.progress && run.player_x>=168 && run.grounded) arm();
            if (run.armed && tapped) open_gate();
            break;
        case WEIGHT:
            if (!run.armed && !run.grounded && touching(116,62)) arm();
            if (run.armed && run.charge<42 && ++run.charge==42) open_gate();
            break;
        case SKID: if (run.on_plate && !run.launch_dir) open_gate(); break;
        case SILENCE: if (run.on_plate && muted) open_gate(); break;
        case PUSH:
            if (!run.gate) {
                if (at_door() && (controls&RIGHT)) {
                    run.player_x=280; ++run.progress; lamps(run.progress/12);
                    if (run.progress>=36) open_gate();
                } else run.progress=0;
            }
            break;
        case CURSOR: if (!run.gate) pointer(); break;
        case GAP:
            if (run.player_x>=134 && run.player_x<=145 && run.feet>=48 && run.feet<=66 && !run.grounded) open_gate();
            break;
        case WATCH:
            if (tapped && !run.armed) { arm(); run.phase_ticks=0; }
            if (run.armed && !run.gate) {
                if ((run.phase_ticks&32) && (controls&(LEFT|RIGHT|JUMP))) {
                    spawn(); run.armed=0; lamps(0); sound_effect(S_CLOSE);
                } else if (at_door()) open_gate();
            }
            break;
        case FREEZE:
            if (run.on_plate) {
                if (!run.gate) open_gate();
                if (pressed&PAUSE) arm();
            } else if (!run.armed) run.gate=0;
            break;
        case LIFT:
            if (!run.gate) {
                if (at_door() && (joy_pins&1)) {
                    if (++run.charge>=28) open_gate();
                } else if (run.charge) --run.charge;
                slide_door();
            }
            break;
        case RIDE:
            if (tapped) arm();
            if (run.armed && !run.gate) {
                y=lift_y();
                x=run.grounded && run.feet==y && run.player_x>=224 && run.player_x<=245;
                if (run.charge<64) ++run.charge;
                else if ((run.charge!=64 || x) && run.charge<128) ++run.charge;
                if (x) { land(lift_y()); if (run.charge>=110) open_gate(); }
                if (run.charge==128 && !run.gate) run.charge=0;
            }
            break;
        case FAINT: sleepy(); if (run.armed && run.on_plate && !dimmed) open_gate(); break;
        case DANCE:
            if (was_on && !run.gate && (pressed&(LEFT|RIGHT|JUMP))) {
                if ((pressed&7)==(1<<run.progress)) ++run.progress;
                else run.progress=(pressed&7)==LEFT;
                lamps(run.progress);
                if (run.progress==3) open_gate();
            }
            if (!run.on_plate && !run.gate) { run.progress=0; lamps(0); }
            break;
        case PICTURE:
            if (tapped && !run.armed) { arm(); picture(); note(); }
            else if (run.armed && !run.gate) play_picture();
            break;
    }
    if (run.gate) lamps(3);
}
static void play(void)
{
    if ((pressed & HINT) && run.hint_ticks==HINT_READY) {
        run.hint_ticks = HINT_DURATION;
        message_ticks = 0;
        note();
    } else if (hint_visible() && !message_ticks && !--run.hint_ticks) {
        label(19,22,"F1:HINT",7,12);
        note();
    }
    if (retry_flash) --retry_flash;
    retry_button();
    move_player();
    player();
    puzzle();
    items();
    fixtures();
    if (run.feet>=153) {
        mode = DYING;
        delay = 22;
        sound_effect(S_FALL);
    } else if (run.gate && run.player_x>=280 && ((run.feet==152 && run.grounded) || (run.pass==CARRY && run.feet>=136) || run.pass==POGO)) {
        mode = LEAVING;
        delay = 25;
        sound_effect(S_CLEAR);
    }
}

static void respawn(void)
{
    byte state=run.progress;
    start_pass(run.hint_ticks);
    if (run.pass==CYCLE && state) {
        run.progress=state==CYCLE_LOCKED ? CYCLE_LOCKED : CYCLE_OPEN;
        if (run.progress==CYCLE_OPEN) { open_gate(); lamps(3); }
        fixtures(); note();
    }
}

static void tick_audio(void)
{
    if (mode==ENDING) sound_tick(VICTORY_MUSIC);
    else if (mode==TITLE) sound_tick(TITLE_MUSIC);
    else sound_tick(ORCHARD_MUSIC+zone_on_screen);
}

void game_tick(void)
{
    byte disk_edge = disk_keys & ~old_disk_keys;
    byte result;
    const char *message;
    old_disk_keys = disk_keys;
    ++game_clock;
    pin_edge=joy_pins & ~old_pins;
    old_pins=joy_pins;
    pressed = controls & ~old_controls;
    old_controls = controls;
    if (pressed & MUTE) sound_toggle();
    if ((disk_edge&2) || ((disk_edge&1) && mode==PLAY)) {
        byte row=mode==TITLE || mode==ENDING ? 15 : 24;
        sound_suspend();
        label(1,row,(disk_edge&2) ? "READING DRIVE 8..." : "SAVING TO DRIVE 8...",38,3);
        if (disk_edge&2) {
            result=load_run(&run);
            if (result==DISK_OK) {
                mode=PLAY;
                draw_pass(run.lamp_count);
                row=24;
            }
            if (result==DISK_NEW_RULE) {
                start_pass(HINT_READY);
                row=24;
            }
            message=result==DISK_NEW_RULE ? "NEW PUZZLE. SAME PASS RESTARTED." :
                    result==DISK_OK ? "SAVED STATE RESTORED." :
                    (result==DISK_EMPTY ? "NO SAVED STATE ON THIS DISK." : "LOAD FAILED. CHECK DRIVE 8.");
        } else {
            result=save_run(&run);
            message=result==DISK_OK ? "STATE SAVED TO DRIVE 8." : "SAVE FAILED. CHECK DISK IN DRIVE 8.";
        }
        message_ticks=85;
        label(1,row,message,38,(result==DISK_OK || result==DISK_NEW_RULE) ? 3 : 10);
        if (mode!=TITLE && mode!=ENDING) hint_meter();
        tick_audio();
        return;
    }
    if (message_ticks && mode==PLAY && !--message_ticks) note();
    if ((mode==PLAY || mode==DYING) && (pressed & RETRY)) {
        start_pass(run.hint_ticks);
        retry_flash = 12;
        retry_button();
        sound_effect(S_PAD);
        tick_audio();
        return;
    }
    switch (mode) {
        case TITLE:
        case ENDING:
            if (pressed & JUMP) {
                run.pass = 0;
                start_pass(HINT_READY);
                VIC[0x11] = 0x3b;
            }
            break;
        case PLAY:
            play();
            if ((game_clock & 15) == 0)
                SCREEN[14+run.pass%10] = (game_clock & 16) ? 0xa0 : 0xf0;
            break;
        case DYING:
            VIC[0x15] = (delay & 4) ? 0 : 31;
            if (!--delay) respawn();
            break;
        case LEAVING:
            VIC[0x15] = 0;
            if (!--delay) {
                if (++run.pass==PASSES) ending(); else start_pass(HINT_READY);
            }
            break;
    }
    if (mode!=TITLE && mode!=ENDING) hint_meter();
    tick_audio();
}

void main(void)
{
    static const byte inks[] = {0,12,3,1,10};
    byte i;
    init_machine();
    sound_init();
    memcpy((void *)0xc000,sprite_art,48*64);
    for (i=0; i<5; ++i) VIC[0x27+i] = inks[i];
    title();
    for (;;) {
        wait_frame();
        controls = read_controls();
        game_tick();
    }
}
