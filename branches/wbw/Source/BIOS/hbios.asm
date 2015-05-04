;
;==================================================================================================
;   HBIOS
;==================================================================================================
;
; INCLUDE GENERIC STUFF
;
#INCLUDE "std.asm"
;
	.ORG	0
;
;==================================================================================================
; NORMAL PAGE ZERO SETUP, RET/RETI/RETN AS APPROPRIATE
;==================================================================================================
;
	.FILL	(000H - $),0FFH		; RST 0
	JP	HB_START
	.DW	ROM_SIG
	.FILL	(008H - $),0FFH		; RST 8
	JP	HB_DISPATCH
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
ROM_SIG:
	.DB	$76, $B5		; 2 SIGNATURE BYTES
	.DB	1			; STRUCTURE VERSION NUMBER
	.DB	7			; ROM SIZE (IN MULTIPLES OF 4KB, MINUS ONE)
	.DW	NAME			; POINTER TO HUMAN-READABLE ROM NAME
	.DW	AUTH			; POINTER TO AUTHOR INITIALS
	.DW	DESC			; POINTER TO LONGER DESCRIPTION OF ROM
	.DB	0, 0, 0, 0, 0, 0	; RESERVED FOR FUTURE USE; MUST BE ZERO
;
NAME	.DB	"ROMWBW v", BIOSVER, ", ", TIMESTAMP, 0
AUTH	.DB	"WBW",0
DESC	.DB	"ROMWBW v", BIOSVER, ", Copyright 2015, Wayne Warthen, GNU GPL v3", 0
;
	.FILL	($100 - $),$FF		; PAD REMAINDER OF PAGE ZERO
;
HCB	.FILL	$100,$FF		; RESERVED FOR HBIOS CONTROL BLOCK
;
;==================================================================================================
;   HBIOS UPPER MEMORY PROXY
;==================================================================================================
;
; THE FOLLOWING CODE IS RELOCATED TO THE TOP OF MEMORY TO HANDLE INVOCATION DISPATCHING
; AFTER RELOCATION THIS AREA (1K) IS REUSED AS THE HBIOS PHYSICAL DISK READ/WRITE BUFFER 
;
	.FILL	(HBX_IMG - $)	; FILL TO START OF PROXY IMAGE START
	.ORG	HBX_LOC		; ADJUST FOR RELOCATION
;
; MEMORY LAYOUT:
;   HBIOS PROXY CODE		$FE00 (256 BYTES)
;   INTERRUPT VECTORS		$FF00 (32 BYTES, 16 ENTRIES)
;   HBIOS PROXY COPY BUFFER	$FF20 (128 BYTES)
;   HBIOS PROXY PRIVATE STACK	$FFA0 (64 BYTES, 32 ENTRIES)
;   HBIOS PROXY MGMT BLOCK	$FFE0 (32 BYTES)
;
; DEFINITIONS
;
HBX_CODSIZ	.EQU	$100	; 256 BYTE CODE SPACE
HBX_IVTSIZ	.EQU	$20	; INT VECTOR TABLE SIZE (16 ENTRIES)
HBX_BUFSIZ	.EQU	$80	; INTERBANK COPY BUFFER
HBX_STKSIZ	.EQU	$40	; PRIVATE STACK SIZE
;
; HBIOS IDENTIFICATION DATA BLOCK
;
HBX_IDENT:
	.DB	'W',~'W'	; MARKER
	.DB	RMJ << 4 | RMN	; FIRST BYTE OF VERSION INFO
	.DB	RUP << 4 | RTP	; SECOND BYTE OF VERSION INFO
;
;==================================================================================================
;   HBIOS ENTRY FOR RST 08 PROCESSING
;==================================================================================================
;
HBX_INVOKE:
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME

	LD	A,(HB_CURBNK)	; GET CURRENT BANK
	LD	(HBX_INVBNK),A	; SETUP TO RESTORE AT EXIT

	LD	A,BID_BIOS	; HBIOS BANK
	CALL	HBX_BNKSEL	; SELECT IT

	CALL	HB_DISPATCH	; CALL HBIOS FUNCTION DISPATCHER

	PUSH	AF		; SAVE AF (FUNCTION RETURN)
	LD	A,$FF		; LOAD ORIGINAL BANK ($FF IS REPLACED AT ENTRY)
HBX_INVBNK	.EQU	$ - 1
	CALL	HBX_BNKSEL	; SELECT IT
	POP	AF		; RESTORE AF

	LD	SP,0		; RESTORE ORIGINAL STACK FRAME
HBX_STKSAV	.EQU	$ - 2

	RET			; RETURN TO CALLER
;
;;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; SETBNK - Switch Memory Bank to Bank in A.
;;   Preserve all Registers including Flags.
;;   Does NOT update current bank.
;;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
HBX_BNKSEL:
	LD	(HB_CURBNK),A	; RECORD NEW CURRENT BANK
;
#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA))
	OUT	(MPCL_ROM),A
	OUT	(MPCL_RAM),A
#ENDIF
#IF (PLATFORM == PLT_ZETA2)
	BIT	7,A
	JR	Z,HBX_ROM		; JUMP IF IT IS A ROM PAGE
        RES     7,A			; RAM PAGE REQUESTED: CLEAR ROM BIT
        ADD	A,16			; ADD 16 x 32K - RAM STARTS FROM 512K 
;
HBX_ROM:
	RLCA				; TIMES 2 - GET 16K PAGE INSTEAD OF 32K
	OUT	(MPGSEL_0),A		; BANK_0: 0K - 16K
	INC	A
	OUT	(MPGSEL_1),A		; BANK_1: 16K - 32K
#ENDIF
#IF (PLATFORM == PLT_N8)
	BIT	7,A
	JR	Z,HBX_ROM
;
HBX_RAM:
	RES	7,A
	RLCA
	RLCA
	RLCA
	OUT0	(Z180_BBR),A
	LD	A,N8_DEFACR | 80H
	OUT0	(N8_ACR),A
	RET
;
HBX_ROM:
	OUT0	(N8_RMAP),A
	XOR	A
	OUT0	(Z180_BBR),A
	LD	A,N8_DEFACR
	OUT0	(N8_ACR),A
	RET
;
#ENDIF
#IF (PLATFORM == PLT_MK4)
	RLCA				; RAM FLAG TO CARRY AND BIT 0
	JR	NC,HBX_BNKSEL1		; IF NC, ROM, SKIP AHEAD
	XOR	%00100001		; SET BIT FOR HI 512K, CLR BIT 0
HBX_BNKSEL1:
	RLCA				; ROTATE
	RLCA				; ... AGAIN
	OUT0	(Z180_BBR),A		; WRITE TO BANK REGISTER
#ENDIF
	RET
;
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; Copy Data - Possibly between banks.  This resembles CP/M 3, but
;  usage of the HL and DE registers is reversed.
; Caller MUST ensure stack is already in high memory.
; Enter:
;        HL = Source Address
;	 DE = Destination Address
;	 BC = Number of bytes to copy
; Exit : None
; Uses : AF,BC,DE,HL
;
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
HBX_BNKCPY:
	; Save current bank to restore at end
	LD	A,(HB_CURBNK)
	LD	(HBX_CPYBNK),A

	; Setup for copy loop
	LD	(HB_SRCADR),HL	; Init working source adr
	LD	(HB_DSTADR),DE	; Init working dest adr 
	LD	H,B		; Move bytes to copy from BC
	LD	L,C		; ... to HL to use as byte counter
;
HBX_BNKCPY2:
	; Copy loop
	LD	A,L		; Low byte of count to A
	AND	$7F		; Isolate bits relevant to 128 byte buf
	LD	BC,$80		; Assume full buf copy
	JR	Z,HBX_BNKCPY3	; If full buf copy, go do it
	LD	C,A		; Otherwise, BC := bytes to copy
;
HBX_BNKCPY3:
	PUSH	HL		; Save bytes left to copy
	CALL	HBX_BNKCPY4	; Do it
	POP	HL		; Recover bytes left to copy
	XOR	A		; Clear CF
	SBC	HL,BC		; Reflect bytes copied in HL
	JR	NZ,HBX_BNKCPY2	; If any left, then loop
	LD	A,$FF		; Load original bank ($FF is replaced at entry)
HBX_CPYBNK	.EQU	$ - 1

	JR	HBX_BNKSEL	; Select and return
;
HBX_BNKCPY4:	; Switch to source bank
	LD	A,(HB_SRCBNK)	; Get source bank
	CALL	HBX_BNKSEL	; Set source bank
;
	; Copy BC bytes from HL -> BUF, allow HL to increment
	PUSH	BC		; Save copy length
	LD	HL,(HB_SRCADR)	; Point to source adr
	LD	DE,HBX_BUF	; Setup buffer as interim destination
	LDIR			; Copy BC bytes: src -> buffer
	LD	(HB_SRCADR),HL	; Update source adr
	POP	BC		; Recover copy length
;	
	; Switch to dest bank
	LD	A,(HB_DSTBNK)	; Get destination bank
	CALL	HBX_BNKSEL	; Set destination bank
;
	; Copy BC bytes from BUF -> HL, allow DE to increment
	PUSH	BC		; Save copy length
	LD	HL,HBX_BUF	; Use the buffer as source now
	LD	DE,(HB_DSTADR)	; Setup final destination for copy
	LDIR			; Copy BC bytes: buffer -> dest
	LD	(HB_DSTADR),DE	; Update dest adr
	POP	BC		; Recover copy length
;
	RET			; Done
;
; Call a routine in another bank saving and restoring the original bank.
; Caller MUST ensure stack is already in high memory.
; On input A=target bank, HL=target address
;
HBX_BNKCALL:
	LD	(HBX_TGTBNK),A	; stuff target bank to call into code below
	LD	(HBX_TGTADR),HL	; stuff address to call into code below
	LD	A,(HB_CURBNK)	; get current bank
	PUSH	AF		; save for return
HBX_TGTBNK	.EQU	$ + 1
	LD	A,$FF		; load bank to call ($FF overlaid at entry)
	CALL	HBX_BNKSEL	; activate the new bank
HBX_TGTADR	.EQU	$ + 1
	CALL	$FFFF		; call routine ($FFFF is overlaid above)
	EX	(SP),HL		; save hl and get bank to restore in hl
	PUSH	AF		; save af
	LD	A,H		; bank to restore to a
	CALL	HBX_BNKSEL	; restore it
	POP	AF		; recover af
	POP	HL		; recover hl
	RET
;
; INTERRUPT HANDLER DISPATCHING
;
INT_TIMER:
	PUSH	HL
	LD	HL,HB_TIMINT
	JR	HBX_INT
;
INT_BAD:
	PUSH	HL
	LD	HL,HB_BADINT
	JR	HBX_INT
;
; COMMON INTERRUPT DISPATCHING CODE
; SETUP AND CALL HANDLER IN BIOS BANK
; 
HBX_INT:
	; SAVE STATE (HL MUST BE SAVED PREVIOUSLY)
	PUSH	AF
	PUSH	BC
	PUSH	DE

	; ACTIVATE BIOS BANK
#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA))
	LD	A,BID_BIOS
	OUT	(MPCL_ROM),A
	OUT	(MPCL_RAM),A
#ENDIF
#IF (PLATFORM == PLT_ZETA2)
	LD	A,(BID_BIOS - $80 + $10) * 2
	OUT	(MPGSEL_0),A		; BANK_0: 0K - 16K
	INC	A
	OUT	(MPGSEL_1),A		; BANK_1: 16K - 32K
#ENDIF
#IF (PLATFORM == PLT_N8)
	LD	A,(BID_BIOS << 3) & $FF
	OUT0	(Z180_BBR),A
	LD	A,N8_DEFACR | $80
	OUT0	(N8_ACR),A
#ENDIF
#IF (PLATFORM == PLT_MK4)
	LD	A,(BID_BIOS << 3) & $FF | $80  
	OUT0	(Z180_BBR),A
#ENDIF

	; SETUP INTERRUPT PROCESSING STACK IN HBIOS
	LD	(HB_INTSTKSAV),SP
	LD	SP,HB_INTSTK

	; DO THE REAL WORK
	CALL	JPHL

	; RESTORE STACK
	LD	SP,(HB_INTSTKSAV)

	; RESTORE BANK
	LD	A,(HB_CURBNK)		; SET TARGET BANK
;
#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA))
	OUT	(MPCL_ROM),A
	OUT	(MPCL_RAM),A
#ENDIF
#IF (PLATFORM == PLT_ZETA2)
	BIT	7,A
	JR	Z,HBX_INT1		; JUMP IF IT IS A ROM PAGE
        RES     7,A			; RAM PAGE REQUESTED: CLEAR ROM BIT
        ADD	A,16			; ADD 16 x 32K - RAM STARTS FROM 512K 
;
HBX_INT1:
	RLCA				; TIMES 2 - GET 16K PAGE INSTEAD OF 32K
	OUT	(MPGSEL_0),A		; BANK_0: 0K - 16K
	INC	A
	OUT	(MPGSEL_1),A		; BANK_1: 16K - 32K
#ENDIF
#IF (PLATFORM == PLT_N8)
	BIT	7,A
	JR	Z,HBX_INT1
;
	RES	7,A
	RLCA
	RLCA
	RLCA
	OUT0	(Z180_BBR),A
	JR	HBX_INT2
;
HBX_INT1:
	XOR	A
	OUT0	(Z180_BBR),A
	LD	A,N8_DEFACR
	OUT0	(N8_ACR),A
;
HBX_INT2:
#ENDIF
#IF (PLATFORM == PLT_MK4)
	RLCA				; RAM FLAG TO CARRY AND BIT 0
	JR	NC,HBX_INT1		; IF NC, ROM, SKIP AHEAD
	XOR	%00100001		; SET BIT FOR HI 512K, CLR BIT 0
HBX_INT1:
	RLCA				; ROTATE
	RLCA				; ... AGAIN
	OUT0	(Z180_BBR),A		; WRITE TO BANK REGISTER
#ENDIF
;
	; RESTORE STATE
	POP	DE
	POP	BC
	POP	AF
	POP	HL

	; DONE
	RETI			; IMPLICITLY REENABLES INTERRUPTS!
;
; FILLER FOR UNUSED HBIOS PROXY CODE SPACE
; PAD TO START OF INTERRUPT VECTOR TABLE
;
HBX_SLACK	.EQU	(HBX_LOC + HBX_CODSIZ - $)
		.ECHO	"HBIOS PROXY space remaining: "
		.ECHO	HBX_SLACK
		.ECHO	" bytes.\n"
		.FILL	HBX_SLACK,$FF
;
; HBIOS INTERRUPT VECTOR TABLE (16 ENTRIES)
;
HBX_IVT		;	.FILL	HBX_IVTSIZ,$FF
		.DW	INT_TIMER
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
		.DW	INT_BAD
;
; INTERBANK COPY BUFFER (128 BYTES)
;
HBX_BUF		.FILL	HBX_BUFSIZ,0
;
; PRIVATE STACK (64 BYTES, 32 ENTRIES)
;
		.FILL	HBX_STKSIZ,$FF
HBX_STACK	.EQU	$
;
; HBIOS PROXY MGMT BLOCK (TOP 32 BYTES)
;
	.DB	BID_BOOT	; CURRENTLY ACTIVE LOW MEMORY BANK ID
	.DB	$FF		; DEPRECATED!!!
	.DW	0		; BNKCPY SOURCE ADDRESS
	.DB	BID_USR		; BNKCPY SOURCE BANK ID
	.DW	0		; BNKCPY DESTINATION ADDRESS
	.DB	BID_USR		; BNKCPY DESTINATION BANK ID
	.FILL	8,0		; FILLER, RESERVED FOR FUTURE HBIOS USE
	JP	HBX_INVOKE	; FIXED ADR ENTRY FOR HBX_INVOKE (ALT FOR RST 08)
	JP	HBX_BNKSEL	; FIXED ADR ENTRY FOR HBX_BNKSEL
	JP	HBX_BNKCPY	; FIXED ADR ENTRY FOR HBX_BNKCPY
	JP	HBX_BNKCALL	; FIXED ADR ENTRY FOR HBX_BNKCALL
	.DW	HBX_IDENT	; ADDRESS OF HBIOX PROXY START
	.DW	HBX_IDENT	; ADDRESS OF HBIOS IDENT INFO DATA BLOCK
;
	.FILL	$MEMTOP - $		; FILL TO END OF MEMORY (AS NEEDED)
	.ORG	HBX_IMG + HBX_SIZ	; RESET ORG
;
;==================================================================================================
;   HBIOS CORE
;==================================================================================================
;
;
;==================================================================================================
;   ENTRY VECTORS (JUMP TABLE)
;==================================================================================================
;
	JP	HB_START		; HBIOS INITIALIZATION
	JP	HB_DISPATCH		; VECTOR TO DISPATCHER
;
;==================================================================================================
;   SYSTEM INITIALIZATION
;==================================================================================================
;
HB_START:
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	; SET BASE FOR CPU IO REGISTERS
   	LD	A,Z180_BASE
	OUT0	(Z180_ICR),A

	; DISABLE REFRESH
	XOR	A
	OUT0	(Z180_RCR),A

	; SET DEFAULT WAIT STATES TO ACCURATELY MEASURE CPU SPEED
	LD	A,$F0
	OUT0	(Z180_DCNTL),A

#IF (Z180_CLKDIV >= 1)
	; SET CLOCK DIVIDE TO 1 RESULTING IN FULL XTAL SPEED
	LD	A,$80
	OUT0	(Z180_CCR),A
#ENDIF

#IF (Z180_CLKDIV >= 2)
	; SET CPU MULTIPLIER TO 1 RESULTING IN XTAL * 2 SPEED
	LD	A,$80
	OUT0	(Z180_CMR),A
#ENDIF

#ENDIF
;
	CALL	HB_CPUSPD		; CPU SPEED DETECTION
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
;
	; SET DESIRED WAIT STATES
	LD	A,0 + (Z180_MEMWAIT << 6) | (Z180_IOWAIT << 4)
	OUT0	(Z180_DCNTL),A
;
#ENDIF
;
	CALL	DELAY_INIT		; INITIALIZE SPEED COMPENSATED DELAY FUNCTIONS
;
; ANNOUNCE HBIOS
;
	CALL	NEWLINE
	CALL	NEWLINE
	PRTX(STR_PLATFORM)
	PRTS(" @ $")
	LD	HL,(HCB + HCB_CPUKHZ)
	CALL	PRTD3M			; PRINT AS DECIMAL WITH 3 DIGIT MANTISSA
	PRTS("MHz ROM=$")
	LD	HL,ROMSIZE
	CALL	PRTDEC
	PRTS("KB RAM=$")
	LD	HL,RAMSIZE
	CALL	PRTDEC
	PRTS("KB$")
;
; PERFORM DEVICE INITIALIZATION
;
	LD	B,HB_INITTBLLEN
	LD	DE,HB_INITTBL
INITSYS2:
	CALL	NEWLINE
	LD	A,(DE)
	LD	L,A
	INC	DE
	LD	A,(DE)
	LD	H,A
	INC	DE
	PUSH	DE
	PUSH	BC
	CALL	JPHL
	POP	BC
	POP	DE
	DJNZ	INITSYS2
;
; SET UP THE DEFAULT DISK BUFFER ADDRESS
;
	LD	HL,HB_BUF	; DEFAULT DISK XFR BUF ADDRESS
	LD	(DIOBUF),HL	; SAVE IT
;
; NOW SWITCH TO CRT CONSOLE IF CONFIGURED
;
#IF CRTACT
	LD	A,CRTDEV	; GET CRT DISPLAY DEVICE
	LD	(HCB + HCB_CONDEV),A	; SAVE IT
;
; IF PLATFORM HAS A CONFIG JUMPER, CHECK TO SEE IF IT IS JUMPERED.
; IF SO, FORCE DISPLAY BACK TO SERIAL PORT (FAILSAFE MODE)
;
#IF ((PLATFORM != PLT_N8) & (PLATFORM != PLT_MK4))
	IN	A,(RTC)		; RTC PORT, BIT 6 HAS STATE OF CONFIG JUMPER
	BIT	6,A		; BIT 6 HAS CONFIG JUMPER STATE
	JR	NZ,INITSYS1	; NZ=OPEN, LEAVE DISPLAY ALONE
	LD	A,SERDEV	; GET THE PRIMARY SERIAL DEVICE
	LD	(HCB + HCB_CONDEV),A	; FORCE DISPLAY BACK TO PRIMARY SERIAL DEVICE
INITSYS1:
#ENDIF
#ENDIF
;
; DISPLAY THE POST-INITIALIZATION BANNER
;
	CALL	NEWLINE
	CALL	NEWLINE
	PRTX(STR_BANNER)
	CALL	NEWLINE
;
	RET
;
;==================================================================================================
;   TABLE OF INITIALIZATION ENTRY POINTS
;==================================================================================================
;
HB_INITTBL:
#IF (UARTENABLE)
	.DW	UART_INIT
#ENDIF
#IF (ASCIENABLE)
	.DW	ASCI_INIT
#ENDIF
#IF (SIMRTCENABLE)
	.DW	SIMRTC_INIT
#ENDIF
#IF (DSRTCENABLE)
	.DW	DSRTC_INIT
#ENDIF
#IF (VDUENABLE)
	.DW	VDU_INIT
#ENDIF
#IF (CVDUENABLE)
	.DW	CVDU_INIT
#ENDIF
#IF (UPD7220ENABLE)
	.DW	UPD7220_INIT
#ENDIF
#IF (N8VENABLE)
	.DW	N8V_INIT
#ENDIF
#IF (PRPENABLE)
	.DW	PRP_INIT
#ENDIF
#IF (PPPENABLE)
	.DW	PPP_INIT
#ENDIF
#IF (DSKYENABLE)
	.DW	DSKY_INIT
#ENDIF
#IF (MDENABLE)
	.DW	MD_INIT
#ENDIF
#IF (FDENABLE)
	.DW	FD_INIT
#ENDIF
#IF (RFENABLE)
	.DW	RF_INIT
#ENDIF
#IF (IDEENABLE)
	.DW	IDE_INIT
#ENDIF
#IF (PPIDEENABLE)
	.DW	PPIDE_INIT
#ENDIF
#IF (SDENABLE)
	.DW	SD_INIT
#ENDIF
#IF (HDSKENABLE)
	.DW	HDSK_INIT
#ENDIF
#IF (PPKENABLE)
	.DW	PPK_INIT
#ENDIF
#IF (KBDENABLE)
	.DW	KBD_INIT
#ENDIF
#IF (TTYENABLE)
	.DW	TTY_INIT
#ENDIF
#IF (ANSIENABLE)
	.DW	ANSI_INIT
#ENDIF
;
HB_INITTBLLEN	.EQU	(($ - HB_INITTBL) / 2)
;
;==================================================================================================
;   IDLE
;==================================================================================================
;
;__________________________________________________________________________________________________
;
IDLE:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
#IF (FDENABLE)
	CALL	FD_IDLE
#ENDIF
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	RET
;
;==================================================================================================
;   BIOS FUNCTION DISPATCHER
;==================================================================================================
;
; MAIN BIOS FUNCTION
;   B: FUNCTION
;__________________________________________________________________________________________________
;
HB_DISPATCH:
	LD	A,B		; REQUESTED FUNCTION IS IN B
	CP	BF_CIO + $10	; $00-$0F: CHARACTER I/O
	JP	C,CIO_DISPATCH
	CP	BF_DIO + $10	; $10-$1F: DISK I/O
	JP	C,DIO_DISPATCH
	CP	BF_RTC + $10	; $20-$2F: REAL TIME CLOCK (RTC)
	JP	C,RTC_DISPATCH
	CP	BF_EMU + $10	; $30-$3F: EMULATION
	JP	C,EMU_DISPATCH
	CP	BF_VDA + $10	; $40-$4F: VIDEO DISPLAY ADAPTER
	JP	C,VDA_DISPATCH
	
	CP	BF_SYS		; SKIP TO BF_SYS VALUE AT $F0
	CALL	C,PANIC		; PANIC IF LESS THAN BF_SYS
	JP	SYS_DISPATCH	; OTHERWISE SYS CALL
	CALL	PANIC		; THIS SHOULD NEVER BE REACHED
;
;==================================================================================================
;   CHARACTER I/O DEVICE DISPATCHER
;==================================================================================================
;
; ROUTE CALL TO SPECIFIED CHARACTER I/O DRIVER
;   B: FUNCTION
;   C: DEVICE/UNIT
;
CIO_DISPATCH:
;
	; CIO FUNCTIONS STARTING AT CIOGETBUF ARE COMMON FUNCTIONS
	LD	A,B		; GET THE REQUESTED FUNCTION
	CP	BF_CIOGETCNT	; TEST FOR FIRST OF THE COMMON FUNCTIONS
	JR	NC,CIO_COMMON	; IF >= CIOGETCNT HANDLE AS COMMON DIO FUNCTION
;
	; STANDARD FUNCTIONS ARE DISPATCHED TO DRIVER
	LD	A,C		; REQUESTED DEVICE/UNIT IS IN C
	AND	$F0		; ISOLATE THE DEVICE PORTION
#IF (UARTENABLE)
	CP	CIODEV_UART
	JP	Z,UART_DISPATCH
#ENDIF
#IF (ASCIENABLE)
	CP	CIODEV_ASCI
	JP	Z,ASCI_DISPATCH
#ENDIF
#IF (PRPENABLE & PRPCONENABLE)
	CP	CIODEV_PRPCON
	JP	Z,PRPCON_DISPATCH
#ENDIF
#IF (PPPENABLE & PPPCONENABLE)
	CP	CIODEV_PPPCON
	JP	Z,PPPCON_DISPATCH
#ENDIF
#IF (VDUENABLE)
	CP	CIODEV_VDU
	JP	Z,VDU_DISPCIO
#ENDIF
#IF (CVDUENABLE)
	CP	CIODEV_CVDU
	JP	Z,CVDU_DISPCIO
#ENDIF
#IF (UPD7220ENABLE)
	CP	CIODEV_UPD7220
	JP	Z,UPD7220_DISPCIO
#ENDIF
#IF (N8VENABLE)
	CP	CIODEV_N8V
	JP	Z,N8V_DISPCIO
#ENDIF
	CP	CIODEV_VDA
	JR	Z,CIOVDA
	CP	CIODEV_CONSOLE
	JR	Z,CIOCON
	CALL	PANIC
;
CIOVDA:
	LD	A,B
	ADD	A,BF_EMU - BF_CIO	; TRANSLATE FUNCTION CIOXXX -> EMUXXX
	LD	B,A
	JP	EMU_DISPATCH
;
CIOCON:
	LD	A,(HCB + HCB_CONDEV)
	LD	C,A
	JR	CIO_DISPATCH
;
; HANDLE COMMON CHARACTER FUNCTIONS (NOT DEVICE DRIVER SPECIFIC)
;
CIO_COMMON:
	SUB	BF_CIOGETCNT	; FUNCTION = CIOGETCNT?
	JR	Z,CIO_GETCNT	; YES, HANDLE IT
	DEC	A		; FUNCTION = CIOGETINF?
	JR	Z,CIO_GETINF	; YES, HANDLE IT
	CALL	PANIC		; INVALID FUNCTION SPECFIED
;
; CHARACTER DEVICE: GET DEVICE COUNT
;
CIO_GETCNT:
	LD	A,(HCB + HCB_CDL)	; GET DEVICE COUNT (FIRST BYTE OF LIST)
	LD	B,A		; PUT IT IN B
	XOR	A		; SIGNALS SUCCESS
	RET
;
; CHARACTER DEVICE: GET DEVICE INFO
;
CIO_GETINF:
	LD	HL,HCB + HCB_CDL	; POINT TO DEVICE MAP ENTRY COUNT (FIRST BYTE OF LIST)
	LD	B,(HL)		; ENTRY COUNT TO B
	LD	A,C		; INDEX TO A
	CP	B		; CHECK INDEX AGAINST MAX VALUE (INDEX - COUNT)
	JR	NC,CIO_GETINF1	; IF INDEX TOO HIGH, ERR
	INC	HL		; BUMP TO START OF CHR MAP ENTRIES
	CALL	ADDHLA		; AND POINT TO REQUESTED INDEX
	LD	C,(HL)		; DEVICE/UNIT TO C
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE

CIO_GETINF1:
	OR	$FF		; SIGNAL ERROR
	RET			; RETURN
;
;==================================================================================================
;   DISK I/O DEVICE DISPATCHER
;================= =================================================================================
;
; ROUTE CALL TO SPECIFIED DISK I/O DRIVER
;   B: FUNCTION
;   C: DEVICE/UNIT
;
DIO_DISPATCH:
	; GET THE REQUESTED FUNCTION TO SEE IF SPECIAL HANDLING
	; IS NEEDED
	LD	A,B
;
	; DIO FUNCTIONS STARTING AT DIOGETBUF ARE COMMON FUNCTIONS
	; AND DO NOT DISPATCH TO DRIVERS (HANDLED GLOBALLY)
	CP	BF_DIOGETBUF	; TEST FOR FIRST OF THE COMMON FUNCTIONS
	JR	NC,DIO_COMMON	; IF >= DIOGETBUF HANDLE AS COMMON DIO FUNCTION
;
	; HACK TO FILL IN HSTTRK AND HSTSEC
	; BUT ONLY FOR READ/WRITE FUNCTION CALLS
	; ULTIMATELY, HSTTRK AND HSTSEC ARE TO BE REMOVED
	CP	BF_DIOST		; BEYOND READ/WRITE FUNCTIONS ?
	JR	NC,DIO_DISPATCH1	; YES, BYPASS
	LD	(HSTTRK),HL		; RECORD TRACK
	LD	(HSTSEC),DE		; RECORD SECTOR
;
DIO_DISPATCH1:
	; START OF THE ACTUAL DRIVER DISPATCHING LOGIC
	LD	A,C		; GET REQUESTED DEVICE/UNIT FROM C
	LD	(HSTDSK),A	; TEMP HACK TO FILL IN HSTDSK
	AND	$F0		; ISOLATE THE DEVICE PORTION
;
#IF (MDENABLE)
	CP	DIODEV_MD
	JP	Z,MD_DISPATCH
#ENDIF
#IF (FDENABLE)
	CP	DIODEV_FD
	JP	Z,FD_DISPATCH
#ENDIF
#IF (RFENABLE)
	CP	DIODEV_RF
	JP	Z,RF_DISPATCH
#ENDIF
#IF (IDEENABLE)
	CP	DIODEV_IDE
	JP	Z,IDE_DISPATCH
#ENDIF
#IF (PPIDEENABLE)
	CP	DIODEV_PPIDE
	JP	Z,PPIDE_DISPATCH
#ENDIF
#IF (SDENABLE)
	CP	DIODEV_SD
	JP	Z,SD_DISPATCH
#ENDIF
#IF (PRPENABLE & PRPSDENABLE)
	CP	DIODEV_PRPSD
	JP	Z,PRPSD_DISPATCH
#ENDIF
#IF (PPPENABLE & PPPSDENABLE)
	CP	DIODEV_PPPSD
	JP	Z,PPPSD_DISPATCH
#ENDIF
#IF (HDSKENABLE)
	CP	DIODEV_HDSK
	JP	Z,HDSK_DISPATCH
#ENDIF
	CALL	PANIC
;
; HANDLE COMMON DISK FUNCTIONS (NOT DEVICE DRIVER SPECIFIC)
;
DIO_COMMON:
	SUB	BF_DIOGETBUF	; FUNCTION = DIOGETBUF?
	JR	Z,DIO_GETBUF	; YES, HANDLE IT
	DEC	A		; FUNCTION = DIOSETBUF?
	JR	Z,DIO_SETBUF	; YES, HANDLE IT
	DEC	A		; FUNCTION = DIOGETCNT?
	JR	Z,DIO_GETCNT	; YES, HANDLE IT
	DEC	A		; FUNCTION = DIOGETINF?
	JR	Z,DIO_GETINF	; YES, HANDLE IT
	CALL	PANIC		; INVALID FUNCTION SPECFIED
;
; DISK: GET BUFFER ADDRESS
;
DIO_GETBUF:
	LD	HL,(DIOBUF)	; HL = DISK BUFFER ADDRESS
	XOR	A		; SIGNALS SUCCESS
	RET
;
; DISK: SET BUFFER ADDRESS
;
DIO_SETBUF:
	LD	A,H		; TEST HL
	OR	L		; ... FOR ZERO
	JR	NZ,DIO_SETBUF1	; IF NOT, PROCEED TO SET BUF ADR
	LD	HL,HB_BUF	; IF ZERO, SET TO DEFAULT ADR
DIO_SETBUF1:
	LD	(DIOBUF),HL	; RECORD NEW DISK BUFFER ADDRESS
	XOR	A		; SIGNALS SUCCESS
	RET
;
; DISK: GET DEVICE COUNT
;
DIO_GETCNT:
	LD	A,(HCB + HCB_DDL)	; GET DEVICE COUNT (FIRST BYTE OF LIST)
	LD	B,A		; PUT IT IN B
	XOR	A		; SIGNALS SUCCESS
	RET
;
; DISK: GET DEVICE INFO
;
DIO_GETINF:
	LD	HL,HCB + HCB_DDL	; POINT TO DEVICE MAP ENTRY COUNT (FIRST BYTE OF LIST)
	LD	B,(HL)		; ENTRY COUNT TO B
	LD	A,C		; INDEX TO A
	CP	B		; CHECK INDEX AGAINST MAX VALUE (INDEX - COUNT)
	JR	NC,DIO_GETINF1	; IF INDEX TOO HIGH, ERR
	INC	HL		; BUMP TO START OF DEV MAP ENTRIES
	CALL	ADDHLA		; AND POINT TO REQUESTED INDEX
	LD	C,(HL)		; DEVICE/UNIT TO C
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE

DIO_GETINF1:
	OR	$FF		; SIGNAL ERROR
	RET			; RETURN
;
;==================================================================================================
;   REAL TIME CLOCK DEVICE DISPATCHER
;==================================================================================================
;
; ROUTE CALL TO REAL TIME CLOCK DRIVER
;   B: FUNCTION
;
RTC_DISPATCH:
#IF (SIMRTCENABLE)
	JP	SIMRTC_DISPATCH
#ENDIF
#IF (DSRTCENABLE)
	JP	DSRTC_DISPATCH
#ENDIF
	CALL	PANIC
;
;==================================================================================================
;   EMULATION HANDLER DISPATCHER
;==================================================================================================
;
; ROUTE CALL TO EMULATION HANDLER CURRENTLY ACTIVE
;   B: FUNCTION
;
EMU_DISPATCH:
	; EMU FUNCTIONS STARTING AT EMUINI ARE COMMON
	; AND DO NOT DISPATCH TO DRIVERS
	LD	A,B		; GET REQUESTED FUNCTION
	CP	BF_EMUINI
	JR	NC,EMU_COMMON
;
	LD	A,(CUREMU)	; GET ACTIVE EMULATION
;
	DEC	A		; 1 = TTY
#IF (TTYENABLE)
	JP	Z,TTY_DISPATCH
#ENDIF
	DEC	A		; 2 = ANSI
#IF (ANSIENABLE)
	JP	Z,ANSI_DISPATCH
#ENDIF
	CALL	PANIC		; INVALID
;
; HANDLE COMMON EMULATION FUNCTIONS (NOT HANDLER SPECIFIC)
;
EMU_COMMON:
	; REG A CONTAINS FUNCTION ON ENTRY
	CP	BF_EMUINI
	JR	Z,EMU_INI
	CP	BF_EMUQRY
	JR	Z,EMU_QRY
	CALL	PANIC
;
; INITIALIZE EMULATION
;   C: VDA DEVICE/UNIT TO USE GOING FORWARD
;   E: EMULATION TYPE TO USE GOING FORWARD
;
EMU_INI:
	LD	A,E		; LOAD REQUESTED EMULATION TYPE
	LD	(CUREMU),A	; SAVE IT
	LD	A,C		; LOAD REQUESTED VDA DEVICE/UNIT
	LD	(CURVDA),A	; SAVE IT
;
	; UPDATE EMULATION VDA DISPATCHING ADDRESS
#IF (VDUENABLE)
	LD	HL,VDU_DISPVDA
	CP	VDADEV_VDU
	JR	Z,EMU_INI1
#ENDIF
#IF (CVDUENABLE)
	LD	HL,CVDU_DISPVDA
	CP	VDADEV_CVDU
	JR	Z,EMU_INI1
#ENDIF
#IF (UPD7220ENABLE)
	LD	HL,UPD7220_DISPVDA
	CP	VDADEV_UPD7220
	JR	Z,EMU_INI1
#ENDIF
#IF (N8VENABLE)
	LD	HL,N8V_DISPVDA
	CP	VDADEV_N8V
	JR	Z,EMU_INI1
#ENDIF
	CALL	PANIC
;
EMU_INI1:
	LD	(EMU_VDADISPADR),HL	; RECORD NEW VDA DISPATCH ADDRESS
	JP	EMU_VDADISP		; NOW LET EMULATOR INITIALIZE
;
; QUERY CURRENT EMULATION CONFIGURATION
;   RETURN CURRENT EMULATION TARGET VDA DEVICE/UNIT IN C
;   RETURN CURRENT EMULATION TYPE IN E
;
EMU_QRY:
	LD	A,(CURVDA)
	LD	C,A
	LD	A,(CUREMU)
	LD	E,A
	JP	EMU_VDADISP	; NOW LET EMULATOR COMPLETE THE FUNCTION
;
;==================================================================================================
;   VDA DISPATCHING FOR EMULATION HANDLERS
;==================================================================================================
;
; SINCE THE EMULATION HANDLERS WILL ONLY HAVE A SINGLE ACTIVE
; VDA TARGET AT ANY TIME, THE FOLLOWING IMPLEMENTS A FAST DISPATCHING
; MECHANISM THAT THE EMULATION HANDLERS CAN USE TO BYPASS SOME OF THE
; VDA DISPATCHING LOGIC.  EMU_VDADISP CAN BE CALLED TO DISPATCH DIRECTLY
; TO THE CURRENT VDA EMULATION TARGET.  IT IS A JUMP INSTRUCTION THAT 
; IS DYNAMICALLY MODIFIED TO POINT TO THE VDA DISPATCHER FOR THE 
; CURRENT EMULATION VDA TARGET.
;
; VDA_DISPERR IS FAILSAFE EMULATION DISPATCH ADDRESS WHICH JUST
; CHAINS TO SYSTEM PANIC
;
VDA_DISPERR:
	JP	PANIC
;
; BELOW IS USED TO INITIALIZE THE EMULATION VDA DISPATCH TARGET
; BASED ON THE DEFAULT VDA.
;
VDA_DISPADR	.EQU	VDA_DISPERR
#IF (VDUENABLE & (VDADEV == VDADEV_VDU))
VDA_DISPADR	.SET	VDU_DISPVDA
#ENDIF
#IF (CVDUENABLE & (VDADEV == VDADEV_CVDU))
VDA_DISPADR	.SET	CVDU_DISPVDA
#ENDIF
#IF (VDUENABLE & (VDADEV == VDADEV_UPD7220))
VDA_DISPADR	.SET	UPD7220_DISPVDA
#ENDIF
#IF (N8VENABLE & (VDADEV == VDADEV_N8V))
VDA_DISPADR	.SET	N8V_DISPVDA
#ENDIF
;
; BELOW IS THE DYNAMICALLY MANAGED EMULATION VDA DISPATCH.
; EMULATION HANDLERS CAN CALL EMU_VDADISP TO INVOKE A VDA
; FUNCTION.  EMU_VDADISPADR IS USED TO MARK THE LOCATION
; OF THE VDA DISPATCH ADDRESS.  THIS ALLOWS US TO MODIFY
; THE CODE DYNAMICALLY WHEN EMULATION IS INITIALIZED AND
; A NEW VDA TARGET IS SPECIFIED.
;
EMU_VDADISP:
	JP	VDA_DISPADR
;
EMU_VDADISPADR	.EQU	$ - 2		; ADDRESS PORTION OF JP INSTRUCTION ABOVE
;
;==================================================================================================
;   VIDEO DISPLAY ADAPTER DEVICE DISPATCHER
;==================================================================================================
;
; ROUTE CALL TO SPECIFIED VDA DEVICE DRIVER
;   B: FUNCTION
;   C: DEVICE/UNIT
;
VDA_DISPATCH:
	LD	A,C		; REQUESTED DEVICE/UNIT IS IN C
	AND	$F0		; ISOLATE THE DEVICE PORTION
#IF (VDUENABLE)
	CP	VDADEV_VDU
	JP	Z,VDU_DISPVDA
#ENDIF
#IF (CVDUENABLE)
	CP	VDADEV_CVDU
	JP	Z,CVDU_DISPVDA
#ENDIF
#IF (UPD7220ENABLE)
	CP	VDADEV_7220
	JP	Z,UPD7220_DISPVDA
#ENDIF
#IF (N8VENABLE)
	CP	VDADEV_N8V
	JP	Z,N8V_DISPVDA
#ENDIF
	CALL	PANIC
;
;==================================================================================================
;   SYSTEM FUNCTION DISPATCHER
;==================================================================================================
;
;   B: FUNCTION
;
SYS_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JR	Z,SYS_SETBNK	; $F0
	DEC	A
	JR	Z,SYS_GETBNK	; $F1
	DEC	A
	JP	Z,SYS_COPY	; $F2
	DEC	A
	JP	Z,SYS_XCOPY	; $F3
	DEC	A
	;JR	Z,SYS_ATTR	; $F4
	DEC	A
	;JR	Z,SYS_XXXX	; $F5
	DEC	A
	JR	Z,SYS_GETVER	; $F6
	DEC	A
	DEC	A
	JR	Z,SYS_HCBGETB	; $F8
	DEC	A
	JR	Z,SYS_HCBPUTB	; $F9
	DEC	A
	JR	Z,SYS_HCBGETW	; $FA
	DEC	A
	JR	Z,SYS_HCBPUTW	; $FB
	CALL	PANIC		; INVALID
;
; SET ACTIVE MEMORY BANK AND RETURN PREVIOUSLY ACTIVE MEMORY BANK
;   NOTE THAT IT GOES INTO EFFECT AS HBIOS IS EXITED
;   HERE, WE JUST SET THE CURRENT BANK
;   CALLER MUST EXTABLISH UPPER MEMORY STACK BEFORE INVOKING THIS FUNCTION!
;
SYS_SETBNK:
	LD	A,(HBX_INVBNK)	; GET THE PREVIOUS ACTIVE MEMORY BANK
	PUSH	AF		; SAVE IT
	LD	A,C		; LOAD THE NEW BANK REQUESTED
	LD	(HBX_INVBNK),A	; SET IT FOR ACTIVATION UPON HBIOS RETURN
	POP	AF		; GET PREVIOUS BANK INTO A
	OR	A
	RET
;
; GET ACTIVE MEMORY BANK
;
SYS_GETBNK:
	LD	A,(HBX_INVBNK)	; GET THE ACTIVE MEMORY BANK
	OR	A
	RET
;
; PERFORM MEMORY COPY POTENTIALLY ACROSS BANKS
;
SYS_COPY:
	PUSH	IX
	POP	BC
	CALL	BNKCPY
	XOR	A
	RET
;
; SET BANKS FOR EXTENDED (INTERBANK) MEMORY COPY
;
SYS_XCOPY:
	LD	A,E
	LD	(HB_SRCBNK),A
	LD	A,D
	LD	(HB_DSTBNK),A
	XOR	A
	RET
;
; GET THE CURRENT HBIOS VERSION
;   RETURNS VERSION IN DE AS BCD
;     D: MAJOR VERION IN TOP 4 BITS, MINOR VERSION IN LOW 4 BITS
;     E: UPDATE VERION IN TOP 4 BITS, PATCH VERSION IN LOW 4 BITS
;     L: PLATFORM ID
;
SYS_GETVER:
	LD	DE,0 | (RMJ << 12) | (RMN << 8) | (RUP << 4) | RTP
	LD	L,PLATFORM
	XOR	A
	RET
;
; GET HCB VALUE BYTE
;   C: HCB INDEX (OFFSET INTO HCB)
;   RETURN BYTE VALUE IN E
;
SYS_HCBGETB:
	CALL	SYS_HCBPTR	; LOAD HL WITH PTR
	LD	E,(HL)		; GET BYTE VALUE
	RET			; DONE
;
; PUT HCB VALUE BYTE
;   C: HCB INDEX (OFFSET INTO HCB)
;   E: VALUE TO WRITE
;
SYS_HCBPUTB:
	CALL	SYS_HCBPTR	; LOAD HL WITH PTR
	LD	(HL),E		; PUT BYTE VALUE
	RET
;
; GET HCB VALUE WORD
;   C: HCB INDEX (OFFSET INTO HCB)
;   RETURN BYTE VALUE IN DE
;
SYS_HCBGETW:
	CALL	SYS_HCBPTR	; LOAD HL WITH PTR
	LD	E,(HL)		; GET BYTE VALUE
	INC	HL
	LD	D,(HL)		; GET BYTE VALUE
	RET			; DONE
;
; PUT HCB VALUE WORD
;   C: HCB INDEX (OFFSET INTO HCB)
;   DE: VALUE TO WRITE
;
SYS_HCBPUTW:
	CALL	SYS_HCBPTR	; LOAD HL WITH PTR
	LD	(HL),E		; PUT BYTE VALUE
	INC	HL
	LD	(HL),D		; PUT BYTE VALUE
	RET
;
; CALCULATE REAL ADDRESS OF HCB VALUE FROM HCB OFFSET
;
SYS_HCBPTR:
	LD	A,C		; LOAD INDEX (HCB OFFSET)
	LD	HL,HCB		; GET HCB ADDRESS
	JP	ADDHLA		; CALC REAL ADDRESS AND RET
;
;==================================================================================================
;   GLOBAL HBIOS FUNCTIONS
;==================================================================================================
;
; COMMON ROUTINE THAT IS CALLED BY CHARACTER IO DRIVERS WHEN
; AN IDLE CONDITION IS DETECTED (WAIT FOR INPUT/OUTPUT)
;
CIO_IDLE:
	PUSH	AF			; PRESERVE AF
	LD	A,(IDLECOUNT)		; GET CURRENT IDLE COUNT
	DEC	A			; DECREMENT
	LD	(IDLECOUNT),A		; SAVE UPDATED VALUE
	CALL	Z,IDLE			; IF ZERO, DO IDLE PROCESSING
	POP	AF			; RECOVER AF
	RET
;
; TIMER INTERRUPT
;
HB_TIMINT:
	RET
;
; BAD INTERRUPT HANDLER
;
HB_BADINT:
	RET
;
; WRAPPER FOR CALL TO HB_BNKCPY FOR USE BY INTERNAL HBIOS FUNCTIONS
;
BNKCPY	.EQU	HB_BNKCPY
;
;==================================================================================================
;   DEVICE DRIVERS
;==================================================================================================
;
#IF (SIMRTCENABLE)
ORG_SIMRTC	.EQU	$
  #INCLUDE "simrtc.asm"
SIZ_SIMRTC	.EQU	$ - ORG_SIMRTC
		.ECHO	"SIMRTC occupies "
		.ECHO	SIZ_SIMRTC
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (DSRTCENABLE)
ORG_DSRTC	.EQU	$
  #INCLUDE "dsrtc.asm"
SIZ_DSRTC	.EQU	$ - ORG_DSRTC
		.ECHO	"DSRTC occupies "
		.ECHO	SIZ_DSRTC
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (UARTENABLE)
ORG_UART	.EQU	$
  #INCLUDE "uart.asm"
SIZ_UART	.EQU	$ - ORG_UART
		.ECHO	"UART occupies "
		.ECHO	SIZ_UART
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (ASCIENABLE)
ORG_ASCI	.EQU	$
  #INCLUDE "asci.asm"
SIZ_ASCI	.EQU	$ - ORG_ASCI
		.ECHO	"ASCI occupies "
		.ECHO	SIZ_ASCI
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (VDUENABLE)
ORG_VDU		.EQU	$
  #INCLUDE "vdu.asm"
SIZ_VDU		.EQU	$ - ORG_VDU
		.ECHO	"VDU occupies "
		.ECHO	SIZ_VDU
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (CVDUENABLE)
ORG_CVDU	.EQU	$
  #INCLUDE "cvdu.asm"
SIZ_CVDU	.EQU	$ - ORG_CVDU
		.ECHO	"CVDU occupies "
		.ECHO	SIZ_CVDU
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (UPD7220ENABLE)
ORG_UPD7220	.EQU	$
  #INCLUDE "upd7220.asm"
SIZ_UPD7220	.EQU	$ - ORG_UPD7220
		.ECHO	"UPD7220 occupies "
		.ECHO	SIZ_UPD7220
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (N8VENABLE)
ORG_N8V		.EQU	$
  #INCLUDE "n8v.asm"
SIZ_N8V		.EQU	$ - ORG_N8V
		.ECHO	"N8V occupies "
		.ECHO	SIZ_N8V
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (PRPENABLE)
ORG_PRP		.EQU	$
  #INCLUDE "prp.asm"
SIZ_PRP		.EQU	$ - ORG_PRP
		.ECHO	"PRP occupies "
		.ECHO	SIZ_PRP
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (PPPENABLE)
ORG_PPP		.EQU	$
  #INCLUDE "ppp.asm"
SIZ_PPP		.EQU	$ - ORG_PPP
		.ECHO	"PPP occupies "
		.ECHO	SIZ_PPP
		.ECHO	" bytes.\n"
#ENDIF
;
#IF (MDENABLE)
ORG_MD		.EQU	$
  #INCLUDE "md.asm"
SIZ_MD		.EQU	$ - ORG_MD
		.ECHO	"MD occupies "
		.ECHO	SIZ_MD
		.ECHO	" bytes.\n"
#ENDIF

#IF (FDENABLE)
ORG_FD		.EQU	$
  #INCLUDE "fd.asm"
SIZ_FD		.EQU	$ - ORG_FD
		.ECHO	"FD occupies "
		.ECHO	SIZ_FD
		.ECHO	" bytes.\n"
#ENDIF

#IF (RFENABLE)
ORG_RF	.EQU	$
  #INCLUDE "rf.asm"
SIZ_RF	.EQU	$ - ORG_RF
		.ECHO	"RF occupies "
		.ECHO	SIZ_RF
		.ECHO	" bytes.\n"
#ENDIF

#IF (IDEENABLE)
ORG_IDE		.EQU	$
  #INCLUDE "ide.asm"
SIZ_IDE		.EQU	$ - ORG_IDE
		.ECHO	"IDE occupies "
		.ECHO	SIZ_IDE
		.ECHO	" bytes.\n"
#ENDIF

#IF (PPIDEENABLE)
ORG_PPIDE	.EQU	$
  #INCLUDE "ppide.asm"
SIZ_PPIDE	.EQU	$ - ORG_PPIDE
		.ECHO	"PPIDE occupies "
		.ECHO	SIZ_PPIDE
		.ECHO	" bytes.\n"
#ENDIF

#IF (SDENABLE)
ORG_SD		.EQU	$
  #INCLUDE "sd.asm"
SIZ_SD		.EQU	$ - ORG_SD
		.ECHO	"SD occupies "
		.ECHO	SIZ_SD
		.ECHO	" bytes.\n"
#ENDIF

#IF (HDSKENABLE)
ORG_HDSK	.EQU	$
  #INCLUDE "hdsk.asm"
SIZ_HDSK	.EQU	$ - ORG_HDSK
		.ECHO	"HDSK occupies "
		.ECHO	SIZ_HDSK
		.ECHO	" bytes.\n"
#ENDIF

#IF (PPKENABLE)
ORG_PPK		.EQU	$
  #INCLUDE "ppk.asm"
SIZ_PPK		.EQU	$ - ORG_PPK
		.ECHO	"PPK occupies "
		.ECHO	SIZ_PPK
		.ECHO	" bytes.\n"
#ENDIF

#IF (KBDENABLE)
ORG_KBD		.EQU	$
  #INCLUDE "kbd.asm"
SIZ_KBD		.EQU	$ - ORG_KBD
		.ECHO	"KBD occupies "
		.ECHO	SIZ_KBD
		.ECHO	" bytes.\n"
#ENDIF

#IF (TTYENABLE)
ORG_TTY		.EQU	$
  #INCLUDE "tty.asm"
SIZ_TTY	.EQU	$ - ORG_TTY
		.ECHO	"TTY occupies "
		.ECHO	SIZ_TTY
		.ECHO	" bytes.\n"
#ENDIF

#IF (ANSIENABLE)
ORG_ANSI	.EQU	$
  #INCLUDE "ansi.asm"
SIZ_ANSI	.EQU	$ - ORG_ANSI
		.ECHO	"ANSI occupies "
		.ECHO	SIZ_ANSI
		.ECHO	" bytes.\n"
#ENDIF
;
#DEFINE	CIOMODE_CONSOLE
#DEFINE	DSKY_KBD
#DEFINE USEDELAY
#INCLUDE "util.asm"
#INCLUDE "time.asm"
#INCLUDE "bcd.asm"
;
#IF ((PLATFORM == PLT_SBC) | (PLATFORM == PLT_ZETA) | (PLATFORM == PLT_ZETA2))
;
; DETECT Z80 CPU SPEED USING DS-1302 RTC
;
HB_CPUSPD:
;
#IF (DSRTCENABLE)
;
	CALL	DSRTC_TSTCLK	; IS CLOCK RUNNING?
	JR	Z,HB_CPUSPD1		; YES, CONTINUE
	; MAKE SURE CLOCK IS RUNNING
	LD	HL,DSRTC_TIMDEF
	CALL	DSRTC_TIM2CLK
	LD	HL,DSRTC_BUF
	CALL	DSRTC_WRCLK
	CALL	DSRTC_TSTCLK	; NOW IS CLOCK RUNNING?
	RET	NZ
;
HB_CPUSPD1:
	; WATT FOR AN INITIAL TICK TO ALIGN, THEN WAIT
	; FOR SECOND TICK AND TO GET A FULL ONE SECOND LOOP COUNT
	CALL	HB_WAITSECS	; WAIT FOR INITIAL SECS TICK
	CALL	HB_WAITSECS	; WAIT FOR SECS TICK AGAIN, COUNT INDE
;
	LD	A,H
	OR	L
	RET	Z		; FAILURE, USE DEFAULT CPU SPEED
;
	; TIMES 4 (W/ ROUNDING) FOR CPU SPEED IN KHZ
	INC	HL
	SRL	H
	RR	L
	SLA	L
	RL	H
	SLA	L
	RL	H
	SLA	L
	RL	H
;	
	LD	(HCB + HCB_CPUKHZ),HL
	LD	DE,1000
	CALL	DIV16
	LD	A,C
	LD	(HCB + HCB_CPUMHZ),A
;
	RET
;	
HB_WAITSECS:
	; WAIT FOR SECONDS TICK
	; RETURN SECS VALUE IN A, LOOP COUNT IN DE
	; LOOP TARGET IS 250 T-STATES, SO CPU FREQ IN KHZ = LOOP COUNT * 4
	LD	HL,0		; INIT LOOP COUNTER
	CALL	HB_RDSEC	; GET SECONDS
	LD	E,A		; SAVE IT
HB_WAITSECS1:
	CALL	DLY32
	CALL	DLY8
	CALL	DLY4
	JP	$ + 3		; 10 TSTATES
;	LD	A,R		; 9 TSTATES
;	INC	BC		; 6 TSTATES
	NOP			; 4 TSTATES
	NOP			; 4 TSTATES
	NOP			; 4 TSTATES
	NOP			; 4 TSTATES
	NOP			; 4 TSTATES
;
	CALL	HB_RDSEC	; GET SECONDS
	INC	HL		; BUMP COUNTER
	CP	E		; EQUAL?
	RET	NZ		; DONE IF TICK OCCURRED
	LD	A,H		; CHECK HL
	OR	L		; ... FOR OVERFLOW
	RET	Z		; TIMEOUT, SOMETHING IS WRONG
	JR	HB_WAITSECS1	; LOOP
;
HB_RDSEC:
	; READ SECONDS BYTE INTO A
	LD	C,$81			; SECONDS REGISTER HAS CLOCK HALT FLAG
	CALL	DSRTC_CMD		; SEND THE COMMAND
	CALL	DSRTC_GET		; READ THE REGISTER
	CALL	DSRTC_END		; FINISH IT
	RET
;
#ELSE
;
	RET				; NO RTC, ABORT
;
#ENDIF
;
#ENDIF
;
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
;
; DETECT Z180 CPU SPEED USING DS-1302 RTC
;
HB_CPUSPD:
;
#IF (DSRTCENABLE)
;
	CALL	DSRTC_TSTCLK		; IS CLOCK RUNNING?
	JR	Z,HB_CPUSPD1		; YES, CONTINUE
	; MAKE SURE CLOCK IS RUNNING
	LD	HL,DSRTC_TIMDEF
	CALL	DSRTC_TIM2CLK
	LD	HL,DSRTC_BUF
	CALL	DSRTC_WRCLK
	CALL	DSRTC_TSTCLK		; NOW IS CLOCK RUNNING?
	RET	NZ
;
HB_CPUSPD1:
	; WATT FOR AN INITIAL TICK TO ALIGN, THEN WAIT
	; FOR SECOND TICK AND TO GET A FULL ONE SECOND LOOP COUNT
	CALL	HB_WAITSECS	; WAIT FOR INITIAL SECS TICK
	CALL	HB_WAITSECS	; WAIT FOR SECS TICK AGAIN, COUNT INDE
;
	LD	A,H
	OR	L
	RET	Z		; FAILURE, USE DEFAULT CPU SPEED
;
	; TIMES 8 FOR CPU SPEED IN KHZ
	SLA	L
	RL	H
	SLA	L
	RL	H
	SLA	L
	RL	H
;
	LD	(HCB + HCB_CPUKHZ),HL
	LD	DE,1000
	CALL	DIV16
	LD	A,C
	LD	(HCB + HCB_CPUMHZ),A
;
	RET
;	
HB_WAITSECS:
	; WAIT FOR SECONDS TICK
	; RETURN SECS VALUE IN A, LOOP COUNT IN DE
	; LOOP TARGET IS 250 T-STATES, SO CPU FREQ IN KHZ = LOOP COUNT * 4
	LD	HL,0		; INIT LOOP COUNTER
	CALL	HB_RDSEC	; GET SECONDS
	LD	E,A		; SAVE IT
HB_WAITSECS1:
	CALL	DLY64
	OR	A		; 7 TSTATES
	;OR	A		; 7 TSTATES
	;OR	A		; 7 TSTATES
	;OR	A		; 7 TSTATES
	NOP			; 6 TSTATES
	NOP			; 6 TSTATES
	NOP			; 6 TSTATES
	NOP			; 6 TSTATES
	;NOP			; 6 TSTATES
;
	CALL	HB_RDSEC	; GET SECONDS
	INC	HL		; BUMP COUNTER
	CP	E		; EQUAL?
	RET	NZ		; DONE IF TICK OCCURRED
	LD	A,H		; CHECK HL
	OR	L		; ... FOR OVERFLOW
	RET	Z		; TIMEOUT, SOMETHING IS WRONG
	JR	HB_WAITSECS1	; LOOP
;
HB_RDSEC:
	; READ SECONDS BYTE INTO A
	LD	C,$81			; SECONDS REGISTER HAS CLOCK HALT FLAG
	CALL	DSRTC_CMD		; SEND THE COMMAND
	CALL	DSRTC_GET		; READ THE REGISTER
	CALL	DSRTC_END		; FINISH IT
	RET
;
#ELSE
;
	RET				; NO RTC, ABORT
;
#ENDIF
;
#ENDIF
;
; PRINT VALUE OF HL AS THOUSANDTHS, IE. 0.000
;
PRTD3M:
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	E,'0'
	LD	BC,-10000
	CALL	PRTD3M1
	LD	E,0
	LD	BC,-1000
	CALL	PRTD3M1
	CALL	PC_PERIOD
	LD	BC,-100
	CALL	PRTD3M1
	LD	C,-10
	CALL	PRTD3M1
	LD	C,-1
	CALL	PRTD3M1
	POP	HL
	POP	DE
	POP	BC
	RET
PRTD3M1:
	LD	A,'0' - 1
PRTD3M2:
	INC	A
	ADD	HL,BC
	JR	C,PRTD3M2
	SBC	HL,BC
	CP	E
	JR	Z,PRTD3M3
	LD	E,0
	CALL	COUT
PRTD3M3:
	RET
;
;==================================================================================================
;   HBIOS GLOBAL DATA
;==================================================================================================
;
;HB_CONDEV	.DB	CONDEV		; ACTIVE CONSOLE DEVICE
;HB_DISPDEV	.DB	CONDEV		; INITIALLY SET TO CONDEV, SWITCHES AFTER INIT
;
IDLECOUNT	.DB	0
;
HSTDSK		.DB	0		; DISK IN BUFFER
HSTTRK		.DW	0		; TRACK IN BUFFER
HSTSEC		.DW	0		; SECTOR IN BUFFER
;
CUREMU		.DB	VDAEMU		; CURRENT VDA TERMINAL EMULATION
CURVDA		.DB	VDADEV		; CURRENT VDA TARGET FOR EMULATION
;
DIOBUF		.DW	HB_BUF		; PTR TO 1024 BYTE DISK XFR BUFFER
;
BOOTDRV		.DW	0		; BOOT DRIVE / LU
;
HB_INTSTKSAV	.DW	0		; SAVED STACK POINTER DURING INT PROCESSING
		.FILL	$40,$FF
HB_INTSTK	.EQU	$

;
STR_BANNER	.DB	"SBC HBIOS v", BIOSVER, ", ", TIMESTAMP, "$"
STR_PLATFORM	.DB	PLATFORM_NAME, "$"
;
HB_BUF		.EQU	$		; PHYSICAL DISK BUFFER
HB_END		.EXPORT	HB_END		; EXPORT ENDING ADDRESS
;
SLACK		.EQU	BNKTOP - $
		.ECHO	"HBIOS space remaining: "
		.ECHO	SLACK
		.ECHO	" bytes.\n"
;
		.END
