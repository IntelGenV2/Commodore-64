// KERNAL is banked out. Scan the matrix directly and read both joystick ports.
.macro KeyOr(mask, address, value) {
    lda Tmp
    and #mask
    beq !+
    lda address
    ora #value
    sta address
!:
}
read_input:
    lda #0
    sta $dc02
    sta $dc03
    sta Keys
    sta Actions
    lda #$ff
    sta $dc00
    sta $dc01
    lda $dc00
    eor #$ff
    and #31
    sta input
    lda $dc01
    // Port 1 grounds these same keyboard columns in every selected row.
    // Keep its idle-high mask so joystick presses cannot become phantom keys.
    sta Tmp6
    eor #$ff
    and #31
    sta input+1
    lda #$ff
    sta $dc02
    lda #$fd
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(2,input,1) // W
    :KeyOr(4,input,4) // A
    :KeyOr(32,input,2) // S
    lda #$fb
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(4,input,8) // D
    :KeyOr(2,input,64) // R reload
    :KeyOr(16,Keys,64) // C rules
    lda #$f7
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(64,input+1,64) // U reload
    lda #$ef
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(2,input+1,1) // I
    :KeyOr(4,input+1,4) // J
    :KeyOr(32,input+1,2) // K
    :KeyOr(128,Keys,32) // N opponent count
    :KeyOr(16,Actions,2) // M mute
    lda #$df
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(4,input+1,8) // L
    lda #$fe
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(2,input+1,16) // Return
    :KeyOr(2,Keys,16)
    // F3 uses PB5, beyond all five port 1 joystick lines. P used PB1.
    :KeyOr(32,Keys,128) // F3 pause
    lda State
    bne scan_stop
    // F1/F3/F5/F7 occupy bits 4/5/6/3 of row zero. The main loop
    // edge-detects them along with mute and Run/Stop.
    lda Tmp
    and #$78
    ora Actions
    sta Actions
    lda Tmp
    and #$84            // CRSR up/down and CRSR left/right
    beq scan_stop
    // Shift reverses either cursor. Check both shift keys, applying
    // the same port-1 joystick mask used for all other keyboard reads.
    lda #$fd
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    bmi menu_shift_cursor
    lda #$bf
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    and #16
    bne menu_shift_cursor
    :KeyOr(128,Keys,8)
    :KeyOr(4,Keys,2)
    jmp scan_stop
menu_shift_cursor:
    :KeyOr(128,Keys,4)
    :KeyOr(4,Keys,1)
scan_stop:
    lda #$7f
    sta $dc00
    lda $dc01
    eor #$ff
    and Tmp6
    sta Tmp
    :KeyOr(16,input,16) // Space
    :KeyOr(128,Actions,1) // Run/Stop returns to setup
    lda #$ff
    sta $dc00
    lda TestInput
    beq input_menu
    ldx #3
!:  lda TestJoy,x
    sta input,x
    dex
    bpl !-
input_menu:
    lda input
    sta Tmp
    :KeyOr(4,Keys,1)
    :KeyOr(8,Keys,2)
    :KeyOr(1,Keys,4)
    :KeyOr(2,Keys,8)
    :KeyOr(16,Keys,16)
    rts
