// Records contain text length, screen address, ink and native screen codes.
.macro MenuLine(row, col, ink, caption) {
    .assert "Menu line fits", col+caption.size() <= 40, true
    .byte caption.size()
    .word SCREEN+row*40+col
    .byte ink
    .text caption
}
.macro MenuLines(table) {
    ldx #<table
    ldy #>table
    jsr menu_lines
}
menu_lines:
    stx Src
    sty Src+1
menu_line_next:
    jsr read_byte
    cmp #0
    beq menu_line_done
    tax
    jsr read_byte
    sta Dst
    sta Ptr
    jsr read_byte
    sta Dst+1
    clc
    adc #>(COLOR-SCREEN)
    sta Ptr+1
    jsr read_byte
    sta Tmp2
!:  lda (Src),y
    sta (Dst),y
    lda Tmp2
    sta (Ptr),y
    iny
    dex
    bne !-
    tya
    clc
    adc Src
    sta Src
    bcc menu_line_next
    inc Src+1
    jmp menu_line_next
menu_line_done:
    rts

.const TITLE_BITMAP=$e000
.const TITLE_MATRIX=$cc00
.const COVER_ROWS=12

title_draw:
    lda #PAGE_TITLE
    sta MenuPage
    jsr text_screen
    lda #$0b
    sta $d011
    :MenuLines(title_lines)
    ldx #13
    jsr menu_rule
    ldx #22
    jsr menu_rule
    jsr title_status
    jsr draw_cover
    ldx #COVER_ROWS
!:  jsr title_text_row
    inx
    cpx #25
    bne !-
    jsr title_cursor
    // VIC bank 3 exposes RAM beneath the KERNAL. Its upper bitmap is
    // scratch in matches; load_map reconstructs the arena back buffers.
    lda $dd00
    and #$fc
    sta $dd00
    lda #$38
    sta $d018
    lda #$18
    sta $d016
    lda #$3b
    sta $d011
    rts

draw_cover:
    lda #<title_cover
    sta Src
    lda #>title_cover
    sta Src+1
    lda #<TITLE_BITMAP
    sta Dst
    lda #>TITLE_BITMAP
    sta Dst+1
cover_cell:
    jsr read_byte
    sta Tmp
    lda #0
    ldx #8
cover_scanline:
    asl Tmp
    bcc !+
    jsr read_byte
!:  sta (Dst),y
    inc Dst
    bne !+
    inc Dst+1
!:  dex
    bne cover_scanline
    lda Dst+1
    cmp #>(TITLE_BITMAP+COVER_ROWS*320)
    bne cover_cell
    ldx #0
!:  lda title_ink,x
    sta TITLE_MATRIX,x
    lda title_ink+240,x
    sta TITLE_MATRIX+240,x
    lda title_color,x
    sta COLOR,x
    lda title_color+240,x
    sta COLOR+240,x
    inx
    cpx #240
    bne !-
    rts

// Render one 40-character row of the normal menu font into the bitmap.
// The raster split presents these rows in hires below the multicolor cover.
title_text_row:
    stx SavedX
    lda row_lo,x
    sta title_read_char+1
    sta title_read_ink+1
    sta title_write_ink+1
    lda row_hi,x
    sta title_read_char+2
    clc
    adc #>(COLOR-SCREEN)
    sta title_read_ink+2
    lda row_hi,x
    clc
    adc #>(TITLE_MATRIX-SCREEN)
    sta title_write_ink+2
    lda bitmap_row_lo,x
    sta Dst
    lda bitmap_row_hi,x
    sta Dst+1
    ldx #0
title_read_char:
    lda SCREEN,x
    sta Tmp
    asl
    asl
    asl
    sta Src
    lda Tmp
    lsr
    lsr
    lsr
    lsr
    lsr
    ora #>CHARSET
    sta Src+1
    ldy #7
!:  lda (Src),y
    sta (Dst),y
    dey
    bpl !-
title_read_ink:
    lda COLOR,x
    asl
    asl
    asl
    asl
title_write_ink:
    sta TITLE_MATRIX,x
    lda Dst
    clc
    adc #8
    sta Dst
    bcc !+
    inc Dst+1
!:  inx
    cpx #40
    bne title_read_char
    ldx SavedX
    rts
bitmap_row_lo: .fill 25, <(TITLE_BITMAP+i*320)
bitmap_row_hi: .fill 25, >(TITLE_BITMAP+i*320)

title_cursor:
    ldx #3
!:  lda title_rows,x
    tay
    lda #0
    cpx HomeChoice
    bne !+
    lda #$70
!:  sta TITLE_MATRIX+14*40+1,y
    dex
    bpl !--
    rts

title_status:
    jsr menu_map_name
    ldy #15
!:  lda (Src),y
    sta SCREEN+15*40+23,y
    dey
    bpl !-
    jsr menu_rule_name
    ldy #0
!:  lda rule_names,x
    sta SCREEN+19*40+23,y
    inx
    iny
    cpy #16
    bne !-
    rts

// A short divider with one gold end cap. X is the screen row.
menu_rule:
    lda row_lo,x
    sta Dst
    sta Ptr
    lda row_hi,x
    sta Dst+1
    clc
    adc #>(COLOR-SCREEN)
    sta Ptr+1
    ldy #38
!:  lda #45
    sta (Dst),y
    lda #11
    sta (Ptr),y
    dey
    bne !-
    iny
    lda #7
    sta (Ptr),y
    rts

menu_page_header:
    jsr text_screen
    :MenuLines(page_identity)
    ldx #3
    jsr menu_rule
    ldx #22
    jmp menu_rule

title_update:
    lda ActionEdge
    and #$78
    beq title_navigate
    ldx #0
!:  and title_keys,x
    bne title_activate
    inx
    lda ActionEdge
    jmp !-
title_navigate:
    lda Edge
    and #32
    beq !+
    jsr menu_players
!:  lda Edge
    and #64
    beq !+
    jsr menu_rules
    jsr title_status
    ldx #19
    jsr title_text_row
!:  lda Edge
    and #4
    beq !+
    dec HomeChoice
!:  lda Edge
    and #8
    beq !+
    inc HomeChoice
!:  lda HomeChoice
    and #3
    sta HomeChoice
    lda Edge
    and #16
    bne !+
    jmp title_cursor
!:
    ldx HomeChoice
title_activate:
    stx HomeChoice
    cpx #0
    bne !+
    jmp start_match
!:  cpx #1
    bne !+
    jmp setup_draw
!:  cpx #2
    bne !+
    jmp menu_controls_page
!:  jmp menu_ladder

title_keys: .byte $10,$20,$40,$08
title_rows: .byte 0,80,160,240
page_identity:
    :MenuLine(1,3,7,"GUN MAYHEM 64")
    .byte 0
title_lines:
    :MenuLine(14,1,0,">")
    :MenuLine(16,1,0,">")
    :MenuLine(18,1,0,">")
    :MenuLine(20,1,0,">")
    :MenuLine(14,3,10,"F1")
    :MenuLine(14,7,1,"START MATCH")
    :MenuLine(16,3,10,"F3")
    :MenuLine(16,7,1,"MATCH SETUP")
    :MenuLine(18,3,10,"F5")
    :MenuLine(18,7,1,"CONTROLS")
    :MenuLine(20,3,10,"F7")
    :MenuLine(20,7,1,"GUN LADDER")
    :MenuLine(14,23,12,"ARENA")
    :MenuLine(18,23,12,"RULES")
    :MenuLine(23,2,15,"W/S OR CURSOR MOVE   RETURN/FIRE GO")
    .byte 0

