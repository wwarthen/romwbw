;
; tty_dochar - added setup in HL of position data before call to write
;==================================================================================================
;   TTY EMULATION MODULE
;==================================================================================================
;
; TODO:
;   - SOME FUNCTIONS ARE NOT IMPLEMENTED!!!
;
TTY_INIT:
	PRTS("TTY: RESET$")
;
	JR	TTY_INI		; REUSE THE INI FUNCTION BELOW
;
;
;
TTY_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JR	Z,TTY_IN	; $30
	DEC	A
	JR	Z,TTY_OUT	; $31
	DEC	A
	JR	Z,TTY_IST	; $32
	DEC	A
	JR	Z,TTY_OST	; $33
	DEC	A
	JR	Z,TTY_CFG	; $34
	CP	8
	JR	Z,TTY_INI	; $38
	CP	9
	JR	Z,TTY_QRY	; $39
	CALL	PANIC
;
;
;
TTY_IN:
	LD	B,BF_VDAKRD	; SET FUNCTION TO KEYBOARD READ
	JP	EMU_VDADISP	; CHAIN TO VDA DISPATCHER
;
;
;
TTY_OUT:
	CALL	TTY_DOCHAR	; HANDLE THE CHARACTER (EMULATION ENGINE)
	XOR	A		; SIGNAL SUCCESS
	RET
;
;
;
TTY_IST:
	LD	B,BF_VDAKST	; SET FUNCTION TO KEYBOARD STATUS
	JP	EMU_VDADISP	; CHAIN TO VDA DISPATCHER
;
;
;
TTY_OST:
	XOR	A		; ZERO ACCUM
	INC	A		; A := $FF TO SIGNAL OUTPUT BUFFER READY
	RET
;
;
;
TTY_CFG:
	XOR	A		; SIGNAL SUCCESS
	RET
;
;
;
TTY_INI:
	LD	B,BF_VDAQRY	; FUNCTION IS QUERY
	LD	HL,0		; WE DO NOT WANT A COPY OF THE CHARACTER BITMAP DATA
	CALL	EMU_VDADISP	; PERFORM THE QUERY FUNCTION
	LD	(TTY_DIM),DE	; SAVE THE SCREEN DIMENSIONS RETURNED
	LD	DE,0		; DE := 0, CURSOR TO HOME POSITION 0,0
	LD	(TTY_POS),DE	; SAVE CURSOR POSITION
	LD	B,BF_VDARES	; SET FUNCTION TO RESET
	JP	EMU_VDADISP	; RESET VDA AND RETURN
;
;
;
TTY_QRY:
	XOR	A		; SIGNAL SUCCESS
	RET
;
;
;
TTY_DOCHAR:
	LD	A,E		; CHARACTER TO PROCESS
	CP	8		; BACKSPACE
	JR	Z,TTY_BS
	CP	12		; FORMFEED
	JR	Z,TTY_FF
	CP	13		; CARRIAGE RETURN
	JR	Z,TTY_CR
	CP	10		; LINEFEED
	JR	Z,TTY_LF
	CP	32		; COMPARE TO SPACE (FIRST PRINTABLE CHARACTER)
	RET	C		; SWALLOW OTHER CONTROL CHARACTERS
	
;;;	LD	HL,(TTY_POS)	; physical driver needs pos data to write
	
	LD	B,BF_VDAWRC
	CALL	EMU_VDADISP	; SPIT OUT THE RAW CHARACTER
	LD	A,(TTY_COL)	; GET CUR COL
	INC	A		; INCREMENT
	LD	(TTY_COL),A	; SAVE IT
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	CP	E		; COMPARE TO COLS IN LINE
	RET	C		; NOT PAST END OF LINE, ALL DONE
	CALL	TTY_CR		; CARRIAGE RETURN
	JR	TTY_LF		; LINEFEED AND RETURN
;
TTY_FF:
	LD	DE,0		; PREPARE TO HOME CURSOR
	LD	(TTY_POS),DE	; SAVE NEW CURSOR POSITION
	CALL	TTY_XY		; EXECUTE
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	LD	H,D		; SET UP TO MULTIPLY ROWS BY COLS
	CALL	MULT8		; HL := H * E TO GET TOTAL SCREEN POSITIONS
	LD	E,' '		; FILL SCREEN WITH BLANKS
	LD	B,BF_VDAFIL	; SET FUNCTION TO FILL
	CALL	EMU_VDADISP	; PERFORM FILL
	JR	TTY_XY		; HOME CURSOR AND RETURN
;
TTY_BS:
	LD	DE,(TTY_POS)	; GET CURRENT ROW/COL IN DE
	LD	A,E		; GET CURRENT COLUMN
	CP	1		; COMPARE TO COLUMN 1
	RET	C		; LESS THAN 1, NOTHING TO DO
	DEC	E		; POINT TO PREVIOUS COLUMN
	LD	(TTY_POS),DE	; SAVE NEW COLUMN VALUE
	CALL	TTY_XY		; MOVE CURSOR TO NEW TARGET COLUMN
	LD	E,' '		; LOAD A SPACE CHARACTER
	LD	B,BF_VDAWRC	; SET FUNCTION TO WRITE CHARACTER
	CALL	EMU_VDADISP	; OVERWRITE WITH A SPACE CHARACTER
	JR	TTY_XY		; NEED TO MOVE CURSOR BACK TO NEW TARGET COLUMN
;
TTY_CR:
	XOR	A		; ZERO ACCUM
	LD	(TTY_COL),A	; COL := 0
	JR	TTY_XY		; REPOSITION CURSOR AND RETURN
;
TTY_LF:
	LD	A,(TTY_ROW)	; GET CURRENT ROW
	INC	A		; BUMP TO NEXT
	LD	(TTY_ROW),A	; SAVE IT
	LD	DE,(TTY_DIM)	; GET SCREEN DIMENSIONS
	CP	D		; COMPARE TO SCREEN ROWS
	JR	C,TTY_XY	; NOT PAST END, ALL DONE
	DEC	D		; D NOW HAS MAX ROW NUM (ROWS - 1)
	SUB	D		; A WILL NOW HAVE NUM LINES TO SCROLL
	LD	E,A		; LINES TO SCROLL -> E
	LD	B,BF_VDASCR	; SET FUNCTION TO SCROLL
	CALL	EMU_VDADISP	; DO THE SCROLLING
	LD	A,(TTY_ROWS)	; GET SCREEN ROW COUNT
	DEC	A		; A NOW HAS LAST ROW
	LD	(TTY_ROW),A	; SAVE IT
	JR	TTY_XY		; RESPOSITION CURSOR AND RETURN
;
TTY_XY:
	LD	DE,(TTY_POS)	; GET THE DESIRED CURSOR POSITION
	LD	B,BF_VDASCP	; SET FUNCTIONT TO SET CURSOR POSITION
	JP	EMU_VDADISP	; REPOSITION CURSOR
;
;
;
TTY_POS:
TTY_COL		.DB	0	; CURRENT COLUMN - 0 BASED
TTY_ROW		.DB	0	; CURRENT ROW - 0 BASED
;
TTY_DIM:
TTY_COLS	.DB	80	; NUMBER OF COLUMNS ON SCREEN
TTY_ROWS	.DB	24	; NUMBER OF ROWS ON SCREEN