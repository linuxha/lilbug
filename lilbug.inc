;
opt             macro
                endm

nam             macro
                endm

noopt           macro
                endm

; This works but you need ttl "xyz abc" 
ttl             macro a
                TITLE a
                endm

spc             macro
                endm

list            macro
                listing on
                endm

nolist          macro
                listing off
                endm

page            macro
                newpage
                endm

PULD            macro
                PULA	; Pull the last thing off the stack
                PULB
                endm

PSHD            macro
                PSHB
                PSHA	; Pus the last thing on the stack
                endm

    warning "Just a test"
    message "And this is just a message"

; This doesn't work
;       IFNDEF   LDD
;LDD             macro
;                endm
;       ENDIF

;** FOR VDG, SET VDG = 0,
;** FOR NON-VDG, SET VDG = 1
VDG     EQU  1

;* FOR ON-CHIP IO, SET CHIPIO = 0
;* FOR ACIA TEST,  SET CHIPIO = 1
CHIPIO  EQU  0

;
        TITLE  "6801 DEBUG MONITOR"
        NAM    LILBUG
;
;* COMPILED APR 78 BY DIAMOND LIL FOR M6801

;*************** COMMANDS ****************
;* L   LOAD A PROGRAM FROM TAPE
;* L <OFFSET>  LOAD FROM TAPE WITH AN OFFSET
;* V   VERIFY THAT A PROGRAM WAS PROPERLY LOADED
;* V <OFFSET>  VERIFY PROGRAM LOADED WITH AN OFFSET
;* D X,Y DISPLAY MEMORY FROM X TO Y
;* P X,Y PUNCH CONTENTS OF MEMORY FROM X TO Y
;* M X    MEMORY EXAMINE/MODIFY
;*       <DATA> CHANGE 1 BYTE IN MEMORY TO <DATA>
;*       LF  INCR POINTER, PR ADR AND VALUE OF NEW PNTR
;*       SP  INCR PNTR, PR NEW VALUE ON SAME LINE
;*       ,   INCR PNTR, NO PR OF ADR OR VALUE
;*       UA  DECR PNTR, PR ADR AND VALUE AT PNTR
;*       /   PR ADR AND VALUE OF CURRENT PNTR
;*       CR  END MEMORY EXAMINE COMMAND
;* X/  SAME AS M X, X MUST START W/ 0-9, MAY NEED LEADING 0
;* /   PR ADR AND VALUE OF LOC LAST REF WITH MEM/EXAM
;* O X Y CALCULATE RELATIVE OFFSET FOR BRANCH INSTR
;* B   DISPLAY ALL BREAKPOINTS
;* B - DELETE ALL BREAKPOINTS
;* B X ENTER BREAKPOINT AT ADR X
;* B -X DELETE BREAKPOINT AT ADR X
;* G X EXECUTE USER PROG STARTING AT ADR X
;* G   EXECUTE USER PROG STARTING AT CURRENT PC
;* R  DISPLAY/CHANGE USER'S PROGRAM REGS
;* .  TRACE 1 INSTRUCTION
;* T X  TRACE X INSTRUCTIONS
;* C EXECUTE USER'S CODE AS SUBR, RTS TO MONITOR
;* C X XQT USER'S CODE AS SUBR START AT ADR X
;* HI SET HIGH SPEED - 120 CPS FOR ON-CHIP IO
;* HY SET HIGHER YET SPEED, FOR CRT - 9600 BD
;* CONTROL X - TERMINATE D OR T PRINT
;* CONTROL W - WAIT DURING D OR T PRT, ANY CHAR  
;*    CAUSES CONTINUATION OF PRINT
        PAGE
PIABD   EQU  $8012              ;* VDG PIA
ACIAS   EQU  $8CF4
ACIAD   EQU  $8CF5

CNTLW   EQU  $17                ;* WAIT CHARACTER
CNTLX   EQU  $18                ;* ABORT CHARACTER
;* ON-CHIP CLOCK EQUATES
P2DDR   EQU  $01                ;* PORT 2 DATA DIRECTION REG
CLOCK   EQU  $09                ;* TIMER 1
TCSR    EQU  $08                ;* TIMER CONTROL STATUS REG
OCREG   EQU  $0B                ;* OUTPUT COMPARE REG
;* ON-CHIP IO EQUATES
RMCR    EQU  $010               ;* RATE & MODE CONTROL
TRCS    EQU  $011               ;* TRANSMIT/RECEIVE CNTRL STAT REG
RECEV   EQU  $012               ;* READ REG
TRANS   EQU  $013               ;* TRANSMIT REG
;* MODE SELECT WORD
MODE    EQU  $03                ;* Mode Reg - UPPER 3 BITS = MODE

;* DEFAULT ADDRESS FOR PTM
PTMADR  EQU  $E000

;*************** RAM STORAGE ***************
;* Looks like 0x80-0xCF (79 bytes) for on chip stack
;* 
;* With Liebert there's ram at 2000-23FF (1024B)
;* I could open this to 2000-3FFF (8192B)
;* P8 - C000-DFFF (could put RAM here also)
;* P9 - E000-FFFF (ROM/ROM Emulator)
;*
    IFDEF EXTRAM
;*
	;error   "liebert.inc not created yet"
        fatal   "liebert.inc not created yet"
        include "liebert.inc"   ;* Need to create this
    ELSE
LOWRAM  EQU  $80                ;* USED FOR STK OVFLOW CHK
        ORG  $CF
STACK   RMB  1                  ;* STK PNTR WILL RUN UP TOWARD USER CODE
;*
;*
;*
        
CT      RMB  1                  ;* INPUT CHAR CT
CKSUM   EQU  CT                 ;* USED BY LOAD/VERF
STRTX   RMB  2                  ;* INPUT CHAR PTR (ON SATCK)
NEXTX   RMB  2                  ;* NEXT TABLE PTR
;* CHRNL - UPPER 6 BITS-# NULLS AFTER CR
;*         LOW 2 BITS-# NULLS AFTER CHAR
CHRNL   RMB  1                  ;* NUM NULLS AFTER CHAR
BBLK    RMB  1                  ;* BULK STORE BLK + NXT 4 LOC
PNTR    RMB  2                  ;* OPEN ADR
TEMPA   RMB  2
TEMP    RMB  1
;* TEMP AND OVFL MUST FOLLOW TEMPA
OVFL    RMB  1                  ;* OVERFLOW FLAG
SAVSTK  RMB  2                  ;* PC
        RMB  2                  ;* X
        RMB  1                  ;* A
        RMB  1                  ;* B
        RMB  1                  ;* CC
SPSAVE  RMB  2                  ;* STK
NUMBP   EQU  4                  ;* NUMBER OF BREAKPOINTS
BKADR   RMB  NUMBP*2            ;* BRKPNT ADDRESS
OPCODE  RMB  NUMBP
BRKFLG  RMB  1                  ;* BRKPNT IN
NTRACE  RMB  2                  ;* TRACE N INSTR
EXONE   RMB  1                  ;* XQT 1 INSTR FLAG
OUTSW   RMB  1                  ;* ECHO FLAG
CALLF   RMB  1                  ;* FLAG FOR C CMD
PTM     RMB  2                  ;* PTM ADDRESS
FCTPTR  RMB  2                  ;* POINTER TO FUNCTION TABLE
IOPTR   RMB  2                  ;* IO TABLE POINTER
VECPTR  RMB  2                  ;* VECTOR TABLE POINTER

    ENDIF
;/* Local Variables: */
;/* mode:asm         */
;/* End:             */
