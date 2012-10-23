;
;==================================================================================================
; PARPORTPROP DRIVER
;==================================================================================================
;
; COMMAND BYTES
;
PPP_CMDNOP	.EQU	$00           ; DO NOTHING
PPP_CMDECHOBYTE	.EQU	$01           ; RECEIVE A BYTE, INVERT IT, SEND IT BACK
PPP_CMDECHOBUF	.EQU	$02           ; RECEIVE 512 BYTE BUFFER, SEND IT BACK
;
PPP_CMDDSKRES	.EQU	$10           ; RESTART SD CARD SUPPORT
PPP_CMDDSKSTAT	.EQU	$11           ; SEND LAST SD CARD STATUS (4 BYTES)
PPP_CMDDSKPUT	.EQU	$12           ; PPI -> SECTOR BUFFER -> PPP
PPP_CMDDSKGET	.EQU	$13           ; PPP -> SECTOR BUFFER -> PPI
PPP_CMDDSKRD	.EQU	$14           ; READ SCTOR FROM SD CARD INTO PPP BUFFER, RETURN 1 BYTE STATUS
PPP_CMDDSKWR	.EQU	$15           ; WRITE SECTOR TO SD CARD FROM PPP BUFFER, RETURN 1 BYTE STATUS
;
PPP_CMDVIDOUT	.EQU	$20           ; WRITE A BYTE TO THE TERMINAL EMULATOR
;
PPP_CMDKBDSTAT	.EQU	$30           ; RETURN A BYTE WITH NUMBER OF CHARACTERS IN BUFFER
PPP_CMDKBDRD	.EQU	$31           ; RETURN A CHARACTER, WAIT IF NECESSARY
;
PPP_CMDSPKTONE	.EQU	$40           ; EMIT SPEAKER TONE AT SPECIFIED FREQUENCY AND DURATION
;
PPP_CMDSIOINIT	.EQU	$50           ; RESET SERIAL PORT AND ESTABLISH A NEW BAUD RATE (4 BYTE BAUD RATE)
PPP_CMDSIORX	.EQU	$51           ; RECEIVE A BYTE IN FROM SERIAL PORT
PPP_CMDSIOTX	.EQU	$52           ; TRANSMIT A BYTE OUT OF THE SERIAL PORT 
PPP_CMDSIORXST	.EQU	$53           ; SERIAL PORT RECEIVE STATUS (RETURNS # BYTES OF RX BUFFER USED)                                   
PPP_CMDSIOTXST	.EQU	$54           ; SERIAL PORT TRANSMIT STATUS (RETURNS # BYTES OF TX BUFFER SPACE AVAILABLE) 
PPP_CMDSIORXFL	.EQU	$55           ; SERIAL PORT RECEIVE BUFFER FLUSH                                   
PPP_CMDSIOTXFL	.EQU	$56           ; SERIAL PORT TRANSMIT BUFFER FLUSH (NOT IMPLEMENTED) 
;
PPP_CMDRESET	.EQU	$F0           ; SOFT RESET PROPELLER
;
; GLOBAL PARPORTPROP INITIALIZATION
;
PPP_INIT:
	LD	A,$9B			; PPI MODE 0, ALL PINS INPUT
	OUT	(PPIX),A		; SEND IT

	LD	A,11000010B		; PPI MODE 2 (BI HANDSHAKE), PC0-2 OUT, PB IN
	OUT	(PPIX),A
	
	CALL	DELAY			; PROBABLY NOT NEEDED
	
	LD	A,00000000B		; SET PC0 -> 0
	OUT	(PPIX),A
	LD	A,00000010B		; SET PC1 -> 0
	OUT	(PPIX),A
	LD	A,00000101B		; SET PC2 -> 1 - ASSERT RESET ON PPP
	OUT	(PPIX),A
	LD	A,00000110B		; SET PC3 -> 0
	OUT	(PPIX),A
	
	CALL	DELAY			; PROBABLY NOT NEEDED
	
	IN	A,(PPIA)		; CLEAR GARBAGE???
	
	CALL	DELAY			; PROBABLY NOT NEEDED
	
	LD	A,00000001B	; SET CMD FLAG
	OUT	(PPIX),A	; SEND IT
	LD	E,PPP_CMDRESET
	CALL	PUTBYTE		; SEND THE COMMAND BYTE
	CALL	DELAY
	LD	A,00000000B	; CLEAR CMD FLAG
	OUT	(PPIX),A
	
	LD	A,00000100B		; SET PC2 -> 0 - DEASSERT RESET ON PPP
	OUT	(PPIX),A
	
	CALL	DELAY			; PROBABLY NOT NEEDED
	
	LD	BC,0
INIT1:
	PUSH	BC
	CALL	DELAY
	CALL	DELAY
	CALL	DELAY
	CALL	DELAY
	IN	A,(PPIA)
	POP	BC
	CP	$AA
	RET	Z
	DEC	BC
	LD	A,B
	OR	C
	JR	NZ,INIT1
	
	CALL	NEWLINE
	LD	DE,PPPSTR_TIMEOUT
	CALL	WRITESTR
	
	CALL	PPPSD_INIT		; SD CARD INITIALIZATION
	
	RET
;
;==================================================================================================
; PARPORTPROP CONSOLE DRIVER
;==================================================================================================
;
; DISPATCH FOR CONSOLE SUBFUNCTIONS
;
PPPCON_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JR	Z,PPPCON_IN	; JUMP IF CHARACTER IN
	DEC	A		; NEXT SUBFUNCTION
	JR	Z,PPPCON_OUT	; JUMP IF CHARACTER OUT
	DEC	A		; NEXT SUBFUCNTION
	JR	Z,PPPCON_IST	; JUMP IF INPUT STATUS
	DEC	A		; NEXT SUBFUNCTION
	JR	Z,PPPCON_OST	; JUMP IF OUTPUT STATUS
	CALL	PANIC		; OTHERWISE SOMETHING IS BADLY BROKEN
;
; CHARACTER INPUT
;   WAIT FOR A CHARACTER AND RETURN IT IN E
;
PPPCON_IN:
	CALL	PPPCON_IST		; CHECK FOR CHAR PENDING
	JR	Z,PPPCON_IN		; WAIT FOR IT IF NECESSARY
	LD	D,PPP_CMDKBDRD		; CMD = KEYBOARD READ
	CALL	SENDCMD			; SEND COMMAND
	CALL	GETBYTE			; GET CHARACTER READ
	XOR	A			; CLEAR A (SUCCESS)
	RET				; AND RETURN 
;
; CHARACTER INPUT STATUS
;   RETURN STATUS IN A, 0 = NOTHING PENDING, > 0 CHAR PENDING
;
PPPCON_IST:
	LD	D,PPP_CMDKBDSTAT	; CMD = KEYBOARD STATUS
	CALL	SENDCMD			; SEND COMMAND
	CALL	GETBYTE			; GET RESPONSE
	LD	A,E			; MOVE IT TO A
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
	CALL	SENDCMD			; SEND COMMAND
	CALL	PUTBYTE			; SEND IT
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
;==================================================================================================
; PARPORTPROP SD CARD DRIVER
;==================================================================================================
;
PPPSD_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F
	JP	Z,PPPSD_READ	; READ
	DEC	A
	JP	Z,PPPSD_WRITE	; WRITE
	DEC	A
	JP	Z,PPPSD_STATUS	; STATUS
	DEC	A
	JP	Z,PPPSD_MEDIA	; MEDIA ID
	CALL	PANIC
;
; SETUP FOR SUBSEQUENT ACCESS
; INIT CARD IF NOT READY OR ON DRIVE LOG IN
;
PPPSD_MEDIA:
	; REINITIALIZE THE CARD HERE TO DETERMINE PRESENCE
	CALL	PPPSD_INITCARD
	LD	A,MID_NONE		; ASSUME FAILURE
	RET	NZ

	; ALL IS WELL, RETURN MEDIA IDENTIFIER
	LD	A,MID_HD		; SET MEDIA ID
	RET
;
; SD CARD INITIALIZATION
;
PPPSD_INIT:
	; MARK DRIVE NOT READY
	; HARDWARE INIT DEFERRED UNTIL DRIVE SELECT
	XOR	A
	DEC	A
	LD	(PPPSD_STAT),A
	RET
;
; REPORT SD CARD READY STATE
;
PPPSD_STATUS:
	LD	A,(PPPSD_STAT)		; GET THE CURRENT READY STATUS
	OR	A
	RET
;
; READ AN LBA BLOCK FROM THE SD CARD
;
PPPSD_READ:
	CALL	PPPSD_CHKCARD		; CHECK / REINIT CARD AS NEEDED
	RET	NZ			; BAIL OUT ON ERROR
	
	; READ A SECTOR
	CALL	PPPSD_SETBLK		; SETUP PPP_LBA WITH BLOCK NUMBER
	LD	D,PPP_CMDDSKRD		; COMMAND = DSKWR
	CALL	SENDCMD			; SEND COMMAND
	CALL	PPPSD_SENDBLK		; SEND THE LBA BLOCK NUMBER
	CALL	GETBYTE
	LD	A,E
	LD	(PPPSD_STAT),A		; SAVE STATUS
	CALL	PPPSD_PRTREAD		; PRINT DIAGNOSTICS AS NEEDED
	OR	A			; SET FLAGS
	RET	NZ			; BAIL OUT ON ERROR

	; GET THE SECTOR DATA
	LD	D,PPP_CMDDSKGET		; COMMAND = DSKGET
	CALL	SENDCMD			; SEND COMMAND

	; READ THE SECTOR DATA
	LD	BC,512
	LD	HL,(DIOBUF)
DSKREAD1:
	CALL	GETBYTE
	LD	(HL),E
	INC	HL
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,DSKREAD1

	XOR	A			 ; SUCCESS
	RET
;
; WRITE AN LBA BLOCK TO THE SD CARD
;
PPPSD_WRITE:
	CALL	PPPSD_CHKCARD		; CHECK / REINIT CARD AS NEEDED
	RET	NZ			; BAIL OUT ON ERROR
	
	CALL	PPPSD_SETBLK		; SETUP THE LBA BLOCK INDEX
	
	; PUT THE SECTOR DATA
	LD	D,PPP_CMDDSKPUT		; COMMAND = DSKPUT
	CALL	SENDCMD			; SEND COMMAND

	; SEND OVER THE SECTOR CONTENTS
	LD	BC,512
	LD	HL,(DIOBUF)
DSKWRITE1:
	LD	E,(HL)
	INC	HL
	CALL	PUTBYTE
	DEC	BC
	LD	A,B
	OR	C
	JP	NZ,DSKWRITE1

	; WRITE THE SECTOR
	LD	D,PPP_CMDDSKWR		; COMMAND = DSKWR
	CALL	SENDCMD
	CALL	PPPSD_SENDBLK		; SEND THE LBA BLOCK NUMBER
	CALL	GETBYTE
	LD	A,E
	LD	(PPPSD_STAT),A		; SAVE STATUS
	CALL	PPPSD_PRTWRITE		; PRINT DIAGNOSTICS AS NEEDED
	OR	A			; SET FLAGS
	RET				; ALL DONE
;
; REINITIALIZE THE SD CARD
;
PPPSD_INITCARD:
	; RESET & STATUS DISK
	LD	D,PPP_CMDDSKRES		; COMMAND = DSKRESET
	CALL	SENDCMD
	CALL	GETBYTE
	LD	A,E
	LD	(PPPSD_STAT),A		; SAVE UPDATED STATUS
	OR	A
	RET				; Z/NZ SET, A HAS RESULT CODE
;
; CHECK THE SD CARD, ATTEMPT TO REINITIALIZE IF NEEDED
;
PPPSD_CHKCARD:
	LD	A,(PPPSD_STAT)		; GET STATUS
	OR	A			; SET FLAGS
	CALL	NZ,PPPSD_INITCARD	; INIT CARD IF NOT READY
	RET				; RETURN WITH STATUS IN A
;
; SET UP LBA BLOCK INDEX BASED ON HSTTRK AND HSTSEC
; NOTE THAT BYTE ORDER IS LITTLE ENDIAN FOR PROPLELLER!
; SEE MAPPING IN COMMENTS
; NOTE THAT HSTSEC:MSB IS UNUSED
;
PPPSD_SETBLK:
	LD	HL,PPP_LBA + 3		; WORK BACKWARDS, START WITH END OF LBA
	XOR	A			; MSB OF LBA IS ALWAYS ZERO
	LD	(HL),A			; LBAHI:MSB = 0
	DEC	HL			; POINT TO NEXT BYTE
	LD	DE,(HSTTRK)		; DE = HSTTRK
	LD	(HL),D			; LBAHI:LSB = D = HSTTRK:MSB
	DEC	HL			; POINT TO NEXT BYTE
	LD	(HL),E			; LBALO:MSB = E = HSTTRK:LSB
	DEC	HL			; POINT TO NEXT BYTE
	LD	A,(HSTSEC)		; A = HSTSEC:LSB
	LD	(HL),A			; LBALO:LSB = A = HSTSEC:LSB
	RET
;
; SEND INDEX OF BLOCK TO READ FROM SD CARD
; 32 BIT VALUE (4 BYTES)
; NOTE THAT BYTES ARE SENT REVERSED, PROPELLER IS LITTLE ENDIAN
;
PPPSD_SENDBLK:
	LD	HL,PPP_LBA
	LD	B,4
PPPSD_SENDBLK1:	
	LD	E,(HL)
	INC	HL
	CALL	PUTBYTE
	DJNZ	PPPSD_SENDBLK1
	RET
;
; PRINT DIAGNOSTICS AFTER COMMAND EXECUTION
;
PPPSD_PRTREAD:
	LD	DE,PPPSTR_READ
	JR	PPPSD_PRT

PPPSD_PRTWRITE:
	LD	DE,PPPSTR_WRITE
	JR	PPPSD_PRT

PPPSD_PRT:
	OR	A
#IF (PPPSDTRACE == 0)
	RET
#ELSE
#IF (PPPSDTRACE == 1)
	RET	Z
#ENDIF
	PUSH	AF
	CALL	NEWLINE
	LD	DE,PPPSTR_PREFIX	; PRINT DRIVER PREFIX
	CALL	WRITESTR
	CALL	PC_SPACE
	CALL	WRITESTR		; PRINT FUNCTION
	CALL	PPPSD_PRTBLK		; PRINT BLOCK NUMBER
	CALL	PC_SPACE
	LD	DE,PPPSTR_ARROW		; PRINT ARROW
	CALL	WRITESTR
	CALL	PC_SPACE
	POP	AF
	PUSH	AF
	CALL	PRTHEXBYTE		; PRINT RESULT BYTE
	CALL	NZ,PPPSD_PRTERR		; PRINT DETAILED ERROR VALUE IF APPROPRIATE
	POP	AF
	RET				; RET WITH A = STATUS

PPPSD_PRTBLK:
	CALL	PC_SPACE
	LD	HL,PPP_LBA + 4
	LD	B,4
PPPSD_PRTBLK1:
	DEC	HL
	LD	A,(HL)
	CALL	PRTHEXBYTE
	DJNZ	PPPSD_PRTBLK1
	RET
	
PPPSD_PRTERR:
	LD	D,PPP_CMDDSKSTAT
	CALL	SENDCMD
	
	LD	HL,PPP_DSKSTAT
	LD	B,4
PPPSD_PRTERR1:	
	CALL	GETBYTE
	LD	(HL),E
	INC	HL
	DJNZ	PPPSD_PRTERR1

	CALL	PC_LBKT
	LD	BC,(PPP_DSKSTHI)
	CALL	PRTHEXWORD
	LD	BC,(PPP_DSKSTLO)
	CALL	PRTHEXWORD
	CALL	PC_RBKT
	
	RET
#ENDIF
;
;==================================================================================================
;   PPPSD DISK DRIVER - DATA
;==================================================================================================
;
PPPSD_STAT	.DB	0
;
PPP_LBA:
PPP_LBALO	.DW	0
PPP_LBAHI	.DW	0
PPP_DSKSTAT:
PPP_DSKSTLO	.DW	0
PPP_DSKSTHI	.DW	0
;
PPPSTR_PREFIX	.TEXT	"PPPDSK:$"
PPPSTR_CMD	.TEXT	"CMD=$"
PPPSTR_READ	.TEXT	"READ$"
PPPSTR_WRITE	.TEXT	"WRITE$"
;PPPSTR_RC	.TEXT	"RC=$"
PPPSTR_ARROW	.TEXT	"-->$"
PPPSTR_ERR	.TEXT	"ERR=$"
;PPPSTR_RCOK	.TEXT	"OK$"
;PPPSTR_RCRDYTO	.TEXT	"READY TIMEOUT$"
;
;==================================================================================================
;   GLOBAL PPP DRIVER FUNCTIONS
;==================================================================================================
;
PUTBYTE:
	IN	A,(PPIC)
	BIT	7,A
	JR	Z,PUTBYTE
	LD	A,E
	OUT	(PPIA),A
	RET
;	
GETBYTE:
	IN	A,(PPIC)
	BIT	5,A
	JR	Z,GETBYTE
	IN	A,(PPIA)
	LD	E,A
	RET
;
SENDCMD:
	IN	A,(PPIA)	; DISCARD ANYTHING PENDING
	; WAIT FOR OBF HIGH (OUTPUT BUFFER TO BE EMPTY)
	IN	A,(PPIC)
	BIT	7,A
	JR	Z,SENDCMD

	LD	A,00000001B	; SET CMD FLAG
	OUT	(PPIX),A	; SEND IT

SENDCMD0:
	IN	A,(PPIC)
	BIT	7,A
	JR	Z,SENDCMD0
	LD	A,D
	OUT	(PPIA),A

SENDCMD1:
	; WAIT FOR OBF HIGH (BYTE HAS BEEN RECEIVED)
	IN	A,(PPIC)
	BIT	7,A
	JR	Z,SENDCMD1
	; TURN OFF CMD
	LD	A,00000000B	; CLEAR CMD FLAG
	OUT	(PPIX),A
	
	RET
;
PPPSTR_TIMEOUT	.TEXT	"ParPortProp not responding!$"
