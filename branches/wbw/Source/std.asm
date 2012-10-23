;
;==================================================================================================
;   STANDARD INCLUDE STUFF
;==================================================================================================
;
;  5/21/2012 2.0.0.0 dwg - added B1F0PEEK & B1F0POKE
;
;  5/11/2012 2.0.0.0 dwg - moved BIOS JMPS together
;
;  3/04/2012 2.0.0.0 dwg - added CBIOS_BNKSEL for new BIOS jump (OEM extension)
;
;  2/21/2012         dwg - added TERM_VT52 terminal type for VDU
; 12/12/2011         dwg - changed TERM_NOT_SPEC to TERM_TTY & TTY=0 ANSI=1 WYSE=2
;
; 12/11/2011         dwg - added TERM_ANSI and TERM_WYSE for TERMTYPE
;
; 11/29/2011         dwg - now uses dynamically generated include file
; 			   instead of static definitions.
;
;---------------------------------------------------------------------------------------------------
;
TRUE:		.EQU 	1
FALSE:		.EQU 	0
;
; PRIMARY HARDWARE PLATFORMS
;
PLT_N8VEM	.EQU	1		; N8VEM ECB Z80 SBC
PLT_ZETA	.EQU	2		; ZETA Z80 SBC
PLT_N8		.EQU	3		; N8 (HOME COMPUTER) Z180 SBC
;
; BOOT STYLE
;
BT_MENU		.EQU	1		; WAIT FOR MENU SELECTION AT LOADER PROMPT
BT_AUTO		.EQU	2		; AUTO SELECT BOOT_DEFAULT AFTER BOOT_TIMEOUT
;
; VDU MODE SELECTIONS
;
VDUMODE_VDU	.EQU	1		; ORIGINAL ECB VDU (6545 CHIP)
VDUMODE_CVDU	.EQU	2		; ECB VDU COLOR (PENDING HARDWARE DEVELOPMENT)
VDUMODE_N8	.EQU	3		; N8 ONBOARD VIDEO SUBSYSTEM (NOT IMPLEMENTED)
;
; CHARACTER DEVICES
;
CIODEV_UART	.EQU	$00
CIODEV_PRPCON	.EQU	$10
CIODEV_VDU	.EQU	$20
CIODEV_CVDU	.EQU	$30
CIODEV_PPPCON	.EQU	$40
CIODEV_BAT	.EQU	$E0
CIODEV_NUL	.EQU	$F0
;
; DISK DEVICES (ONLY FIRST NIBBLE RELEVANT, SECOND NIBBLE RESERVED FOR UNIT)
;
DIODEV_MD	.EQU	$00
DIODEV_FD	.EQU	$10
DIODEV_IDE	.EQU	$20
DIODEV_ATAPI	.EQU	$30
DIODEV_PPIDE	.EQU	$40
DIODEV_SD	.EQU	$50
DIODEV_PRPSD	.EQU	$60
DIODEV_PPPSD	.EQU	$70
DIODEV_HDSK	.EQU	$80
;
; RAM DISK INITIALIZATION OPTIONS
;
CLR_NEVER	.EQU	0		; NEVER CLEAR RAM DISK
CLR_AUTO	.EQU	1		; CLEAR RAM DISK IF INVALID DIR ENTRIES
CLR_ALWAYS	.EQU	2		; ALWAYS CLEAR RAM DISK
;
; DISK MAP SELECTION OPTIONS
;
DM_ROM		.EQU	1		; ROM DRIVE PRIORITY
DM_RAM		.EQU	2		; RAM DRIVE PRIORITY
DM_FD		.EQU	3		; FLOPPY DRIVE PRIORITY
DM_IDE		.EQU	4		; IDE DRIVE PRIORITY
DM_PPIDE	.EQU	5		; PPIDE DRIVE PRIORITY
DM_SD		.EQU	6		; SD DRIVE PRIORITY
DM_PRPSD	.EQU	7		; PROPIO SD DRIVE PRIORITY
DM_PPPSD	.EQU	8		; PROPIO SD DRIVE PRIORITY
DM_HDSK		.EQU	9		; SIMH HARD DISK DRIVE PRIORITY
;
; FLOPPY DISK MEDIA SELECTIONS (ID'S MUST BE INDEX OF ENTRY IN FCD_TBL)
;
FDM720		.EQU	0		; 3.5" FLOPPY, 720KB, 2 SIDES, 80 TRKS, 9 SECTORS
FDM144		.EQU	1		; 3.5" FLOPPY, 1.44MB, 2 SIDES, 80 TRKS, 18 SECTORS
FDM360		.EQU	2		; 5.25" FLOPPY, 360KB, 2 SIDES, 40 TRKS, 9 SECTORS
FDM120		.EQU	3		; 5.25" FLOPPY, 1.2MB, 2 SIDES, 80 TRKS, 15 SECTORS
FDM111		.EQU	4		; 8" FLOPPY, 1.11MB, 2 SIDES, 74 TRKS, 15 SECTORS
;
; MEDIA ID VALUES
;
MID_NONE	.EQU	0
MID_MDROM	.EQU	1
MID_MDRAM	.EQU	2
MID_HD		.EQU	3
MID_FD720	.EQU	4
MID_FD144	.EQU	5
MID_FD360	.EQU	6
MID_FD120	.EQU	7
MID_FD111	.EQU	8
;
; FD MODE SELECTIONS
;
FDMODE_DIO	.EQU	1		; DISKIO V1
FDMODE_ZETA	.EQU	2		; ZETA
FDMODE_DIDE	.EQU	3		; DUAL IDE
FDMODE_N8	.EQU	4		; N8
FDMODE_DIO3	.EQU	5		; DISKIO V3
;
; IDE MODE SELECTIONS
;
IDEMODE_DIO	.EQU	1		; DISKIO V1
IDEMODE_DIDE	.EQU	2		; DUAL IDE
;
; PPIDE MODE SELECTIONS
;
PPIDEMODE_STD	.EQU	1		; STANDARD N8VEM PARALLEL PORT
PPIDEMODE_DIO3	.EQU	2		; DISKIO V3 PARALLEL PORT
;
; CONSOLE DEVICE CHOICES FOR LDRCON AND DBGCON IN CONFIG SETTINGS
;
CON_UART	.EQU	1
CON_VDU		.EQU	2
CON_PRP		.EQU	3
CON_PPP		.EQU	4
;
; CONSOLE TERMINAL TYPE CHOICES
;
TERM_TTY	.EQU	0
TERM_ANSI	.EQU	1
TERM_WYSE	.EQU	2
TERM_VT52	.EQU	3
;
; SYSTEM GENERATION SETTINGS
;
SYS_CPM		.EQU	1		; CPM (IMPLIES BDOS + CCP)
SYS_ZSYS	.EQU	2		; ZSYSTEM OS (IMPLIES ZSDOS + ZCPR)
;
DOS_BDOS	.EQU	1		; BDOS
DOS_ZDDOS	.EQU	2		; ZDDOS VARIANT OF ZSDOS
DOS_ZSDOS	.EQU	3		; ZSDOS
;
CP_CCP		.EQU	1		; CCP COMMAND PROCESSOR
CP_ZCPR		.EQU	2		; ZCPR COMMAND PROCESSOR
;
; CONFIGURE DOS (DOS) AND COMMAND PROCESSOR (CP) BASED ON SYSTEM SETTING (SYS)
;
#IFNDEF BLD_SYS
SYS		.EQU	SYS_CPM
#ELSE
SYS		.EQU	BLD_SYS
#ENDIF
;
#IF (SYS == SYS_CPM)
DOS		.EQU	DOS_BDOS
CP		.EQU	CP_CCP
#DEFINE		OSLBL	"CP/M-80 2.2C"
#ENDIF
;
#IF (SYS == SYS_ZSYS)
DOS		.EQU	DOS_ZSDOS
CP		.EQU	CP_ZCPR
#DEFINE		OSLBL	"ZSDOS 1.1"
#ENDIF
;
; INCLUDE VERSION AND BUILD SETTINGS
;
#INCLUDE "ver.inc"			; ADD BIOSVER
;
#INCLUDE "build.inc"			; INCLUDE USER CONFIG, ADD VARIANT, TIMESTAMP, & ROMSIZE
;
#IF (PLATFORM != PLT_N8)
;
; N8VEM HARDWARE IO PORT ADDRESSES AND MEMORY LOCATIONS
;
MPCL_RAM	.EQU 	78H		; BASE IO ADDRESS OF RAM MEMORY PAGER CONFIGURATION LATCH
MPCL_ROM	.EQU 	7CH		; BASE IO ADDRESS OF ROM MEMORY PAGER CONFIGURATION LATCH
RTC		.EQU	70H		; ADDRESS OF RTC LATCH AND INPUT PORT

;__HARDWARE_INTERFACES________________________________________________________________________________________________________________ 
;
; PPI 82C55 I/O IS DECODED TO PORT 60-67
;
PPIA		.EQU 	60H		; PORT A
PPIB		.EQU 	61H		; PORT B
PPIC		.EQU 	62H		; PORT C
PPIX	 	.EQU 	63H		; PPI CONTROL PORT
;
; 16C550 SERIAL LINE UART
;
SIO_BASE	.EQU	68H
SIO_RBR		.EQU	SIO_BASE + 0	; DLAB=0: RCVR BUFFER REG (READ ONLY)
SIO_THR		.EQU	SIO_BASE + 0	; DLAB=0: XMIT HOLDING REG (WRITE ONLY)
SIO_IER		.EQU	SIO_BASE + 1	; DLAB=0: INT ENABLE REG
SIO_IIR		.EQU	SIO_BASE + 2	; INT IDENT REGISTER (READ ONLY)
SIO_FCR		.EQU	SIO_BASE + 2	; FIFO CONTROL REG (WRITE ONLY)
SIO_LCR		.EQU	SIO_BASE + 3	; LINE CONTROL REG
SIO_MCR		.EQU	SIO_BASE + 4	; MODEM CONTROL REG
SIO_LSR		.EQU	SIO_BASE + 5	; LINE STATUS REG
SIO_MSR		.EQU	SIO_BASE + 6	; MODEM STATUS REG
SIO_SCR		.EQU	SIO_BASE + 7	; SCRATCH REGISTER
SIO_DLL		.EQU	SIO_BASE + 0	; DLAB=1: DIVISOR LATCH (LS)
SIO_DLM		.EQU	SIO_BASE + 1	; DLAB=1: DIVISOR LATCH (MS)
;
#ENDIF		; (PLATFORM != PLT_N8)
;
#IF (PLATFORM == PLT_N8)
;
; Z180 REGISTERS
;
CPU_IOBASE	.EQU	40H		; ONLY RELEVANT FOR Z180
;
CPU_CNTLA0:	.EQU	CPU_IOBASE+$00	;ASCI0 control A
CPU_CNTLA1:	.EQU	CPU_IOBASE+$01	;ASCI1 control A
CPU_CNTLB0:	.EQU	CPU_IOBASE+$02	;ASCI0 control B
CPU_CNTLB1:	.EQU	CPU_IOBASE+$03	;ASCI1 control B
CPU_STAT0:	.EQU	CPU_IOBASE+$04	;ASCI0 status
CPU_STAT1:	.EQU	CPU_IOBASE+$05	;ASCI1 status
CPU_TDR0:	.EQU	CPU_IOBASE+$06	;ASCI0 transmit
CPU_TDR1:	.EQU	CPU_IOBASE+$07	;ASCI1 transmit
CPU_RDR0:	.EQU	CPU_IOBASE+$08	;ASCI0 receive
CPU_RDR1:	.EQU	CPU_IOBASE+$09	;ASCI1 receive
CPU_CNTR:	.EQU	CPU_IOBASE+$0A	;CSI/O control
CPU_TRDR:	.EQU	CPU_IOBASE+$0B	;CSI/O transmit/receive
CPU_TMDR0L:	.EQU	CPU_IOBASE+$0C	;Timer 0 data lo
CPU_TMDR0H:	.EQU	CPU_IOBASE+$0D	;Timer 0 data hi
CPU_RLDR0L:	.EQU	CPU_IOBASE+$0E	;Timer 0 reload lo
CPU_RLDR0H:	.EQU	CPU_IOBASE+$0F	;Timer 0 reload hi
CPU_TCR:	.EQU	CPU_IOBASE+$10	;Timer control
;	
CPU_ASEXT0:	.EQU	CPU_IOBASE+$12	;ASCI0 extension control (Z8S180)
CPU_ASEXT1:	.EQU	CPU_IOBASE+$13	;ASCI1 extension control (Z8S180)
;
CPU_TMDR1L:	.EQU	CPU_IOBASE+$14	;Timer 1 data lo
CPU_TMDR1H:	.EQU	CPU_IOBASE+$15	;Timer 1 data hi
CPU_RLDR1L:	.EQU	CPU_IOBASE+$16	;Timer 1 reload lo
CPU_RLDR1H:	.EQU	CPU_IOBASE+$17	;Timer 1 reload hi
CPU_FRC:	.EQU	CPU_IOBASE+$18	;Free running counter

CPU_ASTC0L:	.EQU	CPU_IOBASE+$1A	;ASCI0 Time constant lo (Z8S180)
CPU_ASTC0H:	.EQU	CPU_IOBASE+$1B	;ASCI0 Time constant hi (Z8S180)
CPU_ASTC1L:	.EQU	CPU_IOBASE+$1C	;ASCI1 Time constant lo (Z8S180)
CPU_ASTC1H:	.EQU	CPU_IOBASE+$1D	;ASCI1 Time constant hi (Z8S180)
CPU_CMR:	.EQU	CPU_IOBASE+$1E	;Clock multiplier (latest Z8S180)
CPU_CCR:	.EQU	CPU_IOBASE+$1F	;CPU control (Z8S180)
;
CPU_SAR0L:	.EQU	CPU_IOBASE+$20	;DMA0 source addr lo
CPU_SAR0H:	.EQU	CPU_IOBASE+$21	;DMA0 source addr hi
CPU_SAR0B:	.EQU	CPU_IOBASE+$22	;DMA0 source addr bank
CPU_DAR0L:	.EQU	CPU_IOBASE+$23	;DMA0 dest addr lo
CPU_DAR0H:	.EQU	CPU_IOBASE+$24	;DMA0 dest addr hi
CPU_DAR0B:	.EQU	CPU_IOBASE+$25	;DMA0 dest addr bank
CPU_BCR0L:	.EQU	CPU_IOBASE+$26	;DMA0 byte count lo
CPU_BCR0H:	.EQU	CPU_IOBASE+$27	;DMA0 byte count hi
CPU_MAR1L:	.EQU	CPU_IOBASE+$28	;DMA1 memory addr lo
CPU_MAR1H:	.EQU	CPU_IOBASE+$29	;DMA1 memory addr hi
CPU_MAR1B:	.EQU	CPU_IOBASE+$2A	;DMA1 memory addr bank
CPU_IAR1L:	.EQU	CPU_IOBASE+$2B	;DMA1 I/O addr lo
CPU_IAR1H:	.EQU	CPU_IOBASE+$2C	;DMA1 I/O addr hi
CPU_IAR1B:	.EQU	CPU_IOBASE+$2D	;DMA1 I/O addr bank (Z8S180)
CPU_BCR1L:	.EQU	CPU_IOBASE+$2E	;DMA1 byte count lo
CPU_BCR1H:	.EQU	CPU_IOBASE+$2F	;DMA1 byte count hi
CPU_DSTAT:	.EQU	CPU_IOBASE+$30	;DMA status
CPU_DMODE:	.EQU	CPU_IOBASE+$31	;DMA mode
CPU_DCNTL:	.EQU	CPU_IOBASE+$32	;DMA/WAIT control
CPU_IL:		.EQU	CPU_IOBASE+$33	;Interrupt vector load
CPU_ITC:	.EQU	CPU_IOBASE+$34	;INT/TRAP control
;
CPU_RCR:	.EQU	CPU_IOBASE+$36	;Refresh control
;
CPU_CBR:	.EQU	CPU_IOBASE+$38	;MMU common base register
CPU_BBR:	.EQU	CPU_IOBASE+$39	;MMU bank base register
CPU_CBAR	.EQU	CPU_IOBASE+$3A	;MMU common/bank area register
;
CPU_OMCR:	.EQU	CPU_IOBASE+$3E	;Operation mode control
CPU_ICR:	.EQU	$3F		;I/O control register (not relocated!!!)
;
; N8 ONBOARD  I/O REGISTERS
;
N8_IOBASE	.EQU	$80
;
PPI		.EQU	N8_IOBASE+$00
PPIA		.EQU 	PPI+$00		; PORT A
PPIB		.EQU 	PPI+$01		; PORT B
PPIC		.EQU 	PPI+$02		; PORT C
PPIX	 	.EQU 	PPI+$03		; PPI CONTROL PORT
;
PPI2		.EQU	N8_IOBASE+$04
PPI2A		.EQU 	PPI2+$00	; PORT A
PPI2B		.EQU 	PPI2+$01	; PORT B
PPI2C		.EQU 	PPI2+$02	; PORT C
PPI2X	 	.EQU 	PPI2+$03	; PPI CONTROL PORT
;
RTC:		.EQU	N8_IOBASE+$08	;RTC latch and buffer
;FDC:		.EQU	N8_IOBASE+$0C	;Floppy disk controller
;UTIL:		.EQU	N8_IOBASE+$10	;Floppy disk utility 
ACR:		.EQU	N8_IOBASE+$14	;auxillary control register
RMAP:		.EQU	N8_IOBASE+$16	;ROM page register
VDP:		.EQU	N8_IOBASE+$18	;Video Display Processor (TMS9918A)
PSG:		.EQU	N8_IOBASE+$1C	;Programmable Sound Generator (AY-3-8910)
;
DEFACR		.EQU	$1B
;
#ENDIF
;
; CHARACTER DEVICE FUNCTIONS
;
CF_INIT		.EQU	0
CF_IN		.EQU	1
CF_IST		.EQU	2
CF_OUT		.EQU	3
CF_OST		.EQU	4
;
; DISK OPERATIONS
;
DOP_READ	.EQU	0		; READ OPERATION
DOP_WRITE	.EQU	1		; WRITE OPERATION
DOP_FORMAT	.EQU	2		; FORMAT OPERATION
DOP_READID	.EQU	3		; READ ID OPERATION
;
; DISK DRIVER FUNCTIONS
;
DF_READY	.EQU	1
DF_SELECT	.EQU	2
DF_READ		.EQU	3
DF_WRITE	.EQU	4
DF_FORMAT	.EQU	5
;
; BIOS FUNCTIONS
;
BF_CIO		.EQU	$00
BF_CIOIN	.EQU	BF_CIO + 0	; CHARACTER INPUT
BF_CIOOUT	.EQU	BF_CIO + 1	; CHARACTER OUTPUT
BF_CIOIST	.EQU	BF_CIO + 2	; CHARACTER INPUT STATUS
BF_CIOOST	.EQU	BF_CIO + 3	; CHARACTER OUTPUT STATUS
;
BF_DIO		.EQU	$10
BF_DIORD	.EQU	BF_DIO + 0	; DISK READ
BF_DIOWR	.EQU	BF_DIO + 1	; DISK WRITE
BF_DIOST	.EQU	BF_DIO + 2	; DISK STATUS
BF_DIOMED	.EQU	BF_DIO + 3	; DISK MEDIA
BF_DIOID	.EQU	BF_DIO + 4	; DISK IDENTIFY
BF_DIOGBA	.EQU	BF_DIO + 8	; DISK GET BUFFER ADR
BF_DIOSBA	.EQU	BF_DIO + 9	; DISK SET BUFFER ADR
;
BF_CLK		.EQU	$20
BF_CLKRD	.EQU	BF_CLK + 0
BF_CLKWR	.EQU	BF_CLK + 1
;
BF_VDU		.EQU	$30
BF_VDUIN	.EQU	BF_VDU + 0	; VDU CHARACTER INPUT
BF_VDUOUT	.EQU	BF_VDU + 1	; VDU CHARACTER OUTPUT
BF_VDUIST	.EQU	BF_VDU + 2	; VDU CHARACTER INPUT STATUS
BF_VDUOST	.EQU	BF_VDU + 3	; VDU CHARACTER OUTPUT STATUS
BF_VDUXY	.EQU	BF_VDU + 4	; VDU CURSOR POSITION X/Y
;
BF_SYS		.EQU	$F0
BF_SYSGETCFG	.EQU	BF_SYS + 0	; GET CONFIGURATION DATA BLOCK
BF_SYSSETCFG	.EQU	BF_SYS + 1	; SET CONFIGURATION DATA BLOCK
BF_SYSBNKCPY	.EQU	BF_SYS + 2	; COPY TO/FROM RAM/ROM MEMORY BANK
;
;
; MEMORY LAYOUT
;
CPM_LOC		.EQU	0D000H			; CONFIGURABLE: LOCATION OF CPM FOR RUNNING SYSTEM
CPM_SIZ		.EQU	2F00H			; SIZE OF CPM IMAGE (CCP + BDOS + CBIOS (INCLUDING DATA))
CPM_END		.EQU	CPM_LOC + CPM_SIZ
;
CCP_LOC		.EQU	CPM_LOC			; START OF COMMAND PROCESSOR
CCP_SIZ		.EQU	800H
CCP_END		.EQU	CCP_LOC + CCP_SIZ
;
BDOS_LOC	.EQU	CCP_END			; START OF BDOS
BDOS_SIZ	.EQU	0E00H
BDOS_END	.EQU	BDOS_LOC + BDOS_SIZ
;
CBIOS_LOC	.EQU	BDOS_END
CBIOS_SIZ	.EQU	CPM_END - CBIOS_LOC
CBIOS_END	.EQU	CBIOS_LOC + CBIOS_SIZ
;
CPM_ENT		.EQU	CBIOS_LOC
;
HB_LOC		.EQU	CPM_END
HB_SIZ		.EQU	100H
HB_END		.EQU	HB_LOC + HB_SIZ
;
MON_LOC		.EQU	0C000H			; LOCATION OF MONITOR FOR RUNNING SYSTEM
MON_SIZ		.EQU	01000H			; SIZE OF MONITOR BINARY IMAGE
MON_END		.EQU	MON_LOC + MON_SIZ
MON_DSKY	.EQU	MON_LOC			; MONITOR ENTRY (DSKY)
MON_UART	.EQU	MON_LOC + 3		; MONITOR ENTRY (UART)
;
CBIOS_BOOT	.EQU	CBIOS_LOC + 0
CBIOS_WBOOT	.EQU	CBIOS_LOC + 3
CBIOS_CONST	.EQU	CBIOS_LOC + 6
CBIOS_CONIN	.EQU	CBIOS_LOC + 9
CBIOS_CONOUT	.EQU	CBIOS_LOC + 12
CBIOS_LIST	.EQU	CBIOS_LOC + 15
CBIOS_PUNCH	.EQU	CBIOS_LOC + 18
CBIOS_READER	.EQU	CBIOS_LOC + 21
CBIOS_HOME	.EQU	CBIOS_LOC + 24
CBIOS_SELDSK	.EQU	CBIOS_LOC + 27
CBIOS_SETTRK	.EQU	CBIOS_LOC + 30
CBIOS_SETSEC	.EQU	CBIOS_LOC + 33
CBIOS_SETDMA	.EQU	CBIOS_LOC + 36
CBIOS_READ	.EQU	CBIOS_LOC + 39
CBIOS_WRITE	.EQU	CBIOS_LOC + 42
CBIOS_LISTST	.EQU	CBIOS_LOC + 45
CBIOS_SECTRN	.EQU	CBIOS_LOC + 48
;
; EXTENDED CBIOS FUNCTIONS
;
CBIOS_BNKSEL	.EQU	CBIOS_LOC + 51
CBIOS_GETDSK	.EQU	CBIOS_LOC + 54
CBIOS_SETDSK	.EQU	CBIOS_LOC + 57
CBIOS_GETINFO	.EQU	CBIOS_LOC + 60
;
; PLACEHOLDERS FOR FUTURE CBIOS EXTENSIONS
;
CBIOS_RSVD1	.EQU	CBIOS_LOC + 63
CBIOS_RSVD2	.EQU	CBIOS_LOC + 76
CBIOS_RSVD3	.EQU	CBIOS_LOC + 69
CBIOS_RSVD4	.EQU	CBIOS_LOC + 72
;
CDISK:	 	.EQU 	00004H		; LOC IN PAGE 0 OF CURRENT DISK NUMBER 0=A,...,15=P
IOBYTE:	 	.EQU 	00003H		; LOC IN PAGE 0 OF I/O DEFINITION BYTE.
;
; MEMORY CONFIGURATION
;
MSIZE		.EQU	59		; CP/M VERSION MEMORY SIZE IN KILOBYTES
;
; "BIAS" IS ADDRESS OFFSET FROM 3400H FOR MEMORY SYSTEMS
; THAN 16K (REFERRED TO AS "B" THROUGHOUT THE TEXT) 
;
BIAS:	 	.EQU 	(MSIZE-20)*1024
CCP:	 	.EQU 	3400H+BIAS	; BASE OF CCP
BDOS:	 	.EQU 	CCP+806H	; BASE OF BDOS
BIOS:	 	.EQU 	CCP+1600H	; BASE OF BIOS
CCPSIZ:		.EQU	00800H
;
#IF (PLATFORM == PLT_N8VEM)
  #DEFINE 	PLATFORM_NAME	"N8VEM Z80 SBC"
#ENDIF
#IF (PLATFORM == PLT_ZETA)
  #DEFINE 	PLATFORM_NAME	"ZETA Z80 SBC"
#ENDIF
#IF (PLATFORM == PLT_N8)
  #DEFINE 	PLATFORM_NAME	"N8 Z180 SBC"
#ENDIF
;
#IF (DSKYENABLE)
  #DEFINE	DSKYLBL	", DSKY"
#ELSE
  #DEFINE	DSKYLBL	""
#ENDIF
;
#IF (VDUENABLE)
  #DEFINE	VDULBL	", VDU"
#ELSE
  #DEFINE	VDULBL	""
#ENDIF
;
#IF (FDENABLE)
  #IF (FDMAUTO)
      #DEFINE	FDLBL	", FLOPPY (AUTOSIZE)"
  #ELSE
    #IF (FDMEDIA == FDM720)
      #DEFINE	FDLBL	", FLOPPY (720KB)"
    #ENDIF
    #IF (FDMEDIA == FDM144)
      #DEFINE	FDLBL	", FLOPPY (1.44MB)"
    #ENDIF
    #IF (FDMEDIA == FDM120)
      #DEFINE	FDLBL	", FLOPPY (1.20MB)"
    #ENDIF
    #IF (FDMEDIA == FDM360)
      #DEFINE	FDLBL	", FLOPPY (360KB)"
    #ENDIF
    #IF (FDMEDIA == FDM111)
      #DEFINE	FDLBL	", FLOPPY (1.11MB)"
    #ENDIF
  #ENDIF
#ELSE
  #DEFINE	FDLBL	""
#ENDIF
;
#IF (IDEENABLE)
  #IF (IDEMODE == IDEMODE_DIO)
    #DEFINE	IDELBL		", IDE (DISKIO)"
  #ENDIF
  #IF (IDEMODE == IDEMODE_DIDE)
    #DEFINE	IDELBL		", IDE (DUAL IDE)"
  #ENDIF
#ELSE
  #DEFINE	IDELBL		""
#ENDIF
;
#IF (PPIDEENABLE)
  #IF (PPIDEMODE == PPIDEMODE_STD)
    #DEFINE	PPIDELBL	", PPIDE (STD)"
  #ENDIF
  #IF (PPIDEMODE == PPIDEMODE_DIO3)
    #DEFINE	PPIDELBL	", PPIDE (DISKIO V3)"
  #ENDIF
#ELSE
  #DEFINE	PPIDELBL	""
#ENDIF
;
#IF (SDENABLE)
  #DEFINE	SDLBL		", SD CARD"
#ELSE
  #DEFINE	SDLBL		""
#ENDIF
;
#IF (IDEENABLE)
  #DEFINE	IDELBL	", IDE"
#ELSE
  #DEFINE	IDELBL	""
#ENDIF
;
#IF (PPIDEENABLE)
  #DEFINE	PPIDELBL	", PPIDE"
#ELSE
  #DEFINE	PPIDELBL	""
#ENDIF

#IF (SDENABLE)
  #DEFINE	SDLBL		", SD CARD"
#ELSE
  #DEFINE	SDLBL		""
#ENDIF

#IF (HDSKENABLE)
  #DEFINE	HDSKLBL		", SIMH DISK"
#ELSE
  #DEFINE	HDSKLBL		""
#ENDIF

#IF (PRPENABLE)
  #IF (PRPCONENABLE & PRPSDENABLE)
    #DEFINE	PRPLBL		", PROPIO (CONSOLE, SD CARD)"
  #ENDIF
  #IF (PRPCONENABLE & !PRPSDENABLE)
    #DEFINE	PRPLBL		", PROPIO (CONSOLE)"
  #ENDIF
  #IF (!PRPCONENABLE & PRPSDENABLE)
    #DEFINE	PRPLBL		", PROPIO (SD CARD)"
  #ENDIF
  #IF (!PRPCONENABLE & !PRPSDENABLE)
    #DEFINE	PRPLBL		", PROPIO ()"
  #ENDIF
#ELSE
  #DEFINE	PRPLBL		""
#ENDIF

#IF (PPPENABLE)
  #IF (PPPCONENABLE & PPPSDENABLE)
    #DEFINE	PPPLBL		", PARPORTPROP (CONSOLE, SD CARD)"
  #ENDIF
  #IF (PPPCONENABLE & !PPPSDENABLE)
    #DEFINE	PPPLBL		", PARPORTPROP (CONSOLE)"
  #ENDIF
  #IF (!PPPCONENABLE & PPPSDENABLE)
    #DEFINE	PPPLBL		", PARPORTPROP (SD CARD)"
  #ENDIF
  #IF (!PPPCONENABLE & !PPPSDENABLE)
    #DEFINE	PPPLBL		", PARPORTPROP ()"
  #ENDIF
#ELSE
  #DEFINE	PPPLBL		""
#ENDIF

	.ECHO	"Configuration: "
	.ECHO	PLATFORM_NAME
	.ECHO	DSKYLBL
	.ECHO	VDULBL
	.ECHO	FDLBL
	.ECHO	IDELBL
	.ECHO	PPIDELBL
	.ECHO	SDLBL
	.ECHO	PRPLBL
	.ECHO	PPPLBL
	.ECHO	"\n"
