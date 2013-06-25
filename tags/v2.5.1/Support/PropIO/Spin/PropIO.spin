{{

  *******************************
  *  PropIO for RomWBW          *
  *  Interface to N8VEM PropIO  *
  *  Version 0.92               *
  *  August 10, 2012            *
  *******************************

  Wayne Warthen
  wwarthen@gmail.com

  Substantially derived from work by:
  
  David Mehaffy (yoda)

  Credits:

  Andrew Lynch (lynchaj)        for creating the N8VEM
  Vince Briel (vbriel)          for the PockeTerm with which a lot of code is shared here
  Jeff Ledger (oldbitcollector) for base terminal code
  Ray Rodrick (cluso99)         for the TriBladeProp that shares some of these ideas
                                for using the CPM to SD

  ToDo:
  
    1)  Add buffer overrun checks?

  Updates:

    2012-02-20 WBW: Updated VGA_1024 ANSI emulation to handle 'f' the same as 'H'

}}

CON
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000
  
  SLEEP = 60 * 5                ' Screen saver timeout in seconds
  
  VGA_BASE = 16                 ' VGA Video pins 16-23 (??)
  KBD_BASE = 14                 ' PS/2 Keyboard pins 14-15 (DATA, CLK)
  SD_BASE = 24                  ' SD Card pins 24-27 (DO, CLK, DI, CS)

  '' Terminal Colors
  TURQUOISE         = $29
  BLUE              = $27
  BABYBLUE          = $95
  RED               = $C1
  GREEN             = $99
  GOLDBROWN         = $A2
  AMBERDARK         = $E2
  LAVENDER          = $A5
  WHITE             = $FF
  HOTPINK           = $C9
  GOLD              = $D9
  PINK              = $C5

  DSKCMD_RESET = $10
  DSKCMD_INIT = $20
  DSKCMD_READBLK = $30
  DSKCMD_PREPARE = $40
  DSKCMD_WRITEBLK = $50

  DSKST_ACT = $80               ' bit indicates interface is actively processing command (busy)
  DSKST_ERR = $40               ' bit indicates device in error status                                    
  DSKST_OVR = $20               ' bit indicates a buffer overrun occurred

  TRMST_ACT = $80               ' bit indicates interface is busy
  TRMST_ERR = $40               ' bit indicates an error has occurred
  TRMST_KBDACT = $20            ' bit set when keyboard input active (getting key from keyboard)                                    
  TRMST_DSPACT = $10            ' bit set when display output active (writing byte to display)

  TRMST_ACTMASK = (TRMST_KBDACT | TRMST_DSPACT)         ' bit mask for kbd or dsp active



OBJ
  dsp : "VGA_1024"                                      ' VGA Terminal Driver
  kbd : "Keyboard"                                      ' PS/2 Keyboard Driver
  sdc : "safe_spi"                                      ' SD Card Driver
  dbg : "Parallax Serial Terminal"                      ' Serial Port Driver (debug output)                                              

VAR
  byte  TermStatKbd
  byte  TermStatDsp
  byte  TermKbdBuf
  byte  TermScrBuf
  byte  DiskStat
  byte  DiskCmd
  long  DiskBlk
  long  DiskBuf[128]                                    ' 512 bytes, long-aligned
  
  long TimerStack[16]
  long TimerCount
   
PUB main

  dbg.Start(115200)

  MsgStr(string("Starting PropIO..."))
  MsgNewLine

  MsgStr(string("Initializing Video..."))
  Result := dsp.Start(VGA_BASE)
  if (Result < 0)
    MsgStr(string(" Failed!   Error: "))
    MsgDec(Result)
  else
    MsgStr(string(" OK"))
    dsp.Color(GOLDBROWN)
    dsp.Cls1(9600, 5, 1, 0, 0)
    dsp.Inv(0)
    dsp.CursorSet(5)
  MsgNewLine

  TimerCount := SLEEP  
  dsp.VidOn

  MsgStr(string("Initializing PropIO..."))

  TermStatKbdAdr := @TermStatKbd
  TermStatDspAdr := @TermStatDsp
  TermKbdBufAdr := @TermKbdBuf
  TermDspBufAdr := @TermScrBuf
  DiskStatAdr := @DiskStat
  DiskCmdAdr := @DiskCmd
  DiskBufAdr := @DiskBuf

  DiskBufIdx := 0
  TermStatKbd := TRMST_KBDACT
  TermStatDsp := 0
  DiskStat := 0
    
  ByteFill(@DiskBuf, $00, 512)

  MsgStr(string(" OK"))
  MsgNewLine

  MsgStr(string("Initializing Keyboard..."))
  Result := kbd.Start(KBD_BASE, KBD_BASE + 1)
  if (Result < 0)
    MsgStr(string(" Failed!   Error: "))
    MsgDec(Result)
  else
    MsgStr(string(" OK"))
  MsgNewLine

  MsgStr(string("Starting Timer..."))
  Result := cognew(Timer, @TimerStack) 
  if (Result < 0)
    MsgStr(string(" Failed!   Error: "))
    MsgDec(Result)
  else
    MsgStr(string(" OK"))
  MsgNewLine

  MsgStr(string("Starting PortIO cog..."))
  Result := cognew(@PortIO, 0) + 1
  if (Result < 0)
    MsgStr(string(" Failed!   Error: "))
    MsgDec(Result)
  else
    MsgStr(string(" OK"))
  MsgNewLine

  MsgStr(string("PropIO Ready!"))
  MsgNewLine

  repeat
    if (DiskStat & DSKST_ACT)
      ProcessDiskCmd
      DiskCmd := 0
      DiskStat &= !DSKST_ACT
      
    if (TermStatDsp & TRMST_DSPACT)
      dsp.Process_Char(TermScrBuf)
      Activity
      TermStatDsp &= !TRMST_DSPACT
      
    if (TermStatKbd & TRMST_KBDACT)
      if (kbd.GotKey)
        TermKbdBuf := kbd.GetKey
        Activity
        TermStatKbd &= !TRMST_KBDACT
       
  MsgNewLine
  MsgStr(string("PropIO Shutdown!"))
  MsgNewLine

PRI ProcessDiskCmd | rsp

  'dbg.Str(string("ProcessDiskCmd: DiskCmd="))
  'dbg.Hex(DiskCmd,2)
  'dbg.NewLine

  if (DiskCmd == DSKCMD_RESET)
    DiskBlk := -1
    DiskStat := DSKST_ACT
        
  elseif (DiskCmd == DSKCMD_INIT)
    rsp := InitCard 
    if (rsp < 0)
      DiskStat := (DiskStat | DSKST_ERR)
      DiskBuf[0] := rsp
          
  elseif (DiskCmd == DSKCMD_READBLK)
    DiskBlk := DiskBuf[0]
    rsp := ReadSector(DiskBlk, @DiskBuf) 
    if (rsp < 0)
      DiskStat := (DiskStat | DSKST_ERR)
      DiskBuf[0] := rsp
          
  elseif (DiskCmd == DSKCMD_PREPARE)
    DiskBlk := DiskBuf[0]
    ByteFill(@DiskBuf, $00, 512)
        
  elseif (DiskCmd == DSKCMD_WRITEBLK)
    rsp := WriteSector(DiskBlk, @DiskBuf)  
    if (rsp < 0)
      DiskStat := (DiskStat | DSKST_ERR)
      DiskBuf[0] := rsp

  'dbg.Str(string("ProcessDiskCmd: DiskStat="))
  'dbg.Hex(DiskStat,2)
  'dbg.NewLine
  

PRI InitCard

  Result := \sdc.Start(SD_BASE)
  'dbg.Str(string("sdc.Start:"))
  'dbg.Dec(Result)
  'dbg.NewLine

PRI ReadSector(Sector, Buffer)

  Result := \sdc.ReadBlock(Sector, Buffer)
  'dbg.Str(string("sdc.ReadBlock("))
  'dbg.Hex(Sector, 8)
  'dbg.Str(string("): "))
  'dbg.Dec(Result)
  'dbg.NewLine

PRI WriteSector(Sector, Buffer)    

  Result := \sdc.WriteBlock(Sector, Buffer)
  'dbg.Str(string("sdc.WriteBlock("))
  'dbg.Hex(Sector, 8)
  'dbg.Str(string("): "))
  'dbg.Dec(Result)
  'dbg.NewLine

PRI MsgNewLine
  dbg.NewLine
  dsp.process_char(13)
  dsp.process_char(10)

PRI MsgStr(StrPtr)
  dbg.Str(StrPtr)
  dsp.Str(StrPtr)

PRI MsgDec(Val)                  
  dbg.Dec(Val)
  dsp.Dec(Val)

PRI MsgHex(Val, Digits)
  dbg.Hex(Val, Digits)
  dsp.Hex(Val, Digits)  

PRI Timer
  TimerCount := SLEEP
  repeat
    waitcnt(clkfreq * 1 + cnt)
    if (TimerCount > 0)
      if (TimerCount == 1)
        dsp.VidOff
      TimerCount--

PRI Activity
  if (TimerCount == 0)
    dsp.VidOn
  TimerCount := SLEEP

{
PRI DumpBuffer(Buffer) | i, j

  repeat i from 0 to 31    
    dbg.Hex(i * 16, 4)
    dbg.Str(string(": "))
    repeat j from 0 to 15
      dbg.Hex((byte[Buffer][((i * 16) + j)]), 2)
      dbg.Str(string(" "))
    dbg.NewLine
}

DAT

{{                        N8VEM Ports


                    +------/WAIT
                    |+-----/RD
                    ||+---- A1
                    |||+--- A0
                    ||||+--/CS
                    |||||
                    |||||
   P15..P0  -->  xxxxxxxx_xxxxxxxx
                          +------+
                          D7....D0


   /RD  A1  A0  /CS
     0   0   0   0       Terminal Status                ' port $40 (IN)                                       
     1   0   0   0       Terminal Command               ' port $40 (OUT)
     0   0   1   0       Terminal Read Data (from kbd)  ' port $41 (IN)
     1   0   1   0       Terminal Write Data (to disp)  ' port $41 (OUT)                       
     0   1   0   0       Disk Status                    ' port $42 (IN)
     1   1   0   0       Disk Command                   ' port $42 (OUT)                                          
     0   1   1   0       Disk Read Data (from disk)     ' port $43 (IN)                     
     1   1   1   0       Disk Write Data (to disk)      ' port $43 (OUT)

}}

                        org 0

PortIO
                        or  outa, BitWait               ' deassert wait (high)
                        waitpeq BitCS, MaskCS           ' wait for CS to be deasserted (high)
                        mov dira, DirMask               ' tri-state data and set cntl for input

                        waitpeq Zero, MaskCS
                        andn outa, BitWait              ' assert wait (low)

                        mov TempAdr, ina                ' get input bits
                        shr TempAdr, #9                 ' /RD, A1, A0 -> bits 2,1,0
                        and TempAdr, #$07               ' isolate the 3 bits

                        add     TempAdr,#JmpTable
                        movs    JmpCmd,TempAdr
                        nop
JmpCmd                  jmp     #0-0
 
JmpTable                jmp     #TermStatus
                        jmp     #TermRead
                        jmp     #DiskStatus
                        jmp     #DiskRead
                        jmp     #TermCommand
                        jmp     #TermWrite
                        jmp     #DiskCommand
                        jmp     #DiskWrite
                   
TermCommand             ' receive terminal command byte from host
                        'andn dira, BitsData            ' set D0-D7 to input
                        'mov TempVal, ina               ' input byte from port
                        'wrbyte TempVal, TermStatusAdr  ' save status byte to global memory
                        jmp LoopRet

TermStatus              ' send terminal status byte to host
                        rdbyte TempVal, TermStatKbdAdr  ' get kbd status
                        mov outa, #0
                        or outa, TempVal                ' combine it
                        rdbyte TempVal, TermStatDspAdr  ' get display status
                        or outa, TempVal                ' combine it
                        xor outa, #TRMST_ACTMASK        ' convert 'active' bits to 'ready' bits for host
                        or dira, BitsData               ' set D0-D7 to output
                        jmp LoopRet

TermRead                ' return byte in key buf to host
                        rdbyte TempVal,TermKbdBufAdr    ' get the byte from the buffer
                        mov outa,TempVal                ' output byte to port
                        rdbyte TempVal, TermStatKbdAdr
                        or TempVal, #TRMST_KBDACT
                        wrbyte TempVal, TermStatKbdAdr
                        or dira, BitsData               ' set D0-D7 to output
                        jmp LoopRet

TermWrite               ' accept byte from host into screen buf
                        mov TempVal, ina                ' input byte from port
                        wrbyte TempVal,TermDspBufAdr    ' put the byte into the buffer
                        rdbyte TempVal, TermStatDspAdr  ' get current display status
                        or TempVal, #TRMST_DSPACT       ' set the active bit
                        wrbyte TempVal, TermStatDspAdr  ' store the updated status
                        jmp LoopRet
                        
DiskCommand             ' receive disk command byte from host
                        mov TempVal, ina                ' input command byte from port
                        wrbyte TempVal, DiskCmdAdr      ' store command byte to global memory
                        rdbyte TempVal, DiskStatAdr     ' get current disk status
                        or TempVal, #DSKST_ACT          ' set the active bit
                        wrbyte TempVal, DiskStatAdr     ' store updated disk status
                        mov DiskBufIdx, #0              ' reset buf index on any incoming command
                        jmp LoopRet

DiskStatus              ' send disk status byte to host
                        rdbyte TempVal, DiskStatAdr     ' get status byte from global memory
                        mov outa, TempVal               ' output byte to port
                        or  dira, BitsData              ' set D0-D7 to output
                        jmp LoopRet

DiskRead               ' send bytes from sector buffer to host
                        mov TempAdr,DiskBufAdr          ' get pointer to sector buffer
                        add TempAdr,DiskBufIdx          ' increment pointer by current index value
                        rdbyte TempVal,TempAdr          ' get the byte from the buffer
                        mov outa,TempVal                ' output byte to port
                        add DiskBufIdx,#1               ' increment index for the next read
                        or dira, BitsData               ' set D0-D7 to output
                        jmp LoopRet

DiskWrite               ' fill bytes of sector buffer from host
                        mov TempAdr,DiskBufAdr          ' get pointer to sector buffer
                        add TempAdr,DiskBufIdx          ' increment pointer by current index value
                        mov TempVal, ina                ' input byte from port
                        wrbyte TempVal,TempAdr          ' put the byte into the buffer
                        add DiskBufIdx,#1               ' increment the index for the next write
                        jmp LoopRet

TermStatKbdAdr          long    0
TermStatDspAdr          long    0
TermKbdBufAdr           long    0
TermDspBufAdr           long    0
DiskStatAdr             long    0
DiskCmdAdr              long    0
DiskBufAdr              long    0
DiskBufIdx              long    0

LoopRet                 long    PortIO

BitsData                long    $00FF
Zero                    long    $0000
MaskCS                  long    $0100
BitCS                   long    $0100
BitWait                 long    $1000
DirMask                 long    $1000

TempVal                 res     1
TempAdr                 res     1

                        fit