; **************************************************************
; * ayfx driver
; **************************************************************
; Based on the border driver here:
; https://gitlab.com/thesmog358/tbblue/-/blob/master/src/asm/border/border_drv.asm
;
; Uses Shiru's afyplay.a80 // http://shiru.untergrund.net
;
; The driver itself (ayfx.asm) must first be built.
;


; ***************************************************************************
; * Definitions                                                             *
; ***************************************************************************
; Pull in the symbol file for the driver itself and calculate the number of
; relocations used.

        include "build/ayfx.labels"

relocs  equ     (reloc_end-reloc_start)/2


; ***************************************************************************
; * .DRV file header                                                        *
; ***************************************************************************
; The driver id must be unique, so current documentation on other drivers
; should be sought before deciding upon an id. This example uses $7f as a
; fairly meaningless value. A network driver might want to identify as 'N'
; for example.
	device ZXSPECTRUMNEXT

        org     $0000

        defm    "NDRV"          ; .DRV file signature

        defb    $31+$80         ; DRIVER ID 0x31 assigned by Garry Lancaster
				; 7-bit unique driver id in bits 0..6
                                ; bit 7=1 if to be called on IM1 interrupts

        defb    relocs          ; number of relocation entries (0..255)

        defb    0         ; number of additional 8K DivMMC RAM banks
                                ; required (0..8); call init/shutdown
        ; NOTE: If bit 7 of the "mmcbanks" value above is set, .INSTALL and
        ;       .UNINSTALL will call your driver's $80 and $81 functions
        ;       to allow you to perform initialisation/shutdown tasks
        ;       (see border.asm for more details)

        defb    0               ; number of additional 8K Spectrum RAM banks
                                ; required (0..200)


; ***************************************************************************
; * Driver binary                                                           *
; ***************************************************************************
; The driver + relocation table should now be included.

        incbin  "build/ayfx.bin"

