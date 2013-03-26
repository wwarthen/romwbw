;
;=============================================================================
;   SD DISK DRIVER
;=============================================================================
;
; - CATER FOR THE VARIOUS SDCARD HARDWARE VERSIONS
; CSIO IS FOR N8-2312 PRODUCTION BOARDS AND MODIFIED N8-2511 PROTOTYPE BOARDS
; RTC IS FOR UNMODIFIED N8-2511 BOARDS AND N8VEM/ZETA USING JUHA MINI-BOARDS 
; PPISD IS FOR A PPISD MINI-BOARD CONNECTED TO 26-PIN PPI HEADER
; - MAKE RTC A PSEUDO-REGISTER FOR NON-CSIO
; - PERFORM BOOT INITIALIZATION OF RTC SOMEWHERE ELSE???
; - PUT RELEVANT RTC BITS TO A KNOWN STATE AT ALL I/O ENTRY POINTS
;
;
#IF (DSD)
SD_OPS		.EQU	$08
#ELSE
SD_OPS		.EQU	RTC
#ENDIF
;
; CONTROL BITS
;
#IF (PLATFORM==PLT_N8)
SD_CS		.EQU	$04		; RTC BIT 2, SD CARD SELECT (ACTIVE HI)
  #IF (!SDCSIO)
SD_CLK		.EQU	$02		; RTC BIT 1, SD CLOCK
SD_DOUT		.EQU	$01		; RTC BIT 0, SD DATA OUT
SD_DIN		.EQU	$40		; RTC BIT 6, SD DATA IN
  #ENDIF
#ELSE
  #IF (PPISD)
SD_CS		.EQU	$10		; PC4, SD CARD SELECT (ACTIVE LO)
SD_CLK		.EQU	$02		; PC1, SD CLOCK
SD_DOUT		.EQU	$01		; PC0, SD DATA OUT
SD_DIN		.EQU	$80		; PB7, SD DATA IN
  #ELSE
    #IF (S2ISD)
SD_CS		.EQU	$08		; MCR:3 OUT2, CD,   ACT=LO=0
SD_CLK		.EQU	$04		; MCR:2 OUT1, CLK,  ACT=LO=1
SD_DIN		.EQU	$20		; MSR:5 DSR,  DAT0, ACT=HI=0
SD_DOUT		.EQU	$01		; MCR:0 DTR,  CMD,  ACT=HI=0
    #ELSE
      #IF (DSD)
SD_CS		.EQU	$04		; OPS BIT 2, SD CARD SELECT (ACTIVE HI)
SD_CLK		.EQU	$02		; OPS BIT 1, SD CLOCK
SD_DOUT		.EQU	$01		; OPS BIT 0, SD DATA OUT
SD_DIN		.EQU	$01		; OPS BIT 0, SD DATA IN
      #ELSE
SD_CS		.EQU	$04		; RTC BIT 2, SD CARD SELECT (ACTIVE HI)
SD_CLK		.EQU	$40		; RTC BIT 6, SD CLOCK
SD_DOUT		.EQU	$80		; RTC BIT 7, DATA OUT TO SD-CARD
SD_DIN		.EQU	$40		; RTC BIT 6, DATA IN FROM SD-CARD
      #ENDIF
    #ENDIF
  #ENDIF
#ENDIF
;
; SD CARD COMMANDS
;
SD_CMD0		.EQU	$40 | 0		; GO_IDLE_STATE
SD_CMD1		.EQU	$40 | 1		; SEND_OP_COND
SD_CMD8		.EQU	$40 | 8		; SEND_IF_COND
SD_CMD9		.EQU	$40 | 9		; SEND_CSD
SD_CMD10	.EQU	$40 | 10	; SEND_CID
SD_CMD16	.EQU	$40 | 16	; SET_BLOCKLEN
SD_CMD17	.EQU	$40 | 17	; READ_SINGLE_BLOCK
SD_CMD24	.EQU	$40 | 24	; WRITE_BLOCK
SD_CMD55	.EQU	$40 | 55	; APP_CMD
SD_CMD58	.EQU	$40 | 58	; READ_OCR
; SD APPLICATION SPECIFIC COMMANDS
SD_ACMD41	.EQU	$40 | 41	; SD_APP_OP_COND
;
; SD CARD TYPE
;
SD_TYPEUNK	.EQU	0
SD_TYPEMMC	.EQU	1
SD_TYPESDSC	.EQU	2
SD_TYPESDHC	.EQU	3
;
;
;
SD_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F
	JR	Z,SD_READ
	DEC	A
	JR	Z,SD_WRITE
	DEC	A
	JR	Z,SD_STATUS
	DEC	A
	JR	Z,SD_MEDIA
	CALL	PANIC
;
;
;
SD_MEDIA:
	; INITIALIZE THE SD CARD TO ACCOMMODATE HOT SWAPPING
	CALL	SD_INITCARD
	LD	A,MID_NONE	; ASSUME FAILURE
	RET	NZ		; INIT FAILED, RETURN WITH HL=0

	; SET READY AND RETURN
	XOR	A
	LD	(SD_STAT),A	; SD_STAT = 0 = OK
	LD	A,MID_HD
	RET
;
SD_INIT:
	PRTS("SD: IO=0x$")
#IF (!SDCSIO)
	LD	A,SD_OPS
#ELSE
	LD	A,CPU_CNTR
#ENDIF
	CALL	PRTHEXBYTE
	PRTS(" UNITS=1$")
;
	LD	A,20H		; PUT RTC LATCH TO IDLE
	OUT	(RTC),A
#IF (PPISD)
	LD	A,82H		; PPI PORT A=OUT, B=IN, C=OUT
	OUT	(PPIX),A
	LD	A,30H		; PC4,5 /CS HIGH
	OUT	(PPIC),A
#ENDIF
#IF (S2ISD)
	IN	A,(SIO_MCR)
	OR	SD_CS			; DEASSERT = HI = 1
	AND	~SD_DIN			; DEASSERT DIN = LO = 1
	AND	~SD_CLK			; DEASSERT CLK = LO = 1
	OUT	(SIO_MCR),A
#ENDIF
	XOR	A
	DEC	A
	LD	(SD_STAT),A
	RET
;
SD_STATUS:
	LD	A,(SD_STAT)
	OR	A
	RET
;
SD_READ:
	JP	SD_RDSEC
;
SD_WRITE:
	JP	SD_WRSEC
;
;=============================================================================
; SD INTERFACE ROUTINES
;=============================================================================
;
; SD_SENDCLKS: A=RTC MASK, B=# OF CLK TRANSITIONS
; For bit bang versions B is number of transitions
; For PPISD B is number of bits
; For CSIO B is number of bytes
SD_SENDCLKS:
#IF (!SDCSIO)
  #IF (PPISD)
	LD	A,03		;PC1=1, TOGGLE CLOCK
	OUT	(PPIX),A
	NOP
	LD	A,02		;PC1=0, RESET CLOCK
	OUT	(PPIX),A
  #ELSE
    #IF (S2ISD)
      OUT	(SIO_MCR),A
      XOR	SD_CLK
    #ELSE
	OUT	(SD_OPS),A
	XOR	SD_CLK		; TOGGLE CLOCK BIT
    #ENDIF
  #ENDIF
	DJNZ	SD_SENDCLKS
	RET
#ELSE
SD_SENDCLKS1:
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	LD	A,0FFH
	OUT0	(CPU_TRDR),A	; put byte in buffer
	IN0	A,(CPU_CNTR)
	SET	4,A		; set transmit enable
	OUT0	(CPU_CNTR),A
	DJNZ	SD_SENDCLKS
	RET

SD_WAITTX:			; WAIT FOR TX EMPTY	
	IN0	A,(CPU_CNTR)	; get CSIO status
	BIT	4,A		; Tx empty?
	JR	NZ,SD_WAITTX
	RET

SD_WAITRX:
	IN0	A,(CPU_CNTR)	; wait for receiver to finish
	BIT	5,A
	JR	NZ,SD_WAITRX
	RET
#ENDIF
;
; COMPLETE A TRANSACTION - PRESERVE AF
;
SD_DONE:
	PUSH	AF
#IF (!SDCSIO)
  #IF (PPISD)
	LD	A,30H
	OUT	(PPIC),A	;PC4=1 /CS INACTIVE
	LD	B,16
  #ELSE
    #IF (S2ISD)
	IN	A,(SIO_MCR)
	OR	SD_CS		; TURN OFF CS
	OUT	(SIO_MCR),A
	LD	B,17
    #ELSE
	XOR	A
	LD	B,17
    #ENDIF
  #ENDIF
	CALL	SD_SENDCLKS
#ELSE
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	IN	A,(SD_OPS)
	AND	~SD_CS		; CLEAR CS
	OUT	(SD_OPS),A
	LD	B,2
	CALL	SD_SENDCLKS
#ENDIF
	POP	AF
	RET
;
; SEND ONE BYTE
;
SD_PUT:
#IF (PPISD)
;	CALL	PRTHEXBYTE	; *DEBUG*
	LD	C,A		; C=BYTE TO SEND
	LD	B,8		; SEND 8 BITS (LOOP 8 TIMES)
	LD	A,08H		;PC4=0, /CS ACTIVE
	OUT	(PPIX),A
SD_PUT1:
	RL	C		;ROTATE NEXT BIT FROM C INTO CF
	LD	A,01		;PC0=1, DATA OUT=1
	JR	C,SD_PUT2
	LD	A,00		;PC0=0, DATA OUT =0
SD_PUT2:
	OUT	(PPIX),A	;SEND DATA OUT
	LD	A,03		;PC1=1, TOGGLE CLOCK
	OUT	(PPIX),A
	LD	A,02		;PC1=0, RESET CLOCK
	OUT	(PPIX),A
	DJNZ	SD_PUT1		;REPEAT FOR ALL 8 BITS
	RET
#ELSE
  #IF (S2ISD)
;	CALL	PRTHEXBYTE	; *DEBUG*
	XOR	$FF		; INVERT FOR S2ISD INTERFACE
	LD	C,A		; C=BYTE TO SEND
	LD	B,8		; SEND 8 BITS (LOOP 8 TIMES)
	IN	A,(SIO_MCR)	; START WITH CURRENT MCR REG VAUE
SD_PUT1:
	RRA			; PREPARE A FOR ROTATE
	RL	C		; ROTATE NEXT DATA BIT FROM C INTO CF
	RLA			; ROTATE DATA BIT INTO A:0
	OR	SD_CLK		; ASSERT CLOCK
	OUT	(SIO_MCR),A	; SEND IT
	AND	~SD_CLK		; DEASSERT CLOCK
	OUT	(SIO_MCR),A	; SEND IT
	DJNZ	SD_PUT1		; REPEAT FOR ALL 8 BITS
	RET
  #ELSE
    #IF (!SDCSIO)
;	CALL	PRTHEXBYTE	; *DEBUG*
	LD	C,A		; C=BYTE TO SEND
	LD	B,8		; SEND 8 BITS (LOOP 8 TIMES)
SD_PUT1:
      #IF ((PLATFORM == PLT_N8) | DSD)
	LD	A,2		; SD_CS >> 1 (SD_CS WILL BE SET AFTER ROTATE)
	RL	C		; ROTATE NEXT BIT FROM C INTO CF
	RLA			; ROTATE CF INTO A:0, SD_DOUT is RTC:0
      #ELSE
	LD	A,8		; SD_CS WILL BE IN BIT2 AFTER ROTATE
	RL	C		; ROTATE NEXT BIT FROM C INTO CF
	RRA			; ROTATE CARRY INTO A:7, SD_DOUT is RTC:7
      #ENDIF
	OUT	(SD_OPS),A	; CLOCK LOW (ABOUT TO SEND BIT)
	OR	SD_CLK		; SET CLOCK BIT
	OUT	(SD_OPS),A		; CLOCK HIGH (SEND BIT)
	DJNZ	SD_PUT1		; REPEAT FOR ALL 8 BITS
	AND	~SD_CLK		; RESET CLOCK
	OUT	(SD_OPS),A	; LEAVE WITH CLOCK LOW
	RET
    #ELSE
	CALL	MIRROR		; MSB<-->LSB mirror bits, result in C
	CALL	SD_WAITRX	; MAKE SURE WE ARE DONE SENDING
	OUT0	(CPU_TRDR),C	; put byte in buffer
	IN0	A,(CPU_CNTR)
	SET	4,A		; set transmit enable
	OUT0	(CPU_CNTR),A
	RET			; let it do the rest
    #ENDIF
  #ENDIF
#ENDIF
;
; RECEIVE ONE BYTE
;
SD_GET:
#IF (PPISD)
	LD	B,8		; RECEIVE 8 BITS (LOOP 8 TIMES)
SD_GET1:
	IN	A,(PPIB)	; GET BIT FROM SD-CARD
	RLA			; ROTATE PB7 INTO CARRY
	RL	C		; ROTATE CARRY INTO C
	LD	A,03		; PC1=1, TOGGLE CLOCK
	OUT	(PPIX),A
	LD	A,02		; PC1=0, RESET CLOCK
	OUT	(PPIX),A
	DJNZ	SD_GET1		; REPEAT FOR ALL 8 BITS
	LD	A,C		; GET BYTE RECEIVED INTO A
;	CALL	PRTHEXBYTE	; *DEBUG*
	RET
#ELSE
  #IF (S2ISD)
	LD	B,8		; SEND 8 BITS (LOOP 8 TIMES)
SD_GET1:
	IN	A,(SIO_MCR)	; GET CURRENT MCR TO TOGGLE CLK
	OR	SD_CLK		; SET CLK
	OUT	(SIO_MCR),A	; SEND IT
	
	NOP

	IN	A,(SIO_MSR)	; MSR:5 HAS DATA BIT
	RLA			; ROTATE DATA BIT TO A:6
	RLA			; ROTATE DATA BIT TO A:7
	RLA			; ROTATE DATA BIT TO CF
	RL	C		; NOW ROTATE CF INTO C:0

	IN	A,(SIO_MCR)	; GET CURRENT MCR TO TOGGLE CLK
	AND	~SD_CLK		; CLEAR CLK
	OUT	(SIO_MCR),A	; SEND IT

	DJNZ	SD_GET1		; REPEAT FOR ALL 8 BITS
	LD	A,C		; GET BYTE RECEIVED INTO A
	XOR	$FF		; INVERT FOR S2ISD INTERFACE
;	CALL	PC_PERIOD	; *DEBUG*
;	CALL	PRTHEXBYTE	; *DEBUG*
	RET
  #ELSE
    #IF (!SDCSIO)
	LD	B,8		; RECEIVE 8 BITS (LOOP 8 TIMES)
SD_GET1:
	IN	A,(SD_OPS)	; GET RTC BITS
      #IF (DSD)
	RRA			; ROTATE OPS:0 (SD_IN) INTO CF
      #ELSE
	RLA			; ROTATE RTC:6 (SD_IN) INTO CF
	RLA
      #ENDIF
	RL	C		; ROTATE CF INTO C:0
	LD	A,SD_CS | SD_DOUT | SD_CLK
	OUT	(SD_OPS),A	; CLOCK HIGH (ACK BIT RECEIVED)
	AND	~SD_CLK		; RESET CLOCK BIT
	OUT	(SD_OPS),A	; CLOCK LOW (READY FOR NEXT BIT)
	DJNZ	SD_GET1		; REPEAT FOR ALL 8 BITS
	LD	A,C		; GET BYTE RECEIVED INTO A
;	CALL	PRTHEXBYTE	; *DEBUG*
	RET
    #ELSE
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	IN0	A,(CPU_CNTR)	; get CSIO status
	SET	5,A		; start receiver
	OUT0	(CPU_CNTR),A
	CALL	SD_WAITRX
	IN0	A,(CPU_TRDR)	; get received byte
	CALL	MIRROR		; MSB<-->LSB mirror bits
	LD	A,C		; keep result
	RET
    #ENDIF
  #ENDIF
#ENDIF

#IF (SDCSIO)
MIRROR:				; MSB<-->LSB mirror bits in A, result in C
  #IF (!SDCSIOFAST)		; slow speed, least code space
	LD      B,8		; bit counter
MIRROR1:
	RLA			; rotate bit 7 into carry
	RR	C		; rotate carry into result
	DJNZ	MIRROR1		; do all 8 bits
	RET
  #ELSE				; fastest but uses most code space
	LD	BC,MIRTAB	; 256 byte mirror table
	ADD	A,C		; add offset
	LD	C,A
	JR	NC,MIRROR2
	INC	B
MIRROR2:
	LD	A,(BC)		; get result
	LD	C,A		; return result in C
	RET
  #ENDIF
#ENDIF

;
; SELECT CARD AND WAIT FOR IT TO BE READY ($FF)
;
SD_WAITRDY:
#IF (PPISD)
	LD	A,21H		;/CS ACTIVE (PC4), DOUT=1 (PC0)
	OUT	(PPIC),A
#ELSE
  #IF (S2ISD)
	IN	A,(SIO_MCR)
	AND	~SD_CS		; ASSERT CS (1)
	OUT	(SIO_MCR),A
  #ELSE
	IN	A,(SD_OPS)
    #IF (!SDCSIO)
	OR	SD_CS | SD_DOUT	; SET SD_CS (CHIP SELECT)
    #ELSE
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	OR	SD_CS		; SET SD_CS (CHIP SELECT)
    #ENDIF
	OUT	(SD_OPS),A
  #ENDIF
#ENDIF
	LD	DE,0		; LOOP MAX (TIMEOUT)
SD_WAITRDY1:
;	CALL	PC_SPACE	; *DEBUG*
	CALL	SD_GET
;	CALL	PRTHEXBYTE	; *DEBUG*
;	XOR	A		; *DEBUG* TO SIMULATE READY TIMEOUT
	INC	A		; $FF -> $00
	RET	Z		; IF READY, RETURN
	DEC    DE
	LD	A,D
	OR	E
	JR	NZ,SD_WAITRDY1	; KEEP TRYING UNTIL TIMEOUT
	LD	A,$FF		; SIGNAL TIMEOUT ERROR
	OR	A		; SET FLAGS
	RET			; TIMEOUT
;
; SD_GETDATA
;
SD_GETDATA:
	PUSH	BC		; SAVE LENGTH TO RECEIVE
	LD	DE,$7FFF	; LOOP MAX (TIMEOUT)
SD_GETDATA1:
	CALL	SD_GET
	CP	$FF		; WANT BYTE != $FF
	JR	NZ,SD_GETDATA2	; NOT $FF, MOVE ON
	DEC    DE
	BIT	7,D
	JR	Z,SD_GETDATA1	; KEEP TRYING UNTIL TIMEOUT
SD_GETDATA2:
	LD	(SD_TOK),A
	POP	DE		; RESTORE LENGTH TO RECEIVE
	CP	$FE		; PACKET START?
	JR	NZ,SD_GETDATA4	; NOPE, ABORT, A HAS ERROR CODE
	LD	HL,(DIOBUF)	; RECEIVE BUFFER
SD_GETDATA3:
	CALL	SD_GET		; GET NEXT BYTE
	LD	(HL),A		; SAVE IT
	INC	HL
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,SD_GETDATA3	; LOOP FOR ALL BYTES
	CALL	SD_GET		; DISCARD CRC BYTE 1
	CALL	SD_GET		; DISCARD CRC BYTE 2
	XOR	A		; RESULT IS ZERO
SD_GETDATA4:
	RET
;
; SD_PUTDATA
;
SD_PUTDATA:
	PUSH	BC		; SAVE LENGTH TO SEND
	
	LD	A,$FE		; PACKET START
	CALL	SD_PUT		; SEND IT

	POP	DE		; RESTORE LENGTH TO SEND
	LD	HL,(DIOBUF)	; RECEIVE BUFFER
SD_PUTDATA1:
	LD	A,(HL)		; GET NEXT BYTE TO SEND
	CALL	SD_PUT		; SEND IF
	INC	HL
	DEC	DE
	LD	A,D
	OR	E
	JR	NZ,SD_PUTDATA1	; LOOP FOR ALL BYTES
	LD	A,$FF		; DUMMY CRC BYTE
	CALL	SD_PUT
	LD	A,$FF		; DUMMY CRC BYTE
	CALL	SD_PUT
	LD	DE,$7FFF	; LOOP MAX (TIMEOUT)
SD_PUTDATA2:
	CALL	SD_GET
	CP	$FF		; WANT BYTE != $FF
	JR	NZ,SD_PUTDATA3	; NOT $FF, MOVE ON
	DEC    	DE
	BIT	7,D
	JR	Z,SD_PUTDATA2	; KEEP TRYING UNTIL TIMEOUT
SD_PUTDATA3:
	AND	$1F
	LD	(SD_TOK),A
	CP	$05
	RET	NZ
	XOR	A
	RET
;
; SETUP COMMAND BUFFER
;
SD_SETCMD0:	; NO PARMS
	LD	HL,SD_CMDBUF
	LD	(HL),A
	INC	HL
	XOR	A
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	(HL),A
	INC	HL
	LD	A,$FF
	LD	(HL),A
	RET
;
SD_SETCMDP:	; W/ PARMS IN BC & DE
	CALL	SD_SETCMD0
	LD	HL,SD_CMDP0
	LD	(HL),B
	INC	HL
	LD	(HL),C
	INC	HL
	LD	(HL),D
	INC	HL
	LD	(HL),E
	RET	
;
; EXECUTE A SD CARD COMMAND
;
SD_EXEC:
	XOR	A
	LD	(SD_RC),A
	LD	(SD_TOK),A
	LD	HL,SD_CMDBUF
	LD	E,6		; COMMANDS ARE 6 BYTES
SD_EXEC1:
#IF (SDCSIO)
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	IN	A,(SD_OPS)
	OR	SD_CS		; SET CS
	OUT	(SD_OPS),A
#ENDIF
#IF (S2ISD)
	IN	A,(SIO_MCR)
	AND	~SD_CS			; ASSERT = LO = 0
	OUT	(SIO_MCR),A
#ENDIF
	LD	A,(HL)
	CALL	SD_PUT
	INC	HL
	DEC	E
	JR	NZ,SD_EXEC1
	LD	DE,$100		; LOOP MAX (TIMEOUT)
SD_EXEC2:
	CALL	SD_GET
	OR	A		; SET FLAGS
	JP	P,SD_EXEC3	; IF HIGH BIT IS 0, WE HAVE RESULT
	DEC	DE
	BIT	7,D
	JR	Z,SD_EXEC2
SD_EXEC3:
	LD	(SD_RC),A
#IF (SDTRACE >= 2)
	CALL	SD_PRTTRN
#ENDIF
#IF (DSKYENABLE)
	CALL	SD_DSKY
#ENDIF
	RET
;	
SD_EXECCMD0:	; EXEC COMMAND, NO PARMS
	CALL	SD_SETCMD0
	JR	SD_EXEC
;
SD_EXECCMDP:	; EXEC CMD W/ PARMS IN BC/DE
	CALL	SD_SETCMDP
	JR	SD_EXEC
;
; PUT CARD IN IDLE STATE
;
SD_GOIDLE:
	; SMALL DELAY HERE HELPS SOME CARDS
	LD	DE,200			; 5 MILISECONDS
	CALL	VDELAY

	; PUT CARD IN IDLE STATE
	LD	A,SD_CMD0		; CMD0 = ENTER IDLE STATE
	CALL	SD_SETCMD0
	LD	A,$95
	LD	(SD_CMDBUF+5),A		; SET CRC=$95
	CALL	SD_EXEC			; EXEC CMD
	CP	$01			; IN IDLE STATE?
	CALL	SD_DONE
	RET
;
; INIT CARD
;
SD_INITCARD:
#IF (PPISD)
	LD	A,82H			; PPI PORT A=OUT, B=IN, C=OUT
	OUT	(PPIX),A
	LD	A,30H			; PC4,5 /CS HIGH
	OUT	(PPIC),A
#ENDIF
#IF (PLATFORM == PLT_N8)
	LD	A,20H			; PUT RTC LATCH TO IDLE
	OUT	(SD_OPS),A
#ENDIF
#IF (DSD)
	XOR	A			; PUT OPS LATCH TO IDLE
	OUT	(SD_OPS),A
#ENDIF
	
#IF (SDCSIO)
	; CSIO SETUP
;	LD	A,02			; 18MHz/20 <= 400kHz
	LD	A,06			; ???
	OUT0	(CPU_CNTR),A
#ENDIF
	CALL	SD_DONE			; SEEMS TO HELP SOME CARDS...

#IF (!SDCSIO)
  #IF (PPISD)
	LD	A,21H			; /CS=0, DOUT=1, CLK=0
	OUT	(PPIC),A
	LD	B,07FH			; 127 CLOCKS (255 TRANSITIONS STARTING WITH LO)
  #ELSE
    #IF (S2ISD)
      IN	A,(SIO_MCR)
      OR	SD_CS			; DEASSERT CS = HI = 1
      AND	~SD_DIN			; ASSERT DIN = HI = 0
      AND	~SD_CLK			; DEASSERT CLK = HI = 0
	LD	B,0FFH			; 127 CLOCKS (255 TRANSITIONS STARTING WITH LO)
    #ELSE
	LD	A,SD_CS | SD_DOUT	; CS=HI, DOUT=HI
	LD	B,0FFH			; 127 CLOCKS (255 TRANSITIONS STARTING WITH LO)
    #ENDIF
  #ENDIF
#ELSE
	CALL	SD_WAITTX		; MAKE SURE WE ARE DONE SENDING
	IN	A,(SD_OPS)
	OR	SD_CS			; SET CS
	OUT	(SD_OPS),A
	LD	B,16
#ENDIF
	CALL	SD_SENDCLKS		; INIT DELAY + GO SPI MODE

	; WAIT FOR CARD TO BE READY FOR A COMMAND
	CALL	SD_WAITRDY
	JP	NZ,SD_ERRRDYTO

	; PUT CARD IN IDLE STATE
	CALL	SD_GOIDLE
	CALL	NZ,SD_GOIDLE		; SOME CARDS REQUIRE A SECOND ATTEMPT
	JP	NZ,SD_ERRCMD		; GIVE UP

SD_INITCARD00:
	LD	A,SD_TYPESDSC		; ASSUME SDSC CARD TYPE
	LD	(SD_TYPE),A		; SAVE IT
	
	; CMD8 IS REQUIRED FOR V2 CARDS.  FAILURE HERE IS OK AND
	; JUST MEANS THAT IT IS A V1.X CARD
	LD	A,SD_CMD8
	
	LD	BC,0
	LD	D,1			; VHS=1, 2.7-3.6V
	LD	E,$AA			; CHECK PATTERN
	CALL	SD_SETCMDP
	LD	A,$87
	LD	(SD_CMDBUF+5),A		; SET CRC=$87
	CALL	SD_EXEC			; EXEC CMD
	AND	~$01
	JR	NZ,SD_INITCARD0
	
	; CMD8 WORKED, SO THIS IS V2 CARD
	; NEED TO CONSUME EXTRA CMD8 RESPONSE BYTES (4)
	CALL	SD_GET
	CALL	SD_GET
	CALL	SD_GET
	CALL	SD_GET
	
SD_INITCARD0:
	CALL	SD_DONE

	LD	B,0		; LOOP LIMIT (TIMEOUT)
SD_INITCARD1:
	; CALL SD_APP_OP_COND UNTIL CARD IS READY (NOT IDLE)
	LD	DE,200		; 5 MILLISECONDS
	CALL	VDELAY
	LD	A,SD_CMD55	; APP CMD IS NEXT
	PUSH	BC
	CALL	SD_EXECCMD0
	POP	BC
	AND	~$01		; ONLY 0 (OK) OR 1 (IDLE) ARE OK
	CALL	SD_DONE
	JP	NZ,SD_ERRCMD
	LD	A,SD_ACMD41	; SD_APP_OP_COND
	PUSH	BC
	LD	BC,$4000	; INDICATE WE SUPPORT HC
	LD	DE,$0000
	CALL	SD_EXECCMDP
	POP	BC
	PUSH	AF
	AND	~$01
	CALL	SD_DONE
	POP	AF
;	LD	A,$01		; *DEBUG* TO SIMULATE INIT TIMEOUT ERROR
	CP	$00		; INIT DONE?
	JR	Z,SD_INITCARD2	; YUP, MOVE ON
	CP	$01		; IDLE?
	JP	NZ,SD_ERRCMD	; NOPE, MUST BE CMD ERROR, ABORT
	DJNZ	SD_INITCARD1	; KEEP CHECKING
	LD	A,$FF		; SIGNAL TIMEOUT
	OR	A
	JP	SD_ERRINITTO
	
SD_INITCARD2:
	; CMD58 RETURNS THE 32 BIT OCR REGISTER, WE WANT TO CHECK
	; BIT 30, IF SET THIS IS SDHC/XC CARD
	LD	A,SD_CMD58
	CALL	SD_EXECCMD0
	CALL	NZ,SD_DONE
	JP	NZ,SD_ERRCMD
	
	; CMD58 WORKED, GET OCR DATA AND SET CARD TYPE
	CALL	SD_GET		; BITS 31-24
	AND	$40		; ISOLATE BIT 30 (CCS)
	JR	Z,SD_INITCARD21	; NOT HC/XC, BYPASS
	LD	A,SD_TYPESDHC	; CARD TYPE = SDHC
	LD	(SD_TYPE),A	; SAVE IT
SD_INITCARD21:
	CALL	SD_GET		; BITS 23-16, DISCARD
	CALL	SD_GET		; BITS 15-8, DISCARD
	CALL	SD_GET		; BITS 7-0, DISCARD
	CALL	SD_DONE
	
	; SET OUR DESIRED BLOCK LENGTH (512 BYTES)
	LD	A,SD_CMD16	; SET_BLOCK_LEN
	LD	BC,0
	LD	DE,512
	CALL	SD_EXECCMDP
	CALL	SD_DONE
	JP	NZ,SD_ERRCMD
	
#IF (SDTRACE >= 2)
	CALL	NEWLINE
	LD	DE,SDSTR_SDTYPE
	CALL	WRITESTR
	LD	A,(SD_TYPE)
	CALL	PRTHEXBYTE
#ENDIF

;	RET	NZ		; IF ERROR, ABORT NOW WITH A SET CORRECTLY

#IF (SDCSIO)
	CALL	SD_WAITTX	; MAKE SURE WE ARE DONE SENDING
	XOR	A		; NOW SET CSIO PORT TO FULL SPEED
	OUT	(CPU_CNTR),A
#ENDIF

	XOR	A		; A = 0 (STATUS = OK)
	LD	(SD_STAT),A	; SAVE IT
	RET			; RETURN WITH A=0, AND Z SET
;;
;; GET AND PRINT CSD, CID
;;
;SD_CARDINFO:
;	LD	A,SD_CMD9	; SEND_CSD
;	CALL	SD_EXECCMD0
;	CALL	SD_DONE
;	JP	NZ,SD_ERRCMD	; ABORT IF PROBLEM
;	LD	BC,16		; 16 BYTES OF CSD
;	CALL	SD_GETDATA
;	CALL	SD_DONE
;	
;	LD	DE,SDSTR_CSD
;	CALL	WRITESTR
;	LD	DE,SECBUF
;	LD	A,16
;	CALL	PRTHEXBUF
;	
;	LD	A,SD_CMD10	; SEND_CID
;	CALL	SD_EXECCMD0
;	CALL	SD_DONE
;	JP	NZ,SD_ERRCMD	; ABORT IF PROBLEM
;	LD	BC,16		; 16 BYTES OF CID
;	CALL	SD_GETDATA
;	CALL	SD_DONE
;	
;	LD	DE,SDSTR_CID
;	CALL	WRITESTR
;	LD	DE,SECBUF
;	LD	A,16
;	CALL	PRTHEXBUF
;	
;	RET
;
; READ ONE SECTOR
;

;
; CHECK THE SD CARD, ATTEMPT TO REINITIALIZE IF NEEDED
;
SD_CHKCARD:
	LD	A,(SD_STAT)		; GET STATUS
	OR	A			; SET FLAGS
	CALL	NZ,SD_INITCARD		; INIT CARD IF NOT READY
	RET				; RETURN WITH STATUS IN A

SD_RDSEC:
	CALL	SD_CHKCARD	; CHECK / REINIT CARD AS NEEDED
	RET	NZ

	CALL	SD_WAITRDY	; WAIT FOR CARD TO BE READY FOR A COMMAND
	JP	NZ,SD_ERRRDYTO	; HANDLE NOT READY TIMEOUT ERROR

	CALL	SD_SETADDR	; SETUP BLOCK ADDRESS

	LD	A,SD_CMD17	; READ_SINGLE_BLOCK
	CALL	SD_EXECCMDP	; EXEC CMD WITH BLOCK ADDRESS AS PARM
	CALL	NZ,SD_DONE	; TRANSACTION DONE IF ERROR OCCURRED
	JP	NZ,SD_ERRCMD	; ABORT ON ERROR
	
	LD	BC,512		; LENGTH TO READ
	CALL	SD_GETDATA	; GET THE BLOCK
	CALL	SD_DONE
	JP	NZ,SD_ERRDATA	; DATA XFER ERROR
	RET
;
; WRITE ONE SECTOR
;
SD_WRSEC:
	CALL	SD_CHKCARD	; CHECK / REINIT CARD AS NEEDED
	RET	NZ

	CALL	SD_WAITRDY	; WAIT FOR CARD TO BE READY FOR A COMMAND
	JP	NZ,SD_ERRRDYTO	; HANDLE NOT READY TIMEOUT ERROR

	CALL	SD_SETADDR	; SETUP BLOCK ADDRESS

	LD	A,SD_CMD24	; WRITE_BLOCK
	CALL	SD_EXECCMDP	; EXEC CMD WITH BLOCK ADDRESS AS PARM
	CALL	NZ,SD_DONE	; TRANSACTION DONE IF ERROR OCCURRED
	JP	NZ,SD_ERRCMD	; ABORT ON ERROR
	
	LD	BC,512		; LENGTH TO WRITE
	CALL	SD_PUTDATA	; PUT THE BLOCK
	CALL	SD_DONE
	JP	NZ,SD_ERRDATA	; DATA XFER ERROR
	RET
;
;	
;
SD_SETADDR:
	LD	A,(SD_TYPE)
	CP	SD_TYPESDSC
	JR	Z,SD_SETADDRSDSC
	CP	SD_TYPESDHC
	JR	Z,SD_SETADDRSDHC
	CALL	PANIC

SD_SETADDRSDSC:
	LD	HL,(HSTSEC)
	LD	E,0
	LD	D,L
	LD	HL,(HSTTRK)
	LD	C,L
	LD	B,H
	XOR	A
	RL	D
	RL	C
	RL	B
	RET

SD_SETADDRSDHC:
	LD	A,(HSTSEC)	; GET SECTOR (LSB ONLY)
	LD	E,A		; PUT IN E
	LD	HL,(HSTTRK)	; GET TRACK
	LD	D,L		; TRACK LSB -> D
	LD	C,H		; TRACK MSB -> C
	LD	B,0		; B ALWAYS ZERO
	RET
;
; HANDLE READY TIMEOUT ERROR
;
SD_ERRRDYTO:
#IF (SDTRACE >= 1)
	CALL	SD_PRTPREFIX
	LD	DE,SDSTR_ERRRDYTO
#ENDIF
	JR	SD_CARDERR
;
; HANDLE INIT TIMEOUT ERROR
;
SD_ERRINITTO:
#IF (SDTRACE >= 1)
	CALL	SD_PRTPREFIX
	LD	DE,SDSTR_ERRINITTO
#ENDIF
	JR	SD_CARDERR
;
; HANDLE COMMAND ERROR
;
SD_ERRCMD:
#IF (SDTRACE == 1)
	CALL	SD_PRTTRN
#ENDIF
#IF (SDTRACE >= 1)
	LD	DE,SDSTR_ERRCMD
#ENDIF
	JR	SD_CARDERR
;
; HANDLE COMMAND ERROR
;
SD_ERRDATA:
#IF (SDTRACE == 1)
	CALL	SD_PRTTRN
#ENDIF
#IF (SDTRACE >= 1)
	LD	DE,SDSTR_ERRDATA
#ENDIF
	JR	SD_CARDERR
;
; GENERIC ERROR HANDLER, DE POINTS TO ERROR STRING
;
SD_CARDERR:
	PUSH	AF
	XOR	A
	DEC	A
	LD	A,FALSE
	LD	(SD_STAT),A
#IF (SDTRACE >= 1)
	CALL	PC_SPACE
	CALL	PC_LBKT
	CALL	WRITESTR
	CALL	PC_RBKT
#ENDIF
	POP	AF
	LD	(SD_STAT),A
	RET
;
; PRINT DIAGNONSTIC PREFIX
;
SD_PRTPREFIX:
	CALL	NEWLINE
	LD	DE,SDSTR_PREFIX
	CALL	WRITESTR
	RET
;
; PRT COMMAND TRACE
;
SD_PRTTRN:
	PUSH	AF
	
	CALL	SD_PRTPREFIX

	LD	DE,SD_CMDBUF
	LD	A,6
	CALL	PRTHEXBUF
	CALL	PC_SPACE
	LD	DE,SDSTR_ARROW
	CALL	WRITESTR
	CALL	PC_SPACE

	LD	DE,SDSTR_RC
	CALL	WRITESTR
	LD	A,(SD_RC)
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	
	LD	DE,SDSTR_TOK
	CALL	WRITESTR
	LD	A,(SD_TOK)
	CALL	PRTHEXBYTE
	
	POP	AF
	RET

;
; DISPLAY COMMAND, LOW ORDER WORD OF PARMS, AND RC
;
#IF (DSKYENABLE)
SD_DSKY:
	PUSH	AF
	LD	HL,DSKY_HEXBUF
	LD	A,(SD_CMD)
	LD	(HL),A
	INC	HL
	LD	A,(SD_CMDP2)
	LD	(HL),A
	INC	HL
	LD	A,(SD_CMDP3)
	LD	(HL),A
	INC	HL
	LD	A,(SD_RC)
	CALL	DSKY_HEXOUT
	POP	AF
	RET
#ENDIF
;
;
;
#IF (SDCSIOFAST)
MIRTAB:	.DB 00H, 80H, 40H, 0C0H, 20H, 0A0H, 60H, 0E0H, 10H, 90H, 50H, 0D0H, 30H, 0B0H, 70H, 0F0H
	.DB 08H, 88H, 48H, 0C8H, 28H, 0A8H, 68H, 0E8H, 18H, 98H, 58H, 0D8H, 38H, 0B8H, 78H, 0F8H
	.DB 04H, 84H, 44H, 0C4H, 24H, 0A4H, 64H, 0E4H, 14H, 94H, 54H, 0D4H, 34H, 0B4H, 74H, 0F4H
	.DB 0CH, 8CH, 4CH, 0CCH, 2CH, 0ACH, 6CH, 0ECH, 1CH, 9CH, 5CH, 0DCH, 3CH, 0BCH, 7CH, 0FCH
	.DB 02H, 82H, 42H, 0C2H, 22H, 0A2H, 62H, 0E2H, 12H, 92H, 52H, 0D2H, 32H, 0B2H, 72H, 0F2H
	.DB 0AH, 8AH, 4AH, 0CAH, 2AH, 0AAH, 6AH, 0EAH, 1AH, 9AH, 5AH, 0DAH, 3AH, 0BAH, 7AH, 0FAH
	.DB 06H, 86H, 46H, 0C6H, 26H, 0A6H, 66H, 0E6H, 16H, 96H, 56H, 0D6H, 36H, 0B6H, 76H, 0F6H
	.DB 0EH, 8EH, 4EH, 0CEH, 2EH, 0AEH, 6EH, 0EEH, 1EH, 9EH, 5EH, 0DEH, 3EH, 0BEH, 7EH, 0FEH
	.DB 01H, 81H, 41H, 0C1H, 21H, 0A1H, 61H, 0E1H, 11H, 91H, 51H, 0D1H, 31H, 0B1H, 71H, 0F1H
	.DB 09H, 89H, 49H, 0C9H, 29H, 0A9H, 69H, 0E9H, 19H, 99H, 59H, 0D9H, 39H, 0B9H, 79H, 0F9H
	.DB 05H, 85H, 45H, 0C5H, 25H, 0A5H, 65H, 0E5H, 15H, 95H, 55H, 0D5H, 35H, 0B5H, 75H, 0F5H
	.DB 0DH, 8DH, 4DH, 0CDH, 2DH, 0ADH, 6DH, 0EDH, 1DH, 9DH, 5DH, 0DDH, 3DH, 0BDH, 7DH, 0FDH
	.DB 03H, 83H, 43H, 0C3H, 23H, 0A3H, 63H, 0E3H, 13H, 93H, 53H, 0D3H, 33H, 0B3H, 73H, 0F3H
	.DB 0BH, 8BH, 4BH, 0CBH, 2BH, 0ABH, 6BH, 0EBH, 1BH, 9BH, 5BH, 0DBH, 3BH, 0BBH, 7BH, 0FBH
	.DB 07H, 87H, 47H, 0C7H, 27H, 0A7H, 67H, 0E7H, 17H, 97H, 57H, 0D7H, 37H, 0B7H, 77H, 0F7H
	.DB 0FH, 8FH, 4FH, 0CFH, 2FH, 0AFH, 6FH, 0EFH, 1FH, 9FH, 5FH, 0DFH, 3FH, 0BFH, 7FH, 0FFH
#ENDIF
;
;
;
SDSTR_PREFIX	.TEXT	"SD:$"
SDSTR_ARROW	.TEXT	"-->$"
SDSTR_RC	.TEXT	"RC=$"
SDSTR_TOK	.TEXT	"TOK=$"
SDSTR_OK	.TEXT	"OK$"
SDSTR_ERR	.TEXT	"ERR$"
SDSTR_ERRRDYTO	.TEXT	"READY TIMEOUT$"
SDSTR_ERRINITTO	.TEXT	"INIT TIMEOUT$"
SDSTR_ERRCMD	.TEXT	"CMD ERR$"
SDSTR_ERRDATA	.TEXT	"DATA ERR$"
SDSTR_SDTYPE	.TEXT	"SD CARD TYPE: $"
;
;==================================================================================================
;   SD DISK DRIVER - DATA
;==================================================================================================
;
SD_STAT		.DB	0
SD_TYPE		.DB	0
SD_RC		.DB	0
SD_TOK		.DB	0
SD_CMDBUF	.EQU	$
SD_CMD		.DB	0
SD_CMDP0	.DB	0
SD_CMDP1	.DB	0
SD_CMDP2	.DB	0
SD_CMDP3	.DB	0
SD_CMDCRC	.DB	0
