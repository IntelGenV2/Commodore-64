// Black Signal is menu-only. Gameplay retains the existing sound effects.
audio_init:
    lda #0
    sta menu_music_active
audio_clear:
    ldx #24
    lda #0
!:  sta $d400,x
    dex
    bpl !-
    sta audio_fx_time
    sta Sfx
    jmp audio_volume
audio_frame:
    lda menu_music_active
    bne audio_volume
    lda State
    cmp #3
    beq audio_volume
    lda audio_fx_time
    beq audio_decay
    dec audio_fx_time
    bne audio_volume
audio_decay:
    lda #$80
    sta $d412
    jmp audio_volume
audio_tick:
    lda Sfx
    beq audio_tick_done
    tay
    lda #0
    sta $d412
    sta $d413
    lda #$a5
    sta $d414
    lda fx_freq,y
    sta $d40f
    lda fx_wave,y
    sta $d412
    lda #4
    sta audio_fx_time
    lda #0
    sta Sfx
audio_tick_done:
    rts
audio_volume:
    lda menu_music_active
    beq audio_game_volume
    lda AudioOn
    beq audio_menu_muted
    lda #$1f
    bne audio_set_volume
audio_menu_muted:
    lda #$10
    bne audio_set_volume
audio_game_volume:
    lda State
    cmp #3
    beq audio_silent
    lda AudioOn
    beq audio_silent
    lda #15
    bne audio_set_volume
audio_silent:
    lda #0
audio_set_volume:
    sta $d418
    rts
audio_fx_time: .byte 0
fx_freq: .byte 0,$30,$48,$38,$14,$08,$0c,$50
fx_wave: .byte 0,$11,$81,$11,$81,$81,$21,$11

// The supplied player sets CIA1 timer A to 100 Hz and preserves $FB/$FC.
// Timer interrupts are enabled only in menus; raster IRQs remain independent.
menu_music_start:
    php
    sei
    lda #1
    sta $dc0d              // disable timer A while reinitializing
    lda #0
    sta $dc0e
    lda $dc0d
    jsr $a000
    lda #1
    sta menu_music_active
    jsr audio_volume
    lda #$81
    sta $dc0d
    lda #$11
    sta $dc0e
    plp
    rts
menu_music_stop:
    php
    sei
    lda #1
    sta $dc0d
    lda #0
    sta $dc0e
    sta menu_music_active
    lda $dc0d
    jsr $a006
    jsr audio_clear       // remove the menu filter and all lingering voices
    plp
    rts
menu_music_irq:
    lda menu_music_active
    beq menu_music_irq_done
    lda State
    bne menu_music_irq_done
    jsr $a003
menu_music_irq_done:
    rts
menu_music_active: .byte 0
