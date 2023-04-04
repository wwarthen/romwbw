;___CTC________________________________________________________________________________________________________________
;
; Z80 CTC
;
;   DISPLAY CONFIGURATION DETAILS
;______________________________________________________________________________________________________________________
;
CTC_DEFCFG	.EQU	%01010011	; CTC DEFAULT CONFIG
CTC_CTRCFG	.EQU	%01010111	; CTC COUNTER MODE CONFIG
CTC_TIM16CFG	.EQU	%00010111	; CTC TIMER/16 MODE CONFIG
CTC_TIM256CFG	.EQU	%00110111	; CTC TIMER/256 MODE CONFIG
;CTC_TIMCFG	.EQU	%11010111	; CTC TIMER CHANNEL CONFIG
		;	 |||||||+-- CONTROL WORD FLAG
		;	 ||||||+--- SOFTWARE RESET
		;	 |||||+---- TIME CONSTANT FOLLOWS
		;	 ||||+----- AUTO TRIGGER WHEN TIME CONST LOADED
		;	 |||+------ RISING EDGE TRIGGER
		;	 ||+------- TIMER MODE PRESCALER (0=16, 1=256)
		;	 |+-------- COUNTER MODE
		;	 +--------- INTERRUPT ENABLE
;
;==================================================================================================
; ONLY IM2 IMPLEMENTED BELOW.  I DON'T SEE ANY REASONABLE WAY TO IMPLEMENT AN IM1 TIMER BECAUSE
; THE CTC PROVIDES NO WAY TO DETERMINE IF IT WAS THE CAUSE OF AN INTERRUPT OR A WAY TO
; DETERMINE WHICH CHANNEL CAUSED AN INTERRUPT.
;==================================================================================================
;
#IF (INTMODE != 2)
	.ECHO	"*** WARNING: CTC TIMER DISABLED -- INTMODE 2 REQUIRED!!!\n"
#ENDIF
;
#IF (CTCTIMER & (INTMODE == 2))
;
  #IF (INT_CTC0A % 4)
  
	.ECHO	INT_CTC0A
	.ECHO	"\n"
	.ECHO	(INT_CTC0A % 4)
	.ECHO	"\n"
  
	.ECHO	"*** ERROR: CTC BASE VECTOR NOT DWORD ALIGNED!!!\n"
	!!!	; FORCE AN ASSEMBLY ERROR
  #ENDIF
;
;==================================================================================================
; TIMER SETUP
;
; A PERIODIC INTERRUPT TIMER CAN BE SETUP USING EITHER THE CPU SYSTEM CLOCK OR AN EXTERNAL
; OSCILLATOR CONNECTED TO THE CTC. THE DEFACTO PERIOD FOR THIS TIMER IS 50Hz OR 60Hz.
;
; THE DESIRED TIMER PERIOD IS SET IN THE CONFIGURATION:
;	TICKFREQ	.SET	60	; OR
;	TICKFREQ	.SET	50
;
; THIS DRIVER USES TWO CTC CHANNELS TO CREATE A TWO STEP DIVIDER THAT DIVIDES THE CPU SYSTEM 
; CLOCK OR EXTERNAL OSCILLATOR INTO A PERIODIC TICK THAT GENERATES AN INTERRUPT.
;
; THE CPU CLOCK OR CTC EXTERNAL OSCILLATOR NEEDS TO BE LESS THAN 3.932160MHz FOR A 60HZ TIMER
; TICK OR 3.276800MHz FOR A 50Hz TIMER TICK.
;
; THE CHANNELS USED ARE DEFINED BY THE CTCPRECH AND CTCTIMCH DEFINITIONS - TYPICALLY 2 & 3.
; EXTERNAL HARDWARE MUST BE CONFIGURED TO MATCH THIS CONFIGURATION.
;
; EACH CHANNEL SUCCESSIVELY DIVIDES THE CLOCK OR OSCILLATOR FREQUENCY DOWN TO A 50 OR 60Hz TICK.
; THE FIRST DIVIDER CHANNEL IS THE PRESCALER, THE SECOND IS THE TIMER CHANNEL. 
;
; IF CTCMODE IS CTCMODE_CTR THEN THE OSCILLATOR CONNECTED TO CTC PRESCALER CHANNEL IS USED.
;
; 	THE CONFIGURATION FILES DEFINE THE OSCILLATOR FREQUENCY THAT IS CONNECTED TO THE PRESCALER
; 	CHANNEL. I.E. THE EXTERNAL HARDWARE CONNECTED TO THE CTC.
;
;	FOR A 60Hz TIMER WITH A 3.579545Mhz OSCILLATOR USE:
;	CTCMODE		.SET	CTCMODE_CTR
;	TICKFREQ	.SET	60
;	CTCOSC		.SET	3579545	
;	
; IF CTCMODE IS CTCMODE_TIM16 OR CTCMODE_TIM256 THE CPU SYSTEM CLOCK FREQUENCY IS USED.
;
;  	THIS MODE HAS LIMITED VALUE AS MANY SYSTEMS OPERATE ABOVE THE USABLE TOP FREQUENCY.
;	THE CONFIGURATION FILE MUST BE UPDATED TO MATCH YOUR CPU CLOCK FREQUENCY.
;
;	FOR A 60Hz TIMER WITH A 2Mhz OSCILLATOR USE:
;	CTCMODE		.SET	CTCMODE_TIM256
;	TICKFREQ	.SET	60
;	CTCOSC		.SET	2000000
;
;	NOTE THAT IF CPU SPEED IS CHANGED IN THIS MODE, THE TIMER SPEED WILL ALSO CHANGE.
;
;==================================================================================================
;
CTC_PREIO	.EQU	CTCBASE + CTCPRECH
CTC_SCLIO	.EQU	CTCBASE + CTCTIMCH
;
  #IF (CTCMODE == CTCMODE_CTR)
CTC_PRECFG	.EQU	CTC_CTRCFG
CTC_PRESCL	.EQU	1
  #ENDIF
  #IF (CTCMODE == CTCMODE_TIM16)
CTC_PRECFG	.EQU	CTC_TIM16CFG
CTC_PRESCL	.EQU	16
  #ENDIF
  #IF (CTCMODE == CTCMODE_TIM256)
CTC_PRECFG	.EQU	CTC_TIM256CFG
CTC_PRESCL	.EQU	256
  #ENDIF
;
CTC_DIV		.EQU	CTCOSC / CTC_PRESCL / TICKFREQ
;
CTC_DIVHI	.EQU	CTCPRE
CTC_DIVLO	.EQU	(CTC_DIV / CTC_DIVHI)
;
	.ECHO "CTC DIVISOR: "
	.ECHO CTC_DIV
	.ECHO ", HI: "
	.ECHO CTC_DIVHI
	.ECHO ", LO: "
	.ECHO CTC_DIVLO
	.ECHO "\n"
;
  #IF ((CTC_DIV == 0) | (CTC_DIV > $FFFF))
	.ECHO "COMPUTED CTC DIVISOR IS UNUSABLE!\n"
	!!!
  #ENDIF
;
  #IF ((CTC_DIVHI > $100) | (CTC_DIVLO > $100))
	.ECHO "COMPUTED CTC DIVISOR IS UNUSABLE!\n"
	!!!
  #ENDIF
;
  #IF ((CTC_DIVHI * CTC_DIVLO * CTC_PRESCL * TICKFREQ) != CTCOSC)
	.ECHO "WARNING: COMPUTED CTC DIVISOR IS INACCURATE!\n"
  #ENDIF
;
CTCTIVT		.EQU	INT_CTC0A + CTCTIMCH
;
#ENDIF
;
;==================================================================================================
; CTC PRE-INITIALIZATION
;
; CHECK TO SEE IF A CTC EXISTS. IF IT EXISTS, ALL FOUR CTC CHANNELS ARE PROGRAMMED TO:
;  INTERRUPTS DISABLED, COUNTER MODE, RISING EDGE TRIGGER, RESET STATE.
;
; IF THE CTCTIMER CONFIGURATION IS SET, THEN A PERIOD INTERRUPT TIMER IS SET UP USING CTC CHANNELS
; 2 (CTCPRECH) & 3 (CTCTIMCH). THE TIMER WILL BE SETUP TO 50 OR 60HZ DEPENDING ON CONFIGURATION 
; SETTING TICKFREQ. CHANNEL 3 WILL GENERATE THE TICK INTERRUPT.. 
;==================================================================================================
;
CTC_PREINIT:
	; BLINDLY RESET THE CTC ASSUMING IT IS THERE
	LD	A,CTC_DEFCFG
	OUT	(CTCBASE),A
	OUT	(CTCBASE+1),A
	OUT	(CTCBASE+2),A
	OUT	(CTCBASE+3),A
;
	CALL	CTC_DETECT		; DO WE HAVE ONE?
	LD	(CTC_EXIST),A		; SAVE IT
	RET	NZ			; ABORT IF NONE
;
#IF (CTCTIMER & (INTMODE == 2))
	; SETUP TIMER INTERRUPT IVT SLOT
	LD	HL,HB_TIMINT		; TIMER INT HANDLER ADR
	LD	(IVT(CTCTIVT)),HL	; IVT ENTRY FOR TIMER CHANNEL
;
	; CTC USES 4 CONSECUTIVE VECTOR POSITIONS, ONE FOR
	; EACH CHANNEL.  BELOW WE SET THE BASE VECTOR TO THE
	; START OF THE IVT, SO THE FIRST FOUR ENTRIES OF THE
	; IVT CORRESPOND TO CTC CHANNELS A-D.
	LD	A,INT_CTC0A * 2
	OUT	(CTCBASE),A		; SETUP CTC BASE INT VECTOR
;
	; IN ORDER TO DIVIDE THE CTC INPUT CLOCK DOWN TO THE
	; DESIRED PERIODIC INTERRUPT, WE NEED TO CONFIGURE ONE
	; CTC CHANNEL AS A PRESCALER AND ANOTHER AS THE ACTUAL
	; TIMER INTERRUPT.  THE PRESCALE CHANNEL OUTPUT MUST BE WIRED
	; TO THE TIMER CHANNEL TRIGGER INPUT VIA HARDWARE.
	LD	A,CTC_PRECFG		; PRESCALE TIMER CHANNEL CFG
	OUT	(CTC_PREIO),A		; SETUP PRESCALE CHANNEL
	LD	A,CTC_DIVHI & $FF	; PRESCALE CHANNEL CONSTANT
	OUT	(CTC_PREIO),A		; SET PRESCALE CONSTANT
;
	LD	A,CTC_CTRCFG | $80	; TIMER CHANNEL + INT CFG
	OUT	(CTC_SCLIO),A		; SETUP TIMER CHANNEL
	LD	A,CTC_DIVLO & $FF	; TIMER CHANNEL CONSTANT
	OUT	(CTC_SCLIO),A		; SET TIMER CONSTANT
;
#ENDIF
;
	XOR	A
	RET
;
;==================================================================================================
; DRIVER INITIALIZATION
;==================================================================================================
;
CTC_INIT:				; MINIMAL INIT
CTC_PRTCFG:
	; ANNOUNCE PORT
	CALL	NEWLINE			; FORMATTING
	PRTS("CTC:$")			; FORMATTING
;
	PRTS(" IO=0x$")			; FORMATTING
	LD	A,CTCBASE		; GET BASE PORT
	CALL	PRTHEXBYTE		; PRINT BASE PORT
;
	LD	A,(CTC_EXIST)		; IS IT THERE?
	OR	A			; 0 MEANS YES
	JR	Z,CTC_PRTCFG1		; IF SO, CONTINUE
;
	; NOTIFY NO CTC HARDWARE
	PRTS(" NOT PRESENT$")
	OR	$FF
	RET
;
CTC_PRTCFG1:
;
#IF (CTCTIMER & (INTMODE == 2))
;
	PRTS(" TIMER MODE=$")			; FORMATTING
  #IF (CTCMODE == CTCMODE_CTR)
	PRTS("CTR$")
  #ENDIF
  #IF (CTCMODE == CTCMODE_TIM16)
	PRTS("TIM16$")
  #ENDIF
  #IF (CTCMODE == CTCMODE_TIM256)
	PRTS("TIM256$")
  #ENDIF
;
  #IF (CTCDEBUG)
	PRTS(" DIVHI=$")
	LD	A,CTC_DIVHI & $FF
	CALL	PRTHEXBYTE
;
	PRTS(" DIVLO=$")
	LD	A,CTC_DIVLO & $FF
	CALL	PRTHEXBYTE
;
	PRTS(" PREIO=$")
	LD	A,CTC_PREIO
	CALL	PRTHEXBYTE
;
	PRTS(" SCLIO=$")
	LD	A,CTC_SCLIO
	CALL	PRTHEXBYTE
;
	PRTS(" DIV=$")
	LD	BC,CTC_DIV
	CALL	PRTHEXWORD
  #ENDIF
;
#ENDIF
;
	XOR	A
	RET
;
;==================================================================================================
; DETECT CTC BY PROGRAMMING THE FIRST CHANNEL TO COUNT IN TIMER
; MODE (BASED ON CPU CLOCK).  THEN CHECK IF COUNTER IS ACTUALLY
; RUNNING.
;==================================================================================================
;
CTC_DETECT:
	LD	A,CTC_TIM16CFG		; RESET & SETUP TIMER MODE
	OUT	(CTCBASE),A		; SEND TO CTC
	LD	A,$FF			; TIME CONSTANT $FF
	OUT	(CTCBASE),A		; SEND CONSTANT & START CTR
	NOP				; BRIEF DELAY
	IN	A,(CTCBASE)		; READ COUNTER
	LD	C,A			; SAVE VALUE
	CALL	DLY8			; WAIT A BIT
	IN	A,(CTCBASE)		; READ COUNTER AGAIN
	PUSH	AF			; SAVE RESULT
	LD	A,CTC_DEFCFG		; DEFAULT CHANNEL CFG
	OUT	(CTCBASE),A		; RESTORE TO DEFAULTS
	POP	AF			; GET RESULT BACK
	CP	C			; COMPARE TO PREVIOUS
	JR	Z,CTC_NO		; IF SAME, FAIL
	XOR	A			; SIGNAL SUCCESS
	RET				; AND DONE
CTC_NO:
	OR	$FF			; SIGNAL FAILURE
	RET				; AND DONE
;
; CTC DRIVER DATA STORAGE
;
CTC_EXIST	.DB	$FF		; SET TO ZERO IF EXISTS
