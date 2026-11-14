; Original Studio 256 score player. 50 Hz, no zero-page or cc65 scratch use.
; Voice 1: game SFX only. Voice 2: fading melody. Voice 3: continuous drone.
.export _audio_reset,_audio_tick,_music_mode,_audio_mix,_sfx
.export _audio_pos,_audio_tempo,_audio_drum,_audio_priority,_audio_delay
.import _video_hz,_music_menu,_music_lengths
.import _freq_pal_lo,_freq_pal_hi,_freq_ntsc_lo,_freq_ntsc_hi
.bss
_music_mode: .res 1
_audio_mix: .res 1      ; bit 0 silences music, bit 1 silences game effects
_sfx: .res 1
audio_state_start:
audio_prev: .res 1
_audio_pos: .res 2
audio_end: .res 2
audio_base: .res 2
_audio_tempo: .res 1
audio_voice: .res 1
audio_note: .res 2
_audio_delay: .res 2
audio_wave: .res 2
audio_frame: .res 1
audio_volume: .res 1
audio_drone_note: .res 1
audio_drone_active: .res 1
audio_drone_delay: .res 1
audio_fade_timer: .res 1
_audio_drum: .res 1
audio_drum_step: .res 1
audio_drum_delay: .res 1
_audio_priority: .res 1
audio_state_end:
.rodata
audio_regs: .byte 0,7
; Five percussion sounds and three game cues. All stop explicitly.
drum_lengths: .byte 8,6,2,9,10,7,6,12
drum_adsr: .byte $04,$03,$01,$05,$06,$03,$04,$06
drum_waves:
 .byte $11,$11,$11,$11,$11,$11,$10,$10,0,0,0,0
 .byte $11,$81,$81,$81,$80,$80,0,0,0,0,0,0
 .byte $81,$80,0,0,0,0,0,0,0,0,0,0
 .byte $11,$11,$11,$11,$11,$11,$11,$10,$10,0,0,0
 .byte $41,$41,$40,$40,$40,$40,$40,$40,$40,$40,0,0
 .byte $11,$11,$11,$11,$10,$10,$10,0,0,0,0,0
 .byte $41,$41,$41,$40,$40,$40,0,0,0,0,0,0
 .byte $11,$11,$11,$11,$11,$11,$11,$11,$10,$10,$10,$10
drum_notes:
 .byte 62,50,43,38,34,31,31,31,0,0,0,0
 .byte 55,72,69,64,60,55,0,0,0,0,0,0
 .byte 82,78,0,0,0,0,0,0,0,0,0,0
 .byte 50,48,46,44,43,41,40,39,38,0,0,0
 .byte 75,74,74,74,74,74,74,74,74,74,0,0
 .byte 49,43,39,36,34,33,32,0,0,0,0,0
 .byte 69,74,76,76,76,76,0,0,0,0,0,0
 .byte 50,50,50,57,57,57,62,62,62,62,62,62
drum_offsets: .byte 0,12,24,36,48,60,72,84
.code
_audio_reset:
 lda #0
 sta _music_mode
 sta _audio_mix
 sta _sfx
 ldx #audio_state_end-audio_state_start-1
audio_clear_state:
 sta audio_state_start,x
 dex
 bpl audio_clear_state
 ldx #24
audio_clear_sid:
 sta $d400,x
 dex
 bpl audio_clear_sid
 lda #255
 sta audio_prev
 rts
_audio_tick:
 lda _music_mode
 cmp audio_prev
 bne audio_change_mode
 jmp audio_same_mode
audio_change_mode:
 sta audio_prev
 lda #0
 sta _audio_pos
 sta _audio_pos+1
 sta _audio_delay
 sta _audio_delay+1
 sta audio_wave
 sta audio_wave+1
 sta $d404
 sta $d40b
 sta $d412
 sta $d406
 sta $d40d
 sta $d414
 sta _audio_drum
 sta _audio_priority
 sta audio_drum_delay
 sta audio_volume
 sta audio_frame
 sta audio_drone_active
 sta audio_drone_delay
 sta audio_fade_timer
 lda #26
 sta audio_drone_note
 lda #218
 sta _audio_tempo
 lda #<_music_menu
 sta audio_base
 lda #>_music_menu
 sta audio_base+1
 lda _music_lengths
 sta audio_end
 lda _music_lengths+1
 sta audio_end+1
 lda #0
 sta $d415
 lda #10
 sta $d416
 lda #$46
 sta $d417
audio_same_mode:
 inc audio_frame
 lda audio_frame
 and #3
 bne audio_master
 lda audio_volume
 cmp #15
 bcs audio_master
 inc audio_volume
audio_master:
 lda _audio_mix
 cmp #3
 beq audio_silenced
 lda _music_mode
 beq audio_silenced
 lda audio_volume
 ldx _music_mode
 cpx #2
 bne audio_vol_ready
 cmp #10
 bcc audio_vol_ready
 lda #10
audio_vol_ready:
 ; Voices 2/3 are routed through the low-pass filter ($d417 = $46).
 ; Disconnect its output for effects-only playback. Both oscillators and
 ; their envelopes keep running. Unfiltered voice 1 remains audible.
 ldx _audio_mix
 cpx #1
 beq audio_set_volume
 ora #$10
audio_set_volume:
 sta $d418
 jmp audio_clock
audio_silenced:
 lda #$10
 sta $d418
audio_clock:
 lda _music_mode
 cmp #1
 beq audio_clock_on
 jmp audio_effect
audio_clock_on:
 clc
 lda _audio_tempo
 adc #32
 bcs audio_new_row
 cmp #250
 bcs audio_new_row
 sta _audio_tempo
 jmp audio_envelopes
audio_new_row:
 sec
 sbc #250
 sta _audio_tempo
 clc
 lda audio_base
 adc _audio_pos
 sta audio_read+1
 lda audio_base+1
 adc _audio_pos+1
 sta audio_read+2
 lda #0
 sta audio_voice
audio_next_voice:
 ldx audio_voice
audio_read:
 lda $ffff,x
 cmp #255
 beq audio_event_done
 cpx #2
 beq audio_drum_event
 cpx #0
 bne audio_melody_event
 cmp #0
 beq audio_event_done
 sta audio_drone_note
 jmp audio_event_done
audio_melody_event:
 sta audio_note,x
 ldy audio_regs,x
 cmp #0
 beq audio_release
audio_prepare_note:
 ; Drop gate and sustain for TWO complete frames before a fresh attack.
 lda #0
 sta $d405,y
 sta $d406,y
 lda audio_wave,x
 and #$fe
 sta $d404,y
 lda #3
 sta _audio_delay,x
 bne audio_event_done
audio_release:
 sta audio_fade_timer
 sta _audio_delay,x
 lda audio_wave,x
 and #$fe
 sta $d404,y
 jmp audio_event_done
audio_drum_event:
 ldx _audio_priority
 bne audio_event_done
 cmp #96
 bcc audio_event_done
 cmp #101
 bcs audio_event_done
 sec
 sbc #95
 jsr audio_start_drum
audio_event_done:
 inc audio_voice
 lda audio_voice
 cmp #3
 bne audio_next_voice
 clc
 lda _audio_pos
 adc #3
 sta _audio_pos
 bcc audio_position
 inc _audio_pos+1
audio_position:
 lda _audio_pos
 cmp audio_end
 bne audio_envelopes
 lda _audio_pos+1
 cmp audio_end+1
 bne audio_envelopes
 lda #0
 sta _audio_pos
 sta _audio_pos+1
audio_envelopes:
 ldx #1
 lda _audio_delay+1
 beq audio_fade_tick
 dec _audio_delay+1
 bne audio_fade_tick
 ldy #7
 ldx audio_note+1
 jsr audio_frequency
audio_lead:
 ; Cap the attack at two 50 Hz ticks, then
 ; release to zero. A held score note never sits on a sustain plateau.
 ; The faster attack scales the brief tone alongside the stronger drone.
 lda #$59
 sta $d40c
 lda #$0a
 sta $d40d
 lda #$80
 sta $d409
 lda #6
 sta $d40a
 lda #$41
 sta audio_wave+1
 sta $d40b
 lda #3
 sta audio_fade_timer
audio_fade_tick:
 lda audio_fade_timer
 beq audio_music_done
 dec audio_fade_timer
 bne audio_music_done
 lda #$40
 sta $d40b
audio_music_done:
 jsr audio_drone_tick
audio_effect:
 lda _audio_mix
 and #2
 beq audio_accept_effect
 lda #0
 sta _sfx
 jmp audio_drum_stop
audio_accept_effect:
 lda _sfx
 beq audio_drum_tick
 cmp #4
 bcs audio_bad_sfx
 clc
 adc #5
 jsr audio_start_drum
 lda #1
 sta _audio_priority
audio_bad_sfx:
 lda #0
 sta _sfx
audio_drum_tick:
 lda _audio_drum
 bne audio_have_drum
 rts
audio_have_drum:
 lda audio_drum_delay
 beq audio_drum_play
 dec audio_drum_delay
 bne audio_return
 ldx _audio_drum
 dex
 lda drum_adsr,x
 sta $d405
 lda #0
 sta $d406
 sta $d402
 lda #4
 sta $d403
audio_drum_play:
 ldx _audio_drum
 dex
 lda audio_drum_step
 cmp drum_lengths,x
 bcs audio_drum_stop
 clc
 adc drum_offsets,x
 tax
 lda drum_waves,x
 sta $d404
 lda drum_notes,x
 tax
 ldy #0
 jsr audio_frequency
 inc audio_drum_step
audio_return:
 rts
audio_drum_stop:
 lda #0
 sta _audio_drum
 sta _audio_priority
 sta $d404
 rts
audio_start_drum:
 sta _audio_drum
 lda #0
 sta audio_drum_step
 sta $d404
 sta $d405
 sta $d406
 lda #3
 sta audio_drum_delay
 rts
; X=MIDI note, Y=voice offset. Does not touch application scratch.
audio_frequency:
 lda _video_hz
 cmp #60
 beq audio_frequency_ntsc
 lda _freq_pal_lo,x
 sta $d400,y
 lda _freq_pal_hi,x
 sta $d401,y
 rts
audio_frequency_ntsc:
 lda _freq_ntsc_lo,x
 sta $d400,y
 lda _freq_ntsc_hi,x
 sta $d401,y
 rts

audio_drone_tick:
 lda _music_mode
 beq audio_drone_return
 lda audio_drone_active
 bne audio_drone_wait
 lda #0
 sta $d412
 sta $d413
 sta $d414
 lda #3
 sta audio_drone_delay
 lda #1
 sta audio_drone_active
audio_drone_wait:
 lda audio_drone_delay
 beq audio_drone_pitch
 dec audio_drone_delay
 bne audio_drone_return
 lda #$79
 sta $d413
 lda #$a8
 sta $d414
 lda #$46
 sta $d417
 lda #$21
 sta $d412
audio_drone_pitch:
 ldx audio_drone_note
 ldy #14
 jsr audio_frequency
audio_drone_return:
 rts
