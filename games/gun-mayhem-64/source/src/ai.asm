// A small platform state machine. Routes are computed at build time; a bot
// commits to its landing platform in the air instead of chasing every Y change.
ai_all:
    lda TestInput
    beq !+
    rts
!:  ldx Humans
ai_loop:
    cpx Count
    bcc !+
    rts
!:  jsr ai_player
    jsr ai_tactics
    inx
    jmp ai_loop
ai_player:
    lda #0
    sta input,x
    lda stocks,x
    beq ai_done
    lda respawn,x
    bne ai_done
    lda aiJumpWait,x
    beq !+
    dec aiJumpWait,x
!:  jsr ai_edge_recovery
    bcs ai_done
    lda aiRetarget,x
    beq ai_new_target
    dec aiRetarget,x
    ldy aiTarget,x
    cpy Count
    bcs ai_new_target
    jsr ai_target_safe
    bcs ai_have_target
ai_new_target:
    jsr ai_choose_target
ai_have_target:
    ldy aiTarget,x
    sty Target
    lda support,x
    cpy Count
    bcs !+
    lda support,y
!:
    sta aiDestination
    jsr ai_pack
    jsr ai_bait_destination
    ldy Target
    cpy Count
    bcs !+
    jsr ai_aim
!:
    lda ground,x
    bne ai_on_platform
    jmp ai_air
ai_done:
    rts
ai_on_platform:
    lda support,x
    cmp aiDestination
    bne ai_route
    sta aiGoal,x
    lda #0
    sta aiMode,x
    lda aiPackState,x
    cmp #3
    bne !+
    jmp ai_collect_pack
!:
    ldy Target
    cpy Count
    bcc !+
    // No safe opponent: brake on this platform, but keep pack/bait routes.
    jsr ai_seek_inside
    jmp ai_guard_ledge
!:
    jmp ai_fight
ai_route:
    // Index next-hop[source * platform count + destination], at most 19^2.
    lda #<NavRoutes
    sta Ptr
    lda #>NavRoutes
    sta Ptr+1
    lda support,x
    sta Tmp4
    beq ai_route_index
ai_route_row:
    lda Ptr
    clc
    adc NumPlats
    sta Ptr
    bcc !+
    inc Ptr+1
!:  dec Tmp4
    bne ai_route_row
ai_route_index:
    lda aiDestination
    tay
    lda (Ptr),y
    sta aiGoal,x
    jsr ai_goal_offset
    lda Platforms+4,y
    sta Tmp5
    jsr ai_seek
    lda Tmp5
    cmp ypos,x
    bcc ai_go_up
    beq ai_go_gap
    lda #2
    sta aiMode,x
    lda input,x
    bne ai_down_approach
    lda #2
    sta input,x
    rts
ai_down_approach:
    jsr ai_ahead
    bcs ai_fire
    lda #3
    sta aiMode,x
    jmp ai_launch
ai_go_gap:
    lda #3
    sta aiMode,x
    jmp ai_up_approach
ai_go_up:
    lda #1
    sta aiMode,x
ai_up_approach:
    lda Tmp3
    bne ai_up_edge
    lda Tmp2
    cmp #25
    bcc ai_launch
ai_up_edge:
    jsr ai_ahead
    bcs ai_fire
ai_launch:
    lda aiJumpWait,x
    bne ai_wait_ledge
    lda #20
    sta aiJumpWait,x
    lda input,x
    ora #1
    sta input,x
    jmp ai_fire
ai_wait_ledge:
    jsr ai_guard_ledge
    jmp ai_fire
ai_air:
    jsr ai_goal_offset
    lda Platforms+4,y
    sta Tmp5
    jsr ai_seek
    lda aiMode,x
    cmp #2
    beq ai_fire
    cmp #4
    beq ai_fire
    lda vy,x
    bmi ai_fire
    lda jumps,x
    cmp #1
    bne ai_fire
    lda Tmp3
    bne ai_air_jump
    lda Tmp2
    cmp #13
    bcs ai_air_jump
    lda ypos,x
    sec
    sbc #4
    cmp Tmp5
    bcc ai_fire
ai_air_jump:
    lda input,x
    ora #1
    sta input,x
ai_fire:
    ldy Target
    cpy Count
    bcs ai_fire_done
    lda input,x
    and #2
    bne ai_fire_done
    ldy Target
    lda ypos,x
    sec
    sbc ypos,y
    clc
    adc #16
    cmp #32
    bcs ai_fire_done
    lda weapon,x
    cmp #2
    beq ai_short_fire
    cmp #7
    bne ai_fire_now
ai_short_fire:
    jsr ai_aim
    lda Tmp3
    bne ai_fire_done
    lda Tmp2
    cmp #76
    bcs ai_fire_done
ai_fire_now:
    lda input,x
    ora #16
    sta input,x
ai_fire_done:
    rts

// Decide once per pack: 3/8 ignore it, 4/8 delay, 1/8 pursue immediately.
// Waiting bots keep fighting; a pursuit expires after six seconds.
ai_pack:
    lda Rule
    bne ai_pack_clear
    lda CrateOn
    bne ai_pack_present
ai_pack_clear:
    lda #0
    sta aiPackState,x
    sta aiPackWait,x
    rts
ai_pack_present:
    lda aiPackState,x
    beq ai_pack_notice
    cmp #1
    beq ai_pack_done
    lda aiPackWait,x
    beq ai_pack_timeout
    dec aiPackWait,x
    lda aiPackState,x
    cmp #3
    beq ai_pack_destination
ai_pack_done:
    rts
ai_pack_timeout:
    lda aiPackState,x
    cmp #2
    beq ai_pack_pursue
ai_pack_ignore:
    lda #1
    sta aiPackState,x
    rts
ai_pack_notice:
    lda weapon,x
    cmp CrateWeapon
    bne ai_pack_roll
    ldy weapon,x
    lda ammo,x
    cmp weapon_ammo,y
    bcs ai_pack_ignore
ai_pack_roll:
    jsr random
    and #7
    cmp #3
    bcc ai_pack_ignore
    cmp #7
    beq ai_pack_pursue
    sec
    sbc #2
    sta Tmp
    asl
    clc
    adc Tmp
    asl
    asl
    asl
    sta aiPackWait,x
    lda #2
    sta aiPackState,x
    rts
ai_pack_pursue:
    lda #3
    sta aiPackState,x
    lda #210
    sta aiPackWait,x
ai_pack_destination:
    lda CrateGoal
    sta aiDestination
    rts

// The route reaches the platform; this last approach reaches the pack itself.
ai_collect_pack:
    lda CrateX
    sec
    sbc xpos,x
    sta Tmp2
    lda CrateXH
    sbc xhigh,x
    sta Tmp3
    lda #8
    sta Tmp
    lda Tmp3
    bpl !+
    lda #4
    sta Tmp
    jsr ai_abs_dx
!:
    lda Tmp3
    bne ai_pack_approach
    lda Tmp2
    cmp #6
    bcs ai_pack_approach
    jsr ai_seek_inside
    jmp ai_fire
ai_pack_approach:
    lda Tmp
    sta input,x
    jsr ai_guard_ledge
    jmp ai_fire

ai_fight:
    lda #48
    sta Tmp4
    lda weapon,x
    cmp #2
    beq !+
    cmp #7
    bne !++
!:  lda #28
    sta Tmp4
!:  lda reloading,x
    beq !+
    lda #80
    sta Tmp4
!:  lda #4
    ldy aiAim,x
    beq !+
    lda #8
!:  sta Tmp
    lda Tmp3
    bne ai_fight_approach
    lda Tmp2
    cmp Tmp4
    bcc ai_fight_retreat
    sbc Tmp4
    cmp #28
    bcs ai_fight_approach
    lda #0
    beq ai_fight_move
ai_fight_retreat:
    lda Tmp
    eor #12
    bne ai_fight_move
ai_fight_approach:
    lda Tmp
ai_fight_move:
    sta input,x
    jsr ai_guard_ledge
    jmp ai_fire

// Stop spacing at a ledge. It is not a reason to start another jump.
ai_guard_ledge:
    lda input,x
    sta Tmp6
    lda vx,x
    ora vxh,x
    beq ai_guard_intent
    lda vxh,x
    bmi !+
    lda #8
    bne !++
!:  lda #4
!:  sta input,x
ai_guard_intent:
    lda input,x
    beq ai_guard_done
    jsr ai_ahead
    bcc !+
    lda Tmp6
    sta input,x
    rts
!:
    lda #0
    sta input,x
    lda vx,x
    ora vxh,x
    beq ai_guard_done
    lda vxh,x
    bmi !+
    lda #4
    bne !++
!:  lda #8
!:  sta input,x
ai_guard_done:
    rts
ai_ahead:
    lda xpos,x
    sta WorkX
    lda xhigh,x
    sta WorkXH
    lda input,x
    and #4
    beq ai_ahead_right
    lda WorkX
    sec
    sbc #18
    sta WorkX
    lda WorkXH
    sbc #0
    sta WorkXH
    jmp ai_ahead_test
ai_ahead_right:
    lda WorkX
    clc
    adc #18
    sta WorkX
    lda WorkXH
    adc #0
    sta WorkXH
ai_ahead_test:
    lda support,x
    sta Tmp4
    asl
    asl
    clc
    adc Tmp4
    tay
    jmp within_platform

ai_goal_offset:
    lda aiGoal,x
    sta Tmp4
    asl
    asl
    clc
    adc Tmp4
    tay
    rts
// Y is a platform descriptor. Return movement and unsigned gap to its inset.
ai_seek:
    lda Platforms,y
    clc
    adc #8
    sta WorkX
    lda Platforms+1,y
    adc #0
    sta WorkXH
    lda WorkX
    sec
    sbc xpos,x
    sta Tmp2
    lda WorkXH
    sbc xhigh,x
    sta Tmp3
    bmi ai_seek_max
    ora Tmp2
    beq ai_seek_max
    lda #8
    sta input,x
    rts
ai_seek_max:
    lda Platforms+2,y
    sec
    sbc #9
    sta WorkX
    lda Platforms+3,y
    sbc #0
    sta WorkXH
    lda xpos,x
    sec
    sbc WorkX
    sta Tmp2
    lda xhigh,x
    sbc WorkXH
    sta Tmp3
    bmi ai_seek_inside
    ora Tmp2
    beq ai_seek_inside
    lda #4
    sta input,x
    rts
ai_seek_inside:
    lda #0
    sta input,x
    sta Tmp2
    sta Tmp3
    lda vxh,x
    bmi ai_seek_brake_right
    bne ai_seek_brake_left
    lda vx,x
    cmp #9
    bcc !+
ai_seek_brake_left:
    lda #4
    sta input,x
!:  rts
ai_seek_brake_right:
    cmp #$ff
    bne ai_seek_right_fast
    lda vx,x
    cmp #248
    bcs !+
ai_seek_right_fast:
    lda #8
    sta input,x
!:
    rts

// Aim stays on the opponent while movement can retreat or follow a route.
ai_aim:
    lda xpos,y
    sec
    sbc xpos,x
    sta Tmp2
    lda xhigh,y
    sbc xhigh,x
    sta Tmp3
    lda #1
    sta aiAim,x
    lda Tmp3
    bpl !+
    lda #0
    sta aiAim,x
    jsr ai_abs_dx
!:  rts
ai_abs_dx:
    lda Tmp2
    eor #$ff
    clc
    adc #1
    sta Tmp2
    lda Tmp3
    eor #$ff
    adc #0
    sta Tmp3
    rts

// Like the original's periodic nearest-target choice, without a square root.
ai_choose_target:
    stx SavedX
    lda #255
    sta Tmp5
    sta aiTarget,x
    ldy #0
ai_candidate:
    cpy SavedX
    beq ai_candidate_next
    jsr ai_target_safe
    bcc ai_candidate_next
    jsr ai_aim
    lda Tmp3
    bne ai_candidate_far
    lda ypos,y
    sec
    sbc ypos,x
    bpl !+
    eor #255
    clc
    adc #1
!:  clc
    adc Tmp2
    bcc ai_candidate_score
ai_candidate_far:
    lda #254
ai_candidate_score:
    cmp Tmp5
    bcs ai_candidate_next
    sta Tmp5
    tya
    sta aiTarget,x
ai_candidate_next:
    iny
    cpy Count
    bcc ai_candidate
    lda #40
    sta aiRetarget,x
    rts

// Check cached targets too: a knockback fall must not start a suicide chase.
// Carry is set for a live, on-screen opponent who is grounded or rising.
ai_target_safe:
    lda stocks,y
    beq ai_target_unsafe
    lda respawn,y
    bne ai_target_unsafe
    lda xhigh,y
    bmi ai_target_unsafe
    cmp #1
    bcc !+
    bne ai_target_unsafe
    lda xpos,y
    cmp #64
    bcs ai_target_unsafe
!:
    lda ground,y
    bne ai_target_ready
    lda vy,y
    bpl ai_target_unsafe
ai_target_ready:
    lda ypos,y
    cmp #224
    bcs ai_target_unsafe
    sec
    rts
ai_target_unsafe:
    clc
    rts
