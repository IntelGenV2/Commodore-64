/* Two melodic parts leave SID voice three free for jumps and room sounds. */
struct WorldScore {
    const unsigned char *lead, *bass;
    unsigned char steps, ticks, lead_gate, bass_gate;
    unsigned char lead_wave, lead_pw, lead_ad, lead_sr;
    unsigned char bass_wave, bass_pw, bass_ad, bass_sr;
};

static const unsigned char orchard_lead[] = {
    G4,B4,D5,TIE,B4,A4,G4,REST,
    A4,C5,E5,TIE,D5,C5,A4,REST,
    B4,D5,G5,TIE,E5,D5,B4,REST,
    A4,TIE,G4,E4,D4,TIE,REST,REST,
    G4,B4,D5,G5,F5,E5,D5,REST,
    C5,E5,G5,E5,D5,C5,A4,REST,
    B4,A4,G4,E4,D4,E4,G4,A4,
    G4,TIE,D5,TIE,G4,TIE,TIE,REST
};
static const unsigned char orchard_bass[] = {
    G2,TIE,D3,REST,B2,REST,D3,REST,
    A2,TIE,E3,REST,C3,REST,E3,REST,
    G2,TIE,D3,REST,G3,REST,D3,REST,
    D3,TIE,A2,REST,D3,TIE,F3,REST,
    G2,TIE,D3,REST,B2,REST,G3,REST,
    C3,TIE,G2,REST,E3,REST,G3,REST,
    E3,REST,B2,REST,D3,REST,F3,REST,
    G2,TIE,D3,REST,G3,TIE,D3,REST
};
static const unsigned char shore_lead[] = {
    A4,TIE,C5,D5,TIE,C5,
    G4,TIE,TIE,E4,TIE,REST,
    F4,A4,C5,E5,TIE,C5,
    D5,TIE,A4,G4,TIE,REST,
    A4,TIE,C5,F5,TIE,E5,
    D5,TIE,C5,A4,TIE,G4,
    F4,A4,C5,G4,TIE,E4,
    F4,TIE,TIE,TIE,TIE,REST
};
static const unsigned char shore_bass[] = {
    F2,TIE,C3,A2,TIE,C3,
    C3,TIE,G2,E3,TIE,REST,
    F2,TIE,A2,C3,TIE,E3,
    D2,TIE,A2,G2,TIE,REST,
    F2,TIE,C3,A2,TIE,C3,
    D2,TIE,A2,F3,TIE,C3,
    G2,TIE,D3,C3,TIE,G2,
    F2,TIE,A2,C3,TIE,REST
};
static const unsigned char snow_lead[] = {
    D5,REST,A5,FS5,REST,D5,REST,A4,
    B4,REST,FS5,D5,REST,B4,A4,REST,
    G4,REST,D5,B4,REST,G5,D5,REST,
    A4,REST,E5,CS5,REST,E5,A5,REST,
    D5,FS5,A5,REST,B5,REST,A5,FS5,
    G5,REST,B4,D5,REST,G5,B5,REST,
    A5,REST,E5,CS5,D5,REST,B4,A4,
    FS5,REST,E5,REST,D5,TIE,TIE,REST
};
static const unsigned char snow_bass[] = {
    D3,TIE,A2,REST,FS2,TIE,A2,REST,
    B2,TIE,FS2,REST,D3,TIE,A2,REST,
    G2,TIE,D3,REST,B2,TIE,D3,REST,
    A2,TIE,E3,REST,CS3,TIE,E3,REST,
    D3,TIE,A2,REST,FS2,TIE,D3,REST,
    G2,TIE,D3,REST,B2,TIE,G3,REST,
    A2,TIE,E3,REST,CS3,TIE,A2,REST,
    D3,TIE,A2,REST,D2,TIE,TIE,REST
};
static const unsigned char bedtime_lead[] = {
    G4,TIE,E4,C4,TIE,REST,
    A4,TIE,F4,D4,TIE,REST,
    B4,TIE,G4,E4,TIE,D4,
    C5,TIE,TIE,G4,TIE,REST,
    E5,TIE,C5,A4,TIE,G4,
    D5,TIE,B4,G4,TIE,REST,
    F4,TIE,A4,G4,TIE,E4,
    C4,TIE,TIE,TIE,TIE,REST
};
static const unsigned char bedtime_bass[] = {
    C3,TIE,G3,E3,TIE,G3,
    F2,TIE,C3,A2,TIE,C3,
    G2,TIE,D3,B2,TIE,D3,
    C3,TIE,E3,G3,TIE,REST,
    A2,TIE,E3,C3,TIE,E3,
    G2,TIE,D3,B2,TIE,D3,
    F2,TIE,C3,G2,TIE,B2,
    C3,TIE,G2,E3,TIE,REST
};

static const struct WorldScore worlds[] = {
    {orchard_lead,orchard_bass,sizeof(orchard_lead),9,4,4,0x40,6,0x18,0x55,0x10,8,0x14,0x65},
    {shore_lead,shore_bass,sizeof(shore_lead),19,15,16,0x10,8,0x38,0x89,0x40,7,0x39,0x47},
    {snow_lead,snow_bass,sizeof(snow_lead),10,2,4,0x40,2,0x06,0x29,0x10,8,0x26,0x66},
    {bedtime_lead,bedtime_bass,sizeof(bedtime_lead),20,15,16,0x10,8,0x46,0x89,0x40,8,0x48,0x38}
};