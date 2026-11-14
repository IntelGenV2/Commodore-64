// A single LOAD contains both the ident and the game. Move their compressed
// streams under ROM first. A cassette-buffer player survives both expansions.
.import source "layout.asm"
.import source "loading-colors.asm"
.pc = $0801
BasicUpstart2(start)
start:
    sei
    lda #0
    sta $d011
    sta $d020
    sta $d021
    ldx #progressEnd-progress
copyProgress:
    lda progressImage-1,x
    sta progress-1,x
    dex
    bne copyProgress
    ldx #residentEnd-resident
copyPlayer:
    lda image-1,x
    sta resident-1,x
    dex
    bne copyPlayer
    lda #$34
    sta $01
    ldx #pages
    ldy #0
copyPage:
    dey
readPage:  lda streams+(pages-1)*256,y
writePage: sta $fe00,y
    tya
    bne copyPage
    dec readPage+2
    dec writePage+2
    dex
    bne copyPage
    jmp resident
image:
.pseudopc $033c {
resident:
    lda #<introSource
    ldx #>introSource
    jsr expand
    lda #$37
    sta $01
    cli
    jsr $080d
    lda $0cb7
    cmp #7
    beq cancelled
    lda #0
    sta $07be
    lda #3
    sta $dbbe
    sei
    lda #$34
    sta $01
    lda #<gameSource
    ldx #>gameSource
    jsr expand
    lda #$37
    sta $01
    .if (!innerGame) {
        lda #$20
        sta $07be
    }
    cli
    jmp $080d
cancelled:
    rts
// Positive tokens are literal counts. Negative tokens copy a prior run of
// 3..130 bytes using a little-endian distance. Zero terminates the stream.
expand:
    sta $fb
    stx $fc
    lda #1
    sta $fd
    lda #8
    sta $fe
next:
    ldy #0
    jsr getByte
    beq finished
    bmi match
    tax
literal:
    lda ($fb),y
    sta ($fd),y
    iny
    dex
    bne literal
    tya
    clc
    adc $fb
    sta $fb
    bcc advance
    inc $fc
    bne advance
match:
    and #$7f
    clc
    adc #3
    tax
    jsr getByte
    sta $f9
    jsr getByte
    sta $fa
    lda $fd
    sec
    sbc $f9
    sta $f9
    lda $fe
    sbc $fa
    sta $fa
repeat:
    lda ($f9),y
    sta ($fd),y
    iny
    dex
    bne repeat
advance:
    tya
    clc
    adc $fd
    sta $fd
    bcc next
    inc $fe
    // Every 2 KiB of output advances the palette. During the first pass
    // the display is blank. During the second pass only the @ is visible.
    lda $fe
    lsr
    lsr
    lsr
    and #7
    tax
    inc $01                    // Show I/O just for the colour-RAM write.
    lda progressInks,x
    sta $dbbe
    dec $01
    jmp next
getByte:
    lda ($fb),y
    inc $fb
    bne flags
    inc $fc
flags:
    cmp #0
finished:
    rts
residentEnd:
}
.assert "Resident loader fits the cassette buffer", residentEnd <= $0400, true
progressImage:
.pseudopc $02a7 {
progress:
    .if (innerGame) {
        // The larger Tanks image uses its native backwards Exomizer pass.
        // Its source-page hook replaces DEC $011a and preserves flags and X.
        jmp innerProgress
        jmp innerFinished
innerProgress:
        dec $011a
        php
        txa
        pha
        lda $011a
        lsr
        lsr
        and #7
        tax
        lda progressInks,x
        sta $dbbe
        pla
        tax
        plp
        rts
innerFinished:
        lda #$20
        sta $07be
        jmp $080d
    }
progressInks: :loadingPalette()
progressEnd:
}
.assert "Progress code fits below KERNAL vectors", progressEnd <= $0300, true
.align $100
streams:
    .import binary "streams.bin"
.assert "The initial LOAD stays below I/O", * <= $d000, true
