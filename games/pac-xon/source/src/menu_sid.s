.export _ntsc
.import menu_start,menu_tick,set_audio_clock

.segment "HEADER"
header:
    .byte "PSID",0,2,0,$7c
    .byte >init,<init, >init,<init, >play,<play
    .byte 0,1,0,1,0,0,0,1      ; one tune, clocked by CIA timer A
    .byte "Pac-Xon - Hero Strikes Back!"
    .res 54-(*-header),0
    .byte "Studio 256 / C64 arrangement"
    .res 86-(*-header),0
    .byte "Studio 256, 2026"
    .res 118-(*-header),0
    .byte 0,$3c,0,0,0,0
.bss
_ntsc: .res 1
.segment "ENTRY"
init:
    lda #0
    ldx #24
:   sta $d400,x
    dex
    bpl :-
    lda $02a6
    eor #1
    and #1
    sta _ntsc
    jsr set_audio_clock
    jmp menu_start
play:
    jmp menu_tick
