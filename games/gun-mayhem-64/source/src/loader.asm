// Resident KERNAL disk loader. Only the selected compressed arena stays in RAM.
.encoding "ascii"
*=$0801 "Disk bootstrap"
.byte $0b,$08,$0a,$00,$9e,$32,$30,$36,$31,$00,$00,$00
    sei
    lda #$36
    sta $01
    ldx #0
!:
    .for(var p=0;p<16;p++) {
        lda loader_image+p*256,x
        sta $9000+p*256,x
    }
    inx
    bne !-
    jmp $9000
loader_image:
.pseudopc $9000 {
    jmp disk_boot
    jmp disk_arena
    jmp disk_read

disk_boot:
    lda $ba
    cmp #8
    bcc !+
    sta disk_device
!:
    jsr disk_setup
    ldx #0
disk_boot_next:
    stx disk_stage
    lda boot_name_lo,x
    sta disk_name
    lda boot_name_hi,x
    sta disk_name+1
    lda boot_name_len,x
    sta disk_length
    jsr disk_caption
    jsr disk_retry
    ldx disk_stage
    inx
    cpx #4
    bcc disk_boot_next
    lda #0
    sta $d015
    jmp $080d

disk_arena:
    php
    pla
    sta disk_status
    sei
    lda $01
    sta disk_bank
    ldx #2
!:
    lda $00,x
    sta disk_zp,x
    inx
    bne !-
    lda $08
    clc
    adc #1
    ldx #48
!:
    cmp #10
    bcc !+
    sec
    sbc #10
    inx
    jmp !-
!:
    stx arena_name+5
    clc
    adc #48
    sta arena_name+6
    jsr disk_setup
    lda #4
    sta disk_stage
    lda #<arena_name
    sta disk_name
    lda #>arena_name
    sta disk_name+1
    lda #7
    sta disk_length
    jsr disk_caption
    jsr disk_retry
    sei
    ldx #2
!:
    lda disk_zp,x
    sta $00,x
    inx
    bne !-
    lda $08
    sta $c011
    lda #0
    sta $d015
    sta $d017
    sta $d01d
    lda disk_bank
    sta $01
    lda #250
    sta $d012
    sta $3b               // RasterLine: match the resumed game's IRQ schedule
    lda #1
    sta $d019
    sta $d01a
    lda $02
    sta $03
    lda disk_status
    pha
    plp
    clc
    rts

disk_read:
    inc disk_reads
    lda #0
    jsr $ff90
    lda disk_length
    ldx disk_name
    ldy disk_name+1
    jsr $ffbd
    lda #1
    ldx disk_device
    ldy #1
    jsr $ffba
    lda #0
    cli
    jsr $ffd5
    sei
    sta disk_error
    rts
disk_retry:
    jsr disk_read
    bcc disk_success
    ldx #0
!:
    lda error_text,x
    sta $0400+19*40+6,x
    lda #10
    sta $d800+19*40+6,x
    inx
    cpx #28
    bcc !-
disk_error_wait:
    lda #0
    sta $dc02
    sta $dc03
    lda $dc00
    and #16
    beq disk_retry_ready
    lda $dc01
    and #16
    beq disk_retry_ready
    lda #$ff
    sta $dc02
    lda #$7f
    sta $dc00
    lda $dc01
    and #16
    bne disk_error_wait
disk_retry_ready:
    lda #$ff
    sta $dc00
    jsr disk_caption
    jmp disk_retry
disk_success:
    rts

disk_setup:
    sei
    lda #$36
    sta $01
    lda #0
    sta $d01a
    sta $d015
    sta $d020
    sta $d021
    sta $d418
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #1
    sta $d019
    lda $dd00
    ora #3
    sta $dd00
    lda #$1b
    sta $d011
    lda #$08
    sta $d016
    lda #$18
    sta $d018
    ldx #0
!:
    .for(var p=0;p<8;p++) {
        lda loader_font+p*256,x
        sta $2000+p*256,x
    }
    lda #32
    .for(var p=0;p<4;p++) { sta $0400+p*250,x }
    lda #1
    .for(var p=0;p<4;p++) { sta $d800+p*250,x }
    inx
    cpx #250
    bne !-
    // The last six font bytes in each page were outside the screen clear loop.
    ldx #250
!:
    .for(var p=0;p<8;p++) {
        lda loader_font+p*256,x
        sta $2000+p*256,x
    }
    inx
    bne !-
    ldx #0
!:
    lda loading_title,x
    sta $0400+3*40+9,x
    cmp #32
    beq !+
    clc
    adc #1
!:
    sta $0400+4*40+9,x
    lda #7
    sta $d800+4*40+9,x
    inx
    cpx #22
    bne !--
    ldx #0
!:
    lda subtitle,x
    sta $0400+7*40+10,x
    lda #3
    sta $d800+7*40+10,x
    inx
    cpx #20
    bcc !-
    ldx #0
!:
    lda #61
    sta $0400+15*40+6,x
    lda #3
    sta $d800+15*40+6,x
    inx
    cpx #28
    bcc !-
    ldx #63
!:
    lda loader_right,x
    sta $2f00,x
    lda loader_left,x
    sta $2f40,x
    dex
    bpl !-
    lda #188
    sta $07f8
    lda #189
    sta $07f9
    lda #88
    sta $d000
    lda #248
    sta $d002
    lda #128
    sta $d001
    sta $d003
    lda #0
    sta $d010
    sta $d01b
    sta $d025
    lda #1
    sta $d026
    lda #10
    sta $d027
    lda #13
    sta $d028
    lda #3
    sta $d017
    sta $d01d
    sta $d01c
    sta $d015
    rts
disk_caption:
    ldx disk_stage
    lda caption_lo,x
    sta disk_caption_fetch+1
    lda caption_hi,x
    sta disk_caption_fetch+2
    lda progress,x
    sta disk_progress
    ldx #0
!:
disk_caption_fetch:
    lda $ffff,x
    sta $0400+18*40+6,x
    lda #32
    sta $0400+19*40+6,x
    sta $0400+20*40+6,x
    lda #1
    sta $d800+18*40+6,x
    sta $d800+19*40+6,x
    lda #174
    sta $0400+22*40+6,x
    lda #11
    cpx disk_progress
    bcs !+
    lda #3
!:
    sta $d800+22*40+6,x
    inx
    cpx #28
    bcc !--
    lda disk_name
    sta disk_file_fetch+1
    lda disk_name+1
    sta disk_file_fetch+2
    ldx #0
!:
disk_file_fetch:
    lda $ffff,x
    sta $0400+20*40+6,x
    inx
    cpx disk_length
    bcc !-
    rts

disk_device: .byte 8
disk_reads: .byte 0
disk_stage: .byte 0
disk_length: .byte 0
disk_name: .word 0
disk_error: .byte 0
disk_bank: .byte $35
disk_status: .byte 0
disk_progress: .byte 0
boot_name_lo: .byte <logic_name,<art_name,<engine_name,<music_name
boot_name_hi: .byte >logic_name,>art_name,>engine_name,>music_name
boot_name_len: .byte 5,3,6,5
logic_name: .text "LOGIC"
art_name: .text "ART"
engine_name: .text "ENGINE"
music_name: .text "MUSIC"
arena_name: .text "ARENA01"
caption_lo: .byte <logic_caption,<art_caption,<engine_caption,<music_caption,<arena_caption
caption_hi: .byte >logic_caption,>art_caption,>engine_caption,>music_caption,>arena_caption
progress: .byte 0,7,14,21,0
logic_caption: .text "LOADING GAME LOGIC          "
art_caption: .text "LOADING SPRITES AND TILES   "
engine_caption: .text "LOADING MATCH ENGINE        "
music_caption: .text "LOADING BLACK SIGNAL        "
arena_caption: .text "LOADING ARENA               "
error_text: .text "DISK ERROR - FIRE TO RETRY  "
subtitle: .text "COMMODORE 64 EDITION "
loading_title: .byte 96,32,98,32,100,32,32,32,102,32,104,32,106,32,108,32,110,32,102,32,112,114
loader_font:
    .import binary "../assets/port/charset.bin"
loader_left:
    .import binary "../assets/port/sprites.bin",0,64
loader_right:
    .import binary "../assets/port/sprites.bin",384,64
.assert "Loader UI and code leave zero-page backup free", * <= $9f00, true
.fill $9f00-*,0
disk_zp: .fill 256,0
}
loader_image_end:
