;
;==================================================================================================
;   MD DISK DRIVER (MEMORY DISK)
;==================================================================================================
;
; MD DEVICE CONFIGURATION
;
;
;       DISK DEVICE TYPE ID	MEDIA ID		ATTRIBUTE
;--------------------------------------------------------------------------------------------------
;	0x00 MEMORY DISK	0x02 RAM DRIVE		%00101000 HD STYLE, NON-REMOVABLE, TYPE-RAM
;	0x00 MEMORY DISK	0x01 ROM DRIVE		%00100000 HD STYLE, NON-REMOVABLE, TYPE-ROM
;	0x00 MEMORY DISK	0x01 ROM DRIVE		%00111000 HD STYLE, NON-REMOVABLE, TYPE-FLASH
;
MD_DEVCNT	.EQU	2		; NUMBER OF MD DEVICES SUPPORTED
MD_CFGSIZ	.EQU	8		; SIZE OF CFG TBL ENTRIES
;
MD_DEV		.EQU	0		; OFFSET OF DEVICE NUMBER (BYTE)
MD_STAT		.EQU	1		; OFFSET OF STATUS (BYTE)
MD_LBA		.EQU	2		; OFFSET OF LBA (DWORD)
MD_MID		.EQU	6		; OFFSET OF MEDIA ID (BYTE)
MD_ATTRIB	.EQU	7		; OFFSET OF ATTRIBUTE (BYTE)
;
MD_AROM		.EQU	%00100000	; ROM ATTRIBUTE
MD_ARAM		.EQU	%00101000	; RAM ATTRIBUTE
MD_AFSH		.EQU	%00111000	; FLASH ATTRIBUTE
;
; DEVICE CONFIG TABLE (RAM DEVICE FIRST TO MAKE IT ALWAYS FIRST DRIVE)
;
MD_CFGTBL:
	; DEVICE 1 (RAM)
	.DB	1			; DRIVER DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	MID_MDRAM		; DEVICE MEDIA ID
	.DB	MD_ARAM			; DEVICE ATTRIBUTE
	; DEVICE 0 (ROM)
	.DB	0			; DEVICE NUMBER
	.DB	0			; DEVICE STATUS
	.DW	0,0			; CURRENT LBA
	.DB	MID_MDROM		; DEVICE MEDIA ID
	.DB	MD_AROM			; DEVICE ATTRIBUTE
;
#IF ($ - MD_CFGTBL) != (MD_DEVCNT * MD_CFGSIZ)
	.ECHO	"*** INVALID MD CONFIG TABLE ***\n"
#ENDIF
;
	.DB	$FF			; END MARKER
;
;
;
MD_INIT:
	CALL	FF_INIT			; PROBE FLASH CAPABILITY

	CALL	NEWLINE			; FORMATTING
	PRTS("MD: UNITS=2 $")
	PRTS("ROMDISK=$")
	LD	HL,ROMSIZE - 128
	CALL	PRTDEC
	PRTS("KB RAMDISK=$")
	LD	HL,RAMSIZE - 256
	CALL	PRTDEC
	PRTS("KB$")
;
; SETUP THE DIO TABLE ENTRIES
;
	LD	A,(FF_RW)		; IF FLASH 
	OR	A			; FILESYSTEM 
	JR	NZ,MD_IN1		; CAPABLE, 
	LD	A,MD_AFSH		; UPDATE ROM DIO
	LD	(MD_CFGTBL + MD_CFGSIZ + MD_ATTRIB),A
MD_IN1:
	LD	BC,MD_FNTBL
	LD	DE,MD_CFGTBL
	PUSH	BC
	CALL	DIO_ADDENT		; ADD FIRST ENTRY
	POP	BC
	LD	DE,MD_CFGTBL + MD_CFGSIZ
	CALL	DIO_ADDENT		; ADD SECOND ENTRY

	XOR	A			; INIT SUCCEEDED
	RET				; RETURN
;
;
;
MD_FNTBL:
	.DW	MD_STATUS
	.DW	MD_RESET
	.DW	MD_SEEK
	.DW	MD_READ
	.DW	MD_WRITE
	.DW	MD_VERIFY
	.DW	MD_FORMAT
	.DW	MD_DEVICE
	.DW	MD_MEDIA
	.DW	MD_DEFMED
	.DW	MD_CAP
	.DW	MD_GEOM
#IF (($ - MD_FNTBL) != (DIO_FNCNT * 2))
	.ECHO	"*** INVALID MD FUNCTION TABLE ***\n"
#ENDIF
;
;
;
MD_VERIFY:
MD_FORMAT:
MD_DEFMED:
	CALL	SYSCHK			; INVALID SUB-FUNCTION
	LD	A,ERR_NOTIMPL
	OR	A
	RET
;
;
;
MD_STATUS:
;	XOR	A			; ALWAYS OK
;	RET
;
;
;
MD_RESET:
	XOR	A			; ALWAYS OK
	RET
;
;
;	
MD_CAP:					; ASSUMES THAT UNIT 1 IS RAM, UNIT 0 IS ROM
	LD	A,(IY+MD_DEV)		; GET DEVICE NUMBER
	OR	A			; SET FLAGS
	JR	Z,MD_CAP0		; UNIT 0
	DEC	A			; TRY UNIT 1
	JR	Z,MD_CAP1		; UNIT 1
	CALL	SYSCHK			; INVALID UNIT
	LD	A,ERR_NOUNIT
	OR	A
	RET
MD_CAP0:
	LD	A,(HCB + HCB_ROMBANKS)	; POINT TO ROM BANK COUNT
	LD	B,4			; SET # RESERVED ROM BANKS
	JR	MD_CAP2
MD_CAP1:
	LD	A,(HCB + HCB_RAMBANKS)	; POINT TO RAM BANK COUNT
	LD	B,8			; SET # RESERVED RAM BANKS
MD_CAP2:
	SUB	B			; SUBTRACT OUT RESERVED BANKS
	LD	H,A			; H := # BANKS
	LD	E,64			; # 512 BYTE BLOCKS / BANK
	CALL	MULT8			; HL := TOTAL # 512 BYTE BLOCKS
	LD	DE,0			; NEVER EXCEEDS 64K, ZERO HIGH WORD
	LD	BC,512			; 512 BYTE SECTOR
	XOR	A
	RET
;
;
;
MD_GEOM:
	; RAM/ROM DISKS ALLOW CHS STYLE ACCESS BY EMULATING
	; A DISK DEVICE WITH 1 HEAD AND 16 SECTORS / TRACK.
	CALL	MD_CAP			; HL := CAPACITY IN BLOCKS
	PUSH	BC			; SAVE SECTOR SIZE
	LD	D,1 | $80		; HEADS / CYL := 1 BY DEFINITION, SET LBA CAPABILITY BIT
	LD	E,16			; SECTORS / TRACK := 16 BY DEFINITION
	LD	B,4			; PREPARE TO DIVIDE BY 16
MD_GEOM1:
	SRL	H			; SHIFT H
	RR	L			; SHIFT L
	DJNZ	MD_GEOM1		; DO 4 BITS TO DIVIDE BY 16
	POP	BC			; RECOVER SECTOR SIZE
	XOR	A			; SIGNAL SUCCESS
	RET				; DONE
;
;
;
MD_DEVICE:
	LD	D,DIODEV_MD		; D := DEVICE TYPE - ALL ARE MEMORY DISKS
	LD	E,(IY+MD_DEV)		; GET DEVICE NUMBER
	LD	C,(IY+MD_ATTRIB)	; GET ATTRIBUTE
	LD	H,0			; H := 0, DRIVER HAS NO MODES
	LD	L,0			; L := 0, NO BASE I/O ADDRESS
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
MD_MEDIA:
	LD	E,(IY+MD_MID)		; GET MEDIA ID
	LD	D,0			; D:0=0 MEANS NO MEDIA CHANGE
	XOR	A			; SIGNAL SUCCESS
	RET
;
;
;
MD_SEEK:
	BIT	7,D			; CHECK FOR LBA FLAG
	CALL	Z,HB_CHS2LBA		; CLEAR MEANS CHS, CONVERT TO LBA
	RES	7,D			; CLEAR FLAG REGARDLESS (DOES NO HARM IF ALREADY LBA)
	LD	(IY+MD_LBA+0),L		; SAVE NEW LBA
	LD	(IY+MD_LBA+1),H		; ...
	LD	(IY+MD_LBA+2),E		; ...
	LD	(IY+MD_LBA+3),D		; ...
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
;
;
MD_READ:
	CALL	HB_DSKREAD		; HOOK HBIOS DISK READ SUPERVISOR
;
;	HL  POINTS TO HB_WRKBUF
;
	LD	A,(IY+MD_ATTRIB)	; GET ADR OF SECTOR READ FUNC
	LD	BC,MD_RDSECF		; 
	CP	MD_AFSH			; RAM / ROM = MD_RDSEC
	JR	Z,MD_RD1		; FLASH     = MD_RDSECF
	LD	BC,MD_RDSEC
MD_RD1:
	LD	(MD_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	JR	MD_RW			; CONTINUE TO GENERIC R/W ROUTINE
;
;
;
MD_WRITE:
	CALL	HB_DSKWRITE		; HOOK HBIOS DISK WRITE SUPERVISOR
;
	LD	A,(IY+MD_ATTRIB)	; GET ADR OF SECTOR WRITE FUNC
	LD	BC,MD_WRSECF		; 
	CP	MD_AFSH			; RAM / ROM = MD_WRSEC
	JR	Z,MD_WR1		; FLASH     = MD_WRSECF
	LD	BC,MD_WRSEC
MD_WR1:
	LD	(MD_RWFNADR),BC		; SAVE IT AS PENDING IO FUNC
	LD	A,(IY+MD_ATTRIB)	; IF THE DEVICES ATTRIBUTE
	CP	MD_AROM			; IS NOT ROM THEN WE CAN
	JR	NZ,MD_RW		; WRITE TO IT
	LD	E,0			; UNIT IS READ ONLY, ZERO SECTORS WRITTEN
	LD	A,ERR_READONLY		; SIGNAL ERROR
	OR	A			; SET FLAGS
	RET				; AND DONE
;
;
;
MD_RW:
	LD	(MD_DSKBUF),HL		; SAVE DISK BUFFER ADDRESS
	LD	A,E			; BLOCK COUNT TO A
	OR	A			; SET FLAGS
	RET	Z			; ZERO SECTOR I/O, RETURN W/ E=0 & A=0
	LD	B,A			; INIT SECTOR DOWNCOUNTER
	LD	C,0			; INIT SECTOR READ/WRITE COUNT
MD_RW1:
	PUSH	BC			; SAVE COUNTERS
	LD	HL,(MD_RWFNADR)		; GET PENDING IO FUNCTION ADDRESS
	CALL	JPHL			; ... AND CALL IT
	JR	NZ,MD_RW2		; IF ERROR, SKIP INCREMENT
	; INCREMENT LBA
	LD	A,MD_LBA		; LBA OFFSET IN CFG ENTRY
	CALL	LDHLIYA			; HL := IY + A, REG A TRASHED
	CALL	INC32HL			; INCREMENT THE VALUE
	; INCREMENT DMA
	LD	HL,MD_DSKBUF+1		; POINT TO MSB OF BUFFER ADR
	INC	(HL)			; BUMP DMA BY
	INC	(HL)			; ... 512 BYTES
	XOR	A			; SIGNAL SUCCESS
MD_RW2:
	POP	BC			; RECOVER COUNTERS
	JR	NZ,MD_RW3		; IF ERROR, BAIL OUT
	INC	C			; BUMP COUNT OF SECTORS READ
	DJNZ	MD_RW1			; LOOP AS NEEDED
MD_RW3:
	LD	E,C			; SECTOR READ COUNT TO E
	LD	HL,(MD_DSKBUF)		; CURRENT DMA TO HL
	OR	A			; SET FLAGS BASED ON RETURN CODE
	RET				; AND RETURN, A HAS RETURN CODE
;
; READ FLASH
;
MD_RDSECF:				; CALLED FROM MD_RW
	CALL	MD_IOSETUPF
	LD	A,(IY+MD_LBA+0)		; GET SECTOR WITHIN 4K BLOCK
	AND	%00000111		; AND CALCULATE OFFSET OFFSET
	ADD	A,A
	LD	D,A			; FROM THE START
	LD	E,0
;
	LD	HL,FF_BUFFER		; POINT TO THE SECTOR WE 
	ADD	HL,DE			; WANT TO COPY
	LD	DE,(MD_DSKBUF)
	LD	BC,512
	LDIR
;
	XOR	A
	RET
;
;
;
MD_IOSETUPF:
	PUSH	DE
	PUSH	HL
	PUSH	IY
	LD	L,(IY+MD_LBA+0)		; HL := LOW WORD OF LBA
	LD	H,(IY+MD_LBA+1)		
	INC	H			; SKIP FIRST 128MB (256 SECTORS)
;
	LD	A,L			; SAVE LBA 4K
	AND	%11111000		; BLOCK WE ARE
	LD	C,A			; GOING TO
	LD	B,H			; ACCESS
;
	LD	D,0			; CONVERT LBA
	LD	E,H			; TO ADDRESS
	LD	H,L			; MULTIPLY BY 512
	LD	L,D			; DE:HL = HLX512
	SLA	H
	RL	E
	RL	D
;
	PUSH	HL			; IS THE SECTOR
	LD	HL,MD_LBA4K		; WE WANT TO
	LD	A,C			; READ ALREADY
	CP	(HL)			; IN THE 4K 
	JR	NZ,MD_SECR		; BLOCK WE HAVE
	INC	HL			; IN THE BUFFER
	LD	A,B
	CP	(HL)
	JR	Z,MD_SECM
;
MD_SECR:
	POP	HL			; DESIRED SECTOR
					; IS NOT IN BUFFER
	LD	(MD_LBA4K),BC		; WE WILL READ IN
					; A NEW 4K SECTOR.
					; SAVE THE 4K LBA
					; FOR FUTURE CHECKS
;
	LD	IX,FF_BUFFER		; SET DESTINATION ADDRESS
	CALL	FF_RINIT		; READ 4K SECTOR
;
	PUSH	HL
;
MD_SECM:POP	HL
	POP	IY
	POP	HL
	POP	DE
	RET
;
MD_LBA4K	.DW	$FFFF		; LBA OF CURRENT SECTOR
;
;
; READ RAM / ROM 
;
MD_RDSEC:
	CALL	MD_IOSETUP		; SETUP FOR MEMORY COPY
#IF (MDTRACE >= 2)
	LD	(MD_SRC),HL
	LD	(MD_DST),DE
	LD	(MD_LEN),BC
#ENDIF
	PUSH	BC
	LD	C,A			; SOURCE BANK
	LD	B,BID_BIOS		; DESTINATION BANK IS RAM BANK 1 (HBIOS)
#IF (MDTRACE >= 2)
	LD	(MD_SRCBNK),BC
	CALL	MD_PRT
#ENDIF
	LD	A,C			; GET SOURCE BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,B			; GET DESTINATION BANK
	LD	(HB_DSTBNK),A		; SET IT
	POP	BC
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; DO THE INTERBANK COPY
#IF (INTMODE == 1)
	EI
#ENDIF
	XOR	A
	RET
;
; WRITE FLASH
;
MD_WRSECF:
	CALL	MD_WRSEC
	PRTS("wf$");
	RET
;
; WRITE RAM
;
MD_WRSEC:
	CALL	MD_IOSETUP		; SETUP FOR MEMORY COPY
	EX	DE,HL			; SWAP SRC/DEST FOR WRITE
#IF (MDTRACE >= 2)
	LD	(MD_SRC),HL
	LD	(MD_DST),DE
	LD	(MD_LEN),BC
#ENDIF
	PUSH	BC
	LD	C,BID_BIOS		; SOURCE BANK IS RAM BANK 1 (HBIOS)
	LD	B,A			; DESTINATION BANK
#IF (MDTRACE >= 2)
	LD	(MD_SRCBNK),BC
	CALL	MD_PRT
#ENDIF
	LD	A,C			; GET SOURCE BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,B			; GET DESTINATION BANK
	LD	(HB_DSTBNK),A		; SET IT
	POP	BC
#IF (INTMODE == 1)
	DI
#ENDIF
	CALL	HB_BNKCPY		; DO THE INTERBANK COPY
#IF (INTMODE == 1)
	EI
#ENDIF
	XOR	A
	RET
;
; SETUP FOR MEMORY COPY
;   A=BANK SELECT
;   BC=COPY SIZE
;   DE=DESTINATION
;   HL=SOURCE
;
; ASSUMES A "READ" OPERATION.  HL AND DE CAN BE SWAPPED
; AFTERWARDS TO ACHIEVE A WRITE OPERATION
;
; ON INPUT, WE HAVE LBA ADDRESSING IN HSTLBAHI:HSTLBALO
; BUT WE NEVER HAVE MORE THAN $FFFF BLOCKS IN A RAM/ROM DISK,
; SO THE HIGH WORD (HSTLBAHI) IS IGNORED
;
; EACH RAM/ROM BANK IS 32K BY DEFINITION AND EACH SECTOR IS 512
; BYTES BY DEFINITION.	SO, EACH RAM/ROM BANK CONTAINS 64 SECTORS
; (32,768 / 512 = 64).	THEREFORE, YOU CAN THINK OF LBA AS
; 00000BBB:BBOOOOOO IS WHERE THE 'B' BITS REPRESENT THE BANK NUMBER
; AND THE 'O' BITS REPRESENT THE SECTOR NUMBER WITHIN THE BANK.
;
; TO EXTRACT THE BANK NUMBER, WE CAN LEFT SHIFT TWICE TO GIVE US:
; 000BBBBB:OOOOOOOO.  FROM THIS WE CAN EXTRACT THE MSB
; TO USE AS THE BANK NUMBER.  NOTE THAT THE "RAW" BANK NUMBER MUST THEN
; BE OFFSET TO THE START OF THE ROM/RAM BANKS.
; ALSO NOTE THAT THE HIGH BIT OF THE BANK NUMBER REPRESENTS "RAM" SO THIS
; BIT MUST ALSO BE SET ACCORDING TO THE UNIT BEING ADDRESSED.
;
; TO GET THE BYTE OFFSET, WE THEN RIGHT SHIFT THE LSB BY 1 TO GIVE US:
; 0OOOOOOO AND EXTRACT THE LSB TO REPRESENT THE MSB OF
; THE BYTE OFFSET.  THE LSB OF THE BYTE OFFSET IS ALWAYS 0 SINCE WE ARE
; DEALING WITH 512 BYTE BOUNDARIES.
;
MD_IOSETUP:
	LD	L,(IY+MD_LBA+0)		; HL := LOW WORD OF LBA
	LD	H,(IY+MD_LBA+1)		; ...
	; ALIGN BITS TO EXTRACT BANK NUMBER FROM H
	SLA	L			; LEFT SHIFT ONE BIT
	RL	H			;   FULL WORD
	SLA	L			; LEFT SHIFT ONE BIT
	RL	H			;   FULL WORD
	LD	C,H			; BANK NUMBER FROM H TO C
	; GET BANK NUM TO A AND SET FLAG Z=ROM, NZ=RAM
	LD	A,(IY+MD_DEV)		; DEVICE TO A
	AND	$01			; ISOLATE LOW BIT, SET ZF
	LD	A,C			; BANK VALUE INTO A
	PUSH	AF			; SAVE IT FOR NOW
	; ADJUST L TO HAVE MSB OF OFFSET
	SRL	L			; ADJUST L TO BE MSB OF BYTE OFFSET
	LD	H,L			; MOVE MSB TO H WHERE IT BELONGS
	LD	L,0			;   AND ZERO L SO HL IS NOW BYTE OFFSET
	; LOAD DESTINATION AND COUNT
	LD	DE,(MD_DSKBUF)		; DMA ADDRESS IS DESTINATION
	LD	BC,512			; ALWAYS COPY ONE SECTOR
	; FINISH UP
	POP	AF			; GET BANK AND FLAGS BACK
	JR	Z,MD_IOSETUP2		; DO ROM DRIVE, ELSE FALL THRU FOR RAM DRIVE
;
MD_IOSETUP1:	; RAM
	ADD	A,BID_RAMD0
	RET
;
MD_IOSETUP2:	; ROM
	ADD	A,BID_ROMD0
	RET
;
;
;
#IF (MDTRACE >= 2)
MD_PRT:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL

	CALL	NEWLINE

	LD	DE,MDSTR_PREFIX
	CALL	WRITESTR

	CALL	PC_SPACE
	LD	DE,MDSTR_SRC
	CALL	WRITESTR
	LD	A,(MD_SRCBNK)
	CALL	PRTHEXBYTE
	CALL	PC_COLON
	LD	BC,(MD_SRC)
	CALL	PRTHEXWORD

	CALL	PC_SPACE
	LD	DE,MDSTR_DST
	CALL	WRITESTR
	LD	A,(MD_DSTBNK)
	CALL	PRTHEXBYTE
	CALL	PC_COLON
	LD	BC,(MD_DST)
	CALL	PRTHEXWORD

	CALL	PC_SPACE
	LD	DE,MDSTR_LEN
	CALL	WRITESTR
	LD	BC,(MD_LEN)
	CALL	PRTHEXWORD

	POP	HL
	POP	DE
	POP	BC
	POP	AF

	RET
#ENDIF
;
;
;
;==================================================================================================
;   FLASH DRIVER FOR FLASH & EEPROM PROGRAMMING 
;
;	26 SEP 2020 - CHIP IDENTIFICATION IMPLEMENTED -- PHIL SUMMERS
;		    - CHIP ERASE IMPLEMENTED
;	23 OCT 2020 - SECTOR ERASE IMPLEMENTED
;	01 NOV 2020 - WRITE SECTOR IMPLEMENTED
;	04 DEC 2020 - READ SECTOR IMPLEMENTED
;==================================================================================================
;
;	UPPER RAM BANK IS ALWAYS AVAILABLE REGARDLESS OF MEMORY BANK SELECTION. 
;	HBX_BNKSEL AND HB_CURBNK ARE ALWAYS AVAILABLE IN UPPER MEMORY.
;
;	THE STACK IS IN UPPER MEMORY DURING BIOS INITIALIZATION BUT IS IN LOWER
;	MEMORY DURING HBIOS CALLS.
;
;	TO ACCESS THE FLASH CHIP FEATURES, CODE IS COPIED TO THE UPPER RAM BANK 
;	AND THE FLASH CHIP IS SWITCHED INTO THE LOWER BANK.
;
;	INSPIRED BY WILL SOWERBUTTS FLASH4 UTILITY - https://github.com/willsowerbutts/flash4/
;
;==================================================================================================
;
FF_DBG:	.EQU	0			; DEBUG
;
FF_RW		.DB	00h		; READ WRITE FLAG
FF_TGT		.EQU	0BFB7H		; TARGET CHIP FOR R/W FILESYSTEM
;
;======================================================================
; BIOS FLASH INITIALIZATION
;
; IDENTIFY AND DISPLAY FLASH CHIPS IN SYSTEM.
; USES MEMORY SIZE DEFINED BY BUILD CONFIGURATION.
;======================================================================
;
;
FF_INIT:
;	CALL	NEWLINE			; DISLAY NUMBER
;	PRTS("FF: UNITS=$")		; OF UNITS 
;	LD	A,+(ROMSIZE/512)	; CONFIGURED FOR.
;	CALL	PRTDECB
;
	LD	B,A			; NUMBER OF DEVICES TO PROBE
	LD	C,$00			; START ADDRESS IS 0000:0000 IN DE:HL
FF_PROBE:
	LD	D,$00			; SET ADDRESS IN DE:HL
	LD	E,C			;
	LD	H,D			; WE INCREASE E BY $08
	LD	L,D			; ON EACH CYCLE THROUGH
;	 
	PUSH	BC
;	CALL	PC_SPACE
;	LD	A,+(ROMSIZE/512)+1
;	SUB	B			; PRINT
;	CALL	PRTDECB			; DEVICE 
;	LD	A,'='			; NUMBER
;	CALL	COUT
	CALL	FF_IINIT		; GET ID AT THIS ADDRESS
;
	PUSH	HL
	PUSH	DE
	LD	H,FF_TGT&$FF		; IF WE MATCH WITH
	LD	L,FF_TGT/$FF
	CCF				; A NON 39SF040
	SBC	HL,DE			; CHIP SET THE
	LD	A,(FF_RW)		; R/W FLAG TO R/O
	OR	H
	OR	L
	LD	(FF_RW),A		; A NON ZERO VALUE
	POP	DE			; MEANS WE CAN'T
	POP	HL			; ENABLE FLASH WRITING
;
;	CALL	FF_LAND			; LOOKUP AND DISPLAY
	POP	BC
;
	LD	A,C			; UPDATE ADDRESS
	ADD	A,$08			; TO NEXT DEVICE
	LD	C,A
;
	DJNZ	FF_PROBE		; ALWAYS AT LEAST ONE DEVICE
;
;	LD	A,(FF_RW)
;	OR	A
;	JR	NZ,FF_PR1
;	CALL PRTSTRD
;	.TEXT " FLASH FILESYSTEM ENABLED$"
;FF_PR1:
;
	XOR	A			; INIT SUCCEEDED
	RET
;
;======================================================================
; LOOKUP AND DISPLAY CHIP
;
; ON ENTRY DE CONTAINS CHIP ID
; ON EXIT  A  CONTAINS STATUS 0=SUCCESS, NZ=NOT IDENTIFIED
;======================================================================
;
FF_LAND:
;
#IF (FF_DBG==1)
	PRTS(" ID:$")
	LD	H,E
	LD	L,D
	CALL	PRTHEXWORDHL		; DISPLAY FLASH ID
	CALL	PC_SPACE
#ENDIF
;
	LD	HL,FF_TABLE		; SEARCH THROUGH THE FLASH
	LD	BC,FF_T_CNT		; TABLE TO FIND A MATCH
FF_NXT1:LD	A,(HL)
	CP	D
	JR	NZ,FF_NXT0		; FIRST BYTE DOES NOT MATCH
;
	INC	HL		
	LD	A,(HL)
	CP	E
	DEC	HL
	JR	NZ,FF_NXT0		; SECOND BYTE DOES NOT MATCH
;
	INC	HL
	INC	HL
	JR	FF_NXT2			; MATCH SO EXIT
;
FF_NXT0:PUSH	BC			; WE DIDN'T MATCH SO POINT
	LD	BC,FF_T_SZ		; TO THE NEXT TABLE ENTRY
	ADD	HL,BC
	POP	BC
;
	LD	A,B			; CHECK IF WE REACHED THE
	OR	C			; END OF THE TABLE
	DEC	BC
	JR	NZ,FF_NXT1		; NOT AT END YET
;
	LD	HL,FF_UNKNOWN		; WE REACHED THE END WITHOUT A MATCH
;
FF_NXT2:CALL	PRTSTR			; AFTER SEARCH DISPLAY THE RESULT
	RET
;======================================================================
;COMMON FUNCTION CALL
;
;======================================================================
;
FF_FNCALL:				; USING HBX_BUF FOR CODE AREA
	CALL	FF_CALCA		; GET BANK AND SECTOR DATA IN IY
;
	POP	HL			; GET ROUTINE TO CALL
;
	LD	DE,HBX_BUF		; PUT EXECUTE / START ADDRESS IN DE
	LD	BC,HBX_BUFSIZ		; CODE SIZE REQUIRED
;
;	PUSH	DE			; SAVE THE EXECUTE ADDRESS
					; COPY OUR RELOCATABLE
	LDIR				; CODE TO THE BUFFER
;	POP	HL			; CALL OUR RELOCATABLE CODE

	PUSH	IY			; PUT BANK AND SECTOR
	POP	BC			; DATA IN BC
;
#IF (FF_DBG==1)
	CALL	PRTHEXWORD
#ENDIF
;
	HB_DI
	CALL	HBX_BUF			; EXECUTE RELOCATED CODE
	HB_EI
;
#IF (FF_DBG==1)
	CALL	PC_SPACE
	CALL	PRTHEXWORD
	CALL	PC_SPACE
	EX	DE,HL
	CALL	PRTHEXWORDHL
	CALL	PC_SPACE
	EX	DE,HL
#ENDIF
;
	LD	A,C			; RETURN WITH STATUS IN A
;
	RET
;
;======================================================================
; IDENTIFY FLASH CHIP. 
;  CALCULATE BANK AND ADDRESS DATA FROM ENTRY ADDRESS
;  CREATE A CODE BUFFER IN HIGH MEMORY AREA
;  COPY FLASH CODE TO CODE BUFFER
;  CALL RELOCATED FLASH IDENTITY CODE
;  RESTORE STACK
;  RETURN WITH ID CODE.
;
; ON ENTRY DE:HL POINTS TO AN ADDRESS WITH THE ADDRESS RANGE OF THE
;                CHIP TO BE IDENTIFIED.
; ON EXIT  DE CONTAINS THE CHIP ID BYTES.
;          NO STATUS IS RETURNED               
;======================================================================
;
FF_IINIT:
	PUSH	HL			; SAVE ADDRESS INFO
	LD	HL,FF_IDENT		; PUT ROUTINE TO CALL
	EX	(SP),HL			; ON THE STACK
	JP	FF_FNCALL		; EXECUTE
;
;======================================================================
; FLASH IDENTIFY
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  ISSUE ID COMMAND
;  READ IN ID WORD
;  ISSUE ID EXIT COMMAND
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          A  CONTAINS CURRENT BANK 
; ON EXIT  DE CONTAINS ID WORD
;          NO STATUS IS RETURNED 
;======================================================================
;
FF_IDENT:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	PUSH	AF			; SAVE CURRENT BANK
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
;
	LD	HL,$5555		; LD	A,$AA			; COMMAND
	LD	(HL),$AA		; LD	($5555),A		; SETUP
	LD	A,H			; LD	A,$55
	LD	($2AAA),A		; LD	($2AAA),A
	LD	(HL),$90		; LD	A,$90
;					; LD	($5555),A
	LD	DE,($0000)						; READ ID
;
	LD	A,$F0			; 				; EXIT 
	LD	(HL),A			; LD	($5555),A		; COMMAND
;
	POP	AF			; RETURN TO ORIGINAL BANK
	CALL	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;
	RET
;
FF_I_SZ	.EQU	$-FF_IDENT		; SIZE OF RELOCATABLE CODE BUFFER REQUIRED
;
;======================================================================
; CALCULATE BANK AND ADDRESS DATA FROM MEMORY ADDRESS
;
; ON ENTRY DE:HL CONTAINS 32 BIT MEMORY ADDRESS.
; ON EXIT  I,B   CONTAINS BANK SELECT BYTE
;          Y,C   CONTAINS HIGH BYTE OF SECTOR ADDRESS
;          A     CONTAINS CURRENT BANK HB_CURBNK
;
; DDDDDDDDEEEEEEEE HHHHHHHHLLLLLLLL
; 3322222222221111 1111110000000000
; 1098765432109876 5432109876543210
; XXXXXXXXXXXXSSSS SSSSXXXXXXXXXXXX < S = SECTOR
; XXXXXXXXXXXXBBBB BXXXXXXXXXXXXXXX < B = BANK
;======================================================================
;
FF_CALCA:
;
#IF (FF_DBG==1)
	CALL	PC_SPACE	; DISPLAY SECTOR
	CALL	PRTHEX32	; SECTOR ADDRESS 
	CALL	PC_SPACE	; IN DE:HL
#ENDIF
;
	LD	A,E		; BOTTOM PORTION OF SECTOR
	AND	$0F		; ADDRESS THAT GETS WRITTEN
	RLC	H		; WITH ERASE COMMAND BYTE
	RLA			; A15 GETS DROPPED OFF AND
	LD	B,A		; ADDED TO BANK SELECT
;
	LD	A,H		; TOP SECTION OF SECTOR
	RRA			; ADDRESS THAT GETS WRITTEN
	AND	$70		; TO BANK SELECT PORT
	LD	C,A
;
	PUSH	BC
	POP	IY
;
#IF (FF_DBG==1)
	CALL	PRTHEXWORD	; DISPLAY BANK AND
	CALL	PC_SPACE	; SECTOR RESULT
#ENDIF
;
	LD	A,(HB_CURBNK)	; WE ARE STARTING IN HB_CURBNK
;
	RET
;
;======================================================================
; ERASE FLASH SECTOR
;
; ON ENTRY DE:HL CONTAINS 32 BIT MEMORY ADDRESS.
;  CALCULATE BANK AND ADDRESS DATA FROM ENTRY ADDRESS
;  CREATE A CODE BUFFER IN HIGH MEMORY AREA
;  COPY FLASH CODE TO CODE BUFFER
;  CALL RELOCATED FLASH ERASE CODE
;  RESTORE STACK
;  RETURN WITH STATUS CODE.
;
; ON ENTRY DE:HL POINTS TO AN ADDRESS IDENTIFYING THE CHIP
; ON EXIT  A     RETURNS STATUS FLASH 0=SUCCESS FF=FAIL
;======================================================================
;
FF_SINIT:
	PUSH	HL			; SAVE ADDRESS INFO
	LD	HL,FF_SERASE		; PUT ROUTINE TO CALL
	EX	(SP),HL			; ON THE STACK
	JP	FF_FNCALL		; EXECUTE
;
;======================================================================
; ERASE FLASH SECTOR. 
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  ISSUE ERASE SECTOR COMMAND
;  POLL TOGGLE BIT FOR COMPLETION STATUS.
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          A  CONTAINS CURRENT BANK 
; ON EXIT  A  RETURNS STATUS FLASH 0=SUCCESS FF=FAIL
;======================================================================
;
FF_SERASE:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	PUSH	AF			; SAVE CURRENT BANK
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
					;
	LD	HL,$5555		; LD	A,$AA			; COMMAND
	LD	A,L			; LD	($5555),A		; SETUP	
	LD	(HL),$AA		; LD	A,$55
	LD	($2AAA),A		; LD	($2AAA),A
	LD	(HL),$80		; LD	A,$80
	LD	(HL),$AA		; LD	($5555),A
	LD	($2AAA),A		; LD	A,$AA
					; LD	($5555),A
					; LD	A,$55
					; LD	($2AAA),A

	LD	H,C			; SECTOR 
	LD	L,$00			; ADDRESS
;
	LD	A,$30			; SECTOR ERASE
	LD	(HL),A			; COMMAND
;
;	LD	DE,$0000		; DEBUG COUNT
;
	LD	A,(HL)			; DO TWO SUCCESSIVE READS
FF_WT4:	LD	C,(HL)			; FROM THE SAME FLASH ADDRESS.
	XOR	C			; IF THE SAME ON BOTH READS
	BIT	6,A			; THEN ERASE IS COMPLETE SO EXIT.
;	INC	DE			; 
	JR	Z,FF_WT5		; BIT 6 = 0 IF SAME ON SUCCESSIVE READS = COMPLETE
					; BIT 6 = 1 IF DIFF ON SUCCESSIVE READS = INCOMPLETE
;
	LD	A,C			; OPERATION IS NOT COMPLETE. CHECK TIMEOUT BIT (BIT 5).
	BIT	5,C			; IF NO TIMEOUT YET THEN LOOP BACK AND KEEP CHECKING TOGGLE STATUS
	JR	Z,FF_WT4		; IF BIT 5=0 THEN RETRY; NZ TRUE IF BIT 5=1
;
	LD	A,(HL)			; WE GOT A TIMOUT. RECHECK TOGGLE BIT IN CASE WE DID COMPLETE 
	XOR	(HL)			; THE OPERATION. DO TWO SUCCESSIVE READS. ARE THEY THE SAME?
	BIT	6,A			; IF THEY ARE THEN OPERATION WAS COMPLETED					
	JR	Z,FF_WT5		; OTHERWISE ERASE OPERATION FAILED OR TIMED OUT.
;
	LD	(HL),$F0		; WRITE DEVICE RESET
	LD	C,$FF			; SET FAIL STATUS
	JR	FF_WT6
;
FF_WT5:	LD	C,0			; SET SUCCESS STATUS
FF_WT6:	POP	AF			; RETURN TO ORIGINAL BANK
	CALL	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;
	RET
;
FF_S_SZ	.EQU	$-FF_SERASE		; SIZE OF RELOCATABLE CODE BUFFER REQUIRED
;
;======================================================================
; READ FLASH SECTOR OF 4096 BYTES
;
; SET ADDRESS TO START OF SECTOR
; CALCULATE BANK AND ADDRESS DATA FROM SECTOR START ADDRESS
;  CREATE A CODE BUFFER IN HIGH MEMORY AREA
;  COPY FLASH CODE TO CODE BUFFER
;  CALL RELOCATED FLASH READ SECTOR CODE
;  RESTORE STACK
;
; ON ENTRY DE:HL POINTS TO A 32 BIT MEMORY ADDRESS.
;          IX    POINTS TO WHERE TO SAVE DATA
;======================================================================
;
FF_RINIT:
	LD	L,0			; CHANGE ADDRESS
	LD	A,H			; TO SECTOR BOUNDARY
	AND	$F0			; BY MASKING OFF
	LD	H,A			; LOWER 12 BITS
;
	PUSH	HL			; SAVE ADDRESS INFO
	LD	HL,FF_SREAD		; PUT ROUTINE TO CALL
	EX	(SP),HL			; ON THE STACK
	JP	FF_FNCALL		; EXECUTE
;
	RET
;======================================================================
; FLASH READ SECTOR. 
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  READ SECTOR OF 4096 BYTES, BYTE AT A TIME
;  SELECT SOURCE BANK,  READ DATA,
;	   SELECT DESTINATION BANK, WRITE DATA
;          DESTINATION BANK IS ALWAYS CURRENT BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          IX POINTS TO DATA TO BE WRITTEN
;          A  CONTAINS CURRENT BANK 
; ON EXIT  NO STATUS RETURNED
;======================================================================
;
FF_SREAD:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	LD	H,C			; SECTOR
	LD	L,$00			; ADDRESS
	LD	D,L			; INITIALIZE 
	LD	E,L			; BYTE COUNT
;
	LD	(FF_RST),SP					; SAVE STACK
	LD	SP,HBX_BUF + (FF_RD1-FF_SREAD)			; SETUP TEMP STACK
;
	PUSH	AF			; SAVE CURRENT BANK
;
FF_RD1:	
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO READ
	LD	C,(HL)			; READ BYTE
;
	POP	AF
	PUSH	AF			; SELECT BANK
	CALL	HBX_BNKSEL		; TO WRITE
	LD	(IX+0),C		; WRITE BYTE
;
	INC	HL			; NEXT SOURCE LOCATION
	INC	IX			; NEXT DESTINATION LOCATION
;
	INC	DE			; CONTINUE READING UNTIL
	BIT	4,D			; WE HAVE DONE ONE SECTOR
	JR	Z,FF_RD1

	POP	AF			; RETURN TO ORIGINAL BANK
	CALL	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;	LD	C,D			; RETURN STATUS
	LD	SP,(FF_RST)		; RESTORE STACK
;
	RET
FF_RST	.DW	0			; SAVE STACK
;
FF_R_SZ	.EQU	$-FF_SREAD		; SIZE OF RELOCATABLE CODE BUFFER REQUIRED
;
;======================================================================
; WRITE FLASH SECTOR OF 4096 BYTES
;
; SET ADDRESS TO START OF SECTOR
; CALCULATE BANK AND ADDRESS DATA FROM SECTOR START ADDRESS
;  CREATE A CODE BUFFER IN HIGH MEMORY AREA
;  COPY FLASH CODE TO CODE BUFFER
;  CALL RELOCATED FLASH WRITE SECTOR CODE
;  RESTORE STACK
;
; ON ENTRY DE:HL POINTS TO A 32 BIT MEMORY ADDRESS.
;          IX    POINTS TO DATA TO BE WRITTEN
;======================================================================
;
FF_WINIT:
	LD	L,0			; CHANGE ADDRESS
	LD	A,H			; TO SECTOR BOUNDARY
	AND	$F0			; BY MASKING OFF
	LD	H,A			; LOWER 12 BITS
;
	PUSH	HL			; SAVE ADDRESS INFO
	LD	HL,FF_SWRITE		; PUT ROUTINE TO CALL
	EX	(SP),HL			; ON THE STACK
	JP	FF_FNCALL		; EXECUTE
;
;======================================================================
; FLASH WRITE SECTOR. 
;
;  SELECT THE APPROPRIATE BANK / ADDRESS
;  WRITE 1 SECTOR OF 4096 BYTES, BYTE AT A TIME
;   ISSUE WRITE BYTE COMMAND AND WRITE THE DATA BYTE
;   POLL TOGGLE BIT FOR COMPLETION STATUS.
;  SELECT ORIGINAL BANK
;
; ON ENTRY BC CONTAINS BANK AND SECTOR DATA
;          IX POINTS TO DATA TO BE WRITTEN
;          A  CONTAINS CURRENT BANK 
; ON EXIT  A  RETURNS STATUS FLASH 0=SUCCESS FF=FAIL
;======================================================================
;
FF_SWRITE:				; THIS CODE GETS RELOCATED TO HIGH MEMORY
;
	PUSH	AF			; SAVE CURRENT BANK
;
	LD	H,C			; SECTOR
	LD	L,$00			; ADDRESS
	LD	D,L			; INITIALIZE 
	LD	E,L			; BYTE COUNT
;
FF_WR1:
	POP	AF			; SELECT BANK
	PUSH	AF			; TO READ
	CALL	HBX_BNKSEL
;
	LD	C,(IX+0)		; READ IN BYTE
;
	LD	A,B			; SELECT BANK
	CALL	HBX_BNKSEL		; TO PROGRAM
;
	LD	A,$AA			; COMMAND
	LD	($5555),A		; SETUP
	LD	A,$55
	LD	($2AAA),A
;
	LD	A,$A0			; WRITE
	LD	($5555),A		; COMMAND
;
	LD	(HL),C			; WRITE OUT BYTE
;
;					; DO TWO SUCCESSIVE READS 
	LD	A,(HL)			; FROM THE SAME FLASH ADDRESS. 
FF_WT7:	LD	C,(HL)			; IF TOGGLE BIT (BIT 6) 
	XOR	C			; IS THE SAME ON BOTH READS
	BIT	6,A			; THEN ERASE IS COMPLETE SO EXIT.
	JR	NZ,FF_WT7		; Z TRUE IF BIT 6=0 I.E. "NO TOGGLE" WAS DETECTED. 
;
	INC	HL			; NEXT DESTINATION LOCATION
	INC	IX			; NEXT SOURCE LOCATION
;
	INC	DE			; CONTINUE WRITING UNTIL
	BIT	4,D			; WE HAVE DONE ONE SECTOR
	JR	Z,FF_WR1
;
	POP	AF			; RETURN TO ORIGINAL BANK
	CALL	HBX_BNKSEL		; WHICH IS OUR RAM BIOS COPY
;
	RET
;
FF_W_SZ	.EQU	$-FF_SWRITE		; SIZE OF RELOCATABLE CODE BUFFER REQUIRED
;
;======================================================================
;
; FLASH CHIP LIST
;
;======================================================================
;
#DEFINE	FF_CHIP(FFROMID,FFROMNM)	\
#DEFCONT ;				\
#DEFCONT	.DW	FFROMID		\
#DEFCONT	.DB	FFROMNM		\
#DEFCONT ;
;
FF_TABLE:
FF_CHIP(00120H,"29F010$    ")
FF_CHIP(001A4H,"29F040$    ")
FF_CHIP(01F04H,"AT49F001NT$")
FF_CHIP(01F05H,"AT49F001N$ ")
FF_CHIP(01F07H,"AT49F002N$ ")
FF_CHIP(01F08H,"AT49F002NT$")
FF_CHIP(01F13H,"AT49F040$  ")
FF_CHIP(01F5DH,"AT29C512$  ")
FF_CHIP(01FA4H,"AT29C040$  ")
FF_CHIP(01FD5H,"AT29C010$  ")
FF_CHIP(01FDAH,"AT29C020$  ")
FF_CHIP(02020H,"M29F010$   ")
FF_CHIP(020E2H,"M29F040$   ")
FF_CHIP(0BFB5H,"39F010$    ")
FF_CHIP(0BFB6H,"39F020$    ")
FF_CHIP(0BFB7H,"39F040$    ")
FF_CHIP(0C2A4H,"MX29F040$  ")
;
FF_T_CNT	.EQU	17
FF_T_SZ		.EQU	($-FF_TABLE) / FF_T_CNT
FF_UNKNOWN	.DB	"UNKNOWN$"
FF_STACK:	.DW	0
;
;======================================================================
;
; 4K FLASH SECTOR BUFFER
;
;======================================================================
;
FF_BUFFER	.FILL	4096,$FF
;
;======================================================================
;
; RELOCATABLE CODE SPACE REQUIREMENTS CHECK
;
;======================================================================
;
FF_CSIZE	.EQU	0
;
#IF (FF_W_SZ>FF_CSIZE)
FF_CSIZE	.SET	FF_W_SZ
#ENDIF
#IF (FF_S_SZ>FF_CSIZE)
FF_CSIZE	.SET	FF_S_SZ
#ENDIF
#IF (FF_I_SZ>FF_CSIZE)
FF_CSIZE	.SET	FF_I_SZ
#ENDIF
#IF (FF_R_SZ>FF_CSIZE)
FF_CSIZE	.SET	FF_R_SZ
#ENDIF
;
		.ECHO	"FF requires "
		.ECHO	FF_CSIZE
		.ECHO	" bytes high memory space.\n"

MD_RWFNADR	.DW	0
;
MD_DSKBUF	.DW	0
;
MD_SRCBNK	.DB	0
MD_DSTBNK	.DB	0
MD_SRC		.DW	0
MD_DST		.DW	0
MD_LEN		.DW	0
;
MDSTR_PREFIX	.TEXT	"MD:$"
MDSTR_SRC	.TEXT	"SRC=$"
MDSTR_DST	.TEXT	"DEST=$"
MDSTR_LEN	.TEXT	"LEN=$"