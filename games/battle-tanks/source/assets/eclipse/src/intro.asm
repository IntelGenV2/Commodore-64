// Studio 256 ZIP artwork intros with Nightshift by Agemixer (2001 Scallop). Stock 64 KB C64, PAL and NTSC.
.import source "../build/config.asm"
.var music = LoadSid("../ref/Nightshift.sid")
.const stream=$02
.const motion=$04
.const remaining=$06
.const run_length=$07
.const destination=$08
.const frame=$10
.const ntsc=$14
.const cadence=$15

*=$0801
.byte $0b,$08,$01,$00,$9e
.text "2061"
.byte 0,0,0
*=$080d
start:
    sei
    cld
    // Silence and reset the oscillators before screen setup or song init.
    lda #0
    ldx #24
reset_sid:
    sta $d400,x
    dex
    bpl reset_sid
    lda #8
    sta $d404
    sta $d40b
    sta $d412
    .if (game_mode!=0) {
        tsx
        .if (game_mode==1) { stx boot_stack }
        .if (game_mode==2) { stx resident_stack }
        ldx #0
    save_environment:
        .for(var p=0;p<4;p++) {
            lda p*256,x
            sta $4000+p*256,x
        }
        inx
        bne save_environment
    }
    lda $ba
    sta boot_device
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #$35
    sta $01
    lda #0
    sta $d01a
    sta $d011
    sta $d020
    sta $d021
    sta $d015
    sta $d010
    sta $d017
    sta $d01d
    sta $d01b
    sta $d01c
    sta frame
    sta frame+1
    sta ntsc
    sta cadence
    sta intro_volume
    sta video_pending
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    ora #2
    sta $dd00
    lda #$18
    sta $d018
    sta $d016
    ldx #0
clear:
    .for(var p=0;p<4;p++) {
        lda screen_data+p*256,x
        sta $4400+p*256,x
        lda color_data+p*256,x
        sta $d800+p*256,x
    }
    lda #0
    .for(var p=0;p<32;p++) {
        sta $6000+p*256,x
    }
    inx
    beq !+
    jmp clear
!:
    lda #1
    sta $d027
    sta $d028
    lda #7
    sta $d029
detect_high:
    bit $d011
    bpl detect_high
detect_line:
    lda $d012
    cmp #32
    bcs pal
    bit $d011
    bmi detect_line
    inc ntsc
pal:
    lda #<updates
    sta stream
    lda #>updates
    sta stream+1
    lda #<positions
    sta motion
    lda #>positions
    sta motion+1
    lda #0
    tax
    tay
    // SID registers are write-only. Capture this driver's two volume/filter
    // writes in RAM, then combine the real filter mode with our outro fade.
    lda #<sid_mode
    sta $105d
    sta $12a9
    lda #>sid_mode
    sta $105e
    sta $12aa
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    jsr music.init
    lda #<music_irq
    sta $fffe
    lda #>music_irq
    sta $ffff
    lda #<intro_nmi
    sta $fffa
    lda #>intro_nmi
    sta $fffb
    lda #0
    sta $dc0e
    lda ntsc
    bne music_ntsc
    lda #<19655
    ldx #>19655
    bne music_timer
music_ntsc:
    lda #<20454
    ldx #>20454
music_timer:
    sta $dc04
    stx $dc05
    lda $dc0d
    lda #$81
    sta $dc0d
    lda #$11
    sta $dc0e
    lda #$3b
    sta $d011
    lda #250
    sta $d012
    lda #1
    sta $d019
    sta $d01a
    cli
ready:
wait_frame:
    // Latch the raster event: a music IRQ must not make us miss line 250.
    lda video_pending
    beq wait_frame
    dec video_pending
    lda ntsc
    beq tick
    inc cadence
    lda cadence
    cmp #6
    bne tick
    lda #0
    sta cadence
    jmp ready
tick:
    lda frame+1
    cmp #>total_frames
    bne animate
    lda frame
    cmp #<total_frames
    bne animate
intro_done:
    sei
    .if (game_mode!=0) {
        lda #0
        sta $d01a
    }
    lda #1
    sta $dc0d
    lda #0
    sta $dc0e
    sta $d418
    .if (game_mode==1) { jmp game_exit }
    .if (game_mode==2) { jmp resident_exit }
    cli
    lda #0
    sta $d015
    // Standalone previews hold the finished artwork; Space/fire replays.
    lda #$7f
    sta $dc00
    lda $dc01
    and #$10
    beq replay
    lda #$ff
    sta $dc00
    lda $dc00
    and #$10
    beq replay
    jmp ready
replay:
    jmp start
animate:
    ldy #0
    lda (stream),y
    sta remaining
    inc stream
    bne !+
    inc stream+1
!:
    lda remaining
    beq colors_done
tile_update:
    ldy #0
    lda (stream),y
    sta destination
    iny
    lda (stream),y
    sta destination+1
    iny
    lda (stream),y
    sta run_length
    clc
    lda stream
    adc #3
    sta stream
    bcc !+
    inc stream+1
!:
    ldy #0
copy_run:
    lda (stream),y
    sta (destination),y
    iny
    cpy run_length
    bne copy_run
    clc
    lda stream
    adc run_length
    sta stream
    bcc !+
    inc stream+1
!:
    dec remaining
    bne tile_update
colors_done:
    ldy #0
    lda (motion),y
    sta $d000
    iny
    lda (motion),y
    sta $d001
    iny
    lda (motion),y
    sta $47f8
    iny
    lda (motion),y
    sta $d002
    iny
    lda (motion),y
    sta $d003
    iny
    lda (motion),y
    sta $47f9
    iny
    lda (motion),y
    sta $d004
    iny
    lda (motion),y
    sta $d005
    iny
    lda (motion),y
    sta $47fa
    iny
    lda (motion),y
    sta $d010
    iny
    lda (motion),y
    sta $d015
    iny
    lda (motion),y
    sta $d016
    iny
    lda (motion),y
    sta intro_volume
    clc
    lda motion
    adc #13
    sta motion
    bcc !+
    inc motion+1
!:
    inc frame
    bne !+
    inc frame+1
!:
    jmp ready

boot_device: .byte 8
sid_mode: .byte 15
intro_volume: .byte 0
video_pending: .byte 0
intro_nmi: rti
music_irq:
    pha
    txa
    pha
    tya
    pha
    lda $d019
    and #1
    beq music_irq_cia
    sta $d019
    inc video_pending
music_irq_cia:
    lda $dc0d
    and #1
    beq music_irq_done
music_step:
    jsr music.play
    lda sid_mode
    and #15
    cmp intro_volume
    bcc !+
    lda intro_volume
!:
    sta music_level+1
    lda sid_mode
    and #$f0
music_level:
    ora #0
    sta $d418
music_irq_done:
    pla
    tay
    pla
    tax
    pla
    rti
.if (game_mode==1) {
    .import source "chainloader.asm"
}
.if (game_mode==2) {
    .import source "resident_handoff.asm"
}
.assert "Engine fits below SID",*<$1000,true
*=music.location "Nightshift by Agemixer (2001 Scallop)"
.fill music.size,music.getData(i)
.assert "SID fits",*<$2000,true
*=$2000 "Motion control"
positions: .import binary "../build/current-motion.bin"
.assert "Motion fits",*<$3800,true
*=$3800 "Original color attributes"
screen_data: .import binary "../build/art.screen"
.fill 24,0
color_data: .import binary "../build/art.color"
.fill 24,0
*=$5800 "Animated glints"
.import binary "../build/stars.bin"
*=$6000 "Bitmap drawing surface"
.fill 8000,0
*=$8000 "Animation updates"
updates: .import binary "../build/current-stream.bin"
.assert "All data remains below I/O",*<$d000,true
