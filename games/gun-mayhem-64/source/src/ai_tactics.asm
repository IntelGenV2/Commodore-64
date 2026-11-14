// Reaction work is staggered: only one bot scans the bullet pool per tick.
ai_tactics:
    lda stocks,x
    beq tactics_wait
    lda respawn,x
    bne tactics_wait
    lda aiDodgeWait,x
    beq !+
    dec aiDodgeWait,x
!:
    jsr ai_idle_check
    lda ground,x
    beq tactics_wait
    lda shield,x
    ora aiDodgeWait,x
    bne tactics_wait
    lda input,x
    and #3
    bne tactics_wait
    txa
    clc
    adc Tick
    and #3
    beq dodge_begin
tactics_wait:
    rts
dodge_begin:
    ldy #15
dodge_scan:
    lda blife,y
    cmp #4
    bcc dodge_next
    txa
    cmp bowner,y
    beq dodge_next
    lda by,y
    sec
    sbc ypos,x
    clc
    adc #21
    cmp #24
    bcs dodge_next
    lda xpos,x
    sec
    sbc bx,y
    sta Tmp2
    lda xhigh,x
    sbc bxh,y
    sta Tmp3
    lda bvx,y
    beq dodge_next
    bpl !+
    jsr ai_abs_dx
!:
    lda Tmp3
    bne dodge_next
    lda Tmp2
    cmp #14
    bcc dodge_next
    cmp #73
    bcs dodge_next
    lda bkind,y
    cmp #2
    beq dodge_range
    cmp #7
    bne dodge_jump
dodge_range:
    lda bdistance,y
    clc
    adc Tmp2
    bcs dodge_next
    cmp #80
    bcs dodge_next
    bcc dodge_jump
dodge_next:
    dey
    bpl dodge_scan
tactics_done:
    rts
dodge_jump:
    lda input,x
    ora #1
    sta input,x
    lda #45
    sta aiDodgeWait,x
    lda #4
    sta aiMode,x
    lda support,x
    sta aiGoal,x
    rts

ai_bait_destination:
    lda aiPackState,x
    cmp #3
    beq bait_cancel
    lda aiBaitTime,x
    beq bait_done
    dec aiBaitTime,x
    lda ground,x
    beq bait_keep
    lda support,x
    cmp aiBaitGoal,x
    beq bait_cancel
bait_keep:
    lda aiBaitGoal,x
    sta aiDestination
bait_done:
    rts
bait_cancel:
    lda #0
    sta aiBaitTime,x
    sta aiIdle,x
    rts

// Small back-and-forth movements still count as holding one firing position.
ai_idle_check:
    lda ground,x
    bne !+
    lda aiMode,x
    cmp #4
    bne idle_reset
!:
    lda aiBaitTime,x
    bne idle_reset
    lda aiPackState,x
    cmp #3
    beq idle_reset
    lda xpos,x
    sec
    sbc aiAnchorX,x
    sta Tmp2
    lda xhigh,x
    sbc aiAnchorH,x
    sta Tmp3
    bpl !+
    jsr ai_abs_dx
!:
    lda Tmp3
    bne idle_reset
    lda Tmp2
    cmp #17
    bcs idle_reset
    lda aiIdle,x
    cmp #200
    bcs !+
    inc aiIdle,x
!:
    txa
    asl
    asl
    asl
    clc
    adc #120
    cmp aiIdle,x
    bcs idle_done
    lda ground,x
    bne idle_relocate
idle_done:
    rts
idle_reset:
    lda #0
    sta aiIdle,x
    lda xpos,x
    sta aiAnchorX,x
    lda xhigh,x
    sta aiAnchorH,x
    rts
idle_relocate:
    jsr idle_reset
    lda NumPlats
    cmp #2
    bcc bait_done
    jsr random
!:
    cmp NumPlats
    bcc !+
    sec
    sbc NumPlats
    jmp !-
!:
    cmp support,x
    bne !++
    clc
    adc #1
    cmp NumPlats
    bcc !+
    lda #0
!: 
!:
    tay
    lda #<NavRoutes
    sta Ptr
    lda #>NavRoutes
    sta Ptr+1
    lda support,x
    sta Tmp4
    beq idle_hop
idle_route_row:
    lda Ptr
    clc
    adc NumPlats
    sta Ptr
    bcc !+
    inc Ptr+1
!:  dec Tmp4
    bne idle_route_row
idle_hop:
    lda (Ptr),y
    sta Tmp5
    sta Tmp
    jsr bait_height
    bcc bait_pick
    beq bait_pick
    // Prefer a jump to a higher/equal tier; descend only at the top of a route.
    lda #0
    sta Tmp6
bait_upward:
    ldy Tmp6
    lda (Ptr),y
    cmp support,x
    beq bait_next
    sta Tmp
    jsr bait_height
    bcc bait_pick
    beq bait_pick
bait_next:
    inc Tmp6
    lda Tmp6
    cmp NumPlats
    bcc bait_upward
    lda Tmp5
    sta Tmp
bait_pick:
    lda Tmp
    sta aiBaitGoal,x
    lda #175
    sta aiBaitTime,x
    rts
bait_height:
    asl
    asl
    clc
    adc Tmp
    tay
    lda Platforms+4,y
    cmp ypos,x
    rts
