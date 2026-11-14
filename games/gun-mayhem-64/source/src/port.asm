// Gun Mayhem 64: character-mode arenas and a multicolor bitmap cover.
.encoding "ascii"
.const MAP_COUNT=21
.const SCREEN=$0400
.const COLOR=$d800
.const HUD=SCREEN+40
.const HUDCOLOR=COLOR+40
.const CHARSET=$2000
.const SPRITES=$2800
.const BACK=$e000
.const BACKCOLOR=$e400
.const px=$c100
.const pxh=$c104
.const py=$c108
.const pyh=$c10c
.const vx=$c110
.const vy=$c114
.const facing=$c118
.const ground=$c11c
.const jumps=$c120
.const stocks=$c124
.const weapon=$c128
.const ammo=$c12c
.const cooldown=$c130
.const shield=$c134
.const respawn=$c138
.const prev=$c13c
.const drop=$c140
.const input=$c148
.const xpos=$c14c
.const xhigh=$c150
.const ypos=$c154
.const oldy=$c158
.const flash=$c15c
.const score=$c160
.const lastHit=$c164
.const costume=$c168
.const aiAim=$c16c
.const gunlevel=$c170
.const reloading=$c174
.const edgeRow=$c178
.const edgeSide=$c17c
.const edgeCacheSide=$c180
.const edgeDistance=$c184
.const edgeDistanceH=$c188
.const edgeDigits=$c18c
.const edgeHundreds=$c190
.const edgeTens=$c194
.const edgeOnes=$c198
.const support=$c19c
.const aiGoal=$c1a0
.const aiTarget=$c1a4
.const aiRetarget=$c1a8
.const aiJumpWait=$c1ac
.const aiMode=$c1b0
.const aiPackState=$c1b4
.const aiPackWait=$c1b8
.const aiDodgeWait=$c1bc
.const aiIdle=$c1c0
.const aiAnchorX=$c1c4
.const aiAnchorH=$c1c8
.const aiBaitGoal=$c1cc
.const aiBaitTime=$c1d0
.const vxh=$c1d4
.const hudWeapon=$c1d8
.const hudAmmo=$c1dc
.const hudReload=$c1e0
.const hudStocks=$c1e4
.const hudLevel=$c1e8
.const HudState=$c012
.const EdgeMaxRow=$c013
.const CLIPPED_SPRITES=$0c00
.const clipPose=$c040
.const clipTop=$c048
.const clipBottom=$c050
.const EDGE_SPRITES=$2f00
.const EDGE_CHAR=183
.const EDGE_LEFT_CHAR=116
.const EDGE_RIGHT_CHAR=117
.const SpriteMulti=$36
.const bx=$c200
.const bxh=$c210
.const by=$c220
.const bvx=$c230
.const bvy=$c240
.const blife=$c250
.const bowner=$c260
.const bpower=$c270
.const bold=$c280
.const boldh=$c290
.const bprevx=$c2b0
.const bprevh=$c2c0
.const bdistance=$c2d0
.const bkind=$c2e0
.const Frame=$02
.const LastFrame=$03
.const Rate=$04
.const Accum=$05
.const Tick=$06
.const State=$07
.const Map=$08
.const Lives=$09
.const Count=$0a
.const Humans=$0b
.const Rule=$0c
.const Keys=$0e
.const OldKeys=$0f
.const Edge=$10
.const Rand=$11
.const NumPlats=$12
.const Winner=$13
.const CrateTime=$14
.const CrateOn=$15
.const CratePlat=$16
.const CrateWeapon=$17
.const CrateX=$18
.const CrateXH=$19
.const CrateY=$1a
.const FX=$1b
.const FXX=$1c
.const FXXH=$1d
.const FXY=$1e
.const Sfx=$1f
.const Ptr=$20
.const Src=$22
.const Dst=$24
.const Tmp=$26
.const Tmp2=$27
.const Tmp3=$28
.const Tmp4=$29
.const Tmp5=$2a
.const Tmp6=$2b
.const SavedX=$2c
.const Slot=$2d
.const Pellets=$2e
.const Target=$2f
.const WorkX=$30
.const WorkXH=$31
.const WorkY=$32
.const Sign=$33
.const SpriteMask=$34
.const SpriteHigh=$35
.const AudioOn=$38
.const Busy=$39
.const Overruns=$3a
.const RasterLine=$3b
.const TestInput=$c000
.const TestJoy=$c001
.const Actions=$c006
.const OldActions=$c007
.const MenuChoice=$c008
.const MenuPage=$c009
.const HomeChoice=$c014
.const ActionEdge=$c015
.const PAGE_TITLE=0
.const PAGE_CONTROLS=1
.const PAGE_LADDER=2
.const PAGE_SETUP=3
.const ArenaBG=$c00a
.const FXDir=$c00d
.const LowestY=$c00e
.const aiDestination=$c00f
.const CrateGoal=$c010
.const LoadedMap=$c011
.const MapBuffer=$5000
.const DiskLoadArena=$9003
.const SpawnList=$c410
.const Platforms=$c420
.const NavRoutes=$c500

*=$0801 "BASIC loader"
.byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
*=$080d "Boot"
    sei
    lda $02a6
    beq !+
    lda #50
    bne !++
!:  lda #60
!:  sta Rate
    lda #$35
    sta $01
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    lda $dd00
    ora #3
    sta $dd00
    lda #$1b
    sta $d011
    lda #$18
    sta $d016
    sta $d018
    lda #0
    sta $d020
    sta $d015
    sta $d017
    sta $d01b
    sta $d01d
    ldx #0
!:  sta $c000,x
    sta $c100,x
    sta $c200,x
    sta $c300,x
    inx
    bne !-
    ldx #$3a
boot_zp:
    cpx #4
    beq !+
    sta $00,x
!:  dex
    cpx #1
    bne boot_zp
    lda #$ad
    sta Rand
    lda #255
    sta LoadedMap
    lda #3
    sta Lives
    lda #2
    sta Count
    lda #1
    sta Humans
    sta AudioOn
    sta $d01a
    lda #250
    sta $d012
    sta RasterLine
    lda #$ff
    sta $d019
    jsr audio_init
    jsr menu_setup
    cli
    jmp main
nmi: rti
irq:
    pha
    lda $dc0d
    and #1
    beq irq_check_vic
    txa
    pha
    tya
    pha
    jsr menu_music_irq
    pla
    tay
    pla
    tax
irq_check_vic:
    lda $d019
    and #1
    bne irq_raster
    pla
    rti
irq_raster:
    // A CIA music tick can finish after the exact raster match line.
    // Dispatch using the scheduled line so a late IRQ cannot lose its cadence.
    lda RasterLine
    cmp #145
    beq irq_bottom
    cmp #74
    beq irq_arena
    cmp #226
    beq irq_bottom
    inc Frame
    lda $d011
    and #$20                // Only the illustrated title uses bitmap mode.
    beq irq_game_frame
    lda #145                // Blank gap between the cover and hires menu.
    sta $d012
    sta RasterLine
    lda #$18
    sta $d016
    jmp irq_ack
irq_game_frame:
    lda #74
    sta $d012
    sta RasterLine
    jmp irq_text
irq_bottom:
    lda #250
    sta $d012
    sta RasterLine
irq_text:
    // Switch in the next line's left border, not halfway through a glyph.
    lda $d012
!:  cmp $d012
    beq !-
    lda #$08
    sta $d016
    jmp irq_ack
irq_arena:
    lda Count
    cmp #3
    bcc !+
    lda #226
    bne irq_schedule
!:  lda #250
irq_schedule:
    sta $d012
    sta RasterLine
    lda State
    and #1
    beq irq_text
    lda $d012
!:  cmp $d012
    beq !-
    lda #$18
    sta $d016
irq_ack:
    lda #1
    sta $d019
    pla
    rti

*=$0a00 "HUD sprite clipping"
#import "sprite_clip.asm"
.assert "Clipping leaves eight scratch sprites", * <= CLIPPED_SPRITES, true
*=$1000 "Off-screen recovery indicators"
#import "offscreen.asm"
#import "ai.asm"
#import "ai_tactics.asm"
#import "hud.asm"
logic_end:
.assert "Indicators fit below character set", * <= $2000, true
*=$2000 "VIC character set"
.import binary "../assets/port/charset.bin"
*=$2800 "Animated hardware sprites"
.import binary "../assets/port/sprites.bin"
.assert "Sprites leave four indicator frames free", * <= EDGE_SPRITES, true
*=$3000 "Game engine"
main:
    lda Frame
    cmp LastFrame
    beq main
    sta LastFrame
    jsr audio_frame
    jsr read_input
    lda Actions
    eor OldActions
    and Actions
    sta ActionEdge
    lda Actions
    sta OldActions
    lda ActionEdge
    and #2
    beq !+
    lda AudioOn
    eor #1
    sta AudioOn
    jsr audio_volume
!:  lda ActionEdge
    and #1
    beq !+
    lda State
    bne leave_match
    lda MenuPage
    beq !+
    jsr title_draw
    jmp main
leave_match:
    jsr menu_setup
    jmp main
!:
    lda Keys
    eor OldKeys
    and Keys
    sta Edge
    lda Keys
    sta OldKeys
    lda State
    bne !+
    jsr menu_update
    jmp main
!:  cmp #2
    bne !+
    jsr result_update
    jmp main
!:  lda Edge
    and #$80
    beq !+
    lda State
    eor #2
    sta State
    jsr draw_hud
    jsr audio_volume
!:  lda State
    cmp #3
    bne !+
    jmp main
!:
    lda Accum
    clc
    adc #35
    cmp Rate
    bcc no_tick
    sec
    sbc Rate
    sta Accum
    jsr game_tick
    jmp main
no_tick:
    sta Accum
    jmp main
game_tick:
    inc Tick
    jsr random
    jsr erase_bullets
    jsr ai_all
    ldx #0
!:  jsr player_step
    lda State
    cmp #1
    bne game_tick_done
    inx
    cpx Count
    bcc !-
    jsr bullets_step
    jsr effects_step
    jsr crate_step
    jsr sync_sprites
    jsr draw_bullets
    jsr draw_hud
    jsr audio_tick
    jsr check_winner
    lda Frame
    cmp LastFrame
    beq !+
    inc Overruns
!:
game_tick_done:
    rts
random:
    lda Rand
    asl
    bcc !+
    eor #$1d
!:  sta Rand
    rts
#import "input.asm"
#import "world.asm"
#import "physics.asm"
#import "combat.asm"
#import "display.asm"
#import "audio.asm"
#import "../assets/port/tables.asm"
engine_end:
.print "Engine end: " + toHexString(*)
.assert "Engine fits below map data", * <= $5000, true
*=$a000 "Black Signal menu music"
.import binary "../build/menu-theme/black-a000.bin"
title_cover: .import binary "../assets/port/title-cover.bin"
title_ink: .import binary "../assets/port/title-ink.bin"
title_color: .import binary "../assets/port/title-color.bin"
menu_assets_end:
.assert "Menu music and title art fit below game state", * <= $c000, true
