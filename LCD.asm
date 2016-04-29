#include    "msp430.h"
; *****************************************************************************
; Description: Interface the microcontroller MSP430g2553 with an LCD 16X2
;               8-bit mode and write a simple message, my name.
;
;                -----------                   ----------
;               |msp430g2553|                 |   LCD    |
;               |           |                 |          |
;               |       P1.0|---------------->|D0        |
;               |       P1.1|---------------->|D1        |
;               |       P1.2|---------------->|D2        |
;               |       P1.3|---------------->|D3        |
;               |       P1.4|---------------->|D4        |
;               |       P1.5|---------------->|D5        |
;               |       P1.6|---------------->|D6        |
;               |       P1.7|---------------->|D7        |
;               |           |                 |          |
;               |       P2.0|---------------->|E         |
;               |           |         GND --->|RW        |
;               |       P2.1|---------------->|RS        |
;                -----------                   ----------
;
; *****************************************************************************
;------------------------------------------------------------------------------
;                   Declare DELAY Macro
;                   COUNT = Value to count up to
;------------------------------------------------------------------------------
delay       MACRO   COUNT
            mov.w   COUNT, TA0CCR0          ; Set Count limit
            bis.w   #GIE+LPM0, SR           ; enable interrupts and go to
                                            ; Low power mode
            nop
            ENDM

;------------------------------------------------------------------------------
;                   Declare WRITE Macro
;                   CHAR = ASCII value of character to write in LCD
;                   R14  = (CHARACTER) DATUM to pass to the LCD
;------------------------------------------------------------------------------
lcdwrt      MACRO   CHAR
            bis.b   #02h, &P2OUT            ; Turn on REGISTER SELECT
            mov.b   CHAR, R14               ; Load character CHAR
            call    #WRT_CMD_LCD            ; Write charater CHAR to LCD
            ENDM

;------------------------------------------------------------------------------
;                   Declare COMMAND Macro
;                   CMD = COMMAND to send the LCD
;                   R14 = (COMMAND) DATUM to pass to the LCD
;------------------------------------------------------------------------------
lcdcmd      MACRO   CMD
            bic.b   #02h, &P2OUT            ; Turn off REGISTER SELECT
            mov.b   CMD, R14                ; Load command CMD
            call    #WRT_CMD_LCD            ; Send command CMD to LCD
            ENDM

;------------------------------------------------------------------------------
            ORG     0C000h                  ; Program Start
;------------------------------------------------------------------------------
RESET       mov.w   #0280h, SP              ; Initialize Stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD, &WDTCTL ; Stop WDT

;------------------------------------------------------------------------------
;                   Configure Timer
;------------------------------------------------------------------------------
            bis.b   #LFXT1S_2,&BCSCTL3      ; ACLK = VLO (Very Low Clock 12KHz)
                                            ; setting bits 4 and 5 (LFXT1S) to 2
                                            ; in the Basic Clock
                                            ; System Control Register 3 (BCSCTL3)
            mov.w   #CCIE, &CCTL0           ; Enable CCR0 interrupts
            mov.w   #TASSEL_1+MC_1, &TA0CTL ; Use ACLK, up-mode

;------------------------------------------------------------------------------
;                   Configure Ports
;------------------------------------------------------------------------------
            bis.b   #0FFh, &P1DIR           ; Set all ports of P1 as output
                                            ; For use with the LCD 16X2
                                            ; In 8-bit mode
            bis.b   #03h, &P2DIR            ; Set P2.0 and P2.1 as output
                                            ; For use as ENABLE and
                                            ; REGISTER SELECT of the LCD 16X2

;------------------------------------------------------------------------------
;                   Initialize LCD
;------------------------------------------------------------------------------
            bic.b   #01h, &P1OUT            ; Turn off ENABLE
            delay   #180                    ; Delay of 15ms
            lcdcmd  #030h                   ; Send command to Wake LCD #1
            delay   #60                     ; Delay of 5ms
            lcdcmd  #030h                   ; Send command to Wake LCD #2
            delay   #2                      ; Delay of ~160u
            lcdcmd  #030h                   ; Send command to Wake LCD #3
            delay   #2                      ; Delay of ~160u
            lcdcmd  #038h                   ; Send command to set 8-bit/2-line
            lcdcmd  #0Ch                    ; Send command to Turn on the
                                            ; Display and do not show Cursor
            lcdcmd  #06h                    ; Send command Entry mode set
            lcdcmd  #01h                    ; Send command to Clear Display
            delay   #180                    ; Delay of 15ms
                                            ; Wait until LCD is stable

;------------------------------------------------------------------------------
;                   Show Message
;------------------------------------------------------------------------------
            mov.w   #MSGNAME, R13           ; Load Cstring of my name message
            call    #WRITEMSG               ; Write message
            jmp     $

;------------------------------------------------------------------------------
;                   SUBROUTINES
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
;                   LCD - Write 1 line string Message
;------------------------------------------------------------------------------
;                   R13 = Pointer to message Cstring
;------------------------------------------------------------------------------
WRITESTR    lcdwrt  @R13+                   ; Write charater to LCD
            cmp.b   #00h, 0(R13)            ; Is this the null character?
            jnz     WRITESTR                ; If it's not, continue loop
            ret

;------------------------------------------------------------------------------
;                   LCD - Write 2 line Message
;------------------------------------------------------------------------------
;                   R13 = Pointer to message Cstring
;------------------------------------------------------------------------------
WRITEMSG    lcdcmd  #01h                    ; Send command to Clear Display
            delay   #180                    ; Delay of 15ms
                                            ; Wait until LCD is stable
            call    #WRITESTR               ; Write first line
            lcdcmd  #0C0h                   ; Send command to move cursor 2nd LN
            inc     R13                     ; Fetch next Cstring
            call    #WRITESTR               ; Write second line
            ret

;------------------------------------------------------------------------------
;                   LCD - WRITE_OR_COMMAND Subroutine
;------------------------------------------------------------------------------
;                   P2.0 = ENABLE
;                   P2.1 = RESGISTER SELECT
;                   R14  = (DATUM) COMMAND/CHARACTER
;------------------------------------------------------------------------------
WRT_CMD_LCD mov.b   R14, &P1OUT             ; Load COMMAND/CHARACTER in Port 1

            bis.b   #01h, &P2OUT            ; Turn on ENABLE
            nop                             ; Small Delay - Delay >= 300ns
            bic.b   #01h, &P2OUT            ; Turn off ENABLE

            mov.w   0(R4), 0(R4)            ; Delay - 6 cycles, 3 words
            ret

;------------------------------------------------------------------------------
;                   ISR of TA0 - Delay
;------------------------------------------------------------------------------
TA0CCR0_ISR mov.w   #0, TA0CCR0             ; Stop Timer
            bic.w   #GIE+LPM0, 0(SP)        ; Disable interrupts and
                                            ; Get out of Low power mode
            reti

;------------------------------------------------------------------------------
;                   Static Message - Cstring
;------------------------------------------------------------------------------
MSGNAME     DB      "Mario Orbegoso",  "Villanueva"

;------------------------------------------------------------------------------
;                       Interrupt Vectors
;------------------------------------------------------------------------------
            ORG     0FFFEh                  ; MSP RESET Vector
            DW      RESET                   ; Address of label RESET
            ORG     0FFF2h                  ; Interrupt vector (TA0CCR0 CCIFG)
            DW      TA0CCR0_ISR             ; Timer TA0 interrupt subrutine
            END
