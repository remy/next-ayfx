	DEVICE ZXSPECTRUMNEXT
	ORG $0000

MMU6_C000_NR_56		equ $56
START_OF_FX_BANK	equ $c000
; **************************************************************
; * API
; - 0: set bank id
; - 1: set effect
; **************************************************************

api_entry:
	jr      ayfx_api
	nop

; At $0003 is the entry point for the interrupt handler (which is why there's a
; `nop` above). This is called because bit 7 of the driver id byte has been set
; in the .DRV file.
im1_entry:
; Before we can call the play routine, we need to swap in the bank with
; the sfx, but if we don't have those details from the user code, then
; it'll bork. So I load in the user bank and if it's not been set yet
; I'll bail out early (jr skip)
reloc_ir_1:
	ld 	a,(ayfx_bank)
	add	a
	jr	z, im1_skip
reloc_ir_2:
	call	activate_user_bank
	push	ix 			; the ayfx uses IX, so preseve it
reloc_ir_3:
	call 	AFXFRAME		; this is the original afx play routine
reloc_ir_4:
	call	restore_bank		; put the original bank back into MMU6
	pop	ix			; restore ix back to it's initial state
im1_skip:
	ret

; ***************************************************************************
; * AYFX driver API                                                      *
; ***************************************************************************
; On entry, use B=call id with HL,DE other parameters.
; (NOTE: HL will contain the value that was either provided in HL (when called
;        from dot commands) or IX (when called from a standard program).
;
; When called from the DRIVER command, DE is the first input and HL is the second.
;
; When returning values, the DRIVER command will place the contents of BC into
; the first return variable, then DE and then HL.

ayfx_api:
	djnz	bnot1			; On if B<>1

; **************************************************************
; * B=1 and DE=user bank holding the sound effects,
; **************************************************************

callId1_load_bank:
reloc_c1_1:
	call	backup_bank
	ld	a,e			; user bank is in DE and set in A and as
	add	a,e			; NextBASIC banks are in 16k: double it
reloc_c1_2:
	ld	(ayfx_bank),a		; store it for future use
	nextreg MMU6_C000_NR_56, a 	; load the user's bank in

	; read HL (ignoring H) and uses for the AY chip selection.
	; 0 is default (i.e. not provided) using AY3. Otherwise,
	; 1-3 selects the appropriate chip
	ld	a,l			; read HL as the chip select
	and	3			; used to check zero for default
	jr	nz,c1_save_chip_select
	ld	l,3			; if HL=0 (nothing loaded) we default to AY 3
c1_save_chip_select:
	ld	a,0
	sub	l			; 0 - a = 255 - (0-2) which gives us our AY
reloc_c1_3:
	ld	(ay_chip_select),a	; save the AY chip select

	push	ix			; ix is modified by AFXINIT
reloc_c1_4:
	call 	AFXINIT
	pop	ix
reloc_c1_5:
	call	restore_bank
	and     a                       ; clear carry to indicate success
	ret

bnot1:
	djnz    bnot2                   ; On if B<>2

; **************************************************************
; * B=2 and DE=effect ID - start playing the given effect
; **************************************************************

callId2_set_effect:
reloc_c2_1:
	call 	activate_user_bank
	ld	a,e			; E = effect id
	push	ix
reloc_c2_2:
	call 	AFXPLAY
	pop	ix
reloc_c2_3:
	call	restore_bank
	and     a                       ; clear carry to indicate success
	ret

; Unsupported values of B.

bnot2:
api_error:
	xor	a			; A=0, unsupported call id
	scf				; Fc=1, signals error
	ret


; **************************************************************
; Bank routines:
; - backup_bank - reads the current bank in MMU6 and stores
;   in `active_bank`
; - activate_user_bank - calls backup, then loads the bank ID
;   stored in `ayfx_bank` into MMU 6 (0xC000 onwards)
; - restore_bank - takes the preserved bank in `active_bank`
;   and points MMU 6 _back_ to it.
;
; uses: bc
; **************************************************************
backup_bank:
	push	af			; this really isn't needed
	ld 	bc,$243b 		; select NEXT register
	in	a,(c)			; save register state (https://gitlab.com/thesmog358/tbblue/-/blob/master/demos/esp/espatdrv.asm#L277)
reloc_br_0:
	ld	(saved_reg), a
	ld 	a, MMU6_C000_NR_56	; begin logic for: `a=REG %$56` - ends on ld(active_bank),a
	out 	(c),a
	inc 	b 			; $253b to access (read or write) value
	in 	a,(c)
reloc_br_1:
	ld	(active_bank),a

	dec	b			; now read that nextreg $09 / Peripheral 4
	ld 	a, $09
	out 	(c),a
	inc 	b
	in 	c,(c)			; C now holds the NEXTREG $09 value
reloc_br_2:
	ld	a,(ay_chip_select)	; get the ay chip (0-2) but stored as 255,254,253
	and	a
	jr	z, ay_chip_mono_skip
	dec	a			; change 255 to 254 so B holds 1-3 (not 0-2)
	xor	$ff			; A now holds 0-2 (AY chip)
	ld	b,a
	ld	a,16			; we'll do 32 << a
ay_chip_mono_mask_loop:
	rlca				; rotate instead of shift, as we're shifting a single bit, and this is faster than SLA
	djnz	ay_chip_mono_mask_loop

	or	c			; OR with 128 to set AY2 to mono
	nextreg	$09, a
ay_chip_mono_skip:
	ld 	bc,$243b		; $243B
	ld	a,2
saved_reg equ $-1
	out	(c),a			; just in case IRQ was in between registry work

	pop	af
	ret

activate_user_bank:
reloc_br_3:
	call	backup_bank
reloc_br_4:
	ld	a, (ayfx_bank)
	nextreg	MMU6_C000_NR_56, a
	ret

restore_bank:
reloc_br_5:
	ld	a, (active_bank)
	nextreg MMU6_C000_NR_56, a
	ret

;-Minimal ayFX player v0.15 06.05.06---------------------------;
;                                                              ;
; The simplest player for effects. Plays effects on one AY,    ;
; without music in the background. Channel selection priority: ;
; if available; free channels, one of them is selected. If free;
; no channels, the longest sounding one is selected. Procedure ;
; playback uses registers AF, BC, DE, HL, IX.                  ;
;                                                              ;
; Initialization:                                              ;
;   ld hl, effect bank address                                 ;
;   call AFXINIT                                               ;
;                                                              ;
; Effects playback:                                            ;
;   ld a, effect number (0..255)                               ;
;   call AFXPLAY                                               ;
;                                                              ;
; In the interrupt handler:                                    ;
;   call AFXFRAME                                              ;
;                                                              ;
;--------------------------------------------------------------;



; ------------------------------------------------- -------------;
; Effects player initialization.                                 ;
; Turns off all channels, sets variables.                        ;
; Input: HL = Effects bank address                               ;
; ------------------------------------------------- -------------;

AFXINIT
reloc_in_1:
	ld hl,afxChDesc		        ; mark all channels as empty
	ld de,#00ff
	ld bc,#03fd			; B is used for the loop, C is used as part of the PORT select
afxInit0
	ld (hl),d
	inc hl
	ld (hl),d
	inc hl
	ld (hl),e
	inc hl
	ld (hl),e
	inc hl
	djnz afxInit0

	ld 	hl,#ffbf		; initialise AY
reloc_in_2:
	ld	a,(ay_chip_select)	; select the AY chip the user provided
	ld 	b,h
	out 	(c),a			; remember `out (c)` is actually out (bc)
					; now that the AY chip is selected,
					; future `out` calls use the same chip.
	ld 	e,#15
afxInit1 ; runs 15 times (from E register)
	dec e
	ld b,h
	out (c),e
	ld b,l
	out (c),d
	jr nz,afxInit1
reloc_in_3:
	ld (afxNseMix+1),de             ; reset the player variables
	ret



; --------------------------------------------------------------;
; Play the current frame.                                       ;
; Has no parameters.                                            ;
; --------------------------------------------------------------;

AFXFRAME
	ld 	bc,#fffd
reloc_fm_0:
	ld	a,(ay_chip_select)	; select the AY chip the user provided
	out 	(c),a
	ld 	bc,#03fd
reloc_fm_1:
	ld ix,afxChDesc

afxFrame0
	push bc

	ld a,11
	ld h,(ix+1)			; high byte of address by <11
	cp h
	jr nc,afxFrame7		        ; channel is not playing, skip
	ld l,(ix+0)

	ld e,(hl)			; take the value of the byte
	inc hl

	sub b				; select the volume register:
	ld d,b				; (11-3=8, 11-2=9, 11-1=10)

	ld b,#ff			;load volume value
	out (c),a
	ld b,#bf
	ld a,e
	and #0f
	out (c),a

	bit 5,e				; will there be a tone change?
	jr z,afxFrame1		        ; tone didn't change

	ld a,3				; select the tone registers:
	sub d				; 3-3=0, 3-2=1, 3-1=2
	add a,a				; 0*2=0, 1*2=2, 2*2=4

	ld b,#ff			; load the tone value
	out (c),a
	ld b,#bf
	ld d,(hl)
	inc hl
	out (c),d
	ld b,#ff
	inc a
	out (c),a
	ld b,#bf
	ld d,(hl)
	inc hl
	out (c),d

afxFrame1
	bit 6,e				; will there be a noise change?
	jr z,afxFrame3		        ; noise didn't change

	ld a,(hl)			; read noise word
	cp #20
	jr nz,afxFrame2		        ; less than # 20, play on
	ld h,a				; otherwise end of the effect
	ld b,#ff
	ld b,c				; in BC we enter the longest time
	jr afxFrame6

afxFrame2
	inc hl
reloc_fm_2:
	ld (afxNseMix+1),a	        ; store the noise value

afxFrame3
	pop bc				; restore the loop value to B
	push bc
	inc b				; number of offsets for TN flags

	ld a,%01101111		        ; mask for TN flags
afxFrame4
	rrc e				; move flags and mask
	rrca
	djnz afxFrame4
	ld d,a
reloc_fm_3:
	ld bc,afxNseMix+2	        ; save flag values
	ld a,(bc)
	xor e
	and d
	xor e				;E is masked with D
	ld (bc),a

afxFrame5
	ld c,(ix+2)			; increase the time counter
	ld b,(ix+3)
	inc bc

afxFrame6
	ld (ix+2),c
	ld (ix+3),b

	ld (ix+0),l			; save changed address
	ld (ix+1),h

afxFrame7
	ld bc,4				; go to next channel
	add ix,bc
	pop bc
	djnz afxFrame0

	ld hl,#ffbf			; load noise and mixer values
afxNseMix
	ld de,0				;+1(E)=noise, +2(D)=mixer
	ld a,6
	ld b,h
	out (c),a
	ld b,l
	out (c),e
	inc a
	ld b,h
	out (c),a
	ld b,l
	out (c),d

	ret



; ------------------------------------------------- -------------;
; Triggers the effect on a free channel. Without the most recent ;
; sounding channel is selected.
; Input: A = effect number 0..255;
; ------------------------------------------------- -------------;

AFXPLAY
	ld de,0				; in DE, the longest search time
	ld h,e
	ld l,a
	add hl,hl
afxBnkAdr
	ld bc,START_OF_FX_BANK+1	; this address is set during AFXINIT and points to our sound effects bank -- IMPORTANT, RS had coded this into a known position
	add hl,bc
	ld c,(hl)
	inc hl
	ld b,(hl)
	add hl,bc			; effect address is held in HL
	push hl				; save the address of the effect on the stack
reloc_pl_1:
	ld hl,afxChDesc		        ; find empty channel
	ld b,3
afxPlay0
	inc hl
	inc hl
	ld a,(hl)			; compare the channel time with the longest
	inc hl
	cp e
	jr c,afxPlay1
	ld c,a
	ld a,(hl)
	cp d
	jr c,afxPlay1
	ld e,c				; save the longest time
	ld d,a
	push hl				; save the channel address+3 in IX
	pop ix
afxPlay1
	inc hl
	djnz afxPlay0

	pop de				; pop the effect address from the stack
	ld (ix-3),e			; put into the channel descriptor
	ld (ix-2),d
	ld (ix-1),b			; zero out the seconds
	ld (ix-0),b

	ret

; **************************************************************
; * data
; **************************************************************

; channel descriptors, 4 bytes per channel:
; +0 (2) current address (channel is free if high byte = # 00)
; +2 (2) effect sounding time
; ...

afxChDesc	DS 3*4			; will be populated with 0x0000 0xffff (x 3 via B register)

ayfx_bank:
        defb	0
ay_chip_select:				; 0-2 AY chip
        defb	0

active_bank:
        defb	0


; this ensures the build is 512 long (not 100% sure why though - probably memory baseds)
	IF $ > 512
		DISPLAY "Driver code exceeds 512 bytes"
		shellexec "exit", "1"	; couldn't work out how to error ¯\_(ツ)_/¯
	ELSE
		defs    512-$
	ENDIF

reloc_start:
        defw	reloc_ir_1+2
        defw	reloc_ir_2+2
        defw	reloc_ir_3+2
        defw	reloc_ir_4+2
	defw	reloc_c1_1+2
	defw	reloc_c1_2+2
	defw	reloc_c1_3+2
	defw	reloc_c1_4+2
	defw	reloc_c1_5+2
	defw	reloc_c2_1+2
	defw	reloc_c2_2+2
	defw	reloc_c2_3+2
	defw	reloc_br_0+2
	defw	reloc_br_1+2
	defw	reloc_br_2+2
	defw	reloc_br_3+2
	defw	reloc_br_4+2
	defw	reloc_br_5+2
	defw 	reloc_in_1+2
	defw 	reloc_in_2+2
	; why is `reloc_in_3+3` and not `+2` like all the others? It's because
	; reloc_in_2 points to `ld (afxNseMix+1),de` and the `ld (**),de` opcode
	; is 2 bytes long, and so we have to jump over that amount to track the
	; reference fully (or certainly that's how I understand it).
	defw 	reloc_in_3+3
	defw	reloc_fm_0+2
	defw 	reloc_fm_1+3
	defw 	reloc_fm_2+2
	defw 	reloc_fm_3+2
	defw	reloc_pl_1+2
reloc_end:
