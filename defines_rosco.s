; configuration
CONFIG_10A := 1

CONFIG_DATAFLG := 1
CONFIG_NULL := 1
CONFIG_PRINT_CR := 1 ; print CR when line end reached
CONFIG_SCRTCH_ORDER := 3
CONFIG_SMALL := 1
; CONFIG_OSI_UP5K := 1            ; Xark - iCE40-UP5K FPGA 65C02 SoC
CONFIG_OSI_ERRMSGFIX := 1       ; Xark - Fix graphic in errors
CONFIG_OSI_BACKSP := 1          ; Xark - Use normal backspace
CONFIG_OSI_GCBUGFUX := 1        ; Xark - Fix string GC bug
CONFIG_OSI_NOMATHMSG := 1       ; Xark - remove RAM BASIC string

; zero page
ZP_START1 = $00
ZP_START2 = $0D
ZP_START3 = $5B
ZP_START4 = $65

;extra ZP variables
USR             	:= $000A	; GORESTART

; constants
STACK_TOP		:= $FC
SPACE_FOR_GOSUB		:= $33
NULL_MAX		:= $0A
WIDTH			:= 72
WIDTH2			:= 72

; memory layout
RAMSTART2		:= $0300

