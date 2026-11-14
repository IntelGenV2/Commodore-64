// Positions and horizontal velocity are signed 12.4; vertical velocity is 4.4.
// Simulation is 35 Hz, matching the source SWF on both PAL and NTSC.
player_step:
    lda stocks,x
    bne !+
    rts
!:  lda respawn,x
    beq player_live
    dec respawn,x
    bne !+
    jsr spawn_player
!:  rts
player_live:
    jsr reload_step
    .var timers = List().add(shield,cooldown,drop,flash)
    .for(var t=0;t<timers.size();t++) {
        .var address = timers.get(t)
        lda address,x
        beq !+
        dec address,x
    !:
    }
    lda input,x
    and #12
    cmp #4
    bne move_right
    lda #0
    sta facing,x
    lda vxh,x
    bpl !+
    cmp #$ff
    bne physics_jump
    lda vx,x
    cmp #$92
    bcc physics_jump
!:  lda vx,x
    sec
    sbc #3
    sta vx,x
    lda vxh,x
    sbc #0
    sta vxh,x
    jmp physics_jump
move_right:
    cmp #8
    bne physics_jump
    lda #1
    sta facing,x
    lda vxh,x
    bmi !+
    bne physics_jump
    lda vx,x
    cmp #110
    bcs physics_jump
!:  lda vx,x
    clc
    adc #3
    sta vx,x
    lda vxh,x
    adc #0
    sta vxh,x
physics_jump:
    lda input,x
    and #1
    beq physics_down
    lda prev,x
    and #1
    bne physics_down
    lda jumps,x
    beq physics_down
    cmp #2
    bne !+
    lda #$bf // -65/16 = -4.0625 px
    bne !++
!:  lda #$ca // 83% second jump
!:  sta vy,x
    dec jumps,x
    lda #0
    sta ground,x
    lda #1
    sta Sfx
physics_down:
    lda input,x
    and #2
    beq physics_shoot
    lda prev,x
    and #2
    bne physics_shoot
    lda ground,x
    beq physics_shoot
    lda ypos,x
    cmp LowestY
    bcs physics_shoot
    lda #10
    sta drop,x
    lda #1
    sta jumps,x
    lda #0
    sta ground,x
    jmp physics_shoot
physics_shoot:
    lda input,x
    and #64
    beq !+
    lda prev,x
    and #64
    bne !+
    jsr begin_reload
!:
    lda TestInput
    bne !+
    cpx Humans
    bcc !+
    lda aiAim,x
    sta facing,x
!:
    lda input,x
    and #16
    beq physics_integrate
    jsr shoot
physics_integrate:
    lda input,x
    sta prev,x
    lda ypos,x
    sta oldy,x
    lda vy,x
    bmi !+
    cmp #96
    bcs !++
!:  clc
    adc #4
    sta vy,x
!:
    // Friction on magnitude avoids a negative velocity rounding bias.
    lda vxh,x
    sta Sign
    sta Tmp4
    lda vx,x
    sta Tmp2
    bit Sign
    bpl friction_magnitude
    lda Tmp2
    eor #$ff
    clc
    adc #1
    sta Tmp2
    lda Tmp4
    eor #$ff
    adc #0
    sta Tmp4
friction_magnitude:
    lda Tmp2
    sta Tmp3
    lda Tmp4
    sta Tmp5
    .for(var shift=0;shift<4;shift++) { lsr Tmp5; ror Tmp3 }
    lda Tmp3
    ora Tmp5
    bne friction_drag
    lda Tmp2
    ora Tmp4
    beq friction_sign
    inc Tmp3
friction_drag:
    lda Tmp2
    sec
    sbc Tmp3
    sta Tmp2
    lda Tmp4
    sbc Tmp5
    sta Tmp4
friction_sign:
    bit Sign
    bpl friction_store
    lda Tmp2
    eor #$ff
    clc
    adc #1
    sta Tmp2
    lda Tmp4
    eor #$ff
    adc #0
    sta Tmp4
friction_store:
    lda Tmp2
    sta vx,x
    lda Tmp4
    sta vxh,x
    lda px,x
    clc
    adc vx,x
    sta px,x
    lda pxh,x
    adc vxh,x
    sta pxh,x
    lda vy,x
    sta Sign
    lda #0
    bit Sign
    bpl !+
    lda #$ff
!:  sta Tmp3
    lda py,x
    clc
    adc vy,x
    sta py,x
    lda pyh,x
    adc Tmp3
    sta pyh,x
    jsr pixel_coords
    lda #0
    sta ground,x
    lda pyh,x
    bmi physics_above
    cmp #14 // feet below 224 px
    bcs physics_ko
    lda vy,x
    bmi physics_air
    jsr player_edge
    bne physics_air
    lda oldy,x
    cmp LowestY
    bcc !+
    bne physics_air
!:
    jsr land
physics_air:
    lda ground,x
    bne physics_done
    lda jumps,x
    cmp #2
    bne physics_done
    dec jumps,x
physics_done: rts
physics_above:
    // Permit recovery above the picture, without wrapping into the floor.
    rts
physics_ko:
    jmp knockout
land:
    lda xpos,x
    sta WorkX
    lda xhigh,x
    sta WorkXH
    // A grounded player usually stays on the same support. Try it first.
    lda support,x
    cmp NumPlats
    bcs land_scan
    sta Tmp4
    asl
    asl
    clc
    adc Tmp4
    tay
    lda oldy,x
    cmp Platforms+4,y
    bne land_scan
    lda drop,x
    bne land_scan
    jsr within_platform
    bcc land_scan
    lda NumPlats
    sec
    sbc support,x
    sta Tmp4
    jmp land_contact
land_scan:
    lda NumPlats
    sta Tmp4
    ldy #0
land_loop:
    lda drop,x
    beq !+
    lda NumPlats
    sec
    sbc Tmp4
    cmp support,x
    beq land_next
!:
    lda oldy,x
    cmp Platforms+4,y
    bcc !+
    beq !+
    jmp land_next
!:  lda ypos,x
    cmp Platforms+4,y
    bcc land_next
    jsr within_platform
    bcc land_next
land_contact:
    lda Platforms+4,y
    sta ypos,x
    sta py,x
    lda #0
    sta pyh,x
    sta vy,x
    sta drop,x
    .for(var i=0;i<4;i++) {
        asl py,x
        rol pyh,x
    }
    lda #1
    sta ground,x
    lda NumPlats
    sec
    sbc Tmp4
    sta support,x
    lda #2
    sta jumps,x
    rts
land_next:
    tya
    clc
    adc #5
    tay
    dec Tmp4
    bne land_loop
    rts
knockout:
    lda #6
    sta Sfx
    dec stocks,x
    ldy lastHit,x
    cpy Count
    bcs ko_respawn
    stx Tmp
    cpy Tmp
    beq ko_respawn
    lda score,y
    clc
    adc #1
    sta score,y
    lda Rule
    cmp #1
    bne ko_respawn
    lda gunlevel,y
    clc
    adc #1
    cmp #8
    bcc !+
    sty Winner
    jmp result_setup
!:  sta gunlevel,y
    txa
    pha
    tya
    tax
    jsr gg_equip
    pla
    tax
ko_respawn:
    lda Rule
    cmp #1
    bne !+
    lda #5
    sta stocks,x
!:  lda #35
    sta respawn,x
    lda #$ff
    sta lastHit,x
    lda Rule
    cmp #1
    beq !+
    lda #0
    sta weapon,x
!:  rts
check_winner:
    lda State
    cmp #1
    beq !+
    rts
!:  lda #0
    sta Tmp
    ldx #0
!:  lda stocks,x
    beq !+
    inc Tmp
    stx Winner
!:  inx
    cpx Count
    bcc !--
    lda Tmp
    cmp #2
    bcs !+
    jmp result_setup
!:  rts
