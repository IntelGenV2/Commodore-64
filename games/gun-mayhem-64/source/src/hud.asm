// Two 18-column panels per band. Only changed stats are repainted.
hud_init:
    lda #255
    sta HudState
    ldx #7
!:  sta clipPose,x
    dex
    bpl !-
    ldx #3
!:  sta hudWeapon,x
    dex
    bpl !-
    ldx #119
!:  lda #32
    sta SCREEN,x
    lda #1
    sta COLOR,x
    dex
    bpl !-
    lda #21
    sta EdgeMaxRow
    lda Count
    cmp #3
    bcc !++
    lda #19
    sta EdgeMaxRow
    ldx #119
!:  lda #32
    sta SCREEN+22*40,x
    lda #1
    sta COLOR+22*40,x
    dex
    bpl !-
!:  rts

draw_hud:
    lda State
    cmp HudState
    beq hud_players
    sta HudState
    ldx #5
!:  lda #32
    ldy State
    cpy #3
    bne !+
    lda pause_text,x
!:  sta SCREEN+17,x
    lda #7
    sta COLOR+17,x
    dex
    bpl !--
hud_players:
    ldx #0
!:  jsr hud_player
    inx
    cpx Count
    bcc !-
    rts
hud_player:
    lda #0
    sta Tmp3
    lda reloading,x
    beq hud_check
    sec
    sbc #1
    inc Tmp3
!:  cmp #35
    bcc hud_check
    sbc #35
    inc Tmp3
    bne !-
hud_check:
    lda weapon,x
    cmp hudWeapon,x
    bne hud_render
    lda stocks,x
    cmp hudStocks,x
    bne hud_render
    lda gunlevel,x
    cmp hudLevel,x
    bne hud_render
    lda ammo,x
    cmp hudAmmo,x
    bne hud_ammo_dirty
    lda Tmp3
    cmp hudReload,x
    bne hud_ammo_dirty
    rts
hud_ammo_dirty:
    lda ammo,x
    sta hudAmmo,x
    lda Tmp3
    sta hudReload,x
    jsr hud_pointer
    jmp hud_ammo
hud_render:
    lda weapon,x
    sta hudWeapon,x
    lda ammo,x
    sta hudAmmo,x
    lda Tmp3
    sta hudReload,x
    lda stocks,x
    sta hudStocks,x
    lda gunlevel,x
    sta hudLevel,x
    jsr hud_pointer
    ldy #17
!:  lda #32
    sta (Dst),y
    lda #1
    sta (Ptr),y
    tya
    clc
    adc #40
    tay
    lda #32
    sta (Dst),y
    lda #1
    sta (Ptr),y
    tya
    sec
    sbc #40
    tay
    dey
    bpl !-
    jsr hud_name
    ldy #0
    lda #'P'
    sta (Dst),y
    lda player_colors,x
    sta (Ptr),y
    iny
    sta (Ptr),y
    txa
    clc
    adc #49
    sta (Dst),y
    ldy #3
    lda Rule
    cmp #1
    beq hud_gun_level
    lda stocks,x
    clc
    adc #48
    sta (Dst),y
    iny
    lda #'/'
    sta (Dst),y
    iny
    lda Lives
    clc
    adc #48
    bne hud_stock_done
hud_gun_level:
    lda #'L'
    sta (Dst),y
    iny
    lda gunlevel,x
    clc
    adc #49
    sta (Dst),y
    iny
    lda #'/'
    sta (Dst),y
    iny
    lda #'8'
hud_stock_done:
    sta (Dst),y
hud_ammo:
    ldy #8
    lda ammo,x
    jsr hud_number
    lda Tmp3
    beq hud_capacity
    lda #'R'
    sta (Dst),y
    iny
    lda Tmp3
    clc
    adc #48
    sta (Dst),y
hud_capacity:
    ldy #10
    lda #'/'
    sta (Dst),y
    ldy weapon,x
    lda weapon_ammo,y
    ldy #11
    jsr hud_number
    ldy #12
!:  lda #7
    sta (Ptr),y
    dey
    cpy #7
    bne !-
    rts
hud_name:
    lda weapon,x
    asl
    asl
    asl
    asl
    clc
    adc #<hud_weapons
    sta Src
    lda #>hud_weapons
    adc #0
    sta Src+1
    ldy #15
hud_name_loop:
    lda (Src),y
    sta Tmp
    tya
    clc
    adc #40
    tay
    lda Tmp
    sta (Dst),y
    tya
    sec
    sbc #40
    tay
    dey
    bpl hud_name_loop
    rts
hud_pointer:
    lda hud_address_lo,x
    sta Dst
    sta Ptr
    lda hud_address_hi,x
    sta Dst+1
    clc
    adc #((COLOR-SCREEN)/256)
    sta Ptr+1
    rts
hud_number:
    jsr decimal_digits
    pha
    lda Tmp2
    sta (Dst),y
    iny
    pla
    sta (Dst),y
    dey
    rts
hud_address_lo: .byte <(HUD+2),<(HUD+20),<(SCREEN+22*40+2),<(SCREEN+22*40+20)
hud_address_hi: .byte >(HUD+2),>(HUD+20),>(SCREEN+22*40+2),>(SCREEN+22*40+20)
pause_text: .text "PAUSED"
hud_weapons:
    .text "PISTOL          "
    .text "SMG             "
    .text "SHOTGUN         "
    .text "AR              "
    .text "SNIPER          "
    .text "MINIGUN         "
    .text "CARBINE         "
    .text "AUTO SHOTGUN    "
    .assert "HUD weapon labels occupy eight 16-character rows", *-hud_weapons, 8*16
