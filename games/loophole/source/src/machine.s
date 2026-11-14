.export _init_machine, _wait_frame, _read_controls, _load_scene
.export _title_art, _room_art, _door_art, _plate_art, _retry_art, _font, _sprite_art
.export _ntsc, _disk_keys, _room_shore, _room_snow, _room_bedtime
.importzp ptr1, ptr2, ptr3
.export _joy_pins

.rodata
_title_art:  .incbin "build/title.bin"
_room_art:   .incbin "build/room.bin"
_room_shore: .incbin "build/shore.bin"
_room_snow: .incbin "build/snow.bin"
_room_bedtime: .incbin "build/bedtime.bin"
_plate_art:  .incbin "build/plate.bin"
_door_art:   .incbin "build/door.bin"
_retry_art:  .incbin "build/retry.bin"
_font:       .incbin "build/font.bin"
_sprite_art: .incbin "build/sprites.bin"

.bss
_ntsc:    .res 1
cadence:  .res 1
buttons:  .res 1
_disk_keys: .res 1
_joy_pins: .res 1
fkeys: .res 1

.code
_init_machine:
    sei
    lda $02a6
    eor #1
    and #1
    sta _ntsc
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #$35
    sta $01
    lda #<ignore_nmi
    sta $fffa
    lda #>ignore_nmi
    sta $fffb
    lda #0
    sta $d01a
    sta $d015
    sta $d010
    sta $d017
    sta $d01b
    sta $d01c
    sta $d01d
    sta $d020
    sta $d021
    sta cadence
    lda $dd02
    ora #3
    sta $dd02
    lda $dd00
    and #$fc
    sta $dd00
    lda #$2b
    sta $d011
    lda #$08
    sta $d016
    lda #$38
    sta $d018
    rts
ignore_nmi:
    rti

; Sync to the bottom border. NTSC omits one of each six refreshes.
_wait_frame:
@leave:
    lda $d012
    cmp #250
    beq @leave
@enter:
    lda $d012
    cmp #250
    bne @enter
    lda _ntsc
    beq @done
    inc cadence
    lda cadence
    cmp #6
    bne @done
    lda #0
    sta cadence
    beq @leave
@done:
    rts

; Port 2 supplies every movement input. Scan the function-key row even
; while the stick is held, so a moving or airborne state can be saved.
_read_controls:
    lda #0
    sta buttons
    sta _disk_keys
    sta $dc02
    sta $dc03
    sta $dc00
    lda $dc00
    eor #$ff
    and #$1f
    sta _joy_pins
    tax
    and #$0c
    lsr
    lsr
    sta buttons
    txa
    and #$11
    beq :+
    lda buttons
    ora #4
    sta buttons
:   txa
    and #2
    beq function_keys
    lda buttons
    ora #64
    sta buttons
function_keys:
    lda #1
    sta $dc02
    lda $dc01
    eor #$ff
    sta fkeys
    and #$10                    ; F1
    beq :+
    lda #2
    sta $dc02
    lda $dc01
    bpl pause_key
    lda #$40
    sta $dc02
    lda $dc01
    and #$10
    beq pause_key
    lda buttons
    ora #8
    bne store_f1
pause_key:
    lda buttons
    ora #128
store_f1:
    sta buttons
:   lda fkeys
    and #$20                    ; F3
    beq :+
    lda buttons
    ora #16
    sta buttons
:   lda fkeys
    and #$40                    ; F5
    beq :+
    inc _disk_keys
:   lda fkeys
    and #8                      ; F7, or SHIFT+F7 for F8
    beq input_done
    lda #2
    sta $dc02
    lda $dc01
    bpl mute
    lda #$40
    sta $dc02
    lda $dc01
    and #$10
    beq mute
    lda _disk_keys
    ora #2
    sta _disk_keys
    bne input_done
mute:
    lda buttons
    ora #32
    sta buttons
input_done:
    lda #0
    sta $dc02
    lda buttons
    ldx #0
    rts

; Two consecutive packet streams contain the bitmap and screen colors.
; cc65 fastcall supplies the source pointer in A/X.
_load_scene:
    sta ptr1
    stx ptr1+1
    lda #0
    sta ptr2
    lda #$e0
    sta ptr2+1
    jsr unpack
    lda #0
    sta ptr2
    lda #$cc
    sta ptr2+1
unpack:
    ldy #0
@packet:
    jsr source_byte
    beq @end
    bmi @repeat
    tax
@literal:
    jsr source_byte
    jsr store_byte
    dex
    bne @literal
    beq @packet
@repeat:
    and #$7f
    clc
    adc #3
    tax
    jsr source_byte
    sta ptr3
    jsr source_byte
    tay
    clc
    lda ptr3
    adc ptr2
    sta ptr3
    tya
    adc ptr2+1
    sta ptr3+1
    ldy #0
@copies:
    lda (ptr3),y
    jsr store_byte
    inc ptr3
    bne :+
    inc ptr3+1
:   dex
    bne @copies
    beq @packet
@end:
    rts
source_byte:
    lda (ptr1),y
    inc ptr1
    bne :+
    inc ptr1+1
:   cmp #0
    rts
store_byte:
    sta (ptr2),y
    inc ptr2
    bne :+
    inc ptr2+1
:   rts
