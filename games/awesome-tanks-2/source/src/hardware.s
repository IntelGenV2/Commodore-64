.export _video_init, _wait_frame, _read_pins, _paint_view
.export _contacts, _map_origin, _show_title_font, _show_field_font
.import _tile_code, _tile_ink
.importzp ptr1, ptr2, ptr3, ptr4
.export _path_slice
.import _generation, _path_read, _path_write
.export _world, _route
; The VIC uses screen RAM at $c000. Its old boot screen is free during battle.
_world = $0400
_route = $ee00
.export _draw_tanks

.segment "BSS"
_contacts:   .res 8
idle_rows:   .res 1
frame_clock: .res 1
_map_origin: .res 2
rows_left:   .res 1
map_col:     .res 1
glyph:       .res 1
cell_base:   .res 2
path_budget: .res 1
_body_pose: .res 1
_turret_pose: .res 1
_actor_slot: .res 1
camera_lo: .res 2
camera_hi: .res 2
local_xy: .res 2
visible_sprites: .res 1

.segment "RODATA"
bits: .byte 1,2,4,8,16,32,64,128
; Neighbors indexed from one row above this cell on the 32-wide map.
offsets: .byte 0,33,64,31
back:    .byte 2,3,0,1
tile_data: .incbin "../build/tiles.bin"
title_chars: .incbin "../build/titlemap.bin"
title_color: .incbin "../build/titleink.bin"
damage_data: .incbin "../build/damage.bin"
tower_base: .incbin "../build/tower-base.bin"
.export _inflate, _load_arena
.import _arena_address

.segment "CODE"
_video_init:
    sei
    lda #$35
    sta $01                 ; RAM above $e000, VIC/CIA/SID still visible
    lda $dd00
    and #$fc
    sta $dd00               ; VIC bank 3
    lda #$02
    sta $d018               ; screen $c000, font $c800
    lda #$1b
    sta $d011
    lda #8
    sta $d016
    lda #0
    sta $d015
    sta $d020
    sta $d021
    sta $d017
    sta $d01d
    sta $d01b
    sta $d025
    lda #15
    sta $d026
    lda #$ff
    sta $d01c
    ; 64 ROM glyphs cover the HUD and menus. Read the character ROM while
    ; the I/O range is banked out, and restore it before touching registers.
    lda #$33
    sta $01
    ldx #0
font_loop:
    lda $d000,x
    sta $c800,x
    lda $d100,x
    sta $c900,x
    inx
    bne font_loop
    lda #$35
    sta $01
    rts

; Boot stub supplies the packed sprite source in $fb/$fc.
_inflate:
    lda $fb
    sta ptr1
    lda $fc
    sta ptr1+1
    ldy #0
    sty ptr2
    lda #$e0
    sta ptr2+1
unpack_at:
sprite_token:
    jsr packed_byte
    tax
    beq sprite_done
    bmi sprite_match
sprite_literal:
    jsr packed_byte
    jsr sprite_byte
    dex
    bne sprite_literal
    beq sprite_token
sprite_match:
    cmp #$c0
    bcs far_match
    and #63
    adc #2                    ; carry clear from CMP
    tax
    sty ptr3+1                ; short distances 1..256, Y is always zero
    bne match_offset          ; lengths are at least two
far_match:
    pha
    lsr
    lsr
    lsr
    lsr
    and #3
    clc
    adc #1
    sta ptr3+1
    pla
    and #15
    adc #3
    tax
match_offset:
    jsr packed_byte
    sta ptr3
    clc                       ; stored distance is one less than actual
    lda ptr2
    sbc ptr3
    sta ptr3
    lda ptr2+1
    sbc ptr3+1
    sta ptr3+1
sprite_copy:
    lda (ptr3),y
    inc ptr3
    bne :+
    inc ptr3+1
:   jsr sprite_byte
    dex
    bne sprite_copy
    beq sprite_token
packed_byte:
    lda (ptr1),y
    inc ptr1
    bne :+
    inc ptr1+1
:   rts
sprite_byte:
    sta (ptr2),y
    inc ptr2
    bne sprite_done
    inc ptr2+1
sprite_done:
    rts

_show_title_font:
    lda #$ca
    ldx #30
    jsr unpack_bank
    lda #<title_chars
    sta ptr1
    lda #>title_chars
    sta ptr1+1
    ldy #0
    sty ptr2
    lda #$c0
    sta ptr2+1
    jsr unpack_at
    lda #<title_color
    sta ptr1
    lda #>title_color
    sta ptr1+1
    sty ptr2
    lda #$d8
    sta ptr2+1
    jmp unpack_at
_show_field_font:
    ldx #1
field_tiles:
    lda tile_src_lo,x
    sta ptr1
    lda tile_src_hi,x
    sta ptr1+1
    lda tile_dst_lo,x
    sta ptr2
    lda tile_dst_hi,x
    sta ptr2+1
    txa
    pha
    ldy #0
    jsr unpack_at
    pla
    tax
    dex
    bpl field_tiles
    ldx #7
:   lda #$18
    sta $c800+189*8,x
    lda fire_left,x
    sta $c800+190*8,x
    lda fire_right,x
    sta $c800+191*8,x
    lda #$ff
    sta tower_last,x
    dex
    bpl :-
    rts

; Hires flames use a forked tip and a dark hollow in the lower flame.
fire_left:  .byte $08,$0c,$2c,$3e,$76,$6e,$3c,$18
fire_right: .byte $20,$30,$34,$7c,$6e,$76,$3c,$18
tile_src_lo: .lobytes tile_data, damage_data
tile_src_hi: .hibytes tile_data, damage_data
tile_dst_lo: .lobytes $ca00, $c800+248*8
tile_dst_hi: .hibytes $ca00, $c800+248*8

; Expand a gun's quadrant atlas directly into its 24x21 multicolor VIC sprite.
; Slot 8 persists for the player. Slot 9 is shared while composing enemy tanks.
.include "../build/turrets.inc"
.import _weapon, _heading, _brain
.export _player_head
_player_head:
    ldx _weapon
    lda _heading
player_gun: cpx #$ff
    bne :+
player_aim: cmp #$ff
    bne :+
    rts
:   stx player_gun+1
    sta player_aim+1
    ldy #0
draw_head:
    sty ptr2
    ldy #$e2
    sty ptr2+1
    pha
    lda head_maps_lo,x
    sta ptr1
    lda head_maps_hi,x
    sta ptr1+1
    ldy #0
    cpx #6
    bcc :+
    iny
:   lda head_left_lo,y
    sta head_left_read+1
    lda head_left_hi,y
    sta head_left_read+2
    lda head_mid_lo,y
    sta head_mid_read+1
    lda head_mid_hi,y
    sta head_mid_read+2
    lda head_right_lo,y
    sta head_right_read+1
    lda head_right_hi,y
    sta head_right_read+2
    pla
    tax
    and #7
    sta glyph
    txa
    lsr
    lsr
    lsr
    tax                       ; quadrant in clockwise order from east
    and #1
    beq :+
    lda #8
    sec
    sbc glyph
    sta glyph
:   ldy glyph
    lda row_start,y
    ldy #$c8                  ; INY for downward-facing heads
    cpx #2
    bcc :+
    ldy #$88                  ; DEY: reflect rows above the horizontal axis
    clc
    adc #10
:   sty head_step
    sta head_row+1
    lda flip_columns,x
    sta head_flip+1
    ldy #0
next_head_row:
    sty head_offset+1
head_row: ldy #0
    lda (ptr1),y
    tax
head_step: iny
    sty head_row+1
head_left_read: lda $ffff,x
    sta ptr3
head_mid_read: lda $ffff,x
    sta ptr3+1
head_right_read: lda $ffff,x
    sta ptr4
head_flip: lda #0
    beq head_offset
    lda ptr4
    jsr reverse_pairs
    pha
    lda ptr3
    jsr reverse_pairs
    sta ptr4
    pla
    sta ptr3
    lda ptr3+1
    jsr reverse_pairs
    sta ptr3+1
head_offset: ldy #0
    ldx #2
head_scanline:
    lda ptr3
    sta (ptr2),y
    iny
    lda ptr3+1
    sta (ptr2),y
    iny
    lda ptr4
    sta (ptr2),y
    iny
    cpy #63                   ; the last logical row is one scanline high
    beq head_done
    dex
    bne head_scanline
    beq next_head_row
head_done:
    rts
reverse_pairs:
    pha
    and #15
    tay
    lda reversed_high,y
    sta ptr4+1
    pla
    lsr
    lsr
    lsr
    lsr
    tay
    lda reversed_low,y
    ora ptr4+1
    rts
row_start: .byte 0,11,22,33,44,55,66,77,88
flip_columns: .byte 0,1,1,0
reversed_low: .byte 0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15
reversed_high: .byte $00,$40,$80,$c0,$10,$50,$90,$d0,$20,$60,$a0,$e0,$30,$70,$b0,$f0

; Give each emplacement a private four-character tile. Its eight aim poses
; sample the tank artwork over an intact, cracked, or breached roof.
.export _tower_head
.import _tower_wear
.segment "BSS"
tower_last: .res 8
.segment "CODE"
_tower_head:
    tay                       ; Y = offset of the 16-byte Site at $f900
    ldx $f90c,y               ; Site.head_slot, unique even for identical guns
    lda $f907,y               ; Site.heading
    clc
    adc #2
    and #$1c
    ora _tower_wear
    cmp tower_last,x
    bne tower_changed
    lda tower_glyphs,x
    ldx #0
    rts
tower_changed:
    sta tower_last,x
    stx tower_slot+1
    and #$1c
    ldx $f90d,y               ; same gun that tower() uses to fire
    ldy #$40
    jsr draw_head
    ldx _tower_wear
    lda roof_lo,x
    sta ptr1
    lda roof_hi,x
    sta ptr1+1
tower_slot: ldx #0
    lda tower_glyphs,x
    pha
    ldx #0
    stx ptr2+1
    asl
    rol ptr2+1
    asl
    rol ptr2+1
    asl
    rol ptr2+1
    sta ptr2
    lda ptr2+1
    ora #$c8
    sta ptr2+1
    stx tower_scan+1
tower_scan: ldy #0
    ldx tower_src_row,y
    lda tower_dst_row,y
    tay
    ; Keep the centre four logical pixels and two from each outer byte.
    lda $e240,x
    asl
    asl
    and #$f0
    sta glyph
    lda $e241,x
    lsr
    lsr
    lsr
    lsr
    ora glyph
    jsr paint_roof
    tya
    clc
    adc #8
    tay
    lda $e241,x
    asl
    asl
    asl
    asl
    sta glyph
    lda $e242,x
    lsr
    lsr
    and #15
    ora glyph
    jsr paint_roof
    inc tower_scan+1
    lda tower_scan+1
    cmp #16
    bne tower_scan
    pla
    ldx #0
    rts
paint_roof:
    sta glyph
    lsr
    ora glyph
    and #$55
    sta map_col
    asl
    ora map_col
    sta map_col
    lda glyph
    eor #$55                  ; convert sprite inks into character inks
    eor (ptr1),y
    and map_col
    eor (ptr1),y
    sta (ptr2),y
    rts
tower_glyphs: .byte 104,161,165,169,173,177,181,185
tower_src_row: .byte 0,6,9,12,18,21,24,27,33,36,39,42,48,51,54,60
tower_dst_row: .byte 0,1,2,3,4,5,6,7,16,17,18,19,20,21,22,23
roof_lo: .lobytes tower_base, $cfc0, $cfe0
roof_hi: .hibytes tower_base, $cfc0, $cfe0

.import _hull, _iframes, _tick
; Cull first. The player uses two layers; each enemy uses one combined sprite.
_draw_tanks:
    lda _view_x
    ldx #0
    jsr camera_pixels
    lda _view_y
    inx
    jsr camera_pixels
    lda #0
    sta visible_sprites
    sta _actor_slot
    lda #<_px
    sta ptr1
    lda #>_px
    sta ptr1+1
    .assert _py = _px+2, lderror, "Player sprite expects consecutive x/y words"
    jsr sprite_position
    bcs enemy_sprite
    lda local_xy
    adc #12
    sta $d000
    sta $d002
    lda local_xy+1
    adc #40
    sta $d001
    sta $d003
    lda #136
    sta $c3f8
    lda _hull
    ora #128
    sta $c3f9
    ldx #13
    ldy #5
    lda _iframes
    beq player_ink
    lda _tick
    and #2
    beq player_ink
    ldx #1
    ldy #1
player_ink:
    lda _player_burn
    beq :+
    lda _clock50
    and #4
    beq :+
    ldx #7
    ldy #8
:   
    stx $d027
    sty $d028
    lda #3
    sta visible_sprites
    jsr _player_head
enemy_sprite:
    ldx _actor_slot
    ldy actor_offsets,x
    lda _actor+4,y
    ora _actor+5,y
    beq next_enemy_sprite
    tya
    clc
    adc #<_actor
    sta ptr1
    lda #>_actor
    sta ptr1+1                 ; all six actor records occupy one page
    jsr sprite_position
    bcs next_enemy_sprite
    jsr explored_local
    beq next_enemy_sprite
    jsr show_enemy_sprite
next_enemy_sprite:
    inc _actor_slot
    lda _actor_slot
    cmp #6
    bne enemy_sprite
    lda #0                    ; clip limit is VIC x=246
    sta $d010
    lda visible_sprites
    sta $d015
    rts
show_enemy_sprite:
    ldx _actor_slot
    ldy actor_offsets,x
    lda _actor+6,y
    sta _turret_pose
    lda _brain+7,y            ; step_dir: north, east, south, west
    clc
    adc #3
    and #3
    sta _body_pose
    lda _actor+7,y
    cmp #24
    bcc normal_hull
    lda _body_pose
    adc #43                   ; carry set: boss hull slots 44..47
    sta _body_pose
    lda #4
    bne enemy_ink
normal_hull:
    asl _body_pose
    lda #10
enemy_ink:
    ldy _burn,x
    beq :+
    tay
    lda _clock50
    and #4
    beq restore_tank_ink
    lda #8
    bne :+
restore_tank_ink:
    tya
:
    sta $d029,x
    txa
    clc
    adc #176
    sta $c3fa,x
    lda bits+2,x
    ora visible_sprites
    sta visible_sprites
    txa
    asl
    tax
    lda local_xy
    adc #12
    sta $d004,x
    lda local_xy+1
    adc #40
    sta $d005,x
    jmp _compose_tank
explored_local:
    ; Look up the explored tile relative to the current view's top left.
    lda local_xy+1
    and #$f0
    asl
    sta ptr1
    lda #0
    rol
    sta ptr1+1
    lda local_xy
    lsr
    lsr
    lsr
    lsr
    ora ptr1
    clc
    adc _map_origin
    sta ptr1
    lda _map_origin+1
    adc ptr1+1
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    rts
camera_pixels:
    pha
    asl
    asl
    asl
    asl
    sta camera_lo,x
    pla
    lsr
    lsr
    lsr
    lsr
    sta camera_hi,x
    rts
sprite_position:
    ldx #0
    ldy #0
sprite_axis:
    lda (ptr1),y
    sec
    sbc camera_lo,x
    sta local_xy,x
    iny
    lda (ptr1),y
    sbc camera_hi,x
    bne outside_view
    lda local_xy,x
    cmp #5
    bcc outside_view
    cmp sprite_limit,x
    bcs outside_view
    iny
    inx
    cpx #2
    bne sprite_axis
    clc
    rts
outside_view:
    sec
    rts
sprite_limit: .byte 235,187

; Overlay nontransparent pairs of turret pixels on the moving hull.
.import _last_body
.segment "BSS"
last_turret: .res 6
last_gun:    .res 6
last_bar:    .res 6
.segment "CODE"
_compose_tank:
    ldx _actor_slot
    ldy actor_offsets,x
    lda _brain,y
    cmp last_gun,x
    bne pose_changed
    lda _actor+13,y
    cmp last_bar,x
    bne pose_changed
    lda _body_pose
    cmp _last_body,x
    bne pose_changed
    lda _turret_pose
    cmp last_turret,x
    bne pose_changed
    rts
pose_changed:
    lda _actor+13,y
    sta last_bar,x
    lda _body_pose
    sta _last_body,x
    lda _turret_pose
    sta last_turret,x
    lda _brain,y
    sta last_gun,x
    tax
    cpx #5                    ; enemy SHOCK slot denotes an unarmed rammer
    bne :+
    ldx #9
:   lda _turret_pose
    ldy #$40
    jsr draw_head
    ldx _body_pose
    jsr pose_address
    sta hull_read+2
    sty hull_read+1
    lda _actor_slot
    clc
    adc #48
    tax
    jsr pose_address
    sta pose_write+2
    sty pose_write+1
    ldx #62
pose_byte:
    lda $e240,x
    sta glyph
    bne masked_hull
    lda #$ff                  ; a transparent head byte leaves the hull intact
    bne hull_read
masked_hull:
    lsr
    ora glyph
    and #$55
    sta map_col
    asl
    ora map_col
    eor #$ff
hull_read: and $ffff,x
    ora glyph
pose_write: sta $ffff,x
    dex
    bpl pose_byte
    ; Actor slots are 16 bytes. Each boss keeps its own eight-step meter
    ; in its sprite, so it follows the hull without taking a shot or VIC slot.
    ldx _actor_slot
    lda last_bar,x         ; Actor.bar_segments (zero for other tanks)
    tax
    beq pose_done
    lda pose_write+1
    sta ptr1
    lda pose_write+2
    sta ptr1+1
    ldy #0
    jsr bar_outline
    jsr bar_fill
    jsr bar_fill
    jmp bar_outline
bar_fill:
    lda boss_bar_left,x
    sta (ptr1),y
    iny
    lda boss_bar_middle,x
    sta (ptr1),y
    iny
    lda boss_bar_right,x
    sta (ptr1),y
    iny
pose_done:
    rts
bar_outline:
    lda #$15
    sta (ptr1),y
    iny
    lda #$55
    sta (ptr1),y
    iny
    lda #$54
    sta (ptr1),y
    iny
    rts
.segment "RODATA"
; Transparent margins, purple end caps, bright fill and a black empty track.
boss_bar_left:   .byte $25,$2d,$2f,$2f,$2f,$2f,$2f,$2f,$2f
boss_bar_middle: .byte $55,$55,$55,$d5,$f5,$fd,$ff,$ff,$ff
boss_bar_right:  .byte $58,$58,$58,$58,$58,$58,$58,$d8,$f8
.segment "CODE"
pose_address:
    txa
    and #3
    ror
    ror
    ror
    and #$c0
    tay
    txa
    lsr
    lsr
    ora #$e0
    rts

; Limit fast frames to 50 Hz. If a battle update ran over its budget,
; accept the elapsed tick immediately instead of waiting another raster.
.import _clock50
_wait_frame:
    lda _clock50
    cmp frame_clock
    beq _wait_frame
    sta frame_clock
    rts

; Scan the keyboard with one active column. Ignore lines already low with
; every column released, including pins grounded by an attached joystick.
_read_pins:
    lda #0
    sta $dc02
    sta $dc03
    sta $dc01
    lda $dc00
    sta idle_rows
    ldx #7
scan:
    lda bits,x
    sta $dc03
    lda $dc00
    eor #$ff
    and idle_rows
    sta _contacts,x
    dex
    bne scan
    lda #0
    sta $dc03
    rts

; 15 x 12 metatiles, with a 32-cell world stride and 40-column screen.
_paint_view:
    lda _map_origin
    sta ptr1
    lda _map_origin+1
    sta ptr1+1
    lda #0
    sta ptr2
    sta ptr3
    lda #$c0
    sta ptr2+1
    lda #$d8
    sta ptr3+1
    lda #12
    sta rows_left
next_row:
    lda #0
    sta map_col
next_tile:
    ldy map_col
    lda (ptr1),y
    tax
    lda _tile_code,x
    sta glyph
    tya
    asl
    tay
    lda glyph
    sta (ptr2),y
    clc
    adc #1
    iny
    sta (ptr2),y
    lda _tile_ink,x
    sta (ptr3),y
    dey
    sta (ptr3),y
    tya
    clc
    adc #40
    tay
    lda _tile_ink,x
    sta (ptr3),y
    lda glyph
    clc
    adc #2
    sta (ptr2),y
    iny
    adc #1
    sta (ptr2),y
    lda _tile_ink,x
    sta (ptr3),y
    inc map_col
    lda map_col
    cmp #15
    bne next_tile
    clc
    lda ptr1
    adc #32
    sta ptr1
    bcc :+
    inc ptr1+1
:   clc
    lda ptr2
    adc #80
    sta ptr2
    sta ptr3
    bcc :+
    inc ptr2+1
    inc ptr3+1
:   dec rows_left
    beq :+
    jmp next_row
:   rts

; Expand twelve breadth-first nodes per update. The queue holds 16-bit
; world offsets. Each visited node has a solid guard ring around the map.
_path_slice:
    lda _path_read
    sta ptr1
    lda _path_read+1
    sta ptr1+1
    lda _path_write
    sta ptr2
    lda _path_write+1
    sta ptr2+1
    lda #12
    sta path_budget
path_node:
    ldy #0
    lda (ptr1),y
    sec
    sbc #32
    sta cell_base
    iny
    lda (ptr1),y
    sbc #0
    sta cell_base+1
    clc
    lda ptr1
    adc #2
    sta ptr1
    bcc :+
    lda ptr1+1
    eor #1
    sta ptr1+1
:   ; Set the three array bases once for all four neighbor reads/writes.
    clc
    lda cell_base
    adc #<_world
    sta world_at+1
    lda cell_base+1
    adc #>_world
    sta world_at+2
    clc
    lda cell_base
    adc #<_route
    sta ptr4
    lda cell_base+1
    adc #>_route
    sta ptr4+1
    ldx #0
neighbor:
    ldy offsets,x
    lda (ptr4),y
    and #$f8
    cmp _generation
    beq skip_neighbor
world_at:
    lda $ffff,y
    cmp #1
    beq enqueue
    cmp #33
    bcc skip_neighbor
enqueue:
    lda back,x
    ora _generation
    sta (ptr4),y
    tya
    clc
    adc cell_base
    ldy #0
    sta (ptr2),y
    lda cell_base+1
    adc #0
    iny
    sta (ptr2),y
    clc
    lda ptr2
    adc #2
    sta ptr2
    bcc skip_neighbor
    lda ptr2+1
    eor #1
    sta ptr2+1
skip_neighbor:
    inx
    cpx #4
    bne neighbor
    lda ptr1
    cmp ptr2
    bne more_nodes
    lda ptr1+1
    cmp ptr2+1
    beq finish_path
more_nodes:
    dec path_budget
    beq finish_path
    jmp path_node
finish_path:
    lda ptr1
    sta _path_read
    lda ptr1+1
    sta _path_read+1
    lda ptr2
    sta _path_write
    lda ptr2+1
    sta _path_write+1
    rts

_load_arena:
    asl
    tax
    lda #$f2
unpack_bank:
    sta ptr2+1
    ldy #0
    sty ptr2
    lda _arena_address,x
    sta ptr1
    lda _arena_address+1,x
    sta ptr1+1
    ; Stage the packed input in the idle map. Re-enable IRQs between
    ; pages so decompressing a title or a sector cannot hold up the SID.
    lda #<_world
    sta ptr3
    lda #>_world
    sta ptr3+1
    cpx #30
    ldx #2
    bcc read_bank_page
    ldx #4
read_bank_page:
    php
    sei
    lda $01
    pha
    lda #$34
    sta $01
:   lda (ptr1),y
    sta (ptr3),y
    iny
    bne :-
    pla
    sta $01
    plp
    inc ptr3+1
    inc ptr1+1
    dex
    bne read_bank_page
    lda #<_world
    sta ptr1
    lda #>_world
    sta ptr1+1
    jmp unpack_at

.export _cell_at, _center, _patrol_step
.importzp c_sp
.import _patrol_cell, _patrol_x, _patrol_y

; y is in AX and x is the two-byte argument on the cc65 stack.
_cell_at:
    stx ptr1+1
    and #$f0
    asl
    sta ptr1
    rol ptr1+1
    ldy #0
    lda (c_sp),y
    lsr
    lsr
    lsr
    lsr
    ora ptr1
    sta ptr1
    iny
    lda (c_sp),y
    asl
    asl
    asl
    asl
    ora ptr1
    ldx ptr1+1
    inc c_sp
    beq :+
    inc c_sp
    beq :++
    rts
:   inc c_sp+1
    inc c_sp
    rts
:   inc c_sp+1
    rts

_center:
    tax
    asl
    asl
    asl
    asl
    ora #8
    sta ptr1
    txa
    lsr
    lsr
    lsr
    lsr
    tax
    lda ptr1
    rts

.segment "BSS"
local_queue: .res 25
local_first: .res 25
local_head: .res 1
local_tail: .res 1
local_best: .res 1
local_dist: .res 1
local_node: .res 1
local_dir: .res 1
delta_x: .res 1
delta_y: .res 1
.segment "RODATA"
local_x: .repeat 25,I
    .byte I .mod 5
.endrepeat
local_y: .repeat 25,I
    .byte I / 5
.endrepeat
patrol_links: .repeat 4,D
    .repeat 25,I
        .if D=0
            .byte (I-5) & 255
        .elseif D=1
            .byte (I+1) + ((I .mod 5)=4)*100
        .elseif D=2
            .byte I+5
        .else
            .byte ((I-1) + ((I .mod 5)=0)*100) & 255
        .endif
    .endrepeat
.endrepeat
local_off: .repeat 25,I
    .byte (I / 5)*32 + (I .mod 5)
.endrepeat
.segment "CODE"
_patrol_step:
    lda _patrol_cell
    and #31
    sec
    sbc #2
    sec
    sbc _patrol_x
    sta delta_x
    lda _patrol_cell+1
    lsr
    lda _patrol_cell
    ror
    lsr
    lsr
    lsr
    lsr
    ldx _patrol_cell+1
    cpx #2
    bcc :+
    ora #16
:   sec
    sbc #2
    sec
    sbc _patrol_y
    sta delta_y
    lda _patrol_cell
    clc
    adc #<(_world-66)
    sta ptr1
    lda _patrol_cell+1
    adc #>(_world-66)
    sta ptr1+1
    ldx #24
    lda #255
:   sta local_first,x
    dex
    bpl :-
    sta local_dist
    lda #0
    sta local_head
    lda #1
    sta local_tail
    lda #12
    sta local_queue
    lda #4
    sta local_first+12
patrol_next:
    ldx local_head
    cpx local_tail
    bne :+
    jmp patrol_done
:
    inc local_head
    ldy local_queue,x
    sty local_node
    lda local_x,y
    clc
    adc delta_x
    bpl :+
    eor #255
    clc
    adc #1
:   sta ptr2
    lda local_y,y
    clc
    adc delta_y
    bpl :+
    eor #255
    clc
    adc #1
:   clc
    adc ptr2
    cmp local_dist
    bcs :+
    sta local_dist
    sty local_best
    cmp #0
    beq patrol_done
:   ldx #0
    stx local_dir
patrol_neighbor:
    lda patrol_links,y
    cmp #25
    bcs patrol_skip
    tax
    lda local_first,x
    cmp #255
    bne patrol_skip
    ldy local_off,x
    lda (ptr1),y
    cmp #1
    beq :+
    cmp #33
    bcc patrol_skip
:   ldy local_node
    lda local_first,y
    cpy #12
    bne :+
    lda local_dir
:   sta local_first,x
    txa
    ldy local_tail
    sta local_queue,y
    inc local_tail
patrol_skip:
    inc local_dir
    ldx local_dir
    cpx #4
    bne :+
    jmp patrol_next
:
    lda patrol_offsets,x
    clc
    adc local_node
    tay
    jmp patrol_neighbor
patrol_done:
    ldx local_best
    lda local_first,x
    ldx #0
    rts
patrol_offsets: .byte 0,25,50,75

; Walk the same tile centres as the AI's Bresenham sight/firing test.
; All differences are at most 31. Keep its work in 8-bit registers and
; only inspect allies when an intermediate tile lies in a firing lane.
.export _clear_line,_shot_line
_clear_line:
    sta los_fire+1
    jsr popax
    jmp los_target
_shot_line:
    ldy #0
    sty los_fire+1
los_target:
    jsr los_xy
    sty line_tx
    sta line_ty
    jsr popax
    jsr los_xy
    sty line_x
    sta line_y
    lda line_tx
    sec
    sbc line_x
    jsr los_magnitude
    sta line_dx
    stx line_sx
    eor #$80
    sta los_x_limit+1
    lda line_ty
    sec
    sbc line_y
    jsr los_magnitude
    sta line_dy
    stx line_sy
    lda #$80
    sec
    sbc line_dy
    sta los_y_limit+1
    lda line_dx
    sec
    sbc line_dy
    sta line_err
    lda line_x
    cmp line_tx
    bne los_step
    lda line_y
    cmp line_ty
    beq los_clear
los_step:
    lda line_err
    asl
    eor #$80
    tax
los_y_limit: cmp #0
    bcc los_y
    beq los_y
    lda line_err
    sec
    sbc line_dy
    sta line_err
    lda line_x
    clc
    adc line_sx
    sta line_x
los_y:
los_x_limit: cpx #0
    bcs los_tile
    lda line_err
    clc
    adc line_dx
    sta line_err
    lda line_y
    clc
    adc line_sy
    sta line_y
los_tile:
    ldy line_y
    cpy line_ty
    bne :+
    lda line_x
    cmp line_tx
    beq los_clear
:   lda ray_row_lo,y
    ora line_x
    sta ptr1
    tya
    lsr
    lsr
    lsr
    ora #>_world
    sta ptr1+1
    ldy #0
    lda (ptr1),y
los_fire: ldx #0
    bne los_firing
    cmp #1
    beq los_step
    cmp #5
    beq los_step
    cmp #8
    beq los_step
    cmp #9
    bcc los_blocked
    cmp #31
    bcc los_step
    cmp #33
    bcs los_step
los_blocked:
    lda #0
    tax
    rts
los_clear:
    lda #1
    ldx #0
    rts
los_firing:
    cmp #5
    beq los_blocked
    cmp #8
    beq los_blocked
    cmp #16
    bcc los_allies
    cmp #31
    bcc los_blocked
los_allies:
    ldx #5
:   ldy actor_offsets,x
    lda _actor+4,y
    ora _actor+5,y
    beq los_next_ally
    lda _actor+1,y
    lsr
    lda _actor,y
    ror
    lsr
    lsr
    lsr
    cmp line_x
    bne los_next_ally
    lda _actor+3,y
    lsr
    lda _actor+2,y
    ror
    lsr
    lsr
    lsr
    cmp line_y
    beq los_blocked
los_next_ally:
    dex
    bpl :-
    jmp los_step
los_magnitude:
    ldx #1
    cmp #$80
    bcc :+
    eor #$ff
    clc
    adc #1
    ldx #$ff
:   rts
los_xy:
    pha
    and #31
    tay
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    sta ptr1
    txa
    asl
    asl
    asl
    ora ptr1
    rts
; Advance a projectile in quarter-pixels. Stop at the first blocking tile
; or overlapping tank. The same trace is used by instant beams.
.export _trace, _ray_x, _ray_y, _ray_dx, _ray_dy, _ray_steps, _ray_skip
.export _ray_cell, _ray_owner, _ray_ignore, _probe_actor
.import _px, _py, _world_w, _world_h
.segment "BSS"
_ray_x: .res 2
_ray_y: .res 2
_ray_cell: .res 2
_ray_ignore: .res 2
_ray_dx: .res 1
_ray_dy: .res 1
_ray_steps: .res 1
_ray_owner: .res 1
_ray_skip: .res 1
probe_x: .res 2
probe_y: .res 2
delta_hi_x: .res 1
delta_hi_y: .res 1
row_targets: .res 32
trace_row: .res 1
eligible: .res 1
.segment "CODE"
.macro pixel axis,out
    lda axis+1
    lsr
    sta out+1
    lda axis
    ror
    lsr out+1
    ror
    sta out
.endmacro
.macro inside coordinate,base,miss
    ; Unsigned (projectile - target + 7) < 15, including page crossings.
    lda coordinate
    sec
    sbc base
    tay
    lda coordinate+1
    sbc base+1
    cpy #249
    adc #0
    bne miss
    tya
    clc
    adc #7
    cmp #15
    bcs miss
.endmacro
; Signed quarter-pixel position to tile index. A step through the left or
; top edge becomes $ff, which the unsigned dimension check rejects.
.macro ray_tile axis
    lda axis
    asl
    lda axis+1
    rol
    sta ptr2
    lda axis
    asl
    asl
    lda ptr2
    rol
.endmacro
.export _prepare_trace
_prepare_trace:
    sta ptr1
    stx ptr1+1
    ldy #0
    sty _ray_skip
    lda (ptr1),y
    sta _ray_x
    iny
    lda (ptr1),y
    sta _ray_x+1
    iny
    lda (ptr1),y
    sta _ray_y
    iny
    lda (ptr1),y
    sta _ray_y+1
    iny
    lda (ptr1),y
    sta _ray_dx
    iny
    lda (ptr1),y
    sta _ray_dy
    ldy #10
    lda (ptr1),y
    sta _ray_owner
    beq player_trace
    ray_tile _ray_y
    tay
    ray_tile _ray_x
    ora ray_row_lo,y
    sta _ray_ignore
    lda _ray_y+1
    lsr
    sta _ray_ignore+1
    rts
player_trace:
    lda #255
    sta _ray_ignore
    sta _ray_ignore+1
    rts
_trace:
    ldx #0
    lda _ray_dx
    bpl :+
    dex
:   stx delta_hi_x
    ldx #0
    lda _ray_dy
    bpl :+
    dex
:   stx delta_hi_y
trace_step:
    clc
    lda _ray_x
    adc _ray_dx
    sta _ray_x
    lda _ray_x+1
    adc delta_hi_x
    sta _ray_x+1
    clc
    lda _ray_y
    adc _ray_dy
    sta _ray_y
    lda _ray_y+1
    adc delta_hi_y
    sta _ray_y+1
    dec _ray_steps
    ray_tile _ray_y
    cmp _world_h
    bcs ray_outside
    tay
    sty trace_row
    ray_tile _ray_x
    cmp _world_w
    bcs ray_outside
    ora ray_row_lo,y
    sta _ray_cell
    lda _ray_y+1
    lsr
    sta _ray_cell+1
    lda _ray_cell            ; _world is page aligned at $0400.
    sta ptr1
    lda _ray_cell+1
    clc
    adc #>_world
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    cmp #1
    beq ray_check
    cmp #33
    bcs ray_check
    lda _ray_cell
    cmp _ray_ignore
    bne ray_wall
    lda _ray_cell+1
    cmp _ray_ignore+1
    beq ray_check
ray_wall:
    lda #254
    ldx #0
    rts
ray_outside:
    ; Return the last in-bounds point for a beam endpoint or shell impact.
    sec
    lda _ray_x
    sbc _ray_dx
    sta _ray_x
    lda _ray_x+1
    sbc delta_hi_x
    sta _ray_x+1
    sec
    lda _ray_y
    sbc _ray_dy
    sta _ray_y
    lda _ray_y+1
    sbc delta_hi_y
    sta _ray_y+1
    lda #253
    ldx #0
    rts
ray_check:
    lda _ray_owner
    bne ray_pixels
    ldy trace_row
    lda _ray_skip
    eor #$ff
    and row_targets,y
    beq ray_miss
    sta eligible
ray_pixels:
    pixel _ray_x,probe_x
    pixel _ray_y,probe_y
    lda _ray_owner
    beq ray_actors
    inside probe_x,_px,ray_miss
    inside probe_y,_py,ray_miss
    lda #0
    tax
    rts
ray_actors:
    jsr _probe_actor
    cmp #255
    bne ray_end
ray_miss:
    lda _ray_steps
    beq :+
    jmp trace_step
:   lda #255
ray_end:
    ldx #0
    rts
_probe_actor:
    ldx #0
actor_probe:
    lsr eligible
    bcc actor_next
    ldy actor_offsets,x
    lda _actor+4,y
    ora _actor+5,y
    beq actor_next
    ; Bias x/y at comparison time, avoiding a multiply per actor.
    lda probe_x
    sec
    sbc _actor,y
    sta ptr2
    lda probe_x+1
    sbc _actor+1,y
    ldy ptr2
    cpy #249
    adc #0
    bne actor_next
    tya
    clc
    adc #7
    cmp #15
    bcs actor_next
    ldy actor_offsets,x
    lda probe_y
    sec
    sbc _actor+2,y
    sta ptr2
    lda probe_y+1
    sbc _actor+3,y
    ldy ptr2
    cpy #249
    adc #0
    bne actor_next
    tya
    clc
    adc #7
    cmp #15
    bcs actor_next
    txa
    ldx #0
    rts
actor_next:
    inx
    lda eligible
    bne actor_probe
    lda #255
    ldx #0
    rts
; Actors cover at most two tile rows. Build the candidate list once per
; volley and check exact pixel bounds and live HP for every possible hit.
.export _refresh_targets
_refresh_targets:
    lda #0
    ldx #31
:   sta row_targets,x
    dex
    bpl :-
    ldx #5
refresh_actor:
    ldy actor_offsets,x
    lda _actor+4,y
    ora _actor+5,y
    beq refresh_next
    lda _actor+3,y
    lsr
    lda _actor+2,y
    ror
    lsr
    lsr
    lsr
    sta map_col
    lda _actor+2,y
    and #15
    ldy map_col
    cmp #7
    bcs refresh_lower
    cpy #0
    beq refresh_center
    lda row_targets-1,y
    ora bits,x
    sta row_targets-1,y
    jmp refresh_center
refresh_lower:
    cmp #9
    bcc refresh_center
    cpy #31
    bcs refresh_center
    lda row_targets+1,y
    ora bits,x
    sta row_targets+1,y
refresh_center:
    lda row_targets,y
    ora bits,x
    sta row_targets,y
refresh_next:
    dex
    bpl refresh_actor
    rts
actor_offsets: .byte 0,16,32,48,64,80
ray_row_lo: .repeat 32,I
    .byte <(I*32)
.endrepeat

; Highest level cell is below row 25. The unused tail of the high HP
; plane adjoins free RAM after the two-page flow-field frontier.
.export _actor, _shot
_actor = $f740
_shot  = $f7a0

; Durability planes share the same page offset. The boss keeps the damage
; already recorded here when it takes a mobile actor slot.
.export _tile_value
_tile_value:
    tay
    txa
    clc
    adc #$c4
    sta read_hp_low+2
    adc #$30
    sta read_hp_high+2
read_hp_low:
    lda $c400,y
read_hp_high:
    ldx $f400,y
    rts

.export _target_range
.import incsp6
; Octagonal distance. All four arguments are world pixel coordinates.
_target_range:
    sta ptr2
    stx ptr2+1
    ldy #2
    lda (c_sp),y
    sec
    sbc ptr2
    sta ptr2
    iny
    lda (c_sp),y
    sbc ptr2+1
    sta ptr2+1
    bcs :+
    lda #0
    sec
    sbc ptr2
    sta ptr2
    lda #0
    sbc ptr2+1
    sta ptr2+1
:   ldy #0
    lda (c_sp),y
    ldy #4
    sec
    sbc (c_sp),y
    sta ptr1
    ldy #1
    lda (c_sp),y
    ldy #5
    sbc (c_sp),y
    sta ptr1+1
    bcs :+
    lda #0
    sec
    sbc ptr1
    sta ptr1
    lda #0
    sbc ptr1+1
    sta ptr1+1
:   ldx ptr1+1
    lda ptr1
    cpx ptr2+1
    bcc range_sum
    bne range_swap
    cmp ptr2
    bcc range_sum
range_swap:
    ldy ptr2
    sta ptr2
    tya
    ldy ptr2+1
    stx ptr2+1
    sty ptr1+1
    sta ptr1
range_sum:
    ldx ptr1+1
    asl
    rol ptr1+1
    clc
    adc ptr1
    sta ptr1
    txa
    adc ptr1+1
    lsr
    ror ptr1
    lsr
    ror ptr1
    lsr
    ror ptr1
    lda ptr1
    clc
    adc ptr2
    tay
    lda ptr2+1
    adc #0
    tax
    tya
    jmp incsp6

.export _draw_beams
.import _beam_count,_beam_x,_beam_y,_overlay_count
.export _overlay_pos,_old_code,_old_ink
_overlay_pos=$ed80
_old_code=$0760
_old_ink=$07a0
.export _erase_shots, _health_meter
.import _hull_hit, _hull_segments, _hull_critical
.segment "CODE"
store_overlay:
    lda line_row_lo,y
    clc
    adc line_x
    sta ptr1
    lda line_row_hi,y
    adc #0
    sta ptr1+1
    txa
    asl
    tay
    lda ptr1
    sta _overlay_pos,y
    lda ptr1+1
    sta _overlay_pos+1,y
    ora #$c0
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    sta _old_code,x
    lda line_glyph
    sta (ptr1),y
    lda ptr1+1
    ora #$18
    sta ptr1+1
    lda (ptr1),y
    sta _old_ink,x
    lda line_ink
    sta (ptr1),y
    inc _overlay_count
    rts

; Keep tracers on the VIC until the replacement frame is ready. A map repaint
; may already have replaced a tracer with fresh terrain while the AI ran.
_erase_shots:
    ldx _overlay_count
    beq erase_done
erase_next:
    dex
    txa
    asl
    tay
    lda _overlay_pos,y
    sta ptr1
    lda _overlay_pos+1,y
    ora #$c0
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    cmp #45
    beq erase_layer
    cmp #42
    beq erase_layer
    cmp #189
    bcc :+
    cmp #192
    bcc erase_layer
:
    cmp #132
    bcc erase_skip
    cmp #160
    bcs erase_skip
erase_layer:
    lda _old_code,x
    sta (ptr1),y
    lda ptr1+1
    ora #$18
    sta ptr1+1
    lda _old_ink,x
    sta (ptr1),y
erase_skip:
    cpx #0
    bne erase_next
    stx _overlay_count
erase_done:
    rts

; Only the meter moves and blinks. The HP digits above it stay legible.
meter_cells = $c000+11*40+31
meter_ink   = $d800+11*40+31
.segment "BSS"
fire_visible: .res 1
.segment "CODE"
_health_meter:
    lda _player_burn
    ora fire_visible
    beq meter_recoil
    lda _player_burn
    sta fire_visible
    ldx #6
    lda _clock50
    and #4
    tay
    lda #7
    cpy #0
    beq :+
    lda #2
:   sta fire_ink+1
fire_status:
    lda #32
    ldy _player_burn
    beq :+
    lda fire_text,x
:   sta $c000+12*40+31,x
fire_ink: lda #7
    sta $d800+12*40+31,x
    dex
    bpl fire_status
meter_recoil:
    ldy #0
    lda #32
    sta meter_cells
    sta meter_cells+8
    ldx #5                    ; green
    lda _hull_hit
    beq meter_critical
    dec _hull_hit
    and #1
    tay                       ; recoil by one column, then settle
    ldx #1                    ; white on impact
    bne meter_ready
meter_critical:
    lda _hull_critical
    beq meter_ready
    ldx #2                    ; red for half the pulse
    lda _clock50
    and #16
    beq meter_ready
    ldx #0
meter_ready:
    stx meter_color+1
    ldx #0
meter_loop:
    cpx _hull_segments
    bcs meter_empty
    lda #160
    sta meter_cells,y
meter_color:
    lda #5
    jmp meter_paint
meter_empty:
    lda #45
    sta meter_cells,y
    lda #3                    ; show the track even during the dark phase
meter_paint:
    sta meter_ink,y
    iny
    inx
    cpx #8
    bne meter_loop
    rts
fire_text: .byte 15,14,32,6,9,18,5 ; ON FIRE
.import _burn,_player_burn
.import _view_x,_view_y,_weapon
.segment "BSS"
line_seg: .res 1
line_x: .res 1
line_y: .res 1
line_tx: .res 1
line_ty: .res 1
line_dx: .res 1
line_dy: .res 1
line_sx: .res 1
line_sy: .res 1
line_err: .res 1
line_ink: .res 1
line_glyph: .res 1
.segment "RODATA"
line_row_lo: .repeat 24,I
    .byte <(I*40)
.endrepeat
line_row_hi: .repeat 24,I
    .byte >(I*40)
.endrepeat
.segment "CODE"
.macro char_coord base,origin,out
    lda base+1,x
    lsr
    lda base,x
    ror
    lsr
    lsr
    ldy base+1,x
    cpy #2
    bcc :+
    ora #64
:   sec
    sbc origin
    sbc origin
    sta out
.endmacro
_draw_beams:
    lda _beam_count
    cmp #2
    bcs :+
    rts
:   lda #0
    sta line_seg
    lda #10
    ldx _weapon
    cpx #5
    bne :+
    lda #14
:   sta line_ink
line_segment:
    ldx line_seg
    char_coord _beam_x,_view_x,line_x
    char_coord _beam_y,_view_y,line_y
    inx
    inx
    stx line_seg
    char_coord _beam_x,_view_x,line_tx
    char_coord _beam_y,_view_y,line_ty
    lda line_tx
    sec
    sbc line_x
    ldx #1
    bpl :+
    eor #255
    clc
    adc #1
    ldx #255
:   sta line_dx
    stx line_sx
    lda line_ty
    sec
    sbc line_y
    ldx #1
    bpl :+
    eor #255
    clc
    adc #1
    ldx #255
:   sta line_dy
    stx line_sy
    lda #45
    ldx line_dx
    cpx line_dy
    bcs :+
    lda #189
:   sta line_glyph
    lda line_dx
    sec
    sbc line_dy
    sta line_err
line_step:
    ldx line_x
    cpx #30
    bcs line_advance
    ldy line_y
    cpy #24
    bcs line_advance
    ldx _overlay_count
    cpx #60
    bcc :+
    rts
:
    jsr store_overlay
line_advance:
    lda line_x
    cmp line_tx
    bne :+
    lda line_y
    cmp line_ty
    beq line_next
:   lda line_err
    asl
    sta ptr2
    clc
    adc line_dy
    bmi :+
    beq :+
    lda line_err
    sec
    sbc line_dy
    sta line_err
    lda line_x
    clc
    adc line_sx
    sta line_x
:   lda ptr2
    sec
    sbc line_dx
    bmi :+
    jmp line_step
:
    lda line_err
    clc
    adc line_dx
    sta line_err
    lda line_y
    clc
    adc line_sy
    sta line_y
    jmp line_step
line_next:
    lda line_seg
    lsr
    clc
    adc #1
    cmp _beam_count
    bcs line_done
    jmp line_segment
line_done:
    rts

.export _glance
.import incsp2
.segment "BSS"
bearing_sign: .res 1
.segment "CODE"
_glance:
    ldy #0
    sty bearing_sign
    stx ptr2+1
    cpx #$80
    bcc :+
    inc bearing_sign
    eor #255
    clc
    adc #1
    pha
    txa
    eor #255
    adc #0
    sta ptr2+1
    pla
:   sta ptr2
    iny
    lda (c_sp),y
    sta ptr1+1
    dey
    lda (c_sp),y
    ldx ptr1+1
    bpl :+
    inc bearing_sign
    inc bearing_sign
    eor #255
    clc
    adc #1
    pha
    txa
    eor #255
    adc #0
    sta ptr1+1
    pla
:   sta ptr1
    lda ptr1+1
    ora ptr2+1
    beq bearing_octant
    lsr ptr1+1
    ror ptr1
    lsr ptr2+1
    ror ptr2
bearing_octant:
    lda ptr2
    cmp ptr1
    bcc :+
    beq :+
    ldx ptr1
    stx ptr2
    sta ptr1
    lda bearing_sign
    ora #4
    sta bearing_sign
:   lda ptr1
    lsr
    sta ptr3
    lsr
    sta ptr3+1
    lsr
    sta ptr4
    lsr
    tax
    lsr
    sta ptr4+1
    lda ptr4
    sec
    sbc ptr4+1
    ldy #0
    cmp ptr2
    bcs bearing_fold
    iny
    txa
    clc
    adc ptr3+1
    cmp ptr2
    bcs bearing_fold
    iny
    lda ptr3
    clc
    adc ptr4+1
    cmp ptr2
    bcs bearing_fold
    iny
    stx ptr4+1
    lda ptr1
    sec
    sbc ptr4
    sbc ptr4+1
    cmp ptr2
    bcs bearing_fold
    iny
bearing_fold:
    lda bearing_sign
    lsr
    lsr
    lsr
    tya
    bcc :+
    eor #255
    clc
    adc #9
:   ldx bearing_sign
    cpx #2
    bcc :+
    cpx #4
    bcc bearing_west
    cpx #6
    bcc :+
bearing_west:
    eor #255
    clc
    adc #17
:   lsr bearing_sign
    bcc :+
    eor #255
    clc
    adc #1
:   and #31
    ldx #0
    jmp incsp2

.export _clear_route_tags
_clear_route_tags:
    ldx #0
:   .repeat 4,I
        lda _route+256*I,x
        and #7
        sta _route+256*I,x
    .endrepeat
    inx
    bne :-
    rts

; Paint into the copy of the terrain glyph that holds this projectile.
; Keep the whole streak in one character and spend one overlay slot per shot.
.export _stamp_tracer
.import _tracer_col, _tracer_row, _tracer_glyph
.import popax
.export _draw_shots, _draw_marker
.segment "BSS"
shot_cursor: .res 2
.segment "CODE"
; Reuse the camera origin from draw_tanks. Cull in 16-bit world coordinates
; before allocating a glyph or touching the screen and colour RAM.
overlay_axis:
    sec
    sbc camera_lo,x
    sta local_xy,x
    lda ptr4+1
    sbc camera_hi,x
    bne outside_overlay
    lda local_xy,x
    cmp overlay_limit,x
    rts
outside_overlay:
    sec
    rts
overlay_limit: .byte 240,192
quarter_axis:
    iny
    lda (ptr2),y
    lsr
    sta ptr4+1
    dey
    lda (ptr2),y
    ror
    lsr ptr4+1
    ror
    jmp overlay_axis
overlay_cell:
    lda local_xy
    lsr
    lsr
    lsr
    sta line_x
    lda local_xy+1
    lsr
    lsr
    lsr
    tay
    ldx _overlay_count
    jmp store_overlay
; C passes x and y on its stack and the effect type in A.
_draw_marker:
    pha
    jsr popax
    stx ptr4+1
    ldx #1
    jsr overlay_axis
    php
    jsr popax
    stx ptr4+1
    plp
    bcs marker_clipped
    ldx #0
    jsr overlay_axis
    bcs marker_clipped
    jsr explored_local
    beq marker_clipped
    pla
    bne draw_flame
    lda #42                    ; bright hires star for an explosion
    sta line_glyph
    lda #7
    sta line_ink
    jmp overlay_cell
marker_clipped:
    pla
    rts
draw_flame:
    lda _clock50
    lsr
    lsr
    and #1
    tax
    lda flame_inks,x
    sta line_ink
    txa
    clc
    adc #190
    sta line_glyph
    jmp overlay_cell
flame_inks: .byte 7,2
.export _draw_burning_tanks
_draw_burning_tanks:
    ldx #0
    lda _player_burn
    jsr mark_burning_hull
    ldx #2
:   lda _burn-2,x
    jsr mark_burning_hull
    inx
    cpx #8
    bne :-
    rts
mark_burning_hull:
    beq no_flame
    lda bits,x
    and visible_sprites
    beq no_flame
    txa
    asl
    tay
    lda $d001,y
    sec
    sbc #59                    ; marker clears the tracks and the boss health bar
    bcc no_flame
    sta local_xy+1
    lda $d000,y
    sec
    sbc #12
    sta local_xy
    txa
    pha
    jsr draw_flame
    pla
    tax
no_flame:
    rts
_draw_shots:
    lda #<draw_one_shot
    ldx #>draw_one_shot
    jmp visit_shots
.export _advance_shots
.import _frame_steps,_steer_rocket,_hostile_beam,_shot_hit,_shot_impact
_advance_shots:
    jsr _refresh_targets
    lda #<advance_one_shot
    ldx #>advance_one_shot
visit_shots:
    sta visit_one+1
    stx visit_one+2
    lda #<_shot
    sta shot_cursor
    lda #>_shot
    sta shot_cursor+1
next_shot:
    lda shot_cursor
    sta ptr2
    lda shot_cursor+1
    sta ptr2+1
    ldy #6
    lda (ptr2),y
    iny
    ora (ptr2),y
    beq advance_cursor
visit_one: jsr draw_one_shot
advance_cursor:
    lda shot_cursor
    clc
    adc #16
    sta shot_cursor
    bcc :+
    inc shot_cursor+1
:   cmp #<(_shot+22*16)
    bne more_shots
    lda shot_cursor+1
    cmp #>(_shot+22*16)
    beq shots_done
more_shots:
    jmp next_shot
shots_done:
    rts
shot_address:
    lda shot_cursor
    ldx shot_cursor+1
    rts
advance_one_shot:
    lda _frame_steps
    sta _ray_steps
    ldy #11
    lda (ptr2),y
    cmp #9
    bne check_lifetime
    lda #1
    sta _ray_steps
    bne trace_round
check_lifetime:
    ldy #6
    lda (ptr2),y
    iny
    and (ptr2),y
    cmp #255
    beq check_rocket
    lda (ptr2),y
    bne reduce_lifetime
    dey
    lda (ptr2),y
    cmp _ray_steps
    bcs subtract_life
    sta _ray_steps
    bcc subtract_life
reduce_lifetime:
    dey
subtract_life:
    lda (ptr2),y
    sec
    sbc _ray_steps
    sta (ptr2),y
    iny
    lda (ptr2),y
    sbc #0
    sta (ptr2),y
check_rocket:
    ldy #11
    lda (ptr2),y
    cmp #6
    bne trace_round
    jsr shot_address
    jsr _steer_rocket
trace_round:
    jsr shot_address
    jsr _prepare_trace
    lda _ray_owner
    beq moving_round
    ldy #11
    lda (ptr1),y
    cmp #7
    beq beam_round
    cmp #8
    bne moving_round
beam_round:
    jsr shot_address
    jmp _hostile_beam
moving_round:
    jsr _trace
    sta _shot_hit
    lda shot_cursor
    sta ptr1
    lda shot_cursor+1
    sta ptr1+1
    ldy #3
:   lda _ray_x,y               ; ray_x and ray_y are consecutive words
    sta (ptr1),y
    dey
    bpl :-
    lda _shot_hit
    cmp #255
    beq :+
    jsr shot_address
    jmp _shot_impact
:   rts
draw_one_shot:
    ldy #0
    ldx #0
    jsr quarter_axis
    bcs skip_shot
    ldy #2
    inx
    jsr quarter_axis
    bcs skip_shot
    ldy #11                    ; Shot.kind
    lda (ptr2),y
    cmp #3
    beq flame_shot
    cmp #9
    bne tracer_shot
    jsr explored_local
    beq skip_shot
    bne tracer_shot
flame_shot:
    jsr explored_local
    beq skip_shot
    jmp draw_flame
skip_shot:
    rts
tracer_shot:
    ldy #10
    lda (ptr2),y               ; incoming yellow, outgoing white
    beq :+
    lda #6
:   clc
    adc #9
    sta line_ink
    lda _overlay_count
    adc #132
    sta line_glyph
    jsr overlay_cell
    lda _old_code,x
    jsr glyph_address
    sty ptr2
    sta ptr2+1
    lda line_glyph
    jsr glyph_address
    sty ptr1
    sty _tracer_glyph
    sta ptr1+1
    sta _tracer_glyph+1
    ldy #7
:   lda (ptr2),y
    sta (ptr1),y
    dey
    bpl :-
    lda local_xy
    and #7
    lsr
    sta _tracer_col
    lda local_xy+1
    and #7
    sta _tracer_row
    lda shot_cursor
    ldx shot_cursor+1
    jmp _stamp_tracer
glyph_address:
    pha
    asl
    asl
    asl
    tay
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    ora #$c8
    rts
.segment "RODATA"
pel_mask: .byte $c0,$30,$0c,$03
long_mask: .byte $fc,$3f
.segment "CODE"
.proc _stamp_tracer
    sta ptr2
    stx ptr2+1
    lda _tracer_glyph
    sta ptr1
    lda _tracer_glyph+1
    sta ptr1+1
    ldy #4                  ; Shot.dx and Shot.dy, in quarter pixels
    lda (ptr2),y
    sta ptr3
    bpl :+
    eor #$ff
    clc
    adc #1
:   sta ptr4
    iny
    lda (ptr2),y
    sta ptr3+1
    bpl :+
    eor #$ff
    clc
    adc #1
:   sta ptr4+1
    ldx _tracer_col
    ora ptr4
    bne moving
    ; A stationary mine has a short, square marker.
    ldy _tracer_row
    cpy #7
    bne :+
    dey
:   lda pel_mask,x
    jsr bright
    lda pel_mask,x
    jmp bright
moving:
    lda ptr4+1
    asl
    cmp ptr4
    bcc horizontal
    ; For a steep shot the head and tail occupy the same column.
    lda ptr4
    asl
    cmp ptr4+1
    bcc same_col
    ; A diagonal crosses two multicolor pixel columns.
    bit ptr3
    bmi west
    cpx #0
    bne :+
    inx
:   lda pel_mask-1,x
    bne tail
west:
    cpx #3
    bne :+
    dex
:   lda pel_mask+1,x
    bne tail
same_col:
    lda pel_mask,x
tail:
    sta ptr4
    lda pel_mask,x
    sta ptr4+1
    ldy _tracer_row
    bit ptr3+1
    bmi upward
    tya
    sec
    sbc #3
    bcs :+
    lda #0
:   tay
    jsr silver_tail
    jmp bright_head
upward:
    cpy #5
    bcc :+
    ldy #4
:   jsr bright_head
silver_tail:
    ; Use the shared silver ink for the tail, retaining neighboring pixels.
    lda ptr4
    and #$55
    eor #$ff
    and (ptr1),y
    sta (ptr1),y
    lda ptr4
    and #$aa
    jsr bright
    lda ptr4
    jmp bright
bright_head:
    lda ptr4+1
    jsr bright
    lda ptr4+1
bright:
    ora (ptr1),y
    sta (ptr1),y
    iny
    rts
horizontal:
    ; Six pixels long with a two-pixel nose and a dark edge under the tail.
    lda _tracer_col
    bit ptr3
    bmi leftward
    cmp #3
    beq :+
    lda #2
:   tax
    lda pel_mask,x
    sta ptr4
    dex
    dex
    jmp bar
leftward:
    cmp #1
    bcc :+
    lda #1
:   tax
    lda pel_mask,x
    sta ptr4
bar:
    ldy _tracer_row
    cpy #7
    bne :+
    dey
:   lda long_mask,x
    jsr bright
    lda long_mask,x
    eor #$ff
    and (ptr1),y
    ora ptr4
    sta (ptr1),y
    rts
.endproc
