@echo off
setlocal

if "%1" == "dist" goto :dist

::
:: Build [<platform> [<config> [<romname>]]]
::

set TOOLS=../../Tools

set PATH=%TOOLS%\tasm32;%TOOLS%\zxcc;%PATH%

set TASMTABS=%TOOLS%\tasm32

set CPMDIR80=%TOOLS%/cpm/

::
:: This PowerShell script validates the build variables passed in.  If
:: necessary, the user is prompted to pick the variables.  It then creates
:: an include file that is imbedded in the HBIOS assembly (build.inc).
:: It also creates a batch command file that sets environment variables
:: for use by the remainder of this batch file (build_env.cmd).
::

PowerShell -ExecutionPolicy Unrestricted .\Build.ps1 %* || exit /b

::
:: Below, we process the command file created by the PowerShell script.
:: This sets the environment variables: Platform, Config, ROMName,
:: & CPUType.
::

call build_env.cmd

::
:: Start of the actual build process for a given ROM.
::

echo.
echo ============================================================
echo %ROMName% for Z%CPUType% CPU
echo ============================================================
echo.

::
:: Create a small app that is used to export key build variables of the build.
:: Then run the app to output a file with the variables.  Finally, read the
:: file into variables usable in this batch file.
::

tasm -t80 -g3 -dCMD hbios_env.asm hbios_env.com hbios_env.lst || exit /b
zxcc hbios_env
zxcc hbios_env >hbios_env.cmd
call hbios_env.cmd

::
:: UNA is a special case, check for it and jump if needed.
::

if %Platform%==UNA goto :UNA

::
:: Determine proper variant of the NetBoot module to embed
::

if %Platform%==DUO (
    set NetBoot=netboot-duo.mod
) else (
    set NetBoot=netboot-mt.mod
)

::
:: Bring the previously build font files into this directory 
::

copy ..\Fonts\font*.asm . || exit /b

::
:: Build HBIOS Core (all variants)
::

tasm -t%CPUType% -g3 -dROMBOOT hbios.asm hbios_rom.bin hbios_rom.lst || exit /b
tasm -t%CPUType% -g3 -dAPPBOOT hbios.asm hbios_app.bin hbios_app.lst || exit /b
::tasm -t%CPUType% -g3 -dIMGBOOT hbios.asm hbios_img.bin hbios_img.lst || exit /b

::
:: Build ROM Components
::

call :asm dbgmon || exit /b
call :asm romldr || exit /b

call :asm eastaegg || exit /b
call :asm nascom || exit /b
:: call :asm tastybasic || exit /b
call :asm game || exit /b
call :asm usrrom || exit /b
call :asm updater || exit /b
call :asm imgpad2 || exit /b

:: Sysconf builds as both BIN and COM files
tasm -t%CPUType% -g3 -fFF -dROMWBW sysconf.asm sysconf.bin sysconf_bin.lst || exit /b
tasm -t%CPUType% -g3 -fFF -dCPM sysconf.asm sysconf.com sysconf_com.lst || exit /b

::
:: Create additional ROM bank images by assembling components into
:: 32K chunks which can be concatenated later.  Note that
:: osimg_small is a special case because it is 20K in size.  This
:: image is subsequently used to generate the .com loadable file.
::

copy /b romldr.bin + dbgmon.bin + ..\zsdos\zsys_wbw.bin + ..\cpm22\cpm_wbw.bin osimg.bin || exit /b
copy /b ..\Forth\camel80.bin + nascom.bin + ..\tastybasic\src\tastybasic.bin + game.bin + eastaegg.bin + %NETBOOT% + updater.bin + sysconf.bin + usrrom.bin osimg1.bin || exit /b

if %Platform%==S100 (
    zxcc slr180 -s100mon/fh || exit /b
    zxcc mload25 -s100mon || exit /b
    copy /b s100mon.com osimg2.bin || exit /b
) else (
    copy /b imgpad2.bin osimg2.bin || exit /b
)

copy /b romldr.bin + dbgmon.bin + ..\zsdos\zsys_wbw.bin osimg_small.bin || exit /b

::
:: Split off anything above 32K mark of the hbios. This will be relocated to rom bank 3
::

"%TOOLS%\srecord\srec_cat.exe" hbios_rom.bin -Binary -crop 0x8000 0x10000 -offset -0x8000 -o osimg2.bin -Binary || exit /b

::
:: Inject one byte checksum at the last byte of all 4 ROM bank image files.
:: This means that computing a checksum over any of the 32K osimg banks
:: should yield a result of zero.
::

for %%f in (hbios_rom.bin osimg.bin osimg1.bin osimg2.bin) do (
  "%TOOLS%\srecord\srec_cat.exe" %%f -Binary -Crop 0 0x7FFF -Checksum_Negative_Big_Endian 0x7FFF 1 1 -o %%f -Binary || exit /b
)

::
:: Create final images (.rom, .upd, & .com)
:: The previously created bank images are concatenated as needed.
::
:: The .rom image is made up of 4 banks followed by the ROM Disk.  This
:: is for programming onto a ROM.
::
:: The .upd image is the same as above, but without the the ROM Disk.
:: This is so you can update just the code portion of your ROM without
:: updating the ROM Disk contents.
::
:: The .com image is a scaled down version of the ROM that you can run
:: as a standard application under an OS and it will replace your
:: HBIOS on the fly for testing purposes.
::

if %ROMSize% gtr 0 (
    copy /b hbios_rom.bin + osimg.bin + osimg1.bin + osimg2.bin + ..\RomDsk\rom%ROMDiskSize%_wbw.dat %ROMName%.rom || exit /b
    copy /b hbios_rom.bin + osimg.bin + osimg1.bin + osimg2.bin %ROMName%.upd || exit /b
    copy /b hbios_app.bin + osimg_small.bin %ROMName%.com || exit /b
) else (
    copy /b hbios_rom.bin + osimg.bin + osimg1.bin + osimg2.bin  + ..\RomDsk\rom%RAMDiskSize%_wbw.dat %ROMName%.rom || exit /b
    copy /b hbios_rom.bin + osimg.bin + osimg1.bin + osimg2.bin %ROMName%.upd || exit /b
    copy /b hbios_app.bin + osimg_small.bin %ROMName%.com || exit /b
)

::
:: Copy results to output directory
::

if exist %ROMName%.rom copy %ROMName%.rom ..\..\Binary || exit /b
if exist %ROMName%.upd copy %ROMName%.upd ..\..\Binary || exit /b
if exist %ROMName%.com copy %ROMName%.com ..\..\Binary || exit /b

if exist sysconf.com copy sysconf.com ..\..\Binary\Apps\ || exit /b

goto :eof

::
:: UNA specific ROM creation
::

:UNA

::
:: This process is basically equivalent to the one above, but tailored
:: for the UNA BIOS.
::

:: Build ROM components required by UNA
call :asm dbgmon || exit /b
call :asm romldr || exit /b

:: Create the OS bank
copy /b romldr.bin + dbgmon.bin + ..\zsdos\zsys_una.bin + ..\cpm22\cpm_una.bin osimg.bin || exit /b

:: Copy OS Bank and ROM Disk image files to output
copy /b osimg.bin ..\..\Binary\UNA_WBW_SYS.bin || exit /b
copy /b ..\RomDsk\rom%ROMDiskSize%_una.dat ..\..\Binary\UNA_WBW_ROM%ROMDiskSize%.bin || exit /b

:: Create the final ROM image
copy /b ..\UBIOS\UNA-BIOS.BIN + osimg.bin + ..\UBIOS\FSFAT.BIN + ..\RomDsk\rom%ROMDiskSize%_una.dat %ROMName%.rom || exit /b

:: Copy to output
copy %ROMName%.rom ..\..\Binary || exit /b

goto :eof

::
:: Simple procedure to assemble a specified component via TASM.
::

:asm

echo.
echo Building %1...
tasm -t80 -g3 -fFF %1.asm %1.bin %1.lst || exit /b

goto :eof

::
:: Build all of the official distribution ROMs
::

:dist

call Build SBC std || exit /b
call Build SBC simh_std || exit /b
call Build MBC std || exit /b
call Build ZETA std || exit /b
call Build ZETA2 std || exit /b
call Build N8 std || exit /b
call Build MK4 std || exit /b
call Build RCZ80 std || exit /b
call Build RCZ80 kio_std || exit /b
call Build RCZ80 easy_std || exit /b
call Build RCZ80 tiny_std || exit /b
call Build RCZ80 skz_std || exit /b
call Build RCZ80 zrc_std || exit /b
call Build RCZ80 zrc_ram_std || exit /b
call Build RCZ80 zrc512_std || exit /b
call Build RCZ80 ez512_std || exit /b
call Build RCZ80 k80w_std || exit /b
call Build RCZ180 ext_std || exit /b
call Build RCZ180 nat_std || exit /b
call Build RCZ180 z1rcc_std || exit /b
call Build RCZ280 ext_std || exit /b
call Build RCZ280 nat_std || exit /b
call Build RCZ280 zz80mb_std || exit /b
call Build RCZ280 zzrcc_std || exit /b
call Build RCZ280 zzrcc_ram_std || exit /b
call Build SCZ180 sc126_std || exit /b
call Build SCZ180 sc130_std || exit /b
call Build SCZ180 sc131_std || exit /b
call Build SCZ180 sc140_std || exit /b
call Build SCZ180 sc503_std || exit /b
call Build SCZ180 sc700_std || exit /b
call Build GMZ180 std || exit /b
call Build DYNO std || exit /b
call Build RPH std || exit /b
call Build Z80RETRO std || exit /b
call Build S100 std || exit /b
call Build DUO std || exit /b
call Build HEATH std || exit /b
call Build EPITX std || exit /b
:: call Build MON std || exit /b
call Build NABU std || exit /b
call Build FZ80 std || exit /b
call Build UNA std || exit /b

goto :eof
