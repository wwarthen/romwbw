; Adapted from https://rosettacode.org/wiki/Mandelbrot_set#Z80_Assembly
; by Phillip Summers difficultylevelhigh@gmail.com
;
; WBWROM Easteregg
;
;  Compute a Mandelbrot set on a simple Z80 computer.
;
; Porting this program to another Z80 platform should be easy and straight-
; forward: The only dependencies on my homebrew machine are the system-calls 
; used to print strings and characters. These calls are performed by loading
; IX with the number of the system-call and performing an RST 08. To port this
; program to another operating system just replace these system-calls with 
; the appropriate versions. Only three system-calls are used in the following:
; _crlf: Prints a CR/LF, _puts: Prints a 0-terminated string (the adress of 
; which is expected in HL), and _putc: Print a single character which is 
; expected in A. RST 0 give control back to the monitor.
;
#include        "std.asm"

cr				.equ	0dh
lf				.equ	0ah
eos				.equ	00h
 
                .org     EGG_LOC
 
scale           .equ     256                     ; Do NOT change this - the 
                                                ; arithmetic routines rely on
                                                ; this scaling factor! :-)
divergent       .equ     scale * 4
 
				ld		sp,HBX_LOC
				ld      hl, welcome             ; Print a welcome message
				call	_puts
 
; for (y = <initial_value> ; y <= y_end; y += y_step)
; {
outer_loop      ld      hl, (y_end)             ; Is y <= y_end?
                ld      de, (y)
                and     a                       ; Clear carry
                sbc     hl, de                  ; Perform the comparison
                jp      m, mandel_end           ; End of outer loop reached
 
;    for (x = x_start; x <= x_end; x += x_step)
;    {
                ld      hl, (x_start)           ; x = x_start
                ld      (x), hl
inner_loop      ld      hl, (x_end)             ; Is x <= x_end?
                ld      de, (x)
                and     a
                sbc     hl, de
                jp      m, inner_loop_end       ; End of inner loop reached
 
;      z_0 = z_1 = 0;
                ld      hl, 0
                ld      (z_0), hl
                ld      (z_1), hl
 
;      for (iteration = iteration_max; iteration; iteration--)
;      {
                ld      a, (iteration_max)
                ld      b, a
iteration_loop  push    bc                      ; iteration -> stack
;        z2 = (z_0 * z_0 - z_1 * z_1) / SCALE;
                ld      de, (z_1)               ; Compute DE HL = z_1 * z_1
				ld		b,d
				ld		c,e

				call    mul_16
                ld      (z_0_square_low), hl    ; z_0 ** 2 is needed later again
                ld      (z_0_square_high), de
 
                ld      de, (z_0)               ; Compute DE HL = z_0 * z_0
				ld		b,d
				ld		c,e

                call    mul_16
                ld      (z_1_square_low), hl    ; z_1 ** 2 will be also needed
                ld      (z_1_square_high), de
 
                and     a                       ; Compute subtraction
                ld      bc, (z_0_square_low)
                sbc     hl, bc
                ld      (scratch_0), hl         ; Save lower 16 bit of result
				ld		h,d
				ld		l,e
                ld      bc, (z_0_square_high)
                sbc     hl, bc
                ld      bc, (scratch_0)         ; HL BC = z_0 ** 2 - z_1 ** 2
 
                ld      c, b                    ; Divide by scale = 256
                ld      b, l                    ; Discard the rest
                push    bc                      ; We need BC later
 
;        z3 = 2 * z0 * z1 / SCALE;
                ld      hl, (z_0)               ; Compute DE HL = 2 * z_0 * z_1
                add     hl, hl
				ld		d,h
				ld		e,l
                ld      bc, (z_1)
                call    mul_16
 
                ld      b, e                    ; Divide by scale (= 256)
                ld      c, h                    ; BC contains now z_3
 
;        z1 = z3 + y;
                ld      hl, (y)
                add     hl, bc
                ld      (z_1), hl
 
;        z_0 = z_2 + x;
                pop     bc                      ; Here BC is needed again :-)
                ld      hl, (x)
                add     hl, bc
                ld      (z_0), hl
 
;        if (z0 * z0 / SCALE + z1 * z1 / SCALE > 4 * SCALE)
                ld      hl, (z_0_square_low)    ; Use the squares computed
                ld      de, (z_1_square_low)    ; above
                add     hl, de
              
				ld		b,h						; BC contains lower word of sum
				ld		c,l
 
                ld      hl, (z_0_square_high)
                ld      de, (z_1_square_high)
                adc     hl, de
 
                ld      h, l                    ; HL now contains (z_0 ** 2 + 
                ld      l, b                    ; z_1 ** 2) / scale
 
                ld      bc, divergent
                and     a
                sbc     hl, bc
 
;          break;
                jp      c, iteration_dec        ; No break
                pop     bc                      ; Get latest iteration counter
                jr      iteration_end           ; Exit loop
 
;        iteration++;
iteration_dec   pop     bc                      ; Get iteration counter
                djnz    iteration_loop          ; We might fall through!
;      }
iteration_end
;      printf("%c", display[iteration % 7]);
                ld      a, b
                and     $7                      ; lower three bits only (c = 0)
                sbc     hl, hl
                ld      l, a
                ld      de, display             ; Get start of character array
                add     hl, de                  ; address and load the 
                ld      a, (hl)                 ; character to be printed
				call	_putc      		        ; Print the character	
 
                ld      de, (x_step)            ; x += x_step
                ld      hl, (x)
                add     hl, de
                ld      (x), hl
 
                jp      inner_loop
;    }
;    printf("\n");
inner_loop_end	call	_putcrlf               	; Print a CR/LF pair
 
                ld      de, (y_step)            ; y += y_step
                ld      hl, (y)
                add     hl, de
                ld      (y), hl                 ; Store new y-value
 
                jp      outer_loop
; }
 
mandel_end      ld      hl, finished            ; Print finished-message
				call	_puts
												; GET CONSOLE INPUT STATUS VIA HBIOS
waitch
#IF (BIOS == BIOS_WBW)
		LD	C,CIO_CONSOLE		; CONSOLE UNIT TO C
		LD	B,BF_CIOIN		; HBIOS FUNC: INPUT CHAR
		RST	08			; DO IT
		
		;; RETURN TO THE LOADER
		;LD	A,BID_BOOT		; BOOT BANK
		;LD	HL,0			; ADDRESS ZERO
		;CALL	HB_BNKCALL		; DOES NOT RETURN
		
		LD	B,BF_SYSRESET		; SYSTEM RESTART
		LD	C,BF_SYSRES_WARM	; WARM START
		CALL	$FFF0			; CALL HBIOS
		
		HALT
#ENDIF
#IF (BIOS == BIOS_UNA)
		LD	B,0			; CONSOLE UNIT TO B
		LD	C,BF_CIOIN		; UBIOS FUNC: INPUT CHAR
		CALL	$FFFD			; DO IT
		
		; RETURN TO THE LOADER
		LD	BC,$01FB		; UNA FUNC = SET BANK
		LD	DE,0			; ROM BANK 0
		CALL	$FFFD			; DO IT
		JP	0			; JUMP TO RESTART ADDRESS
#ENDIF
				
_putcrlf		ld		hl, crlf
_puts			push	af
puts0			ld		a,(hl)
				cp		eos
				jr		z,puts1
				call	_putc
				inc		hl
				jr		puts0
puts1			pop		af
				ret			

_putc
#IF (BIOS == BIOS_WBW)
		PUSH	AF
		PUSH	BC
		PUSH	DE
		PUSH	HL
		LD	E,A			; OUTPUT CHAR TO E
		LD	C,CIO_CONSOLE		; CONSOLE UNIT TO C
		LD	B,BF_CIOOUT		; HBIOS FUNC: OUTPUT CHAR
		RST	08			; HBIOS OUTPUTS CHARACTDR
		POP	HL
		POP	DE
		POP	BC
		POP	AF
		RET
#ENDIF
#IF (BIOS == BIOS_UNA)
		PUSH	AF
		PUSH	BC
		PUSH	DE
		PUSH	HL
		LD	E,A			; OUTPUT CHAR TO E
		LD	B,0			; CONSOLE UNIT TO B
		LD	C,BF_CIOOUT		; UBIOS FUNC: OUTPUT CHAR
		CALL	$FFFD			; UBIOS OUTPUTS CHARACTDR
		POP	HL
		POP	DE
		POP	BC
		POP	AF
		RET
#ENDIF


welcome         .db    "Generating a Mandelbrot set..."
                .db    cr, lf, cr, lf, eos
finished        .db    "Computation finished."
crlf			.db	cr, lf, eos
 
iteration_max   .db    10                      ; How many iterations
x               .dw    0                       ; x-coordinate
x_start         .dw    -2 * scale              ; Minimum x-coordinate
x_end           .dw    5 *  scale / 10         ; Maximum x-coordinate
x_step          .dw    4  * scale / 100        ; x-coordinate step-width
y               .dw    -1 * scale              ; Minimum y-coordinate
y_end           .dw    1  * scale              ; Maximum y-coordinate
y_step          .dw    1  * scale / 10         ; y-coordinate step-width
z_0             .dw    0	;0
z_1             .dw    0	;0
scratch_0       .dw    0
z_0_square_high .dw    0
z_0_square_low  .dw    0
z_1_square_high .dw    0
z_1_square_low  .dw    0
display         .db    " .-+*=#@"              ; 8 characters for the display
 
;
;   Compute DEHL = BC * DE (signed): This routine is not too clever but it 
; works. It is based on a standard 16-by-16 multiplication routine for unsigned
; integers. At the beginning the sign of the result is determined based on the
; signs of the operands which are negated if necessary. Then the unsigned
; multiplication takes place, followed by negating the result if necessary.
;
mul_16          xor     a                       ; Clear carry and A (-> +)
                bit     7, b                    ; Is BC negative?
                jr      z, bc_positive          ; No
                sub     c                       ; A is still zero, complement
                ld      c, a
                ld      a, 0
                sbc     a, b
                ld      b, a
                scf                             ; Set carry (-> -)
bc_positive     bit     7, D                    ; Is DE negative?
                jr      z, de_positive          ; No
                push    af                      ; Remember carry for later!
                xor     a
                sub     e
                ld      e, a
                ld      a, 0
                sbc     a, d
                ld      d, a
                pop     af                      ; Restore carry for complement
                ccf                             ; Complement Carry (-> +/-?)
de_positive     push    af                      ; Remember state of carry
                and     a                       ; Start multiplication
                sbc     hl, hl
                ld      a, 16                   ; 16 rounds
mul_16_loop     add     hl, hl
                rl      e
                rl      d
                jr      nc, mul_16_exit
                add     hl, bc
                jr      nc, mul_16_exit
                inc     de
mul_16_exit     dec     a
                jr      nz, mul_16_loop
                pop     af                      ; Restore carry from beginning
                ret     nc                      ; No sign inversion necessary
                xor     a                       ; Complement DE HL
                sub     l
                ld      l, a
                ld      a, 0
                sbc     a, h
                ld      h, a
                ld      a, 0
                sbc     a, e
                ld      e, a
                ld      a, 0
                sbc     a, d
                ld      d, a
				ret
				
lastbyte		.equ	$
				
SLACK			.EQU	(EGG_END - lastbyte)
				.FILL	SLACK,'e'
;
				.ECHO	"EASTEREGG space remaining: "
				.ECHO	SLACK
				.ECHO	" bytes.\n"
				
				.end
				