;
;==================================================================================================
; PARPORTPROP DRIVER
;==================================================================================================
;
; TODO:
;
PPP_IO		.EQU	PPPBASE + 0	; PPP DATA I/O (PPI PORT A)
PPP_CTL		.EQU	PPPBASE + 2	; PPP CTL LINES (PPI PORT C)
PPP_PPICTL	.EQU	PPPBASE + 3	; PPI CONTROL PORT
;
		DEVECHO	"PPP: IO="
		DEVECHO	PPP_IO
		DEVECHO	"\n"
;
; COMMAND BYTES
;
PPP_CMDNOP	.EQU	$00		; DO NOTHING
PPP_CMDECHOBYTE	.EQU	$01		; RECEIVE A BYTE, INVERT IT, SEND IT BACK
PPP_CMDECHOBUF	.EQU	$02		; RECEIVE 512 BYTE BUFFER, SEND IT BACK
;
PPP_CMDDSKRES	.EQU	$10		; RESTART SD CARD SUPPORT
PPP_CMDDSKSTAT	.EQU	$11		; SEND LAST SD CARD STATUS (4 BYTES)
PPP_CMDDSKPUT	.EQU	$12		; PPI -> SECTOR BUFFER -> PPP
PPP_CMDDSKGET	.EQU	$13		; PPP -> SECTOR BUFFER -> PPI
PPP_CMDDSKRD	.EQU	$14		; READ SCTOR FROM SD CARD INTO PPP BUFFER, RETURN 1 BYTE STATUS
PPP_CMDDSKWR	.EQU	$15		; WRITE SECTOR TO SD CARD FROM PPP BUFFER, RETURN 1 BYTE STATUS
PPP_CMDDSKTYPE	.EQU	$16		; GET SD CARD TYPE
PPP_CMDDSKCAP	.EQU	$17		; GET CURRENT DISK CAPACITY
PPP_CMDDSKCSD	.EQU	$18		; GET CURRENT SD CARD CSD REGISTER
;
PPP_CMDVIDOUT	.EQU	$20		; WRITE A BYTE TO THE TERMINAL EMULATOR
;
PPP_CMDKBDSTAT	.EQU	$30		; RETURN A BYTE WITH NUMBER OF CHARACTERS IN BUFFER
PPP_CMDKBDRD	.EQU	$31		; RETURN A CHARACTER, WAIT IF NECESSARY
;
PPP_CMDSPKTONE	.EQU	$40		; EMIT SPEAKER TONE AT SPECIFIED FREQUENCY AND DURATION
;
PPP_CMDSIOINIT	.EQU	$50		; RESET SERIAL PORT AND ESTABLISH A NEW BAUD RATE (4 BYTE BAUD RATE)
PPP_CMDSIORX	.EQU	$51		; RECEIVE A BYTE IN FROM SERIAL PORT
PPP_CMDSIOTX	.EQU	$52		; TRANSMIT A BYTE OUT OF THE SERIAL PORT
PPP_CMDSIORXST	.EQU	$53		; SERIAL PORT RECEIVE STATUS (RETURNS # BYTES OF RX BUFFER USED)
PPP_CMDSIOTXST	.EQU	$54		; SERIAL PORT TRANSMIT STATUS (RETURNS # BYTES OF TX BUFFER SPACE AVAILABLE)
PPP_CMDSIORXFL	.EQU	$55		; SERIAL PORT RECEIVE BUFFER FLUSH
PPP_CMDSIOTXFL	.EQU	$56		; SERIAL PORT TRANSMIT BUFFER FLUSH (NOT IMPLEMENTED)
;
PPP_CMDRESET	.EQU	$F0		; SOFT RESET PROPELLER
PPP_CMDVER	.EQU	$F1		; SEND FIRMWARE VERSION
;
; GLOBAL PARPORTPROP INITIALIZATION
;
PPP_INIT:
	CALL	NEWLINE			; FORMATTING
	PRTS("PPP: IO=0x$")
	LD	A,PPPBASE
	CALL	PRTHEXBYTE
;
	CALL	PPP_INITPPP		; INIT PPP BOARD
	RET	NZ			; BAIL OUT ON ERROR
;
	CALL	PPP_DETECT		; DETECT PPP PRESENCE
	;CALL	PC_SPACE		; *DEBUG*
	;CALL	PRTHEXWORD		; *DEBUG*
	LD	DE,PPP_STR_NOHW		; PREPARE FOR NOT PRESENT
	JP	NZ,WRITESTR		; BAIL OUT WITH NZ IF NOT DETECTED
;
	CALL	PPP_GETVER		; GET F/W VERSION
	RET	NZ			; ABORT ON FAILURE
;
	; PRINT FIRMWARE VERSION
	PRTS(" F/W=$")
	LD	HL,PPP_FWVER
	CALL	LD32
	LD	A,D
	CALL	PRTDECB
	CALL	PC_PERIOD
	LD	A,E
	CALL	PRTDECB
	CALL	PC_PERIOD
	CALL	PRTDEC
;
	; CHECK F/W VERSION & NOTIFY USER IF UPGRADE REQUIRED
	LD	HL,PPP_FWVER
	CALL	LD32
	XOR	A
	CP	D
	JR	NZ,PPP_INIT1
	CP	E
	JR	NZ,PPP_INIT1
	LD	DE,PPP_STR_UPGRADE
	CALL	WRITESTR
;
PPP_INIT1:
	CALL	PPPCON_INIT		; CONSOLE INITIALIZATION
	CALL	PPPSD_INIT		; SD CARD INITIALIZATION
;
	RET
;
;
;
PPP_INITPPP:
	; SETUP PARALLEL PORT (8255)
	LD	A,%11000010		; PPI MODE 2 (BI HANDSHAKE), PC0-2 OUT, PB IN
	OUT	(PPP_PPICTL),A		; NOTE: ALL OUTPUTS SET TO LOGIC ZERO ON MODE CHANGE
	CALL	DELAY			; PROBABLY NOT NEEDED

	; RESET PROPELLER
	LD	A,%00000101		; SET PC2 (ASSERT PROP RESET LINE)
	OUT	(PPP_PPICTL),A
	CALL	DELAY			; PROBABLY NOT NEEDED
	IN	A,(PPP_IO)		; CLEAR GARBAGE???
	CALL	DELAY			; PROBABLY NOT NEEDED
	LD	A,%00000001		; SET PC0 (CMD FLAG)
	OUT	(PPP_PPICTL),A		; DO IT
	LD	A,PPP_CMDRESET		; RESET COMMAND
	CALL	PPP_PUTBYTE		; SEND IT
	CALL	DELAY			; DELAY FOR PPP TO PROCESS COMMAND
	LD	A,%00000000		; CLEAR PC0 (CMD FLAG)
	OUT	(PPP_PPICTL),A		; DO IT
	LD	A,%00000100		; CLEAR PC2 (DEASSERT PROP RESET LINE)
	OUT	(PPP_PPICTL),A		; DO IT
	;CALL	DELAY			; PROBABLY NOT NEEDED
	LD	DE,1024			; ONE SECOND
	CALL	VDELAY			; ... DELAY

	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPP_DETECT:
	LD	BC,4096			; TRY FOR ABOUT 4 SECONDS
PPP_DETECT1:
	LD	DE,64			; 1 MS
	CALL	VDELAY

	IN	A,(PPP_CTL)
	BIT	5,A
	JR	Z,PPP_DETECT2

	IN	A,(PPP_IO)
	;CALL	PC_SPACE
	;CALL	PRTHEXBYTE
	CP	$AA
	RET	Z			; RETURN IF MATCH
;
PPP_DETECT2:
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,PPP_DETECT1
	OR	$FF			; SIGNAL FAILURE
	RET
;
;
;
PPP_GETVER:
#IF (PPPSDTRACE >= 3)
	CALL	PPP_PRTPREFIX
	PRTS(" VER$")
#ENDIF
	LD	D,PPP_CMDVER		; COMMAND = GET VERSION
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ
	LD	B,4			; GET 4 BYTES
	LD	HL,PPP_FWVER
PPP_GETVER1:
	CALL	PPP_GETBYTE
	LD	(HL),A
	INC	HL
	DJNZ	PPP_GETVER1
;
#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	HL,PPP_FWVER
	CALL	LD32
	CALL	PRTHEX32
#ENDIF
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPP_SNDCMD:
	IN	A,(PPP_IO)		; DISCARD ANYTHING PENDING
	; WAIT FOR OBF HIGH (OUTPUT BUFFER TO BE EMPTY)
	IN	A,(PPP_CTL)
	BIT	7,A
	JR	Z,PPP_SNDCMD

	LD	A,%00000001		; SET CMD FLAG
	OUT	(PPP_PPICTL),A		; SEND IT

PPP_SNDCMD0:
	IN	A,(PPP_CTL)
	BIT	7,A
	JR	Z,PPP_SNDCMD0
	LD	A,D
	OUT	(PPP_IO),A

PPP_SNDCMD1:
	; WAIT FOR OBF HIGH (BYTE HAS BEEN RECEIVED)
	IN	A,(PPP_CTL)
	BIT	7,A
	JR	Z,PPP_SNDCMD1
	; TURN OFF CMD
	LD	A,%00000000		; CLEAR CMD FLAG
	OUT	(PPP_PPICTL),A

	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPP_PUTBYTE:
	PUSH	AF
PPP_PUTBYTE1:
	IN	A,(PPP_CTL)
	BIT	7,A
	JR	Z,PPP_PUTBYTE1
	POP	AF
	OUT	(PPP_IO),A
	RET
;
;
;
PPP_GETBYTE:
	IN	A,(PPP_CTL)
	BIT	5,A
	JR	Z,PPP_GETBYTE
	IN	A,(PPP_IO)
	RET
;
; PRINT DIAGNONSTIC PREFIX
;
PPP_PRTPREFIX:
	CALL	NEWLINE
	PRTS("PPP:$")
	RET
;
;
;
PPP_STR_NOHW		.TEXT	" NOT PRESENT$"
PPP_STR_UPGRADE		.TEXT	" !!!UPGRADE REQUIRED!!!$"
;
PPP_FWVER		.DB	$00, $00, $00, $00	; MMNNBBB (M=MAJOR, N=MINOR, B=BUILD)
;
;==================================================================================================
; PARPORTPROP CONSOLE DRIVER
;==================================================================================================
;
PPPCON_ROWS	.EQU	29		; PROPELLER VGA DISPLAY ROWS (30 - 1 STATUS LINES)
PPPCON_COLS	.EQU	80		; PROPELLER VGA DISPLAY COLS
;
		DEVECHO	"PPPCON: ENABLED\n"
;
PPPCON_INIT:
	CALL	NEWLINE
	PRTS("PPPCON:$")
;
	; DISPLAY CONSOLE DIMENSIONS
	CALL	PC_SPACE
	LD	A,PPPCON_COLS
	CALL	PRTDECB
	LD	A,'X'
	CALL	COUT
	LD	A,PPPCON_ROWS
	CALL	PRTDECB
	CALL	PRTSTRD
	.TEXT	" TEXT (ANSI)$"
;
; ADD OURSELVES TO CIO DISPATCH TABLE
;
	LD	D,0			; PHYSICAL UNIT IS ZERO
	LD	E,CIODEV_PPPCON		; DEVICE TYPE
	LD	BC,PPPCON_FNTBL		; BC := FUNCTION TABLE ADDRESS
	CALL	CIO_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED
	LD	(HCB + HCB_CRTDEV),A	; SET OURSELVES AS THE CRT DEVICE
;
	XOR	A
	RET
;
; DRIVER FUNCTION TABLE
;
PPPCON_FNTBL:
	.DW	PPPCON_IN
	.DW	PPPCON_OUT
	.DW	PPPCON_IST
	.DW	PPPCON_OST
	.DW	PPPCON_INITDEV
	.DW	PPPCON_QUERY
	.DW	PPPCON_DEVICE
#IF (($ - PPPCON_FNTBL) != (CIO_FNCNT * 2))
	.ECHO	"*** INVALID PPPCON FUNCTION TABLE ***\n"
#ENDIF
;
; CHARACTER INPUT
;   WAIT FOR A CHARACTER AND RETURN IT IN E
;
PPPCON_IN:
	CALL	PPPCON_IST		; CHECK FOR CHAR PENDING
	JR	Z,PPPCON_IN		; WAIT FOR IT IF NECESSARY
	LD	D,PPP_CMDKBDRD		; CMD = KEYBOARD READ
	CALL	PPP_SNDCMD		; SEND COMMAND
	CALL	PPP_GETBYTE		; GET CHARACTER READ
	LD	E,A			; PUT IN E
	XOR	A			; CLEAR A (SUCCESS)
	RET				; AND RETURN
;
; CHARACTER INPUT STATUS
;   RETURN STATUS IN A, 0 = NOTHING PENDING, > 0 CHAR PENDING
;
PPPCON_IST:
	LD	D,PPP_CMDKBDSTAT	; CMD = KEYBOARD STATUS
	CALL	PPP_SNDCMD		; SEND COMMAND
	CALL	PPP_GETBYTE		; GET RESPONSE
	OR	A			; SET FLAGS
	RET	NZ			; A <> 0, CHAR(S) PENDING
	JP	CIO_IDLE		; OTHERWISE RET VIA IDLE PROCESSING
;
; CHARACTER OUTPUT
;   WRITE CHARACTER IN E
;
PPPCON_OUT:
	CALL	PPPCON_OST		; CHECK FOR OUTPUT READY
	JR	Z,PPPCON_OUT		; WAIT IF NECESSARY
	LD	D,PPP_CMDVIDOUT		; CMD = VIDEO OUTPUT
	CALL	PPP_SNDCMD		; SEND COMMAND
	LD	A,E			; MOVE TO A
	CALL	PPP_PUTBYTE		; SEND IT
	RET				; RETURN
;
; CHARACTER OUTPUT STATUS
;   RETURN STATUS IN A, 0 = NOT READY, > 0 READY TO SEND
;   CONSOLE IS ALWAYS READY TO SEND (SYNCHRONOUS OUTPUT)
;
PPPCON_OST:
	XOR	A			; SET A=$01 TO SIGNAL READY
	INC	A
	RET
;
;
;
PPPCON_INITDEV:
	SYSCHKERR(ERR_NOTIMPL)
	RET
;
;
;
PPPCON_QUERY:
	LD	DE,0
	LD	HL,0
	XOR	A
	RET
;
;
;
PPPCON_DEVICE:
	LD	D,CIODEV_PPPCON		; D := DEVICE TYPE
	LD	E,0			; E := DEVICE NUM, ALWAYS 0
	LD	C,$BF			; C := DEVICE TYPE, 0xBF IS PROP TERM
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,PPPBASE		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;==================================================================================================
; PARPORTPROP SD CARD DRIVER
;==================================================================================================
;
; SD CARD TYPE
;
PPPSD_TYPEUNK	.EQU	0		; CARD TYPE UNKNOWN/UNDETERMINED
PPPSD_TYPEMMC	.EQU	1		; MULTIMEDIA CARD (MMC STANDARD)
PPPSD_TYPESDSC	.EQU	2		; SDSC CARD (V1)
PPPSD_TYPESDHC	.EQU	3		; SDHC CARD (V2)
PPPSD_TYPESDXC	.EQU	4		; SDXC CARD (V3)
;
; SD CARD STATUS (PPPSD_STAT)
;
PPPSD_STOK	.EQU	0		; OK
PPPSD_STINVUNIT	.EQU	-1		; INVALID UNIT
PPPSD_STRDYTO	.EQU	-2		; TIMEOUT WAITING FOR CARD TO BE READY
PPPSD_STINITTO	.EQU	-3		; INITIALIZATOIN TIMEOUT
PPPSD_STCMDTO	.EQU	-4		; TIMEOUT WAITING FOR COMMAND RESPONSE
PPPSD_STCMDERR	.EQU	-5		; COMMAND ERROR OCCURRED (REF SD_RC)
PPPSD_STDATAERR	.EQU	-6		; DATA ERROR OCCURRED (REF SD_TOK)
PPPSD_STDATATO	.EQU	-7		; DATA TRANSFER TIMEOUT
PPPSD_STCRCERR	.EQU	-8		; CRC ERROR ON RECEIVED DATA PACKET
PPPSD_STNOMEDIA	.EQU	-9		; NO MEDIA IN CONNECTOR
PPPSD_STWRTPROT	.EQU	-10		; ATTEMPT TO WRITE TO WRITE PROTECTED MEDIA
;
; PPPSD DEVICE CONFIGURATION
;
PPPSD_DEVCNT	.EQU	1		; ONE DEVICE SUPPORTED
PPPSD_CFGSIZ	.EQU	12		; SIZE OF CFG TBL ENTRIES
;
; PER DEVICE DATA OFFSETS
;
PPPSD_DEV	.EQU	0		; OFFSET OF DEVICE NUMBER (BYTE)
PPPSD_STAT	.EQU	1		; LAST STATUS (BYTE)
PPPSD_TYPE	.EQU	2		; DEVICE TYPE (BYTE)
PPPSD_FLAGS	.EQU	3		; FLAG BITS BIT 0=CF, 1=LBA (BYTE)
PPPSD_MEDCAP	.EQU	4		; MEDIA CAPACITY (DWORD)
PPPSD_LBA	.EQU	8		; OFFSET OF LBA (DWORD)
;
PPPSD_CFGTBL:
	; DEVICE 0
	.DB	0			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DB	0			; DEVICE TYPE
	.DB	0			; FLAGS BYTE
	.DW	0,0			; DEVICE CAPACITY
	.DW	0,0			; CURRENT LBA
;
#IF ($ - PPPSD_CFGTBL) != (PPPSD_DEVCNT * PPPSD_CFGSIZ)
	.ECHO	"*** INVALID PPPSD CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
		DEVECHO	"PPPSD: ENABLED\n"
;
; SD CARD INITIALIZATION
;
PPPSD_INIT:
;
; SETUP THE DISPATCH TABLE ENTRIES
;
	LD	B,PPPSD_DEVCNT		; LOOP CONTROL
	LD	IY,PPPSD_CFGTBL		; START OF CFG TABLE
PPPSD_INIT0:
	PUSH	BC			; SAVE LOOP CONTROL
	LD	BC,PPPSD_FNTBL		; BC := FUNC TABLE ADR
	PUSH	IY			; CFG ENTRY POINTER
	POP	DE			; COPY TO DE
	CALL	DIO_ADDENT		; ADD ENTRY, BC IS NOT DESTROYED
	LD	BC,PPPSD_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	POP	BC			; RESTORE BC
	DJNZ	PPPSD_INIT0		; LOOP AS NEEDED
;
	; INITIALIZE INDIVIDUAL UNIT(S) AND DISPLAY DEVICE INVENTORY
	LD	B,PPPSD_DEVCNT		; INIT LOOP COUNTER TO DEVICE COUNT
	LD	IY,PPPSD_CFGTBL		; START OF CFG TABLE
PPPSD_INIT1:
	PUSH	BC			; SAVE LOOP COUNTER/INDEX
	CALL	PPPSD_INITUNIT		; INITIALIZE IT
#IF (PPPSDTRACE < 2)
	CALL	NZ,PPPSD_PRTSTAT	; IF ERROR, SHOW IT
#ENDIF
	LD	BC,PPPSD_CFGSIZ		; SIZE OF CFG ENTRY
	ADD	IY,BC			; BUMP IY TO NEXT ENTRY
	POP	BC			; RESTORE LOOP CONTROL
	DJNZ	PPPSD_INIT1		; DECREMENT LOOP COUNTER AND LOOP AS NEEDED
;
	RET				; DONE
;
;
;
PPPSD_INITUNIT:
	; REINITIALIZE THE CARD HERE
	CALL	PPPSD_INITCARD
	RET	NZ
;
	CALL	PPPSD_PRTPREFIX
;
	; PRINT CARD TYPE
	PRTS(" TYPE=$")
	CALL	PPPSD_PRTTYPE
;
	; PRINT STORAGE CAPACITY (BLOCK COUNT)
	PRTS(" BLOCKS=0x$")		; PRINT FIELD LABEL
	LD	A,PPPSD_MEDCAP		; OFFSET TO CAPACITY FIELD
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32			; GET THE CAPACITY VALUE
	CALL	PRTHEX32		; PRINT HEX VALUE
;
	; PRINT STORAGE SIZE IN MB
	PRTS(" SIZE=$")			; PRINT FIELD LABEL
	LD	B,11			; 11 BIT SHIFT TO CONVERT BLOCKS --> MB
	CALL	SRL32			; RIGHT SHIFT
	;CALL	PRTDEC			; PRINT LOW WORD IN DECIMAL (HIGH WORD DISCARDED)
	CALL	PRTDEC32		; PRINT DWORD IN DECIMAL
	PRTS("MB$")			; PRINT SUFFIX
;
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPPSD_FNTBL:
	.DW	PPPSD_STATUS
	.DW	PPPSD_RESET
	.DW	PPPSD_SEEK
	.DW	PPPSD_READ
	.DW	PPPSD_WRITE
	.DW	PPPSD_VERIFY
	.DW	PPPSD_FORMAT
	.DW	PPPSD_DEVICE
	.DW	PPPSD_MEDIA
	.DW	PPPSD_DEFMED
	.DW	PPPSD_CAP
	.DW	PPPSD_GEOM
#IF (($ - PPPSD_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID PPPSD FUNCTION TABLE ***\n"
#ENDIF
;
PPPSD_VERIFY:
PPPSD_FORMAT:
PPPSD_DEFMED:
	SYSCHKERR(ERR_NOTIMPL)		; INVALID SUB-FUNCTION
	RET
;
;
;
PPPSD_READ:
	CALL	HB_DSKREAD		; HOOK HBIOS DISK READ SUPERVISOR
	LD	BC,PPPSD_RDSEC		; GET ADR OF SECTOR READ FUNC
	LD	(PPPSD_IOFNADR),BC	; SAVE IT AS PENDING IO FUNC
	JR	PPPSD_IO		; CONTINUE TO GENERIC IO ROUTINE
;
;
;
PPPSD_WRITE:
	CALL	HB_DSKWRITE		; HOOK HBIOS DISK WRITE SUPERVISOR
	LD	BC,PPPSD_WRSEC		; GET ADR OF SECTOR READ FUNC
	LD	(PPPSD_IOFNADR),BC	; SAVE IT AS PENDING IO FUNC
	JR	PPPSD_IO		; CONTINUE TO GENERIC IO ROUTINE
;
;
;
PPPSD_IO:
	LD	(PPPSD_DSKBUF),HL	; SAVE DISK BUFFER ADDRESS
	LD	A,E			; BLOCK COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR R/W COUNTER

#IF (PPPSDTRACE == 1)
	LD	HL,PPPSD_PRTERR		; SET UP PPPSD_PRTERR
	PUSH	HL			; ... TO FILTER ALL EXITS
#ENDIF

	PUSH	BC			; SAVE COUNTERS
	CALL	PPPSD_CHKCARD		; CHECK / REINIT CARD AS NEEDED
	POP	BC			; RESTORE COUNTERS
	JR	NZ,PPPSD_IO3		; BAIL OUT ON ERROR

PPPSD_IO1:
	PUSH	BC			; SAVE COUNTERS

#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
#ENDIF

	LD	HL,(PPPSD_IOFNADR)	; GET PENDING IO FUNCTION ADDRESS
	CALL	JPHL			; ... AND CALL IT
	JR	NZ,PPPSD_IO2		; BAIL OUT ON ERROR
	; INCREMENT LBA
	LD	A,PPPSD_LBA		; LBA OFFSET
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE
	; INCREMENT DMA
	LD	HL,PPPSD_DSKBUF+1	; POINT TO MSB OF BUFFER ADR
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES
	XOR	A			; SIGNAL SUCCESS

PPPSD_IO2:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,PPPSD_IO3		; IF ERROR PENDING, BAIL OUT
	INC	C			; BUMP COUNT OF SECTORS READ
	DJNZ	PPPSD_IO1		; LOOP AS NEEDED

PPPSD_IO3:
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(PPPSD_DSKBUF)	; CURRENT BUF ADR TO HL
	OR	A			; SET FLAGS BASED ON RETURN CODE
	RET	Z			; RETURN IF SUCCESS
	LD	A,ERR_IO		; SIGNAL IO ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
;
;
PPPSD_RDSEC:
;
#IF (PPPSDTRACE >= 3)
	PRTS(" READ$")
#ENDIF

	LD	D,PPP_CMDDSKRD		; READ COMMAND
	CALL	PPP_SNDCMD		; ... AND SEND COMMAND
	RET	NZ			; BAIL OUT ON ERROR

	CALL	PPPSD_SENDBLK		; SEND THE LBA BLOCK NUMBER
	CALL	PPP_GETBYTE		; GET READ RESULT
	LD	(PPPSD_DSKSTAT),A	; SAVE IT

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF

	OR	A			; SET FLAGS
	JR	Z,PPPSD_RDSEC1

	; HANDLE ERROR
	CALL	PPPSD_GETDSKSTAT	; GET FULL ERROR CODE
	JP	PPPSD_ERRCMD		; RETURN VIA ERROR HANDLER

PPPSD_RDSEC1:
	; GET THE SECTOR DATA
	LD	D,PPP_CMDDSKGET		; COMMAND = DSKGET
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ			; BAIL OUT ON ERROR

	; READ THE SECTOR DATA
	LD	BC,512
	LD	HL,(PPPSD_DSKBUF)
PPPSD_RDSEC2:
	CALL	PPP_GETBYTE
	LD	(HL),A
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,PPPSD_RDSEC2

	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPPSD_WRSEC:
;
#IF (PPPSDTRACE >= 3)
	PRTS(" WRITE$")
#ENDIF

	; PUT THE SECTOR DATA
	LD	D,PPP_CMDDSKPUT		; COMMAND = DSKPUT
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ

	; SEND OVER THE SECTOR CONTENTS
	LD	BC,512
	LD	HL,(PPPSD_DSKBUF)
PPPSD_WRSEC1:
	LD	A,(HL)
	INC	HL
	CALL	PPP_PUTBYTE
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,PPPSD_WRSEC1

	; WRITE THE SECTOR
	LD	D,PPP_CMDDSKWR		; COMMAND = DSKWR
	CALL	PPP_SNDCMD
	RET	NZ
	CALL	PPPSD_SENDBLK		; SEND THE LBA BLOCK NUMBER
	CALL	PPP_GETBYTE
	LD	(PPPSD_DSKSTAT),A	; SAVE IT

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF

	OR	A			; SET FLAGS
	RET	Z			; DONE IF NO ERRORS

	; HANDLE ERROR
	CALL	PPPSD_GETDSKSTAT	; GET FULL ERROR CODE
	JP	PPPSD_ERRCMD		; EXIT VIA ERROR HANDLER
;
; REPORT SD CARD READY STATE
;
PPPSD_STATUS:
	LD	A,(IY+PPPSD_STAT)	; GET THE CURRENT READY STATUS
	OR	A
	RET
;
;
;
PPPSD_RESET:
	XOR	A			; ALWAYS OK
	RET
;
;
;
PPPSD_DEVICE:
	LD	D,DIODEV_PPPSD		; D := DEVICE TYPE
	LD	E,(IY+PPPSD_DEV)	; E := PHYSICAL DEVICE NUMBER
	LD	C,%00110010		; C := ATTRIBUTES, REMOVABLE, SD CARD
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,PPPBASE		; L := BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
; SETUP FOR SUBSEQUENT ACCESS
; INIT CARD IF NOT READY OR ON DRIVE LOG IN
;
PPPSD_MEDIA:
	; REINITIALIZE THE CARD HERE TO DETERMINE PRESENCE
	CALL	PPPSD_INITCARD
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTERR		; PRINT ANY ERRORS
#ENDIF
	LD	E,MID_HD		; ASSUME WE ARE OK
	RET	Z			; RETURN IF GOOD INIT
	LD	E,MID_NONE		; SIGNAL NO MEDA
	LD	A,ERR_NOMEDIA		; NO MEDIA ERROR
	OR	A			; SET FLAGS
	RET				; AND RETURN
;
;
;
PPPSD_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+PPPSD_LBA+0),L	; SAVE NEW LBA
	LD	(IY+PPPSD_LBA+1),H	; ...
	LD	(IY+PPPSD_LBA+2),E	; ...
	LD	(IY+PPPSD_LBA+3),D	; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
PPPSD_CAP:
	LD	A,PPPSD_MEDCAP		; OFFSET TO CAPACITY FIELD
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32			; GET THE CURRENT CAPACITY INTO DE:HL
	LD	BC,512			; 512 BYTES PER BLOCK
	LD	A,(IY+PPPSD_STAT)	; GET CURRENT STATUS
	OR	A			; SET FLAGS
	RET
;
;
;
PPPSD_GEOM:
	; FOR LBA, WE SIMULATE CHS ACCESS USING 16 HEADS AND 16 SECTORS
	; RETURN HS:CC -> DE:HL, SET HIGH BIT OF D TO INDICATE LBA CAPABLE
	CALL	PPPSD_CAP		; GET TOTAL BLOCKS IN DE:HL, BLOCK SIZE TO BC
	LD	L,H			; DIVIDE BY 256 FOR # TRACKS
	LD	H,E			; ... HIGH BYTE DISCARDED, RESULT IN HL
	LD	D,16 | $80		; HEADS / CYL = 16, SET LBA CAPABILITY BIT
	LD	E,16			; SECTORS / TRACK = 16
	RET				; DONE, A STILL HAS PPPSD_CAP STATUS
;
; REINITIALIZE THE SD CARD
;
PPPSD_INITCARD:
	;; CLEAR ALL STATUS DATA
	;LD	HL,PPPSD_UNITDATA
	;LD	BC,PPPSD_UNITDATALEN
	;XOR	A
	;CALL	FILL
;
	; RESET INTERFACE, RETURN WITH NZ ON FAILURE
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
	PRTS(" RESET$")
#ENDIF

	; RESET & STATUS DISK
	LD	D,PPP_CMDDSKRES		; COMMAND = DSKRESET
	CALL	PPP_SNDCMD
	RET	NZ
	CALL	PPP_GETBYTE		; GET STATUS
	LD	(PPPSD_DSKSTAT),A	; SAVE STATUS

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF

	OR	A
	JR	Z,PPPSD_INITCARD1

	; HANDLE ERROR
	CALL	PPPSD_GETDSKSTAT	; GET FULL ERROR CODE
	;JP	PPPSD_ERRCMD		; HANDLE ERRORS
	JP	PPPSD_NOMEDIA		; RETURN W/ NO MEDIA ERROR

PPPSD_INITCARD1:

#IF (PPPSDTRACE >= 3)
	; GET CSD IF DEBUGGING
	CALL	PPPSD_GETCSD
	RET	NZ
#ENDIF

	; GET CARD TYPE
	CALL	PPPSD_GETTYPE
	RET	NZ

	; GET CAPACITY
	CALL	PPPSD_GETCAP
	RET	NZ

	RET
;
; CHECK THE SD CARD, ATTEMPT TO REINITIALIZE IF NEEDED
;
PPPSD_CHKCARD:
	LD	A,(IY+PPPSD_STAT)	; GET STATUS
	OR	A			; SET FLAGS
	RET	Z			; IF ALL GOOD, DONE
	JP	PPPSD_INITCARD		; OTHERWISE, REINIT
;
;
;
PPPSD_GETDSKSTAT:
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
	PRTS(" STAT$")
#ENDIF

	LD	D,PPP_CMDDSKSTAT	; COMMAND = GET DISK STATUS
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ			; ABORT ON ERROR

	LD	B,4			; GET 4 BYTES
	LD	HL,PPPSD_ERRCODE	; TO ERROR CODE
PPPSD_GETDSKSTAT1:
	CALL	PPP_GETBYTE
	LD	(HL),A
	INC	HL
	DJNZ	PPPSD_GETDSKSTAT1

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	HL,PPPSD_ERRCODE
	CALL	LD32
	CALL	PRTHEX32
#ENDIF

	XOR	A
	RET
;
;
;
PPPSD_GETTYPE:
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
	PRTS(" TYPE$")
#ENDIF

	LD	D,PPP_CMDDSKTYPE	; COMMAND = GET DISK TYPE
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ			; ABORT ON ERROR
	CALL	PPP_GETBYTE		; GET DISK TYPE VALUE
	LD	(IY+PPPSD_TYPE),A	; SAVE IT

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
#ENDIF

	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
PPPSD_GETCAP:
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
	PRTS(" CAP$")
#ENDIF

	LD	D,PPP_CMDDSKCAP		; COMMAND = GET CAPACITY
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ			; ABORT ON ERROR

	LD	A,PPPSD_MEDCAP		; OFFSET OF CAPACITY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	LD	B,4			; GET 4 BYTES
PPPSD_GETCAP1:
	CALL	PPP_GETBYTE
	LD	(HL),A
	INC	HL
	DJNZ	PPPSD_GETCAP1

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	A,PPPSD_MEDCAP		; OFFSET OF CAPACITY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32
	CALL	PRTHEX32
#ENDIF

	XOR	A
	RET
;
;
;
PPPSD_GETCSD:
#IF (PPPSDTRACE >= 3)
	CALL	PPPSD_PRTPREFIX
	PRTS(" CSD$")
#ENDIF

	LD	D,PPP_CMDDSKCSD		; COMMAND = GET CAPACITY
	CALL	PPP_SNDCMD		; SEND COMMAND
	RET	NZ			; ABORT ON ERROR

	LD	B,16			; GET 16 BYTES
	LD	HL,PPPSD_CSDBUF
PPPSD_GETCSD1:
	CALL	PPP_GETBYTE
	LD	(HL),A
	INC	HL
	DJNZ	PPPSD_GETCSD1

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	DE,PPPSD_CSDBUF
	LD	A,16
	CALL	PRTHEXBUF
#ENDIF

	XOR	A
	RET
;
; SEND INDEX OF BLOCK TO READ FROM SD CARD
; 32 BIT VALUE (4 BYTES)
; NOTE THAT BYTES ARE SENT REVERSED, PROPELLER IS LITTLE ENDIAN
;
PPPSD_SENDBLK:
#IF (PPPSDTRACE >= 3)
	PRTS(" BLK$")
#ENDIF

#IF (PPPSDTRACE >= 3)
	CALL	PC_SPACE
	LD	A,PPPSD_LBA		; OFFSET OF LBA
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	LD32
	CALL	PRTHEX32
#ENDIF

	LD	A,PPPSD_LBA		; OFFSET OF LBA
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
;;;#IF (DSKYENABLE)
;;;  #IF (DSKYDSKACT)
	CALL	HB_DSKACT		; SHOW ACTIVITY
;;;  #ENDIF
;;;#ENDIF
	LD	B,4
PPPSD_SENDBLK1:
	LD	A,(HL)

	;CALL	PC_SPACE
	;CALL	PRTHEXBYTE

	INC	HL
	CALL	PPP_PUTBYTE
	DJNZ	PPPSD_SENDBLK1
	RET
;
;=============================================================================
; ERROR HANDLING AND DIAGNOSTICS
;=============================================================================
;
; ERROR HANDLERS
;
PPPSD_INVUNIT:
	LD	A,PPPSD_STINVUNIT
	JR	PPPSD_ERR2		; SPECIAL CASE FOR INVALID UNIT
;
PPPSD_ERRRDYTO:
	LD	A,PPPSD_STRDYTO
	JR	PPPSD_ERR
;
PPPSD_ERRINITTO:
	LD	A,PPPSD_STINITTO
	JR	PPPSD_ERR
;
PPPSD_ERRCMDTO:
	LD	A,PPPSD_STCMDTO
	JR	PPPSD_ERR
;
PPPSD_ERRCMD:
	LD	A,PPPSD_STCMDERR
	JR	PPPSD_ERR
;
PPPSD_ERRDATA:
	LD	A,PPPSD_STDATAERR
	JR	PPPSD_ERR
;
PPPSD_ERRDATATO:
	LD	A,PPPSD_STDATATO
	JR	PPPSD_ERR
;
PPPSD_ERRCRC:
	LD	A,PPPSD_STCRCERR
	JR	PPPSD_ERR
;
PPPSD_NOMEDIA:
	LD	A,PPPSD_STNOMEDIA
	JR	PPPSD_ERR
;
PPPSD_WRTPROT:
	LD	A,PPPSD_STWRTPROT
	JR	PPPSD_ERR2		; DO NOT UPDATE UNIT STATUS!
;
PPPSD_ERR:
	LD	(IY+PPPSD_STAT),A	; UPDATE STATUS
;
PPPSD_ERR2:
#IF (PPPSDTRACE >= 2)
	CALL	PPPSD_PRTSTAT
#ENDIF
	OR	A			; SET FLAGS
	RET
;
;
;
PPPSD_PRTERR:
	RET	Z			; DONE IF NO ERRORS
	; FALL THRU TO PPPSD_PRTSTAT
;
; PRINT STATUS STRING
;
PPPSD_PRTSTAT:
	PUSH	AF
	PUSH	DE
	PUSH	HL
	LD	A,(IY+PPPSD_STAT)
	OR	A
	LD	DE,PPPSD_STR_STOK
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STINVUNIT
	JR	Z,PPPSD_PRTSTAT1	; INVALID UNIT IS SPECIAL CASE
	INC	A
	LD	DE,PPPSD_STR_STRDYTO
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STINITTO
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STCMDTO
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STCMDERR
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STDATAERR
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STDATATO
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STCRCERR
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STNOMEDIA
	JR	Z,PPPSD_PRTSTAT1
	INC	A
	LD	DE,PPPSD_STR_STWRTPROT
	JR	Z,PPPSD_PRTSTAT1
	LD	DE,PPPSD_STR_STUNK
PPPSD_PRTSTAT1:
	CALL	PPPSD_PRTPREFIX		; PRINT UNIT PREFIX
	CALL	PC_SPACE		; FORMATTING
	CALL	WRITESTR
	LD	A,(IY+PPPSD_STAT)
	CP	PPPSD_STCMDERR
	CALL	Z,PPPSD_PRTSTAT2
	POP	HL
	POP	DE
	POP	AF
	RET
PPPSD_PRTSTAT2:
	CALL	PC_SPACE
	LD	A,(PPPSD_DSKSTAT)
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	JP	PPPSD_PRTERRCODE
	RET

;
;
;
PPPSD_PRTERRCODE:
	PUSH	HL
	PUSH	DE
	LD	HL,PPPSD_ERRCODE
	CALL	LD32
	CALL	PRTHEX32
	POP	DE
	POP	HL
	RET
;
; PRINT DIAGNONSTIC PREFIX
;
PPPSD_PRTPREFIX:
	PUSH	AF
	CALL	NEWLINE
	PRTS("PPPSD$")
	LD	A,(IY+PPPSD_DEV)	; GET CURRENT DEVICE NUM
	ADD	A,'0'
	CALL	COUT
	CALL	PC_COLON
	POP	AF
	RET
;
; PRINT THE CARD TYPE
;
PPPSD_PRTTYPE:
	LD	A,(IY+PPPSD_TYPE)
	LD	DE,PPPSD_STR_TYPEMMC
	CP	PPPSD_TYPEMMC
	JR	Z,PPPSD_PRTTYPE1
	LD	DE,PPPSD_STR_TYPESDSC
	CP	PPPSD_TYPESDSC
	JR	Z,PPPSD_PRTTYPE1
	LD	DE,PPPSD_STR_TYPESDHC
	CP	PPPSD_TYPESDHC
	JR	Z,PPPSD_PRTTYPE1
	LD	DE,PPPSD_STR_TYPESDXC
	CP	PPPSD_TYPESDXC
	JR	Z,PPPSD_PRTTYPE1
	LD	DE,PPPSD_STR_TYPEUNK
PPPSD_PRTTYPE1:
	JP	WRITESTR
;
;=============================================================================
; STRING DATA
;=============================================================================
;
;
PPPSD_STR_STOK		.TEXT	"OK$"
PPPSD_STR_STINVUNIT	.TEXT	"INVALID UNIT$"
PPPSD_STR_STRDYTO	.TEXT	"READY TIMEOUT$"
PPPSD_STR_STINITTO	.TEXT	"INITIALIZATION TIMEOUT$"
PPPSD_STR_STCMDTO	.TEXT	"COMMAND TIMEOUT$"
PPPSD_STR_STCMDERR	.TEXT	"COMMAND ERROR$"
PPPSD_STR_STDATAERR	.TEXT	"DATA ERROR$"
PPPSD_STR_STDATATO	.TEXT	"DATA TIMEOUT$"
PPPSD_STR_STCRCERR	.TEXT	"CRC ERROR$"
PPPSD_STR_STNOMEDIA	.TEXT	"NO MEDIA$"
PPPSD_STR_STWRTPROT	.TEXT	"WRITE PROTECTED$"
PPPSD_STR_STUNK		.TEXT	"UNKNOWN$"
;
PPPSD_STR_TYPEUNK	.TEXT	"UNK$"
PPPSD_STR_TYPEMMC	.TEXT	"MMC$"
PPPSD_STR_TYPESDSC	.TEXT	"SDSC$"
PPPSD_STR_TYPESDHC	.TEXT	"SDHC$"
PPPSD_STR_TYPESDXC	.TEXT	"SDXC$"
;
;=============================================================================
; DATA STORAGE
;=============================================================================
;
PPPSD_IOFNADR		.DW	0	; PENDING IO FUNCTION ADDRESS
;
PPPSD_DSKBUF		.DW	0
;
PPPSD_DSKSTAT		.DB	0
PPPSD_ERRCODE		.DW	0,0
PPPSD_CSDBUF		.FILL	16,0
