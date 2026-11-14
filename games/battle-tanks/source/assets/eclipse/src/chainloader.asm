// Runs above the two original boot programs while KERNAL LOAD replaces the intro.
// Preserve the pre-intro BASIC/KERNAL workspace and SYS return stack.
boot_stack: .byte 0
game_exit:
    sei
    lda #0
    sta $d015
    sta $d418
    ldx #0
!:
    lda chain_image,x
    sta $c000,x
    lda chain_image+$100,x
    sta $c100,x
    inx
    bne !-
    lda boot_device
    cmp #8
    bcs !+
    lda #8
!:
    sta chain_device
    lda boot_stack
    sta chain_stack
    jmp chain_start
chain_image:
.pseudopc $c000 {
chain_start:
    ldx #0
!:
    .for(var p=1;p<4;p++) {
        lda $4000+p*256,x
        sta p*256,x
    }
    inx
    bne !-
    ldx #2
!:
    lda $4000,x
    sta $00,x
    inx
    bne !-
    ldx chain_stack
    txs
    lda #$37
    sta $01
    jsr $ff84             // IOINIT: SID, CIA timers and serial bus
    jsr $ff8a             // RESTOR: default KERNAL vectors
    jsr $ff81             // CINT: standard text display and PAL/NTSC timers
    lda #0
    sta $d020
    sta $d021
    sta $c6
    jsr $ff90             // suppress KERNAL search/loading messages
    ldx #0
!:
    lda chain_caption,x
    sta $0400+12*40+6,x
    lda #3
    sta $d800+12*40+6,x
    inx
    cpx #28
    bne !-
    cli
chain_load:
    lda #game_file.size()
    ldx #<chain_name
    ldy #>chain_name
    jsr $ffbd
    lda #1
    ldx chain_device
    ldy #1
    jsr $ffba
    lda #0
    jsr $ffd5
    bcs chain_error
    // Keep BASIC's end-of-program pointers consistent for the game's runtime.
    stx $2d
    sty $2e
    stx $2f
    sty $30
    stx $31
    sty $32
chain_loaded:
    jmp game_entry
chain_error:
    ldx #0
!:
    lda chain_error_caption,x
    sta $0400+15*40+6,x
    lda #10
    sta $d800+15*40+6,x
    inx
    cpx #28
    bne !-
!:
    jsr $ffe4
    cmp #32
    bne !-
    jmp chain_load
chain_device: .byte 8
chain_stack: .byte 0
.encoding "ascii"
chain_name: .text game_file
.encoding "screencode_upper"
chain_caption: .text game_caption
chain_error_caption: .text "LOAD ERROR - SPACE TO RETRY  "
chain_end:
.assert "Loader must fit in two pages", chain_end<$c200, true
}
.fill 512-(*-chain_image),0
