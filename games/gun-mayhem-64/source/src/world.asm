load_map:
    lda Map
    cmp LoadedMap
    beq map_cached
    jsr DiskLoadArena
map_cached:
    lda #<MapBuffer
    sta Src
    lda #>MapBuffer
    sta Src+1
    jsr read_byte
    sta ArenaBG
    sta $d021
    jsr read_byte
    sta $d022
    jsr read_byte
    sta $d023
    jsr read_byte
    sta NumPlats
    ldx #0
!:  jsr read_byte
    sta SpawnList,x
    inx
    cpx #4
    bne !-
    lda NumPlats
    asl
    asl
    clc
    adc NumPlats
    sta Tmp5
    ldx #0
!:  jsr read_byte
    sta Platforms,x
    inx
    cpx Tmp5
    bne !-
    lda #0
    sta LowestY
    ldx #4
map_floor:
    lda Platforms,x
    cmp LowestY
    bcc !+
    sta LowestY
!:  txa
    clc
    adc #5
    tax
    cpx Tmp5
    bcc map_floor
    lda #<NavRoutes
    sta Dst
    lda #>NavRoutes
    sta Dst+1
    lda NumPlats
    sta Tmp5
map_route_row:
    lda NumPlats
    sta Tmp6
map_route_byte:
    jsr read_byte
    sta (Dst),y
    inc Dst
    bne !+
    inc Dst+1
!:  dec Tmp6
    bne map_route_byte
    dec Tmp5
    bne map_route_row
    lda #<SCREEN
    sta Dst
    lda #>SCREEN
    sta Dst+1
    jsr unpack
    lda #<COLOR
    sta Dst
    lda #>COLOR
    sta Dst+1
    jsr unpack
    ldx #0
!:  .for(var p=0;p<4;p++) {
        lda SCREEN+p*256,x
        sta BACK+p*256,x
        lda COLOR+p*256,x
        sta BACKCOLOR+p*256,x
    }
    inx
    bne !-
    rts
read_byte:
    ldy #0
    lda (Src),y
    inc Src
    bne !+
    inc Src+1
!:  rts
unpack:
    jsr read_byte
    cmp #0 // read_byte updates the pointer, so its Z flag is not the byte's Z.
    beq unpack_done
    tax
    jsr read_byte
unpack_run:
    sta (Dst),y
    inc Dst
    bne !+
    inc Dst+1
!:  dex
    bne unpack_run
    jmp unpack
unpack_done: rts
start_match:
    jsr menu_music_stop
    jsr game_video
    lda #0
    sta State
    sta $d015
    sta Accum
    sta CrateOn
    sta FX
    sta Tick
    ldx #0
!:  sta $c100,x
    sta $c200,x
    sta $c300,x
    inx
    bne !-
    jsr load_map
    jsr edge_init
    lda #140
    sta CrateTime
    lda #0
    sta $d025
    lda #1
    sta $d026
    lda #$ff
    sta $d01c
    ldx #0
match_init_player:
    lda Lives
    sta stocks,x
    lda #$ff
    sta lastHit,x
    lda #0
    sta weapon,x
    sta score,x
    sta gunlevel,x
    lda Rule
    cmp #1
    bne !+
    jsr gg_equip
!:
    txa
    and #1
    eor #1
    sta costume,x
    jsr spawn_player
    inx
    cpx Count
    bcc match_init_player
    lda #1
    sta State
    jsr hud_init
    jsr sync_sprites
    jsr draw_hud
    rts
spawn_player:
    lda SpawnList,x
    sta support,x
    sta aiGoal,x
    asl
    asl
    clc
    adc SpawnList,x
    tay
    lda Platforms,y
    clc
    adc Platforms+2,y
    sta Tmp
    lda Platforms+1,y
    adc Platforms+3,y
    lsr
    sta pxh,x
    ror Tmp
    lda Tmp
    sta px,x
    lda Platforms+4,y
    sta py,x
    lda #0
    sta pyh,x
    .for(var i=0;i<4;i++) {
        asl px,x
        rol pxh,x
        asl py,x
        rol pyh,x
    }
    lda #0
    sta vx,x
    sta vxh,x
    sta vy,x
    sta cooldown,x
    sta drop,x
    sta respawn,x
    sta prev,x
    sta aiJumpWait,x
    sta aiMode,x
    sta aiPackState,x
    sta aiPackWait,x
    sta aiDodgeWait,x
    sta aiIdle,x
    sta aiBaitTime,x
    txa
    asl
    asl
    asl
    clc
    adc #1
    sta aiRetarget,x
    lda #1
    sta ground,x
    txa
    and #1
    eor #1
    sta facing,x
    lda #2
    sta jumps,x
    lda #70
    sta shield,x
    lda Rule
    cmp #1
    bne !+
    jsr gg_equip
    jmp spawn_coords
!:
    jsr equip_weapon
spawn_coords:
    jsr pixel_coords
    lda xpos,x
    sta aiAnchorX,x
    lda xhigh,x
    sta aiAnchorH,x
    rts
pixel_coords:
    lda px,x
    sta Tmp
    lda pxh,x
    .for(var i=0;i<4;i++) { cmp #$80; ror; ror Tmp }
    sta xhigh,x
    lda Tmp
    sta xpos,x
    lda py,x
    sta Tmp
    lda pyh,x
    .for(var i=0;i<4;i++) { lsr; ror Tmp }
    lda Tmp
    sta ypos,x
    rts
// WorkX/H and WorkY are pixels. C indicates a platform beneath the feet.
platform_under:
    ldy #0
    lda NumPlats
    sta Tmp4
plat_search:
    lda WorkY
    cmp Platforms+4,y
    bne plat_next
    jsr within_platform
    bcs plat_found
plat_next:
    tya
    clc
    adc #5
    tay
    dec Tmp4
    bne plat_search
    clc
    rts
plat_found: sec
    rts
within_platform:
    lda WorkXH
    cmp Platforms+1,y
    bcc plat_out
    bne !+
    lda WorkX
    cmp Platforms,y
    bcc plat_out
!:  lda WorkXH
    cmp Platforms+3,y
    bcc plat_in
    bne plat_out
    lda WorkX
    cmp Platforms+2,y
    bcs plat_out
plat_in: sec
    rts
plat_out: clc
    rts
