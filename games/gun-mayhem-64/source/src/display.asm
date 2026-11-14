.macro TextAt(label, address, length, color) {
    ldx #0
!:  lda label,x
    sta address,x
    lda #color
    sta address+COLOR-SCREEN,x
    inx
    cpx #length
    bne !-
}
#import "title_menu.asm"
menu_setup:
    lda #0
    sta State
    sta HomeChoice
    sta MenuChoice
    jsr menu_music_start
    jmp title_draw

setup_draw:
    lda #PAGE_SETUP
    sta MenuPage
    jsr menu_page_header
    :MenuLines(setup_lines)
    jmp menu_labels

setup_lines:
    :MenuLine(4,3,10,"MATCH SETUP")
    :MenuLine(6,5,1,"START MATCH")
    :MenuLine(8,5,1,"ARENA")
    :MenuLine(10,5,1,"RULES")
    :MenuLine(12,5,1,"PLAYERS")
    :MenuLine(14,5,1,"HUMANS")
    :MenuLine(16,5,1,"STOCKS")
    :MenuLine(18,5,1,"SOUND")
    :MenuLine(20,5,1,"BACK TO TITLE")
    :MenuLine(23,2,15,"UP/DOWN SELECT  LEFT/RIGHT OR FIRE")
    .byte 0
game_video:
    lda $dd00
    ora #3
    sta $dd00
    lda #$18
    sta $d018
    lda #$08
    sta $d016
    lda #$1b
    sta $d011
    rts
text_screen:
    jsr game_video
    lda #0
    sta $d015
    sta $d021
    .for(var p=0;p<4;p++) { sta edgeRow+p }
    lda #$08
    sta $d016
    ldx #0
!:  lda #32
    .for(var p=0;p<4;p++) { sta SCREEN+p*250,x }
    lda #1
    .for(var p=0;p<4;p++) { sta COLOR+p*250,x }
    inx
    cpx #250
    bne !-
    rts
menu_labels:
    ldx #7
!:  lda menu_row_lo,x
    sta Dst
    lda menu_row_hi,x
    sta Dst+1
    ldy #2
    lda #32
    cpx MenuChoice
    bne !+
    lda #62
!:  sta (Dst),y
    dex
    bpl !--
    jsr menu_map_name
!:  ldy #15
!:  lda (Src),y
    sta SCREEN+8*40+18,y
    lda #1
    sta COLOR+8*40+18,y
    dey
    bpl !-
    lda Count
    clc
    adc #48
    sta SCREEN+12*40+18
    lda Humans
    clc
    adc #48
    sta SCREEN+14*40+18
    lda Lives
    clc
    adc #48
    sta SCREEN+16*40+18
    :TextAt(sound_off,SCREEN+18*40+18,3,1)
    lda AudioOn
    beq !+
    :TextAt(sound_on,SCREEN+18*40+18,3,1)
!:
    jsr menu_rule_name
    ldy #0
!:  lda rule_names,x
    sta SCREEN+10*40+18,y
    lda #1
    sta COLOR+10*40+18,y
    inx
    iny
    cpy #16
    bne !-
    rts
menu_row_lo: .fill 8, <(SCREEN+(6+i*2)*40)
menu_row_hi: .fill 8, >(SCREEN+(6+i*2)*40)
menu_map_name:
    lda Map
    asl
    asl
    asl
    asl
    sta Src
    lda #0
    rol
    clc
    adc #>map_names
    sta Src+1
    lda Src
    clc
    adc #<map_names
    sta Src
    bcc !+
    inc Src+1
!:  rts
menu_rule_name:
    lda Rule
    asl
    asl
    asl
    asl
    tax
    rts
sound_on: .text "ON "
sound_off: .text "OFF"
rule_names: .text "STOCK BATTLE    GUN GAME        "
menu_update:
    lda MenuPage
    bne !+
    jmp title_update
!:  cmp #PAGE_SETUP
    beq setup_update
    lda Edge
    and #17
    beq !+
    jmp title_draw
!:  lda MenuPage
    cmp #PAGE_CONTROLS
    bne menu_help_wait
    lda Edge
    and #2
    beq menu_help_wait
    jmp menu_ladder
menu_help_wait:
    rts
setup_update:
    lda Edge
    and #4
    beq !++
    lda MenuChoice
    bne !+
    lda #8
    sta MenuChoice
!:  dec MenuChoice
!:
    lda Edge
    and #8
    beq !+
    inc MenuChoice
    lda MenuChoice
    cmp #8
    bcc !+
    lda #0
    sta MenuChoice
!:  lda Edge
    and #32
    beq !+
    jsr menu_players
!:
    lda Edge
    and #64
    beq !+
    jsr menu_rules
!:
    lda Edge
    and #19
    bne !+
    jmp menu_labels
!:
    lda MenuChoice
    bne menu_adjust
    lda Edge
    and #16
    bne !+
    rts
!:  jmp start_match
menu_adjust:
    cmp #1
    bne menu_adjust_rule
    lda Edge
    and #1
    beq menu_next_map
    lda Map
    bne !+
    lda #MAP_COUNT
    sta Map
!:  dec Map
    jmp menu_labels
menu_next_map:
    inc Map
    lda Map
    cmp #MAP_COUNT
    bcc !+
    lda #0
    sta Map
!:  jmp menu_labels
menu_adjust_rule:
    cmp #2
    bne !+
    jsr menu_rules
    jmp menu_labels
!:  cmp #3
    bne !+
    jsr menu_players
    jmp menu_labels
!:  cmp #4
    bne !+
    lda Humans
    eor #3
    sta Humans
    jmp menu_labels
!:  cmp #5
    bne menu_adjust_sound
    lda Edge
    and #1
    beq menu_stock_up
    lda Lives
    cmp #2
    bcc !+
    dec Lives
!:  jmp menu_labels
menu_stock_up:
    lda Lives
    cmp #9
    bcs !+
    inc Lives
!:  jmp menu_labels
menu_adjust_sound:
    cmp #6
    beq !+
    jmp title_draw
!:
    lda AudioOn
    eor #1
    sta AudioOn
    jsr audio_volume
    jmp menu_labels
menu_rules:
    lda Edge
    and #1
    beq !+
    lda Rule
    eor #1
    sta Rule
    rts
!:
    inc Rule
    lda Rule
    cmp #2
    bcc !+
    lda #0
    sta Rule
!:  rts
menu_players:
    lda Edge
    and #1
    beq !++
    lda Count
    cmp #2
    bne !+
    lda #5
    sta Count
!:  dec Count
    rts
!:
    inc Count
    lda Count
    cmp #5
    bcc !+
    lda #2
    sta Count
!:  rts
menu_controls_page:
    lda #PAGE_CONTROLS
    sta MenuPage
    jsr menu_page_header
    :MenuLines(help_lines)
    rts
help_lines:
    :MenuLine(5,3,10,"CONTROLS")
    :MenuLine(8,3,7,"P1")
    :MenuLine(8,7,1,"WASD   SPACE FIRE    R RELOAD")
    :MenuLine(10,3,7,"P2")
    :MenuLine(10,7,1,"IJKL   RETURN FIRE   U RELOAD")
    :MenuLine(13,3,10,"JOYSTICKS   P1 PORT 2 / P2 PORT 1")
    :MenuLine(15,3,1,"UP JUMP   DOWN DROP   FIRE SHOOT")
    :MenuLine(17,3,1,"F3 PAUSE   M MUTE   RUN/STOP TITLE")
    :MenuLine(19,3,1,"AMMO/CAPACITY   R = RELOAD SECONDS")
    :MenuLine(23,2,15,"RIGHT GUN LADDER    FIRE/LEFT BACK")
    .byte 0
menu_ladder:
    lda #PAGE_LADDER
    sta MenuPage
    jsr menu_page_header
    :MenuLines(ladder_lines)
    lda #<gg_names
    sta Src
    lda #>gg_names
    sta Src+1
    lda #<(SCREEN+8*40+7)
    sta Dst
    lda #>(SCREEN+8*40+7)
    sta Dst+1
    lda #0
    sta Tmp5
ladder_row:
    ldy #25
!:  lda (Src),y
    sta (Dst),y
    dey
    bpl !-
    lda Tmp5
    clc
    adc #1
    jsr decimal_digits
    // Digits are three columns before the name, with a signed pointer offset.
    pha
    lda Dst
    sec
    sbc #3
    sta Ptr
    lda Dst+1
    sbc #0
    sta Ptr+1
    ldy #0
    lda Tmp2
    sta (Ptr),y
    iny
    pla
    sta (Ptr),y
    lda Src
    clc
    adc #26
    sta Src
    bcc !+
    inc Src+1
!:  lda Dst
    clc
    adc #40
    sta Dst
    bcc !+
    inc Dst+1
!:  inc Tmp5
    lda Tmp5
    cmp #8
    bne ladder_row
    rts
ladder_lines:
    :MenuLine(5,3,10,"GUN LADDER")
    :MenuLine(18,3,1,"DEATH KEEPS YOUR GUN AND REFILLS IT")
    :MenuLine(20,3,1,"EMPTY MAG DROPS ONE GUN LEVEL")
    :MenuLine(23,2,15,"FIRE/LEFT BACK")
    .byte 0

// Hardware X is nine bits; Y is feet minus the 21-pixel frame height.
sync_sprites:
    jsr erase_edges
    lda #0
    sta SpriteMask
    sta SpriteHigh
    lda #$ff
    sta SpriteMulti
    ldx #0
sprite_players:
    lda stocks,x
    beq sprite_hidden
    lda respawn,x
    bne sprite_hidden
    jsr player_edge
    beq !+
    jsr draw_edge
    jmp sprite_skip
!:
    lda pyh,x
    bmi sprite_hidden
    lda ypos,x
    cmp #21
    bcc sprite_hidden
    cmp #220
    bcs sprite_hidden
    lda shield,x
    beq sprite_visible
    lda Tick
    and #2
    beq sprite_visible
sprite_hidden:
    jmp sprite_skip
sprite_visible:
    lda bits,x
    ora SpriteMask
    sta SpriteMask
    lda xpos,x
    clc
    adc #12 // +24 border, -12 sprite center
    sta WorkX
    lda xhigh,x
    adc #0
    beq !+
    lda bits,x
    ora SpriteHigh
    sta SpriteHigh
!:  txa
    asl
    tay
    lda WorkX
    sta $d000,y
    lda ypos,x
    clc
    adc #31 // 51 raster origin -20
    sta $d001,y
    lda #0
    sta Tmp
    lda ground,x
    bne !+
    lda #3
    bne sprite_pose
!:  lda vx,x
    ora vxh,x
    beq !+
    lda Tick
    lsr
    lsr
    and #1
    clc
    adc #1
    sta Tmp
!:  lda Tmp
sprite_pose:
    sta Tmp
    lda flash,x
    beq !+
    lda #4
    sta Tmp
!:  lda facing,x
    beq !+
    lda Tmp
    clc
    adc #6
    sta Tmp
!:  lda costume,x
    beq !+
    lda Tmp
    clc
    adc #16
    sta Tmp
!:  lda Tmp
    clc
    adc #160
    sta $07f8,x
    lda player_colors,x
    sta Tmp
    lda ArenaBG
    and #15
    cmp Tmp
    bne !+
    lda #3
    sta Tmp
!:  lda Tmp
    sta $d027,x
sprite_skip:
    inx
    cpx Count
    bcs !+
    jmp sprite_players
!:
    lda CrateOn
    beq sprite_effect
    lda SpriteMask
    ora #16
    sta SpriteMask
    lda CrateX
    clc
    adc #12
    sta $d008
    lda CrateXH
    adc #0
    beq !+
    lda SpriteHigh
    ora #16
    sta SpriteHigh
!:  lda CrateY
    clc
    adc #41
    sta $d009
    lda #172
    sta $07fc
    lda #7
    sta $d02b
sprite_effect:
    lda FX
    beq sprite_finish
    lda FXXH
    bmi sprite_finish
    cmp #1
    bcc !+
    bne sprite_finish
    lda FXX
    cmp #64
    bcs sprite_finish
!:
    lda SpriteMask
    ora #128
    sta SpriteMask
    lda FXX
    clc
    adc #12
    sta $d00e
    lda FXXH
    adc #0
    beq !+
    lda SpriteHigh
    ora #128
    sta SpriteHigh
!:  lda FXY
    clc
    adc #39
    sta $d00f
    lda #175
    sta $07ff
    lda #7
    sta $d02e
sprite_finish:
    ldx #7
!:  jsr clip_hud_sprite
    dex
    bpl !-
    lda SpriteMulti
    sta $d01c
    lda SpriteHigh
    sta $d010
    lda SpriteMask
    sta $d015
    rts
bits: .byte 1,2,4,8,16,32,64,128
player_colors: .byte 14,10,7,13

// Only dirty bullet cells are restored. Collision never reads screen memory.
erase_bullets:
    ldx #15
erase_loop:
    lda boldh,x
    beq erase_next
    sta Dst+1
    clc
    adc #((BACK-SCREEN)/256)
    sta Src+1
    lda bold,x
    sta Dst
    sta Src
    ldy #0
    lda (Src),y
    sta (Dst),y
    lda Dst+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Dst+1
    lda Src+1
    clc
    adc #((BACKCOLOR-BACK)/256)
    sta Src+1
    lda (Src),y
    sta (Dst),y
    lda #0
    sta boldh,x
erase_next:
    dex
    bpl erase_loop
    rts
draw_bullets:
    ldx #0
draw_bullet_loop:
    lda blife,x
    bne !+
    jmp draw_bullet_next
!:
    lda by,x
    cmp #200
    bcc !+
    jmp draw_bullet_next
!:
    cmp #24
    bcs !+
    jmp draw_bullet_next
!:  ldy Count
    cpy #3
    bcc !+
    cmp #176
    bcc !+
    jmp draw_bullet_next
!:
    lsr
    lsr
    lsr
    tay
    lda row_lo,y
    sta Ptr
    lda row_hi,y
    sta Ptr+1
    lda bx,x
    sta Tmp
    lda bxh,x
    lsr
    ror Tmp
    lsr Tmp
    lsr Tmp
    lda Tmp
    clc
    adc Ptr
    sta Ptr
    bcc !+
    inc Ptr+1
!:  lda Ptr
    sta bold,x
    lda Ptr+1
    sta boldh,x
    // Each active bullet owns one scratch glyph. Copy the underlying cell
    // first so a projectile never punches an 8x8 hole in a platform.
    ldy #0
    lda (Ptr),y
    cmp #EDGE_CHAR
    bne !+
    // Leave the opaque backing behind an off-screen counter untouched.
    lda #0
    sta boldh,x
    jmp draw_bullet_next
!:
    cmp #32
    bne !+
    jmp bullet_sky
!:
    sta Src
    lda #0
    sta Src+1
    .for(var n=0;n<3;n++) {
        asl Src
        rol Src+1
    }
    lda Src+1
    clc
    adc #>CHARSET
    sta Src+1
    txa
    asl
    asl
    asl
    sta Dst
    lda #>(CHARSET+192*8)
    sta Dst+1
    .for(var row=0;row<8;row++) {
        ldy #row
        lda (Src),y
        sta (Dst),y
    }
    lda Ptr+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Src+1
    lda Ptr
    sta Src
    ldy #0
    lda (Src),y
    and #8
    sta WorkY
    bne !+
    lda #1
    sta (Src),y
!:
    stx Slot
    lda bx,x
    and #6
    lsr
    sta Tmp
    lda by,x
    and #6
    tay
    ldx Tmp
    lda WorkY
    beq bullet_hires
    lda bullet_mc,x
    bne bullet_composite
bullet_hires:
    lda bullet_bits,x
bullet_composite:
    sta Tmp2
    lda (Dst),y
    and bullet_clear,x
    ora Tmp2
    sta (Dst),y
    iny
    lda (Dst),y
    and bullet_clear,x
    ora Tmp2
    sta (Dst),y
    ldx Slot
    txa
    clc
    adc #192
    ldy #0
    sta (Ptr),y
    jmp draw_bullet_next
bullet_sky:
    // Shared phase glyphs avoid copying a blank background for every shot.
    lda bx,x
    lsr
    and #3
    sta Tmp
    lda by,x
    and #6
    asl
    ora Tmp
    ora #224
    ldy #0
    sta (Ptr),y
    lda Ptr
    sta Src
    lda Ptr+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Src+1
    lda #1
    sta (Src),y
draw_bullet_next:
    inx
    cpx #16
    bcs !+
    jmp draw_bullet_loop
!:
    rts
bullet_clear: .byte $03,$00,$c0,$f0
bullet_bits: .byte $f0,$3c,$0f,$03
bullet_mc: .byte $a0,$28,$0a,$02
row_lo: .fill 25, <(SCREEN+i*40)
row_hi: .fill 25, >(SCREEN+i*40)

decimal_digits:
    pha
    lda #48
    sta Tmp2
    pla
!:  cmp #10
    bcc !+
    sec
    sbc #10
    inc Tmp2
    bne !-
!:  clc
    adc #48
    rts
result_setup:
    lda #2
    sta State
    jsr erase_bullets
    jsr text_screen
    :TextAt(result_label,SCREEN+10*40+10,20,1)
    lda Winner
    clc
    adc #49
    sta SCREEN+10*40+17
    :TextAt(result_help,SCREEN+12*40+5,30,7)
    lda #7
    sta Sfx
    jsr audio_tick
    rts
result_label: .text "PLAYER 1 WINS       "
result_help: .text "FIRE: CONTINUE  LEFT: TITLE    "
result_update:
    lda Edge
    and #1
    beq !+
    jmp menu_setup
!:  lda Edge
    and #16
    bne !+
    rts
!:  jmp start_match
