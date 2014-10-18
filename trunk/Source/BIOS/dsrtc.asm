;
;==================================================================================================
; DALLAS SEMICONDUCTOR DS1302 RTC DRIVER
;==================================================================================================
;
; PROGRAMMING NOTES:
;  - ALL SIGNALS ARE ACTIVE HIGH
;  - DATA OUTPUT (HOST -> RTC) ON RISING EDGE
;  - DATA INPUT (RTC -> HOST) ON FALLING EDGE
;  - SIMPLIFIED TIMING CONSTRAINTS:
;    @ 50MHZ, 1 TSTATE IS WORTH 20NS, 1 NOP IS WORTH 80NS, 1 EX (SP), IX IS WORTH 23 460NS
;    1) AFTER CHANGING CE, WAIT 1US (2 X EX (SP), IX)
;    2) AFTER CHANGING CLOCK, WAIT 250NS (3 X NOP)
;    3) AFTER SETTING A DATA BIT, WAIT 50NS (1 X NOP)
;    4) PRIOR TO READING A DATA BIT, WAIT 200NS (3 X NOP)
;
;  COMMAND BYTE:
;
;     7     6     5     4     3     2     1     0
;  +-----+-----+-----+-----+-----+-----+-----+-----+
;  |  1  | RAM |  A4 |  A3 |  A2 |  A1 |  A0 |  RD |
;  |     | ~CK |     |     |     |     |     | ~WR |
;  +-----+-----+-----+-----+-----+-----+-----+-----+
;
;  REGISTER ADDRESSES (HEX / BCD):
;
;    RD   WR   D7   D6   D5   D4   D3   D2   D1   D0     RANGE
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 81 | 80 | CH | 10 SECS      | SEC               | 00-59     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 83 | 82 |    | 10 MINS      | MIN               | 00-59     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 85 | 84 | TF | 00 | PM | 10 | HOURS             | 1-12/0-23 |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 87 | 86 | 00 | 00 | 10 DATE | DATE              | 1-31      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 89 | 88 | 00 | 10 MONTHS    | MONTH             | 1-12      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8B | 8A | 00 | 00 | 00 | 00 | DAY               | 1-7       |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8D | 8C | 10 YEARS          | YEAR              | 0-99      |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 8F | 8E | WP | 00 | 00 | 00 | 00 | 00 | 00 | 00 |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | 91 | 90 | TCS               | DS      | RS      |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | BF | BE | *CLOCK BURST*                                     |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | C1 | C0 |                                       |           |
;  | .. | .. | *RAM*                                 |           |
;  | FD | FC |                                       |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;  | FF | FE | *RAM BURST*                           |           |
;  +----+----+----+----+----+----+----+----+----+----+-----------+
;
;  CH=CLOCK HALT (1=CLOCK HALTED & OSC STOPPED)
;  TF=12 HOUR (1) OR 24 HOUR (0)
;  PM=IF 24 HOURS, 0=AM, 1=PM, ELSE 10 HOURS
;  WP=WRITE PROTECT (1=PROTECTED)
;  TCS=TRICKLE CHARGE ENABLE (1010 TO ENABLE)
;  DS=TRICKLE CHARGE DIODE SELECT
;  RS=TRICKLE CHARGE RESISTOR SELECT
;
; CONSTANTS
;
DSRTC_BASE	.EQU	RTC		; RTC PORT ON ALL N8VEM SERIES Z80 PLATFORMS
;
DSRTC_DATA	.EQU	%10000000	; BIT 7 CONTROLS RTC DATA (I/O) LINE
DSRTC_CLK	.EQU	%01000000	; BIT 6 CONTROLS RTC CLOCK LINE, 1 = HIGH
DSRTC_RD	.EQU	%00100000	; BIT 5 CONTROLS DATA DIRECTION, 1 = READ
DSRTC_CE	.EQU	%00010000	; BIT 4 CONTROLS RTC CE LINE, 1 = HIGH (ENABLED)
;
DSRTC_BUFSIZ	.EQU	7		; 7 BYTE BUFFER (YYMMDDHHMMSSWW)
;
; RTC DEVICE INITIALIZATION ENTRY
;
DSRTC_INIT:
	PRTS("DSRTC: $")
;
	; CHECK FOR CLOCK HALTED
	CALL	DSRTC_TSTCLK
	JR	Z,DSRTC_INIT1
	PRTS("INIT CLOCK $")
	LD	HL,DSRTC_TIMDEF
	CALL	DSRTC_TIM2CLK
	LD	HL,DSRTC_BUF
	CALL	DSRTC_WRCLK
;
DSRTC_INIT1:
	; DISPLAY CURRENT TIME
	LD	HL,DSRTC_BUF
	CALL	DSRTC_RDCLK
	LD	HL,DSRTC_TIMBUF
	CALL	DSRTC_CLK2TIM
	LD	HL,DSRTC_TIMBUF
	CALL	PRTDT
;
	XOR	A	; SIGNAL SUCCESS
	RET
;
; RTC DEVICE FUNCTION DISPATCH ENTRY
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   B: FUNCTION (IN)
;
DSRTC_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JP	Z,DSRTC_GETTIM	; GET TIME
	DEC	A
	JP	Z,DSRTC_SETTIM	; SET TIME
	DEC	A
	JP	Z,DSRTC_GETBYT	; GET NVRAM BYTE VALUE
	DEC	A
	JP	Z,DSRTC_SETBYT	; SET NVRAM BYTE VALUE
	DEC	A
	JP	Z,DSRTC_GETBLK	; GET NVRAM DATA BLOCK VALUES
	DEC	A
	JP	Z,DSRTC_SETBLK	; SET NVRAM DATA BLOCK VALUES 
	CALL	PANIC
;
; NVRAM FUNCTIONS ARE NOT AVAILABLE IN SIMULATOR
;
DSRTC_GETBYT:
DSRTC_SETBYT:
DSRTC_GETBLK:
DSRTC_SETBLK:
	CALL	PANIC
;
; RTC GET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (OUT)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSS
; 24 HOUR TIME FORMAT IS ASSUMED
;
DSRTC_GETTIM:
;
	PUSH	HL			; SAVE ADR OF OUTPUT BUF
;
	; READ THE CLOCK
	LD	HL,DSRTC_BUF		; POINT TO CLOCK BUFFER
	CALL	DSRTC_RDCLK		; READ THE CLOCK
	LD	HL,DSRTC_TIMBUF		; POINT TO TIME BUFFER
	CALL	DSRTC_CLK2TIM		; CONVERT CLOCK TO TIME
;
	LD	C,BID_HB		; SOURCE BANK IS OUR BANK
	CALL	HBXX_GETBNK		; GET USER BANK
	LD	B,A			; PUT IN B AS DEST BANK
	CALL	HBXX_XCOPY		; SETUP COPY BANKS
	LD	HL,DSRTC_TIMBUF		; SOURCE IS TIMBUF
	POP	DE			; DESTINATION IS PASSED IN
	LD	BC,6			; 6 BYTES
	CALL	HBXX_COPY		; DO IT
;
	; CLEAN UP AND RETURN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; RTC SET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (IN)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSS
; 24 HOUR TIME FORMAT IS ASSUMED
;
DSRTC_SETTIM:
;
	; COPY INCOMING TIME DATA TO OUR TIME BUFFER
	CALL	HBXX_GETBNK
	LD	C,A
	LD	B,BID_HB
	CALL	HBXX_XCOPY
	LD	DE,DSRTC_TIMBUF
	LD	BC,6
	CALL	HBXX_COPY
;
	; WRITE TO CLOCK
	LD	HL,DSRTC_TIMBUF		; POINT TO TIME BUFFER
	CALL	DSRTC_TIM2CLK		; CONVERT TO CLOCK FORMAT
	LD	HL,DSRTC_BUF		; POINT TO CLOCK BUFFER
	CALL	DSRTC_WRCLK		; WRITE TO THE CLOCK
;
	; CLEAN UP AND RETURN
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; CONVERT DATA IN CLOCK BUFFER TO TIME BUFFER AT HL
;
DSRTC_CLK2TIM:
	LD	A,(DSRTC_YR)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_MON)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_DT)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_HR)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_MIN)
	LD	(HL),A
	INC	HL
	LD	A,(DSRTC_SEC)
	LD	(HL),A	
	RET
;
; CONVERT DATA IN TIME BUFFER AT HL TO CLOCK BUFFER
;
DSRTC_TIM2CLK:
	PUSH	HL
	LD	A,(HL)
	LD	(DSRTC_YR),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_MON),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_DT),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_HR),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_MIN),A
	INC	HL
	LD	A,(HL)
	LD	(DSRTC_SEC),A
	POP	HL
	XOR	A
	LD	(DSRTC_DAY),A
	RET
;
; TEST CLOCK FOR VALID DATA
;   READ CLOCK HALT BIT AND RETURN ZF BASED ON BIT VALUE
;   0 = RUNNING
;   1 = HALTED
;
DSRTC_TSTCLK:
	LD	C,$81			; SECONDS REGISTER HAS CLOCK HALT FLAG
	CALL	DSRTC_CMD		; SEND THE COMMAND
	CALL	DSRTC_GET		; READ THE REGISTER
	CALL	DSRTC_END		; FINISH IT
	AND	%10000000		; HIGH ORDER BIT IS CLOCK HALT
	RET
;
; BURST READ CLOCK DATA INTO BUFFER AT HL
;
DSRTC_RDCLK:
	LD	C,$BF			; COMMAND = $BF TO BURST READ CLOCK
	CALL	DSRTC_CMD		; SEND COMMAND TO RTC
	LD	B,DSRTC_BUFSIZ		; B IS LOOP COUNTER
DSRTC_RDCLK1:
	PUSH	BC			; PRESERVE BC
	CALL	DSRTC_GET		; GET NEXT BYTE
	LD	(HL),A			; SAVE IN BUFFER
	INC	HL			; INC BUF POINTER
	POP	BC			; RESTORE BC
	DJNZ	DSRTC_RDCLK1		; LOOP IF NOT DONE
	JP	DSRTC_END		; FINISH IT
;
; BURST WRITE CLOCK DATA FROM BUFFER AT HL
;
DSRTC_WRCLK:
	LD	C,$8E			; COMMAND = $8E TO WRITE CONTROL REGISTER
	CALL	DSRTC_CMD		; SEND COMMAND
	XOR	A			; $00 = UNPROTECT
	CALL	DSRTC_PUT		; SEND VALUE TO CONTROL REGISTER
	CALL	DSRTC_END		; FINISH IT
;
	LD	C,$BE			; COMMAND = $BE TO BURST WRITE CLOCK
	CALL	DSRTC_CMD		; SEND COMMAND TO RTC
	LD	B,DSRTC_BUFSIZ		; B IS LOOP COUNTER
DSRTC_WRCLK1:
	PUSH	BC			; PRESERVE BC
	LD	A,(HL)			; GET NEXT BYTE TO WRITE
	CALL	DSRTC_PUT		; PUT NEXT BYTE
	INC	HL			; INC BUF POINTER
	POP	BC			; RESTORE BC
	DJNZ	DSRTC_WRCLK1		; LOOP IF NOT DONE
	LD	A,$80			; ADD CONTROL REG BYTE, $80 = PROTECT ON
	CALL	DSRTC_PUT		; WRITE REQUIRED 8TH BYTE
	JP	DSRTC_END		; FINISH IT
;
; SEND COMMAND IN C TO RTC
;   ALL RTC SEQUENCES MUST CALL THIS FIRST TO SEND THE RTC COMMAND.
;   THE COMMAND IS SENT VIA A PUT.  CE AND CLK ARE LEFT HIGH!  THIS
;   IS INTENTIONAL BECAUSE WHEN THE CLOCK IS LOWERED, THE FIRST BIT
;   WILL BE PRESENTED TO READ (IN THE CASE OF A READ CMD).
;
;   0) ASSUME ALL LINES UNDEFINED AT ENTRY
;   1) DEASSERT ALL LINES (CE, RD, CLOCK, & DATA)
;   2) WAIT 1US
;   3) SET CE HI
;   4) WAIT 1US
;   5) PUT COMMAND
;
DSRTC_CMD:
	XOR	A			; ALL LINES LOW TO RESET
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY2MS			; DELAY 2MS
	XOR	DSRTC_CE		; NOW SET CE HIGH
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY2MS			; DELAY 2MS
	LD	A,C			; LOAD COMMAND
	CALL	DSRTC_PUT		; WRITE IT
	RET
;
; WRITE BYTE IN A TO THE RTC
;   WRITE BYTE IN A TO THE RTC.  CE IS IMPLICITY ASSERTED AT
;   THE START.  CE AND CLK ARE LEFT HIGH AT THE END IN CASE
;   NEXT ACTION IS A READ.
;
;   0) ASSUME ENTRY WITH CE HI, OTHERS UNDEFINED
;   1) SET CLK LO
;   2) WAIT 250NS
;   3) SET DATA ACCORDING TO BIT VALUE
;   4) SET CLOCK HI
;   5) WAIT 250NS (CLOCK READS DATA BIT FROM BUS)
;   6) LOOP FOR 8 DATA BITS
;   7) EXIT WITH CE,CLK HI
;
DSRTC_PUT:
	LD	B,8			; LOOP FOR 8 BITS
	LD	C,A			; SAVE THE WORKING VALUE
DSRTC_PUT1:
	LD	A,DSRTC_CE		; SET CLOCK LOW
	OUT	(DSRTC_BASE),A		; DO IT
	CALL	DLY1MS			; DELAY 1MS
	LD	A,C			; RECOVER WORKING VALUE
	RRCA				; ROTATE NEXT BIT TO SEND INTO BIT 7
	LD	C,A			; SAVE WORKING VALUE
	AND	%10000000		; ISOLATE THE DATA BIT
	OR	DSRTC_CE		; KEEP CE HIGH
	OUT	(DSRTC_BASE),A		; ASSERT DATA BIT ON BUS
	OR	DSRTC_CLK		; SET CLOCK HI
	OUT	(DSRTC_BASE),A		; DO IT
	CALL	DLY1MS			; DELAY 1MS
	DJNZ	DSRTC_PUT1		; LOOP IF NOT DONE
	RET
;
; READ BYTE FROM RTC, RETURN VALUE IN A
;   READ THE NEXT BYTE FROM THE RTC INTO A.  CE IS IMPLICITLY
;   ASSERTED AT THE START.  CE AND CLK ARE LEFT HIGH AT
;   THE END.  CLOCK *MUST* BE LEFT HIGH FROM DSRTC_CMD!
;
;   0) ASSUME ENTRY WITH CE HI, OTHERS UNDEFINED
;   1) SET RD HI AND CLOCK LOW
;   3) WAIT 250NS (CLOCK PUTS DATA BIT ON BUS)
;   4) READ DATA BIT
;   5) SET CLOCK HI
;   6) WAIT 250NS
;   7) LOOP FOR 8 DATA BITS
;   8) EXIT WITH CE,CLK,RD HI
;
DSRTC_GET:
	LD	C,0			; INITIALIZE WORKING VALUE TO 0
	LD	B,8			; LOOP FOR 8 BITS
DSRTC_GET1:
	LD	A,DSRTC_CE | DSRTC_RD	; SET CLK LO
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY1MS			; DELAY 1MS
	;CALL	DLY1MS			; DELAY 1MS
	IN	A,(DSRTC_BASE)		; READ THE RTC PORT
	AND	%00000001		; ISOLATE THE DATA BIT
	OR	C			; COMBINE WITH WORKING VALUE
	RRCA				; ROTATE FOR NEXT BIT
	LD	C,A			; SAVE WORKING VALUE
	LD	A,DSRTC_CE | DSRTC_CLK | DSRTC_RD	; CLOCK BACK TO HI
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	CALL	DLY1MS			; DELAY 1MS
	DJNZ	DSRTC_GET1		; LOOP IF NOT DONE (13)
	LD	A,C			; GET RESULT INTO A
	RET
;
; COMPLETE A COMMAND SEQUENCE
;   FINISHES UP A COMMAND SEQUENCE.
;   DOES NOT DESTROY ANY REGISTERS.
;
;   1) SET ALL LINES LO
;
DSRTC_END:
	PUSH	AF			; SAVE AF
	XOR	A			; ALL LINES OFF TO CLEAN UP
	OUT	(DSRTC_BASE),A		; WRITE TO RTC PORT
	POP	AF			; RESTORE AF
	RET
;
; WORKING VARIABLES
;
; DSRTC_BUF IS USED FOR BURST READ/WRITE OF CLOCK DATA TO DS-1302
; FIELDS BELOW MATCH ORDER OF DS-1302 FIELDS (BCD)
;
DSRTC_BUF:
DSRTC_SEC:	.DB	0		; SECOND
DSRTC_MIN:	.DB	0		; MINUTE
DSRTC_HR:	.DB	0		; HOUR
DSRTC_DT:	.DB	0		; DATE
DSRTC_MON:	.DB	0		; MONTH
DSRTC_DAY:	.DB	0		; DAY OF WEEK
DSRTC_YR:	.DB	0		; YEAR
;
; DSRTC_TIMBUF IS TEMP BUF USED TO STORE TIME TEMPORARILY TO DISPLAY
; IT.
;
DSRTC_TIMBUF	.FILL	6,0		; 6 BYTES FOR GETTIM
;
; DSRTC_TIMDEF IS DEFAULT TIME VALUE TO INITIALIZE CLOCK IF IT IS
; NOT RUNNING.
;
DSRTC_TIMDEF:	; DEFAULT TIME VALUE TO INIT CLOCK
		.DB	$00,$01,$01	; 2000-01-01
		.DB	$00,$00,$00	; 00:00:00
