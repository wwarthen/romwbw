;======================================================================
;	COLOR VDU DRIVER FOR N8VEM PROJECT
;
;	WRITTEN BY: DAN WERNER -- 11/4/2011
;	ROMWBW ADAPTATION BY: WAYNE WARTHEN -- 11/9/2012
;======================================================================
;
; TODO:
;   - IMPLEMENT CONSTANTS FOR SCREEN DIMENSIONS
;   - IMPLEMENT SET CURSOR STYLE (VDASCS) FUNCTION
;   - IMPLEMENT ALTERNATE DISPLAY MODES?
;   - IMPLEMENT DYNAMIC READ/WRITE OF CHARACTER BITMAP DATA?
;
;======================================================================
; CVDU DRIVER - CONSTANTS
;======================================================================
;
CVDU_STAT	 .EQU	$E4		; READ M8563 STATUS
CVDU_REG	 .EQU	$E4		; SELECT M8563 REGISTER
CVDU_DATA	 .EQU	$EC		; READ/WRITE M8563 DATA
;
;======================================================================
; CVDU DRIVER - INITIALIZATION
;======================================================================
;
CVDU_INIT:
	CALL 	CVDU_CRTINIT		; SETUP THE CVDU CHIP REGISTERS
	CALL	CVDU_LOADFONT		; LOAD FONT DATA FROM ROM TO CVDU STRORAGE

CVDU_RESET:
	LD	A,$0E			; ATTRIBUTE IS STANDARD WHITE ON BLACK
	LD	(CVDU_ATTR),A		; SAVE IT
	
	LD	A,'#'			; BLANK THE SCREEN
	LD	DE,$800			; FILL ENTIRE BUFFER
	CALL	CVDU_FILL		; DO IT
	LD	DE,0			; ROW = 0, COL = 0
	CALL	CVDU_XY			; SEND CURSOR TO TOP LEFT
	
	XOR	A			; SIGNAL SUCCESS
	RET
;	
;======================================================================
; CVDU DRIVER - CHARACTER I/O (CIO) DISPATCHER AND FUNCTIONS
;======================================================================
;
CVDU_DISPCIO:
	LD	A,B			; GET REQUESTED FUNCTION
	AND	$0F			; ISOLATE SUB-FUNCTION
	JR	Z,CVDU_CIOIN		; $00
	DEC	A
	JR	Z,CVDU_CIOOUT		; $01
	DEC	A
	JR	Z,CVDU_CIOIST		; $02
	DEC	A
	JR	Z,CVDU_CIOOST		; $03
	CALL	PANIC
;	
CVDU_CIOIN:
	JP	KBD_READ		; CHAIN TO KEYBOARD DRIVER
;
CVDU_CIOIST:
	JP	KBD_STAT		; CHAIN TO KEYBOARD DRIVER
;
CVDU_CIOOUT:
	JP	CVDU_VDAWRC		; WRITE CHARACTER
;
CVDU_CIOOST:
	XOR	A			; A = 0
	INC	A			; A = 1, SIGNAL OUTPUT BUFFER READY
	RET
;	
;======================================================================
; CVDU DRIVER - VIDEO DISPLAY ADAPTER (VDA) DISPATCHER AND FUNCTIONS
;======================================================================
;
CVDU_DISPVDA:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION

	JR	Z,CVDU_VDAINI	; $40
	DEC	A
	JR	Z,CVDU_VDAQRY	; $41
	DEC	A
	JR	Z,CVDU_VDARES	; $42
	DEC	A
	JR	Z,CVDU_VDASCS	; $43
	DEC	A
	JR	Z,CVDU_VDASCP	; $44
	DEC	A
	JR	Z,CVDU_VDASAT	; $45
	DEC	A
	JR	Z,CVDU_VDASCO	; $46
	DEC	A
	JR	Z,CVDU_VDAWRC	; $47
	DEC	A
	JR	Z,CVDU_VDAFIL	; $48
	DEC	A
	JR	Z,CVDU_VDASCR	; $49
	DEC	A
	JP	Z,KBD_STAT	; $4A
	DEC	A
	JP	Z,KBD_FLUSH	; $4B
	DEC	A
	JP	Z,KBD_READ	; $4C
	CALL	PANIC

CVDU_VDAINI:
	JR	CVDU_INIT	; INITIALIZE

CVDU_VDAQRY:
	LD	C,$00		; MODE ZERO IS ALL WE KNOW
	LD	DE,$1950	; 25 ROWS ($19), 80 COLS ($50)
	LD	HL,0		; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED YET
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDARES:
	JR	CVDU_RESET	; DO THE RESET
	
CVDU_VDASCS:
	CALL	PANIC		; NOT IMPLEMENTED (YET)
	
CVDU_VDASCP:
	CALL	CVDU_XY		; SET CURSOR POSITION
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDASAT:
	; INCOMING IS:  -----RUB (R=REVERSE, U=UNDERLINE, B=BLINK)
	; TRANSFORM TO: -RUB----
	LD	A,E		; GET THE INCOMING ATTRIBUTE
	RLCA			; TRANSLATE TO OUR DESIRED BIT
	RLCA			; "
	RLCA			; "
	RLCA			; "
	AND	%01110000	; REMOVE ANYTHING EXTRANEOUS
	LD	E,A		; SAVE IT IN E
	LD	A,(CVDU_ATTR)	; GET CURRENT ATTRIBUTE SETTING
	AND	%10001111	; CLEAR OUT OLD ATTRIBUTE BITS
	OR	E		; STUFF IN THE NEW ONES
	LD	A,(CVDU_ATTR)	; AND SAVE THE RESULT
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDASCO:
	; INCOMING IS:  IBGRIBGR (I=INTENSITY, B=BLUE, G=GREEN, R=RED)
	; TRANSFORM TO: ----RGBI (DISCARD BACKGROUND COLOR IN HIGH NIBBLE)
	XOR	A		; CLEAR A
	LD	B,4		; LOOP 4 TIMES (4 BITS)
CVDU_VDASCO1:
	RRC	E		; ROTATE LOW ORDER BIT OUT OF E INTO CF
	RLA			; ROTATE CF INTO LOW ORDER BIT OF A
	DJNZ	CVDU_VDASCO1	; DO FOUR BITS OF THIS
	LD	E,A		; SAVE RESULT IN E
	LD	A,(CVDU_ATTR)	; GET CURRENT VALUE INTO A
	AND	%11110000	; CLEAR OUT OLD COLOR BITS
	OR	E		; STUFF IN THE NEW ONES
	LD	A,(CVDU_ATTR)	; AND SAVE THE RESULT
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDAWRC:
	LD	A,E		; CHARACTER TO WRITE GOES IN A
	CALL	CVDU_PUTCHAR	; PUT IT ON THE SCREEN
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDAFIL:
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	CVDU_FILL	; DO THE FILL
	XOR	A		; SIGNAL SUCCESS
	RET
	
CVDU_VDASCR:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	RET	Z		; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,CVDU_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	CVDU_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	CVDU_VDASCR	; LOOP
CVDU_VDASCR1:
	CALL	CVDU_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	CVDU_VDASCR	; LOOP
;	
;======================================================================
; CVDU DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;----------------------------------------------------------------------
; MOS 8563 DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
CVDU_CRTINIT:
    	LD 	C,0			; START WITH REGISTER 0
	LD	B,37			; INIT 37 REGISTERS
    	LD 	HL,CVDU_INIT8563	; HL = POINTER TO THE DEFAULT VALUES
CVDU_CRTINIT1:
	LD	A,(HL)			; GET VALUE
	CALL	CVDU_WR			; WRITE IT
	INC	HL			; POINT TO NEXT VALUE
	INC	C			; POINT TO NEXT REGISTER
	DJNZ	CVDU_CRTINIT1		; LOOP
    	RET
;
;----------------------------------------------------------------------
; LOAD FONT DATA
;----------------------------------------------------------------------
;
CVDU_LOADFONT:
	LD	HL,$2000		; START OF FONT BUFFER
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	LD	HL,CVDU_FONTDATA	; POINTER TO FONT DATA
	LD	DE,$2000		; LENGTH OF FONT DATA
	LD	C,31			; DATA REGISTER
CVDU_LOADFONT1:
	LD	A,(HL)			; LOAD NEXT BYTE OF FONT DATA
	CALL	CVDU_WR			; WRITE IT
	INC	HL			; INCREMENT FONT DATA POINTER
	DEC	DE			; DECREMENT LOOP COUNTER
	LD	A,D			; CHECK DE...
	OR	E			; FOR COUNTER EXHAUSTED
	JR	NZ,CVDU_LOADFONT1	; LOOP TILL DONE
	RET
;
;----------------------------------------------------------------------
; UPDATE M8563 REGISTERS
;   CVDU_WR WRITES VALUE IN A TO VDU REGISTER SPECIFIED IN C
;   CVDU_WRX WRITES VALUE IN DE TO VDU REGISTER PAIR IN C, C+1
;----------------------------------------------------------------------
;
CVDU_WR:
	PUSH	AF			; SAVE VALUE TO WRITE
	LD	A,C			; SET A TO CVDU REGISTER TO SELECT
	OUT	(CVDU_REG),A		; WRITE IT TO SELECT THE REGISTER
CVDU_WR1:
	IN	A,(CVDU_STAT)		; GET CVDU STATUS
	BIT	7,A			; CHECK BIT 7
	JR	Z,CVDU_WR1		; LOOP WHILE NOT READY (BIT 7 NOT SET)
	POP	AF			; RESTORE VALUE TO WRITE
	OUT	(CVDU_DATA),A		; WRITE IT
	RET
;
CVDU_WRX:
	LD	A,H			; SETUP MSB TO WRITE
	CALL	CVDU_WR			; DO IT
	INC	C			; NEXT CVDU REGISTER
	LD	A,L			; SETUP LSB TO WRITE
	JR	CVDU_WR			; DO IT & RETURN
;
;----------------------------------------------------------------------
; READ M8563 REGISTERS
;   CVDU_RD READS VDU REGISTER SPECIFIED IN C AND RETURNS VALUE IN A
;   CVDU_RDX READS VDU REGISTER PAIR SPECIFIED BY C, C+1 
;     AND RETURNS VALUE IN HL
;----------------------------------------------------------------------
;
CVDU_RD:
	LD	A,C			; SET A TO CVDU REGISTER TO SELECT
	OUT	(CVDU_REG),A		; WRITE IT TO SELECT THE REGISTER
CVDU_RD1:
	IN	A,(CVDU_STAT)		; GET CVDU STATUS
	BIT	7,A			; CHECK BIT 7
	JR	Z,CVDU_RD1		; LOOP WHILE NOT READY (BIT 7 NOT SET)
	IN	A,(CVDU_DATA)		; READ IT
	RET
;
CVDU_RDX:
	CALL	CVDU_RD			; GET VALUE FROM REGISTER IN C
	LD	H,A			; SAVE IN H
	INC	C			; BUMP TO NEXT REGISTER OF PAIR
	CALL	CVDU_RD			; READ THE VALUE
	LD	L,A			; SAVE IT IN L
	RET
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
CVDU_XY:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,80			; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN
	LD	(CVDU_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
    	LD 	C,14			; CURSOR POSITION REGISTER PAIR
	JP	CVDU_WRX		; DO IT AND RETURN
;
;----------------------------------------------------------------------
; WRITE VALULE IN A TO CURRENT VDU BUFFER POSTION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
CVDU_PUTCHAR:
	PUSH	AF			; SAVE CHARACTER

	; SET MEMORY LOCATION FOR CHARACTER
	LD	HL,(CVDU_POS)		; LOAD CURRENT POSITION INTO HL
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; PUT THE CHARACTER THERE
	POP	AF			; RECOVER CHARACTER VALLUE TO WRITE
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; BUMP THE CURSOR FORWARD
	INC	HL			; BUMP HL TO NEXT POSITION
	LD	(CVDU_POS),HL		; SAVE IT
	LD	C,14			; CURSOR POSITION REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; SET MEMORY LOCATION FOR ATTRIBUTE
	LD	DE,$800 - 1		; SETUP DE TO ADD OFFSET INTO ATTRIB BUFFER
	ADD	HL,DE			; HL NOW POINTS TO ATTRIB POS FOR CHAR JUST WRITTEN
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; PUT THE ATTRIBUTE THERE
	LD	A,(CVDU_ATTR)		; LOAD THE ATTRIBUTE VALUE
	LD	C,31			; DATA REGISTER
	JP	CVDU_WR			; DO IT AND RETURN
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
CVDU_FILL:
	PUSH	DE			; SAVE FILL COUNT
	LD	HL,(CVDU_POS)		; SET CHARACTER BUFFER POSITION TO FILL
	PUSH	HL			; SAVE BUF POS
	CALL	CVDU_FILL1		; DO THE CHARACTER FILL
	POP	HL			; RECOVER BUF POS
	LD	DE,$800			; INCREMENT FOR ATTRIBUTE FILL
	ADD	HL,DE			; HL := BUF POS FOR ATTRIBUTE FILL
	POP	DE			; RECOVER FILL COUNT
	LD	A,(CVDU_ATTR)		; SET ATTRIBUTE VALUE FOR ATTRIBUTE FILL
	JR	CVDU_FILL1		; DO ATTRIBUTE FILL AND RETURN
	
CVDU_FILL1:
	LD	B,A			; SAVE REQUESTED FILL VALUE
	
	; CHECK FOR VALID FILL LENGTH
	LD	A,D			; LOAD D
	OR	E			; OR WITH E
	RET	Z			; BAIL OUT IF LENGTH OF ZERO SPECIFIED
	
	; POINT TO BUFFER LOCATION TO START FILL
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT
	
	; SET MODE TO BLOCK WRITE
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT

	; SET CHARACTER TO WRITE (WRITES ONE CHARACTER)
	LD	A,B			; RECOVER FILL VALUE
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT
	DEC	DE			; REFLECT ONE CHARACTER WRITTEN
	
	; LOOP TO DO BULK WRITE (UP TO 255 BYTES PER LOOP)
	EX	DE,HL			; NOW USE HL FOR COUNT
	LD	C,30			; BYTE COUNT REGISTER
CVDU_FILL2:
	LD	A,H			; GET HIGH BYTE
	OR	A			; SET FLAGS
	LD	A,L			; PRESUME WE WILL WRITE L COUNT (ALL REMAINING) BYTES
	JR	Z,CVDU_FILL3		; IF H WAS ZERO, WRITE L BYTES
	LD	A,$FF			; H WAS > 0, NEED MORE LOOPS, WRITE 255 BYTES
CVDU_FILL3:
	CALL	CVDU_WR			; DO IT (SOURCE/DEST REGS AUTO INCREMENT)
	LD	D,0			; CLEAR D
	LD	E,A			; SET E TO BYTES WRITTEN
	SBC	HL,DE			; SUBTRACT FROM HL
	RET	Z			; IF ZERO, WE ARE DONE
	JR	CVDU_FILL2		; OTHERWISE, WRITE SOME MORE
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
CVDU_SCROLL:
	; SCROLL THE CHARACTER BUFFER
	LD	A,' '			; CHAR VALUE TO FILL NEW EXPOSED LINE
	LD	HL,0			; SOURCE ADDRESS OF CHARACER BUFFER
	CALL	CVDU_SCROLL1		; SCROLL CHARACTER BUFFER
	
	; SCROLL THE ATTRIBUTE BUFFER
	LD	A,(CVDU_ATTR)		; ATTRIBUTE VALUE TO FILL NEW EXPOSED LINE
	LD	HL,$800			; SOURCE ADDRESS OF ATTRIBUTE BUFFER
	JR	CVDU_SCROLL1		; SCROLL ATTRIBUTE BUFFER

CVDU_SCROLL1:
	PUSH	AF			; SAVE FILL VALUE FOR NOW
	
	; SET MODE TO BLOCK COPY
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	OR	$80			; SET BIT 7 FOR COPY MODE
	CALL	CVDU_WR			; DO IT

	; SET INITIAL BLOCK COPY DESTINATION (USING HL PASSED IN)
    	LD 	C,18			; UPDATE ADDRESS (DESTINATION) REGISTER
	CALL	CVDU_WRX		; DO IT

	; COMPUTE SOURCE (INCREMENT ONE ROW)
	LD	DE,80			; SOURCE ADDRESS IS ONE ROW PAST DESTINATION
	ADD	HL,DE			; ADD IT TO BUF ADDRESS

	; SET INITIAL BLOCK COPY SOURCE
    	LD 	C,32			; BLOCK START ADDRESS REGISTER
	CALL	CVDU_WRX		; DO IT

	LD	B,23			; ITERATIONS (ROWS - 1)
CVDU_SCROLL2:
	; SET BLOCK COPY COUNT (WILL EXECUTE COPY)
	LD	A,80			; COPY 80 BYTES
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	; LOOP TILL DONE WITH ALL LINES
	DJNZ	CVDU_SCROLL2		; REPEAT FOR ALL LINES
	
	; SET MODE TO BLOCK WRITE TO CLEAR NEW LINE EXPOSED BY SCROLL
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT
	
	; SET CHARACTER TO WRITE
	POP	AF			; RESTORE THE FILL VALUE PASSED IN
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; SET BLOCK WRITE COUNT (WILL EXECUTE THE WRITE)
	LD	A,80 - 1		; SET WRITE COUNT TO LINE LENGTH - 1 (1 CHAR ALREADY WRITTEN)
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT
	
	RET
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
CVDU_RSCROLL:
	; SCROLL THE CHARACTER BUFFER
	LD	A,'='			; CHAR VALUE TO FILL NEW EXPOSED LINE
	LD	HL,80*23		; SOURCE ADDRESS OF CHARACER BUFFER (LINE 24)
	CALL	CVDU_RSCROLL1		; SCROLL CHARACTER BUFFER
	
	; SCROLL THE ATTRIBUTE BUFFER
	LD	A,(CVDU_ATTR)		; ATTRIBUTE VALUE TO FILL NEW EXPOSED LINE
	LD	HL,$800+(80*23)		; SOURCE ADDRESS OF ATTRIBUTE BUFFER (LINE 24)
	JR	CVDU_RSCROLL1		; SCROLL ATTRIBUTE BUFFER AND RETURN

CVDU_RSCROLL1:
	PUSH	AF			; SAVE FILL VALUE FOR NOW
	
	; SET MODE TO BLOCK COPY
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	OR	$80			; SET BIT 7 FOR COPY MODE
	CALL	CVDU_WR			; DO IT

	; LOOP TO SCROLL EACH LINE WORKING FROM BOTTOM TO TOP
	LD	B,23			; ITERATIONS (23 ROWS)
CVDU_RSCROLL2:

	; SET BLOCK COPY DESTINATION (USING HL PASSED IN)
    	LD 	C,18			; UPDATE ADDRESS (DESTINATION) REGISTER
	CALL	CVDU_WRX		; DO IT

	; COMPUTE SOURCE (DECREMENT ONE ROW)
	LD	DE,80			; SOURCE ADDRESS IS ONE ROW PAST DESTINATION
	SBC	HL,DE			; SUBTRACT IT FROM BUF ADDRESS

	; SET BLOCK COPY SOURCE
    	LD 	C,32			; BLOCK START ADDRESS REGISTER
	CALL	CVDU_WRX		; DO IT

	; SET BLOCK COPY COUNT (WILL EXECUTE COPY)
	LD	A,80			; COPY 80 BYTES
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	DJNZ	CVDU_RSCROLL2		; REPEAT FOR ALL LINES
	
	; SET MODE TO BLOCK WRITE TO CLEAR NEW LINE EXPOSED BY SCROLL
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT
	
	; SET CHARACTER TO WRITE
	POP	AF			; RESTORE THE FILL VALUE PASSED IN
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; SET BLOCK WRITE COUNT (WILL EXECUTE THE WRITE)
	LD	A,80 - 1		; SET WRITE COUNT TO LINE LENGTH - 1 (1 CHAR ALREADY WRITTEN)
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT
	
	RET
;
;==================================================================================================
;   CVDU DRIVER - DATA
;==================================================================================================
;
CVDU_ATTR		.DB	0	; CURRENT COLOR
CVDU_POS		.DW 	0	; CURRENT DISPLAY POSITION
;
; ATTRIBUTE ENCODING:
;   BIT 7: ALTERNATE CHARACTER SET
;   BIT 6: REVERSE VIDEO
;   BIT 5: UNDERLINE
;   BIT 4: BLINK
;   BIT 3: RED
;   BIT 2: GREEN
;   BIT 1: BLUE
;   BIT 0: INTENSITY
;
;==================================================================================================
;   CVDU DRIVER - 8563 REGISTER INITIALIZATION
;==================================================================================================
;
; Reg	Hex	Bit 7	Bit 6	Bit 5	Bit 4	Bit 3	Bit 2	Bit 1	Bit 0	Description
; 0	$00	HT7	HT6	HT5	HT4	HT3	HT2	HT1	HT0	Horizontal Total
; 1	$01	HD7	HD6	HD5	HD4	HD3	HD2	HD1	HD0	Horizontal Displayed
; 2	$02	HP7	HP6	HP5	HP4	HP3	HP2	HP1	HP0	Horizontal Sync Position
; 3	$03	VW3	VW2	VW1	VW0	HW3	HW2	HW1	HW0	Vertical/Horizontal Sync Width
; 4	$04	VT7	VT6	VT5	VT4	VT3	VT2	VT1	VT0	Vertical Total
; 5	$05	--	--	--	VA4	VA3	VA2	VA1	VA0	Vertical Adjust
; 6	$06	VD7	VD6	VD5	VD4	VD3	VD2	VD1	VD0	Vertical Displayed
; 7	$07	VP7	VP6	VP5	VP4	VP3	VP2	VP1	VP0	Vertical Sync Position
; 8	$08	--	--	--	--	--	--	IM1	IM0	Interlace Mode
; 9	$09	--	--	--	--	CTV4	CTV3	CTV2	CTV1	Character Total Vertical
; 10	$0A	--	CM1	CM0	CS4	CS3	CS2	CS1	CS0	Cursor Mode, Start Scan
; 11	$0B	--	--	--	CE4	CE3	CE2	CE1	CE0	Cursor End Scan Line
; 12	$0C	DS15	DS14	DS13	DS12	DS11	DS10	DS9	DS8	Display Start Address High Byte
; 13	$0D	DS7	DS6	DS5	DS4	DS3	DS2	DS1	DS0	Display Start Address Low Byte
; 14	$0E	CP15	CP14	CP13	CP12	CP11	CP10	CP9	CP8	Cursor Position High Byte
; 15	$0F	CP7	CP6	CP5	CP4	CP3	CP2	CP1	CP0	Cursor Position Low Byte
; 16	$10	LPV7	LPV6	LPV5	LPV4	LPV3	LPV2	LPV1	LPV0	Light Pen Vertical Position
; 17	$11	LPH7	LPH6	LPH5	LPH4	LPH3	LPH2	LPH1	LPH0	Light Pen Horizontal Position
; 18	$12	UA15	UA14	UA13	UA12	UA11	UA10	UA9	UA8	Update Address High Byte
; 19	$13	UA7	UA6	UA5	UA4	UA3	UA2	UA1	UA0	Update Address Low Byte
; 20	$14	AA15	AA14	AA13	AA12	AA11	AA10	AA9	AA8	Attribute Start Address High Byte
; 21	$15	AA7	AA6	AA5	AA4	AA3	AA2	AA1	AA0	Attribute Start Address Low Byte
; 22	$16	CTH3	CTH2	CTH1	CTH0	CDH3	CDH2	CDH1	CDH0	Character Total Horizontal, Character Display Horizontal
; 23	$17	--	--	--	CDV4	CDV3	CDV2	CDV1	CDV0	Character Display Vertical
; 24	$18	COPY	RVS	CBRATE	VSS4	VSS3	VSS2	VSS1	VSS0	Vertical Smooth Scrolling
; 25	$19	TEXT	ATR	SEMI	DBL	HSS3	HSS2	HSS1	HSS0	Horizontal Smooth Scrolling
; 26	$1A	FG3	FG2	FG1	FG0	BG3	BG2	BG1	BG0	Foreground/Background color
; 27	$1B	AI7	AI6	AI5	AI4	AI3	AI2	AI1	AI0	Address Increment per Row
; 28	$1C	CB15	CB14	CB13	RAM	--	--	--	--	Character Base Address
; 29	$1D	--	--	--	UL4	UL3	UL2	UL1	UL0	Underline Scan Line
; 30	$1E	WC7	WC6	WC5	WC4	WC3	WC2	WC1	WC0	Word Count
; 31	$1F	DA7	DA6	DA5	DA4	DA3	DA2	DA1	DA0	Data Register
; 32	$20	BA15	BA14	BA13	BA12	BA11	BA10	BA9	BA8	Block Start Address High Byte
; 33	$21	BA7	BA6	BA5	BA4	BA3	BA2	BA1	BA0	Block Start Address Low Byte
; 34	$22	DEB7	DEB6	DEB5	DEB4	DEB3	DEB2	DEB1	DEB0	Display Enable Begin
; 35	$23	DEE7	DEE6	DEE5	DEE4	DEE3	DEE2	DEE1	DEE0	Display Enable End
; 36	$24	--	--	--	--	DRR3	DRR2	DRR1	DRR0	DRAM Refresh Rate
;
; EGA 720X368  9-BIT CHARACTERS
;   - requires 16.257Mhz oscillator frequency
;
CVDU_INIT8563:
	.DB	97		; 0: hor. total - 1
	.DB	80		; 1: hor. displayed
	.DB	90		; 2: hor. sync position 85
	.DB	$14		; 3: vert/hor sync width 		or 0x4F -- MDA
	.DB	26		; 4: vert total
	.DB	2		; 5: vert total adjust
	.DB	25		; 6: vert. displayed
	.DB	26		; 7: vert. sync postition
	.DB	0		; 8: interlace mode
	.DB	13		; 9: char height - 1
	.DB	(2<<5)+12	; 10: cursor mode, start line
	.DB	13		; 11: cursor end line
	.DB	0		; 12: display start addr hi
	.DB	0		; 13: display start addr lo
	.DB	7		; 14: cursor position hi
	.DB	128		; 15: cursor position lo
	.DB	1		; 16: light pen vertical
	.DB	1		; 17: light pen horizontal
	.DB	0		; 18: update address hi
	.DB	0		; 19: update address lo
	.DB	8		; 20: attribute start addr hi
	.DB	0		; 21: attribute start addr lo
	.DB	$89		; 22: char hor size cntrl 		0x78
	.DB	13		; 23: vert char pixel space - 1, increase to 13 with new font
	.DB	0		; 24: copy/fill, reverse, blink rate; vertical scroll
	.DB	$48		; 25: gr/txt, color/mono, pxl-rpt, dbl-wide; horiz. scroll
	.DB	$E0		; 26: fg/bg colors (monochr)
	.DB	0		; 27: row addr display incr
	.DB	$20+(1<<4)	; 28: char set addr; RAM size (64/16)
	.DB	13		; 29: underline position
	.DB	0		; 30: word count - 1
	.DB	0		; 31: data
	.DB	0		; 32: block copy src hi
	.DB	0		; 33: block copy src lo
	.DB	6		; 34: display enable begin
	.DB	88		; 35: display enable end
	.DB	0		; 36: refresh rate

;	.DB	126,80,102,73,32,224,25,29,252,231,160,231,0,0,7,128
;	.DB	18,23,15,208,8,32,120,232,32,71,240,0,47,231,79,7,15,208,125,100,245
;
;==================================================================================================
;   CVDU DRIVER - FONT DATA
;==================================================================================================
;
#INCLUDE "cvdu_font.asm"