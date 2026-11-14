.macpack longbranch
.export _machine,_scan,_flood,_ntsc,_ticks,_cue,_request,_contacts,_joy
.export _active_bank,_ready_bank,_banks,_multiplex,_charset,_sprites,_title_art
.import _board,_trail,_terrain_color,_cursor_visible,_menu_y,_ghost_ink
.export _copy_menu_matrix,_menu_border,_publish_colors,_guide_sprites,_title_cursor
.import menu_start,menu_tick,set_audio_clock,plo,phi,nlo,nhi
.importzp ptr1,ptr2,ptr3
.rodata
_title_art: .incbin "assets/title.bin"
_charset: .incbin "assets/charset.bin",0,1264
.export _sky,_death_art
_death_art: .incbin "assets/death.bin"
_sky: .incbin "assets/sky.bin"
_sprites: .incbin "assets/sprites.bin"
score: .incbin "assets/score.bin"
.include "../assets/score.inc"
bits: .byte 1,2,4,8,16,32,64,128
.bss
_active_bank: .res 1
_ready_bank: .res 1
_banks: .res 3*69       ; upper list, lower list, split flag
_multiplex: .res 1
_ntsc: .res 1
_ticks: .res 1
_cue: .res 1
_request: .res 1
_contacts: .res 8
_joy: .res 1
idle: .res 1
duration: .res 1
half: .res 1
fx_wave: .res 1
fx_glide: .res 1
fx_pitch: .res 1
queue = _trail
.code
; The VIC can see RAM behind the I/O registers in bank three. Mask IRQs
; for four bytes at a time so the CIA music clock keeps its normal cadence.
_copy_menu_matrix:
    sta ptr2+1
    lda #$c0
    sta ptr1+1
    lda #0
    sta ptr1
    sta ptr2
    tay
    ldx #4
@group:
    sei
    dec $01
    .repeat 4
        lda (ptr1),y
        sta (ptr2),y
        iny
    .endrepeat
    inc $01
    cli
    tya
    bne @group
    inc ptr1+1
    inc ptr2+1
    dex
    bne @group
    rts

_menu_border:
    lda #251
:   cmp $d012
    bne :-
    rts

; Colour RAM has one physical page set. Write from the top down after the
; last visible row. Each group reaches its bad line ahead of the next frame.
_publish_colors:
    ldx #0
    .repeat 4,page
:       .repeat 4,col
            lda _terrain_color+256*page+col,x
            sta $d800+256*page+col,x
        .endrepeat
        txa
        clc
        adc #4
        tax
        .if page=3
            cpx #232
        .endif
        bne :-
    .endrepeat
    rts

_guide_sprites:
    lda #0
    sta $d010
    lda #1
    sta $d026
    .repeat 6,i
        lda #48
        sta $d000+2*i
        lda #99+16*i
        sta $d001+2*i
        lda _ghost_ink+i
        sta $d027+i
    .endrepeat
    lda #63
    sta $d015
    rts

_title_cursor:
    lda _menu_y
    sta $d001
    lda _ticks
    lsr
    lsr
    lsr
    and #1
    ora #$10
    php
    sei
    dec $01
    sta $dbf8
    inc $01
    plp
    rts

_machine:
    sei
    lda #0
    sta _ntsc
@low:
    bit $d011
    bmi @low
@high:
    bit $d011
    bpl @high
@line:
    lda $d012
    cmp #32
    bcs @standard
    bit $d011
    bmi @line
    inc _ntsc
@standard:
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #$35
    sta $01
    lda #<restore
    sta $fffa
    lda #>restore
    sta $fffb
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    lda #0
    sta $d011
    sta $d015
    sta $d017
    sta $d01b
    sta $d01d
    sta $d020
    sta $d021
    sta $d012
    sta $dc0e
    sta half
    sta duration
    ldx #24
:   sta $d400,x
    dex
    bpl :-
    lda #$0f
    sta $d418
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    sta $dd00
    lda #1
    sta $d019
    sta $d01a
    jsr set_audio_clock
    lda #$81
    sta $dc0d
    lda #$11
    sta $dc0e
    cli
    rts
; Separate NMI return for RESTORE (CIA2 sources are disabled).
restore: rti

_scan:
    lda #0
    sta $dc02
    sta $dc03
    lda $dc00
    eor #$ff
    and #31
    sta _joy
    ; The stick grounds PA. Read keys on PB so a direction or fire contact
    ; changing during this scan cannot masquerade as a keyboard switch.
    lda #0
    sta $dc00
    lda $dc01
    sta idle
    ldx #7
:   lda bits,x
    sta $dc02
    lda $dc01
    eor #$ff
    and idle
    sta _contacts,x
    dex
    bpl :-
    lda #0
    sta $dc02
scan_done:
    rts

irq:
    pha
    txa
    pha
    tya
    pha
    lda $d019
    and #1
    jeq timer
    sta $d019
    lda half
    bne lower
    inc half
    lda #145
    sta $d012
menu_vblank:
    lda _cursor_visible
    beq :+
    jsr _title_cursor
:
    ldx _ready_bank
    stx _active_bank
    jmp raster
lower:
    lda #0
    sta half
    sta $d012
    ldx _active_bank
    lda _banks+68,x
    jeq timer
    txa
    clc
    adc #34
    tax
raster:
    lda _multiplex
    jeq timer
    .repeat 8,v
        lda _banks+2*v,x
        sta $d000+2*v
        lda _banks+2*v+1,x
        sta $d001+2*v
        lda _banks+16+v,x
        sta $c3f8+v
        lda _banks+24+v,x
        sta $d027+v
    .endrepeat
    lda _banks+32,x
    sta $d010
    lda _banks+33,x
    sta $d015
timer:
    lda $dc0d
    and #1
    beq irq_done
    inc _ticks
    jsr audio
irq_done:
    pla
    tay
    pla
    tax
    pla
    rti

silence:
    lda #0
    sta $d404
    sta $d40b
    sta $d412
    sta $d417
    sta _cue
    lda #$0f
    sta $d418
    rts

audio:
    ldx _request
    beq advance
    lda #0
    sta _request
    cpx #$ff
    beq silence
    cpx #12
    bne new_effect
    jsr silence
    stx _cue
    jmp menu_start
new_effect:
    lda _cue
    cmp #12
    bne :+
    jsr silence
:   stx _cue
    lda cue_lo,x
    sta source+1
    lda cue_hi,x
    sta source+2
    lda fx_wave
    sta $d404               ; one tick between interrupted effects
    lda #1
    sta duration
    rts
advance:
    lda _cue
    beq audio_done
    cmp #12
    bne :+
    jmp menu_tick
:   dec duration
    beq next_note
    lda duration
    cmp #1
    beq release_note
    lda fx_glide
    beq audio_done
    clc
    adc fx_pitch
    sta fx_pitch
    tax
    jmp fx_frequency
release_note:
    lda fx_wave
    sta $d404               ; leave pitch intact for the envelope tail
audio_done:
    rts
next_note:
    ldy #0
    jsr readbyte
    cmp #0
    bne :+
    sta _cue
    rts
:   sta duration
    jsr readbyte
    sta fx_pitch
    jsr readbyte
    tax
    jsr readbyte
    sta fx_glide
    clc
    lda source+1
    adc #4
    sta source+1
    bcc :+
    inc source+2
:   lda fx_ad,x
    sta $d405
    lda fx_sr,x
    sta $d406
    lda #0
    sta $d402
    lda fx_width,x
    sta $d403
    lda fx_control,x
    sta fx_wave
    ldx fx_pitch
    jsr fx_frequency
    lda fx_wave
    ora #1
    sta $d404
    rts
fx_frequency:
    lda _ntsc
    bne @ntsc
    lda plo,x
    sta $d400
    lda phi,x
    sta $d401
    rts
@ntsc:
    lda nlo,x
    sta $d400
    lda nhi,x
    sta $d401
    rts
readbyte:
source: lda $ffff,y
    iny
    rts

.rodata
; Triangle movement, pulse pluck, bright bell and hollow pulse.
fx_control: .byte $10,$40,$40,$40
fx_ad:      .byte $02,$13,$04,$13
fx_sr:      .byte $43,$94,$55,$83
fx_width:   .byte   0,  6,  3,  8
.code

; Flood only open cells. Mark on enqueue, so each cell fits in the bounded queue once.
_flood:
    clc
    adc #<_board
    sta ptr1
    txa
    adc #>_board
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    beq :+
    rts
:   lda #<queue
    sta ptr2
    sta ptr3
    lda #>queue
    sta ptr2+1
    sta ptr3+1
    jsr enqueue
pop:
    ldy #0
    lda (ptr2),y
    sta ptr1
    iny
    lda (ptr2),y
    sta ptr1+1
    clc
    lda ptr2
    adc #2
    sta ptr2
    bcc :+
    inc ptr2+1
:   .repeat 4,i
      .if i=0
        delta .set -40
      .elseif i=1
        delta .set 39
      .elseif i=2
        delta .set 2
      .else
        delta .set 39
      .endif
      clc
      lda ptr1
      adc #<delta
      sta ptr1
      lda ptr1+1
      adc #>delta
      sta ptr1+1
      ldy #0
      lda (ptr1),y
      bne :+
      jsr enqueue
:   .endrepeat
    lda ptr2
    cmp ptr3
    bne pop
    lda ptr2+1
    cmp ptr3+1
    bne pop
    rts
enqueue:
    ldy #0
    lda #5
    sta (ptr1),y
    lda ptr1
    sta (ptr3),y
    iny
    lda ptr1+1
    sta (ptr3),y
    clc
    lda ptr3
    adc #2
    sta ptr3
    bcc :+
    inc ptr3+1
:   rts
