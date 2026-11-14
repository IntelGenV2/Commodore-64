#include "sound.h"

#define SID ((volatile unsigned char *)0xd400)
extern unsigned char ntsc;

/* A two-voice title theme, with voice three reserved for game sounds. */
static const unsigned note_pal[] = {
    2176,2588,2905,3259,3876,4352,5176,5810,6519,7752,8705,10352,11620
};
static const unsigned note_ntsc[] = {
    2096,2493,2798,3140,3734,4192,4985,5596,6281,7469,8384,9970,11192
};
static const unsigned char melody[] = {
    5,8,9,0,8,7,6,0, 4,7,8,0,7,6,4,0,
    5,8,10,9,8,0,6,7, 4,7,9,8,6,4,5,0
};
static const unsigned char bass[] = {0,0,1,1,2,2,1,4};
static const unsigned char length[] = {9,8,18,20,10,24};
static const unsigned initial[] = {3100,8300,6100,9200,4000,0};
unsigned char music_scene;
unsigned char muted;
static unsigned char beat, step, bar, suspended, effect, timer;
static unsigned pitch;

enum {
    REST,C2,D2,E2,F2,G2,A2,B2,C3,D3,E3,F3,G3,A3,B3,
    C4,D4,E4,F4,G4,A4,B4,C5,D5,E5,F5,G5,A5,B5,C6,
    FS2,FS4,FS5,BF2,BF3,BF4,CS3,CS5, TIE=255
};
static const unsigned score_pal[] = {
    0,1114,1250,1403,1487,1669,1873,2103,2228,2500,2807,2973,3338,3746,4205,
    4455,5001,5613,5947,6675,7493,8410,8910,10001,11226,11894,13350,14985,16820,17820,
    1575,6300,12600,1985,3969,7938,2360,9440
};
static const unsigned score_ntsc[] = {
    0,1073,1204,1352,1432,1608,1804,2025,2146,2409,2704,2864,3215,3609,4051,
    4292,4817,5407,5729,6430,7218,8102,8584,9635,10815,11458,12861,14436,16204,17167,
    1517,6070,12139,1912,3824,7647,2274,9094
};
#include "world_scores.h"
static const struct WorldScore *world;
static unsigned char lead_wave;
static const unsigned char hatch_notes[][4] = {
    {G4,B4,D5,G5}, {F4,A4,C5,F5}, {D4,FS4,A4,D5}, {C4,E4,G4,C5}
};
static const unsigned *score;
/* Eight bars at 125 BPM. A rest damps the lead, a tie lets it sing. */
static const unsigned char hook[8][16] = {
    {E5,TIE,REST,G4, C5,TIE,G4,REST, E5,TIE,G5,TIE, D5,TIE,C5,TIE},
    {C5,TIE,REST,E5, A5,TIE,G5,TIE, E5,TIE,C5,REST, A4,TIE,B4,TIE},
    {C5,TIE,A4,REST, F5,TIE,E5,TIE, C5,TIE,A4,TIE, G4,REST,A4,C5},
    {D5,TIE,B4,REST, G4,TIE,B4,D5, G5,TIE,TIE,REST, D5,REST,G4,B4},
    {E5,TIE,REST,G4, C5,TIE,G4,REST, E5,G5,C6,TIE, G5,TIE,E5,TIE},
    {F5,TIE,C5,TIE, A4,TIE,C5,REST, F5,TIE,A5,TIE, G5,TIE,F5,E5},
    {D5,TIE,G4,B4, D5,TIE,F5,TIE, G5,TIE,B5,TIE, A5,G5,F5,D5},
    {E5,TIE,G5,TIE, C6,TIE,TIE,TIE, TIE,TIE,TIE,REST, REST,G4,C5,D5}
};
static const unsigned char roots[] = {C2,A2,F2,G2,C2,F2,G2,C2};
static const unsigned char bass_line[] = {0,255,7,255,255,4,255,7,0,255,255,4,7,255,4,255};
/* One bar of call and answer, then a half-bar C-major landing. */
static const unsigned char short_lead[] = {
    E5,TIE,REST,G4, C5,E5,G5,TIE, D5,REST,B4,D5, F5,E5,D5,G5,
    C6 /* lookahead for the downbeat of the closing chord */
};
static const unsigned char lift[] = {C5,E5,G5,C6};
static const unsigned kick[] = {6000,3240,2050,1450,1080,920};
static unsigned char drum;

static void freq(unsigned char voice, unsigned value)
{
    SID[voice] = (unsigned char)value;
    SID[voice+1] = value >> 8;
}

void sound_init(void)
{
    unsigned char i;
    for (i=0; i<25; ++i) SID[i] = 0;
    music_scene = ROOM_AUDIO;
    timer = muted = suspended = 0;
    score = ntsc ? score_ntsc : score_pal;
    SID[3] = 4;
    SID[5] = 0x08;
    SID[6] = 0x65;
    SID[12] = 0x19;
    SID[13] = 0x74;
    SID[17] = 8;
    SID[19] = 0x03;
    SID[20] = 0x74;
    SID[24] = 12;
}

void sound_toggle(void)
{
    muted ^= 1;
    SID[24] = muted || suspended ? 0 : 12;
}

void sound_suspend(void)
{
    suspended = 1;
    SID[24] = 0;
}

void sound_effect(unsigned char which)
{
    effect = which;
    timer = length[which];
    pitch = initial[which];
    SID[18] = 0;
    freq(14, pitch);
    /* The next frame supplies the rising gate after an envelope reset. */
}

static void victory_tick(unsigned char short_form)
{
    unsigned char note, next_note, offset, root;
    if (short_form && bar==1 && step==8) return;
    if (short_form && bar==1) {
        /* The drum voice becomes the third of the closing chord. Release
           all three envelopes together and park the sequencer after the tail. */
        if (step==0 && beat==0) {
            freq(0,score[C6]);
            freq(7,score[C3]);
            freq(14,score[E4]);
            SID[19] = 0x14;
            SID[20] = 0x84;
            SID[4] = 0x41;
            SID[11] = 0x21;
            SID[18] = 0x11;
        }
        if (step==6 && beat==0) {
            SID[4] = 0x40;
            SID[11] = 0x20;
            SID[18] = 0x10;
        }
        if (++beat==6) { beat=0; ++step; }
        return;
    }
    if (beat == 0) {
        note = short_form ? short_lead[step] : hook[bar][step];
        if (note == REST) SID[4] = 0x40;
        else if (note != TIE) {
            freq(0,score[note]);
            SID[2] = step & 2 ? 0xb0 : 0x40;
            SID[4] = 0x41;
        }
        offset = bass_line[step];
        if (offset != 255) {
            root = short_form ? (step<8 ? C2 : G2) : roots[bar];
            freq(7,score[root+offset]);
            SID[11] = 0x21;
        }
        /* Kick, snare and offbeat hats share the third SID voice. */
        drum = 0;
        if ((step & 7)==0 || (bar==5 && step==11)) drum = 1;
        else if ((step & 7)==4 || ((short_form || bar==3 || bar==6) && step==15)) drum = 2;
        else if ((step & 3)==2) drum = 3;
        if (drum) {
            SID[19] = drum==2 ? 0x08 : 0x04;
            SID[20] = drum==1 ? 0x63 : (drum==2 ? 0x44 : 0x12);
            freq(14,drum==1 ? kick[0] : (drum==2 ? 6300 : 14200));
            SID[18] = drum==1 ? 0x11 : 0x81;
        }
    }
    if (drum==1) freq(14,kick[beat]);
    if (beat==(drum==3 ? 1 : 4)) SID[18] = drum==1 ? 0x10 : 0x80;
    if (beat==4) {
        SID[11] = 0x20;
        next_note = short_form ? short_lead[step+1] : hook[(bar+(step==15))&7][(step+1)&15];
        if (next_note!=TIE) SID[4] = 0x40;
    }
    if (++beat==6) {
        beat = 0;
        if (++step==16) {
            step = 0;
            bar = (bar+1)&7;
        }
    }
}

static void clear_tick(void)
{
    if (step<4 && beat==0) {
        freq(0,score[lift[step]]);
        freq(7,score[step<2 ? C3 : G3]);
        SID[4] = 0x41;
        SID[11] = 0x11;
    }
    if (beat==4) { SID[4] = 0x40; SID[11] = 0x10; }
    if (++beat==6) { beat=0; ++step; }
}

static void world_tick(void)
{
    unsigned char lead, bass, next;
    next = step+1;
    if (next==world->steps) next=0;
    if (!beat) {
        lead=world->lead[step];
        if (lead==REST) SID[4]=lead_wave;
        else if (lead!=TIE) {
            lead_wave=world->lead_wave;
            freq(0,score[lead]);
            SID[4]=lead_wave|1;
        }
        bass=world->bass[step];
        if (bass==REST) SID[11]=world->bass_wave;
        else if (bass!=TIE) {
            freq(7,score[bass]);
            SID[11]=world->bass_wave|1;
        }
    }
    if (beat==world->lead_gate && world->lead[next]!=TIE) SID[4]=lead_wave;
    if (beat==world->bass_gate && world->bass[next]!=TIE) SID[11]=world->bass_wave;
    if (++beat==world->ticks) { beat=0; step=next; }
}

void sound_tick(unsigned char scene)
{
    const unsigned *notes;
    unsigned char victory = scene==VICTORY_MUSIC || scene==SHORT_VICTORY;
    if (scene != music_scene) {
        SID[4] = SID[11] = SID[18] = 0;
        music_scene = scene;
        step = beat = bar = timer = 0;
        SID[2] = 0;
        SID[3] = victory ? 6 : 4;
        SID[5] = victory ? 0x17 : 0x08;
        SID[6] = victory ? 0x95 : 0x65;
        SID[12] = victory ? 0x04 : 0x19;
        SID[13] = victory ? 0x83 : 0x74;
        SID[19] = 0x03;
        SID[20] = 0x74;
        SID[10] = 0;
        if (scene>=ORCHARD_MUSIC) {
            world=&worlds[scene-ORCHARD_MUSIC];
            lead_wave=world->lead_wave;
            SID[3]=world->lead_pw;
            SID[5]=world->lead_ad;
            SID[6]=world->lead_sr;
            SID[10]=world->bass_pw;
            SID[12]=world->bass_ad;
            SID[13]=world->bass_sr;
        }
    }
    if (suspended) {
        suspended=0;
        SID[24]=muted ? 0 : 12;
    }
    if (victory) {
        victory_tick(scene==SHORT_VICTORY);
        return;
    }
    if (scene==CLEAR_MUSIC) {
        clear_tick();
        return;
    }
    if (scene>=ORCHARD_MUSIC) world_tick();
    if (scene==TITLE_MUSIC) {
        if (beat == 0) {
            notes = ntsc ? note_ntsc : note_pal;
            if (melody[step]) {
                freq(0, notes[melody[step]]);
                SID[4] = 0x41;
            }
            if ((step & 3) == 0) {
                freq(7, notes[bass[step >> 2]] >> 1);
                SID[11] = 0x11;
            }
        }
        if (beat == 7) SID[4] = 0x40;
        if (beat == 9 && (step & 3) == 2) SID[11] = 0x10;
        if (++beat == 12) {
            beat = 0;
            step = (step+1) & 31;
        }
    }
    if (timer && effect==S_CLEAR) {
        unsigned char age=length[S_CLEAR]-timer;
        if (age%6==1) {
            const unsigned char *chime=scene>=ORCHARD_MUSIC ? hatch_notes[scene-ORCHARD_MUSIC] : lift;
            freq(14,score[chime[age/6]]);
            SID[18]=0x11;
        } else if (age%6==5) SID[18]=0x10;
        --timer;
    } else if (timer) {
        if (timer == length[effect]-1) SID[18] = effect == S_FALL ? 0x81 : 0x11;
        switch (effect) {
            case S_JUMP: pitch += 410; break;
            case S_PAD: pitch -= 440; break;
            case S_OPEN: if (timer == 11) pitch += 3100; break;
            case S_FALL: pitch -= 400; break;
            case S_CLOSE: pitch -= 230; break;
        }
        freq(14, pitch);
        if (--timer == 0) SID[18] = 0;
    }
}