; Ghost positions are quarter-pixels. Each ten-byte record matches Ghost in pacxon.h.
.macpack longbranch
.import _ghosts,_count,_board,_pickup,_powers,_px,_py,_mode
.import _move_ghost,_banks,_active_bank,_ready_bank,_multiplex,_clock30,_facing,_flash,_spill
.export _fast_ghosts,_bump_ghosts,_sprite_frame
.importzp ptr1
.bss
off: .res 1
limit: .res 1
nx: .res 2
ny: .res 2
oldrow: .res 1
cx: .res 1
cy: .res 1
pairx: .res 1
pairy: .res 1
index: .res 1
bank: .res 1
sx: .res 2
sy: .res 1
pic: .res 1
ink: .res 1
phase: .res 1
slot: .res 1
which: .res 1
mask: .res 1
.rodata
ends: .byte 0,10,20,30,40,50,60,70,80,90,100,110,120
bits: .byte 1,2,4,8,16,32,64,128
.export _ghost_frame,_ghost_ink
_ghost_frame: .byte 24,26,28,30,60,62
; The same six inks work in hardware sprites and hi-res character cells.
; Drifter, Patroller, Wisp, Crusher, Seeker, Spinner (order of the AI enum).
_ghost_ink:   .byte 1,7,3,2,5,4
shr5: .repeat 256,i
    .byte i/32
.endrepeat
rowlo: .repeat 23,i
    .byte <(_board+83+40*i)
.endrepeat
rowhi: .repeat 23,i
    .byte >(_board+83+40*i)
.endrepeat
.code
.macro cell lo,hi,result
    ldy lo
    lda hi
    asl
    asl
    asl
    ora shr5,y
    sta result
.endmacro
.macro update pos,vel,dst
    lda _ghosts+vel,x
    ldy _powers+6
    beq :+
    cmp #$80
    ror
    bpl :+
    bcc :+
    adc #0                  ; round a negative half-step towards zero
:   clc
    tay                     ; sign of the rounded delta, including -1 / 2 = 0
    adc _ghosts+pos,x
    sta dst
    tya
    bmi :+
    lda #0
    beq :++
:   lda #$ff
:   adc _ghosts+pos+1,x
    sta dst+1
.endmacro
.macro near sourcepos,otherpos,range,faraway
    sec
    lda sourcepos
    sbc otherpos
    tay
    lda sourcepos+1
    sbc otherpos+1
    beq :+
    cmp #$ff
    bne faraway
    cpy #256-range
    bcc faraway
    bcs :++
:   cpy #range
    bcs faraway
:
.endmacro
_fast_ghosts:
    ldy _count
    lda ends,y
    sta limit
    ldx #0
    cpx limit
    jeq done
next:
    stx off
    lda _ghosts+7,x
    bne living
    lda _ghosts+9,x
    cmp #1
    jeq slow
    dec _ghosts+9,x
    jmp advance
living:
    lda _powers
    jne slow
    lda _ghosts+6,x
    cmp #1
    jeq slow
    cmp #4
    jcs slow
    update 0,4,nx
    update 2,5,ny
    cell nx,nx+1,cx
    cell ny,ny+1,cy
    lda cx
    cmp #34
    bcs slow
    lda cy
    cmp #23
    bcs slow
    ldy _ghosts+2,x
    lda _ghosts+3,x
    asl
    asl
    asl
    ora shr5,y
    sta oldrow
    ldy oldrow
    jsr terrain
    bcs slow
    ldy cy
    jsr terrain
    bcs slow
    ; Check pickups at the destination before committing either coordinate.
    clc
    lda ptr1
    adc #<(_pickup-_board)
    sta ptr1
    lda ptr1+1
    adc #>(_pickup-_board)
    sta ptr1+1
    ldy cx
    lda (ptr1),y
    bne slow
    near nx,_px,30,commit
    near ny,_py,30,commit
slow:
    txa
    clc
    adc #<_ghosts
    pha
    lda #>_ghosts
    adc #0
    tax
    pla
    jsr _move_ghost
    lda _mode
    cmp #5
    bne done
    ldx off
    jmp advance
commit:
    lda nx
    sta _ghosts,x
    lda nx+1
    sta _ghosts+1,x
    lda ny
    sta _ghosts+2,x
    lda ny+1
    sta _ghosts+3,x
advance:
    txa
    clc
    adc #10
    tax
    cpx limit
    jcc next
done:rts
terrain:
    lda rowlo,y
    sta ptr1
    lda rowhi,y
    sta ptr1+1
    ldy cx
    lda (ptr1),y
    ldy _ghosts+6,x
    cpy #2
    beq rear
    cmp #1
    rts
rear:
    cmp #1
    beq pass
    cmp #2
    beq pass
    sec
    rts
pass:clc
    rts

; Most pairs reject on their X coordinate in a few dozen cycles.
.macro difference field,dest
    sec
    lda _ghosts+field,x
    sbc _ghosts+field,y
    sta dest
    lda _ghosts+field+1,x
    sbc _ghosts+field+1,y
    beq :+
    cmp #255
    bne reject
    lda dest
    cmp #231
    bcc reject
    bcs :++
:   lda dest
    cmp #26
    bcs reject
:
.endmacro
.macro reflect field,delta
    .local skip,negative,hit,other
    lda delta
    beq skip
    bmi negative
    sec
    lda _ghosts+field,x
    sbc _ghosts+field,y
    bpl skip
    bmi hit
negative:
    sec
    lda _ghosts+field,y
    sbc _ghosts+field,x
    bpl skip
hit:
    lda _ghosts+6,x
    cmp #1
    beq other
    cmp #3
    bne :+
    cmp _ghosts+6,y
    bne other
:   lda #0
    sec
    sbc _ghosts+field,x
    sta _ghosts+field,x
other:
    lda _ghosts+6,y
    cmp #1
    beq skip
    cmp #3
    bne :+
    cmp _ghosts+6,x
    bne skip
:   lda #0
    sec
    sbc _ghosts+field,y
    sta _ghosts+field,y
skip:
.endmacro
_bump_ghosts:
    ldx #0
pair:
    txa
    clc
    adc #10
    tay
    cpy limit
    bcs pair_done
    lda _ghosts+7,x
    beq next_x
test_pair:
    lda _ghosts+7,y
    beq reject
    difference 0,pairx
    difference 2,pairy
    jsr bounce
reject:
    tya
    clc
    adc #10
    tay
    cpy limit
    bcc test_pair
next_x:
    txa
    clc
    adc #10
    tax
    jmp pair
pair_done:rts
bounce:
    reflect 4,pairx
    reflect 5,pairy
    rts

; Keep the displayed bank immutable through both raster interrupts. The
; producer can replace a queued frame without ever writing into a live bank.
.macro position lo,hi,add,dest
    lda hi
    lsr
    lda lo
    ror
    sta dest
    lda hi
    lsr
    lsr
    ror dest
    lda dest
    clc
    adc #add
    sta dest
.endmacro
_sprite_frame:
    lda #0
@free:
    cmp _active_bank
    beq @next
    cmp _ready_bank
    bne @build
@next:
    clc
    adc #69
    bne @free
@build:
    sta bank
    tay
    lda _count
    cmp #8
    lda #0
    rol
    sta _banks+68,y
    lda #0
    sta _banks+32,y
    sta _banks+33,y
    sta _banks+66,y
    sta _banks+67,y
    sta off
    sta index
    sta slot
    lda _clock30
    lsr
    lsr
    and #1
    sta phase
    lda _mode
    cmp #7
    bne player
    lda _flash
    cmp #40
    bcs scan_ghosts
player:
    position _px,_px+1,36,sx
    lda _px+1
    and #4
    adc #0
    sta sx+1
    position _py,_py+1,56,sy
    lda #7
    sta ink
    lda _facing
    asl
    clc
    adc phase
    adc #16
    sta pic
    lda _mode
    cmp #7
    bne :+
    lda _flash
    lsr
    lsr
    cmp #8
    bcc :++
    lda #7
    bne :++
:   jmp player_ready
:   clc
    adc #52
    sta pic
player_ready:
    lda #3
    sta which
    lda #1
    sta mask
    jsr both
scan_ghosts:
    lda index
    cmp _count
    jcs publish
    ldx off
    lda _ghosts+7,x
    jeq next_sprite
    ; Divide a 16-bit coordinate by four without touching the source.
    lda _ghosts+1,x
    lsr
    lda _ghosts,x
    ror
    sta sx
    lda _ghosts+1,x
    lsr
    lsr
    ror sx
    lda sx
    clc
    adc #36
    sta sx
    lda _ghosts+1,x
    and #4
    adc #0
    sta sx+1
    lda _ghosts+3,x
    lsr
    lda _ghosts+2,x
    ror
    sta sy
    lda _ghosts+3,x
    lsr
    lsr
    ror sy
    lda sy
    clc
    adc #56
    sta sy
    ldy bank
    lda _banks+68,y
    beq top_only            ; up to seven ghosts use fixed slots for the whole frame
    lda sy
    cmp #124
    bcc top_only
    cmp #164                ; lower list is installed after the line-145 IRQ
    bcs bottom_only
    lda #3
    sta which
    lda _banks+33,y
    ora _banks+67,y
    jmp slots
top_only:
    lda #1
    sta which
    lda _banks+33,y
    jmp slots
bottom_only:
    lda #2
    sta which
    lda _banks+67,y
slots:
    ldy #1
    lsr
:   lsr
    bcc found
    iny
    cpy #8
    bne :-
    lda index
    jsr _spill
    jmp next_sprite
found:
    sty slot
    lda bits,y
    sta mask
    ldy _ghosts+6,x
    lda _ghost_frame,y
    clc
    adc phase
    sta pic
    lda _ghost_ink,y
    sta ink
    jsr both
next_sprite:
    lda off
    clc
    adc #10
    sta off
    inc index
    jmp scan_ghosts
publish:
    lda bank
    sta _ready_bank
    lda #1
    sta _multiplex
    rts
both:
    lda which
    lsr
    bcc :+
    ldx bank
    jsr put
:   lda which
    and #2
    beq end_put
    lda bank
    clc
    adc #34
    tax
put:
    lda slot
    asl
    sta pos_add+1
    txa
    clc
pos_add: adc #0
    tay
    lda sx
    sta _banks,y
    lda sy
    sta _banks+1,y
    txa
    clc
    adc slot
    tay
    lda pic
    sta _banks+16,y
    lda ink
    sta _banks+24,y
    lda sx+1
    beq :+
    lda mask
    ora _banks+32,x
    sta _banks+32,x
:   lda mask
    ora _banks+33,x
    sta _banks+33,x
end_put:rts
