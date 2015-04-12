;
;==================================================================================================
;   ROMWBW 2.X CONFIGURATION FOR N8 2312
;==================================================================================================
;
; BUILD CONFIGURATION OPTIONS
;
CPUOSC		.EQU	18432		; CPU OSC FREQ IN KHZ
;
BOOTCON		.EQU	CIODEV_ASCI	; CONSOLE DEVICE FOR BOOT MESSAGES (MUST BE PRIMARY SERIAL PORT FOR PLATFORM)
DEFCON		.EQU	CIODEV_ASCI	; DEFAULT CONSOLE DEVICE (LOADER AND MONITOR): CIODEV_UART, CIODEV_CRT, CIODEV_PRPCON, CIODEV_PPPCON
ALTCON		.EQU	CIODEV_PRPCON	; ALT CONSOLE DEVICE (USED WHEN CONFIG JUMPER SHORTED)
CONBAUD		.EQU	38400		; BAUDRATE FOR CONSOLE DURING HARDWARE INIT
DEFVDA		.EQU	VDADEV_NONE	; DEFAULT VDA DEVICE (VDADEV_NONE, VDADEV_VDU, VDADEV_CVDU, VDADEV_N8V, VDADEV_UPD7220)
DEFEMU		.EQU	EMUTYP_TTY	; DEFAULT VDA EMULATION (EMUTYP_TTY, EMUTYP_ANSI, ...)
;
RAMSIZE		.EQU	512		; SIZE OF RAM IN KB, MUST MATCH YOUR HARDWARE!!!
CLRRAMDISK	.EQU	CLR_AUTO	; CLR_ALWAYS, CLR_NEVER, CLR_AUTO (CLEAR IF INVALID DIR AREA)
;
DSKYENABLE	.EQU	FALSE		; TRUE FOR DSKY SUPPORT (DO NOT COMBINE WITH PPIDE)
;
SIMRTCENABLE	.EQU	FALSE		; SIMH CLOCK DRIVER
DSRTCENABLE	.EQU	TRUE		; DS-1302 CLOCK DRIVER
;
UARTENABLE	.EQU	FALSE		; TRUE FOR UART SUPPORT (N8 USES ASCI DRIVER)
UARTCNT		.EQU	0		; NUMBER OF UARTS
;
ASCIENABLE	.EQU	TRUE		; TRUE FOR Z180 ASCI SUPPORT
ASCI0BAUD	.EQU	CONBAUD		; ASCI0 BAUDRATE (IMPLEMENTED BY Z180_CNTLB0)
ASCI1BAUD	.EQU	CONBAUD		; ASCI1 BAUDRATE (IMPLEMENTED BY Z180_CNTLB1)
;
VDUENABLE	.EQU	FALSE		; TRUE FOR VDU BOARD SUPPORT
CVDUENABLE	.EQU	FALSE		; TRUE FOR CVDU BOARD SUPPORT
UPD7220ENABLE	.EQU	FALSE		; TRUE FOR uPD7220 BOARD SUPPORT
N8VENABLE	.EQU	FALSE		; TRUE FOR N8 (TMS9918) VIDEO/KBD SUPPORT
;
DEFIOBYTE	.EQU	$00		; DEFAULT INITIAL VALUE FOR CP/M IOBYTE, $00=TTY, $01=CRT (MUST HAVE CRT HARDWARE)
ALTIOBYTE	.EQU	$01		; ALT INITIAL VALUE (USED WHEN CONFIG JUMPER SHORTED)
WRTCACHE	.EQU	TRUE		; ENABLE WRITE CACHING IN CBIOS (DE)BLOCKING ALGORITHM
DSKTRACE	.EQU	FALSE		; ENABLE TRACING OF CBIOS DISK FUNCTION CALLS
;
MDENABLE	.EQU	TRUE		; TRUE FOR ROM/RAM DISK SUPPORT (ALMOST ALWAYS WANT THIS ENABLED)
MDTRACE		.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF MDENABLE = TRUE)
;
FDENABLE	.EQU	FALSE		; TRUE FOR FLOPPY SUPPORT
FDMODE		.EQU	FDMODE_N8	; FDMODE_DIO, FDMODE_ZETA, FDMODE_DIDE, FDMODE_N8, FDMODE_DIO3
FDTRACE		.EQU	1		; 0=SILENT, 1=FATAL ERRORS, 2=ALL ERRORS, 3=EVERYTHING (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIA		.EQU	FDM144		; FDM720, FDM144, FDM360, FDM120 (ONLY RELEVANT IF FDENABLE = TRUE)
FDMEDIAALT	.EQU	FDM720		; ALTERNATE MEDIA TO TRY, SAME CHOICES AS ABOVE (ONLY RELEVANT IF FDMAUTO = TRUE)
FDMAUTO		.EQU	TRUE		; SELECT BETWEEN MEDIA OPTS ABOVE AUTOMATICALLY
;
RFENABLE	.EQU	FALSE		; TRUE FOR RAM FLOPPY SUPPORT
RFCNT		.EQU	1		; NUMBER OF RAM FLOPPY UNITS
;
IDEENABLE	.EQU	FALSE		; TRUE FOR IDE SUPPORT
IDEMODE		.EQU	IDEMODE_MK4	; IDEMODE_DIO, IDEMODE_DIDE, IDEMODE_MK4
IDECNT		.EQU	1		; NUMBER OF IDE UNITS
IDETRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
IDE8BIT		.EQU	TRUE		; USE IDE 8BIT TRANSFERS (PROBABLY ONLY WORKS FOR CF CARDS!)
IDECAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
;
PPIDEENABLE	.EQU	FALSE		; TRUE FOR PPIDE SUPPORT (DO NOT COMBINE WITH DSKYENABLE)
PPIDEIOB	.EQU	$60		; PPIDE IOBASE
PPIDECNT	.EQU	1		; NUMBER OF PPIDE UNITS
PPIDETRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPIDEENABLE = TRUE)
PPIDE8BIT	.EQU	FALSE		; USE IDE 8BIT TRANSFERS (PROBABLY ONLY WORKS FOR CF CARDS!)
PPIDECAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
PPIDESLOW	.EQU	FALSE		; ADD DELAYS TO HELP PROBLEMATIC HARDWARE (TRY THIS IF PPIDE IS UNRELIABLE)
;
SDENABLE	.EQU	FALSE		; TRUE FOR SD SUPPORT
SDMODE		.EQU	SDMODE_MK4	; SDMODE_JUHA, SDMODE_CSIO, SDMODE_UART, SDMODE_PPI, SDMODE_DSD, SDMODE_MK4
SDTRACE		.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
SDCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
SDCSIOFAST	.EQU	FALSE		; TABLE-DRIVEN BIT INVERTER
;
PRPENABLE	.EQU	TRUE		; TRUE FOR PROPIO SD SUPPORT (FOR N8VEM PROPIO ONLY!)
PRPIOB		.EQU	$A8		; PORT IO ADDRESS BASE
PRPSDENABLE	.EQU	TRUE		; TRUE FOR PROPIO SD SUPPORT (FOR N8VEM PROPIO ONLY!)
PRPSDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PRPSDENABLE = TRUE)
PRPSDCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
PRPCONENABLE	.EQU	TRUE		; TRUE FOR PROPIO CONSOLE SUPPORT (PS/2 KBD & VGA VIDEO)
;
PPPENABLE	.EQU	FALSE		; TRUE FOR PARPORTPROP SUPPORT
PPPSDENABLE	.EQU	TRUE		; TRUE FOR PARPORTPROP SD SUPPORT
PPPSDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPPENABLE = TRUE)
PPPSDCAPACITY	.EQU	64		; CAPACITY OF PPP SD DEVICE (IN MB)
PPPCONENABLE	.EQU	TRUE		; TRUE FOR PROPIO CONSOLE SUPPORT (PS/2 KBD & VGA VIDEO)
;
HDSKENABLE	.EQU	FALSE		; TRUE FOR SIMH HDSK SUPPORT
HDSKTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF IDEENABLE = TRUE)
HDSKCAPACITY	.EQU	64		; CAPACITY OF DEVICE (IN MB)
;
PPKENABLE	.EQU	FALSE		; TRUE FOR PARALLEL PORT KEYBOARD
PPKTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF PPKENABLE = TRUE)
KBDENABLE	.EQU	FALSE		; TRUE FOR PS/2 KEYBOARD ON I8242
KBDTRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF KBDENABLE = TRUE)
;
TTYENABLE	.EQU	FALSE		; INCLUDE TTY EMULATION SUPPORT
ANSIENABLE	.EQU	FALSE		; INCLUDE ANSI EMULATION SUPPORT
ANSITRACE	.EQU	1		; 0=SILENT, 1=ERRORS, 2=EVERYTHING (ONLY RELEVANT IF ANSIENABLE = TRUE)
;
BOOTTYPE	.EQU	BT_MENU		; BT_MENU (WAIT FOR KEYPRESS), BT_AUTO (BOOT_DEFAULT AFTER BOOT_TIMEOUT SECS)
BOOT_TIMEOUT	.EQU	20		; APPROX TIMEOUT IN SECONDS FOR AUTOBOOT, 0 FOR IMMEDIATE
BOOT_DEFAULT	.EQU	'Z'		; SELECTION TO INVOKE AT TIMEOUT
;
#DEFINE		AUTOCMD	""		; AUTO STARTUP COMMAND FOR CP/M
;
; 18.432MHz OSC @ FULL SPEED, 38.4Kbps
;
;Z180_CLKDIV	.EQU	1		; 0=OSC/2, 1=OSC, 2=OSC*2
;Z180_MEMWAIT	.EQU	1		; MEMORY WAIT STATES TO INSERT (0-3)
;Z180_IOWAIT	.EQU	1		; IO WAIT STATES TO INSERT (0-3)
;Z180_CNTLB0	.EQU	20H		; SERIAL PORT 0 DIV, SEE Z180 CLOCKING DOCUMENT
;Z180_CNTLB1	.EQU	20H		; SERIAL PORT 1 DIV, SEE Z180 CLOCKING DOCUMENT
;
; 18.432MHz OSC @ DOUBLE SPEED, 38.4Kbps
;
Z180_CLKDIV	.EQU	2		; 0=OSC/2, 1=OSC, 2=OSC*2
Z180_MEMWAIT	.EQU	1		; MEMORY WAIT STATES TO INSERT (0-3)
Z180_IOWAIT	.EQU	1		; IO WAIT STATES TO INSERT (0-3)
Z180_CNTLB0	.EQU	21H		; SERIAL PORT 0 DIV, SEE Z180 CLOCKING DOCUMENT
Z180_CNTLB1	.EQU	21H		; SERIAL PORT 1 DIV, SEE Z180 CLOCKING DOCUMENT
