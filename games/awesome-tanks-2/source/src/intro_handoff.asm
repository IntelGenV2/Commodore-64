// Called by the Studio 256 player after its final frame and SID fade.
resident_stack: .byte 0
resident_exit:
    sei
    lda #0
    sta $d015
    sta $d418
    // The player saved the boot-time system pages at $4000 on entry.
    ldx #0
!:
    .for (var p=1; p<4; p++) {
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
    ldx resident_stack
    txs
    lda #$37
    sta $01
    jsr $ff84                 // IOINIT
    jsr $ff81                 // CINT
    lda #0
    sta $d011
    sta $d020
    sta $d021
    sta $c6
    lda boot_device
    sta $ba
    ldx #0
!:
    lda copier,x
    sta $0400,x
    inx
    bne !-
    jmp $0400

copier:
.pseudopc $0400 {
    lda #$30                  // Read the resident bytes beneath I/O and ROM.
    sta $01
    lda #<$0801
    sta $fd
    lda #>$0801
    sta $fe
    .for (var i=0; i<chunk_starts.size(); i++) {
        lda #<chunk_starts.get(i)
        sta $fb
        lda #>chunk_starts.get(i)
        sta $fc
        ldx #>chunk_sizes.get(i)
        lda #<chunk_sizes.get(i)
        jsr copy_chunk
    }
    lda #$37
    sta $01
    jmp game_entry

copy_chunk:
    sta tail_limit+1
    ldy #0
    cpx #0
    beq tail_limit
copy_page:
    lda ($fb),y
    sta ($fd),y
    iny
    bne copy_page
    inc $fc
    inc $fe
    dex
    bne copy_page
tail_limit:
    cpy #0
    beq advance
    lda ($fb),y
    sta ($fd),y
    iny
    bne tail_limit
advance:
    tya
    clc
    adc $fd
    sta $fd
    bcc !+
    inc $fe
!:  rts
}
.assert "Handoff fits on the boot screen", *-copier<=256, true
.fill 256-(*-copier),0
.assert "Keep the resident game chunk below the SID free", * <= $0d00, true
