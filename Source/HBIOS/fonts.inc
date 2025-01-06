;
;==================================================================================================
;   FONTS
;==================================================================================================
;
HB_FONTS_BEG	.EQU	$
;
ORG_FONTS	.EQU	$
;
	MEMECHO	"FONTS"
;
#IFDEF USEFONT8X8
FONT8X8:

; WE NEVER COMPRESS THE 8X8 FONT AS THERE IS NOT ENOUGH SPACE TO DECOMPRESS THEM AT WARM BOOT

  #IF USELZSA2 & FALSE
    #INCLUDE "font8x8c.asm"
  #ELSE
    #INCLUDE "font8x8u.asm"
  #ENDIF
	MEMECHO	" 8X8"
#ENDIF
;
#IFDEF USEFONT8X11
FONT8X11:
  #IF USELZSA2
    #INCLUDE "font8x11c.asm"
  #ELSE
    #INCLUDE "font8x11u.asm"
  #ENDIF
	MEMECHO	" 8X11"
#ENDIF
;
#IFDEF USEFONT8X16
FONT8X16:
  #IF USELZSA2
    #INCLUDE "font8x16c.asm"
  #ELSE
    #INCLUDE "font8x16u.asm"
  #ENDIF
	MEMECHO	" 8X16"
#ENDIF
;
#IFDEF USEFONTCGA
FONTCGA:
  #IF USELZSA2
    #INCLUDE "fontcgac.asm"
  #ELSE
    #INCLUDE "fontcgau.asm"
  #ENDIF
	MEMECHO	" CGA"
#ENDIF
;
#IFDEF USEFONTVGARC
FONTVGARC:
  #IF USELZSA2
    #INCLUDE "fontvgarcc.asm"
  #ELSE
    #INCLUDE "fontvgarcu.asm"
  #ENDIF
	MEMECHO	" VGARC"
#ENDIF
;
SIZ_FONTS	.EQU	$ - ORG_FONTS
		MEMECHO	" occupy "
		MEMECHO	SIZ_FONTS
		MEMECHO	" bytes.\n"
;
HB_FONTS_END	.EQU	$