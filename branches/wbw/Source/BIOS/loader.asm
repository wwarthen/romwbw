;
;==================================================================================================
;   LOADER
;==================================================================================================
;
; BOOT LOADER
;   CAN BE COMPILED IN DIFFERENT MODES:
;     - LOAD FROM ROM
;     - LOAD FROM IMAGE IN RAM
;     - LOAD FROM COM APPLICATION
;
#INCLUDE "std.asm"
#INCLUDE "hbios.exp"
;
LM_ROM	.EQU	1	; LOAD FROM ROM PAGE
LM_IMG	.EQU	2	; LOAD FROM IMAGE
LM_COM	.EQU	3	; LOAD FROM COM APP
;
P2LOC	.EQU	$F000	; PHASE 2 RUN LOCATION
;
LDRMODE	.EQU	MODE	; DEFINE MODE ON COMMAND LINE
;
#IF (LDRMODE == LM_ROM)
CURBNK	.EQU	BID_BOOT
#ELSE
CURBNK	.EQU	BID_USR
#ENDIF

#IF (LDRMODE == LM_COM)
	.ORG	$100
#ELSE
	.ORG	0
;
;==================================================================================================
; NORMAL PAGE ZERO SETUP, RET/RETI/RETN AS APPROPRIATE
;==================================================================================================
;
	.FILL	(000H - $),0FFH		; RST 0
	JP	START			; JUMP TO BOOT CODE
	.FILL	(004H - $),0FFH		; FILL TO START OF SIG PTR
	.DW	ROM_SIG
	.FILL	(008H - $),0FFH		; RST 8
	RET
	.FILL	(010H - $),0FFH		; RST 10
	RET
	.FILL	(018H - $),0FFH		; RST 18
	RET
	.FILL	(020H - $),0FFH		; RST 20
	RET
	.FILL	(028H - $),0FFH		; RST 28
	RET
	.FILL	(030H - $),0FFH		; RST 30
	RET
	.FILL	(038H - $),0FFH		; INT
	RETI
	.FILL	(066H - $),0FFH		; NMI
	RETN
;
	.FILL	(070H - $),0FFH		; SIG STARTS AT $80
;
ROM_SIG:
	.DB	$76, $B5		; 2 SIGNATURE BYTES
	.DB	1			; STRUCTURE VERSION NUMBER
	.DB	7			; ROM SIZE (IN MULTIPLES OF 4KB, MINUS ONE)
	.DW	NAME			; POINTER TO HUMAN-READABLE ROM NAME
	.DW	AUTH			; POINTER TO AUTHOR INITIALS
	.DW	DESC			; POINTER TO LONGER DESCRIPTION OF ROM
	.DB	0, 0, 0, 0, 0, 0	; RESERVED FOR FUTURE USE; MUST BE ZERO
;
;NAME	.DB	"ROMWBW v", BIOSVER, ", ", BIOSBLD, ", ", TIMESTAMP, 0
NAME	.DB	"ROMWBW v", BIOSVER, ", ", TIMESTAMP, 0
AUTH	.DB	"WBW",0
DESC	.DB	"ROMWBW v", BIOSVER, ", Copyright 2014, Wayne Warthen, GNU GPL v3", 0
;
	.FILL	($100 - $),$FF		; PAD REMAINDER OF PAGE ZERO
#ENDIF
;
;==================================================================================================
;   COLD START
;==================================================================================================
;
START:
	DI			; NO INTERRUPTS
	IM	1		; INTERRUPT MODE 1
	LD	SP,HBX_LOC	; SETUP INITIAL STACK JUST BELOW HBIOS PROXY
;
; HARDWARE BOOTSTRAP FOR Z180
; FOR N8, ACR & RMAP ARE ASSUMED TO BE ALREADY SET OR THIS CODE
; WOULD NOT BE EXECUTING
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	; SET BASE FOR CPU IO REGISTERS
   	LD	A,CPU_BASE
	OUT0	(CPU_ICR),A

	; DISABLE REFRESH
	XOR	A
	OUT0	(CPU_RCR),A

	; SET DEFAULT CPU CLOCK MULTIPLIERS (XTAL / 2)
	XOR	A
	OUT0	(CPU_CCR),A
	OUT0	(CPU_CMR),A

	; SET DEFAULT WAIT STATES
	LD	A,$F0
	OUT0	(CPU_DCNTL),A

	; MMU SETUP
	LD	A,$80
	OUT0	(CPU_CBAR),A		; SETUP FOR 32K/32K BANK CONFIG
#IF (LDRMODE == LM_ROM)
	XOR	A
	OUT0	(CPU_BBR),A		; BANK BASE = 0
#ENDIF
	LD	A,(RAMSIZE + RAMBIAS - 64) >> 2
	OUT0	(CPU_CBR),A		; COMMON BASE = LAST (TOP) BANK

#IF (Z180_CLKDIV >= 1)
	; SET CLOCK DIVIDE TO 1 RESULTING IN FULL XTAL SPEED
	LD	A,$80
	OUT0	(CPU_CCR),A
#ENDIF

#IF (Z180_CLKDIV >= 2)
	; SET CPU MULTIPLIER TO 1 RESULTING IN XTAL * 2 SPEED
	LD	A,$80
	OUT0	(CPU_CMR),A
#ENDIF

	; SET DESIRED WAIT STATES
	LD	A,0 + (Z180_MEMWAIT << 6) | (Z180_IOWAIT << 4)
	OUT0	(CPU_DCNTL),A

#ENDIF
;
; HARDWARE BOOTSTRAP FOR ZETA 2
;
#IF (PLATFORM == PLT_ZETA2)
	; SET PAGING REGISTERS
#IF (LDRMODE == LM_ROM)
	XOR	A
	OUT	(MPGSEL_0),A
	INC	A
	OUT	(MPGSEL_1),A
#ENDIF
	LD	A,62
	OUT	(MPGSEL_2),A
	INC	A
	OUT	(MPGSEL_3),A
	; ENABLE PAGING
	LD	A,1
	OUT	(MPGENA),A
#ENDIF

;
; EMIT FIRST SIGN OF LIFE TO SERIAL PORT
;
	CALL	XIO_INIT	; INIT SERIAL PORT
	LD	HL,STR_BOOT	; POINT TO MESSAGE
	CALL	XIO_OUTS	; SAY HELLO
;
; COPY OURSELVES AND LOADER TO HI RAM FOR PHASE 2
;
	LD	HL,0		; COPY FROM START OF ROM IMAGE
	LD	DE,P2LOC	; TO HIMEM RUN LOCATION
	LD	BC,LDR_END	; COPY FULL IMAGE
	LDIR
;
	CALL	XIO_DOT		; MARK PROGRESS
;
	JP	PHASE2		; JUMP TO PHASE 2 BOOT IN UPPER MEMORY
;
STR_BOOT	.DB	"RomWBW$"
;
; IMBED DIRECT SERIAL I/O ROUTINES
;
#INCLUDE "xio.asm"
;
;______________________________________________________________________________________________________________________
;
; THIS IS THE PHASE 2 CODE THAT MUST EXECUTE IN UPPER MEMORY
;
	.ORG	$ + P2LOC	; WE ARE NOW EXECUTING IN UPPER MEMORY
;
PHASE2:
	CALL	XIO_DOT		; MARK PROGRESS
;
; INSTALL HBIOS PROXY IN UPPER MEMORY
;
#IF (LDRMODE == LM_ROM)
	LD	A,BID_BIOSIMG	; HBIOS IMAGE ROM BANK
	CALL	BNKSEL		; SELECT IT
#ENDIF
	LD	HL,HBX_IMG	; HL := SOURCE OF HBIOS PROXY IMAGE
#IF (LDRMODE != LM_ROM)
	LD	BC,LDR_END	; SIZE OF LOADER
	ADD	HL,BC		; OFFSET SOURCE ADDRESS
#ENDIF
	LD	DE,HBX_LOC	; DE := DESTINATION TO INSTALL IT
	LD	BC,HBX_SIZ	; SIZE
	LDIR			; DO THE COPY
	LD	A,CURBNK	; BOOT/SETUP BANK
	LD	(HB_CURBNK),A	; INIT CURRENT BANK
#IF (LDRMODE == LM_ROM)
	CALL	BNKSEL		; SELECT IT
#ENDIF
	CALL	XIO_DOT		; MARK PROGRESS
;
; INSTALL HBIOS CODE BANK
;
#IF (LDRMODE == LM_ROM)
	LD	A,BID_BIOSIMG	; SOURCE BANK
#ELSE
	LD	A,(HB_CURBNK)	; SOURCE BANK
#ENDIF
	LD	(HB_SRCBNK),A	; SET IT
	LD	A,BID_BIOS	; DESTINATION BANK
	LD	(HB_DSTBNK),A	; SET IT
	LD	HL,0		; SOURCE ADDRESS IS ZERO
#IF (LDRMODE != LM_ROM)
	LD	BC,LDR_END	; SIZE OF LOADER
	ADD	HL,BC		; OFFSET SOURCE ADDRESS
#ENDIF
	LD	DE,0		; TARGET ADDRESS IS ZERO
	LD	BC,HB_END	; COPY ALL OF HBIOS IMAGE
	CALL	HB_BNKCPY	; DO IT
	CALL	XIO_DOT		; MARK PROGRESS
	
	;; HACK TO FLUSH THE OUTPUT FIFO
	;XOR	A
	;CALL	XIO_OUTC
	;CALL	XIO_OUTC
	;CALL	XIO_OUTC
	;CALL	XIO_OUTC
;
; INITIALIZE HBIOS
;
	LD	A,BID_BIOS	; HBIOS BANK
	LD	HL,0		; ADDRESS 0 IS HBIOS INIT ENTRY ADDRESS
	CALL	HB_BNKCALL	; DO IT
	
;
; CHAIN TO OS LOADER
;
#IF (LDRMODE == LM_ROM)
	; PERFORM BANK CALL TO OS IMAGES BANK
	LD	A,BID_OSIMG	; CHAIN TO OS IMAGES BANK
	LD	HL,0		; ENTER AT ADDRESS 0
	CALL	HB_BNKCALL	; GO THERE
	HALT			; WE SHOULD NEVER COME BACK!
#ELSE
	; SLIDE OS IMAGES BLOB DOWN TO $0000
	LD	HL,LDR_END	; SOURCE IS LOADER END
	LD	BC,HB_END	; PLUS HBIOS IMAGE SIZE
	ADD	HL,BC		; FINAL SOURCE ADDRESS
	LD	DE,0		; TARGET ADDRESS IS ZERO
	LD	BC,BNKTOP	; MAX SIZE OF OS IMAGES
	LDIR			; DO IT
	; JUMP TO START
	JP	0		; AND CHAIN
#ENDIF
;
;==================================================================================================
;   MEMORY MANAGER
;==================================================================================================
;
#IF (LDRMODE == LM_ROM)
#INCLUDE "memmgr.asm"
#ENDIF
;
;==================================================================================================
;   CLEAN UP
;==================================================================================================
;
	.ORG	$ - P2LOC	; BANK TO IMAGE-BASED ADDRESSING
LDR_END	.EXPORT	LDR_END		; EXPORT ENDING ADDRESS
	.END
