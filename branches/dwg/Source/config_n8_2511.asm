;
;==================================================================================================
;   ROMWBW 2.X CONFIGURATION FOR N8 5/8/2012
;==================================================================================================
;
; BUILD CONFIGURATION OPTIONS
;
CPUFREQ		.EQU	20		; IN MHZ, USED TO COMPUTE DELAY FACTORS
;
PLATFORM	.EQU	PLT_N8		; PLT_N8VEM, PLT_ZETA, PLT_N8
;
DEFCON		.EQU	CIODEV_UART	; DEFAULT CONSOLE DEVICE (LOADER AND MONITOR): CIODEV_UART, CIODEV_VDU, DIODEV_PRPCON
ALTCON		.EQU	DEFCON		; ALT CONSOLE DEVICE (USED WHEN CONFIG JUMPER SHORTED)
DEFVDA		.EQU	VDADEV_N8V	; DEFAULT VDA (VDADEV_NONE, VDADEV_VDU, VDADEV_CVDU, VDADEV_7220, VDADEV_N8V)
DEFEMU		.EQU	EMUTYP_TTY	; DEFAULT EMULATION TYPE (EMUTYP_TTY, EMUTYP_ANSI, ...)
;
RAMSIZE		.EQU	512		; SIZE OF RAM IN KB, MUST MATCH YOUR HARDWARE!!!
CLRRAMDISK	.EQU	CLR_AUTO	; CLR_ALWAYS, CLR_NEVER, CLR_AUTO (CLEAR IF INVALID DIR AREA)
;
DSKMAP		.EQU	DM_RAM		; DM_ROM, DM_RAM, DM_FD, DM_IDE, DM_PPIDE, DM_SD, DM_PRPSD, DM_PPPSD
;
DSKYENABLE	.EQU	FALSE		; TRUE FOR DSKY SUPPORT (DO NOT COMBINE WITH PPIDE)
;
UARTENABLE	.EQU	TRUE		; TRUE FOR UART SUPPORT (ALMOST ALWAYS WANT THIS TO BE TRUE)
UARTFIFO	.EQU	TRUE		; TRUE ENABLES UART FIFO (16550 ASSUMED, N8VEM AND ZETA ONLY)
UARTAFC		.EQU	FALSE		; TRUE ENABLES AUTO FLOW CONTROL (YOUR TERMINAL/UART MUST SUPPORT RTS/CTS FLOW CONTROL!!!)
;
VDUENABLE	.EQU	FALSE		; TRUE FOR VDU BOARD SUPPORT
CVDUENABLE	.EQU	FALSE		; TRUE FOR CVDU BOARD SUPPORT
UPD7220ENABLE	.EQU	FALSE		; TRUE FOR uPD7220 BOARD SUPPORT
N8VENABLE	.EQU	TRUE		; TRUE FOR N8 (TMS9918) VIDEO/KBD SUPPORT
;
DEFIOBYTE	.EQU	$00		; DEFAULT INITIAL VALUE FOR CP/M IOBYTE, $00=TTY, $01=CRT (MUST HAVE CRT HARDWARE)
ALTIOBYTE	.EQU	DEFIOBYTE	; ALT INITIAL VALUE (USED WHEN CONFIG JUMPER SHORTED)
WRTCACHE	.EQU	TRUE		; ENABLE WRITE CACHING IN CBIOS (DE)BLOCKING ALGORITHM
DSKTRACE	.EQU	FALSE		; ENABLE TRACING OF CBIOS DISK FUNCTION CALLS
;
FDENABLE	.EQU	TRUE		; TRUE FOR FLOPPY SUPPORT
FDMODE		.EQU	FDMODE_N8	; FDMODE_DIO, FDMODE_ZETA, FDMODE_DIDE, FDMODE_N8, FDMODE_DIO3
FDTRACE		.EQU	1		; 0=SILENT, 1=FATAL ERRORS, 2=ALL ERRORS, 3=EVERYTHING (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIA		.EQU	FDM144		; FDM720, FDM144, FDM360, FDM120 (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIAALT	.EQU	FDM720		; ALTERNATE MEDIA TO TRY, SAME CHOICES AS ABOVE (ONLY RELEVANT IF FDMAUTO = TRUE)
FDMAUTO		.EQU	TRUE		; SELECT BETWEEN MEDIA OPTS ABOVE AUTOMATICALLY
;
IDEENABLE	.EQU	FALSE		; TRUE FOR IDE SUPPORT
IDEMODE		.EQU	IDEMODE_DIO	; IDEMODE_DIO, IDEMODE_DIDE
IDETRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
IDE8BIT		.EQU	FALSE		; USE IDE 8BIT TRANSFERS (PROBABLY ONLY WORKS FOR CF CARDS!)
IDECAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
;
PPIDEENABLE	.EQU	FALSE		; TRUE FOR PPIDE SUPPORT (DO NOT COMBINE WITH DSKYENABLE)
PPIDEMODE	.EQU	PPIDEMODE_STD	; PPIDEMODE_STD, PPIDEMODE_DIO3
PPIDETRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPIDEENABLE = TRUE)
PPIDE8BIT	.EQU	FALSE		; USE IDE 8BIT TRANSFERS (PROBABLY ONLY WORKS FOR CF CARDS!)
PPIDECAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
PPIDESLOW	.EQU	FALSE		; ADD DELAYS TO HELP PROBLEMATIC HARDWARE (TRY THIS IF PPIDE IS UNRELIABLE)
;
SDENABLE	.EQU	TRUE		; TRUE FOR SD SUPPORT
SDTRACE		.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
SDCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
SDCSIO		.EQU	FALSE		; TRUE IF USING THE CSIO PORT (N8 ONLY)
SDCSIOFAST	.EQU	FALSE		; TRUE IF USING THE LOOKUP TABLE RATHER THAN SHIFTS AND ROTATES (N8 ONLY)
PPISD		.EQU	FALSE		; TRUE IF USING PPISD MINI-BOARD (DO NOT COMBINE WITH PPIDE)
;
PRPENABLE	.EQU	FALSE		; TRUE FOR PROPIO SD SUPPORT (FOR N8VEM PROPIO ONLY!)
PRPSDENABLE	.EQU	TRUE		; TRUE FOR PROPIO SD SUPPORT (FOR N8VEM PROPIO ONLY!)
PRPSDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PRPSDENABLE = TRUE)
PRPSDCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
PRPCONENABLE	.EQU	TRUE		; TRUE FOR PROPIO CONSOLE SUPPORT (PS/2 KBD & VGA VIDEO)
;
PPPENABLE	.EQU	FALSE		; TRUE FOR PARPORTPROP SUPPORT
PPPSDENABLE	.EQU	TRUE		; TRUE FOR PROPIO SD SUPPORT (FOR N8VEM PROPIO ONLY!)
PPPSDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPPENABLE = TRUE)
PPPSDCAPACITY	.EQU	64		; CAPACITY OF PPP SD DEVICE (IN MB)
PPPCONENABLE	.EQU	TRUE		; TRUE FOR PROPIO CONSOLE SUPPORT (PS/2 KBD & VGA VIDEO)
;
HDSKENABLE	.EQU	FALSE		; TRUE FOR SIMH HDSK SUPPORT
HDSKTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
HDSKCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
;
PPKENABLE	.EQU	TRUE		; TRUE FOR PARALLEL PORT KEYBOARD
PPKTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPKENABLE = TRUE)
KBDENABLE	.EQU	FALSE		; TRUE FOR PS/2 KEYBOARD ON I8242
KBDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF KBDENABLE = TRUE)
;
TTYENABLE	.EQU	TRUE		; INCLUDE TTY EMULATION SUPPORT
ANSIENABLE	.EQU	TRUE		; INCLUDE ANSI EMULATION SUPPORT
;
BOOTTYPE	.EQU	BT_MENU		; BT_MENU (WAIT FOR KEYPRESS), BT_AUTO (BOOT_DEFAULT AFTER BOOT_TIMEOUT SECS)
BOOT_TIMEOUT	.EQU	20		; APPROX TIMEOUT IN SECONDS FOR AUTOBOOT, 0 FOR IMMEDIATE
BOOT_DEFAULT	.EQU	'R'		; SELECTION TO INVOKE AT TIMEOUT
;
BAUDRATE	.EQU	38400		; IN BPS: 1200, 9600, 38400, ..., 115200
TERMTYPE	.EQU	TERM_ANSI	; TERM_TTY=0, TERM_ANSI=1, TERM_WYSE=2
;
Z180_CLKDIV	.EQU	1		; 0=XTAL/2, 1=XTAL/1
Z180_MEMWAIT	.EQU	0		; MEMORY WAIT STATES TO INSERT (0-3)
Z180_IOWAIT	.EQU	3		; IO WAIT STATES TO INSERT (0-3)
Z180_CNTLB0	.EQU	20H		; SERIAL PORT 0 DIV, SEE Z180 CLOCKING DOCUMENT
Z180_CNTLB1	.EQU	20H		; SERIAL PORT 1 DIV, SEE Z180 CLOCKING DOCUMENT
