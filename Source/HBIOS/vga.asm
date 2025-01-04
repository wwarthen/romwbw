;======================================================================
;	VGA DRIVER FOR RBC PROJECT
;
;	WRITTEN BY: WAYNE WARTHEN -- 5/29/2017
;======================================================================
;
; TODO:
;
;======================================================================
; VGA DRIVER - CONSTANTS
;======================================================================
;
VGA_BASE	.EQU	$E0
;
VGA_KBDDATA	.EQU	VGA_BASE + $00	; KBD CTLR DATA PORT
VGA_KBDST	.EQU	VGA_BASE + $01	; KBD CTLR STATUS/CMD PORT
VGA_REG		.EQU	VGA_BASE + $02	; SELECT CRTC REGISTER
VGA_DATA	.EQU	VGA_BASE + $03	; READ/WRITE CRTC DATA
VGA_CFG		.EQU	VGA_BASE + $04	; VGA3 BOARD CFG REGISTER
VGA_HI		.EQU	VGA_BASE + $05	; BOARD RAM HI ADDRESS
VGA_LO		.EQU	VGA_BASE + $06	; BOARD RAM LO ADDRESS
VGA_DAT		.EQU	VGA_BASE + $07	; BOARD RAM BYTE R/W
;
		DEVECHO	"VGA: "
		DEVECHO	"IO="
		DEVECHO	VGA_BASE
		DEVECHO	", KBD MODE=PS/2"
		DEVECHO	", KBD IO="
		DEVECHO	VGA_KBDDATA
		DEVECHO	"\n"
;
VGA_NOBL	.EQU	00000000B	; NO BLINK
VGA_NOCU	.EQU	00100000B	; NO CURSOR
VGA_BFAS	.EQU	01000000B	; BLINK AT X16 RATE
VGA_BSLO	.EQU	01100000B	; BLINK AT X32 RATE
;
VGA_BLOK	.EQU	0		; BLOCK CURSOR
VGA_ULIN	.EQU	1		; UNDERLINE CURSOR
;
VGA_CSTY	.EQU	VGA_BLOK	; DEFAULT CURSOR STYLE
VGA_BLNK	.EQU	VGA_NOBL	; DEFAULT BLINK RATE
VGA_9BIT	.EQU	$0101		; 9 BIT MSK-CFG
VGA_8BIT	.EQU	$0000		; 8 BIT MSK-CFG

VGA_NICE	.EQU	FALSE		; TRUE = SLOW BUT PRETTY
;
#IF (VGASIZ=V80X25)
VGA_ROWS	.EQU	25
VGA_COLS	.EQU	80
VGA_SCANL	.EQU	16
VGA_89BIT	.EQU	VGA_8BIT
#DEFINE USEFONT8X16
#DEFINE	VGA_FONT FONT8X16
#ENDIF
#IF (VGASIZ=V80X30)
VGA_ROWS	.EQU	30
VGA_COLS	.EQU	80
VGA_SCANL	.EQU	16
VGA_89BIT	.EQU	VGA_8BIT
#DEFINE USEFONT8X16
#DEFINE	VGA_FONT FONT8X16
#ENDIF
#IF (VGASIZ=V80X43)
VGA_ROWS	.EQU	43
VGA_COLS	.EQU	80
VGA_SCANL	.EQU	11
VGA_89BIT	.EQU	VGA_8BIT
#DEFINE USEFONT8X11
#DEFINE	VGA_FONT FONT8X11
#ENDIF
#IF (VGASIZ=V80X60)
VGA_ROWS	.EQU	60
VGA_COLS	.EQU	80
VGA_SCANL	.EQU	8
VGA_89BIT	.EQU	VGA_8BIT
#DEFINE USEFONT8X8
#DEFINE	VGA_FONT FONT8X8
#ENDIF
;
#IF VGA_CSTY=VGA_BLOK
VGA_R10		.EQU	(VGA_BLNK + $00)
VGA_R11		.EQU	VGA_SCANL-1
#ENDIF
;
#IF VGA_CSTY=VGA_ULIN
VGA_R10		.EQU	(VGA_BLNK + VGA_SCANL-1)
VGA_R11		.EQU	VGA_SCANL-1
#ENDIF
;
#DEFINE		DEFREGS		REGS_VGA
;
TERMENABLE	.SET	TRUE		; INCLUDE TERMINAL PSEUDODEVICE DRIVER
KBDENABLE	.SET	TRUE		; INCLUDE KBD KEYBOARD SUPPORT
;
; DRIVER UTILIZES THE MULTIPLE DISPLAY WINDOW FEATURE OF THE CRTC TO ACCOMPLISH
; FULL SCREEN SCROLLING WITHOUT THE NEED TO MOVE DISPLAY RAM BYTES.
;
; SCREEN 1 IMPLICITLY STARTS AT PHYSICAL ROW 0
; SCREEN 1 RAM ADDRESS POINTER POINTS TO SCREEN OFFSET (R12/R13)
; SCREEN 2 ROW DEFINES WHERE BUFFER BYTE 0 WILL BE DISPLAYED (R18)
; SCREEN 2 RAM ADDRESS IS ALWAYS ZERO (R19/R20)
;
;======================================================================
; VGA DRIVER - INITIALIZATION
;======================================================================
;
VGA_PREINIT:
	LD	IY,VGA_IDAT		; POINTER TO INSTANCE DATA
	JP	KBD_PREINIT		; INITIALIZE KEYBOARD
;	RET
;
VGA_INIT:
	LD	IY,VGA_IDAT		; POINTER TO INSTANCE DATA
;
	CALL	NEWLINE			; FORMATTING
	PRTS("VGA: IO=0x$")
	LD	A,VGA_REG
	CALL	PRTHEXBYTE
	CALL	VGA_PROBE		; CHECK FOR HW PRESENCE
	JR	Z,VGA_INIT1		; CONTINUE IF HW PRESENT
;
	; HARDWARE NOT PRESENT
	PRTS(" NOT PRESENT$")
	OR	$FF			; SIGNAL FAILURE
	RET
;
VGA_INIT1:
	; DISPLAY CONSOLE DIMENSIONS
	LD	A,VGA_COLS
	CALL	PC_SPACE
	CALL	PRTDECB
	LD	A,'X'
	CALL	COUT
	LD	A,VGA_ROWS
	CALL	PRTDECB
	PRTS(" TEXT$")

	; HARDWARE INITIALIZATION
	CALL 	VGA_CRTINIT		; SETUP THE VGA CHIP REGISTERS
	CALL	VGA_LOADFONT		; LOAD FONT DATA FROM ROM TO VGA STORAGE
	CALL	VGA_VDARES
	CALL	KBD_INIT		; INITIALIZE KEYBOARD DRIVER

	; ADD OURSELVES TO VDA DISPATCH TABLE
	LD	BC,VGA_FNTBL		; BC := FUNCTION TABLE ADDRESS
	LD	DE,VGA_IDAT		; DE := VGA INSTANCE DATA PTR
	CALL	VDA_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED

	; INITIALIZE EMULATION
	LD	C,A			; C := ASSIGNED VIDEO DEVICE NUM
	LD	DE,VGA_FNTBL		; DE := FUNCTION TABLE ADDRESS
	LD	HL,VGA_IDAT		; HL := VGA INSTANCE DATA PTR
	CALL	TERM_ATTACH		; DO IT

	XOR	A			; SIGNAL SUCCESS
	RET
;
;======================================================================
; VGA DRIVER - VIDEO DISPLAY ADAPTER (VDA) FUNCTIONS
;======================================================================
;
VGA_FNTBL:
	.DW	VGA_VDAINI
	.DW	VGA_VDAQRY
	.DW	VGA_VDARES
	.DW	VGA_VDADEV
	.DW	VGA_VDASCS
	.DW	VGA_VDASCP
	.DW	VGA_VDASAT
	.DW	VGA_VDASCO
	.DW	VGA_VDAWRC
	.DW	VGA_VDAFIL
	.DW	VGA_VDACPY
	.DW	VGA_VDASCR
	.DW	KBD_STAT
	.DW	KBD_FLUSH
	.DW	KBD_READ
	.DW	VGA_VDARDC
#IF (($ - VGA_FNTBL) != (VDA_FNCNT * 2))
	.ECHO	"*** INVALID VGA FUNCTION TABLE ***\n"
	!!!!!
#ENDIF

VGA_VDAINI:
	; RESET VDA
	; CURRENTLY IGNORES VIDEO MODE AND BITMAP DATA
	CALL	VGA_VDARES	; RESET VDA

	LD	A,$07		; ATTRIBUTE IS STANDARD WHITE ON BLACK
	LD	(VGA_ATTR),A	; SAVE IT
	XOR	A		; ZERO (REVERSE, UNDERLINE, BLINK)
	LD	(VGA_RUB),A	; SAVE IT

	LD	DE,0		; ROW = 0, COL = 0
	CALL	VGA_XY		; SEND CURSOR TO TOP LEFT
	LD	A,' '		; BLANK THE SCREEN
	LD	DE,VGA_ROWS*VGA_COLS	; FILL ENTIRE BUFFER
	CALL	VGA_FILL	; DO IT
	LD	DE,0		; ROW = 0, COL = 0
	CALL	VGA_XY		; SEND CURSOR TO TOP LEFT

	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDAQRY:
	LD	C,$00		; MODE ZERO IS ALL WE KNOW
	LD	D,VGA_ROWS	; ROWS
	LD	E,VGA_COLS	; COLS
	LD	HL,0		; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED YET
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDARES:
	LD	HL,$0404 | VGA_89BIT; SET VIDEO ENABLE BIT
	CALL	VGA_SETCFG	; DO IT

	XOR	A
	RET

VGA_VDADEV:
	LD	D,VDADEV_VGA	; D := DEVICE TYPE
	LD	E,0		; E := PHYSICAL UNIT IS ALWAYS ZERO
	LD	H,0		; H := 0, DRIVER HAS NO MODES
	LD	L,VGA_BASE	; L := BASE I/O ADDRESS
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDASCS:
	SYSCHKERR(ERR_NOTIMPL)	; NOT IMPLEMENTED (YET)
	RET

VGA_VDASCP:
	CALL	VGA_XY		; SET CURSOR POSITION
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDASAT:
	; INCOMING IS:  -----RUB (R=REVERSE, U=UNDERLINE, B=BLINK)
	;
	; JUST SAVE THE VALUE AND FALL THROUGH.  ONLY REVERSE IS
	; SUPPORTED WHICH IS IMPLEMENTED BELOW.
	LD	A,E
	LD	(VGA_RUB),A	; SAVE IT
	JR	VGA_VDASCO2	; IMPLEMENT SETTING

VGA_VDASCO:
	; WE HANDLE ONLY PER-CHARACTER COLORS (D=0)
	LD	A,D		; GET CHAR/SCREEN SCOPE
	OR	A		; CHARACTER?
	JR	NZ,VGA_VDASCO3	; IF NOT, JUST RETURN
	; INCOMING IS:  IBGRIBGR (I=INTENSITY, B=BLUE, G=GREEN, R=RED)
	; TRANSFORM TO: -RGBIRGB (DISCARD INTENSITY BIT IN HIGH NIBBLE)
	;
	; A := INVERTED E, SO A IS RGBIRGBI (F/B)
	LD	B,8		; DO 8 BITS
VGA_VDASCO1:
	RRC	E		; LOW BIT OF E ROTATED RIGHT INTO CF
	RLA			; CF ROTATED LEFT INTO LOW BIT OF A
	DJNZ	VGA_VDASCO1	; DO FOR ALL 8 BITS
	; LS A X 3 TO SWAP F/B BITS, SO A IS IRGBIRGB (B/F)
	RLCA
	RLCA
	RLCA
	; MASK FOR RELEVANT BITS, SO A IS 0R0B0R0B
	AND	%01010101
	; SAVE A IN C AND SET A = E
	LD	C,A
	LD	A,E
	; MASK FOR RELEVANT BITS, SO A IS 00G0I0G0
	AND	%00101010
	; COMBINE WITH SAVED
	OR	E
	; SAVE NEW ATTR VALUE
	LD	(VGA_ATTR),A	; AND SAVE THE RESULT
VGA_VDASCO2:
	; CHECK FOR REVERSE VIDEO
	LD	A,(VGA_RUB)	; GET RUB SETTING
	BIT	2,A		; REVERSE IS BIT 2
	JR	Z,VGA_VDASCO3	; DONE IF REVERSE VID NOT SET
	; IMPLEMENT REVERSE VIDEO
	LD	A,(VGA_ATTR)	; GET ATTRIBUTE
	PUSH	AF		; SAVE IT
	AND	%00001000	; ISOLATE INTENSITY BIT
	LD	E,A		; SAVE IN E
	POP	AF		; GOT ATTR BACK
	RLCA			; SWAP FG/BG COLORS
	RLCA
	RLCA
	RLCA
	AND	%01110111	; REMOVE HIGH BITS
	OR	E		; COMBINE WITH PREVIOUS INTENSITY BIT
	LD	(VGA_ATTR),A	; SAVE NEW VALUE
VGA_VDASCO3:
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDAWRC:
	LD	A,E		; CHARACTER TO WRITE GOES IN A
	CALL	VGA_PUTCHAR	; PUT IT ON THE SCREEN
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDAFIL:
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	VGA_FILL	; DO THE FILL
	XOR	A		; SIGNAL SUCCESS
	RET

VGA_VDACPY:
	; LENGTH IN HL, SOURCE ROW/COL IN DE, DEST IS VGA_POS
	; BLKCPY USES: HL=SOURCE, DE=DEST, BC=COUNT
	PUSH	HL		; SAVE LENGTH
	CALL	VGA_XY2IDX	; ROW/COL IN DE -> SOURCE ADR IN HL
	POP	BC		; RECOVER LENGTH IN BC
	LD	DE,(VGA_POS)	; PUT DEST IN DE
	JP	VGA_BLKCPY	; DO A BLOCK COPY

VGA_VDASCR:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	RET	Z		; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,VGA_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	VGA_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	VGA_VDASCR	; LOOP
VGA_VDASCR1:
	CALL	VGA_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	VGA_VDASCR	; LOOP

;----------------------------------------------------------------------
; READ VALUE AT CURRENT VDU BUFFER POSITION
; RETURN E = CHARACTER, B = COLOUR, C = ATTRIBUTES
;----------------------------------------------------------------------

VGA_VDARDC:
	OR	$FF		; UNSUPPORTED FUNCTION
	RET
;
;======================================================================
; VGA DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;----------------------------------------------------------------------
; SET BOARD CONFIGURATON REGISTER
;   MASK IN H, VALUE IN L
;----------------------------------------------------------------------
;
VGA_SETCFG:
	PUSH	AF		; PRESERVE AF
	LD	A,H		; MASK IN ACCUM
	CPL			; INVERT IT
	LD	H,A		; BACK TO H
	LD	A,(VGA_CFGV)	; GET CURRENT CONFIG VALUE
	AND	H		; RESET ALL TARGET BITS
	OR	L		; SET TARGET BITS
	LD	(VGA_CFGV),A	; SAVE NEW VALUE
	OUT	(VGA_CFG),A	; AND WRITE IT TO REGISTER
	POP	AF		; RESTORE AF
	RET
;
;----------------------------------------------------------------------
; UPDATE CRTC REGISTERS
;   VGA_REGWR WRITES VALUE IN A TO VDU REGISTER SPECIFIED IN C
;----------------------------------------------------------------------
;
VGA_REGWR:
	PUSH	AF			; SAVE VALUE TO WRITE
	LD	A,C			; SET A TO VGA REGISTER TO SELECT
	OUT	(VGA_REG),A		; WRITE IT TO SELECT THE REGISTER
	POP	AF			; RESTORE VALUE TO WRITE
	OUT	(VGA_DATA),A		; WRITE IT
	RET
;
VGA_REGWRX:
	LD	A,H			; SETUP MSB TO WRITE
	CALL	VGA_REGWR		; DO IT
	INC	C			; NEXT VDU REGISTER
	LD	A,L			; SETUP LSB TO WRITE
	JR	VGA_REGWR		; DO IT & RETURN
;
;----------------------------------------------------------------------
; READ CRTC REGISTERS
;   VGA_REGRD READS VDU REGISTER SPECIFIED IN C AND RETURNS VALUE IN A
;----------------------------------------------------------------------
;
VGA_REGRD:
	LD	A,C			; SET A TO VGA REGISTER TO SELECT
	OUT	(VGA_REG),A		; WRITE IT TO SELECT THE REGISTER
	IN	A,(VGA_DATA)		; READ IT
	RET
;
VGA_REGRDX:
	CALL	VGA_REGRD		; GET VALUE FROM REGISTER IN C
	LD	H,A			; SAVE IN H
	INC	C			; BUMP TO NEXT REGISTER OF PAIR
	CALL	VGA_REGRD		; READ THE VALUE
	LD	L,A			; SAVE IT IN L
	RET
;
;----------------------------------------------------------------------
; WRITE VIDEO RAM
;   VGA_MEMWR WRITES VALUE IN A TO ADDRESS IN DE
;   VGA_MEMWRX WRITES VALUE IN HL TO ADDRESS IN DE
;----------------------------------------------------------------------
;
VGA_MEMWR:
	LD	C,VGA_HI
	OUT	(C),D
	INC	C
	OUT	(C),E
	INC	C
	OUT	(C),A
	RET
;
VGA_MEMWRX:
	LD	C,VGA_HI
	OUT	(C),D
	INC	C
	OUT	(C),E
	INC	C
	OUT	(C),H
	INC	E
	DEC	C
	OUT	(C),E
	INC	C
	OUT	(C),L
	DEC	E
	RET
;
;----------------------------------------------------------------------
; READ VIDEO RAM
;   VGA_MEMRD READS VALUE IN DE TO A
;   VGA_MEMRDX READS VALUE IN DE TO HL
;----------------------------------------------------------------------
;
VGA_MEMRD:
	LD	C,VGA_HI
	OUT	(C),D
	INC	C
	OUT	(C),E
	INC	C
	IN	A,(C)
	RET
;
VGA_MEMRDX:
	LD	C,VGA_HI
	OUT	(C),D
	INC	C
	OUT	(C),E
	INC	C
	IN	H,(C)
	INC	E
	DEC	C
	OUT	(C),E
	INC	C
	IN	L,(C)
	DEC	E
	RET
;
;----------------------------------------------------------------------
; WAIT FOR VERTICAL RETRACE ACTIVE
;----------------------------------------------------------------------
;
VGA_WAITSB:
	LD	A,31			; CRTC REG 31 IS STATUS REG
	OUT	(VGA_REG),A		; SETUP TO ACCESS IT
VGA_WAITSB1:
	IN	A,(VGA_DATA)		; GET STATUS
	BIT	1,A			; TEST SB BIT (RETRACE ACTIVE)
	RET	NZ			; RETURN IF ACTIVE
	JR	VGA_WAITSB1		; LOOP
;
;----------------------------------------------------------------------
; PROBE FOR VGA HARDWARE
;----------------------------------------------------------------------
;
; ON RETURN, ZF SET INDICATES HARDWARE FOUND
;
VGA_PROBE:
	LD	DE,0			; POINT TO FIRST BYTE OF VRAM
	LD	A,$A5			; INITIAL TEST VALUE
	LD	B,A			; SAVE IN B
	CALL	VGA_MEMWR		; WRITE IT
	INC	E			; NEXT BYTE OF VRAM
	CPL				; INVERT TEST VALUE
	CALL	VGA_MEMWR		; WRITE IT
	DEC	E			; BACK TO FIRST BYTE OF VRAM
	CALL	VGA_MEMRD		; READ IT
	CP	B			; CHECK FOR TEST VALUE
	RET	NZ			; RETURN NZ IF FAILURE
	INC	E			; SECOND VRAM BYTE
	CALL	VGA_MEMRD		; READ IT
	CPL				; INVERT IT
	CP	B			; CHECK FOR INVERTED TEST VALUE
	RET				; RETURN WITH ZF SET BASED ON CP
;
;----------------------------------------------------------------------
; CRTC DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
VGA_CRTINIT:
	LD	HL,$FF00 | VGA_89BIT	; INITIAL CFG BITS
	CALL	VGA_SETCFG		; DO IT

	CALL	VGA_RES			; RESET CRTC (ALL REGS TO ZERO)

	LD	HL,DEFREGS		; HL = POINTER TO TABLE OF REG VALUES
VGA_CRTINIT1:
	LD	A,(HL)			; FIRST BYTE IS REG ADR
	LD	C,A			; PUT IN C FOR LATER
	INC	A			; TEST FOR END MARKER ($FF)
	RET	Z			; IF EQUAL, DONE
	INC	HL			; NEXT BYTE
	LD	A,(HL)			; SECOND BYTE IS REG VAL
	INC	HL			; HL TO NEXT ENTRY
	CALL	VGA_REGWR		; WRITE REGISTER VALUE
	JR	VGA_CRTINIT1		; LOOP
;
VGA_RES:
	LD	C,0			; START WITH REG ZERO
	LD	B,40			; CLEAR 40 REGISTERS
VGA_RES1:
	XOR	A			; VALUE IS ZERO
	CALL	VGA_REGWR		; SET VALUE
	INC	C			; NEXT REGISTER
	DJNZ	VGA_RES1		; LOOP TILL DONE
	RET				; DONE
;
VGA_CRTCDUMP:
	LD	C,0			; START WITH REG ZERO
	LD	B,40			; CLEAR 40 REGISTERS
VGA_CRTCDUMP1:
	CALL	VGA_REGRD		; SET VALUE
	CALL	PRTHEXBYTE
	CALL	PC_SPACE
	INC	C			; NEXT REGISTER
	DJNZ	VGA_CRTCDUMP1		; LOOP TILL DONE
	RET				; DONE
;
;----------------------------------------------------------------------
; LOAD FONT DATA
;
; IF V80X60 MODE IS USED THEN THE 8*8 UNCOMPRESSED FONT IS ALWAYS USED.
; THE FONT DATA MAY BE STORED IN THE HBIOS AREA OR ROM BANK 3 (BID_IMG2)
; EXCEPT FOR THE 8X8 FONT, DATA MAY BE COMPRESSED OR UNCOMPRESSED.
;----------------------------------------------------------------------
;
; IF FONTS ARE STORED INLINE IN HBIOS:
;  IF 8x8 - NO COMPRESSION SO PROGRAM STRAIGHT FROM HBIOS
;  IF UNCOMPRESSED - PROGRAM STRAIGHT FROM HBIOS
;  IF COMPRESSED - DECOMPRESS FIRST
; IF FONTS ARE STORED IN BANK3
;  IF 8x8 - NO COMPRESSION - SO PROGRAM FROM BANK3 USING PEEK
;  IF UNCOMPRESSED - PROGRAM FROM BANK3 USING PEEK
;  IF COMPRESSED - DECOMPRESS FIRST
;
VGA_LOADFONT:
	LD	HL,$7000 | VGA_89BIT	; CLEAR FONT PAGE NUM
	CALL	VGA_SETCFG

#IF USELZSA2 & (VGASIZ != V80X60)
	LD	(VGA_STACK),SP		; SAVE STACK
	LD	HL,(VGA_STACK)		; AND SHIFT IT
	LD	DE,$2000		; DOWN 4KB TO
	OR	A			; CREATE A
	SBC	HL,DE			; DECOMPRESSION BUFFER
	LD	SP,HL			; HL POINTS TO BUFFER
	EX	DE,HL			; START OF STACK BUFFER
	PUSH	DE			; SAVE IT
	LD	HL,VGA_FONT & $7FFF	; START OF FONT DATA
	CALL	DLZSA2			; DECOMPRESS TO DE
	POP	HL			; RECALL STACK BUFFER POSITION
#ELSE
	LD	HL,VGA_FONT & $7FFF	; START OF FONT DATA
#ENDIF
;
;	AT THIS POINT HL POINTS TO UNCOMPRESSED FONT DATA
;	THIS DATA MAY BE IN THE HBIOS AREA, IN THE STACK BUFFER
;	OR IN BANK 3
;
	LD	DE,$7000		; PAGE 7 OF VIDEO RAM
VGA_LOADFONT1:
	LD	B,VGA_SCANL		; # BYTES FOR EACH CHAR
VGA_LOADFONT2:

#IF	((USELZSA2 == FALSE) & (FONTS_INLINE == FALSE))
	PUSH	DE
	LD	D,BID_IMG2
	CALL	HBX_PEEK		; GET NEXT BYTE FROM ROM BANK 3
	LD	A,E
	POP	DE
#ELSE
	LD	A,(HL)			; GET NEXT BYTE FROM HBIOS OR STACK BUFFER
#ENDIF
;	CALL	PRTHEXBYTE
	CALL	VGA_MEMWR		; MEM(DE) := A
	INC	HL			; NEXT FONT BYTE
	INC	DE			; NEXT MEM BYTE
	DJNZ	VGA_LOADFONT2

	LD	BC,16-VGA_SCANL		; MOVE TO NEXT
	EX	DE,HL			; 16 BYTE
	ADD	HL,BC			; CHARACTER
	EX	DE,HL

	LD	A,D
	CP	$80			; CHECK FOR END
	JR	NZ,VGA_LOADFONT1	; LOOP
	LD	HL,$7070 | VGA_89BIT	; SET FONT PAGE NUM TO 7
	CALL	VGA_SETCFG

#IF USELZSA2 & (VGASIZ != V80X60)
	LD	HL,(VGA_STACK)		; ERASE DECOMPRESS BUFFER
	LD	SP,HL			; BY RESTORING THE STACK
	RET				; DONE
VGA_STACK	.DW	0
#ELSE
	RET
#ENDIF
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
VGA_XY:
	CALL	VGA_XY2IDX		; CONVERT ROW/COL TO BUF IDX
	LD	(VGA_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
    	LD 	C,14			; CURSOR POSITION REGISTER PAIR
	JP	VGA_REGWRX		; DO IT AND RETURN
;
;----------------------------------------------------------------------
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;----------------------------------------------------------------------
;
VGA_XY2IDX:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,VGA_COLS		; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN

	LD	DE,(VGA_OFF)		; SCREEN OFFSET
	ADD	HL,DE			; ADJUST
;
	PUSH	HL			; SAVE IT
	LD	DE,VGA_ROWS * VGA_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VGA_XY2IDX1		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	RET				; DONE
VGA_XY2IDX1:
	POP	HL			; NO WRAP, RESTORE
	RET				; RETURN
;
;----------------------------------------------------------------------
; WRITE VALUE IN A TO CURRENT VDU BUFFER POSITION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
VGA_PUTCHAR:
	; SETUP DE WITH BUFFER ADDRESS
	LD	DE,(VGA_POS)		; GET CURRENT POSITION
	SLA	E			; MULTIPLY BY 2
	RL	D			; ... 2 BYTES PER CHAR
	; SETUP CHAR/ATTR IN HL
	LD	H,A			; CHARACTER
	LD	A,(VGA_ATTR)		; ATTRIBUTE
	LD	L,A			; ... TO L
	; WRITE CHAR & ATTR
#IF (VGA_NICE)
	CALL	VGA_WAITSB		; WAIT FOR RETRACE
#ENDIF
	CALL	VGA_MEMWRX
	; UPDATE CURRENT POSITION
	LD	HL,(VGA_POS)		; GET CURSOR POSITION
	INC	HL			; INCREMENT
;
	PUSH	HL			; SAVE IT
	LD	DE,VGA_ROWS * VGA_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VGA_PUTCHAR1		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	JR	VGA_PUTCHAR2		; CONTINUE
VGA_PUTCHAR1:
	POP	HL			; NO WRAP, RESTORE
VGA_PUTCHAR2:
	LD	(VGA_POS),HL		; SAVE NEW POSITION
    	LD 	C,14			; CURSOR POSITION REGISTER PAIR
	JP	VGA_REGWRX		; DO IT AND RETURN
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
VGA_FILL:
	LD	B,A			; CACHE FILL CHAR IN B

	; SETUP HL WITH INITIAL BUFFER ADDRESS
	LD	HL,(VGA_POS)		; GET CURRENT POSITION
	SLA	L			; MULTIPLY BY 2
	RL	H			; ... 2 BYTES PER CHAR

VGA_FILL1:
	; FILL ONE POSITION (CHAR & ATTR)
	LD	C,VGA_HI		; C := VGA ADR HI
	OUT	(C),H			; SET HI ADDR
	INC	C			; C := VGA ADR LO
	OUT	(C),L			; SET LO ADDR
	INC	C			; POINT TO DATA REG
	OUT	(C),B			; OUTPUT FILL CHAR
	INC	L			; BUMP ADDR (ONLY NEED TO DO LOW BYTE)
	DEC	C			; C := VGA ADDR LO
	OUT	(C),L			; UDPATE LO ADDR
	INC	C			; POINT TO DATA REG
#IF (VGA_NICE)
	CALL	VGA_WAITSB		; WAIT FOR RETRACE
#ENDIF
	LD	A,(VGA_ATTR)		; GET CUR ATTR
	OUT	(C),A			; OUTPUT ATTR

	; CHECK COUNT
	DEC	DE			; DECREMENT COUNT
	LD	A,D			; TEST FOR
	OR	E			; ... ZERO
	RET	Z			; DONE IF SO

	; BUMP BUFFER ADDRESS WITH POSSIBLE WRAP
	INC	HL			; NEXT POSITION
	LD	A,0 + (VGA_ROWS * VGA_COLS * 2) & $FF
	CP	L			; TEST LOW BYTE
	JR	NZ,VGA_FILL1		; IF NOT EQ, NO WRAP, LOOP
	LD	A,0 + ((VGA_ROWS * VGA_COLS * 2) >> 8) & $FF
	CP	H			; TEST HI BYTE
	JR	NZ,VGA_FILL1		; IF NOT EQ, NO WRAP, LOOP
	LD	HL,0			; WRAP!
	JR	VGA_FILL1		; AND LOOP
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VGA_SCROLL:
	; CLEAR TOP LINE WHICH IS ABOUT TO BECOME NEW LINE
	; AT BOTTOM OF SCREEN
	LD	DE,(VGA_POS)		; GET CURRENT POS
	PUSH	DE			; SAVE IT
	LD	DE,(VGA_OFF)		; TOP OF SCREEN IS OFFSET VALUE
	LD	(VGA_POS),DE		; SET POS
	LD	DE,VGA_COLS		; CLEAR ONE ROW
	LD	A,' '			; WITH BLANKS
	CALL	VGA_FILL		; DO IT
	POP	DE			; GET ORIG POS VALUE BACK
	LD	(VGA_POS),DE		; AND SAVE IT
;
	; OFF += ROWLEN, IF OFF >= BUFSIZ, ADR := 0
	LD	HL,(VGA_OFF)		; CURRENT SCREEN OFFSET
	LD	A,VGA_COLS		; ROW LENGTH
	CALL	ADDHLA			; BUMP TO NEXT ROW
	PUSH	HL			; SAVE IT
	LD	DE,VGA_ROWS * VGA_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VGA_SCROLL1
	LD	HL,0			; WRAP AROUND TO 0
	POP	DE			; THROW AWAY TOS
	JR	VGA_SCROLL2		; CONTINUE
VGA_SCROLL1:
	POP	HL			; NO WRAP, RESTORE
VGA_SCROLL2:
	LD	(VGA_OFF),HL		; SAVE IT
	CALL	VGA_WAITSB
	LD	C,12			; SCREEN 1 ADDRESS
	CALL	VGA_REGWRX		; COMMIT
;
	; S2ROW--, IF S2ROW < 0, THEN S2ROW := MAXROW
	LD	A,(VGA_S2ROW)		; CURRENT S2 ROW
	OR	A			; = 0?
	JR	Z,VGA_SCROLL3		; IF 0, WRAP
	DEC	A			; DECREMENT
	JR	VGA_SCROLL4		; AND CONTINUE
VGA_SCROLL3:
	LD	A,VGA_ROWS - 1		; WRAP BACK TO MAX ROW
VGA_SCROLL4:
	LD	(VGA_S2ROW),A		; SAVE IT
	DEC	A			; ADJUST
	LD	C,18			; S2 ROW REG
	CALL	VGA_REGWR		; COMMIT
;
	; POS += ROWLEN; IF POS >= BUFSIZ, POS -= BUFSIZ
	LD	HL,(VGA_POS)		; CURRENT POSITION
	LD	A,VGA_COLS		; ROW LENGTH
	CALL	ADDHLA			; BUMP TO NEXT ROW
	PUSH	HL			; SAVE IT
	LD	DE,VGA_ROWS * VGA_COLS	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VGA_SCROLL5		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	JR	VGA_SCROLL6		; CONTINUE
VGA_SCROLL5:
	POP	HL			; NO WRAP, RESTORE
VGA_SCROLL6:
	LD	(VGA_POS),HL		; SAVE IT
	LD	C,14			; CURSOR 1 POS REG
	CALL	VGA_REGWRX		; COMMIT

	RET
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
VGA_RSCROLL:
	; OFF -= ROWLEN, IF OFF < 0, OFF := MAXROW ((ROWS - 1) * COLS)
	LD	HL,(VGA_OFF)		; CURRENT SCREEN OFFSET
	LD	DE,VGA_COLS		; SUBTRACT ONE ROW
	SBC	HL,DE			; DO IT
	JR	NC,VGA_RSCROLL1		; IF NOT NEGATIVE, CONTINUE
	LD	HL,0 + ((VGA_ROWS - 1) * VGA_COLS)
VGA_RSCROLL1:
	LD	(VGA_OFF),HL		; SAVE IT
	CALL	VGA_WAITSB		; WAIT FOR RETRACE
	LD	C,12			; SCREEN 1 ADDRESS
	CALL	VGA_REGWRX		; COMMIT
;
	; S2ROW++, IF S2ROW >= ROWS, THEN S2ROW := 0
	LD	A,(VGA_S2ROW)		; CURRENT S2 ROW
	INC	A			; BUMP TO NEXT ROW
	CP	VGA_ROWS		; COMPARE TO ROWS
	JR	C,VGA_RSCROLL2		; IF NOT >= ROWS, CONTINUE
	XOR	A			; SET TO ZERO
VGA_RSCROLL2:
	LD	(VGA_S2ROW),A		; SAVE IT
	DEC	A			; ADJUST
	LD	C,18			; S2 ROW REG
	CALL	VGA_REGWR		; COMMIT
;
	; POS -= ROWLEN; IF POS < 0, POS += BUFSIZ
	LD	HL,(VGA_POS)		; CURRENT SCREEN OFFSET
	LD	DE,VGA_COLS		; SUBTRACT ONE ROW
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; DO IT
	JR	NC,VGA_RSCROLL3		; IF NOT NEGATIVE, CONTINUE
	LD	DE,VGA_ROWS * VGA_COLS	; DE := BUF SIZE
	ADD	HL,DE			; ADD TO HL
VGA_RSCROLL3:
	LD	(VGA_POS),HL		; SAVE IT
	LD	C,14			; CURSOR 1 POS REG
	CALL	VGA_REGWRX		; COMMIT
;
	; CLEAR TOP LINE JUST EXPOSED
	LD	DE,(VGA_POS)		; GET CURRENT POS
	PUSH	DE			; SAVE IT
	LD	DE,(VGA_OFF)		; TOP OF SCREEN IS OFFSET VALUE
	LD	(VGA_POS),DE		; SET POS
	LD	DE,VGA_COLS		; CLEAR ONE ROW
	LD	A,' '			; WITH BLANKS
	CALL	VGA_FILL		; DO IT
	POP	DE			; GET ORIG POS VALUE BACK
	LD	(VGA_POS),DE		; AND SAVE IT
;
	RET
;
;----------------------------------------------------------------------
; BLOCK COPY BC BYTES FROM HL TO DE
;----------------------------------------------------------------------
;
VGA_BLKCPY:
	; DOUBLE BC TO ACCOUNT FOR 2 BYTE ENTRIES (CHAR & ATTR)
	SLA	C
	RL	B
	PUSH	BC			; COUNT ==> TOS

	; ADJUST HL & DE FOR SCREEN OFFSET/WRAP
	CALL	VGA_BLKCPY4		; DO HL
	EX	DE,HL			; SWAP
	CALL	VGA_BLKCPY4		; DO OTHER
	EX	DE,HL			; SWAP BACK

VGA_BLKCPY1:
#IF (VGA_NICE)
	CALL	VGA_WAITSB		; WAIT FOR RETRACE
#ENDIF

	; GET NEXT SOURCE BYTE
	LD	C,VGA_HI		; C := VGA_HI
	OUT	(C),H			; VGA_HI := SOURCE HI (H)
	INC	C			; C := VGA_LO
	OUT	(C),L			; VGA_LO := SOURCE LO (L)
	INC	C			; C := VGA_DATA
	IN	A,(C)			; A := (HL)

	; COPY TO DESTINATION
	LD	C,VGA_HI		; C := VGA_HI
	OUT	(C),D			; VGA_HI := SOURCE HI (H)
	INC	C			; C := VGA_LO
	OUT	(C),E			; VGA_LO := SOURCE LO (L)
	INC	C			; C := VGA_DATA
	OUT	(C),A			; (DE) := A

	; BUMP SOURCE ADDRESS WITH POSSIBLE WRAP
	INC	HL			; NEXT POSITION
	LD	A,0 + (VGA_ROWS * VGA_COLS * 2) & $FF
	CP	L			; TEST LOW BYTE
	JR	NZ,VGA_BLKCPY2		; IF NOT EQ, NO WRAP, CONTINUE
	LD	A,0 + ((VGA_ROWS * VGA_COLS * 2) >> 8) & $FF
	CP	H			; TEST HI BYTE
	JR	NZ,VGA_BLKCPY2		; IF NOT EQ, NO WRAP, CONTINUE
	LD	HL,0			; WRAP!

VGA_BLKCPY2:
	; BUMP DEST ADDRESS WITH POSSIBLE WRAP
	INC	DE			; NEXT POSITION
	LD	A,0 + (VGA_ROWS * VGA_COLS * 2) & $FF
	CP	E			; TEST LOW BYTE
	JR	NZ,VGA_BLKCPY3		; IF NOT EQ, NO WRAP, CONTINUE
	LD	A,0 + ((VGA_ROWS * VGA_COLS * 2) >> 8) & $FF
	CP	D			; TEST HI BYTE
	JR	NZ,VGA_BLKCPY3		; IF NOT EQ, NO WRAP, CONTINUE
	LD	DE,0			; WRAP!

VGA_BLKCPY3:
	; DECREMENT BYTE COUNT AND CHECK FOR COMPLETION
	EX	(SP),HL			; GET COUNT, SAVE HL
	DEC	HL			; DECREMENT
	LD	A,H			; TEST FOR
	CP	L			; ... ZERO
	EX	(SP),HL			; COUNT BACK TO TOS, RESTORE HL
	JR	NZ,VGA_BLKCPY1		; LOOP IF NOT ZERO
	POP	BC			; CLEAN UP STACK
	RET				; DONE
;
VGA_BLKCPY4:
	; SUBROUTINE TO ADJUST FOR SCREEN OFFSET/WRAP
	PUSH	DE			; SAVE DE
	LD	DE,(VGA_OFF)		; CUR SCRN OFFSET
	;ADD	HL,DE			; ADJUST FOR OFFSET
	SLA	L			; MULTIPLY BY 2
	RL	H			; ... FOR TWO BYTES PER ENTRY
	PUSH	HL			; SAVE IT
	LD	DE,VGA_ROWS * VGA_COLS * 2	; DE := BUF SIZE
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	JR	C,VGA_BLKCPY4A		; BYPASS IF NO WRAP
	POP	DE			; THROW AWAY TOS
	JR	VGA_BLKCPY4B		; CONTINUE
VGA_BLKCPY4A:
	POP	HL			; NO WRAP, RESTORE
VGA_BLKCPY4B:
	POP	DE			; RESTORE DE
	RET
;
;==================================================================================================
;   VGA DRIVER - DATA
;==================================================================================================
;
VGA_ATTR	.DB	0	; CURRENT COLOR
VGA_POS		.DW 	0	; CURRENT DISPLAY POSITION
VGA_OFF		.DW	0	; SCREEN START OFFSET INTO CRTC RAM
VGA_S2ROW	.DB	0	; CURRENT S2 ROW
VGA_CFGV	.DB	0	; CURRENT BOARD CONFIG VALUE
VGA_RUB		.DB	0	; REVERSE/UNDERLINE/BLINK (-----RUB)
;
; ATTRIBUTE ENCODING:
;   BIT 7: ALT FONT
;   BIT 6: BG REG
;   BIT 5: BG GREEN
;   BIT 4: BG BLUE
;   BIT 3: FG INTENSITY
;   BIT 2: FG RED
;   BIT 1: FG GREEN
;   BIT 0: FG BLUE
;
#IF	(VGASIZ=V80X25)
;===============================================================================
; 80x25x8 70hz REGISTER VALUES
;===============================================================================
;
REGS_VGA:
	.DB	0,100 - 1	; HORZ TOT - 1
	.DB	1,VGA_COLS	; HORZ DISP
	.DB	2,VGA_COLS + 2	; HORZ DISP + HORZ FP
	.DB	3,(2 << 4) | (12 & $0F)	; VERT SW, HORZ SW
	.DB	4,28 - 1	; VERT TOT - 1
	.DB	5,1		; VERT TOT ADJ
	.DB	6,VGA_ROWS	; VERT DISP
	.DB	7,VGA_ROWS + 0	; VERT DISP + VERT FP ROWS
	.DB	9,VGA_SCANL - 1	; CHAR HEIGHT - 1
	.DB	10,VGA_R10	; CURSOR START & CURSOR BLINK
	.DB	11,VGA_R11	; CURSOR END
	.DB	12,($0000 >> 8) & $FF	; SCRN 1 START (HI)
	.DB	13,($0000 & $FF)	; SCRN 1 START (LO)
	.DB	18,-1		; S2 ROW - 1
	.DB	27,12		; VERT SYNC POS ADJ
	.DB	30,$01 | $08	; CTL 1, 2 WINDOWS & ENABLE R27 VSYNC FINE ADJ

	.DB	$FF		; END MARKER
#ENDIF
#IF	(VGASIZ=V80X30)
;===============================================================================
; 80x30x8 60hz REGISTER VALUES
;===============================================================================
;
REGS_VGA:
	.DB	0,100 - 1	; HORZ TOT - 1
	.DB	1,VGA_COLS	; HORZ DISP
	.DB	2,VGA_COLS + 2	; HORZ DISP + HORZ FP
	.DB	3,44		; VERT SW, HORZ SW
	.DB	4,33 - 1	; VERT TOT - 1
	.DB	5,13		; VERT TOT ADJ
	.DB	6,VGA_ROWS	; VERT DISP
	.DB	7,VGA_ROWS + 0	; VERT DISP + VERT FP ROWS
	.DB	9,VGA_SCANL - 1	; CHAR HEIGHT - 1
	.DB	10,VGA_R10	; CURSOR START & CURSOR BLINK
	.DB	11,VGA_R11	; CURSOR END
	.DB	12,0		; SCRN 1 START (HI)
	.DB	13,0		; SCRN 1 START (LO)
	.DB	18,-1		; S2 ROW - 1
	.DB	27,0		; VERT SYNC POS ADJ
	.DB	30,$01 | $08	; CTL 1, 2 WINDOWS & ENABLE R27 VSYNC FINE ADJ
	.DB	$FF		; END MARKER
#ENDIF
#IF	(VGASIZ=V80X43)
;===============================================================================
; 80x43x8 60hz REGISTER VALUES
;===============================================================================
;
REGS_VGA:
	.DB	0,100 - 1	; HORZ TOT - 1
	.DB	1,VGA_COLS	; HORZ DISP
	.DB	2,VGA_COLS + 2	; HORZ DISP + HORZ FP
	.DB	3,44		; VERT SW, HORZ SW
	.DB	4,47 - 1	; VERT TOT - 1
	.DB	5,8		; VERT TOT ADJ
	.DB	6,VGA_ROWS	; VERT DISP
	.DB	7,VGA_ROWS + 0	; VERT DISP + VERT FP ROWS
	.DB	9,VGA_SCANL - 1	; CHAR HEIGHT - 1
	.DB	10,VGA_R10	; CURSOR START & CURSOR BLINK
	.DB	11,VGA_R11	; CURSOR END
	.DB	12,0		; SCRN 1 START (HI)
	.DB	13,0		; SCRN 1 START (LO)
	.DB	18,-1		; S2 ROW - 1
	.DB	27,0		; VERT SYNC POS ADJ
	.DB	30,$01 | $08	; CTL 1, 2 WINDOWS & ENABLE R27 VSYNC FINE ADJ
	.DB	$FF		; END MARKER
#ENDIF
#IF	(VGASIZ=V80X60)
;===============================================================================
; 80x60X8 60hz REGISTER VALUES
;===============================================================================
;
REGS_VGA:
	.DB	0,100 - 1	; HORZ TOT - 1
	.DB	1,VGA_COLS	; HORZ DISP
	.DB	2,VGA_COLS + 2	; HORZ DISP + HORZ FP
	.DB	3,44		; VERT SW, HORZ SW
	.DB	4,66 - 1	; VERT TOT - 1
	.DB	5,0		; VERT TOT ADJ
	.DB	6,VGA_ROWS	; VERT DISP
	.DB	7,VGA_ROWS + 0	; VERT DISP + VERT FP ROWS
	.DB	9,VGA_SCANL - 1	; CHAR HEIGHT - 1
	.DB	10,VGA_R10	; CURSOR START & CURSOR BLINK
	.DB	11,VGA_R11	; CURSOR END
	.DB	12,0		; SCRN 1 START (HI)
	.DB	13,0		; SCRN 1 START (LO)
	.DB	18,-1		; S2 ROW - 1
	.DB	27,0		; VERT SYNC POS ADJ
	.DB	30,$01 | $08	; CTL 1, 2 WINDOWS & ENABLE R27 VSYNC FINE ADJ
	.DB	$FF		; END MARKER
#ENDIF
;==================================================================================================
;   VGA DRIVER - INSTANCE DATA
;==================================================================================================
;
VGA_IDAT:
	.DB	KBDMODE_PS2	; PS/2 8242 KEYBOARD CONTROLLER
	.DB	VGA_KBDST
	.DB	VGA_KBDDATA
