// Eight distinct weapon behaviors. No damage bar: impacts change velocity.
weapon_rate: .byte 18,3,16,5,24,2,7,12
weapon_power: .byte 46,46,56,84,208,20,62,36
weapon_speed: .byte 6,7,5,8,8,7,8,5
weapon_pellets: .byte 1,1,3,1,1,1,1,4
weapon_ammo: .byte 12,24,5,20,4,60,15,8
weapon_reload: .byte 35,49,70,56,77,105,42,84
// Original Progressive ladder condensed to the eight available C64 classes.
// Repeated families are omitted; the original machine-gun tier uses minigun.
gg_source_ids: .byte 2,29,19,46,13,11,62,66
gg_classes: .byte 0,6,1,7,2,4,3,5
gg_names:
    .text "PISTOL                    "
    .text "CARBINE                   "
    .text "SMG                       "
    .text "AUTO SHOTGUN              "
    .text "SHOTGUN                   "
    .text "SNIPER                    "
    .text "AR                        "
    .text "MINIGUN                   "
    .assert "Gun ladder labels occupy eight 26-character rows", *-gg_names, 8*26
shoot:
    lda reloading,x
    beq !+
    rts
!:  lda ammo,x
    bne !+
    jmp begin_reload
!:
    lda cooldown,x
    beq !+
    rts
!:  ldy #15
shoot_find_space:
    lda blife,y
    beq shoot_ready
    dey
    bpl shoot_find_space
    rts
shoot_ready:
    ldy weapon,x
    lda weapon_rate,y
    sta cooldown,x
    lda weapon_pellets,y
    sta Pellets
    dec ammo,x
shoot_ammo_ok:
    lda #3
    sta flash,x
    lda #2
    sta Sfx
    stx SavedX
shoot_pellet:
    ldy #0
!:  lda blife,y
    beq shoot_slot
    iny
    cpy #16
    bcc !-
    jmp shoot_finish
shoot_slot:
    lda xpos,x
    sta bx,y
    lda xhigh,x
    sta bxh,y
    lda #0
    sta bdistance,y
    lda weapon,x
    sta bkind,y
    lda ypos,x
    sec
    sbc #9
    sta by,y
    stx Tmp5
    lda weapon,x
    tax
    lda weapon_speed,x
    sta Tmp4
    ldx Tmp5
    lda facing,x
    beq shot_left
    lda Tmp4
    sta bvx,y
    jmp shot_dir_done
shot_left:
    lda Tmp4
    eor #$ff
    clc
    adc #1
    sta bvx,y
shot_dir_done:
    txa
    sta bowner,y
    lda #45
    sta blife,y
    lda #0
    sta bvy,y
    lda weapon,x
    cmp #2
    beq shot_spread
    cmp #7
    bne shot_power
shot_spread:
    lda Pellets
    sec
    sbc #2
    cmp #2
    bne !+
    lda #0
!:
    sta bvy,y
shot_power:
    stx Tmp5
    lda weapon,x
    tax
    lda weapon_power,x
    sta bpower,y
    ldx Tmp5
    dec Pellets
    beq !+
    jmp shoot_pellet
shoot_finish:
!:
    lda ammo,x
    bne !+
    jmp begin_reload
!:
    rts

// Stock pickups revert to pistol when emptied. Gun Game demotes one tier.
equip_weapon:
    ldy weapon,x
    lda weapon_ammo,y
    sta ammo,x
equip_ready:
    lda #0
    sta reloading,x
    sta cooldown,x
    rts
begin_reload:
    lda reloading,x
    bne reload_noop
    lda Rule
    cmp #1
    bne reload_stock
    lda ammo,x
    bne reload_noop
    jsr discard_gun
    lda gunlevel,x
    beq gg_floor
    dec gunlevel,x
    jsr gg_equip
    lda #8
    sta cooldown,x
    rts
gg_floor:
    jsr gg_equip
    lda #35
    sta cooldown,x
    rts
reload_stock:
    ldy weapon,x
    lda ammo,x
    bne reload_stock_partial
    cpy #0
    beq reload_begin
    jsr discard_gun
    lda #0
    sta weapon,x
    // Keep the last shot's cooldown when handing over the fresh pistol.
    lda cooldown,x
    pha
    jsr equip_weapon
    pla
    sta cooldown,x
    rts
reload_stock_partial:
    cmp weapon_ammo,y
    bcs reload_noop
reload_begin:
    lda weapon_reload,y
    sta reloading,x
reload_noop:
    rts
reload_step:
    lda reloading,x
    beq reload_noop
    dec reloading,x
    bne reload_noop
    ldy weapon,x
    lda weapon_ammo,y
    sta ammo,x
    rts
gg_equip:
    ldy gunlevel,x
    lda gg_classes,y
    sta weapon,x
    jmp equip_weapon
discard_gun:
    lda FX
    bne !+
    lda #12
    sta FX
    lda xpos,x
    sta FXX
    lda xhigh,x
    sta FXXH
    lda ypos,x
    sec
    sbc #10
    sta FXY
    lda facing,x
    sta FXDir
!:  rts

bullets_step:
    ldx #0
bullet_loop:
    lda blife,x
    bne !+
    jmp bullet_next
!:  dec blife,x
    bne !+
    jmp bullet_next
!:
    lda bx,x
    sta bprevx,x
    lda bxh,x
    sta bprevh,x
    lda bvx,x
    bpl !+
    eor #$ff
    clc
    adc #1
!:  clc
    adc bdistance,x
    bcc !+
    lda #255
!:  sta bdistance,x
    lda bkind,x
    cmp #2
    beq bullet_short_range
    cmp #7
    bne bullet_x_move
bullet_short_range:
    lda bdistance,x
    cmp #80
    bcc bullet_x_move
    jmp bullet_kill
bullet_x_move:
    lda bvx,x
    bmi !+
    lda #0
    beq !++
!:  lda #$ff
!:  sta Tmp
    lda bx,x
    clc
    adc bvx,x
    sta bx,x
    lda bxh,x
    adc Tmp
    sta bxh,x
    bpl !+
    jmp bullet_kill
!:
    cmp #1
    bcc bullet_y_move
    beq bullet_right_edge
    jmp bullet_kill
bullet_right_edge:
    lda bx,x
    cmp #64
    bcc !+
    jmp bullet_kill
bullet_y_move:
!:
    lda bkind,x
    cmp #2
    beq bullet_narrow_spread
    cmp #7
    bne bullet_apply_y
bullet_narrow_spread:
    lda blife,x
    and #1
    bne bullet_test_bounds
bullet_apply_y:
    lda by,x
    clc
    adc bvy,x
    sta by,x
bullet_test_bounds:
    lda by,x
    cmp #24
    bcs !+
    jmp bullet_kill
!:
    cmp #192
    bcc !+
    jmp bullet_kill
!:
    stx Slot
    ldy #0
bullet_test:
    tya
    cmp bowner,x
    beq bullet_test_next
    lda stocks,y
    beq bullet_test_next
    lda shield,y
    ora respawn,y
    bne bullet_test_next
    lda by,x
    sec
    sbc ypos,y
    clc
    adc #21
    cmp #22
    bcs bullet_test_next
    lda bx,x
    sec
    sbc xpos,y
    sta Tmp
    lda bxh,x
    sbc xhigh,y
    sta Tmp2
    lda Tmp
    clc
    adc #9
    sta Tmp
    lda Tmp2
    adc #0
    bne bullet_previous
    lda Tmp
    cmp #18
    bcc bullet_hit
bullet_previous:
    // Swept endpoint test includes overlapping players and fast projectiles.
    lda bprevx,x
    sec
    sbc xpos,y
    sta Tmp
    lda bprevh,x
    sbc xhigh,y
    sta Tmp2
    lda Tmp
    clc
    adc #9
    sta Tmp
    lda Tmp2
    adc #0
    bne bullet_test_next
    lda Tmp
    cmp #18
    bcs bullet_test_next
bullet_hit:
    jsr bullet_impact
    jmp bullet_next
bullet_test_next:
    iny
    cpy Count
    bcc bullet_test
    jmp bullet_next
bullet_kill:
    lda #0
    sta blife,x
bullet_next:
    inx
    cpx #16
    bcs !+
    jmp bullet_loop
!:  rts
bullet_impact:
    lda bkind,x
    cmp #2
    beq impact_shotgun
    cmp #7
    bne impact_force
impact_shotgun:
    lda bdistance,x
    cmp #80
    bcc !+
    lda #0
    sta blife,x
    rts
!:  cmp #40
    bcc impact_force
    lda #12
    sta Tmp
    lda bkind,x
    cmp #7
    bne !+
    lda #7
    sta Tmp
!:  lda Tmp
    sta bpower,x
impact_force:
    lda bowner,x
    sta lastHit,y
    lda bpower,x
    sta Tmp
    lda #0
    sta Tmp2
    lda bvx,x
    bpl !+
    lda Tmp
    eor #$ff
    clc
    adc #1
    sta Tmp
    lda #$ff
    sta Tmp2
!:  lda vx,y
    clc
    adc Tmp
    sta vx,y
    lda vxh,y
    adc Tmp2
    sta vxh,y
    bmi impact_negative
    cmp #1
    bcc impact_ready
    bne impact_cap_right
    lda vx,y
    cmp #64
    bcc impact_ready
impact_cap_right:
    lda #1
    sta vxh,y
    lda #64
    sta vx,y
    bne impact_ready
impact_negative:
    cmp #$fe
    bcc impact_cap_left
    bne impact_ready
    lda vx,y
    cmp #$c0
    bcs impact_ready
impact_cap_left:
    lda #$fe
    sta vxh,y
    lda #$c0
    sta vx,y
impact_ready:
    // Impacts preserve gravity, grounded state and remaining jumps.
    lda #0
    sta blife,x
    lda #4
    sta Sfx
    rts

effects_step:
    lda FX
    beq !+
    dec FX
    lda FXDir
    beq discard_right
    lda FXX
    sec
    sbc #2
    sta FXX
    lda FXXH
    sbc #0
    sta FXXH
    jmp discard_fall
discard_right:
    lda FXX
    clc
    adc #2
    sta FXX
    lda FXXH
    adc #0
    sta FXXH
discard_fall:
    lda FX
    cmp #8
    bcc discard_down
    dec FXY
    dec FXY
    rts
discard_down:
    inc FXY
    inc FXY
!:  rts
crate_step:
    lda Rule
    cmp #1
    bne !+
    rts
!:
    lda CrateOn
    bne crate_fall
    dec CrateTime
    beq !+
    rts
!:  lda #175
    sta CrateTime
    lda #1
    sta CrateOn
    lda Rand
crate_mod:
    cmp NumPlats
    bcc !+
    sec
    sbc NumPlats
    jmp crate_mod
!:  sta CrateGoal
    sta CratePlat
    asl
    asl
    clc
    adc CratePlat
    sta CratePlat
    tay
    lda Platforms,y
    clc
    adc Platforms+2,y
    sta CrateX
    lda Platforms+1,y
    adc Platforms+3,y
    lsr
    sta CrateXH
    ror CrateX
    lda #24
    sta CrateY
    lda Rand
    and #7
    bne !+
    lda #1
!:  sta CrateWeapon
crate_fall:
    ldy CratePlat
    lda CrateY
    cmp Platforms+4,y
    bcs crate_pickup
    clc
    adc #2
    sta CrateY
crate_pickup:
    ldx #0
crate_check:
    lda stocks,x
    beq crate_next
    lda respawn,x
    bne crate_next
    lda ypos,x
    sec
    sbc CrateY
    clc
    adc #10
    cmp #30
    bcs crate_next
    lda xpos,x
    sec
    sbc CrateX
    sta Tmp
    lda xhigh,x
    sbc CrateXH
    sta Tmp2
    lda Tmp
    clc
    adc #12
    sta Tmp
    lda Tmp2
    adc #0
    bne crate_next
    lda Tmp
    cmp #24
    bcs crate_next
    ldy CrateWeapon
    tya
    sta weapon,x
    jsr equip_weapon
    lda #0
    sta CrateOn
    lda #3
    sta Sfx
    rts
crate_next:
    inx
    cpx Count
    bcc crate_check
    rts
