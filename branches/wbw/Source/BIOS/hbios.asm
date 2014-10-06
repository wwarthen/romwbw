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
	JP	0100H			; JUMP TO BOOT CODE
	.FILL	(004H - $),0FFH		; FILL TO START OF SIG PTR
	.DW	ROM_SIG
	.FILL	(008H - $),0FFH		; RST 8
	JP	HB_INVOKE
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
NAME	.DB	"ROMWBW v", BIOSVER, ", ", BIOSBLD, ", ", TIMESTAMP, 0
AUTH	.DB	"WBW",0
DESC	.DB	"ROMWBW v", BIOSVER, ", Copyright 2014, Wayne Warthen, GNU GPL v3", 0
;
	.FILL	(100H - $),0FFH		; PAD REMAINDER OF PAGE ZERO
;
;==================================================================================================
;   ROM COLD START
;==================================================================================================
;
	DI			; NO INTERRUPTS
	IM	1		; INTERRUPT MODE 1
	LD	SP,HBX_LOC	; SETUP INITIAL STACK JUST BELOW HBIOS PROXY
;
; PERFORM MINIMAL HARDWARE INITIALIZATION
;
#IFNDEF UNALOAD
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4))
	; SET BASE FOR CPU IO REGISTERS
   	LD	A,CPU_BASE
	OUT0	(CPU_ICR),A
	
	; SET DEFAULT CPU CLOCK MULTIPLIERS (XTAL / 2)
	XOR	A
	OUT0	(CPU_CCR),A
	OUT0	(CPU_CMR),A
	
	; SET DEFAULT WAIT STATES
	LD	A,$F0
	OUT0	(CPU_DCNTL),A

#IF (Z180_CLKDIV >= 1)
	; SET CLOCK DIVIDE TO 1 RESULTING IN FULL XTAL SPEED
	LD	A,$80
	OUT0	(CPU_CCR),A
#ENDIF

#IF (Z180_CLKDIV >= 2)
	; SET CPU MULTIPLIER TO 1 RESULTINT IN XTAL * 2 SPEED
	LD	A,$80
	OUT0	(CPU_CMR),A
#ENDIF
	; SET DESIRED WAIT STATES
	LD	A,0 + (Z180_MEMWAIT << 6) | (Z180_IOWAIT << 4)
	OUT0	(CPU_DCNTL),A

	; MMU SETUP
	LD	A,$80
	OUT0	(CPU_CBAR),A		; SETUP FOR 32K/32K BANK CONFIG
	XOR	A
	OUT0	(CPU_BBR),A		; BANK BASE = 0
	LD	A,(RAMSIZE + RAMBIAS - 64) >> 2
	OUT0	(CPU_CBR),A		; COMMON BASE = LAST (TOP) BANK
#ENDIF
;
#ENDIF
;
; EMIT FIRST SIGN OF LIFE TO SERIAL PORT
;
	CALL	XIO_INIT	; INIT SERIAL PORT
	LD	HL,STR_BOOT	; POINT TO MESSAGE
	CALL	XIO_OUTS	; SAY HELLO
;
; INSTALL HBIOS PROXY IN UPPER MEMORY
;
	LD	HL,HBX_IMG	; HL := SOURCE OF HBIOS PROXY IMAGE
	LD	DE,HBX_LOC	; DE := DESTINATION TO INSTALL IT
	LD	BC,HBX_SIZ	; SIZE
	LDIR			; DO THE COPY
;
; COPY OURSELVES AND LOADER TO HI RAM FOR PHASE 2
;
	LD	HL,0		; COPY FROM START OF ROM IMAGE
	LD	DE,$F000	; TO HIMEM $F000
	LD	BC,$0800	; COPY 2K
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
	.ORG	$ + $F000	; WE ARE NOW EXECUTING IN UPPER MEMORY
;
PHASE2:
	CALL	XIO_DOT		; MARK PROGRESS
;
; COPY HBIOS IMAGE FROM ROM TO RAM
;
	LD	C,BID_BIOSIMG
	LD	B,BID_BIOS
	LD	(HBX_SRCBNK),BC
	LD	HL,0
	LD	DE,0
	LD	BC,$8000
	LD	A,BID_BIOS	; RET BANK IS HBIOS
	CALL	HBX_COPY
	CALL	XIO_DOT		; MARK PROGRESS
;
; INITIALIZE HBIOS AND JUMP TO LOADER
;
	; CALL HBIOS HARDWARE INITIALIZATION
	LD	C,BID_BIOS	; HBIOS RAM PAGE
	LD	B,BF_SYSSETBNK	; HBIOS FUNC: SET BANK
	RST	08		; DO IT
	CALL	$1000		; CALL HBIOS INITIALIZATION
;
	; SETUP USER PAGE FOR HBIOS INVOCATIONS
	LD	C,BID_USR	; USER RAM PAGE
	LD	B,BF_SYSSETBNK	; HBIOS FUNC: SET BANK
	RST	08		; DO IT
	LD	A,$C3		; $C3 = JP
	LD	($08),A		; ... GOES TO FIRST BYTE OF RST 08
	LD	HL,HBX_INVOKE	; JP TARGET IS HBX_INVOKE
	LD	($09),HL	; SAVE IT
;
	JP	$F400		; JUMP TO LOADER W/ USER PAGE IN LOW MEM
;
	.FILL	$F400 - $,$FF	; PAD OUT REMAINDER OF BOOT AREA	
;
;==================================================================================================
;   LOADER
;==================================================================================================
;
	LD	C,BID_OSIMG	; OS IMAGES ROM PAGE
	LD	B,BF_SYSSETBNK	; HBIOS FUNC: SET BANK
	RST	08		; DO IT
	JP	0		; CHAIN TO IT
;
; PAD OUT REMAINDER OF LOADER AREA
;
	.ORG	$ - $F000	; RESTORE ORG
	.FILL	$1000 - $	; PAD OUT REMAINDER OF LOADER
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
	.ORG	$1000
	JP	HB_START
;	JP	HB_DISPATCH
	CALL	PANIC			; REMOVE AFTER VERIFYING UNUSED
;
;==================================================================================================
;   HBIOS INTERNAL PROXY JUMP TABLE
;==================================================================================================
;
#DEFINE		DEVENT(DEV,UNIT) \
#DEFCONT	.DB	DEV | UNIT
;
		.DB	DEVCNT
DEVMAP:
#IFDEF DEVLST
		DEVLST
#ELSE

; RAM/ROM MEMORY DISK UNITS
#IF MDENABLE
	DEVENT(DIODEV_MD,1)		; MD1: (RAM DISK)
	DEVENT(DIODEV_MD,0)		; MD0: (ROM DISK)
#ENDIF

#IF FDENABLE
	DEVENT(DIODEV_FD,0)		; FD0: (PRIMARY FLOPPY DRIVE)
	DEVENT(DIODEV_FD,1)		; FD1: (SECONDARY FLOPPY DRIVE)
#ENDIF

; RAM FLOPPY MEMORY DISK UNITS
#IF RFENABLE
	DEVENT(DIODEV_RF,0)		; RF0: (RAMFLOPPY DISK UNIT 0)
;	DEVENT(DIODEV_RF,1)		; RF1: (RAMFLOPPY DISK UNIT 1)
#ENDIF

; IDE DISK UNITS
#IF IDEENABLE
	DEVENT(DIODEV_IDE,0)		; IDE0: (IDE PRIMARY MASTER DISK)
;	DEVENT(DIODEV_IDE,1)		; IDE1: (IDE PRIMARY SLAVE DISK)
#ENDIF

; PPIDE DISK UNITS
#IF PPIDEENABLE
	DEVENT(DIODEV_PPIDE,0)		; PPIDE0: (PAR PORT IDE PRIMARY MASTER DISK)
;	DEVENT(DIODEV_PPIDE,1)		; PPIDE1: (PAR PORT IDE PRIMARY SLAVE DISK)
#ENDIF

; SD CARD DISK UNITS
#IF SDENABLE
	DEVENT(DIODEV_SD,0)		; SD0: (SD CARD DISK)
#ENDIF

; PROPIO SD CARD DISK UNITS
#IF (PRPENABLE & PRPSDENABLE)
	DEVENT(DIODEV_PRPSD,0)		; PRPSD0: (PROPIO SD DISK)
#ENDIF

; PARPORTPROP SD CARD DISK UNITS
#IF (PPPENABLE & PPPSDENABLE)
	DEVENT(DIODEV_PPPSD,0)		; PPPSD0: (PARPORTPROP SD DISK)
#ENDIF

; SIMH EMULATOR DISK UNITS
#IF HDSKENABLE
	DEVENT(DIODEV_HDSK,0)		; HDSK0: (SIMH DISK DRIVE 0)
	DEVENT(DIODEV_HDSK,1)		; HDSK1: (SIMH DISK DRIVE 1)
#ENDIF	

#ENDIF
;
DEVCNT		.EQU	($ - DEVMAP) / 1
		.ECHO	DEVCNT
		.ECHO	" devices defined.\n"
;
;==================================================================================================
;   SYSTEM INITIALIZATION
;==================================================================================================
;
HB_START:
;
; ANNOUNCE HBIOS
;
	CALL	NEWLINE
	CALL	NEWLINE
	PRTX(STR_PLATFORM)
	PRTS(" @ $")
	LD	HL,CPUFREQ
	CALL	PRTDEC
	PRTS("MHz ROM=$")
	LD	HL,ROMSIZE
	CALL	PRTDEC
	PRTS("KB RAM=$")
	LD	HL,RAMSIZE
	CALL	PRTDEC
	PRTS("KB$")
;
; DURING INITIALIZATION, CONSOLE IS ALWAYS PRIMARY SERIAL PORT
; POST-INITIALIZATION, WILL BE SWITCHED TO USER CONFIGURED CONSOLE
;
	LD	A,BOOTCON
	LD	(CONDEV),A
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
; NOW SWITCH TO USER CONFIGURED CONSOLE
;
#IF ((PLATFORM == PLT_N8) | (PLATFORM == PLT_MK4) | (PLATFORM == PLT_S100))
	LD	A,DEFCON
#ELSE
	IN	A,(RTC)		; RTC PORT, BIT 6 HAS STATE OF CONFIG JUMPER
	BIT	6,A		; BIT 6 HAS CONFIG JUMPER STATE
	LD	A,DEFCON	; ASSUME WE WANT DEFAULT CONSOLE
	JR	NZ,INITSYS1	; IF NZ, JUMPER OPEN, DEF CON IS CORRECT
	LD	A,ALTCON	; JUMPER SHORTED, USE ALTERNATE CONSOLE
INITSYS1:
#ENDIF
	LD	(CONDEV),A	; SET THE ACTIVE CONSOLE DEVICE
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
	CP	CIODEV_CRT
	JR	Z,CIOEMU
	CP	CIODEV_CONSOLE
	JR	Z,CIOCON
	CALL	PANIC
;
CIOEMU:
	LD	A,B
	ADD	A,BF_EMU - BF_CIO	; TRANSLATE FUNCTION CIOXXX -> EMUXXX
	LD	B,A
	JP	EMU_DISPATCH
;
CIOCON:
	LD	A,(CONDEV)
	LD	C,A
	JR	CIO_DISPATCH
;
;==================================================================================================
;   DISK I/O DEVICE DISPATCHER
;==================================================================================================
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
	DEC	A		; FUNCTION = DIODEVCNT?
	JR	Z,DIO_DEVCNT	; YES, HANDLE IT
	DEC	A		; FUNCTION = DIODEVINF?
	JR	Z,DIO_DEVINF	; YES, HANDLE IT
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
DIO_DEVCNT:
	LD	A,(DEVMAP - 1)	; GET DEVICE COUNT
	LD	B,A		; PUT IT IN B
	XOR	A		; SIGNALS SUCCESS
	RET
;
; DISK: GET DEVICE INFO
;
DIO_DEVINF:
	LD	HL,DEVMAP - 1	; POINT TO DEVICE MAP ENTRY COUNT
	LD	B,(HL)		; ENTRY COUNT TO B
	LD	A,C		; INDEX TO A
	CP	B		; CHECK INDEX AGAINST MAX VALUE (INDEX - COUNT)
	JR	NC,DIO_DEVINF1	; IF INDEX TOO HIGH, ERR
	INC	HL		; BUMP TO START OF DEV MAP ENTRIES
	CALL	ADDHLA		; AND POINT TO REQUESTED INDEX
	LD	C,(HL)		; DEVICE/UNIT TO C
	XOR	A		; SIGNAL SUCCESS
	RET			; DONE

DIO_DEVINF1:
	OR	$FF		; SIGNAL ERROR
	RET			; RETURN
;
;==================================================================================================
;   REAL TIME CLOCK DEVICE DISPATCHER
;==================================================================================================
;
; ROUTE CALL TO REAL TIME CLOCK DRIVER (NOT YET IMPLEMENTED)
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
#IF (TTYENABLE)
	DEC	A		; 1 = TTY
	JP	Z,TTY_DISPATCH
#ENDIF
#IF (ANSIENABLE)
	DEC	A		; 2 = ANSI
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
#IF (VDUENABLE & (DEFVDA == VDADEV_VDU))
VDA_DISPADR	.SET	VDU_DISPVDA
#ENDIF
#IF (CVDUENABLE & (DEFVDA == VDADEV_CVDU))
VDA_DISPADR	.SET	CVDU_DISPVDA
#ENDIF
#IF (VDUENABLE & (DEFVDA == VDADEV_UPD7220))
VDA_DISPADR	.SET	UPD7220_DISPVDA
#ENDIF
#IF (N8VENABLE & (DEFVDA == VDADEV_N8V))
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
	JR	Z,SYS_ATTR	; $F4
	DEC	A
	;JR	Z,SYS_XXXX	; $F5
	DEC	A
	JR	Z,SYS_GETVER	; $F6
	CALL	PANIC		; INVALID
;
; SET ACTIVE MEMORY BANK AND RETURN PREVIOUSLY ACTIVE MEMORY BANK
;   NOTE THAT IT GOES INTO EFFECT AS HBIOS IS EXITED
;   HERE, WE JUST SET THE CURRENT BANK
;   CALLER MUST EXTABLISH UPPER MEMORY STACK BEFORE INVOKING THIS FUNCTION!
;
SYS_SETBNK:
	LD	A,(HBX_CURBNK)	; GET THE PREVIOUS ACTIVE MEMORY BANK
	PUSH	AF		; SAVE IT
	LD	A,C		; LOAD THE NEW BANK REQUESTED
	LD	(HBX_CURBNK),A	; SET IT FOR ACTIVATION UPON HBIOS RETURN
	POP	AF		; GET PREVIOUS BANK INTO A
	OR	A
	RET
;
; GET ACTIVE MEMORY BANK
;
SYS_GETBNK:
	LD	A,(HBX_CURBNK)	; GET THE ACTIVE MEMORY BANK
	OR	A
	RET
;
; PERFORM MEMORY COPY POTENTIALLY ACROSS BANKS
;
SYS_COPY:
	PUSH	IX
	POP	BC
	LD	A,BID_BIOS	; RET BANK IS HBIOS
	CALL	HB_COPY
	XOR	A
	RET
;
; SET BANKS FOR EXTENDED (INTERBANK) MEMORY COPY
;
SYS_XCOPY:
	LD	(HBX_SRCBNK),DE
	XOR	A
	RET
;
; GET/SET SYSTEM ATTRIBUTE
;   C: ATTRIBUTE ID (BIT 7 INDICATES GET/SET, ON=SET)
;   DE: ATTRIBUTE VALUES
;
SYS_ATTR:
	LD	A,C		; LOAD ATTRIB ID
	AND	$7F		; MASK OUT GET/SET BIT
	RLCA			; MULTIPLY BY 2 FOR WORD OFFSET
	LD	HL,HB_ATTR	; POINT TO START OF ATTR TABLE
	CALL	ADDHLA		; ADD THE OFFSET
	BIT	7,C		; TEST HIGH BIT
	JR	NZ,SYS_ATTR1	; IF SET, GO TO SET OPER
	LD	E,(HL)		; GET LSB TO E
	INC	HL		; NEXT BYTE
	LD	D,(HL)		; GET MSB TO D
	XOR	A
	RET
SYS_ATTR1:
	LD	(HL),E		; SAVE LSB
	INC	HL		; NEXT BYTE
	LD	(HL),D		; SAVE MSB
	XOR	A
	RET
;
; GET THE CURRENT HBIOS VERSION
;   RETURNS VERSION IN DE AS BCD
;     D: MAJOR VERION IN TOP 4 BITS, MINOR VERSION IN LOW 4 BITS
;     E: UPDATE VERION IN TOP 4 BITS, PATCH VERSION IN LOW 4 BITS
;
SYS_GETVER:
	LD	DE,0 | (RMJ << 12) | (RMN << 8) | (RUP << 4) | RTP
	XOR	A
	RET
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
#INCLUDE "util.asm"
#INCLUDE "time.asm"
;
;==================================================================================================
;   HBIOS GLOBAL DATA
;==================================================================================================
;
CONDEV		.DB	BOOTCON
;
IDLECOUNT	.DB	0
;
HSTDSK		.DB	0		; DISK IN BUFFER
HSTTRK		.DW	0		; TRACK IN BUFFER
HSTSEC		.DW	0		; SECTOR IN BUFFER
;
CUREMU		.DB	DEFEMU		; CURRENT EMULATION
CURVDA		.DB	DEFVDA		; CURRENT VDA TARGET FOR EMULATION
;
DIOBUF		.DW	HB_BUF		; PTR TO 1024 BYTE DISK XFR BUFFER
;
BOOTDRV		.DW	0		; BOOT DRIVE / LU
;
STR_BANNER	.DB	"N8VEM HBIOS v", BIOSVER, ", ", BIOSBLD, ", ", TIMESTAMP, "$"
STR_PLATFORM	.DB	PLATFORM_NAME, "$"
;
HB_ATTR:	; ATTRIBUTE TABLE, 128 WORD VALUES
AT_BOOTVOL	.DW	0		; BOOT VOLUME, MSB=DEV/UNIT, LSB=LU
AT_BOOTROM	.DW	0		; BANK ID OF ROM PAGE BOOTED
		.FILL	HB_ATTR + 256 - $,0	; FILL OUT UNUSED ENTRIES
;
;==================================================================================================
;   FILL REMAINDER OF HBIOS
;==================================================================================================
;
SLACK		.EQU	(HBX_LOC - $8000 - $)
		.FILL	SLACK,0FFH
;
		.ECHO	"HBIOS space remaining: "
		.ECHO	SLACK
		.ECHO	" bytes.\n"
;
;==================================================================================================
;   HBIOS UPPER MEMORY PROXY
;==================================================================================================
;
; THE FOLLOWING CODE IS RELOCATED TO THE TOP OF MEMORY TO HANDLE INVOCATION DISPATCHING
; AFTER RELOCATION THIS AREA (1K) IS REUSED AS THE HBIOS PHYSICAL DISK READ/WRITE BUFFER 
;
HB_BUF		.EQU	$
HBX_IMG		.EQU	$
		.ORG	HBX_LOC
;
;;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;; SETBNK - Switch Memory Bank to Bank in A.
;;   Preserve all Registers including Flags.
;;   Does NOT update current bank.
;;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
HBX_SETBNK:
;
#IF ((PLATFORM == PLT_N8VEM) | (PLATFORM == PLT_ZETA))
	OUT	(MPCL_ROM),A
	OUT	(MPCL_RAM),A
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
	OUT0	(CPU_BBR),A
	LD	A,DEFACR | 80H
	OUT0	(ACR),A
	RET
;
HBX_ROM:
	OUT0	(RMAP),A
	XOR	A
	OUT0	(CPU_BBR),A
	LD	A,DEFACR
	OUT0	(ACR),A
	RET
;
#ENDIF
#IF (PLATFORM == PLT_MK4)
	RLCA
	RLCA
	RLCA
	OUT0	(CPU_BBR),A
#ENDIF
	RET
;
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
; Copy Data - Possibly between banks.  This resembles CP/M 3, but
;  usage of the HL and DE registers is reversed.
; Enter: A = Bank activated on exit
;        HL = Source Address
;	 DE = Destination Address
;	 BC = Number of bytes to copy
; Exit : None
; Uses : AF,BC,DE,HL
;
;::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;
HBX_COPY:
	LD	(HBX_RETBNK),A	; Save the return bank
	CALL	HBX_COPY1	; Do the work
	LD	A,(HBX_RETBNK)	; Set desired return bank
	JR	HBX_SETBNK	; .. activate and return
;
HBX_COPY1:	; Setup for copy loop
	LD	(HBX_SRCADR),HL	; Init working source adr
	LD	(HBX_DSTADR),DE	; Init working dest adr 
	LD	H,B		; Move bytes to copy from BC...
	LD	L,C		;   to HL to use as byte counter
;
HBX_COPY2:	; Copy loop
	INC	L		; Set ZF to indicate...
	DEC	L		;   if a partial page copy is needed
	LD	BC,$100		; Assume a full page copy, 100H bytes
	JR	Z,HBX_COPY3	; If full page copy, go do it
	DEC	B		; Otherwise, setup for partial page copy
	LD	C,L		; by making BC := 0
;
HBX_COPY3:
	PUSH	HL		; Save bytes left to copy
	CALL	HBX_COPY4	; Do it
	POP	HL		; Recover bytes left to copy
	XOR	A		; Clear CF
	SBC	HL,BC		; Reflect bytes copied in HL
	JR	NZ,HBX_COPY2	; If any left, then loop
;
	LD	HL,(HBX_DEFBNK)	; Get TPA Bank #
	LD	H,L		; .to both H and L
	LD	(HBX_SRCBNK),HL	; ..set Source & Destination Bank # to default
;
	RET			; Done
;
HBX_COPY4:	; Switch to source bank
	LD	A,(HBX_SRCBNK)	; Get source bank
	CALL	HBX_SETBNK	; Set bank without making it current
;
	; Copy BC bytes from HL -> BUF, allow HL to increment
	PUSH	BC		; Save copy length
	LD	HL,(HBX_SRCADR)	; Point to source adr
	LD	DE,HBX_BUF	; Setup buffer as interim destination
	LDIR			; Copy BC bytes: src -> buffer
	LD	(HBX_SRCADR),HL	; Update source adr
	POP	BC		; Recover copy length
;	
	; Switch to dest bank
	LD	A,(HBX_DSTBNK)	; Get destination bank
	CALL	HBX_SETBNK	; Set bank without making it current
;
	; Copy BC bytes from BUF -> HL, allow DE to increment
	PUSH	BC		; Save copy length
	LD	HL,HBX_BUF	; Use the buffer as source now
	LD	DE,(HBX_DSTADR)	; Setup final destination for copy
	LDIR			; Copy BC bytes: buffer -> dest
	LD	(HBX_DSTADR),DE	; Update dest adr
	POP	BC		; Recover copy length
;
	RET			; Done
;
;==================================================================================================
;   HBIOS ENTRY FOR RST 08 PROCESSING
;==================================================================================================
;
HBX_INVOKE:
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME

	LD	A,BID_BIOS	; HBIOS BANK
	CALL	HBX_SETBNK	; SELECT IT

	CALL	HB_DISPATCH	; CALL HBIOS FUNCTION DISPATCHER

	PUSH	AF		; SAVE AF (FUNCTION RETURN)
	LD	A,(HBX_CURBNK)	; GET ENTRY BANK
	CALL	HBX_SETBNK	; SELECT IT
	POP	AF		; RESTORE AF

	LD	SP,(HBX_STKSAV)	; RESTORE ORIGINAL STACK FRAME

	RET			; RETURN TO CALLER
;
;==================================================================================================
;   HBIOS INTERBANK MEMORY COPY BUFFER
;==================================================================================================
;
	.FILL	$FE00 - $,$FF	; FILL TO START OF BUFFER PAGE
HBX_BUF	.FILL	$100,0		; INTER-BANK COPY BUFFER
;
;==================================================================================================
;   HBIOS INTERRUPT VECTOR TABLE
;==================================================================================================
;
	.FILL	$FF00 - $,$FF	; FILL TO START OF LAST PAGE
;
; AREA RESERVED FOR UP TO 16 INTERRUPT VECTOR ENTRIES (MODE 2)
;
HBX_IVT:
	.FILL	$20,$FF
;
;==================================================================================================
;	Load  A,(HL)  from  Alternate  Bank  (in Reg C)
;==================================================================================================
;
HBX_FRGETB:
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME
	PUSH	BC
	LD	A,C
	DI
	CALL	HBX_SETBNK	; SELECT IT
	LD	C,(HL)
	LD	A,(HBX_CURBNK)
	CALL	HBX_SETBNK	; SELECT IT
	EI
	LD	A,C
	POP	BC
	LD	SP,(HBX_STKSAV)	; RESTORE ORIGINAL STACK FRAME
	RET
;
;==================================================================================================
;	Load  DE,(HL)  from  Alternate  Bank
;==================================================================================================
;
HBX_FRGETW:
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME
	LD	A,C
	DI
	CALL	HBX_SETBNK	; SELECT IT
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	LD	A,(HBX_CURBNK)
	CALL	HBX_SETBNK	; SELECT IT
	EI
	LD	SP,(HBX_STKSAV)	; RESTORE ORIGINAL STACK FRAME
	RET
;
;==================================================================================================
;	Load  (HL),A  to  Alternate  Bank  (in Reg C)
;==================================================================================================
;
HBX_FRPUTB:	
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME
	PUSH	BC
	LD	B,A
	LD	A,C
	DI
	CALL	HBX_SETBNK	; SELECT IT
	LD	(HL),B
	LD	A,(HBX_CURBNK)
	CALL	HBX_SETBNK	; SELECT IT
	EI
	POP	BC
	LD	SP,(HBX_STKSAV)	; RESTORE ORIGINAL STACK FRAME
	RET
;
;==================================================================================================
;	Load  (HL),DE  to  Alternate  Bank
;==================================================================================================
;
HBX_FRPUTW:	
	LD	(HBX_STKSAV),SP	; SAVE ORIGINAL STACK FRAME
	LD	SP,HBX_STACK	; SETUP NEW STACK FRAME
	LD	A,C
	DI
	CALL	HBX_SETBNK	; SELECT IT
	LD	(HL),E
	INC	HL
	LD	(HL),D
	DEC	HL
	LD	A,(HBX_CURBNK)
	CALL	HBX_SETBNK	; SELECT IT
	EI
	LD	SP,(HBX_STKSAV)	; RESTORE ORIGINAL STACK FRAME
	RET
;
; PRIVATE DATA
;
HBX_STKSAV	.DW	0		; Saved stack pointer during HBIOS calls
HBX_RETBNK	.DB	0		; Used to save bank to activate on ret
HBX_SAVBNK	.DB	0		; Place to save entry bank during HB processing
HBX_DEFBNK	.DB	BID_USR		; Default bank number
HBX_SRCADR	.DW	0		; Copy Source Address
HBX_DSTADR	.DW	0		; Copy Destination Address
;
; HBIOS IDENTIFICATION DATA BLOCK
;
HBX_IDENT:
	.DB	'W',~'W'		; MARKER
	.DB	RMJ << 4 | RMN		; FIRST BYTE OF VERSION INFO
	.DB	RUP << 4 | RTP		; SECOND BYTE OF VERSION INFO
;
; PRIVATE STACK
;
HBX_STKSIZ	.EQU	(HBX_END - $ - $10)
		.ECHO	"STACK space remaining: "
		.ECHO	HBX_STKSIZ
		.ECHO	" bytes.\n"
;
		.FILL	HBX_STKSIZ,$FF
HBX_STACK	.EQU	$
;
; TOP 16 BYTES OF HBIOS PROXY ARE RESERVED
;
HB_INVOKE:	JP	HBX_INVOKE	; FIXED ADR ENTRY FOR HBX_INVOKE (ALT FOR RST 08)
HB_SETBNK:	JP	HBX_SETBNK	; FIXED ADR ENTRY FOR HBX_SETBNK
HB_COPY:	JP	HBX_COPY	; FIXED ENTRY FOR HBX_BNKCPY
		.DW	0		; FILLER, RESERVED FOR FUTURE HBIOS USE
HBX_SRCBNK	.DB	BID_USR		; SOURCE BANK FOR NEXT HBX_BNKCPY
HBX_DSTBNK	.DB	BID_USR		; DESTINATION BANK FOR NEXT HBX_BNKCPY
HBX_CURBNK	.DB	BID_BOOT	; CURRENTLY ACTIVE LOW MEMORY BANK ID
		.DW	HBX_IDENT	; ADDRESS OF HBIOS IDENT INFO DATA BLOCK
;
	.END
