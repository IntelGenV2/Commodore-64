// The game is already in RAM. Restore system state, copy its packed image
// below the intro, and enter its short decruncher without a disk operation.
resident_stack: .byte 0
resident_exit:
    sei
    lda #0
    sta $d015
    sta $d418
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
    ldx resident_stack
    txs
    lda #$37
    sta $01
    jsr $ff84
    // The boot-time RAM vectors were restored above. RESTOR would replace
    // cartridge/KERNAL hooks and can also write beneath the KERNAL ROM.
    jsr $ff81
    lda #0
    sta $d011
    sta $d020
    sta $d021
    sta $c6
    lda boot_device
    sta $ba
    ldx #0
!:
    lda handoff_image,x
    sta $0400,x
    lda handoff_image+$100,x
    sta $0500,x
    inx
    bne !-
    jmp $0400
handoff_image:
.pseudopc $0400 {
    lda #$30
    sta $01
    // build_startup.py emits the free RAM windows and their destinations.
    .for(var i=0;i<resident_from.size();i++) {
        .var from=resident_from.get(i)
        .var to=resident_to.get(i)
        .var size=resident_sizes.get(i)
        lda #<from
        sta relocate_read+1
        lda #>from
        sta relocate_read+2
        lda #<to
        sta relocate_write+1
        lda #>to
        sta relocate_write+2
        lda #<size
        sta relocate_tail+1
        ldx #>size
        ldy #0
        jsr relocate
    }
    lda #0
    sta $fb
    lda #$70
    sta $fc
    lda #1
    sta $fd
    lda #8
    sta $fe
unpack_token:
    ldy #0
    jsr get_byte
    bmi unpack_match
    tax
    inx
unpack_literal:
    lda ($fb),y
    sta ($fd),y
    iny
    dex
    bne unpack_literal
    tya
    clc
    adc $fb
    sta $fb
    bcc advance_output
    inc $fc
    jmp advance_output
unpack_match:
    and #$7f
    clc
    adc #3
    tax
    jsr get_byte
    sta $02
    jsr get_byte
    sta $03
    lda $fd
    sec
    sbc $02
    sta $f9
    lda $fe
    sbc $03
    sta $fa
unpack_match_copy:
    lda ($f9),y
    sta ($fd),y
    iny
    dex
    bne unpack_match_copy
advance_output:
    tya
    clc
    adc $fd
    sta $fd
    bcc !+
    inc $fe
!:
    lda $fe
    cmp #>game_end
    bne unpack_token
    lda $fd
    cmp #<game_end
    bne unpack_token
handoff_ready:
    lda #$37
    sta $01
    jmp $080d
get_byte:
    lda ($fb),y
    inc $fb
    bne !+
    inc $fc
!:
    cmp #0 // Return N/Z for the byte, not the incremented source pointer.
    rts
relocate:
    cpx #0
    bne relocate_read
relocate_tail:
    cpy #0
    beq relocate_done
relocate_read:
    lda $4800,y
relocate_write:
    sta $7000,y
    iny
    bne relocate
    inc relocate_read+2
    inc relocate_write+2
    dex
    jmp relocate
relocate_done:
    rts
handoff_end:
}
.assert "Handoff fits in two pages", handoff_end-$0400<512, true
.fill 512-(*-handoff_image),0
.assert "Keep the packed bank at $0e00-$0fff clear", * <= $0e00, true
