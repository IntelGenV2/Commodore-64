// D015 cannot reliably crop an already active sprite. Clear only its rows
// inside a HUD band, using eight frames in the loaded logic's unused gap.
clip_hud_sprite:
    lda bits,x
    and SpriteMask
    bne !+
    rts
!:  lda #0
    sta Tmp5
    lda #21
    sta Tmp6
    txa
    asl
    tay
    lda $d001,y
    sta WorkY
    cmp #75
    bcs clip_bottom
    lda #75
    sec
    sbc WorkY
    cmp #21
    bcs clip_hidden
    sta Tmp5
clip_bottom:
    lda #251
    ldy Count
    cpy #3
    bcc !+
    lda #227
!:  sec
    sbc WorkY
    bcc clip_hidden
    beq clip_hidden
    cmp #21
    bcs !+
    sta Tmp6
!:  lda Tmp5
    bne clip_copy
    lda Tmp6
    cmp #21
    bne clip_copy
    rts
clip_hidden:
    lda bits,x
    eor #$ff
    and SpriteMask
    sta SpriteMask
    rts
clip_copy:
    lda $07f8,x
    cmp clipPose,x
    bne clip_changed
    lda Tmp5
    cmp clipTop,x
    bne clip_changed
    lda Tmp6
    cmp clipBottom,x
    bne clip_changed
    jmp clip_ready
clip_changed:
    lda $07f8,x
    sta clipPose,x
    lda Tmp5
    sta clipTop,x
    lda Tmp6
    sta clipBottom,x
    lda Tmp5
    asl
    clc
    adc Tmp5
    sta Tmp5
    lda Tmp6
    asl
    clc
    adc Tmp6
    sta Tmp6
    lda $07f8,x
    pha
    lsr
    lsr
    sta Src+1
    pla
    .for(var i=0;i<6;i++) { asl }
    sta Src
    txa
    .for(var i=0;i<6;i++) { asl }
    sta Dst
    txa
    lsr
    lsr
    clc
    adc #>CLIPPED_SPRITES
    sta Dst+1
    ldy #62
clip_row:
    cpy Tmp5
    bcc clip_clear_row
    cpy Tmp6
    bcs clip_clear_row
    .for(var column=0;column<3;column++) {
        lda (Src),y
        sta (Dst),y
        dey
    }
    bpl clip_row
    bmi clip_ready
clip_clear_row:
    lda #0
    .for(var column=0;column<3;column++) {
        sta (Dst),y
        dey
    }
    bpl clip_row
clip_ready:
    txa
    clc
    adc #(CLIPPED_SPRITES/64)
    sta $07f8,x
    rts
