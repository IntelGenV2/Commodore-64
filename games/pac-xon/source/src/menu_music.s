; Shared by the single-load game and the stand-alone PSID. One cursor and one
; gate per oscillator. A level change or a drum bend never retriggers a note.
.export menu_start, menu_tick, set_audio_clock, plo, phi, nlo, nhi
.import _ntsc
.rodata
.include "../assets/pitches.inc"
lead:   .incbin "assets/menu-1.bin"
comp:   .incbin "assets/menu-2.bin"
beat:   .incbin "assets/menu-3.bin"
start_lo: .byte <lead,<comp,<beat
start_hi: .byte >lead,>comp,>beat
sid_offset: .byte 0,7,14
;         level lead pluck bass kick bend noise
waveform: .byte 0, $40, $20, $40, $10, 0, $80
ad:       .byte 0, $12, $32, $12, $02, 0, $11
release:  .byte 0,   3,   3,   2,   2, 0,   1
.bss
position_lo: .res 3
position_hi: .res 3
remaining:   .res 3
last_wave:   .res 3
tail:        .res 3
lane:        .res 1
note:        .res 1
command:     .res 1
.code
; CIA A underflows every latch+1 PHI2 cycles. Use the nearest hardware
; period to 20 ms for both the game IRQ and the exported PSID.
set_audio_clock:
    lda #<19704
    ldx #>19704
    ldy _ntsc
    beq :+
    lda #<20454
    ldx #>20454
:   sta $dc04
    stx $dc05
    rts
menu_start:
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d402
    sta $d410
    lda #8
    sta $d403             ; 50% duty, matching the odd harmonics of the lead
    sta $d411             ; strong fundamental on the offbeat bass notes
    lda #3
    sta $d415
    lda #$90
    sta $d416
    lda #$22              ; low-pass only the accompaniment initially
    sta $d417
    lda #$1f
    sta $d418
    ldx #2
@reset:
    lda start_lo,x
    sta position_lo,x
    lda start_hi,x
    sta position_hi,x
    lda #1
    sta remaining,x
    lda #0
    sta last_wave,x
    sta tail,x
    dex
    bpl @reset
menu_tick:
    ldx #0
@voice:
    dec remaining,x
    bne @next
    stx lane
    jsr event
    ldx lane
@next:
    inx
    cpx #3
    bne @voice
    rts

event:
    lda position_lo,x
    sta fetch+1
    lda position_hi,x
    sta fetch+2
    ldy #0
    jsr fetch
    bne event_row
menu_wrap:
    lda start_lo,x
    sta position_lo,x
    lda start_hi,x
    sta position_hi,x
    jmp event
event_row:
    sta remaining,x
    iny
    jsr fetch
    sta note
    iny
    jsr fetch
    sta command
    clc
    lda position_lo,x
    adc #3
    sta position_lo,x
    bcc :+
    inc position_hi,x
:   ldy sid_offset,x
    lda command
    beq lift
    cmp #16
    bcc level
    ; Pitch is written only for a sounding note or an intentional kick bend.
    ldx note
    lda _ntsc
    beq @pal
    lda nlo,x
    sta $d400,y
    lda nhi,x
    jmp @high
@pal:
    lda plo,x
    sta $d400,y
    lda phi,x
@high:
    sta $d401,y
    ldx lane
    lda command
    lsr
    lsr
    lsr
    lsr
    cmp #5
    beq level
    pha
    lda last_wave,x
    sta $d404,y
    pla
    tax
    lda ad,x
    sta $d405,y
    lda release,x
    pha
    lda waveform,x
    ldx lane
    sta last_wave,x
    pla
    sta tail,x
    jsr level
    lda last_wave,x
    ora #1
    sta $d404,y
    cpx #2
    bne done
    lda command
    and #$f0
    cmp #$30              ; round the pulse bass, bypass the filter for drums
    beq @bass_filter
    lda #$22
    bne :+
@bass_filter:
    lda #$26
:   sta $d417
done:
    rts
lift:
    lda last_wave,x
    sta $d404,y           ; leave oscillator pitch, sustain and release intact
    rts
level:
    lda command
    asl
    asl
    asl
    asl
    ora tail,x
    sta $d406,y
    rts
fetch:
    lda $ffff,y
    rts
