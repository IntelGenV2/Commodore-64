; Three-voice SID music, updated by a raster IRQ independently of game speed.
; The IRQ uses no cc65 zero-page temporaries and preserves all CPU registers.
.export _audio_init, _audio_suspend, _audio_resume, _sound, _silence
.export _music_step, _music_frames, _music_notes, _sfx_ticks, _sfx_kind
.export _flight_sound, _flight_pitch
.export _music_theme
.import _muted, _video_hz, _music_enabled, _sfx_enabled, _phase, _field_mode

.bss
_music_step: .res 1
_music_frames: .res 2
_music_notes: .res 3
_sfx_ticks: .res 1
_sfx_kind: .res 1
_flight_pitch: .res 1
_music_theme: .res 1
tick_left: .res 1
ntsc_divider: .res 1
raster_stage: .res 1

.rodata
.include "../assets/music.inc"
voice_offsets: .byte 0,7,14
voice_wave: .byte $41,$11,$21
voice_ad: .byte $08,$18,$08
voice_sr: .byte $86,$56,$86
effect_length: .byte 14,25,5,64
effect_freq: .byte $2c,$16,$38,$1d
effect_ad: .byte $03,$02,$02,$04
effect_sr: .byte $a4,$a8,$54,$96
effect_wave: .byte $81,$81,$11,$41
winner_notes: .byte 34,37,41,46,41,46,49,46

.code
_audio_init:
 sei
 lda #0
 ldx #24
clear_sid:
 sta $d400,x
 dex
 bpl clear_sid
 sta _music_step
 sta _music_frames
 sta _music_frames+1
 sta _sfx_ticks
 sta _flight_pitch
 sta ntsc_divider
 lda #255
 sta _music_theme
 lda #1
 sta tick_left
 lda #8
 sta $d403
 sta $d40a
 sta $d411
 jmp _audio_resume

; Disk I/O temporarily exposes the KERNAL IRQ vector. Stop our IRQ first.
_audio_suspend:
 sei
 lda #0
 sta $d01a
 sta $d404
 sta $d40b
 sta $d412
 sta $d418
 sta _sfx_ticks
 sta _flight_pitch
 lda #8
 sta $d016
 rts

_audio_resume:
 sei
 lda #$7f
 sta $dc0d
 lda $dc0d
 lda #<music_irq
 sta $fffe
 lda #>music_irq
 sta $ffff
 lda $d011
 and #$7f
 sta $d011
 lda #250
 sta $d012
 lda #2
 sta raster_stage
 lda #1
 sta $d019
 sta $d01a
 sta tick_left
 cli
 rts

; Cancel the current effect. Music continues unless the global mute is set.
_silence:
 php
 sei
 lda #0
 sta _sfx_ticks
 sta $d404
 sta $d40b
 sta $d412
 lda #1
 sta tick_left
 lda _muted
 beq silence_done
 lda #0
 sta $d404
 sta $d40b
 sta $d418
silence_done:
 plp
 rts

; Fastcall argument A: 0 launch, 1 explosion, 2 selection, 3 victory.
; Effects borrow only voice 3; melody and harmony continue uninterrupted.
_sound:
 php
 sei
 tax
 lda _muted
 bne effect_done
 lda _sfx_enabled
 beq effect_done
 cpx #4
 bcs effect_done
 stx _sfx_kind
 lda #0
 sta $d412
 sta $d40e
 cpx #3
 bne start_effect
 sta $d404
 sta $d40b
start_effect:
 lda effect_length,x
 sta _sfx_ticks
 lda effect_freq,x
 sta $d40f
 lda effect_ad,x
 sta $d413
 lda effect_sr,x
 sta $d414
 lda effect_wave,x
 sta $d412
effect_done:
 plp
 rts

; Pitch follows the height of the first airborne projectile. Zero stops it.
_flight_sound:
 ldx _sfx_enabled
 bne flight_enabled
 lda #0
flight_enabled:
 sta _flight_pitch
 rts

music_irq:
 pha
 txa
 pha
 tya
 pha
 cld
 lda #1
 sta $d019
 lda raster_stage
 cmp #2
 beq audio_raster
 cmp #1
 beq field_bottom
 ; Switch in the right border BEFORE the badline. A write on the badline
 ; can be stalled by VIC DMA and turn part of the HUD into a colored bar.
 lda #8
 ldx _field_mode
 beq field_mode_ready
 lda #24
field_mode_ready:
 ldx #106
field_top_wait:
 cpx $d012
 bne field_top_wait
 .repeat 25
 nop
 .endrepeat
 sta $d016
 lda #240
 sta $d012
 inc raster_stage
 jmp irq_done
field_bottom:
 lda #8
 ldx #242
field_bottom_wait:
 cpx $d012
 bne field_bottom_wait
 .repeat 25
 nop
 .endrepeat
 sta $d016
 lda #250
 sta $d012
 inc raster_stage
 jmp irq_done
audio_raster:
 lda #0
 sta raster_stage
 lda #104
 sta $d012
 lda _video_hz
 cmp #60
 bne tick
 inc ntsc_divider
 lda ntsc_divider
 cmp #6
 bne tick
 lda #0
 sta ntsc_divider
 beq irq_done
tick:
 jsr music_tick
irq_done:
 pla
 tay
 pla
 tax
 pla
 rti

music_tick:
 inc _music_frames
 bne frame_counted
 inc _music_frames+1
frame_counted:
 lda _muted
 beq audible
 lda #0
 sta $d404
 sta $d40b
 sta $d412
 sta $d418
 rts
audible:
 ldx #0
 lda _phase
 cmp #2
 beq battle_theme
 cmp #3
 beq battle_theme
 cmp #8
 bne check_theme
battle_theme:
 inx
check_theme:
 cpx _music_theme
 beq theme_ready
 stx _music_theme
 lda #0
 sta _music_step
 sta $d404
 sta $d40b
 lda _sfx_ticks
 ora _flight_pitch
 bne theme_gate
 sta $d412
theme_gate:
 lda #1
 sta tick_left
theme_ready:
 lda #12
 sta $d418
 lda _sfx_enabled
 bne effects_enabled
 lda _sfx_ticks
 ora _flight_pitch
 beq no_pending_effect
 lda #0
 sta _sfx_ticks
 sta _flight_pitch
 sta $d412
no_pending_effect:
 jmp sequencer
effects_enabled:
 lda _sfx_ticks
 beq flight
 dec _sfx_ticks
 bne effect_slide
 lda #0
 sta $d412
 ; Restart the music after an exclusive fanfare, or restore the flight tone.
 lda #1
 sta tick_left
 jmp flight
effect_slide:
 lda _sfx_kind
 cmp #3
 beq fanfare
 cmp #2
 beq sequencer
 lda _sfx_ticks
 asl
 sta $d40f
 lda _sfx_ticks
 asl
 asl
 asl
 sta $d40e
 jmp sequencer
fanfare:
 lda _sfx_ticks
 and #7
 cmp #1
 bne fanfare_note
 lda #0
 sta $d412
 rts
fanfare_note:
 lda #64
 sec
 sbc _sfx_ticks
 lsr
 lsr
 lsr
 tay
 ldx winner_notes,y
 lda _video_hz
 cmp #60
 bcc fanfare_pal
 lda freq_ntsc_lo,x
 sta $d40e
 lda freq_ntsc_hi,x
 jmp fanfare_high
fanfare_pal:
 lda freq_pal_lo,x
 sta $d40e
 lda freq_pal_hi,x
fanfare_high:
 sta $d40f
 lda #$41
 sta $d412
 rts
flight:
 lda _flight_pitch
 beq sequencer
 sta $d40f
 lda _music_frames
 and #3
 asl
 asl
 asl
 asl
 sta $d40e
 lda #$02
 sta $d413
 lda #$68
 sta $d414
 lda #$11
 sta $d412
sequencer:
 lda _music_enabled
 bne music_enabled
 lda #0
 sta $d404
 sta $d40b
 lda _sfx_ticks
 ora _flight_pitch
 bne music_done
 sta $d412
 rts
music_enabled:
 dec tick_left
 beq new_notes
 lda tick_left
 cmp #1
 bne music_done
 ; Release the gates one full frame before retriggering the envelopes.
 lda #0
 sta $d404
 sta $d40b
 lda _sfx_ticks
 ora _flight_pitch
 bne music_done
 sta $d412
music_done:
 rts
new_notes:
 ldy _music_step
 lda _music_theme
 beq menu_notes
 lda #12
 sta tick_left
 lda song_melody,y
 sta _music_notes
 lda song_harmony,y
 sta _music_notes+1
 lda song_bass,y
 sta _music_notes+2
 jmp notes_ready
menu_notes:
 lda #16
 sta tick_left
 lda menu_melody,y
 sta _music_notes
 lda menu_harmony,y
 sta _music_notes+1
 lda menu_bass,y
 sta _music_notes+2
notes_ready:
 inc _music_step
 lda _music_step
 and #127
 sta _music_step
 ldx #0
 jsr play_voice
 ldx #1
 jsr play_voice
 lda _sfx_ticks
 ora _flight_pitch
 bne music_done
 ldx #2
play_voice:
 lda voice_offsets,x
 tay
 lda #0
 sta $d404,y
 lda voice_ad,x
 sta $d405,y
 lda voice_sr,x
 sta $d406,y
 lda _music_notes,x
 beq voice_done
 pha
 lda voice_wave,x
 pha
 ldx _video_hz
 cpx #60
 pla
 sta $d404,y
 pla
 tax
 beq voice_done
 ; Carry from the video-rate comparison selects NTSC (60) versus PAL (50).
 bcc pal_pitch
 lda freq_ntsc_lo,x
 sta $d400,y
 lda freq_ntsc_hi,x
 sta $d401,y
 rts
pal_pitch:
 lda freq_pal_lo,x
 sta $d400,y
 lda freq_pal_hi,x
 sta $d401,y
voice_done:
 rts
