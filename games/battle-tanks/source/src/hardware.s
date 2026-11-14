.export _hw_init, _wait_frame, _scan_input, _key, _video_hz
.export _render_terrain
.export _shift_labels
.export _barrel
.import _barrel_tips, _tank_rows, _clip_on, _clip_col, _clip_row, _cell_bits
.import _typing
.export _terrain, _players
; The old text-screen RAM is unused by our bitmap display.
_terrain = $0400
_players = $0600
.importzp ptr1, ptr2, ptr3
.import popax
.export _unpack_banner

; Match the ASCII command values used by the C sources. The c64 assembler
; target otherwise maps uppercase literals to PETSCII's high-byte range.
.repeat 128, C
 .charmap C, C
.endrepeat

.bss
_key: .res 1
_video_hz: .res 1
joy: .res 1
idle: .res 1
shift: .res 1
matrix: .res 8
col: .res 2
mask: .res 1
ploty: .res 1
phasey: .res 1
gun_index: .res 1
gun_x: .res 2
gun_y: .res 1
gun_bottom: .res 1
gun_left: .res 1
gun_shape: .res 1
gun_dir: .res 1
gun_dx: .res 1
gun_dy: .res 1
gun_error: .res 1
gun_e2: .res 1
gun_steps: .res 1
gun_lastx: .res 1
gun_lasty: .res 1
gun_col: .res 1

.rodata
rows: .byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f
gun_masks: .byte $80,$40,$20,$10,$08,$04,$02,$01
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
; Expand a menu bitmap or its screen attributes directly into VIC memory.
; ptr1 = compressed input, ptr2 = output, ptr3 = earlier output for a match.
_unpack_banner:
 sta ptr2
 stx ptr2+1
 jsr popax
 sta ptr1
 stx ptr1+1
@token:
 ldy #0
 lda (ptr1),y
 beq @done
 bmi @match
 tax
 jsr @advance_src
@literal:
 lda (ptr1),y
 sta (ptr2),y
 iny
 dex
 bne @literal
 tya
 jsr @add_src
 jmp @advance_dest
@match:
 pha
 and #63
 clc
 adc #3
 tax
 iny
 lda (ptr1),y
 clc
 adc ptr2
 sta ptr3
 ; A near reference omits the high byte of its negative displacement.
 pla
 and #$40
 bne @near
 iny
 lda (ptr1),y
 adc ptr2+1
 sta ptr3+1
 lda #3
 bne @match_src
@near:
 lda #$ff
 adc ptr2+1
 sta ptr3+1
 lda #2
@match_src:
 jsr @add_src
 ldy #0
@copy:
 lda (ptr3),y
 sta (ptr2),y
 iny
 dex
 bne @copy
@advance_dest:
 tya
 clc
 adc ptr2
 sta ptr2
 bcc @token
 inc ptr2+1
 bne @token
@done:
 rts
@advance_src:
 lda #1
@add_src:
 clc
 adc ptr1
 sta ptr1
 bcc @done
 inc ptr1+1
 rts

_hw_init:
 sei
 lda $02a6
 beq ntsc
 lda #50
 bne video
ntsc: lda #60
video: sta _video_hz
 lda #$7f
 sta $dc0d
 sta $dd0d
 lda $dc0d
 lda $dd0d
 lda #0
 sta $d01a
 sta $d015
 sta $d020
 sta $d021
 ; Use the machine's own uppercase/symbol character ROM, arranged as ASCII.
 lda #$33
 sta $01
 ldx #0
copy_font:
 lda $d100,x
 sta $c400,x
 lda $d000,x
 sta $c500,x
 inx
 bne copy_font
 lda #$35
 sta $01
 lda #0
 ldx #0
clear_color:
 sta $d800,x
 sta $d900,x
 sta $da00,x
 sta $db00,x
 inx
 bne clear_color
 lda $dd02
 ora #3
 sta $dd02
 lda $dd00
 and #$fc
 sta $dd00
 lda #$3b
 sta $d011
 lda #8
 sta $d016
 sta $d018
 ; RESTORE NMI is harmless while the KERNAL is out.
 lda #<nmi
 sta $fffa
 lda #>nmi
 sta $fffb
 rts
nmi: rti

; A = player. Short Bresenham barrel, with no cc65 arithmetic per pixel.
; Skip solid turret pixels so aiming never needs to repaint the tank body.
_barrel:
 sta gun_index
 and #1
 beq gun_type_ready
 lda #7
gun_type_ready:
 sta gun_shape
 lda gun_index
 asl
 asl
 asl
 sta gun_col
 asl
 asl
 ldy #0
 bcc gun_mul_low
 iny
gun_mul_low:
 clc
 adc gun_col
 bcc gun_mul_add
 iny
gun_mul_add:
 sec
 sbc gun_index
 bcs gun_mul_sub
 dey
gun_mul_sub:
 sta ptr1
 tya
 clc
 adc #>_players
 sta ptr1+1
 ldy #9
 lda (ptr1),y
 sta gun_x
 and #$fe
 sec
 sbc #4
 sta gun_left
 iny
 lda (ptr1),y
 sta gun_x+1
 iny
 lda (ptr1),y
 sta gun_bottom
 sec
 sbc #4
 sta gun_y
 ldy #13
 lda (ptr1),y
 ldx #0
 cmp #91
 bcc gun_angle_ready
 sta gun_col
 lda #180
 sec
 sbc gun_col
 ldx #1
gun_angle_ready:
 stx gun_dir
 tax
 lda _barrel_tips,x
 pha
 and #7
 sta gun_dy
 pla
 lsr
 lsr
 lsr
 sta gun_dx
 sec
 sbc gun_dy
 sta gun_error
 lda gun_dx
 cmp gun_dy
 bcs gun_count_ready
 lda gun_dy
gun_count_ready:
 sta gun_steps
 lda #255
 sta gun_lastx
 sta gun_lasty
gun_loop:
 lda gun_x
 and #$fe
 cmp gun_lastx
 bne gun_new_pair
 lda gun_y
 cmp gun_lasty
 bne gun_new_pair
 jmp gun_advance
gun_new_pair:
 lda gun_x
 and #$fe
 sta gun_lastx
 sec
 sbc gun_left
 sta gun_col
 lda gun_y
 sta gun_lasty
 lda gun_bottom
 sec
 sbc gun_y
 cmp #7
 bcs gun_plot
 sta gun_e2
 lda gun_col
 cmp #10
 bcs gun_plot
 lsr
 tax
 lda #6
 sec
 sbc gun_e2
 clc
 adc gun_shape
 tay
 lda _tank_rows,y
 and gun_masks,x
 beq gun_plot
 jmp gun_advance
gun_plot:
 lda _clip_on
 beq gun_bitmap
 lda gun_y
 lsr
 lsr
 lsr
 cmp _clip_row
 bne gun_advance
 lda gun_x+1
 lsr
 lda gun_x
 ror
 lsr
 lsr
 cmp _clip_col
 bne gun_advance
 lda gun_y
 and #7
 clc
 adc #<_cell_bits
 sta ptr1
 lda #>_cell_bits
 adc #0
 sta ptr1+1
 jmp gun_xor
gun_bitmap:
 ldy gun_y
 lda gun_x
 and #$f8
 clc
 adc ylow,y
 sta ptr1
 lda gun_x+1
 adc yhigh,y
 sta ptr1+1
gun_xor:
 lda gun_x
 and #6
 tax
 ldy #0
 lda (ptr1),y
 eor gun_masks,x
 sta (ptr1),y
gun_advance:
 lda gun_steps
 bne gun_step
 rts
gun_step:
 dec gun_steps
 lda gun_error
 asl
 sta gun_e2
 clc
 adc gun_dy
 bmi gun_vertical
 lda gun_error
 sec
 sbc gun_dy
 sta gun_error
 lda gun_dir
 beq gun_right
 lda gun_x
 bne gun_left_low
 dec gun_x+1
gun_left_low:
 dec gun_x
 jmp gun_vertical
gun_right:
 inc gun_x
 bne gun_vertical
 inc gun_x+1
gun_vertical:
 lda gun_dx
 sec
 sbc gun_e2
 bmi gun_repeat
 lda gun_error
 clc
 adc gun_dx
 sta gun_error
 dec gun_y
gun_repeat:
 jmp gun_loop

; Shift only changed bytes in the hires roster row; C draws the last glyph.
_shift_labels:
 ldx #0
label_page:
 lda $fe08,x
 cmp $fe00,x
 beq label_same
 sta $fe00,x
label_same:
 inx
 bne label_page
label_tail:
 lda $ff08,x
 cmp $ff00,x
 beq tail_same
 sta $ff00,x
tail_same:
 inx
 cpx #56
 bne label_tail
 ldx #0
label_colors:
 lda $c3c1,x
 cmp $c3c0,x
 beq color_same
 sta $c3c0,x
color_same:
 inx
 cpx #39
 bne label_colors
 rts

; Synchronize once per full video frame on both PAL and NTSC.
_wait_frame:
 bit $d011
 bmi _wait_frame
wait_bottom:
 bit $d011
 bpl wait_bottom
 rts

; Active-high U,D,L,R,F. Port 2 is primary; port 1 also works hot-seat.
; The physical C64 has two cursor keys: SHIFT reverses each direction.
_scan_input:
 lda #0
 sta $dc02
 sta $dc03
 sta _key
 sta shift
 lda #$ff
 sta $dc00
 sta $dc01
 lda $dc00
 eor #$ff
 and #31
 sta joy
 lda $dc01
 sta idle
 eor #$ff
 and #31
 ora joy
 sta joy
 lda #$ff
 sta $dc02
 ldx #7
scan_row:
 lda rows,x
 sta $dc00
 lda $dc01
 eor #$ff
 and idle
 sta matrix,x
 dex
 bpl scan_row
 lda matrix+1
 and #$80
 sta shift
 lda matrix+6
 and #$10
 ora shift
 sta shift
 ; Direction input comes only from the joystick ports.
 lda matrix
 and #2
 bne setfire
 lda matrix+7
 and #$10
 beq lookup
setfire:
 lda joy
 ora #16
 sta joy
lookup:
 lda _typing
 beq function_keys
 ldx #0
 ldy #0
nextrow:
 lda matrix,x
 sta idle
nextbit:
 lsr idle
 bcc skipkey
 lda keys,y
 beq skipkey
 sta _key
skipkey:
 iny
 tya
 and #7
 bne nextbit
 inx
 cpx #8
 bne nextrow
 ; Letters are text input only. Commands have distinct function-key codes.
function_keys:
 ldx #0
 lda matrix
 and #$10
 beq nof1
 ldx #$80
nof1:
 lda matrix
 and #$20
 beq nof3
 ldx #$82
nof3:
 lda matrix
 and #$40
 beq nof5
 ldx #$84
nof5:
 lda matrix
 and #8
 beq function_done
 ldx #$86
function_done:
 cpx #0
 beq done
 txa
 ldy shift
 beq function_store
 ora #1
function_store:
 sta _key
done:
 lda #$ff
 sta $dc00
 lda joy
 ldx #0
 rts

; Initial multicolor terrain fill: 01 pairs select green independently of tanks.
_render_terrain:
 lda #<$e8c0
 sta ptr1
 lda #>$e8c0
 sta ptr1+1
 ldx #20
 ldy #0
 lda #0
clearloop:
 sta (ptr1),y
 iny
 bne clearloop
 inc ptr1+1
 dex
 bne clearloop
 ; The enlarged field includes one extra 320-byte character row.
 ldy #0
extra_page:
 sta (ptr1),y
 iny
 bne extra_page
 inc ptr1+1
extra_tail:
 sta (ptr1),y
 iny
 cpy #64
 bne extra_tail
 lda #0
 sta col
 sta col+1
 lda #$40
 sta mask
column:
 lda #<_terrain
 clc
 adc col
 sta ptr1
 lda #>_terrain
 adc col+1
 sta ptr1+1
 ldy #0
 lda (ptr1),y
 iny
 cmp (ptr1),y
 bcc height_ready
 lda (ptr1),y
height_ready:
 sta ploty
solid:
 lda ploty
 cmp #192
 bcs nextcol
 jsr dot
 inc ploty
 bne solid
nextcol:
 inc col
 bne lowok
 inc col+1
lowok:
 inc col
 bne pair_ready
 inc col+1
pair_ready:
 lsr mask
 lsr mask
 bne maskok
 lda #$40
 sta mask
maskok:
 lda col+1
 beq column
 lda col
 cmp #64
 bne column
 rts
dot:
 ldx ploty
 lda col
 and #$f8
 clc
 adc ylow,x
 sta ptr1
 lda col+1
 adc yhigh,x
 sta ptr1+1
 ldy #0
 lda (ptr1),y
 ora mask
 sta (ptr1),y
 rts
