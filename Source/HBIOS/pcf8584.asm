;==================================================================================================
; PCF8584 I2C CLOCK DRIVER
;==================================================================================================
;
PCF_BASE  	.EQU  0F0H
PCF_ID   	.EQU  0AAH
CPU_CLK	  	.EQU  12

PCF_RS0     	.EQU  PCF_BASE
PCF_RS1    	.EQU  PCF_RS0+1
PCF_OWN	 	.EQU  (PCF_ID >> 1)        	; PCF'S ADDRESS IN SLAVE MODE
;
;T4LC512D	.EQU	10100000B		; DEVICE IDENTIFIER
;T4LC512A1	.EQU	00000000B		; DEVICE ADDRESS
;T4LC512A2	.EQU	00001110B		; DEVICE ADDRESS
;T4LC512A3	.EQU	00000010B		; DEVICE ADDRESS
;T4LC512W	.EQU	00000000B		; DEVICE WRITE
;T4LC512R	.EQU	00000001B		; DEVICE READ
;
;I2CDEV1W  	.EQU	(T4LC512D+T4LC512A1+T4LC512W)
;I2CDEV1R	.EQU	(T4LC512D+T4LC512A1+T4LC512R)
;
;I2CDEV2W  	.EQU	(T4LC512D+T4LC512A2+T4LC512W)
;I2CDEV2R	.EQU	(T4LC512D+T4LC512A2+T4LC512R)
;
;I2CDEV3W  	.EQU	(T4LC512D+T4LC512A3+T4LC512W)
;I2CDEV3R	.EQU	(T4LC512D+T4LC512A3+T4LC512R)
;
; CONTROL REGISTER BITS
;
PCF_PIN  	.EQU  10000000B
PCF_ES0  	.EQU  01000000B
PCF_ES1  	.EQU  00100000B
PCF_ES2  	.EQU  00010000B
PCF_EN1  	.EQU  00001000B
PCF_STA  	.EQU  00000100B
PCF_STO  	.EQU  00000010B
PCF_ACK  	.EQU  00000001B
;
PCF_START_    	.EQU  (PCF_PIN | PCF_ES0 | PCF_STA | PCF_ACK)
PCF_STOP_     	.EQU  (PCF_PIN | PCF_ES0 | PCF_STO | PCF_ACK)
PCF_REPSTART_ 	.EQU  (          PCF_ES0 | PCF_STA | PCF_ACK)
PCF_IDLE_     	.EQU  (PCF_PIN | PCF_ES0           | PCF_ACK)
;
; STATUS REGISTER BITS
;
;PCF_PIN  	.EQU  10000000B
PCF_INI   	.EQU  01000000B   ; 1 if not initialized 
PCF_STS   	.EQU  00100000B
PCF_BER   	.EQU  00010000B
PCF_AD0   	.EQU  00001000B
PCF_LRB   	.EQU  00001000B
PCF_AAS   	.EQU  00000100B
PCF_LAB   	.EQU  00000010B
PCF_BB    	.EQU  00000001B
;
; CLOCK CHIP FREQUENCIES
;
PCF_CLK3   	.EQU	000H
PCF_CLK443 	.EQU	010H
PCF_CLK6   	.EQU	014H
PCF_CLK8   	.EQU	018H
PCF_CLK12  	.EQU	01cH
;
; TRANSMISSION FREQUENCIES
;
PCF_TRNS90 	.EQU	000H	;  90 kHz */
PCF_TRNS45 	.EQU	001H	;  45 kHz */
PCF_TRNS11 	.EQU	002H	;  11 kHz */
PCF_TRNS15 	.EQU	003H	; 1.5 kHz */
;
; TIMEOUT AND DELAY VALUES (ARBITRARY)
;
PCF_PINTO	.EQU	65000
PCF_ACKTO	.EQU	65000
PCF_BBTO	.EQU	65000
PCF_LABDLY	.EQU	65000
;
; DATA PORT REGISTERS
;
#IF (CPU_CLK = 443)
PCF_CLK .EQU PCF_CLK4433
#ELSE 
 #IF (CPU_CLK = 8)
PCF_CLK .EQU PCF_CLK8
 #ELSE 
  #IF (CPU_CLK = 12)
PCF_CLK .EQU PCF_CLK12
  #ELSE ***ERROR
  #ENDIF
 #ENDIF	
#ENDIF
;
; THE PCF8584 TARGETS A TOP I2C CLOCK SPEED OF 90KHZ AND SUPPORTS DIVIDERS FOR 
; 3, 4.43, 6, 8 AND 12MHZ TO ACHEIVE THIS.
;
; +--------------------------------------------------------------------------------------------+
; | div/clk |  2MHz |  4MHz  |  6MHz | 7.38Mhz |  10MHz | 12MHz |  16MHz | 18.432Mhz |  20MHz  |
; +----------------------------------------------------------------------------------+---------+
; |   3MHz  | 60Khz | 120Khz |       |         |        |       |        |           |         |
; | 4.43MHz |       |  81Khz |       |         |        |       |        |           |         | 
; |   6MHz  |       |        | 90Khz | 110Khz  |        |       |        |           |         |
; |   8MHz  |       |        |       |  83Khz  | 112Khz |       |        |           |         |
; |  12MHz  |       |        |       |         |        | 90Khz | 120Khz |   138Khz  |  150Khz |
; +----------------------------------------------------------------------------------+---------+
;
PCF8584_INIT:
	CALL	NEWLINE				; Formatting
	PRTS("I2C: IO=0x$")
	LD	A, PCF_BASE
	CALL	PRTHEXBYTE
	CALL	PCF_INIT
	CALL	NEWLINE
	RET
;
; LINUX DRIVER BASED CODE
;
;	I2C_INB		= IN A,(PCF_RS0)
;	I2C_OUTB	= LD A,* | OUT (PCF_RS0),A
;	SET_PCF		-= LD A,* | OUT (PCF_RS1),A
;	GET_PCF		= IN A,(PCF_RS1)
;	
;-----------------------------------------------------------------------------
PCF_START:
        LD     A,PCF_START_  
	OUT    (PCF_RS1),A
	RET
;
;-----------------------------------------------------------------------------
PCF_REPSTART:
        LD     A,PCF_REPSTART_  
	OUT    (PCF_RS1),A
	RET
;
;-----------------------------------------------------------------------------
PCF_STOP:   
	LD   	A,PCF_STOP_
        OUT  	(PCF_RS1),A
        RET
;
;-----------------------------------------------------------------------------
;
PCF_INIT:
       LD       A,PCF_PIN   	; S1=80H: S0 SELECTED, SERIAL 
       OUT     (PCF_RS1),A    	; INTERFACE OFF
       NOP
       IN      A,(PCF_RS1)    	; CHECK TO SEE S1 NOW USED AS R/W
       AND     07FH         	; CTRL. PCF8584 DOES THAT WHEN ESO
       JP      NZ,PCF_INIERR    ; IS ZERO
;
       LD      A,PCF_OWN    	; LOAD OWN ADDRESS IN S0,     
       OUT     (PCF_RS0),A    	; EFFECTIVE ADDRESS IS (OWN <<1)
       NOP
       IN      A,(PCF_RS0)    	; CHECK IT IS REALLY WRITTEN
       CP      PCF_OWN
       JP      NZ,PCF_SETERR
;
       LD      A,+(PCF_PIN | PCF_ES1) ; S1=0A0H
       OUT     (PCF_RS1),A              ; NEXT BYTE IN S2
       NOP
       IN      A,(PCF_RS1)
       AND     07FH
       CP      PCF_ES1
       JP      NZ,PCF_REGERR
;
       LD      A,PCF_CLK    	; LOAD CLOCK REGISTER S2
       OUT     (PCF_RS0),A
       NOP
       IN      A,(PCF_RS0)    	; CHECK IT'S REALLY WRITTEN, ONLY
       AND     1FH          	; THE LOWER 5 BITS MATTER
       CP      PCF_CLK
       JP      NZ,PCF_CLKERR
;
       LD      A,PCF_IDLE_
       OUT     (PCF_RS1),A  
       NOP
       IN      A,(PCF_RS1)  
       CP      +(PCF_PIN | PCF_BB)
       JP      NZ,PCF_IDLERR
;
       RET
;
;-----------------------------------------------------------------------------
PCF_HANDLE_LAB:
;
        LD     A,PCF_PIN  
	OUT    (PCF_RS1),A        
        LD     A,PCF_ES0  
	OUT    (PCF_RS1),A
;
        LD     HL,PCF_LABDLY
PCF_LABLP:
	LD     A,H
        OR     L
        DEC    HL  
        JR     NZ,PCF_LABLP
;
        IN     A,(PCF_RS1)
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
	IN      A,(PCF_RS1)					; GET BUS
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
	IN      A,(PCF_RS1)	; READ PIN
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

	IN	A,(PCF_RS0)	; DUMMY READ
	JR	PCF_RB6

PCF_RB5:IN	A,(PCF_RS0)	; READ AND SAVE
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
	IN	A,(PCF_RS1)	; READ S1 REGISTER
	BIT	7,A		; CHECK PIN STATUS
	JP	NZ,PCF_READI2C
	BIT	3,A		; CHECK LRB=0
	JP	NZ,PCF_RDERR
	IN	A,(PCF_RS0)	; GET DATA
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
	IN     A,(PCF_RS1)
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
;-----------------------------------------------------------------------------
; DEBUG HELPER
;
#IF (1)
PCF_DBG:
	PUSH	AF
        PUSH 	DE
        PUSH   	HL
	LD	A,'['
	CALL	COUT
	LD	HL,PCF_DBGF
	LD	A,(HL)
	ADD	A,'0'
	INC	(HL)
	CALL	COUT
	LD	A,']'
	CALL	COUT
        POP 	HL
        POP  	DE
        POP  	AF
	RET
PCF_DBGF:	
	.DB	0		; DEBUG STAGE COUNTER
#ENDIF
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
