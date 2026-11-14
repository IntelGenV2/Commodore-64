.import _init_track, _play_track, __ZP_START__, __ZP_SIZE__
.importzp c_sp
.export _ntsc

; PSID v2NG, one SID at $d400, PAL and NTSC VBI.
.segment "HEADER"
header:
    .byte "PSID", 0,2, 0,$7c
    .byte >init,<init, >init,<init, >play,<play
.ifdef WORLD_ALBUM
    .byte 0,4, 0,1, 0,0,0,0
    .byte "Loophole - Four Worlds"
.else
    .byte 0,2, 0,1, 0,0,0,0
    .byte "Loophole - Victory"
.endif
    .res 54-(*-header),0
    .byte "Loophole"
    .res 86-(*-header),0
    .byte "2026"
    .res 118-(*-header),0
    .byte 0,$3c, 0,0,0,0

.segment "DATA"
_ntsc:      .byte 0
cadence:    .byte 0
saved_zp:   .res $1a,0
            .res 64,0
stack_top:

.segment "ENTRY"
init:   jmp init_song
play:   jmp play_frame

.code
init_song:
    pha
    lda $02a6
    eor #1
    and #1
    sta _ntsc
    lda #0
    sta cadence
    jsr enter_c
    pla
    jsr _init_track
    jmp leave_c

play_frame:
    lda _ntsc
    beq tick
    inc cadence
    lda cadence
    cmp #6
    bne tick
    lda #0
    sta cadence
    rts
tick:
    jsr enter_c
    jsr _play_track
leave_c:
    ldx #<__ZP_SIZE__-1
restore:
    lda saved_zp,x
    sta __ZP_START__,x
    dex
    bpl restore
    rts

; SID players own their zero page. Borrow the cc65 workspace for the
; duration of each call, and keep the C software stack inside the tune.
enter_c:
    ldx #<__ZP_SIZE__-1
save:
    lda __ZP_START__,x
    sta saved_zp,x
    dex
    bpl save
    lda #<stack_top
    sta c_sp
    lda #>stack_top
    sta c_sp+1
    rts
