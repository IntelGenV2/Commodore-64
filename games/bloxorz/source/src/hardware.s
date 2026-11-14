.export _hw_init,_wait_frame,_scan_input,_unpack,_blit_tile
.export _key,_video_hz,_ticks,_blend_patch,_commit_patch
.export _joy_used, joystick_sample
.import _patch_width,_patch_rows
; The intro's reveal schedule is finished before the board painter runs.
.export _patch_pixels := $0400
.export _publish_sprites
.export _menu_unpack,_menu_unpack_banked,_circuit_tick
.import _sprx,_spry,_sprp,_sprc,_sprmask,_sprite_priority
.import _source,_destination,_blit_source,_blit_x,_blit_y,_blit_erase
.import _audio_reset,_audio_tick
.importzp ptr1,ptr2,ptr3
.repeat 128,C
 .charmap C,C
.endrepeat
.bss
_key: .res 1
_video_hz: .res 1
_ticks: .res 1
joy: .res 1
joy_previous: .res 1
joy_direction: .res 1
joy_clean: .res 1
joy_fire_previous: .res 1
joy_fire: .res 1
joy_delay: .res 1
_joy_used: .res 1
matrix: .res 8
shift: .res 1
function_mask: .res 1
function_key: .res 1
mask: .res 1
length: .res 1
runbyte: .res 1
tile_row: .res 1
tile_col: .res 1
tile_byte: .res 1
cadence: .res 1
.rodata
rows: .byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
; Port 2 has four switches. A diagonal or opposing pair is ambiguous.
cardinals: .byte 0,1,2,0,4,0,0,0,8,0,0,0,0,0,0,0
; CIA row 0, columns 3..6: F7, F1, F3, F5. Shift adds four to PETSCII.
function_codes: .byte 0,$88,$85,0,$86,0,0,0,$87,0,0,0,0,0,0,0
keys:
 .byte 8,13,0,0,0,0,0,0
 .byte '3','W','A','4','Z','S','E',0
 .byte '5','R','D','6','C','F','T','X'
 .byte '7','Y','G','8','B','H','U','V'
 .byte '9','I','J','0','M','K','O','N'
 .byte '+','P','L','-','.',':','@',','
 .byte 0,'*',';',0,0,'=',0,'/'
 .byte '1',0,0,'2',' ',0,'Q',27
ylow: .repeat 200,I
 .byte <($e000+(I/8)*320+(I .mod 8))
 .endrepeat
yhigh: .repeat 200,I
 .byte >($e000+(I/8)*320+(I .mod 8))
 .endrepeat
.code
_hw_init:
 sei
 ; The single-load PRG carries its title bank at $c000. Preserve it in RAM
 ; beneath I/O before the VIC screen and sprite buffers reuse the load area.
 lda $01
 pha
 lda #$34
 sta $01
 ldx #0
copy_menu_bank:
 .repeat 16,P
 lda $c000+P*256,x
 sta $d000+P*256,x
 .endrepeat
 inx
 bne copy_menu_bank
 pla
 sta $01
 lda $02a6
 beq ntsc
 lda #50
 bne standard
ntsc: lda #60
standard: sta _video_hz
 lda #$7f
 sta $dc0d
 sta $dd0d
 lda $dc0d
 lda $dd0d
 lda #$35
 sta $01
 lda #0
 sta $d020
 sta $d021
 sta $d015
 sta $d010
 sta $d017
 sta $d01d
 sta $d01b
 sta _ticks
 sta cadence
 jsr _audio_reset
 lda #$ff
 sta $d01c
 lda #11
 sta $d025
 lda #7
 sta $d026
 ldx #7
 lda #8
sprcolors: sta $d027,x
 dex
 bpl sprcolors
 lda $dd02
 ora #3
 sta $dd02
 lda $dd00
 and #$fc
 sta $dd00
 lda #$18
 sta $d018
 sta $d016
 lda #$3b
 sta $d011
 lda #<irq
 sta $fffe
 lda #>irq
 sta $ffff
 lda #<nmi
 sta $fffa
 lda #>nmi
 sta $fffb
 lda #250
 sta $d012
 lda #1
 sta $d019
 sta $d01a
 cli
 rts
nmi: rti
irq:
 pha
 txa
 pha
 tya
 pha
 ; Menu poses can be read directly from the RAM beneath I/O. The raster
 ; interrupt always gets its VIC/SID registers, then restores the caller's map.
 lda $01
 pha
 lda #$35
 sta $01
 lda #1
 sta $d019
 lda _video_hz
 cmp #60
 bne tick
 inc cadence
 lda cadence
 cmp #6
 bne tick
 lda #0
 sta cadence
 jmp irq_end
tick:
 inc _ticks
 jsr _audio_tick
 jsr joystick_sample
irq_end:
 pla
 sta $01
 pla
 tay
 pla
 tax
 pla
 rti
; Sample once per logical 50 Hz tick, including during rolls and redraws.
; Preserve the active keyboard row if the IRQ interrupts a matrix scan.
joystick_sample:
 lda $dc02
 pha
 lda #0
 sta $dc02
 lda $dc00
 eor #$ff
 tax
 pla
 sta $dc02
 txa
 and #16
 cmp joy_fire_previous
 sta joy_fire_previous
 bne :+
 sta joy_fire
:
 txa
 and #15
 tax
 lda cardinals,x
 cmp joy_previous
 sta joy_previous
 beq @confirmed
 lda #0
 sta joy_clean
 rts
@confirmed:
 sta joy_clean
 cmp joy_direction
 beq @hold
 sta joy_direction
 lda #0
 sta _joy_used
 lda #15              ; 300 ms from confirmation to the first held repeat
 sta joy_delay
 rts
@hold:
 lda joy_delay
 beq :+
 dec joy_delay
: rts
_wait_frame:
 lda _ticks
wait: cmp _ticks
 beq wait
 rts
_scan_input:
 lda #0
 sta _key
 sta $dc02
 sta $dc03
 lda #$ff
 sta $dc00
 sta $dc01
 lda joy_direction
 beq @ready
 cmp _joy_used
 bne @ready
 ldx joy_delay
 bne @inhibit
 cmp joy_clean
 beq @ready
@inhibit:
 ora #$20             ; keep held direction visible to the mid-roll buffer
@ready:
 ora joy_fire
 sta joy
 lda #$ff
 sta $dc02
 ldx #7
scanrow:
 lda rows,x
 sta $dc00
 lda $dc01
 eor #$ff
 sta matrix,x
 dex
 bpl scanrow
 lda matrix+1
 and #$80
 sta shift
 lda matrix+6
 and #$10
 ora shift
 sta shift
 lda matrix
 and #$78
 beq function_released
 ; Keep the original chord until its physical key is released. Releasing
 ; Shift first after F8 must never activate the F7 option beneath it.
 tax
 and function_mask
 bne function_held
 txa
 lsr
 lsr
 lsr
 tay
 lda function_codes,y
 beq function_done
 stx function_mask
 ldx shift
 beq function_save
 clc
 adc #4
function_save:
 sta function_key
function_held:
 lda function_key
 sta _key
function_done:
 jmp joydone
function_released:
 sta function_mask
 ldx #0
 ldy #0
keyrow:
 lda matrix,x
 sta mask
keybit:
 lsr mask
 bcc nextbit
 lda keys,y
 beq nextbit
 sta _key
nextbit:
 iny
 tya
 and #7
 bne keybit
 inx
 cpx #8
 bne keyrow
 lda matrix
 and #$80
 beq vertical
 lda shift
 beq right
 lda joy
 ora #4
 bne storejoy
right:
 lda joy
 ora #8
storejoy: and #$df    ; cursor keys bypass joystick repeat timing
 sta joy
vertical:
 lda matrix
 and #4
 beq joydone
 lda shift
 beq down
 lda joy
 ora #1
 bne setvertical
down:
 lda joy
 ora #2
setvertical: and #$df
 sta joy
joydone:
 lda #$ff
 sta $dc00
 lda joy
 ldx #0
 rts
; Byte RLE: 1..127 literals, 129..255 repeated byte, zero ends.
_unpack:
 lda _source
 sta ptr1
 lda _source+1
 sta ptr1+1
 lda _destination
 sta ptr2
 lda _destination+1
 sta ptr2+1
decode:
 ldy #0
 lda (ptr1),y
 beq unpack_done
 inc ptr1
 bne decode_count
 inc ptr1+1
decode_count:
 cmp #128
 bcs decode_run
 sta length
literal:
 lda (ptr1),y
 sta (ptr2),y
 iny
 cpy length
 bne literal
 tya
 clc
 adc ptr1
 sta ptr1
 bcc advance_output
 inc ptr1+1
 jmp advance_output
decode_run:
 and #127
 sta length
 lda (ptr1),y
 inc ptr1
 bne repeatbyte
 inc ptr1+1
repeatbyte:
 sta (ptr2),y
 iny
 cpy length
 bne repeatbyte
advance_output:
 tya
 clc
 adc ptr2
 sta ptr2
 bcc decode
 inc ptr2+1
 jmp decode
unpack_done:rts

_menu_unpack_banked:
 dec $01
 jsr _menu_unpack
 inc $01
 rts

; A match may refer to a previous pose in the same hidden sprite group.
_menu_unpack:
 lda _source
 sta ptr1
 lda _source+1
 sta ptr1+1
 lda _destination
 sta ptr2
 lda _destination+1
 sta ptr2+1
@token:
 ldy #0
 lda (ptr1),y
 beq @done
 bmi @match
 tax
 inc ptr1
 bne @literal
 inc ptr1+1
@literal:
 lda (ptr1),y
 sta (ptr2),y
 iny
 dex
 bne @literal
 tya
 clc
 adc ptr1
 sta ptr1
 bcc @advance_output
 inc ptr1+1
 jmp @advance_output
@match:
 tax
 and #3
 sta length
 iny
 lda (ptr1),y
 sta runbyte
 lda ptr2
 clc
 sbc runbyte
 sta ptr3
 lda ptr2+1
 sbc length
 sta ptr3+1
 txa
 and #$7c
 lsr
 lsr
 clc
 adc #3
 tax
 lda ptr1
 clc
 adc #2
 sta ptr1
 bcc :+
 inc ptr1+1
 :
 ldy #0
@copy: lda (ptr3),y
 sta (ptr2),y
 iny
 dex
 bne @copy
@advance_output:
 tya
 clc
 adc ptr2
 sta ptr2
 bcc @token
 inc ptr2+1
 jmp @token
@done: rts

; Color-cell reveal over the intact Circuit bitmap. The temporarily unused
; sprite RAM holds its two final palette maps. Padding times are $ff.
_circuit_tick:
 tax
 ldy #0
 cpx #8
 bne @normal
@beds:
 .repeat 4,P
 lda $0400+P*256,y
 cmp #180
 bcc :+
 cmp #237
 bcs :+
 lda #$bb
 sta $c400+P*256,y
 sta $d800+P*256,y
 :
 .endrepeat
 iny
 bne @beds
@normal:
 stx length
@cells:
 .repeat 4,P
 lda $0400+P*256,y
 cmp length
 bne :+
 lda $c800+P*256,y
 sta $c400+P*256,y
 lda $cc00+P*256,y
 sta $d800+P*256,y
 :
 .endrepeat
 iny
 bne @cells
 rts

; Overlay a clipped tile on the 4x16-byte offscreen repair buffer.
; ptr1/ptr3 address its color and keep-mask planes, eight bytes per row.
_blend_patch:
 lda _blit_source
 sta ptr1
 clc
 adc #4
 sta ptr3
 lda _blit_source+1
 sta ptr1+1
 adc #0
 sta ptr3+1
 lda _destination
 sta ptr2
 lda _destination+1
 sta ptr2+1
 ldx _patch_rows
blend_row:
 ldy #0
blend_col:
 lda (ptr2),y
 and (ptr3),y
 ora (ptr1),y
 sta (ptr2),y
 iny
 cpy _patch_width
 bne blend_col
 clc
 lda ptr1
 adc #8
 sta ptr1
 bcc blend_mask
 inc ptr1+1
blend_mask:
 clc
 lda ptr3
 adc #8
 sta ptr3
 bcc blend_dest
 inc ptr3+1
blend_dest:
 clc
 lda ptr2
 adc #4
 sta ptr2
 bcc blend_next
 inc ptr2+1
blend_next:
 dex
 bne blend_row
 rts

; Publish only changed bitmap bytes. Rows use the VIC-II interleaved layout.
_commit_patch:
 lda _blit_x
 and #$fc
 asl
 sta ptr3
 lda #0
 rol
 sta ptr3+1
 ldx #0
 lda _blit_y
 sta tile_row
patch_row:
 ldy tile_row
 clc
 lda ylow,y
 adc ptr3
 sta ptr2
 lda yhigh,y
 adc ptr3+1
 sta ptr2+1
 ldy #0
patch_col:
 lda _patch_pixels,x
 cmp (ptr2),y
 beq patch_skip
 sta (ptr2),y
patch_skip:
 inx
 tya
 clc
 adc #8
 tay
 cpy #32
 bne patch_col
 inc tile_row
 cpx #64
 bne patch_row
 rts
_blit_tile:
 lda _blit_source
 sta ptr1
 lda _blit_source+1
 sta ptr1+1
 lda #0
 sta tile_row
tilerow:
 lda tile_row
 clc
 adc _blit_y
 tax
 lda ylow,x
 sta ptr2
 lda yhigh,x
 sta ptr2+1
 lda _blit_x
 and #$fc
 asl
 bcc tile_add
 inc ptr2+1
tile_add:
 clc
 adc ptr2
 sta ptr2
 bcc tile_nocarry
 inc ptr2+1
tile_nocarry:
 lda #0
 sta tile_col
tilecol:
 lda tile_col
 clc
 adc #4
 tay
 lda (ptr1),y
 sta tile_byte
 ldy #0
 lda (ptr2),y
 and tile_byte
 sta tile_byte
 ldy tile_col
 lda _blit_erase
 bne erase
 lda (ptr1),y
 ora tile_byte
 jmp write_tile
erase: lda tile_byte
write_tile:
 ldy #0
 sta (ptr2),y
 lda ptr2
 clc
 adc #8
 sta ptr2
 bcc tile_next
 inc ptr2+1
tile_next:
 inc tile_col
 lda tile_col
 cmp #4
 bne tilecol
 lda ptr1
 clc
 adc #8
 sta ptr1
 bcc row_next
 inc ptr1+1
row_next:
 inc tile_row
 lda tile_row
 cmp #16
 beq tile_done
 jmp tilerow
tile_done:
 rts

; Flush both coordinate bytes, pointer, color and priority in the border.
_publish_sprites:
 lda #0
 sta mask
 ldx #7
 ldy #14
publish_one:
 lda _sprx,y
 sta $d000,y
 lda _sprx+1,y
 lsr
 rol mask
 lda _spry,x
 sta $d001,y
 lda _sprp,x
 sta $c7f8,x
 lda _sprc,x
 sta $d027,x
 dey
 dey
 dex
 bpl publish_one
 lda mask
 sta $d010
 lda _sprite_priority
 sta $d01b
 lda _sprmask
 sta $d015
 rts
