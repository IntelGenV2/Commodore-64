.setcpu "6502"
.segment "CODE"
.export music_init, music_play, music_stop, loop_count, loop_boundary, tick_lo, tick_hi, song_end
music_init: jmp init
music_play: jmp play
music_stop: jmp stop

init:
    ldx #24
    lda #0
@clear: sta $d400,x
    dex
    bpl @clear
    sta tick_lo
    sta tick_hi
    sta loop_count
    ldx #2
@voices:
    lda starts_lo,x
    sta ptr_lo,x
    lda starts_hi,x
    sta ptr_hi,x
    lda #1
    sta wait,x
    lda #0
    sta phase,x
    dex
    bpl @voices
    lda $02a6
    beq @ntsc
    lda #<pal_lo
    sta freq_read_lo+1
    lda #>pal_lo
    sta freq_read_lo+2
    lda #<pal_hi
    sta freq_read_hi+1
    lda #>pal_hi
    sta freq_read_hi+2
    lda #<9852
    sta $dc04
    lda #>9852
    sta $dc05
    bne @ready
@ntsc:
    lda #<ntsc_lo
    sta freq_read_lo+1
    lda #>ntsc_lo
    sta freq_read_lo+2
    lda #<ntsc_hi
    sta freq_read_hi+1
    lda #>ntsc_hi
    sta freq_read_hi+2
    lda #<10227
    sta $dc04
    lda #>10227
    sta $dc05
@ready:
    lda #2
    sta $d415
    lda #$32
    sta $d417
    lda #$1f
    sta $d418
    rts

stop:
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d418
    rts

play:
    lda $fb
    pha
    lda $fc
    pha
    inc tick_lo
    bne :+
    inc tick_hi
:
    lda tick_lo
    lsr
    lsr
    lsr
    tay
    lda filter_curve,y
    clc
    adc #FILTER_BASE
    sta $d416
    ldx #0
voice:
    dec wait,x
    bne render
event:
    lda ptr_lo,x
    sta $fb
    lda ptr_hi,x
    sta $fc
    ldy #0
    lda ($fb),y
    bne read_event
    cpx #0
    bne :+
loop_boundary:
    inc loop_count
:
    lda starts_lo,x
    sta ptr_lo,x
    lda starts_hi,x
    sta ptr_hi,x
    jmp event
read_event:
    sta wait,x
    iny
    lda ($fb),y
    sta note,x
    iny
    lda ($fb),y
    sta instrument,x
    iny
    lda ($fb),y
    sta gate_length,x
    lda #0
    sta phase,x
    lda ptr_lo,x
    clc
    adc #4
    sta ptr_lo,x
    bcc render
    inc ptr_hi,x
render:
    stx track
    ldy instrument,x
    lda waves,y
    sta control
    lda ads,y
    sta ad
    lda srs,y
    sta sr
    lda pulses,y
    sta pw_hi
    lda kinds,y
    sta kind
    lda note,x
    sta pitch
    bne :+
    jmp silent
:
    lda phase,x
    beq release
    cmp gate_length,x
    bcc gate_done
release:
    lda control
    and #$fe
    sta control
gate_done:
    lda kind
    cmp #1
    bne not_kick
    lda phase,x
    cmp #15
    bcc :+
    lda #15
:
    tay
    lda kick_notes,y
    sta pitch
    jmp pitch_ready
not_kick:
    cmp #2
    bne not_snare
    lda phase,x
    cmp #1
    bne :+
    lda #$11
    sta control
    lda #55
    sta pitch
    bne pitch_ready
:
    lda #102
    sta pitch
    bne pitch_ready
not_snare:
    cmp #4
    bne not_arp
    lda phase,x
    lsr
    and #7
    tay
    lda instrument,x
    cmp #12
    beq major_arp
    cmp #13
    beq sus_arp
    lda minor_steps,y
    bne arp_add
    beq arp_add
major_arp:
    lda major_steps,y
    jmp arp_add
sus_arp:
    lda sus_steps,y
arp_add:
    clc
    adc pitch
    sta pitch
    jmp pitch_ready
not_arp:
    cmp #5
    bne pitch_ready
    lda phase,x
    lsr
    cmp #9
    bcc :+
    lda #9
:
    sta temp
    lda pitch
    sec
    sbc temp
    sta pitch
pitch_ready:
    ldy pitch
freq_read_lo: lda pal_lo,y
    sta fl
freq_read_hi: lda pal_hi,y
    sta fh
    ldx track
    lda instrument,x
    cmp #4
    bcs output
    lda phase,x
    cmp #10
    bcc output
    and #31
    tay
    lda vibrato,y
    clc
    adc fl
    sta fl
    lda vibrato,y
    bmi negative_vib
    lda fh
    adc #0
    sta fh
    jmp output
negative_vib:
    lda fh
    adc #$ff
    sta fh
    jmp output
silent:
    lda #0
    sta control
    sta fl
    sta fh
output:
    lda phase,x
    and #31
    tay
    lda pwm_curve,y
    sta pw_lo
    ldy offsets,x
    lda fl
    sta $d400,y
    lda fh
    sta $d401,y
    lda pw_lo
    sta $d402,y
    lda pw_hi
    sta $d403,y
    lda ad
    sta $d405,y
    lda sr
    sta $d406,y
    lda control
    sta $d404,y
    inc phase,x
    inx
    cpx #3
    beq done
    jmp voice
done:
    pla
    sta $fc
    pla
    sta $fb
    rts

offsets: .byte 0,7,14
; rest, PWM lead, muted lead, bright lead, saw bass, pulse bass,
; mellow bass, kick, snare, closed hat, open hat, minor/major/sus arps, tom
waves: .byte $00,$41,$11,$41,$21,$41,$11,$11,$81,$81,$81,$41,$41,$41,$11
ads:   .byte $00,$03,$24,$02,$03,$02,$14,$00,$00,$00,$01,$02,$02,$03,$00
srs:   .byte $00,$a5,$85,$b4,$83,$73,$85,$a2,$72,$30,$53,$63,$63,$64,$82
pulses:.byte $00,$05,$08,$03,$08,$04,$08,$08,$08,$08,$08,$02,$02,$03,$08
kinds: .byte 0,0,0,0,0,0,0,1,2,3,3,4,4,4,5
kick_notes:.byte 69,64,53,43,36,33,31,30,29,28,28,28,28,28,28,28
minor_steps:.byte 0,7,12,7,3,7,12,7
major_steps:.byte 0,7,12,7,4,7,12,7
sus_steps:.byte 0,7,12,7,2,7,12,7
filter_curve:.byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0
pwm_curve:.byte 0,16,32,48,64,80,96,112,128,144,160,176,192,208,224,240,240,224,208,192,176,160,144,128,112,96,80,64,48,32,16,0
vibrato:.byte 0,6,12,18,23,27,30,32,33,32,30,27,23,18,12,6,0,250,244,238,233,229,226,224,223,224,226,229,233,238,244,250
starts_lo:.byte <voice0,<voice1,<voice2
starts_hi:.byte >voice0,>voice1,>voice2
ptr_lo:.res 3,0
ptr_hi:.res 3,0
wait:.res 3,1
note:.res 3,0
instrument:.res 3,0
gate_length:.res 3,0
phase:.res 3,0
track:.byte 0
control:.byte 0
ad:.byte 0
sr:.byte 0
pw_lo:.byte 0
pw_hi:.byte 0
kind:.byte 0
pitch:.byte 0
fl:.byte 0
fh:.byte 0
temp:.byte 0
tick_lo:.byte 0
tick_hi:.byte 0
loop_count:.byte 0
.include "notes.inc"
voice0:.incbin "voice0.bin"
voice1:.incbin "voice1.bin"
voice2:.incbin "voice2.bin"
song_end:
