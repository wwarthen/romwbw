;
;==================================================================================================
; UART DRIVER (SERIAL PORT)
;==================================================================================================
;
UART_DEBUG		.EQU	FALSE
;
UART_NONE		.EQU	0	; UNKNOWN OR NOT PRESENT
UART_8250		.EQU	1
UART_16450		.EQU	2
UART_16550		.EQU	3
UART_16550A		.EQU	4
UART_16550C		.EQU	5
UART_16650		.EQU	6
UART_16750		.EQU	7
UART_16850		.EQU	8
;
UART_RBR		.EQU	0	; DLAB=0: RCVR BUFFER REG (READ)
UART_THR		.EQU	0	; DLAB=0: XMIT HOLDING REG (WRITE)
UART_IER		.EQU	1	; DLAB=0: INT ENABLE REG (READ)
UART_IIR		.EQU	2	; INT IDENT REGISTER (READ)
UART_FCR		.EQU	2	; FIFO CONTROL REG (WRITE)
UART_LCR		.EQU	3	; LINE CONTROL REG (READ/WRITE)
UART_MCR		.EQU	4	; MODEM CONTROL REG (READ/WRITE)
UART_LSR		.EQU	5	; LINE STATUS REG (READ)
UART_MSR		.EQU	6	; MODEM STATUS REG (READ)
UART_SCR		.EQU	7	; SCRATCH REGISTER (READ/WRITE)
UART_DLL		.EQU	0	; DLAB=1: DIVISOR LATCH (LS) (READ/WRITE)
UART_DLM		.EQU	1	; DLAB=1: DIVISOR LATCH (MS) (READ/WRITE)
UART_EFR		.EQU	2	; LCR=$BF: ENHANCED FEATURE REG (READ/WRITE)
;
#DEFINE	UART_IN(RID)	CALL UART_INP \ .DB RID
#DEFINE	UART_OUT(RID)	CALL UART_OUTP \ .DB RID
;
#IF (UARTCNT >= 1)
UART0_RBR		.EQU	UART0IOB + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
UART0_THR		.EQU	UART0IOB + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
UART0_IER		.EQU	UART0IOB + 1	; DLAB=0: INT ENABLE REG
UART0_IIR		.EQU	UART0IOB + 2	; INT IDENT REGISTER (READ ONLY)
UART0_FCR		.EQU	UART0IOB + 2	; FIFO CONTROL REG (WRITE ONLY)
UART0_LCR		.EQU	UART0IOB + 3	; LINE CONTROL REG
UART0_MCR		.EQU	UART0IOB + 4	; MODEM CONTROL REG
UART0_LSR		.EQU	UART0IOB + 5	; LINE STATUS REG
UART0_MSR		.EQU	UART0IOB + 6	; MODEM STATUS REG
UART0_SCR		.EQU	UART0IOB + 7	; SCRATCH REGISTER
UART0_DLL		.EQU	UART0IOB + 0	; DLAB=1: DIVISOR LATCH (LS)
UART0_DLM		.EQU	UART0IOB + 1	; DLAB=1: DIVISOR LATCH (MS)
UART0_EFR		.EQU	UART0IOB + 2	; ENHANCED FEATURE (WHEN LCR = $BF)
;
#ENDIF
;
#IF (UARTCNT >= 2)
UART1_RBR		.EQU	UART1IOB + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
UART1_THR		.EQU	UART1IOB + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
UART1_IER		.EQU	UART1IOB + 1	; DLAB=0: INT ENABLE REG
UART1_IIR		.EQU	UART1IOB + 2	; INT IDENT REGISTER (READ ONLY)
UART1_FCR		.EQU	UART1IOB + 2	; FIFO CONTROL REG (WRITE ONLY)
UART1_LCR		.EQU	UART1IOB + 3	; LINE CONTROL REG
UART1_MCR		.EQU	UART1IOB + 4	; MODEM CONTROL REG
UART1_LSR		.EQU	UART1IOB + 5	; LINE STATUS REG
UART1_MSR		.EQU	UART1IOB + 6	; MODEM STATUS REG
UART1_SCR		.EQU	UART1IOB + 7	; SCRATCH REGISTER
UART1_DLL		.EQU	UART1IOB + 0	; DLAB=1: DIVISOR LATCH (LS)
UART1_DLM		.EQU	UART1IOB + 1	; DLAB=1: DIVISOR LATCH (MS)
UART1_EFR		.EQU	UART1IOB + 2	; ENHANCED FEATURE (WHEN LCR = $BF)
;
#ENDIF
;
#IF (UARTCNT >= 3)
UART2_RBR		.EQU	UART2IOB + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
UART2_THR		.EQU	UART2IOB + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
UART2_IER		.EQU	UART2IOB + 1	; DLAB=0: INT ENABLE REG
UART2_IIR		.EQU	UART2IOB + 2	; INT IDENT REGISTER (READ ONLY)
UART2_FCR		.EQU	UART2IOB + 2	; FIFO CONTROL REG (WRITE ONLY)
UART2_LCR		.EQU	UART2IOB + 3	; LINE CONTROL REG
UART2_MCR		.EQU	UART2IOB + 4	; MODEM CONTROL REG
UART2_LSR		.EQU	UART2IOB + 5	; LINE STATUS REG
UART2_MSR		.EQU	UART2IOB + 6	; MODEM STATUS REG
UART2_SCR		.EQU	UART2IOB + 7	; SCRATCH REGISTER
UART2_DLL		.EQU	UART2IOB + 0	; DLAB=1: DIVISOR LATCH (LS)
UART2_DLM		.EQU	UART2IOB + 1	; DLAB=1: DIVISOR LATCH (MS)
UART2_EFR		.EQU	UART2IOB + 2	; ENHANCED FEATURE (WHEN LCR = $BF)
;
#ENDIF
;
#IF (UARTCNT >= 4)
UART3_RBR		.EQU	UART3IOB + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
UART3_THR		.EQU	UART3IOB + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
UART3_IER		.EQU	UART3IOB + 1	; DLAB=0: INT ENABLE REG
UART3_IIR		.EQU	UART3IOB + 2	; INT IDENT REGISTER (READ ONLY)
UART3_FCR		.EQU	UART3IOB + 2	; FIFO CONTROL REG (WRITE ONLY)
UART3_LCR		.EQU	UART3IOB + 3	; LINE CONTROL REG
UART3_MCR		.EQU	UART3IOB + 4	; MODEM CONTROL REG
UART3_LSR		.EQU	UART3IOB + 5	; LINE STATUS REG
UART3_MSR		.EQU	UART3IOB + 6	; MODEM STATUS REG
UART3_SCR		.EQU	UART3IOB + 7	; SCRATCH REGISTER
UART3_DLL		.EQU	UART3IOB + 0	; DLAB=1: DIVISOR LATCH (LS)
UART3_DLM		.EQU	UART3IOB + 1	; DLAB=1: DIVISOR LATCH (MS)
UART3_EFR		.EQU	UART3IOB + 2	; ENHANCED FEATURE (WHEN LCR = $BF)
;
#ENDIF
;
; CHARACTER DEVICE DRIVER ENTRY
;   A: RESULT (OUT), CF=ERR
;   B: FUNCTION (IN)
;   C: CHARACTER (IN/OUT)
;   E: DEVICE/UNIT (IN)
;
;
UART_INIT:
#IF (UARTCNT >= 1)
	CALL	UART0_INIT
#ENDIF
#IF (UARTCNT >= 2)
	CALL	UART1_INIT
#ENDIF
#IF (UARTCNT >= 3)
	CALL	UART2_INIT
#ENDIF
#IF (UARTCNT >= 4)
	CALL	UART3_INIT
#ENDIF
	RET
;
;
;
UART_DISPATCH:
	LD	A,C	; GET DEVICE/UNIT
	AND	$0F	; ISOLATE UNIT
#IF (UARTCNT >= 1)
	JP	Z,UART0_DISPATCH
#ENDIF
#IF (UARTCNT >= 2)
	DEC	A
	JP	Z,UART1_DISPATCH
#ENDIF
#IF (UARTCNT >= 3)
	DEC	A
	JP	Z,UART2_DISPATCH
#ENDIF
#IF (UARTCNT >= 4)
	DEC	A
	JP	Z,UART3_DISPATCH
#ENDIF
	CALL	PANIC

;
;
;
#IF (UARTCNT >= 1)
;
UART0_INIT:
	PRTS("UART0: IO=0x$")
	LD	A,UART0IOB
	CALL	PRTHEXBYTE
;
	; SETUP FOR GENERIC INIT ROUTINE
	LD	(UART_BASE),A		; IO BASE ADDRESS
	LD	DE,UART0OSC >> 16
	LD	(UART_OSCHI),DE
	LD	DE,UART0OSC & $FFFF
	LD	(UART_OSCLO),DE
	LD	DE,UART0BAUD >> 16
	LD	(UART_BAUDHI),DE
	LD	DE,UART0BAUD & $FFFF
	LD	(UART_BAUDLO),DE
;
	; MAP REQUESTED FEATURES TO FLAGS IN UART_FUNC
	XOR	A			; START WITH NO FEATURES
#IF (UART0FIFO)
	SET	UART_FIFO,A		; TURN ON FIFO BIT IF REQUESTED
#ENDIF
#IF (UART0AFC)
	SET	UART_AFC,A		; TURN ON AFC BIT IF REQUESTED
#ENDIF
	LD	(UART_FUNC),A		; SAVE IT
;
	JP	UART_INITP		; HAND OFF TO GENERIC INIT CODE
;
;
;
UART0_DISPATCH:
	LD	A,B	; GET REQUESTED FUNCTION
	AND	$0F	; ISOLATE SUB-FUNCTION
	JP	Z,UART0_IN
	DEC	A
	JP	Z,UART0_OUT
	DEC	A
	JP	Z,UART0_IST
	DEC	A
	JP	Z,UART0_OST
	CALL	PANIC
;
;
;
UART0_IN:
	CALL	UART0_IST
	OR	A
	JR	Z,UART0_IN
	IN	A,(UART0_RBR)	; READ THE CHAR FROM THE UART
	LD	E,A
	RET
;
;
;
UART0_IST:
	IN	A,(UART0_LSR)		; READ LINE STATUS REGISTER
	AND	$01			; TEST IF DATA IN RECEIVE BUFFER
	JP	Z,CIO_IDLE		; DO IDLE PROCESSING AND RETURN
	XOR	A
	INC	A			; SIGNAL CHAR READY, A = 1
	RET
;
;
;
UART0_OUT:
	CALL	UART0_OST
	OR	A
	JR	Z,UART0_OUT
	LD	A,E
	OUT	(UART0_THR),A		; THEN WRITE THE CHAR TO UART
	RET
;
UART0_OST:
	IN	A,(UART0_LSR)		; READ LINE STATUS REGISTER
	AND	$20
	JP	Z,CIO_IDLE		; DO IDLE PROCESSING AND RETURN
	XOR	A
	INC	A			; SIGNAL BUFFER EMPTY, A = 1
	RET
;
#ENDIF
;
;
;
#IF (UARTCNT >= 2)
;
UART1_INIT:
	CALL	NEWLINE
	PRTS("UART1: IO=0x$")
	LD	A,UART1IOB
	CALL	PRTHEXBYTE
;
	; SETUP FOR GENERIC INIT ROUTINE
	LD	(UART_BASE),A		; IO BASE ADDRESS
	LD	DE,UART1OSC >> 16
	LD	(UART_OSCHI),DE
	LD	DE,UART1OSC & $FFFF
	LD	(UART_OSCLO),DE
	LD	DE,UART1BAUD >> 16
	LD	(UART_BAUDHI),DE
	LD	DE,UART1BAUD & $FFFF
	LD	(UART_BAUDLO),DE
;
	; MAP REQUESTED FEATURES TO FLAGS IN UART_FUNC
	XOR	A			; START WITH NO FEATURES
#IF (UART1FIFO)
	SET	UART_FIFO,A		; TURN ON FIFO BIT IF REQUESTED
#ENDIF
#IF (UART1AFC)
	SET	UART_AFC,A		; TURN ON AFC BIT IF REQUESTED
#ENDIF
	LD	(UART_FUNC),A		; SAVE IT
;
	JP	UART_INITP		; HAND OFF TO GENERIC INIT CODE
;
;
;
UART1_DISPATCH:
	LD	A,B	; GET REQUESTED FUNCTION
	AND	$0F	; ISOLATE SUB-FUNCTION
	JP	Z,UART1_IN
	DEC	A
	JP	Z,UART1_OUT
	DEC	A
	JP	Z,UART1_IST
	DEC	A
	JP	Z,UART1_OST
	CALL	PANIC
;
;
;
UART1_IN:
	CALL	UART1_IST
	OR	A
	JR	Z,UART1_IN
	IN	A,(UART1_RBR)	; READ THE CHAR FROM THE UART
	LD	E,A
	RET
;
;
;
UART1_IST:
	IN	A,(UART1_LSR)		; READ LINE STATUS REGISTER
	AND	$01			; TEST IF DATA IN RECEIVE BUFFER
	JP	Z,CIO_IDLE		; DO IDLE PROCESSING AND RETURN
	XOR	A
	INC	A			; SIGNAL CHAR READY, A = 1
	RET
;
;
;
UART1_OUT:
	CALL	UART1_OST
	OR	A
	JR	Z,UART1_OUT
	LD	A,E
	OUT	(UART1_THR),A		; THEN WRITE THE CHAR TO UART
	RET
;
UART1_OST:
	IN	A,(UART1_LSR)		; READ LINE STATUS REGISTER
	AND	$20
	JP	Z,CIO_IDLE		; DO IDLE PROCESSING AND RETURN
	XOR	A
	INC	A			; SIGNAL BUFFER EMPTY, A = 1
	RET
;
#ENDIF
;
; UART INITIALIZATION ROUTINE
;
UART_INITP:
	; WAIT FOR ANY IN-FLIGHT DATA TO BE SENT
	LD	B,0			; LOOP TIMEOUT COUNTER
UART_INITP00:
	UART_IN(UART_LSR)		; GET LINE STATUS REGISTER
	BIT	6,A			; TEST BIT 6 (TRANSMITTER EMPTY)
	JR	NZ,UART_INITP0		; EMPTY, CONTINUE
	LD	DE,100			; DELAY 100 * 16US
	CALL	VDELAY			; NORMALIZE TIMEOUT TO CPU SPEED
	DJNZ	UART_INITP00		; KEEP CHECKING UNTIL TIMEOUT

UART_INITP0:
	; DETECT THE UART TYPE
	CALL	UART_DETECT		; DETERMINE UART TYPE
	LD	(UART_TYPE),A		; SAVE TYPE

	; HL IS USED BELOW TO REFER TO FEATURE BITS ENABLED
	LD	HL,UART_FEAT		; HL POINTS TO FEATURE FLAGS BYTE
	XOR	A			; RESET ALL FEATURES
	LD	(HL),A			; SAVE IT

	; START OF UART INITIALIZATION, SET BAUD RATE
	LD	A,80H
	UART_OUT(UART_LCR)		; DLAB ON
	CALL	UART_COMPDIV		; COMPUTE DIVISOR TO BC
	LD	A,B
	UART_OUT(UART_DLM)		; SET DIVISOR (MS)
	LD	A,C
	UART_OUT(UART_DLL)		; SET DIVISOR (LS)
	
	; SET LCR TO DEFAULT
	LD	A,$03			; DLAB OFF, 8 DATA, 1 STOP, NO PARITY
	UART_OUT(UART_LCR)		; SAVE IT

	; SET MCR TO DEFAULT
	LD	A,$03			; DTR + RTS
	UART_OUT(UART_MCR)		; SAVE IT
	
	LD	A,(UART_TYPE)		; GET UART TYPE
	CP	UART_16550A		; 16550A OR BETTER?
	JR	C,UART_INITP1		; NOPE, SKIP FIFO & AFC FEATURES

	LD	B,0			; START BY ASSUMING NO FIFOS, FCR=0
	LD	A,(UART_FUNC)		; LOAD FIFO ENABLE REQUEST VALUE
	BIT	UART_FIFO,A		; TEST FOR FIFO REQUESTED
	JR	Z,UART_FIFO1		; NOPE
	LD	B,$07			; VALUE TO ENABLE AND RESET FIFOS
	SET	UART_FIFO,(HL)		; RECORD FEATURE ENABLED
UART_FIFO1:
	LD	A,B			; MOVE VALUE TO A
	UART_OUT(UART_FCR)		; DO IT

	LD	A,(UART_TYPE)		; GET UART TYPE
	CP	UART_16550C		; 16550C OR BETTER?
	JR	C,UART_INITP1		; NOPE, SKIP AFC FEATURES

	; BRANCH BASED ON TYPE AFC CONFIGURATION (EFR OR MCR)
	LD	A,(UART_TYPE)		; GET UART TYPE
	CP	UART_16650		; 16650?
	JR	Z,UART_AFC2		; USE EFR REGISTER
	CP	UART_16850		; 16750?
	JR	Z,UART_AFC2		; USE EFR REGISTER
	
	; SET AFC VIA MCR
	LD	B,$03			; START WITH DEFAULT MCR
	LD	A,(UART_FUNC)		; LOAD AFC ENABLE REQUEST VALUE
	BIT	UART_AFC,A		; TEST FOR AFC REQUESTED
	JR	Z,UART_AFC1		; NOPE
	SET	5,B			; SET MCR BIT TO ENABLE AFC
	SET	UART_AFC,(HL)		; RECORD FEATURE ENABLED
UART_AFC1:
	LD	A,B			; MOVE VALUE TO Ar
	UART_OUT(UART_MCR)		; SET AFC VALUE VIA MCR
	JR	UART_INITP1		; AND CONTINUE
	
UART_AFC2:	; SET AFC VIA EFR
	LD	A,$BF			; VALUE TO ACCESS EFR
	UART_OUT(UART_LCR)		; SET VALUE IN LCR
	
	LD	B,0			; ASSUME AFC OFF, EFR=0
	LD	A,(UART_FUNC)		; LOAD AFC ENABLE REQUEST VALUE
	BIT	UART_AFC,A		; TEST FOR AFC REQUESTED
	JR	Z,UART_AFC3		; NOPE
	LD	B,$C0			; ENABLE CTS/RTS FLOW CONTROL
	SET	UART_AFC,(HL)		; RECORD FEATURE ENABLED
UART_AFC3:
	LD	A,B			; MOVE VALUE TO A
	UART_OUT(UART_EFR)		; SAVE IT
	LD	A,$03			; NORMAL LCR VALUE
	UART_OUT(UART_LCR)		; SAVE IT

UART_INITP1:
#IF (UART_DEBUG)
	PRTS(" [$")
	
	; DEBUG: DUMP UART TYPE
	LD	A,(UART_TYPE)
	CALL	PRTHEXBYTE

	; DEBUG: DUMP IIR
	UART_IN(UART_IIR)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE

	; DEBUG: DUMP LCR
	UART_IN(UART_LCR)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE

	; DEBUG: DUMP MCR
	UART_IN(UART_MCR)
	CALL	PC_SPACE
	CALL	PRTHEXBYTE

	; DEBUG: DUMP EFR
	LD	A,$BF
	UART_OUT(UART_LCR)
	UART_IN(UART_EFR)
	PUSH	AF
	LD	A,$03
	UART_OUT(UART_LCR)
	POP	AF
	CALL	PC_SPACE
	CALL	PRTHEXBYTE
	
	PRTC(']')
#ENDIF
	
	; PRINT THE UART TYPE
	LD	A,(UART_TYPE)
	RLCA
	LD	HL,UART_TYPE_MAP
	LD	D,0
	LD	E,A
	ADD	HL,DE			; HL NOW POINTS TO MAP ENTRY
	LD	A,(HL)
	INC	HL
	LD	D,(HL)
	LD	E,A			; HL NOW POINTS TO STRING
	CALL	PC_SPACE
	CALL	WRITESTR		; PRINT THE STRING
;
	; ALL DONE IF NO UART WAS DETECTED
	LD	A,(UART_TYPE)
	OR	A
;	JR	Z,UART_INITP3
;
	; PRINT BAUD RATE
	PRTS(" BAUD=$")
	LD	HL,(UART_BAUDHI)
	LD	BC,(UART_BAUDLO)
	LD	DE,UART_INITBUF
	CALL	BIN2BCD
	EX	DE,HL
	CALL	PRTBCD
;	CALL	PRTDEC
;
	; PRINT FEATURES ENABLED
	LD	A,(UART_FEAT)
	BIT	UART_FIFO,A
	JR	Z,UART_INITP2
	PRTS(" FIFO$")
UART_INITP2:
	BIT	UART_AFC,A
	JR	Z,UART_INITP3
	PRTS(" AFC$")
UART_INITP3:
;
	RET
;
UART_INITBUF	.FILL	5,0		; WORKING BUFFER FOR BCD NUMBER
;
; UART DETECTION ROUTINE
;
UART_DETECT:
;
	; SEE IF UART IS THERE BY CHECKING DLAB FUNCTIONALITY
	XOR	A			; ZERO ACCUM
	UART_OUT(UART_IER)		; IER := 0
	LD	A,$80			; DLAB BIT ON
	UART_OUT(UART_LCR)		; OUTPUT TO LCR (DLAB REGS NOW ACTIVE)
	LD	A,$5A			; LOAD TEST VALUE
	UART_OUT(UART_DLM)		; OUTPUT TO DLM
	UART_IN(UART_DLM)		; READ IT BACK
	CP	$5A			; CHECK FOR TEST VALUE
	JR	NZ,UART_DETECT_NONE	; NOPE, UNKNOWN UART OR NOT PRESENT
	XOR	A			; DLAB BIT OFF
	UART_OUT(UART_LCR)		; OUTPUT TO LCR (DLAB REGS NOW INACTIVE)
	UART_IN(UART_IER)		; READ IER
	CP	$5A			; CHECK FOR TEST VALUE
	JR	Z,UART_DETECT_NONE	; IF STILL $5A, UNKNOWN OR NOT PRESENT
;
	; TEST FOR FUNCTIONAL SCRATCH REG, IF NOT, WE HAVE AN 8250
	LD	A,$5A			; LOAD TEST VALUE
	UART_OUT(UART_SCR)		; PUT IT IN SCRATCH REGISTER
	UART_IN(UART_SCR)		; READ IT BACK
	CP	$5A			; CHECK IT
	JR	NZ,UART_DETECT_8250	; STUPID 8250
;
	; TEST FOR EFR REGISTER WHICH IMPLIES 16650/850
	LD	A,$BF			; VALUE TO ENABLE EFR
	UART_OUT(UART_LCR)		; WRITE IT TO LCR
	UART_IN(UART_SCR)		; READ SCRATCH REGISTER
	CP	$5A			; SPR STILL THERE?
	JR	NZ,UART_DETECT1		; NOPE, HIDDEN, MUST BE 16650/850
;
	; RESET LCR TO DEFAULT
	LD	A,$80			; DLAB BIT ON
	UART_OUT(UART_LCR)		; RESET LCR
;
	; TEST FCR TO ISOLATE 16450/550/550A
	LD	A,$E7			; TEST VALUE
	UART_OUT(UART_FCR)		; PUT IT IN FCR
	UART_IN(UART_IIR)		; READ BACK FROM IIR
	BIT	6,A			; BIT 6 IS FIFO ENABLE, LO BIT
	JR	Z,UART_DETECT_16450	; IF NOT SET, MUST BE 16450
	BIT	7,A			; BIT 7 IS FIFO ENABLE, HI BIT
	JR	Z,UART_DETECT_16550	; IF NOT SET, MUST BE 16550
	BIT	5,A			; BIT 5 IS 64 BYTE FIFO
	JR	Z,UART_DETECT2		; IF NOT SET, MUST BE 16550A/C
	JR	UART_DETECT_16750	; ONLY THING LEFT IS 16750
;
UART_DETECT1:	; PICK BETWEEN 16650/850
	; NOT SURE HOW TO DIFFERENTIATE 16650 FROM 16850 YET
	JR	UART_DETECT_16650	; ASSUME 16650
	RET
;
UART_DETECT2:	; PICK BETWEEN 16650A/C
	; SET AFC BIT IN FCR
	LD	A,$20			; SET AFC BIT, MCR:5
	UART_OUT(UART_MCR)		; WRITE NEW FCR VALUE
;
	; READ IT BACK, IF SET, WE HAVE 16550C
	UART_IN(UART_MCR)		; READ BACK MCR
	BIT	5,A			; CHECK AFC BIT
	JR	Z,UART_DETECT_16550A	; NOT SET, SO 16550A
	JR	UART_DETECT_16550C	; IS SET, SO 16550C
;
UART_DETECT_NONE:
	LD	A,UART_NONE
	RET
;
UART_DETECT_8250:
	LD	A,UART_8250
	RET
;
UART_DETECT_16450:
	LD	A,UART_16450
	RET
;
UART_DETECT_16550:
	LD	A,UART_16550
	RET
;
UART_DETECT_16550A:
	LD	A,UART_16550A
	RET
;
UART_DETECT_16550C:
	LD	A,UART_16550C
	RET
;
UART_DETECT_16650:
	LD	A,UART_16650
	RET
;
UART_DETECT_16750:
	LD	A,UART_16750
	RET
;
UART_DETECT_16850:
	LD	A,UART_16850
	RET
;
; COMPUTE DIVISOR TO BC
; USES UART_BAUD AND UART_OSC VARIABLES BELOW
;
UART_COMPDIV:
	; SETUP DE:HL WITH OSC FREQUENCY
	LD	DE,(UART_OSCHI)
	LD	HL,(UART_OSCLO)
	; DIVIDE OSC FREQ BY PRESCALE FACTOR OF 16
	LD	B,4	; 4 ITERATIONS
UART_COMPDIV1:
	SRL	D
	RR	E
	RR	H
	RR	L
	DJNZ	UART_COMPDIV1
	; CONVERT FROM DE:HL -> A:HL (THROW AWAY HIGH BYTE)
	LD	A,E
	; SETUP C:DE WITH TARGET BAUD RATE
	LD	BC,(UART_BAUDHI)
	LD	DE,(UART_BAUDLO)
	; DIVIDE OSC FREQ AND BAUD BY 2 UNTIL FREQ FITS IN 16 BITS
UART_COMPDIV2:
	SRL	A
	RR	H
	RR	L
	SRL	C
	RR	D
	RR	E
	OR	A
	JR	NZ,UART_COMPDIV2
	; DIVIDE ADJUSTED VALUES (OSC FREQ / BAUD RATE)
	CALL	DIV16
	RET
;
; ROUTINES TO READ/WRITE PORTS INDIRECTLY
;
; READ VALUE OF UART PORT ON TOS INTO REGISTER A
;
UART_INP:
	EX	(SP),HL		; SWAP HL AND TOS
	PUSH	BC		; PRESERVE BC
	LD	A,(UART_BASE)	; GET UART IO BASE PORT
	OR	(HL)		; OR IN REGISTER ID BITS
	LD	C,A		; C := PORT
	INC	HL		; BUMP HL PAST REG ID PARM
	IN	A,(C)		; READ PORT INTO A
	POP	BC		; RESTORE BC
	EX	(SP),HL		; SWAP BACK HL AND TOS
	RET
;
; WRITE VALUE IN REGISTER A TO UART PORT ON TOS
;
UART_OUTP:
	EX	(SP),HL		; SWAP HL AND TOS
	PUSH	BC		; PRESERVE BC
	PUSH	AF		; SAVE AF (VALUE TO WRITE)
	LD	A,(UART_BASE)	; GET UART IO BASE PORT
	OR	(HL)		; OR IN REGISTER ID BITS
	LD	C,A		; C := PORT
	INC	HL		; BUMP HL PAST REG ID PARM
	POP	AF		; RESTORE VALUE TO WRITE
	OUT	(C),A		; WRITE VALUE TO PORT
	POP	BC		; RESTORE BC
	EX	(SP),HL		; SWAP BACK HL AND TOS
	RET
;
;
;
UART_TYPE_MAP:
			.DW	UART_STR_NONE
			.DW	UART_STR_8250
			.DW	UART_STR_16450
			.DW	UART_STR_16550
			.DW	UART_STR_16550A
			.DW	UART_STR_16550C
			.DW	UART_STR_16650
			.DW	UART_STR_16750
			.DW	UART_STR_16850

UART_STR_NONE		.DB	"<NOT PRESENT>$"
UART_STR_8250		.DB	"8250$"
UART_STR_16450		.DB	"16450$"
UART_STR_16550		.DB	"16550$"
UART_STR_16550A		.DB	"16550A$"
UART_STR_16550C		.DB	"16550C$"
UART_STR_16650		.DB	"16650$"
UART_STR_16750		.DB	"16750$"
UART_STR_16850		.DB	"16850$"
;
; WORKING VARIABLES
;
UART_BASE		.DB	0		; BASE IO ADDRESS FOR ACTIVE UART
UART_TYPE		.DB	0		; UART TYPE DISCOVERED
UART_FEAT		.DB	0		; UART FEATURES DISCOVERED
UART_BAUDLO		.DW	0		; BAUD RATE LO WORD
UART_BAUDHI		.DW	0		; BAUD RATE HI WORD
UART_OSCLO		.DW	0		; UART OSC FREQUENCY LO
UART_OSCHI		.DW	0		; UART OSC FREQUENCY HI
;UART_DIV		.DW	0		; BAUD DIVISOR
UART_FUNC		.DB	0		; UART FUNCTIONS REQUESTED
;
;
;
UART_FIFO		.EQU	0		; FIFO ENABLE BIT
UART_AFC		.EQU	1		; AUTO FLOW CONTROL ENABLE BIT
