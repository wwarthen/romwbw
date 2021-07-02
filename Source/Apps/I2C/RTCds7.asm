;==================================================================================================
; PCF8584 I2C Clock Driver
;==================================================================================================
;
	.ECHO	"rtcds7\n"
;
#INCLUDE "pcfi2c.inc"
;

;
        .ORG  100H
;
DS7_START:
	CALL	DS7_PROBE		; PROBE FRO DEVICE
	RET	Z			; EXIT IF DEVICE NOT FOUND
;
	LD	A,(FCB+1)		; GET FIRST CHAR 
	CP	' '			; COMPARE TO BLANK. IF SO NO
	JR	Z,DS7_ST0		; ARGUMENTS SO DISLAY TIME AND DATE
;
	LD	A,(FCB+1)		; GET FIRST CHAR 
	CP	'/'			; IS IT INDICATING AN ARGUMENT
	JR	NZ,DS7_ST0		; 
;
	LD	A,(FCB+2)		; GET NEXT CHARACTER
	CP	'D'			; 
	JR	NZ,DS7_ST1		; 
;
;	/D SET DATE
;
	RET
;
DS7_ST1:
	LD	A,(FCB+2)		; GET NEXT CHARACTER
	CP	'T'			; 
	JR	NZ,DS7_ST2		; 
;
;	/T SET TIME
;
	RET
;
DS7_ST2:
	LD	A,(FCB+2)		; GET NEXT CHARACTER
	CP	'S'			; 
	JR	NZ,DS7_ST3		; 
;
;	/S SET TIME AND DATE
;
	RET
;
DS7_ST3:
;
;	UNREGOGNIZED ARGUMENT
;
	RET
;
DS7_ST0:
        CALL   DS7_RDC         ; READ CLOCK DATA INTO BUFFER  
        CALL   DS7_DISP        ; DISPLAY TIME AND DATE FROM BUFFER 
	RET
;
;-----------------------------------------------------------------------------
; RETURN 00/Z IF NOT FOUND
;        NZ IF FOUND
;
;
DS7_PROBE:
	LD      A,PCF_PIN   	; SET PIN BIT
	OUT     (PCF_RS1),A
	NOP
	IN      A,(PCF_RS1)    	; CHECK IF SET
	AND	07FH
	JR	NZ,DS7_PR0	; ERROR IF NOT SET

	LD	A,'%'
	CALL	COUT

	OR	0FFH		; SUCCESS
	RET

DS7_PR0:
       LD      A,PCF_OWN    	; LOAD OWN ADDRESS IN S0,     
       OUT     (PCF_RS0),A    	; EFFECTIVE ADDRESS IS (OWN <<1)

       LD      A,PCF_IDLE_
       OUT     (PCF_RS1),A 

	CALL	PCF_INIERR	; DISLAY ERROR
	XOR	A		; SET ERROR
	RET
;
;-----------------------------------------------------------------------------
; RTC READ
;
; 1.	ISSUE SLAVE ADDRESS WITH START CONDITION AND WRITE STATUS
; 2.	OUTPUT THE ADDRESS TO ACCESS. (00H = START OF DS1307 REGISTERS)
; 3.	OUTPUT REPEAT START TO TRANSITION TO READ PROCESS
; 4.	ISSUE SLAVE ADDRESS WITH READ STATUS
; 5. 	DO A DUMMY READ 
; 6.	READ 8 BYTES STARTING AT ADDRESS PREVIOUSLY SET
; 7.	END READ WITH NON-ACKNOWLEDGE
; 8.	ISSUE STOP AND RELEASE BUS 
;
DS7_RDC:LD	A,DS7_WRITE	; SET SLAVE ADDRESS
        OUT	(REGS0),A
;
	CALL	PCF_WAIT_FOR_BB
	JP	NZ,PCF_BBERR
;
        CALL	PCF_START	; GENERATE START CONDITION
	CALL	PCF_WAIT_FOR_PIN; AND ISSUE THE SLAVE ADDRESS
	CALL	NZ,PCF_PINERR
;
        LD     	A,0
        OUT    	(REGS0),A    	; PUT ADDRESS MSB ON BUS
	CALL	PCF_WAIT_FOR_PIN
	CALL	NZ,PCF_PINERR
;
	CALL	PCF_REPSTART    ; REPEAT START
;
        LD	A,DS7_READ	; ISSUE CONTROL BYTE + READ
        OUT	(REGS0),A
;
	CALL	PCF_READI2C	; DUMMY READ
;
	LD	HL,DS7_BUF	; READ 8 BYTES INTO BUFFER
	LD	B,8
DS7_RL1:CALL	PCF_READI2C
	LD	(HL),A
	INC	HL
	DJNZ    DS7_RL1
;
#IF (0)
	LD	A,8
	LD	DE,DS7_BUF	; DISLAY DATA READ
	CALL	PRTHEXBUF	; 
	CALL   	NEWLINE
#ENDIF
;
	LD     	A,PCF_ES0	; END WITH NOT-ACKNOWLEDGE
	OUT    	(REGS1),A       ; AND RELEASE BUS
	NOP
	IN    	A,(REGS0)
	NOP
DS7_WTPIN:	
	IN	A,(REGS1)	; READ S1 REGISTER
	BIT	7,A		; CHECK PIN STATUS
	JP	NZ,DS7_WTPIN
	CALL   	PCF_STOP
;
	IN    	A,(REGS0)
        RET

;
;-----------------------------------------------------------------------------
; DISPLAY CLOCK INFORMATION FROM DATA STORED IN BUFFER
;
DS7_DISP:
	LD	HL,DS7_CLKTBL
DS7_CLP:LD	C,(HL)
	INC	HL
	LD	D,(HL)
	CALL	DS7_BCD
	INC	HL
	LD	A,(HL)
	OR      A
	RET	Z
        CALL	COUT
	INC	HL
	JR	DS7_CLP
	RET
;
DS7_CLKTBL:
	.DB	04H, 00111111B, '/'
	.DB	05H, 00011111B, '/'
	.DB	06H, 11111111B, ' '
	.DB	02H, 00011111B, ':'
	.DB	01H, 01111111B, ':'
	.DB	00H, 01111111B, 00H
;
DS7_BCD:PUSH	HL
	LD      HL,DS7_BUF     	; READ VALUE FROM
	LD      B,0           	; BUFFER, INDEXED BY A 
	ADD     HL,BC
	LD      A,(HL)
	AND     D             	; MASK OFF UNNEEDED
	SRL     A
	SRL     A
	SRL     A
	SRL     A      
	ADD     A,30H
	CALL    COUT
	LD      A,(HL)    
	AND     00001111B
	ADD     A,30H
	CALL    COUT
	POP	HL
	RET
;
DS7_BUF:	.FILL	8,0	; BUFFER FOR TIME, DATE AND CONTROL

;-----------------------------------------------------------------------------
PCF_START:
        LD     A,PCF_START_  
	OUT    (REGS1),A
	RET
;
;-----------------------------------------------------------------------------
PCF_REPSTART:
        LD     A,PCF_REPSTART_  
	OUT    (REGS1),A
	RET
;
;-----------------------------------------------------------------------------
PCF_STOP:   
	LD   	A,PCF_STOP_
        OUT  	(REGS1),A
        RET
;
;-----------------------------------------------------------------------------
;;
PCF_INIT:
       LD       A,PCF_PIN   	; S1=80H: S0 SELECTED, SERIAL 
       OUT     (REGS1),A    	; INTERFACE OFF
       NOP
       IN      A,(REGS1)    	; CHECK TO SEE S1 NOW USED AS R/W
       AND     07FH         	; CTRL. PCF8584 DOES THAT WHEN ESO
       JP      NZ,PCF_INIERR    ; IS ZERO
;
       LD      A,PCF_OWN    	; LOAD OWN ADDRESS IN S0,     
       OUT     (REGS0),A    	; EFFECTIVE ADDRESS IS (OWN <<1)
       NOP
       IN      A,(REGS0)    	; CHECK IT IS REALLY WRITTEN
       CP      PCF_OWN
       JP      NZ,PCF_SETERR
;
       LD      A,+(PCF_PIN | PCF_ES1) ; S1=0A0H
       OUT     (REGS1),A              ; NEXT BYTE IN S2
       NOP
       IN      A,(REGS1)
       AND     07FH
       CP      PCF_ES1
       JP      NZ,PCF_REGERR
;
       LD      A,PCF_CLK    	; LOAD CLOCK REGISTER S2
       OUT     (REGS0),A
       NOP
       IN      A,(REGS0)    	; CHECK IT'S REALLY WRITTEN, ONLY
       AND     1FH          	; THE LOWER 5 BITS MATTER
       CP      PCF_CLK
       JP      NZ,PCF_CLKERR
;
       LD      A,PCF_IDLE_
       OUT     (REGS1),A  
       NOP
       IN      A,(REGS1)  
       CP      +(PCF_PIN | PCF_BB)
       JP      NZ,PCF_IDLERR
;
       RET
;
;-----------------------------------------------------------------------------
PCF_HANDLE_LAB:
;
        LD     A,PCF_PIN  
	OUT    (REGS1),A        
        LD     A,PCF_ES0  
	OUT    (REGS1),A
;
        LD     HL,PCF_LABDLY
PCF_LABLP:
	LD     A,H
        OR     L
        DEC    HL  
        JR     NZ,PCF_LABLP
;
        IN     A,(REGS1)
        RET
;
;-----------------------------------------------------------------------------
;
; RETURN A=00/Z  IF SUCCESSFULL
; RETURN A=FF/NZ IF TIMEOUT
; RETURN A=01/NZ IF LOST ARBITRATION
; PCF_STATUS HOLDS LAST PCF STATUS
;
PCF_WAIT_FOR_PIN:
	PUSH	HL
        LD      HL,PCF_PINTO					; SET TIMEOUT VALUE

PCF_WFP0: 
	IN      A,(REGS1)					; GET BUS
	LD	(PCF_STATUS),A					; STATUS
	LD	B,A

	DEC	HL						; HAVE WE
	LD	A,H						; TIMED OUT
	OR	L
	JR	Z,PCF_WFP1					; YES WE HAVE, GO ACTION IT

	LD	A,B						; 		
        AND     PCF_PIN						; IS TRANSMISSION COMPLETE?
        JR	NZ,PCF_WFP0					; KEEP ASKING IF NOT OR
	POP	HL						; YES COMPLETE (PIN=0) RETURN WITH ZERO
	RET
PCF_WFP1:
	LD	A,B						; DID WE LOSE ARBITRATION?
	AND	PCF_LAB						; IF A=0 THEN NO
	CPL	
	JR	NZ,PCF_WFP2					; NO 
	CALL	PCF_HANDLE_LAB					; YES GO HANDLE IT
	LD	(PCF_STATUS),A
	XOR	A						; RETURN NZ, A=01H
	INC	A
PCF_WFP2:
	POP	HL                				; RET NZ, A=FF IF TIMEOUT 
	RET
;
PCF_STATUS	.DB	00H

;--------------------------------------------------------------------------------
;
; RETURN NZ/FF IF TIMEOUT ERROR
; RETURN NZ/01 IF FAILED TO RECEIVE ACKNOWLEDGE
; RETURN Z/00  IF RECEIVED ACKNOWLEDGE
;
PCF_WAIT_FOR_ACK:
	PUSH	HL
	LD	HL,PCF_ACKTO
;
PCF_WFA0:
	IN      A,(REGS1)	; READ PIN
        LD	(PCF_STATUS),A	; STATUS
        LD	B,A
;        
        DEC	HL		; SEE IF WE HAVE TIMED
        LD	A,H		; OUT WAITING FOR PIN
        OR	L		; EXIT IF
        JR	Z,PCF_WFA1	; WE HAVE
;        
        LD	A,B		; OTHERWISE KEEP LOOPING
        AND     PCF_PIN		; UNTIL WE GET PIN
        JR	NZ,PCF_WFA0	; OR TIMEOUT
;
	LD	A,B		; WE GOT PIN SO NOW
	AND	PCF_LRB		; CHECK WE HAVE
	LD	A,1
	JR	Z,PCF_WFA2	; RECEIVED ACKNOWLEDGE
	XOR	A
	JR	PCF_WFA2
PCF_WFA1:
	CPL			; TIMOUT ERROR
PCF_WFA2:
	POP	HL		; EXIT WITH NZ = FF
	RET
;	
;--------------------------------------------------------------------------------
;
;	HL POINTS TO DATA
;	DE = COUNT
;	A = 0 LAST A=1 NOT LAST
;
;
;PCF_READBYTES:			; NOT FUNCTIONAL YET

	LD	(PCF_LBF),A	; SAVE LAST BYTE FLAG
;
	INC	DE		; INCREMENT NUMBER OF BYTES TO READ BY ONE -- DUMMY READ BYTE
	LD	BC,0		; SET BYTE COUNTER
;
PCF_RBL:PUSH	BC
	CALL	PCF_WAIT_FOR_PIN	; DO WE HAVE THE BUS?
	POP	BC
	JR	Z,PCF_RB1	; YES
	CP	01H
	JR	Z,PCF_RB3	; NO - LOST ARBITRATION
	JR	PCF_RB2		; NO - TIMEOUT
;
PCF_RB1:
	LD	A,(PCF_STATUS)
	AND	PCF_LRB


	; IS THIS THE SECOND TO LAST BYTE TO GO?

	PUSH	DE		; SAVE COUNT	
	DEC	DE		; COUNT (DE) = NUMBER OF BYTES TO READ LESS 1
	EX	DE,HL		; SAVE POINTER, PUT COUNT IN DE
	XOR	A		; CLEAR CARRY FLAG
	SBC	HL,BC		; DOES BYTE COUNTER = HL (NUMBER OF BYTES TO READ LESS 1)
	EX	DE,HL		; RESTORE POINTER
	POP	DE		; RESTORE COUNT

				; Z = YES IT IS
				; NZ = NO IT ISN'T
	JR	NZ,PCF_RB4
;
PCF_RB4:LD	A,B		; IF FIRST READ DO A DUMMY 
	OR	C		; READ OTHERWISE READ AND SAVE
	JR	NZ,PCF_RB5

	IN	A,(REGS0)	; DUMMY READ
	JR	PCF_RB6

PCF_RB5:IN	A,(REGS0)	; READ AND SAVE
	LD	(HL),A
;
PCF_RB6:	; HAVE WE DONE ALL?

	PUSH	DE		; SAVE COUNT
	EX	DE,HL		; SAVE POINTER, PUT COUNT IN DE
	XOR	A		; CLEAR CARRY FLAG
	SBC	HL,BC		; DOES BYTE COUNTER = HL (NUMBER OF BYTES TO READ)
	EX	DE,HL		; RESTORE POINTER
	POP	DE		; RESTORE COUNT
;
	INC	HL		; BUFFER POINTER
	INC	BC		; COUNT
;
	JR	NZ,PCF_RBL	; REPEAT UNTIL COUNTS MATCH
	RET
;
PCF_RB2:			; TIMEOUT
	CALL	PCF_STOP
	CALL	PCF_TOERR
	RET
;
PCF_RB3:			; LOST ARBITRATION
	CALL	PCF_ARBERR
	RET
;
PCF_LBF:
	.DB	0		; LAST BYTE FLAG
;
;-----------------------------------------------------------------------------
; READ ONE BYTE FROM I2C
; RETURNS DATA IN A
; Z FLAG SET IS ACKNOWLEDGE RECEIVED (CORRECT OPERATION)
;
PCF_READI2C:
	IN	A,(REGS1)	; READ S1 REGISTER
	BIT	7,A		; CHECK PIN STATUS
	JP	NZ,PCF_READI2C
	BIT	3,A		; CHECK LRB=0
	JP	NZ,PCF_RDERR
	IN	A,(REGS0)	; GET DATA
	RET
;-----------------------------------------------------------------------------
;
; POLL THE BUS BUSY BIT TO DETERMINE IF BUS IS FREE.
; RETURN WITH A=00H/Z STATUS IF BUS IS FREE
; RETURN WITH A=FFH/NZ STATUS IF BUS
;
; AFTER RESET THE BUS BUSY BIT WILL BE SET TO 1 I.E. NOT BUSY
;
PCF_WAIT_FOR_BB:
        LD     HL,PCF_BBTO
PCF_WFBB0:
	IN     A,(REGS1)
        AND    PCF_BB
        RET    Z		; BUS IS FREE RETURN ZERO
        DEC    HL
        LD     A,H
        OR     L
        JR     NZ,PCF_WFBB0	; REPEAT IF NOT TIMED OUT
        CPL                	; RET NZ IF TIMEOUT  
	RET 
;
;-----------------------------------------------------------------------------
; DISPLAY ERROR MESSAGES
;
PCF_RDERR:
	PUSH	HL
	LD	HL,PCF_RDFAIL
	JR	PCF_PRTERR
;
PCF_INIERR:
	PUSH	HL
	LD      HL,PCF_NOPCF
	JR	PCF_PRTERR
;	
PCF_SETERR:
	PUSH	HL
	LD      HL,PCF_WRTFAIL
	JR	PCF_PRTERR
;
PCF_REGERR:
	PUSH	HL
	LD      HL,PCF_REGFAIL
	JR	PCF_PRTERR
;	
PCF_CLKERR:
	PUSH	HL
	LD      HL,PCF_CLKFAIL
	JR	PCF_PRTERR
;	
PCF_IDLERR:
	PUSH	HL
	LD      HL,PCF_IDLFAIL
	JR	PCF_PRTERR 
;	
PCF_ACKERR:
	PUSH	HL
	LD      HL,PCF_ACKFAIL
	JR	PCF_PRTERR
;
PCF_RDBERR:
	PUSH	HL
	LD	HL,PCF_RDBFAIL
	JR	PCF_PRTERR
;
PCF_TOERR:
	PUSH	HL
	LD	HL,PCF_TOFAIL
	JR	PCF_PRTERR
;
PCF_ARBERR:
	PUSH	HL
	LD	HL,PCF_ARBFAIL
	JR	PCF_PRTERR
;
PCF_PINERR:
	PUSH	HL
	LD	HL,PCF_PINFAIL
	JR	PCF_PRTERR
;
PCF_BBERR:
	PUSH	HL
	LD	HL,PCF_BBFAIL
	JR	PCF_PRTERR
;
PCF_PRTERR:
	CALL	PRTSTR
	CALL	NEWLINE
	POP	HL	
	RET
;
PCF_NOPCF	.DB	"NO DEVICE FOUND$"
PCF_WRTFAIL	.DB     "SETTING DEVICE ID FAILED$"
PCF_REGFAIL 	.DB     "CLOCK REGISTER SELECT ERROR$"
PCF_CLKFAIL 	.DB     "CLOCK SET FAIL$"
PCF_IDLFAIL 	.DB     "BUS IDLE FAILED$"
PCF_ACKFAIL 	.DB	"FAILED TO RECEIVE ACKNOWLEDGE$"
PCF_RDFAIL	.DB	"READ FAILED$"
PCF_RDBFAIL	.DB	"READBYTES FAILED$"
PCF_TOFAIL	.DB	"TIMEOUT ERROR$"
PCF_ARBFAIL 	.DB	"LOST ARBITRATION$"
PCF_PINFAIL 	.DB	"PIN FAIL$"
PCF_BBFAIL	.DB	"BUS BUSY$"
;
;-----------------------------------------------------------------------------
;
#INCLUDE "i2ccpm.inc"
;
        .END
