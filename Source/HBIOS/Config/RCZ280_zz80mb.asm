;
;==================================================================================================
;   RCBUS Z280 STANDARD CONFIGURATION (NATIVE Z280 MMU W/ LINEAR MEMORY ON ZZ80MB)
;==================================================================================================
;
; THE COMPLETE SET OF DEFAULT CONFIGURATION SETTINGS FOR THIS PLATFORM ARE FOUND IN THE
; CFG_<PLT>.ASM INCLUDED FILE WHICH IS FOUND IN THE PARENT DIRECTORY.  THIS FILE CONTAINS
; COMMON CONFIGURATION SETTINGS THAT OVERRIDE THE DEFAULTS.  IT IS INTENDED THAT YOU MAKE
; YOUR CUSTOMIZATIONS IN THIS FILE AND JUST INHERIT ALL OTHER SETTINGS FROM THE DEFAULTS.
; EVEN BETTER, YOU CAN MAKE A COPY OF THIS FILE WITH A NAME LIKE <PLT>_XXX.ASM AND SPECIFY
; YOUR FILE IN THE BUILD PROCESS.
;
; THE SETTINGS BELOW ARE THE SETTINGS THAT ARE MOST COMMONLY MODIFIED FOR THIS PLATFORM.
; MANY OF THEM ARE EQUAL TO THE SETTINGS IN THE INCLUDED FILE, SO THEY DON'T REALLY DO
; ANYTHING AS IS.  THEY ARE LISTED HERE TO MAKE IT EASY FOR YOU TO ADJUST THE MOST COMMON
; SETTINGS.
;
; N.B., SINCE THE SETTINGS BELOW ARE REDEFINING VALUES ALREADY SET IN THE INCLUDED FILE,
; TASM INSISTS THAT YOU USE THE .SET OPERATOR AND NOT THE .EQU OPERATOR BELOW. ATTEMPTING
; TO REDEFINE A VALUE WITH .EQU BELOW WILL CAUSE TASM ERRORS!
;
; PLEASE REFER TO THE CUSTOM BUILD INSTRUCTIONS (README.TXT) IN THE SOURCE DIRECTORY (TWO
; DIRECTORIES ABOVE THIS ONE).
;
#DEFINE PLATFORM_NAME "ZZ80MB", " [", CONFIG, "]"
;
#DEFINE	BOOT_DEFAULT	"H"		; DEFAULT BOOT LOADER CMD ON <CR> OR AUTO BOOT
;
#include "cfg_rcz280.asm"
;
CPUOSC		.SET	12000000	; CPU OSC FREQ IN MHZ
INTMODE		.SET	3		; INTERRUPTS: 0=NONE, 1=MODE 1, 2=MODE 2
CRTACT		.SET	FALSE		; ACTIVATE CRT (VDU,CVDU,PROPIO,ETC) AT STARTUP
;
MEMMGR		.SET	MM_Z280		; MEMORY MANAGER: MM_[SBC|Z2|N8|Z180|Z280]
;
RAMLOC		.SET	23		; START OF RAM AS POWER OF 2 (2^N) IN PHYSICAL ADDRESS SPACE
RAMBIAS		.SET	(1 << (RAMLOC - 10))	; OFFSET OF START OF RAM IN PHYSICAL ADDRESS SPACE
;
Z280_MEMLOWAIT	.SET	0		; Z280: LOW 8MB MEMORY WAIT STATES (0-3)
Z280_MEMHIWAIT	.SET	0		; Z280: HIGH 8MB MEMORY WAIT STATES (0-3)
Z280_IOWAIT	.SET	1		; Z280: I/O WAIT STATES TO ADD ABOVE 1 W/S BUILT-IN (0-3)
Z280_INTWAIT	.SET	0		; Z280: INT ACK WAIT STATUS (0-3)
;
Z2UENABLE	.SET	TRUE		; Z2U: ENABLE Z280 UART SERIAL DRIVER (Z2U.ASM)
Z2U0HFC		.SET	TRUE		; Z2U 0: ENABLE HARDWARE FLOW CONTROL
UARTENABLE	.SET	TRUE		; UART: ENABLE 8250/16550-LIKE SERIAL DRIVER (UART.ASM)
ACIAENABLE	.SET	FALSE		; ACIA: ENABLE MOTOROLA 6850 ACIA DRIVER (ACIA.ASM)
SIOENABLE	.SET	TRUE		; SIO: ENABLE ZILOG SIO SERIAL DRIVER (SIO.ASM)
;
TMSENABLE	.SET	FALSE		; TMS: ENABLE TMS9918 VIDEO/KBD DRIVER (TMS.ASM)
TMSMODE		.SET	TMSMODE_MSX	; TMS: DRIVER MODE: TMSMODE_[SCG|N8|MBC|MSX|MSX9958|MSXKBD|COLECO]
MKYENABLE	.SET	FALSE		; MSX 5255 PPI KEYBOARD COMPATIBLE DRIVER (REQUIRES TMS VDA DRIVER)
VDAEMU_SERKBD	.SET	0		; VDA EMULATION: SERIAL KBD UNIT #, OR $FF FOR HW KBD
;
AY38910ENABLE	.SET	FALSE		; AY: AY-3-8910 / YM2149 SOUND DRIVER
AYMODE		.SET	AYMODE_RCZ80	; AY: DRIVER MODE: AYMODE_[SCG|N8|RCZ80|RCZ180|MSX|LINC]
SN76489ENABLE	.SET	FALSE		; SN: ENABLE SN76489 SOUND DRIVER
;
FDENABLE	.SET	TRUE		; FD: ENABLE FLOPPY DISK DRIVER (FD.ASM)
FDMODE		.SET	FDMODE_RCWDC	; FD: DRIVER MODE: FDMODE_[DIO|ZETA|ZETA2|DIDE|N8|DIO3|RCSMC|RCWDC|DYNO|EPWDC]
;
IDEENABLE	.SET	TRUE		; IDE: ENABLE IDE DISK DRIVER (IDE.ASM)
PPIDEENABLE	.SET	TRUE		; PPIDE: ENABLE PARALLEL PORT IDE DISK DRIVER (PPIDE.ASM)
SDENABLE	.SET	FALSE		; SD: ENABLE SD CARD DISK DRIVER (SD.ASM)
SDCNT		.SET	1		; SD: NUMBER OF SD CARD DEVICES (1-2), FOR DSD/SC/MT SC ONLY
;
PRPENABLE	.SET	FALSE		; PRP: ENABLE ECB PROPELLER IO BOARD DRIVER (PRP.ASM)
