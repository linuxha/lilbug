       ;;
        ;;
        ;;
        ifndef ASCII_INC
ASCII_INC       equ 1
        ;; A list of callable routines
;* ASCII control characters.
NULL            equ $00
SOH             equ $01
STX             equ $02
ETX             equ $03
EOT             equ $04
ENQ             equ $05
ACK             equ $06
BS              equ $08
TAB             equ $09
LF              equ $0A
CR              equ $0D
NAK             equ $15
CAN             equ $18
ESC             equ $1B
SPC             equ $20
DEL             equ $7E
;
CASEMASK        equ $DF         ;Mask to make lowercase into uppercase.
        ENDIF
;/* Local Variables: */
;/* mode: asm        */
;/* End:             */
