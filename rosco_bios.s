;------------------------------------------------------------
;                            ___ ___ ___ ___ 
;  ___ ___ ___ ___ ___      |  _| __|   |__ |
; |  _| . |_ -|  _| . |     | . |__ | | | __|
; |_| |___|___|___|___|_____|___|___|___|___|
;                     |_____|      BASIC BIOS
;------------------------------------------------------------
; Copyright (c)2022-2024 Ross Bamford and contributors
; See top-level LICENSE.md for licence information.
;
; Initial bringup and basic testing code for the board.
;------------------------------------------------------------

.setcpu "65C02"
.debuginfo
.segment "BIOS"

; rosco_6502 defines

; * Low RAM        : $0000 - $3FFF (16KB)
; * Banked RAM     : $4000 - $BFFF (32KB in 16 banks)
; * IO             : $C000 - $DFFF (8KB)
; * ROM            : $E000 - $FFFF (8KB in 4 banks)
;
; The top byte of IO space ($DFFF) is the bank register.
;
; N.B. BANKSEL is active high!

; 65C02S ROM and RAM bank register (write-only, mirrored in BANKS)
BANK_SET    = $dfff         ; W [5:4] ROM bank, [3:0] RAM bank

; XR68C681P DUART registers
DUA_MR1A    = $c000         ; R/W
DUA_MR2A    = $c000         ; R/W
DUA_SRA     = $c001         ; R
DUA_CSRA    = $c001         ; W
DUA_MISR    = $c002         ; R
DUA_CRA     = $c002         ; W
DUA_RBA     = $c003         ; R (aka RHRA)
DUA_TBA     = $c003         ; W (aka THRA)
DUA_IPCR    = $c004         ; R
DUA_ACR     = $c004         ; W
DUA_ISR     = $c005         ; R
DUA_IMR     = $c005         ; W
DUA_CTU     = $c006         ; R/W
DUA_CTL     = $c007         ; R/W
DUA_MR1B    = $c008         ; R/W
DUA_MR2B    = $c008         ; R/W
DUA_SRB     = $c009         ; R
DUA_CSRB    = $c009         ; W
; reserved  = $c00A         ; R
DUA_CRB     = $c00A         ; W
DUA_RBB     = $c00b         ; R (aka RHRB)
DUA_TBB     = $c00b         ; W (aka THRB)
DUA_IVR     = $c00c         ; R/W
DUA_IP      = $c00d         ; R
DUA_OPCR    = $c00d         ; W
DUA_STARTC  = $c00e         ; R (start timer)
DUA_OPR_S   = $c00e         ; W (set GPIO OPn)
DUA_STOPC   = $c00f         ; R (stop timer)
DUA_OPR_C   = $c00f         ; W (clear GPIO OPn)

; DUART GPIO output usage
OP_RTSA     = $01           ; GPIO output UART A RTS
OP_RTSB     = $02           ; GPIO output UART B RTS
OP_SPI_CS   = $04           ; GPIO output SPI CS 1
OP_LED_R    = $08           ; GPIO output RED LED
OP_SPI_CLK  = $10           ; GPIO output SPI CLK
OP_LED_G    = $20           ; GPIO output GREEN LED
OP_SPI_MOSI = $40           ; GPIO output SPI MOSI
OP_SPI_CS2  = $80           ; GPIO output SPI CS 2
; DUART GPIO input usage
IP_CTSA     = $01           ; GPIO input UART A CTS
IP_CTSB     = $02           ; GPIO input UART B CTS
IP_SPI_MISO = $04           ; GPIO input SPI MISO

; memory bank map
BANK_RAM_AD = $4000         ; $4000 - $BFFF 16 x 32KB RAM banks BANK_SET[3:0]
BANK_RAM_SZ = $8000         ; 32KB RAM bank size
BANK_ROM_AD = $E000         ; $E000 - $FFFF 8KB or 4 x 8KB ROM  BANK_SET[5:4]
BANK_ROM_SZ = $2000         ; 8K ROM bank size

;*****************

; bios system globals
BANKS       = $200          ; mirror of BANK_SET
TICKCNT     = $201          ; tick counter (high bit is LED off/on)

BLINKCOUNT  = 50            ; ~100Hz interrupts between LED toggles

; rosco_6502 reset/init

ROSCO_RESET:
                sei
                cld
                ldx     #$ff
                txs

                ; Init DUART A
                lda     #$a0          ; Enable extended TX rates
                sta     DUA_CRA
                lda     #$80          ; Enable extended RX rates
                sta     DUA_CRA
                lda     #$80          ; Select bit rate set 2
                sta     DUA_ACR
                lda     #$88          ; Select 115k2
                sta     DUA_CSRA
                lda     #$10          ; Select MR1A
                sta     DUA_CRA
                lda     #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
                sta     DUA_MR1A
                lda     #$07          ; Normal, No TX CTX/RTS, 1 stop bit
                sta     DUA_MR2A
                lda     #$05          ; Enable TX/RX port A
                sta     DUA_CRA

                ; Init DUART B
                lda     #$a0          ; Enable extended TX rates
                sta     DUA_CRB
                lda     #$80          ; Enable extended RX rates
                sta     DUA_CRB
                lda     #$80          ; Select bit rate set 2
                sta     DUA_ACR
                lda     #$88          ; Select 115k2
                sta     DUA_CSRB
                lda     #$10          ; Select MR1B
                sta     DUA_CRB
                lda     #$13          ; No RTS, RxRDY, Char, No Parity, 8 bits
                sta     DUA_MR1B
                lda     #$07          ; Normal, No TX CTX/RTS, 1 stop bit
                sta     DUA_MR2B
                lda     #$05          ; Enable TX/RX port B
                sta     DUA_CRB

                ; Set up timer tick
                lda     #$F0          ; Enable timer XCLK/16
                sta     DUA_ACR

                ; Timer will run at ~100Hz: 3686400 / 16 / (1152 * 2) = 100
                lda     #$04          ; Counter MSB = 0x04
                sta     DUA_CTU
                lda     #$80          ; Counter LSB = 0x80
                sta     DUA_CTL
                lda     DUA_STARTC    ; Issue START COUNTER
                lda     #$08          ; Unmask counter interrupt
                sta     DUA_IMR

                lda     #BLINKCOUNT   ; Initial tick count
                sta     TICKCNT
                cli                   ; Enable interrupts
 
                ; Do the banner
                ldx     #$00          ; Start at first character
@banner_loop:
                lda     ROSCO_BANNER,x  ; Get character into A
                beq     @banner_done    ; If it's zero, we're done..
                jsr     CHROUT          ; otherwise, print it
                inx                     ; next character
                bra     @banner_loop    ; and continue
@banner_done:

@echo_test:
                jsr     CHRIN
                bcc     @echo_test
                cmp     #'X'
                bne     @echo_test

                jmp     COLD_START

ROSCO_BANNER:
.if 0
                .byte   $D, $A, $1B, "[1;33m"
                .byte   "                           ___ ___ ___ ___ ", $D, $A
                .byte   " ___ ___ ___ ___ ___      |  _| __|   |__ |", $D, $A
                .byte   "|  _| . |_ -|  _| . |     | . |__ | | | __|", $D, $A
                .byte   "|_| |___|___|___|___|_____|___|___|___|___|", $D, $A
                .byte   "                    |_____|", $1B, "[1;37m BASIC ", $1B, "[1;30m0.01.DEV", $1B, "[0m", $D, $A, $D, $A, 0
.else
                .byte   $D,$A, "Rosco_6502 - echo test, X for BASIC", $D, $A, 0
.endif

; *******************************************************
; Timer tick IRQ handler; Driven by DUART timer
; *******************************************************
ROSCO_IRQ:
                pha                     ; save A
                phx                     ; save X

                ldx     TICKCNT         ; Get tick count
                dex                     ; Decrement it
                txa                     ; copy new count to A
                asl                     ; shift out high bit
                bne     @done           ; if non-zero, we're done

                ; If here, time to toggle green LED

                lda     #OP_LED_G       ; Set up to bit 6 (LED G) to set/clear
                bcc     @turnon         ; if high bit was clear, turn on

                ; If here, LED is on
                ldx     #BLINKCOUNT     ; Reset tick count
                sta     DUA_OPR_C       ; Send command
                bra     @done
@turnon:
                ldx     #$80|BLINKCOUNT ; Reset tick count OR'd with on flag
                sta     DUA_OPR_S       ; Send command
@done:
                stx     TICKCNT         ; Store X as the new tick count
                lda     DUA_STOPC       ; Send "stop timer" command (reset ISR[3])

                plx                     ; restore X
                pla                     ; restore A
                rti

; BASIC load

LOAD:
                rts

; BASIC save
SAVE:
                rts


; Input a character from the serial interface.
; On return, carry flag indicates whether a key was pressed
; If a key was pressed, the key value will be in the A register
;
; Modifies: flags, A
MONRDKEY:
CHRIN:
                lda     DUA_SRA         ; read DUART status
                and     #$01            ; is RXRDY set (Bit 1 of DUART SRA)?
                beq     @no_keypressed  ; branch no char ready.
                lda     DUA_RBA         ; load character. 
                jsr     CHROUT		; echo
                sec                     ; indicate character read
                rts
@no_keypressed:
                clc                     ; indicate no character read
                rts

; Output a character (from the A register) to the serial interface.
;
; Modifies: flags
MONCOUT:
CHROUT:
                pha                     ; save character
@txdelay:
                lda     DUA_SRA         ; read DUART status
                and     #$04            ; is TXRDY set?
                beq     @txdelay        ; Loop if not ready (bit clear)
                pla                     ; restore character
                sta     DUA_TBA         ; send character
                rts

; .include "wozmon.s"

.segment "RESETVEC"
                .word   ROSCO_RESET     ; NMI vector
                .word   ROSCO_RESET     ; RESET vector
                .word   ROSCO_IRQ       ; IRQ vector

