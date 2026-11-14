// Reuse each player's hardware sprite: full-size font over a restored black
// character backing. Four mutable frames cost 256 bytes, without multiplexing.
edge_init:
    ldx #7
    lda #$ff
!:  sta CHARSET+EDGE_CHAR*8,x
    dex
    bpl !-
    ldx #3
!:  sta edgeCacheSide,x
    dex
    bpl !-
    ldx #0
    lda #0
!:  sta EDGE_SPRITES,x
    inx
    bne !-
    // Seed the frames before play, so entering an edge only changes digits.
    ldx #0
edge_init_frames:
    lda #1
    sta edgeSide,x
    jsr edge_frame
    inx
    cpx #4
    bcc edge_init_frames
    rts

// A=0 inside, 1 left, 2 right. Signed pixel X must never wrap at an edge.
player_edge:
    lda xhigh,x
    bmi edge_left
    beq edge_inside
    cmp #1
    bne edge_right
    lda xpos,x
    cmp #64
    bcs edge_right
edge_inside:
    lda #0
    rts
edge_left:
    lda #1
    rts
edge_right:
    lda #2
    rts

// CPUs spend their remaining jump recovering instead of retreating farther.
ai_edge_recovery:
    jsr player_edge
    bne !+
    clc
    rts
!:  cmp #1
    beq !+
    lda #4
    bne !++
!:  lda #8
!:  sta input,x
    lda vy,x
    bmi !+
    lda Tick
    and #7
    bne !+
    lda input,x
    ora #1
    sta input,x
!:  sec
    rts

// Run after dirty bullets are erased, before any new bullets are drawn.
erase_edges:
    ldx #3
erase_edge_loop:
    lda edgeRow,x
    beq erase_edge_next
    jsr edge_screen_pointer
    lda Dst
    sta Src
    lda Dst+1
    clc
    adc #((BACK-SCREEN)/256)
    sta Src+1
    jsr edge_restore_panel
    lda Src+1
    clc
    adc #((BACKCOLOR-BACK)/256)
    sta Src+1
    lda Dst+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Dst+1
    jsr edge_restore_panel
    lda #0
    sta edgeRow,x
erase_edge_next:
    dex
    bpl erase_edge_loop
    rts
edge_restore_panel:
    .for(var row=0;row<3;row++) {
        .for(var col=0;col<4;col++) {
            ldy #(row*40+col)
            lda (Src),y
            sta (Dst),y
        }
    }
    rts

edge_screen_pointer:
    ldy edgeRow,x
    lda row_lo,y
    sta Dst
    lda row_hi,y
    sta Dst+1
    ldy edgeSide,x
    lda edge_column-1,y
    clc
    adc Dst
    sta Dst
    bcc !+
    inc Dst+1
!:  rts
edge_column: .byte 1,35

draw_edge:
    sta edgeSide,x
    jsr edge_frame
    lda pyh,x
    bmi edge_top
    lda ypos,x
    sec
    sbc #22
    bcc edge_top
    lsr
    lsr
    lsr
    cmp #3
    bcc edge_top
    cmp EdgeMaxRow
    bcc edge_row_ready
    lda EdgeMaxRow
    bne edge_row_ready
edge_top:
    lda #3
edge_row_ready:
    sta edgeRow,x
    lda #3
    sta Tmp6
    lda edgeRow,x
    cmp #13
    bcc !+
    lda #$fd
    sta Tmp6
!:
    stx SavedX
    // Stack toward the screen's center when several players share an edge.
edge_try_row:
    ldy #0
edge_check_row:
    cpy SavedX
    beq edge_row_free
    lda edgeSide,y
    cmp edgeSide,x
    bne edge_check_next
    lda edgeRow,y
    beq edge_check_next
    sec
    sbc edgeRow,x
    clc
    adc #2
    cmp #5
    bcs edge_check_next
    lda edgeRow,y
    clc
    adc Tmp6
    cmp #3
    bcs !+
    lda EdgeMaxRow
!:
    cmp EdgeMaxRow
    bcc !+
    beq !+
    lda #3
!:
    sta edgeRow,x
    jmp edge_try_row
edge_check_next:
    iny
    bne edge_check_row
edge_row_free:
    jsr edge_screen_pointer
    lda Dst
    sta Src
    lda Dst+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Src+1
    .for(var row=0;row<3;row++) {
        .for(var col=0;col<4;col++) {
            ldy #(row*40+col)
            lda #EDGE_CHAR
            sta (Dst),y
            lda #0
            sta (Src),y
        }
    }
    lda bits,x
    ora SpriteMask
    sta SpriteMask
    lda bits,x
    eor #$ff
    and SpriteMulti
    sta SpriteMulti
    lda edgeSide,x
    cmp #1
    beq edge_sprite_left
    lda bits,x
    ora SpriteHigh
    sta SpriteHigh
    lda #52 // 308 = 280 + four-pixel inset + VIC border
    bne edge_sprite_x
edge_sprite_left:
    lda #36 // 8 + four-pixel inset + VIC border
edge_sprite_x:
    sta Tmp
    txa
    asl
    tay
    lda Tmp
    sta $d000,y
    lda edgeRow,x
    asl
    asl
    asl
    clc
    adc #51
    sta $d001,y
    txa
    clc
    adc #(EDGE_SPRITES/64)
    sta $07f8,x
    lda #1
    sta $d027,x
    rts

edge_frame:
    lda edgeSide,x
    cmp #1
    bne edge_right_distance
    lda #0
    sec
    sbc xpos,x
    sta WorkX
    lda #0
    sbc xhigh,x
    sta WorkXH
    jmp edge_distance_ready
edge_right_distance:
    lda xpos,x
    sec
    sbc #63 // Pixels past the last visible column (319).
    sta WorkX
    lda xhigh,x
    sbc #1
    sta WorkXH
edge_distance_ready:
    lda WorkXH
    cmp #3
    bcc edge_distance_capped
    bne edge_cap_distance
    lda WorkX
    cmp #232
    bcc edge_distance_capped
edge_cap_distance:
    lda #231
    sta WorkX
    lda #3
    sta WorkXH
edge_distance_capped:
    lda edgeSide,x
    cmp edgeCacheSide,x
    bne edge_new_frame
    lda WorkX
    cmp edgeDistance,x
    bne edge_new_frame
    lda WorkXH
    cmp edgeDistanceH,x
    bne edge_new_frame
    rts
edge_new_frame:
    lda edgeSide,x
    eor edgeCacheSide,x
    sta Tmp5
    lda edgeSide,x
    sta edgeCacheSide,x
    lda WorkX
    sta edgeDistance,x
    lda WorkXH
    sta edgeDistanceH,x
    lda #48
    sta edgeDigits
    // Four bounded comparisons avoid nine 16-bit subtractions at long range.
    .for(var hundreds=8;hundreds>=1;hundreds=hundreds/2) {
        lda WorkXH
        cmp #>(hundreds*100)
        bcc !++
        bne !+
        lda WorkX
        cmp #<(hundreds*100)
        bcc !++
    !:  lda WorkX
        sec
        sbc #<(hundreds*100)
        sta WorkX
        lda WorkXH
        sbc #>(hundreds*100)
        sta WorkXH
        lda edgeDigits
        clc
        adc #hundreds
        sta edgeDigits
    !:
    }
edge_tens:
    ldy #48
    lda WorkX
    cmp #80
    bcc !+
    sbc #80
    ldy #56
!:  cmp #40
    bcc !+
    sbc #40
    .for(var i=0;i<4;i++) { iny }
!:  cmp #20
    bcc !+
    sbc #20
    iny
    iny
!:  cmp #10
    bcc !+
    sbc #10
    iny
!:  ora #48
    sta edgeDigits+2
    sty edgeDigits+1
    txa
    .for(var i=0;i<6;i++) { asl }
    clc
    adc #3
    sta Dst
    lda #>EDGE_SPRITES
    sta Dst+1
    lda Tmp5
    bne !+
    jmp edge_header_done
!:
    txa
    tay
    lda edgeSide,x
    cmp #1
    beq !+
    tya
    clc
    adc #4
    tay
!:  lda edge_header_lo,y
    sta Src
    lda edge_header_hi,y
    sta Src+1
    .for(var i=0;i<24;i++) {
        ldy #i
        lda (Src),y
        sta (Dst),y
    }
edge_header_done:
edge_number:
    lda Dst
    clc
    adc #30 // Ten sprite rows down.
    sta Dst
    lda edgeDigits
    cmp edgeHundreds,x
    beq !+
    sta edgeHundreds,x
    jsr edge_glyph
!:
    inc Dst
    lda edgeDigits+1
    cmp edgeTens,x
    beq !+
    sta edgeTens,x
    jsr edge_glyph
!:
    inc Dst
    lda edgeDigits+2
    cmp edgeOnes,x
    beq !+
    sta edgeOnes,x
    jsr edge_glyph
!:
    rts

// Copy one existing bold 8x8 font glyph into a sprite's three-byte row stride.
edge_glyph:
    sta Src
    lda #0
    sta Src+1
    .for(var i=0;i<3;i++) { asl Src; rol Src+1 }
    lda Src+1
    clc
    adc #>CHARSET
    sta Src+1
    .for(var row=0;row<8;row++) {
        ldy #row
        lda (Src),y
        ldy #(row*3)
        sta (Dst),y
    }
    rts

// Native font bytes, laid out once in sprite order to make edge entry cheap.
edge_header_lo: .fill 8, <(edge_headers+i*24)
edge_header_hi: .fill 8, >(edge_headers+i*24)
edge_headers:
.var edgeFont=LoadBinary("../assets/port/charset.bin")
.for(var side=0;side<2;side++) {
    .for(var player=0;player<4;player++) {
        .for(var row=0;row<8;row++) {
            .if(side==0) {
                .byte edgeFont.get(EDGE_LEFT_CHAR*8+row),edgeFont.get(80*8+row),edgeFont.get((49+player)*8+row)
            } else {
                .byte edgeFont.get(80*8+row),edgeFont.get((49+player)*8+row),edgeFont.get(EDGE_RIGHT_CHAR*8+row)
            }
        }
    }
}
