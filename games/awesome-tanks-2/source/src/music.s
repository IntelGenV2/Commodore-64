.export _music_irq_on, _music_irq_off, _music_track, _music_step
.import _music_on, _sfx_busy, _pickup_ticks
.export _clock50

effects_volume = $1c        ; low-pass mode and SID master level 12
music_volume   = $1f        ; full headroom for the three-voice score

.segment "RODATA"
.include "../build/score.inc"
order_lo: .lobytes order0,order1,order2
order_hi: .hibytes order0,order1,order2
sid_offset: .byte 0,7,14
wave: .byte $11,$11,$41
attack_decay: .byte $58,$08,$26
sustain_release: .byte $85,$c4,$f6
battle_ad: .byte $05,$04,$16
battle_sr: .byte $43,$64,$b5
filter_voices: .byte $04,$06,$04
filter_cut: .byte $63,$6e,$63
vibrato: .lobytes 0,9,17,22,24,22,17,9,0,-9,-17,-22,-24,-22,-17,-9

; A short pitched kick, a rim with a single frame of noise, and a lower tom.
; All drum entries end by releasing the gate with their waveform still selected.
; The battle snare starts with a noise transient and drops into a pitched body.
drum_start: .byte 1,6,9,13
drum_pitch: .byte 0,10,6,4,3,0, 13,21,0, 11,9,8,0, 37,15,10,7,0
drum_wave:  .byte 0,$11,$11,$11,$11,$10, $11,$81,$80, $11,$11,$11,$10, $81,$11,$11,$11,$10

.segment "BSS"
_clock50: .res 1
_music_track: .res 1
_music_step:  .res 1
playing:      .res 1
order_pos:    .res 1
phase:        .res 2
row_mask_lo:  .res 3
row_mask_hi:  .res 3
event_lo:     .res 3
event_hi:     .res 3
pending:      .res 3
control:      .res 3
drum_pos:     .res 1
pulse_phase:  .res 1
lead_base:    .res 2
lead_age:     .res 1
vib_phase:    .res 1
arp_third:    .res 1
arp_root:     .res 1
arp_phase:    .res 1

.segment "CODE"
_music_irq_off:
    sei
    lda #$7f
    sta $dc0d
    lda $dc0d
    lda #0
    sta $d40b
    sta $d412
    sta $d404
    lda #$ff
    sta playing
    rts

_music_irq_on:
    sei
    lda #$7f
    sta $dc0d
    lda #0
    sta $dc0e
    sta $d01a
    lda #<music_irq
    sta $fffe
    lda #>music_irq
    sta $ffff
    lda $02a6
    beq ntsc
    lda #<(985248/50)
    sta $dc04
    lda #>(985248/50)
    sta $dc05
    lda #<pal_lo
    sta freq_lo+1
    lda #>pal_lo
    sta freq_lo+2
    lda #<pal_hi
    ldx #>pal_hi
    bne table_done
ntsc:
    lda #<(1022727/50)
    sta $dc04
    lda #>(1022727/50)
    sta $dc05
    lda #<ntsc_lo
    sta freq_lo+1
    lda #>ntsc_lo
    sta freq_lo+2
    lda #<ntsc_hi
    ldx #>ntsc_hi
table_done:
    sta freq_hi+1
    stx freq_hi+2
    lda #$ff
    sta playing
    lda #0
    sta $d415
    sta $d410
    lda #6
    sta $d411
    lda #$80
    sta $d409
    lda #3
    sta $d40a
    lda #effects_volume
    sta $d418
    lda $dc0d
    lda #$81
    sta $dc0d
    lda #$11
    sta $dc0e
    cli
    rts

; IRQ scratch is independent of the C runtime and its zero page.
music_irq:
    pha
    txa
    pha
    tya
    pha
    lda $dc0d
    inc _clock50
    lda _pickup_ticks
    beq :+
    dec _pickup_ticks
    bne :+
    lda #0
    sta $d404
    sta _sfx_busy
:   lda _music_on
    bne active
    lda #effects_volume
    sta $d418
    lda #0
    sta $d40b
    sta $d412
    lda _sfx_busy
    bne :+
    sta $d404
:   lda #255
    sta playing
    jmp done
active:
    ldx _music_track
    cpx playing
    beq run
    stx playing
    lda #music_volume
    sta $d418
    lda filter_voices,x
    sta $d417
    lda filter_cut,x
    sta $d416
    lda order_lo,x
    sta order_read+1
    lda order_hi,x
    sta order_read+2
    lda #0
    sta order_pos
    sta _music_step
    sta pending
    sta pending+1
    sta pending+2
    sta drum_pos
    sta arp_third
    sta lead_age
    sta pulse_phase
    sta $d40b
    sta $d412
    lda _sfx_busy
    bne :+
    sta $d404
:   lda #255
    sta phase
    sta phase+1
run:
    ldx #2
attack_loop:
    lda pending,x
    beq next_attack
    jsr attack
    lda #0
    sta pending,x
next_attack:
    dex
    bpl attack_loop
    jsr colour
    ldx playing
    clc
    lda phase
    adc tempo_lo,x
    sta phase
    lda phase+1
    adc tempo_hi,x
    sta phase+1
    bcc done
    lda _music_step
    and #15
    bne row
    jsr new_bar
row:
    ldx #2
row_lane:
    lsr row_mask_hi,x
    ror row_mask_lo,x
    bcc next_lane
    lda event_lo,x
    sta read_note+1
    lda event_hi,x
    sta read_note+2
    inc event_lo,x
    bne read_note
    inc event_hi,x
read_note:
    lda $ffff
    sta pending,x
    cpx #0
    bne release
    lda #0
    sta arp_third
    lda _sfx_busy
    beq release
    lda #0
    sta pending
    beq next_lane
release:
    ; Preserve the oscillator on a rest. For a new attack give the envelope
    ; one tick to reset before raising its gate, including repeated pitches.
    ldy sid_offset,x
    lda pending,x
    beq :+
    lda #0
    sta $d406,y
:   lda control,x
    and #$fe
    sta $d404,y
next_lane:
    dex
    bpl row_lane
    inc _music_step
done:
    pla
    tay
    pla
    tax
    pla
    rti

new_bar:
    ldx #0
lane:
    ldy order_pos
order_read:
    lda $ffff,y
    tay
    inc order_pos
    lda bar_lo,y
    sta mask_read+1
    clc
    adc #2
    sta event_lo,x
    lda bar_hi,y
    sta mask_read+2
    adc #0
    sta event_hi,x
    ldy #0
    jsr mask_read
    sta row_mask_lo,x
    iny
    jsr mask_read
    sta row_mask_hi,x
    inx
    cpx #3
    bne lane
    ldx playing
    lda order_pos
    cmp order_len,x
    bne :+
    lda #0
    sta order_pos
:   rts
mask_read:
    lda $ffff,y
    rts

attack:
    cpx #0
    bne melodic
    ldy _sfx_busy
    beq :+
    rts
:
    ldy #0
    sty drum_pos
    ; Bit 6 marks a chord, bit 7 selects its major third.
    cmp #$c0
    bcs major
    cmp #$80
    bcs drum_attack
    cmp #$40
    bcc melodic
    ldy #3
    bne chord
major:
    ldy #4
chord:
    sty arp_third
    and #$3f
    tay
    dey
    sty arp_root
    ldy #0
    sty arp_phase
    jmp melodic
drum_attack:
    and #3
    tay
    lda drum_start,y
    sta drum_pos
    lda #$04
    sta $d405
    lda #$34
    sta $d406
    rts
melodic:
    ldy sid_offset,x
    stx restore_x+1
    tax
    dex
    jsr set_pitch
restore_x:
    ldx #0
    lda playing
    cmp #1
    bne standard_tone
    lda battle_ad,x
    sta $d405,y
    lda battle_sr,x
    sta $d406,y
    lda wave,x
    cpx #1
    bne gate_tone
    lda #$41
    bne gate_tone
standard_tone:
    lda attack_decay,x
    sta $d405,y
    lda sustain_release,x
    sta $d406,y
    lda wave,x
gate_tone:
    sta control,x
    sta $d404,y
    rts
set_pitch:
freq_lo:
    lda $ffff,x
    sta $d400,y
    cpy #14
    bne :+
    sta lead_base
:   
freq_hi:
    lda $ffff,x
    sta $d401,y
    cpy #14
    bne pitch_done
    sta lead_base+1
    lda #0
    sta vib_phase
    sta lead_age
pitch_done:
    rts

colour:
    inc pulse_phase
    lda pulse_phase
    and #$3f
    cmp #$20
    bcc :+
    eor #$3f
:   asl
    asl
    asl
    sta $d410
    lda lead_age
    cmp #13
    bcs vibrate
    inc lead_age
    bne percussion
vibrate:
    inc vib_phase
    lda vib_phase
    and #15
    tax
    lda vibrato,x
    ldy #0
    cmp #$80
    bcc :+
    dey
:   clc
    adc lead_base
    sta $d40e
    tya
    adc lead_base+1
    sta $d40f
percussion:
    ldx _sfx_busy
    beq drum
    lda #0
    sta drum_pos
    sta arp_third
    rts
drum:
    lda arp_third
    beq plain_drum
    ldx arp_phase
    beq root
    cpx #1
    beq arp_note
    lda #7
    ldx #255
    bne arp_note
root:
    lda #0
arp_note:
    inx
    stx arp_phase
    clc
    adc arp_root
    tax
    ldy #0
    jmp set_pitch
plain_drum:
    ldx drum_pos
    beq drum_done
    lda drum_pitch,x
    beq drum_release
    sta $d401
    lda #0
    sta $d400
    inc drum_pos
    bne drum_gate
drum_release:
    sta drum_pos
drum_gate:
    lda drum_wave,x
    sta control
    sta $d404
drum_done:
    rts
