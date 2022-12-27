	;MACEXP  off
        CPU     6301            ; That's what asl has
;**[ lilbug for the Liebert ]*******************************
;*
;* Lilbug was originally written for a 6801 EVB with no extra
;* RAM and direct serial access. There seems to be an code
;* support for a VDG (6847), PTM (6840) and PIA (682x).
;*
;* So registers from 0x0-0x20, internal RAM from 0x80-0xFF (128B)
;* and the ROM at E000-FFFF (interrupt/reset vectors at FFF0)
;*
;* The Liebert board has no such external devices (PTM etc.).
;* It has 1K of RAM at 2000, unknown devices at 4000, 6000, 8000
;* and A000, ROM at C000-DFFF (P8) and ROM at E000-FFFF (P9).
;* The internal registers and RAM remain the same.
;*
;***********************************************************
;	CPU:		Motorola 6803 (6801/6803 family)
;*
	include "lilbug.inc"

        ORG  $F800

;* JUMP TABLE TO SUBROUTINES
EX.NMI  JMP  M.NMI              ; NMI VECTOR FOR PTM
IN.NMI  JMP  C.NMI              ; NMI VECTOR FOR INTERNAL RESOURCES
INCHNP  JMP  INCH1              ; INPUT 1 CHAR W/ NO PARITY
OUTCH   JMP  OUTCH1             ; OUTPUT 1 CHAR W/PADDING
        JMP  PDATA1             ; PRINT DATA STRING
        JMP  PDATA              ; PR CR/LF, DATA STRING
        JMP  OUT2HS             ; PR 2 HEX + SP (X)
        JMP  OUT4HS             ; PR 4 HEX + SP (X)
        JMP  PCRLF              ; PRINT CR/LF
        JMP  SPACE              ; PRINT A SPACE
STRT    JMP  START              ; RESTART ADDRESS
IN.SWI  JMP  M.SWI              ; SWI VECTOR

;***** FUNCTION JUMP TABLE *****
;* BESIDES THIS INTERNAL COMMAND TABLE THERE MAY
;*   BE AN EXTERNAL TABLE OF THE SAME FORMAT
;*   'FCTPTR' POINTS TO THE TABLE TO
;*   BE SEARCHED FIRST. WITH EXERNAL VECTORS,
;*   THE USER CAN DEFINE THE RESET VECTOR
;*   AND DO HIS OWN INITIALIZATION - DEFINE A
;*   COMMAND TABLE, SET FCTPTR - BEFORE JUMPING
;*   TO THE MONITOR INITIALIZATION.
;*
;* EACH ENTRY IN THE FUNCTION JUMP TABLE IS 
;*   ORGANIZED AS FOLLOWS:
;*     FCB   XXX   XXX=TOTAL SIZE OF ENTRY
;*     FCC   /STRING/ WHERE STRING IS THE INPUT STRING
;*     FDB   ADDR     WHERE ADDR IS THE ROUTINE ADDRESS
;*
;* THE LAST ENTRY IS:
;*     -1  =  END OF EXTERNAL TABLE - GO SEARCH
;*            INTERNAL TABLE.
;*     -2  =  END OF TABLE(S)
;*
;* NOTE: AN EXTERNAL FUNCTION TABLE TERMINATED BY
;*   -1, THE INTERNAL TABLE WILL ALSO BE SEARCHED.
;*   IF TERMINATED BY -2, INTERNAL TABLE NOT CHECKED.
;*
FCTABL  EQU  *

        FCB  4                  ;* *
        FCC  "B"                ;* *
        FDB  BRKPNT

        FCB  4                  ;* *
        FCC  "C"
        FDB  CALL

        FCB  4
        FCC  "D"
        FDB  DISPLY

        FCB  4                  ;* *
        FCC  "G"
        FDB  GOXQT

        FCB  4                  ;* *
        FCC  "L"
        FDB  LOAD

        FCB  4                  ;* *
        FCC  "M"                ;* *
        FDB  MEMORY

        FCB  4                  ;* *
        FCC  "O"
        FDB  OFFSET

        FCB  4                  ;* *
        FCC  "P"
        FDB  PUNCH

        FCB  4                  ;* *
        FCC  "R"
        FDB  REGSTR

        FCB  5
        FCC  "HI"
        FDB  S120

        FCB  5
        FCC  "HY"
        FDB  HY

        FCB  4                  ;* *
        FCC  "T"
        FDB  TRACE
	
        FCB  4                  ;* *
        FCC  "V"
        FDB  VERF

        FCB  -2                 ;* *END OF TABLE

;**************** IO TABLE ***************
;* ROUTINE IO IS CALLED WITH
;* INDEX INTO IO TABLE CI OR INTO USER IO TABLE
;* IOPTR POINTS TO THE IO TABLE TO BE USED
;* THE INDEX TABLE DEFINES ORDER OF IO ROUTINES IN IO TABL
CI      FDB  CION,CIDTA,CIOFF
        FDB  COON,CODTA,COOFF
        FDB  HSON,HSDTA,HSOFF
        FDB  BSON,BSDTA,BSOFF

;* THE FOLLOWING ARE INDICES INTO IO TABLE
CI.ON   EQU  0               ;* INIT INPUT DEVICE
CI.DTA  EQU  2               ;* INPUT A CHAR W/NO WAIT
CI.OFF  EQU  4               ;* DISABLE INPUT DEVICE
CO.ON   EQU  6               ;* INIT OUTPUT DEVICE
CO.DTA  EQU  8               ;* OUTPUT A CHAR W/PADDING
CO.OFF  EQU  $A              ;* DISABLE OUTPUT DEVICE
HS.ON   EQU  $C              ;* INIT HIGH SPEED OUTPUT DEVICE
HS.DTA  EQU  $E              ;* OUTPUT BLOCK OF DATA
HS.OFF  EQU  $10             ;* DISABLE HIGH SPEED DEVICE
BS.ON   EQU  $12             ;* INIT TAPE DEVICE
BS.DTA  EQU  $14             ;* WRITE BLOCK OF DATA TO TAPE
BS.OFF  EQU  $16             ;* DISABLE TAPE DEVICE
;*
;************** INCH **************
;* CALL IO ROUTINE W/ INDEX TO INPUT DATA
;* CLEARS PARITY
;* IGNORES RUBOUT CHAR
;* ECHOES OUTPUT IF FLAG CLEAR
;* SAVE, RESTORE REG B
INCH1   PSHB
INCH15  LDAB #CI.DTA            ;* OFFSET TO CIDTA
INCH2   BSR  IO                 ;* SCAN IO DEVICE
        BCC  INCH15             ;* LOOP ON NO WAIT INPUT
        ANDA #$7F               ;* CLEAR PARITY
        BEQ  INCH15             ;* IGNORE NULLS
        CMPA #$7F               ;* RUBOUT?
        BEQ  INCH15             ;
        LDAB OUTSW              ;* CHK IF ECHO
        BNE  INCH4              ;
        BSR  OUTCH1             ;* ECHO INPUT
INCH4   PULB
        RTS

;*************** OUTCH ***************
;* CALL IO ROUTINE W/ INDEX TO OUTPUT DATA
;* SAVES, RESTORES REG B
OUTCH1  PSHB
        LDAB #CO.DTA            ;* PNTR TO OUTPUT A CHAR W/PADDING
        BSR  IO
        PULB
        RTS

;*************** CIDTA ***************
;* READ 1 CHAR FROM INPUT W/ NO WAIT
;* RETURN W/ C CLEAR IF NO READ
;*     ELSE REG A = INPUT & C IS SET
CIDTA   LDAA TRCS               ;* GET CONTROL WORD
        ASLA                    ;* CHK THAT RDRF IS SET
        BCS  CIDTA1             ;* READ DATA IF SET
        ASLA                    ;* LOOK AT ERR BIT
        BCC  CIDTA2             ;* RTN W/C CLR IF NO READ
;* IF FRAMING ERR OR OVER RUN-READ
CIDTA1  LDAA RECEV              ;* READ
;* RETURN W/CARRY SET & LDAA BITS SET
        SEC                     ;* FLAG READ-NO WAIT ACOMPLISHD
CIDTA2  RTS

;********** CODTA **********
;* OUTPUT CHAR FROM REG A
;* OUTC - SUBR CALLED BY CODTA
;* EXPECT 30 OR 120 CPS
;* DEFAULT SPEED = 30 CPS
;* PADS CR AND CHAR FOR 120
;* PAD 4 NULLS IF PUNCH CR
OUTC    PSHB
OUTC1   LDAB TRCS               ;* GET CONTRL WRD
        BITB #$20               ;* TDRE SET?
        BEQ  OUTC1              ;* WAIT UNTIL IT IS
        STAA TRANS
        PULB
CRTN    RTS

CODTA   BSR  OUTC               ;* OUTPUT CHAR
        LDAB OUTSW              ;* GET TAPE FLAG
        BNE  N1
        LDAB CHRNL              ;* NOT TAPE
N1      CMPA #$D                ;* CR
        BEQ  N3
        CMPA #$10               ;* NO PADDING IF DLE
        BEQ  CRTN
        ANDB #$3                ;* MASK OUT HIGH 6-BIT CNTR
        BRA  N4
N3      LSRB                    ;* REMOVE LOW 2-BIT CNTR
        LSRB
N4      DECB                    ;* DECR NULL CNTR
        BMI  CRTN               ;* EXIT IF ENOUGH NULLS
        PSHA
        CLRA
        BSR  OUTC               ;* OUTPUT NULL
        PULA
        BRA  N4                 ;* PR NXT NULL

;*************** CION ***************
;* INITIALIZE ON-CHIP SERIAL IO
CION    EQU  *
;*
    IFDEF DEF9600
        ;* Baud rate to 9600
        ;* Set padding to Zero
        LDD  #$0005             ;* SET PADDING FOR 9600
    ELSE
        ;* Baud rate 300
        ;* Set padding to 1 null after CR
        LDD  #$1007             ;* SET PADDING FOR 300
    ENDIF
;*
        BSR  S1205              ;* SET RMCR
        LDAA #$0A               ;* SET TRCS FOR ON-CHP IO
        STAA TRCS
;* NO ACTION NEEDED BY THESE DEVICES
CIOFF   EQU  *                  ;* TURN CONSOLE IN OFF
HSON    EQU  *                  ;* TURN ON HIGH SPEED
HSOFF   EQU  *                  ;* TURN OFF HIGH SPEED
COOFF   RTS

;*************** COON ***************
;* INITIALIZE OUTPUT DEVICE-SILENT 700 PRT
;* TURN ON TI PRINTER
COON    LDX  #PRTON             ;* ACTIVATE ACD
COON2   JSR  PDATA1
;* ENTRY FROM BSOFF FOR DELAY AFTER TURN OFF PUNCH
DELAY   LDX  #$411B             ;* 100 MS DELAY
DLY     DEX
        BNE  DLY
        RTS
;*
;*************** IO ROUTINE ***************
;* THIS ROUTINE USES INDEX TO RETRIEVE IO
;* ROUTINE ADR FROM IO TABLE, THEN CALL AS SUBR
;* REG B IS INDEX INTO IO TABLE
;* TO DO IO, REG B IS SET, IO ROUTINE IS CALLED
;* SAVES REG X
IO      PSHX
        LDX  IOPTR              ;* ADR OF IO TABLE
        ABX                     ;* ADD OFFSET
        LDX  0,X                ;* GET IO ROUTINE ADR
        JSR  0,X                ;* DO IO
        PULX
        RTS

;* xx xx CC1 CC0 SS1 SS0
;*
;* CC1 | CC0 | Format   | Source   | P2b2
;*  0  |  0  | Bi-phase | Internal | Not used
;*  0  |  1  | NRZ      | Internal | Not used
;*  1  |  0  | NRZ      | Internal | Output
;*  1  |  1  | NRZ      | External | Input
;*
;*
;* SS1 | SS0 | Notes
;*  0  |  0  | 76800 baud
;*  0  |  1  |  9600 baud
;*  1  |  0  |  1200 baud
;*  1  |  1  |   300 baud
;*
;* $06 = 0110 - NRZ/Internal/Not used/1200
;* $05 = 0101 - NRZ/Internal/Not used/9600
;*
;************** HY / HI *************
;* HY & HI SET CHRNL FLAG FOR PADDING
;* LOW  2 BITS = NUM NULLS AFTER CHAR
;* HIGH 6 BITS = NUM NULLS AFTER CR
;*  SPC
;************** HI **************
;* SET SPEED FOR 120 CPS
;* SET # NULLS TO PAD CHAR
;* SET BITS FOR 1200 BAUD IN RMCR
S120    LDD  #$4F06
S1205   STAA CHRNL
        STAB RMCR               ;* SET BAUD RATE
        RTS

;*************** HY ***************
;* HIGHER YET - 9600 BAUD ON CRT
;* SET PADDING TO ZERO
HY      LDD  #$0005             ;* ALSO SET RMCR
        BRA  S1205
                                ;* PAGE
;********** RESET **********
;* COME HERE FOR MONITOR RESTART
;* INIT IO & FCN TABLE POINTERS
;* TURN ON CONSOLE
;* PRINT MONITOR NAME
;* INIT RAM USED BY MONITOR
;* MASK I BIT IN USER CC
;* SET INITIAL SPEED
;* INIT HARDWARE TRACE DEVICE
START   LDS  #STACK             ;* INIT STK PNTR
        LDX  #CI                ;* INIT I/O PNTR TABLE
        STX  IOPTR              ;
        LDX  #SERIAL            ;* INIT VECTOR TABLE POINTER
        STX  VECPTR
        LDX  #FCTABL            ;* INIT FUNCTION TABLE PTR
;*                              ;*
        STX  FCTPTR 		;* Note this can be overridden to point to your own table! :-)
;*                              ;*
        LDX  #PTMADR            ;* SET ADR FOR PTM
        STX  PTM
        LDS  #STACK-20          ;* RESET INCASE USER DIDN'T
        STS  SPSAVE             ;* INIT USER STACK
        LDS  #STACK             ;* RESET MONITOR STK
        LDX  #BKADR             ;* ZERO BKADR TO OVFL
CLRAM   CLR  0,X 
        INX
        CPX  #CALLF+1
        BNE  CLRAM 
        CLRB                    ;* OFFSET FOR CION
        BSR  IO                 ;* TURN ON CONSOLE IN
        LDAB #CO.ON             ;* OFFSET FOR COON
        BSR  IO                 ;* TURN ON CONSOLE OUTPUT
        LDX  #LIL               ;* PR LILBUG
        JSR  PDATA              ;* WITH CR/LF
        LDAA #$D0               ;* MASK I IN CC
        STAA SAVSTK+6


;* INIT FOR HARDWARE TRACE -
;*    CLOCK OR PTM
        JSR  IFPTM
        BEQ  INPTM              ;* GO INIT PTM
;* INIT ON-CHIP CLOCK
        CPX  #IN.NMI            ;* MAY NOT WANT ANY TRACE
        BNE  MAIN               ;* IF NMI NOT SET-NO TRACE
        INC  TCSR               ;* SET OLVL BIT HI
        BRA  MAIN
;* INIT PTM - SINGLE SHOT, 8 BIT
;* USER MUST SET NMI VCTR FOR PTM TRACE
;* MONITOR CHK IF VCTR SET
INPTM   LDX  PTM                ;* GET PTM ADDRESS
        CLR  2,X                ;* SET LATCH FOR BRING OUT
        CLR  3,X                ;* OF RESET, MAKE G HI
        LDD  #$0122
        STAA 1,X                ;* SET TO WRITE TO CR1
        STAB 0,X                ;* BRING OUT OF RESET
        LDD  #$A600             ;* SET SINGLE SHOT MODE
        STD  0,X                ;* ALSO SET NO WRITE TO CR1
;* 
;*************** MAIN ***************
;* PROMPT USER
;* READ NEXT COMMAND
;*
MAIN    LDS  #STACK
        CLR  OUTSW              ;* MAKE SURE INPUT IS ECHOED
        JSR  PCRLF              ;* PRINT CR/LF
        LDAA #$21               ;* '!
        JSR  OUTCH
        JSR  INPUTA             ;* A-F ALPHA
        BMI  MAIN               ;* ABORT
        BEQ  MAIN01 
;* HEX VALIDITY CHK
        JSR  VALIN 
        BMI  MAIN               ;* <ADR>/ VALID?
        LDX  #MEM01             ;* ENTER MEMORY ROUTINE
        BRA  MAIN08             ;* SET UP FOR RTN
;* A CONTAINS FIRST INPUT CHARACTER
MAIN01  LDX  #NEXT              ;* CHK FOR TRACE 1
        CMPA #$2E               ;* '. QUICK TRACE
        BEQ  MAIN08
        LDX  #MEMSL             ;* CHK FOR /
        CMPA #$2F               ;* '/ QUICK MEM EXAMINE
        BEQ  MAIN08
;*
;* READ IN STRING. PUSH STRING UNTO THE
;*   STACK. MARK TOP OF STRING IN 'STRTX'
;*
        STS  STRTX              ;* SAVE PTR TO INPUT STRING
        CLR  CT                 ;* INPUT CHAR CT
MAIN03  BSR  TERM               ;* CHECK FOR TERMINATORS
        BEQ  SRCH               ;* GOT ONE,GO DO COMPARES
        INC  CT                 ;* CT + 1 -> CT
        PSHA                    ;* SAVE INPUT CHAR ON STACK
        TSX                     ;* CHECK STACK POINTER
        CPX  #LOWRAM
        BEQ  MERROR    		;* CHK IF END OF STK
        JSR  INPUTA    		;* GO GET NEXT CHAR
        BMI  MAIN07    		;* ESCAPE
        BNE  MERROR    		;* NBRS ARE NOT ALLOWED
        BRA  MAIN03    		;* LOOP
;*
;* HERE AFTER STRING WAS INPUT. CHECK IT AGAINST
;*   STRINGS IN THE EXTERNAL AND/OR INTERNAL
;*   FUNCTION TABLES. STRTX POINTS TO THE
;*   INPUT STRING. FCTPTR POINTS TO THE START
;*   OF THE FIRST TABLE TO SEARCH (EXTERNAL OR
;*   INTERNAL).
;*
SRCH    STAA BBLK        ;* LOCAL VAR - SAVE DELIMITER
        LDX  FCTPTR      ;* GET PTR TO TABLE
        STX  NEXTX       ;* SAVE IN TEMP
SRCH01  LDX  NEXTX       ;* GET NEXT PTR INTO TABLE
        PSHX             ;* SAVE A COPY ON STACK
        LDAB 0,X         ;* GET ENTRY SIZE
        ABX              ;* CALCULATE ADDR OF NEXT ENTRY
        STX  NEXTX       ;* SAVE FOR NEXT SEARCH
        SUBB #3          ;* SUB OFF ADDR SIZE
        CMPB CT          ;* IS INPUT LENGTH=ENTRY LENGTH?
        BEQ  SRCH03      ;* YES,A POSSIBLE MATCH
;* NO MATCH ON THIS ENTRY
;* CHECK FOR TABLE TERMINATORS
;* -1 = END OF EXTERNAL TABLE
;* -2 = END OF TABLE(S)
;* IF NOT -1 OR -2, NOT RECOGNIZE END OF TABLE
;* B IS ALLREADY TERM-3
        PULX                    ;* CLEAN STACK
        CMPB #-4                ;* END OF EXTERNAL TABLE?
        BNE  SRCH02             ;* NO
;* SWITCH FROM EXT TO INT TABLE
        LDX  #FCTABL            ;* GET INNER TABLE
        STX  NEXTX
SRCH02  CMPB #-5                ;* END OF TABLE SEARCH?
        BNE  SRCH01             ;* NO,KEEP TRUCKIN
;* INPUT STRING NOT FOUND ! GO GRIPE
;* HERE ON ERROR. PRINT ? AND
;*   GO BACK TO MAIN START
MERROR  LDX  #QMARK
        JSR  PDATA
MAIN07  BRA  MAIN
;*
;* INPUT LENGTH=TABLE ENTRY LENGTH. TRY
;*   FOR A MATCH. B=SIZE; (SP) = TABLE PTR
;*
SRCH03  LDX  STRTX              ;* INIT PTR TO INPUT STRING
        STX  TEMPA
SRCH04  PULX                    ;* RESTORE CURRENT TABLE PTR
        INX 
        LDAA 0,X                ;* GET TABLE CHAR
        PSHX                    ;* SAVE FOR NEXT LOOP
        LDX  TEMPA              ;* GET INPUT PTR
        CMPA 0,X                ;* INPUT CHAR=TABLE CHAR?
        BEQ  SRCH05             ;* YES
        PULX                    ;* NO,CLEAN STAACK
        BRA  SRCH01             ;* GET NEXT TABLE VALUE
;* HERE WHEN A CHARACTER MATCHED
SRCH05  DEX                     ;* DEC INPUT PTR FOR NEXT TIME
        STX  TEMPA
        DECB                    ;* COMPARED ALL CHARS?
        BNE  SRCH04
;*
;* WE HAVE A MATCH! GO TO THE ROUTINE
;*
        PULX                    ;* GET TABLE PTR
        INX                     ;* POINT TO ADDRESS IN TABLE
        LDS  STRTX              ;* CLEAN STACK
        LDX  0,X                ;* GET ROUTINE ADDRESS
        LDAA BBLK               ;* LOAD TERMINATOR
MAIN08  JSR  0,X                ;* GO TO ROUTINE
        BMI  MERROR             ;* ERROR RETURN
        BRA  MAIN07             ;* GO BACK TO MAIN
;********** TERMINATOR SUB
;*
;* CHECK INPUT CHAR FOR A TERMINATOR
;*   TERMINATORS ARE: , BLANK <CR>
;*   CHAR IN A ON CALL
;*   Z BIT SET ON EXIT IFF CHAR WAS
;*   TERMINATOR
;***********
TERM    CMPA #','               ;* COMMA?
        BEQ  TERM02
        CMPA #' '               ;* BLANK?
        BEQ  TERM02
        CMPA #$D                ;* CR?
        BEQ  TERM02
        CMPA #'-'               ;* ALLOW MINUS
TERM02  RTS                     ;* RETURN WITH Z BIT 
;*

;*************** VALIN ***************
;* VALIDATE INPUT - ENTRY VALINP READS INPUT
;* ALLOW 4 DIGIT INPUT W/LEADING 0'S NOT COUNT
;* SET CC NEG IF ERROR
VALINP  BSR  INPUT              ;* READ HEX
VALIN   BLE  VALRTN
        CMPB #4
        BLE  INPUTC
        TST  OVFL               ;* LEADING ZEROES?
        BEQ  INPUTC
        COMB                    ;* SET C NEG FOR ERR RTN
VALRTN  RTS

;*****INPUT - READ ROUTINE
;* INPUT ENTRY SET B=0, READ A-F AS HEX
;* INPUTA ENTRY SET B#0, READ A-F AS ALPHA
;* X= HEX NUMBER (ALSO IN TEMPA)
;* A=LAST CHAR READ (NON-HEX)
;* B= # HEX CHAR READ (TEMP)
;* OVFL # 0 IF OVERFLOW FROM LEFT SHIFT
;* CC SET FROM LDAB BEFORE RETRN
;* CC SET NEG IF ABORT
INPUTA  LDAB #$F0               ;* READ A-F AS ALPHA
        BRA  INPUT2
INPUT   CLRB                    ;* READ A-F AS HEX
INPUT2  LDX  #0                 ;* INIT VAR TO 0
        STX  TEMPA
        STX  TEMP               ;* 0 TTEMP, OVFL
        LDX  #TEMPA             ;* X PNT TO WH INPUT CHR STORED
INPUT3  BSR  INHEX              ;* READ A CHAR
        BMI  INPUT7             ;* JMP IF NOT HEX
        LDAB #4
INPUT5  ASL  1,X
        ROL  0,X
        BCC  INPUT6             ;* SET FLAG IF OVERFLOW
        INC  OVFL
INPUT6  DECB                    ;* LEFT SHIFT 4 BITS
        BNE  INPUT5
        ORAA 1,X                ;* ADD IN LSB
        STAA 1,X
        INC  TEMP
        BRA  INPUT3
INPUT7  CMPA #CNTLX             ;* CHK IF ABORT
        BNE  INPUT9             ;* SKIP IF NOT ABORT
NOTHEX  EQU  *                  ;* ERROR ENTRY FROM INHEX
        LDAB #$FF               ;* SET CC NEG
        RTS
INPUT9  LDX  TEMPA              ;* SET REG X=# READ
INPUTC  LDAB TEMP               ;* SET REG B=# HEX CHAR READ
        RTS

;*************** INHEX ****************
;* INPUT 1 HEX CHAR, CONVERT TO HEX
;* RETURN HEX IN REG A
;* REG B = 0 CONVERT A-F TO HEX
;* REG B < 0 LEAVE A-F ALPHA
INHEX   JSR  INCHNP             ;* (INHEX) MUST BE NEG
        CMPA #'0'
        BMI  NOTHEX             ;* NOT HEX
        CMPA #'9'
        BLE  IN1HG              ;* GOOD
        TSTB                    ;* A-F NUMBERS?
        BMI  NOTHEX             ;* NO
        CMPA #'A'
        BMI  NOTHEX             ;* NOT HEX
        CMPA #'F'
        BGT  NOTHEX             ;* NOT HEX
        SUBA #7
IN1HG   ANDA #$F
        CLRB                    ;* AFTER FIND 0-9 CLEARR
        RTS                     ;* GOOD HEX - RTN

;************* MEMORY EXAMINE/CHANGE ***************
;* PRINT VALUE AT <ADR>, MAINTAIN PNTR
;* M <ADR>(SPACE)
;* <ADR>/
;* <ADR> IS 1-4 HEX, NOT COUNTING LEADING ZEROES
;* SUBCOMMANDS
;*      <DATA> MODIFY VALUE AT CURRENT LOC
;*      SP     INCR POINTER, PR VALUE AT NEXT ADR
;*      ,      INCR PNTR, NO PRINT
;*      LF     INCR PNTR, PR ADR & VALUE ON NEXT LINE
;*      UA     DECR PNTR, PR ADR & VALUE ON NEXT LINE
;*      /      PR CURRENT ADR AND VALUE
;*      CR     TERMINATE MEM/EXAM COMMAND
MEMORY  BSR  VALINP
        BLE  MERRTN             ;* NOT HEX - ERROR
MEM01   LDX  TEMPA              ;* RRESET FOR ADR/
        CMPA #'/'               ;* DELIMITER?
        BEQ  MEM02
        CMPA #$20               ;* SPACE?
        BNE  MERRTN
MEM02   BSR  OUT2H              ;* PRINT VALUE
MEM25   STX  PNTR
        PSHX
        CLRB                    ;* A-F NUMBER FLAG
        BSR  INPUT              ;* X=ADR
        PULX
        BMI  RETRN              ;* IF NEG - ABORT
        BEQ  MEM03              ;* JUMP IF NOT HEX
        LDAB TEMPA+1            ;* GET LAST BYTE
        JSR  STRCHK             ;* STORE B AND CHK FOR CHG MEM
        BMI  RETRN              ;* ERR IN CHG MEMORY
MEM03   CMPA #$D                ;* CR?
        BEQ  RETRN              ;* END MEM/EX?
;*** X = ADR OF CURRENT BYTE
        CMPA #','               ;* COMMA?
        BNE  MEM33
        INX                     ;* OPEN NEXT LOC, DO NOT PR
        BRA  MEM25
MEM33   CMPA #$20               ;* SPACE?
        BNE  MEM04
        INX                     ;* INCR PNTR
        BRA  MEM02              ;* GO PR VALUE
MEM04   CMPA #$A                ;* LF?
        BNE  MEM06
        INX
        JSR  PCR                ;* OUT CR, NO LF
        BRA  MEM12              ;* PR ADDR,SPACE
MEM06   CMPA #$5E               ;* UA?
        BNE  MEM08
        DEX
        BRA  MEM10
MEM08   CMPA #'/'               ;* SLASH?
        BNE  MERRTN
MEM10   BSR  PCRLF              ;* PR CR/LF
MEM12   STX  PNTR               ;* SAVE NEW PNTR ADR
MEMSL   EQU  *                  ;* FOUND / AS INSTR
        LDX  #PNTR              ;* X PNT TO PR OBJECT
        BSR  OUT4HS             ;* ADR,SP
        LDX  PNTR               ;* RESET X TO PNTR
        BRA  MEM02
;*
MERRTN  LDAA #$FF               ;* SET CC NEG FOR RTN
RETRN   RTS

;********** OFFSET **********
;*O <ADR> CALCULATES OFFSET FROM LAST MEMORY REF
;*WHICH SHOULD BE LOC OF REL ADR OF BR INSTR, TO
;*THE <ADR> SPECIFIED
;* IF A=0, B<80 DISTANCE CHK
;* IF A=FF, B>7F
;*
OFFSET  JSR  RD2ADR             ;* READ 2 ADDR
        LDD  TEMPA
        SUBD #1
        SUBD PNTR               ;* OFFSET=TO-(FROM+1)
        CMPB #$7F               ;* CHK IF VALID DISTANCE
        BHI  OFF4
        TSTA                    ;* POSITIVE DISTANCE?
        BEQ  OFF6
        BRA  MERRTN
OFF4    CMPA #$FF               ;* NEG DISTANCE
        BNE  MERRTN
OFF6    STAB TEMP               ;* PR OFFSET
        BSR  PCRLF              ;* PR LF AFTER USER CR
        LDX  #TEMP
        BSR  OUT2HS
        BSR  PCRLF
        BRA  MEMSL              ;* GO TO / ROUTINE

;**************** OUT4HS ***************
;* PRINT 2 BYTES AND SPACE
;* REG X - ADR OF 1ST BYTE
;* X WILL BE INCREMENTED BY 1
OUT4HS  BSR  OUT2H
        INX                     ;* GET NEXT BYTE
;* FALL THRU OUT2HS

;*************** OUT2HS ****************
;* PRINT 1 BYTE AND SPACE
;* REG X - ADR OF BYTE
OUT2HS  BSR  OUT2H              ;* 1 BYTE
SPACE   LDAA #$20               ;* PR SPACE
        BRA  XOUTCH             ;* PR 1 CHAR & RTN

;*************** OUT2H ***************
;* PRINT 1 BYTE
;* REG X - ADR OF BYTE
OUT2H   LDAA 0,X
        PSHA                    ;* READ BYTE ONLY ONCE
        BSR  OUTHL
        PULA
        BRA  OUTHR              ;* RIGHT
;*************** OUTHL ***************
;* CONVERT LEFT 4 BITS OF BYTE TO DISPLAY
OUTHL   LSRA                    ;* OUTPUT LEFT 4 BINARY BITTS
        LSRA
        LSRA
        LSRA

;*************** OUTHR ***************
;* CONVERT RIGHT 4 BITS OF BYTE AND PRINT
OUTHR   ANDA #$F                ;* OUTPUT RIGHT 4 BITS
        ADDA #$90               ;* CONVERT TO DISPLAY
        DAA
        ADCA #$40
        DAA
        BRA  XOUTCH             ;* PR 1 CHAR & RTN

;*************** STRCHK ***************
;* STORE B AT 0,X & VERIFY STORE *****
;* DETECTS NON-EXISTENT MEMORY, ROM, PROTECTED RAM
STRCHK  STAB 0,X                ;* STORE B
        CMPB 0,X                ;* VERIFY MEMORY CHG
        BEQ  RETRN              ;* OK
        LDX  #NOCHG             ;* MSG
        BSR  PDATA
        BRA  MERRTN             ;* SET CC NEG
;*
;*************** PDATA1 ***************
;* PRINT DATA STRING
;* REG X POINTS TO PRINT ARRAY
;* X WILL BE INCREMENTED
PDATA2  BSR  XOUTCH             ;* CALL OUTPUT ROUTINE
        INX                     ;* X=ADR OF OUTPUT ARRAY
PDATA1  LDAA 0,X                ;* GET CHAR
        CMPA #4                 ;* EOT?
        BNE  PDATA2
        RTS

;**************** PDATA ***************
;* CR/LF THEN PRINT DATA STRING
PDATA   BSR  PCRLF              ;* CR/LF, DATA STRING
        BRA  PDATA1

;*************** PCRLF ***************
;* OUTPUT CR/LF
;* SAVE, RESTORE REG X
PCRLF   LDAA #$A                ;* OUTPUT LF
        BSR  XOUTCH             ;* PR & RTN

PCR     LDAA #$D                ;* DO CR
        BSR  XOUTCH             ;* PR & RTN
        CLRA
XOUTCH  JMP  OUTCH              ;* OUTPUT & RTN

;*********** PRINT REGISTERS **********
;* PR REGISTERS ACROSS PAGE
;* PR 2ND LINE REG, READING INPUT
;*     SPACE - PR CONTENTS REG, GO TO NEXT REG
;*     HEX,SP - MODIFY REG, GO TO NEXT REG
;*     HEX,CR - MODIFY REG, RTN
;*     CR OR OTHER COMBINATION - NO CHG, RTN
REGSTR  BSR  PREGS1
        BSR  PCRLF              ;* CR/LF AFTER REG PRINT
REGS1   LDX  #SAVSTK            ;* PSEUDO REGS
        CLRB                    ;* INIT OFFSET
REGS2   PSHX                    ;* SAVE REG PNTR
        LDX  #ARRAY             ;* CONTAINS REG NAMES
        ABX                     ;* ADD OFFSET
        LDAA 0,X                ;* GET CURRENT REG
        BSR  OUTDA              ;* PR REG NAME, DASH
        LDAA 1,X                ;* #BYTES FLAG
        PULX                    ;* REG PNTR
        TST  CT                 ;* PRINT OR MOD?
        BEQ  REGS3              ;* MODIFY
        TSTA                    ;* CHK # BYTES
        BEQ  REGS4
        BSR  OUT2H              ;* PR 2 HEX DIGITS
        INX
REGS4   BSR  OUT2HS             ;* PR 2 HEX + SP_
        INX
        BRA  REGS6
REGS3   PSHB                    ;* SAVE OFFSET
        BSR  INDAT              ;* GO READ INPUT
        PULB                    ;* RETRIEVE OFFSET
REGS6   ADDB #2                 ;* UPDATE
        CMPB #12                ;* ALL REG CHKED
        BNE  REGS2              ;* NO - LOOP
        RTS

;*************** INDAT ***************
;* INPUT FOR REG MODIFICATION
INDAT   PSHA                    ;* SAVE LEN FLG
        PSHX                    ;* REG PNTR ADR
        JSR  INPUT
        PULX                    ;* RESTORE
        PULB
        BMI  PRERR              ;* ABORT
        BEQ  INDAT2             ;* NOT HEX
        JSR  TERM               ;* ACCEPT SP , CR
        BNE  PRERR              ;* RTN TO MAIN
        TSTB                    ;* CHK  LENGTH FLAG
        BEQ  INDAT0
        PSHA                    ;* SAVE LAST CHAR READ
        LDD  TEMPA              ;* GET 2 BYTE READ IN
        STD  0,X
        PULA                    ;* RESTORE LAST CHAR
        INX                     ;* INCR REG PNTR
        BRA  INDAT5
INDAT0  LDAB TEMPA+1            ;* 1 BYTE CHANGE
        STAB 0,X
INDAT5  CMPA #$D                ;* CR - RTN
        BNE  INDAT1
PRERR   PULX                    ;* POP RTN ADR
        PULB                    ;* REMOVE FLAG FROM STK
        CLRA                    ;* NO BELL ON RETURN
        RTS                     ;* RTN TO MAIN
INDAT2  CMPA #$20               ;* NO HEX, SPACE
        BNE  PRERR              ;* RTN TO MAIN
        TSTB                    ;* 2 OR 4 CHAR
        BNE  INDAT4
        JSR  OUT2HS             ;* PR 2 CHAR,SPACE
        BRA  INDAT1
INDAT4  JSR  OUT4HS             ;* PR 4 CHAR, SPACE
INDAT1  INX                     ;* ADJUST REG PNTR
        RTS

;**************** PREGS ***************
;* PRINT REGS - P,X,A,B,C,S
PREGS1  BSR  PCRLF
PREGS   INC  CT                 ;* SET FLAG-PRT REG
        BSR  REGS1              ;* GO PRINT
        CLR  CT                 ;* RESET FLAG
        RTS

;*************** OUTDA ***************
;* PRINT REG A, -
OUTDA   BSR  ZOUTCH             ;* OUTPUT REG A
        LDAA #'-'               ;* DASH
ZOUTCH  JMP  OUTCH

;********** BRKPNT **********
;* COME HERE AFTER RECOGNIZE B<DELIM>
;* B    DISPLAY ALL
;* B -  REMOVE ALL
;* B <ADR> INSERT BRKPNT
;* B -<ADR> REMOVE BRKPNT
BRKPNT  CMPA #$D                ;* CR?
        BEQ  PRBRK              ;* PRINT
        CMPA #'-'               ;* DELETE?
        BEQ  DELBRK
        JSR  VALINP
        BMI  GOX2               ;* ABORT?
        BNE  BP02               ;* HEX?
        CMPA #'-'               ;* DELETE
        BEQ  DELBRK
        BRA  GOX2               ;* ERR IF NOT DEL
BP02    CMPA #$D                ;* CR
        BNE  BERRTN             ;* ERROR RTN
        BSR  BRKTAB             ;* IN TABL
        BEQ  PRBRK              ;* YES - OK RTN
        LDX  #BKADR
BP04    LDD  0,X
        BEQ  BP06               ;* AVAIL SP?
        INX                     ;* CHK NEXT POSN
        INX
        CPX  #OPCODE            ;* END TABL?
        BNE  BP04
        BRA  BERRTN             ;* NO AVAIL SP
BP06    LDD  TEMPA              ;* GET ADR
        STD  0,X                ;* STORE IN TABLE
;* FALL THRU AND PR BRKPNTS
;* PRINT BREAKPOINTS
PRBRK   JSR  PCRLF
        LDX  #BKADR
        LDAB #4
PRBRK2  JSR  OUT4HS
        INX                     ;* INCR PNTR TO BRKPNTS
        DECB
        BNE  PRBRK2
        RTS 

;* SEARCH BREAKPOINT TABLE
;* RETURN -1 IF BRKPNT NOT IN TABL
;* OTHERWISE REG X POINT TO BRKPNT IN TABL
BRKTAB  LDX  #BKADR
TAB1    LDD  TEMPA              ;* GET PC
        SUBD 0,X
        BEQ  BRTN
        INX
        INX
        CPX  #OPCODE            ;* CMPAR TO END TABLE
        BNE  TAB1
GOX2    EQU  *                  ;* ERROR RETURN ENTRY FROM G
BERRTN  LDAA #$FF
BRTN    RTS

;* DELETE BRKPNT
DELBRK  JSR  VALINP
        BMI  BERRTN             ;* ABORT OR ERR?
        CMPA #$D                ;* CR?
        BNE  BERRTN
        TSTB                    ;* HEX?
        BNE  DBRK6              ;* JMP IF SO
        LDX  #BKADR-1
        LDAB #12                ;* 0 BRKPNT TABLE
DBRK2   INX
        CLR  0,X
        DECB
        BNE  DBRK2
        BRA  PRBRK
;* DELETE 1 BRKPNT
DBRK6   BSR  BRKTAB
        BNE  BERRTN
        STD  0,X                ;* D=0 FROM BRKTAB
        CLR  8,X                ;* CLR OP CODE
        BRA  PRBRK

;********** CALL **********
;* CALL USER ROUTINE AS SUBR
;* USER RTS RETURNS TO MONITOR
;* STK PNTR NOT GOOD ON RETURN
;* C <ADR> (CR) OR C (CR)
CALL    STAA CALLF              ;* SET FLAG # 0

;********** G **********
;* GO EXECUTE USER CODE
;* G(CR) OR G <ADR>
GOXQT   CMPA #$D                ;* CR
        BEQ  GOX6               ;* XQT FROM CURRENT PC
        JSR  VALINP
        BLE  GOX2
        CMPA #$D                ;* CR?
        BNE  GOX2               ;* ERR
        CLR  EXONE              ;* SEE BRKPNT, IF ANY
        STX  SAVSTK             ;* SET USER PC
GOX6    JSR  PCRLF
        LDAA CALLF              ;* CALL CMD?
        BEQ  GOX7               ;* NO
        CLR  CALLF
        LDX  SPSAVE             ;* GET USER STK
        LDD  #CRTS              ;* RTN TO MONITOR ADR
        DEX 
        STD  0,X                ;* STOR ON USER STK
        DEX                     ;* ADJUST USER STK
        STX  SPSAVE             ;* RESAVE STK
;* NOW GO XQT USER SUBR
GOX7    LDAA EXONE              ;* STOPPED ON BRKPNT
        BNE  GOX8
        JSR  SETB
GOX8    BRA  BARMS

;********** . (PERIOD) **********
;* TRACE 1 INSTRUCTION
NEXT    LDX  #1
        BRA  TRACE2
	
;********** T **********
;* T <HEX> - TRACE <HEX> INSTTR
TRACE   CMPA #$D                ;* T(CR) ? - TRACE 1
        BEQ  NEXT
        JSR  INPUT              ;* GET <HEX>
        BLE  GOX2               ;* RTN IF ABORT OR NOT HEX
TRACE2  STX  NTRACE             ;* STORE <HEX>
        BEQ  GOX2               ;* RTN IF TRACE = 0
        INC  EXONE              ;* XQT 1 INSTR
BARMS   BRA  ARMSTK

;********** CALL SUBR **********
;* ENTRY AFTER C COMMAND, AFTER XQT USER RTS
;* SAVE USER REGISTERS
;* PRINT REGISTERS
;* RETURN TO ROUTINE CALLING C COMMAND ROUTINE
CRTS    PSHA                    ;* SAVE  TO GET CC
        TPA 
        STAA SAVSTK+6           ;* CC
        PULA
        STS  SPSAVE             ;* STK PNTR
        LDS  #STACK
        STD  SAVSTK+4           ;* A,B
        STX  SAVSTK+2           ;* X
        LDX  #CRTS              ;* PC PNT TO MONITOR
        STX  SAVSTK
        JSR  RBRK               ;* REMOVE BRKPNTS
        JMP  ENDCAL             ;* GO PR REGS, 0 EXONE

;* SETCLK - USED BY ON-CHIP CLOCK
;* FOR HARDWARE TRACE
;* SET TIMER TO COMPARE AFTER 1 CYCLE OF USER INSTR
SETCLK  LDAB #$18               ;* SET #CYCLES
        LDX  CLOCK              ;* GET CLOCK TIME
        ABX                     ;* ADD # CYCLES
        STX  OCREG              ;* STORE IN COMPARE REG
        RTS

;********** NMI ENTRY **********
;* ENTER FROM XQT 1 INSTR - TRACE OR XQT OVER BRKPNT
;* MOVE REGS FROM USER STK TO MONITOR STORAGE
;* REPLACE BRKPNTS WITH USER CODE
;* IF NOT TRACING, REPLACE CODE WITH BRKPNTS (3F)
;* IF TRACING, PRINT REGISTERS
;*             EXECUTE NEXT USER INSTR
;* ENTRY FOR ONCHIP CLOCK TRACE
C.NMI   INC  TCSR               ;* BRING LEVEL HIGH
        BSR  SETCLK             ;* NO NMI, BUT LEVEL CHG

;* ENTRY FOR PTM HARDWARE TRACE
M.NMI   TSX                     ;* TRANSFER STK PNTR
        LDS  #STACK
        BSR  MOVSTK             ;* SAVE USER REGS
        JSR  RBRK               ;* REMOVE BRKPNT
        LDX  NTRACE             ;* TRACE?
        BNE  NMI01
        CLR  EXONE
        JSR  SETB
        BMI  NMI03
        BRA  ARMSTK
NMI01   DEX
NMI015  STX  NTRACE
        BNE  NMI02
        CLR  EXONE
;* PRINT TRACE LINE:
;* OP-XX P-XXXX X-XXXX A-XX B-XX C-XX S-XXXX
;* CHECK IF USER HIT CONTROL X TO TERMINATE TRACE
NMI02   LDX  #0                 ;* CLR TRACE & EXONE IF TERMINATE
        JSR  CHKABT
        BEQ  NMI015             ;* TERMINT IF = CNTL X
        LDX  #PRTOP             ;* GET ADR OF OP-
        JSR  PDATA
        LDX  TEMPA              ;* GET OLD PC
        JSR  OUT2HS             ;* PR OPCODE
        JSR  PREGS              ;* PR TRACE LINE
        LDAA EXONE
        BNE  ARMSTK
NMI03   JMP  MAIN
;* STACK USER REGISTERS
;* MOVE FROM MONITOR STORAGE TO USER STACK
;* IF TRACE - SET HARDWARE
ARMSTK  LDS  SPSAVE             ;* SET STK FOR RTI
        LDX  SAVSTK             ;* PC
        PSHX
        LDX  SAVSTK+2           ;* X
        PSHX
        LDD SAVSTK+4            ;* GET A, B
        PSHA                    ;* MOVE TO STK
        PSHB
        LDAA SAVSTK+6           ;* GET CC
        PSHA
        LDAA EXONE
        BEQ  ARMS04
        LDX  SAVSTK             ;* SAVE PC PNTR FOR NXT TRACE PRT
        STX  TEMPA
;* CHECK IF USE PTM OR ON-CHIP CLOCK
        BSR  IFPTM
        BEQ  SETPTM             ;* GO USE PTM
;* IF USER ISSUE TRACE COMMAND AND 
;* NOT USING PTM - ASSUME ON-CHIP
        LDAA #2                 ;* SET DDR FOR OUTPUT
        STAA P2DDR              ;* PORT 2
        LDAB TCSR               ;* SET UP FOR ON-CHIP CLOCK
        ANDB #$FE               ;* CLEAR OLVL BIT
        STAB TCSR 
        BSR  SETCLK             ;* SET CMPR REG, WAIT FOR CMPR
DUMMY   EQU *                   ;* INTERRUPT VECTORS USE THIS
        RTI

;* SET HARDWARE FOR PTM
;* INITIATE COUNTER
SETPTM  LDD  #$0501             ;* M=5,L=1 TURN ON TRACE
        LDX  PTM                ;* GET ADR OF PTM
        STD  2,X                ;* STORE AT PTM ADR +2
ARMS04  RTI

;* CHECK NMI VECTOR
;* DETERMINE IF USE ON-CHIP CLOCK OR PTM
;*    FOR HARDWARE TRACE
IFPTM   LDX  #VECTR             ;* GET ADR OF VECTORS
        LDAA MODE               ;* EXTERNAL VECTRS?
        ANDA #$E0               ;* CHK 3 MSB
        CMPA #$20               ;* MODE 1?
        BEQ  IFPTM2             ;
        LDX  VECPTR             ;* GET VECTOR TABLE
IFPTM2  LDX  $C,X               ;* GET NMI ADDRESS
        CPX  #EX.NMI            ;* PTM ENTRY?
        RTS                     ;* RETURN WITH CC SET

;*************** MOVSTK ***************
;* MOVE USER REGS FROM USER STACK TO MONITOR STORAGE
;* RESET USER STACK POINTER
MOVSTK  LDAA 0,X                ;* MOVE C,B,A,X,PC
        STAA SAVSTK+6           ;* TO PC,X,A,B,C
        LDD  1,X
        STAA SAVSTK+5
        STAB SAVSTK+4
        LDD  3,X
        STD  SAVSTK+2
        LDD  5,X
        STD  SAVSTK
        LDAB #6
        ABX
        STX  SPSAVE
        RTS

;*************** RBRK ***************
;* REPLACE BRKPNTS (SWI) WITH USER CODE
;* BKADR - TABLE OF 4 BRKPNT ADR
;* OPCODE - TABLE OF OPCODES, CORRESPOND TO ADR
RBRK    LDAA BRKFLG             ;* IGNORE IF BRKPNTS NOT IN
        BEQ  RBRK6
        LDX  #BKADR             ;* GET TABLE OF ADR
        LDAB #NUMBP*2           ;* INDEX INTO OPCODE TABLE
RBRK2   PSHX                    ;* SAVE TABLE ADR
        PSHX
        ABX 
        LDAA 0,X                ;* GET OPCODE
        PULX
        LDX  0,X                ;* GET USER BRKPNT ADR
        BEQ  RBRK3              ;* NO ADR
        STAA 0,X                ;* RESTORE OPCODE
RBRK3   PULX                    ;* GET NXTT ADR FROM TABL
        INX
        INX
        DECB                    ;* ADJUST OPCODE INDEX
        CMPB #NUMBP             ;* END TABLE?
        BNE  RBRK2
        CLR  BRKFLG             ;* CLR BRKPNT FLAG
RBRK6   RTS

;*************** SETB ***************
;* REPLACE USER CODE WITH 3F AT BRKPNT ADDRESSES
;* IGNORE IF BREAKPOINTS ALREADY IN
SETB    LDAA BRKFLG             ;* ALREADY IN?
        BNE  SHERR              ;* SET NEG RETURN
        LDX  #BKADR
        LDAB #NUMBP*2           ;* SET INDEX INTO OPCODES
SETB2   PSHX                    ;* SAVE ADR PNTR
        LDX  0,X                ;* GET USER BRKPNT ADR
        BEQ  SETB4              ;* SKIP IF NO ADR
        LDAA 0,X                ;* GET OPCODE
        PSHB                    ;* SAVE OPCODE INDEX
        LDAB #$3F               ;* SET SWI
        JSR  STRCHK             ;* STORE & CHK CHG
        PULB                    ;* INDEX
        PULX                    ;* ADR TABLE PNTR
        BMI  SETB6              ;* 3F STORED GOOD?
        PSHX                    ;* RESAVE TABLE PNTR
        ABX                     ;* CALCLATE OP POS IN TABLE
        STAA 0,X                ;* SAVE OPCODE
SETB4   PULX                    ;* GET TABLE ADR
        INX
        INX                     ;* GET NXT ADT
        DECB                    ;* ADJUST OPCODE INDEX
        CMPB #NUMBP             ;* END TABLE?
        BNE  SETB2              ;* LOOP IF NOT
        STAB BRKFLG             ;* SET BRKPNT FLAG
SETB6   RTS

;********** SWI ENTRY **********
;* ENTER WITH BRKPOINT SETTING
;* SAVE USER REGISTERS
;* DECR PC TO POINT AT SWI
;* REPLACE SWI'S WITH USER CODE
;* PRINT REGISTERS
;* GO TO MAIN CONTROL LOOP
M.SWI   TSX                     ;* GET USER STK
        LDS  #STACK             ;* SET TO INTERNAL STK
        BSR  MOVSTK             ;* SAVE USER REGS
        LDX  SAVSTK             ;* DECR USER PC
        DEX
        STX  SAVSTK
        STX  TEMPA              ;* SAVE FOR BRKTAB CHK
        LDAA BRKFLG             ;* ERR IF NOT BRKPOINT
        BEQ  BKPERR
        BSR  RBRK               ;* REMOVE BRKPNT FROM CODE
        JSR  BRKTAB             ;* BRKPNT IN TABLE?
        BNE  BKPERR
;* REG A = 0 IF BRKTAB FIND BRKPNT
        INCA
        BRA  SWI3
;* ENTRY FROM CRTS - PR REGS, RTN TO MAIN
ENDCAL  EQU *
BKPERR  CLRA
        CLRB
        STD  NTRACE             ;* RESET NUM INSTR TO TRACE
SWI3    STAA EXONE              ;* CLEAR XQT 1 INSTR
        JSR  PREGS1
        JMP  MAIN               ;* GO TO MAIN LOOP

;********** DISPLAY **********
;* D   OR D <ADR>  OR D <ADR> <ADR>
;* DISPLAY MEMORY - BLK OF MEMORY AROUND LAST
;*   REFERENCED BYTE FROM MEM/EX
;* DISPLAY 16 BYTES AROUND <ADR> SPECIFIED
;* OR DISPLAY FROM <ADR> TO <ADR> MOD 16
;* ASCII CHAR WILL BE PRINTED ON THE RIGHT
;* MEM/EX PNTR WILL PNT TO LAST ADR REFERENCED
;* AT END OF DISPLAY COMMAND
;*
DISPLY  LDX  PNTR               ;* SAVE MEMORY/EX PNTR
        PSHX
        CMPA #$D                ;* CR?
        BEQ  SHOW35             ;* NO ARG
        BSR  PVALIN
        BLE  SHERR2             ;* ERR IF NOT HEX, OR ABORT
        STX  PNTR               ;
        CMPA #$D                ;* CR?
        BNE  SHOW4
SHOW35  LDD  PNTR               ;* DEFINE BLK TO DMP
        ANDB #$F0               ;* MASK OUT LOW DIGIT
        SUBD #$10
        STD  PNTR
        ADDD #$20
        STD  TEMPA              ;* TO ADR
        BRA  SHOW8
SHERR2  PULX                    ;* RESET MEM/EX PNTR
        STX  PNTR
SHERR   LDAA #$FF
        RTS
;	
SHOW4   BSR  PVALIN             ;* READ HEX #
        BLE  SHERR2             ;* JMP IF ERR
        LDD  PNTR               ;* FROM ADR < TO ADR?
        ANDB #$F0               ;* MASK OUT LOW ORDER DIGIT
        STAB PNTR+1
        SUBD TEMPA
        BHI  SHERR2
        LDAA TEMPA+1            ;* MASK TO FULL LINE
        ANDA #$F0
        STAA TEMPA+1            ;* CHANGES LAST REF ADR
;* TURN ON HIGH SPEED DEVICE
;* CALL HIGH SPEED DATA ROUTINE TO OUTPUT
;*    DATA FROM ADR IN PNTR TO ADR IN TEMPA
SHOW8   LDAB #HS.ON
        JSR  IO2
        LDX  #BBLK+1            ;* GET TRANSFER PACKET
        LDAB #HS.DTA
        JSR  IO
        PULX                    ;* RETRIEVE MEM/EX PNTR
        STX  PNTR
        LDAB #HS.OFF
        BSR  IO2
        CLRA                    ;* CLEAR CC FOR RETURN
        RTS
;        SPC
;**************** CHKABT ***************
;* READ WITH NO WAIT
;* CHK FOR CONTROL X - ESCAPE FROM PRINT
;* CHK FOR CONTROL W - WAIT DURING T OR D PRINT
;*    ANY CHARACTER CONTINUES PRINT
;* ANY OTHER CHARACTER - READ & IGNORE
CHKABT  PSHA
        LDAB #CI.DTA            ;* READ A CHAR
        BSR  IO2
        ANDA #$7F               ;* CLEAR PARITY
        CMPA #CNTLW             ;* CONTROL W?
        BNE  CHK2               ;* IF SO WAIT FOR INPUT
        JSR  INCHNP             ;*  TO CONTINUE PRINT
CHK2    CMPA #CNTLX             ;* CONTROL X?
;* RETURN WITH CC SET
 PULA
SHOW19  RTS
; SPC
PVALIN  JMP  VALINP             ;* SAVE BYTES
; SPC
;************** HSDTA ***************
;* FROM ADR, TO ADR IN TRANSFER BLOCK
;* ADR ARE DIVISIBLE BY 16
;* ADR OF BLOCK WAS IN REG X
;* X SAVED ON STK BY IO
HSDTA   TSX                     ;* GET TRANSFER PACKET
        LDX  2,X
        LDD  0,X                ;* GET FROM ADR
        STD  PNTR               ;* SAVE FOR DUMP
        LDD  2,X                ;* GET TO ADR
        STD  TEMPA
SHOW9   JSR  PCRLF              ;* LINE FEED
;* PRINT BLOCK HEADING
        LDX  #SPACE6            ;* PR LEADING BLANKS
        JSR  PDATA
        CLRA
PRTTL   PSHA
        JSR  OUTHR              ;* CONVERT TO DISPLAY
        JSR  SPACE
        JSR  SPACE              ;* PR 2 SPACES
        PULA                    ;* GET CNTR
        INCA
        CMPA #$10               ;* PR 0-F
        BNE  PRTTL              ;* FINISHED?
;* CHECK IF USER WANT TO TERMINT DISPLAY CMD
SHOW10  BSR  CHKABT
        BEQ  SHOW19             ;* RETURN IF CONTROL X
        JSR  PCRLF
        LDX  #PNTR              ;* GET ADR OF LINE
        JSR  OUT4HS             ;* PRINT ADR
        LDX  PNTR               ;* GET CONTENTS OF MEMORY
        LDAB #16                ;* CNTR FOR LINE
SHOW12  JSR  OUT2HS             ;* PR DATA
        INX                     ;* INCR ADR PNTR
        DECB
        BNE  SHOW12             ;* LOOP
        JSR  SPACE              ;* PRINT ASCII DUMP
        LDAB #16                ;* NUM CHAR/LINE
        LDX  PNTR
SHOW14  LDAA 0,X
        ANDA #$7F               ;* CHK PRINTABLE
        CMPA #$20
        BLT  SHOW16             ;* NON-CHAR
        CMPA #$61
        BLT  SHOW18
SHOW16  LDAA #'.'               ;* PR . FOR NON-CHAR
SHOW18  JSR  OUTCH
        INX
        DECB
        BNE  SHOW14             ;* LOOP
        LDD  TEMPA
        SUBD PNTR
        BEQ  SHOW19             ;* RETURN
        STX  PNTR               ;* SAVE  FROM ADR
        TST  PNTR+1
        BNE  SHOW10             ;* END OF LINE
        BRA  SHOW9              ;* END OF BLOCK
; SPC
;* IO CALL - TO SAVE A FEW BYTES
IO2     JMP  IO
; SPC
;*************** RD2ADR ***************
;* READ <DELIM> <ADR1> <ADR2>
RD2ADR  CMPA #$0D               ;* CR?
        BEQ PNCHER
        BSR PVALIN              ;* CALL INPUT ROUTINE
        BLE PNCHER              ;* CHK IF NUMBER
        STX BBLK+1              ;* SAVE 1ST ADR (PNTR)
;* INPUT CHECKS FOR DELIMITER
        CMPA #$D                ;* CR?
        BEQ PNCHER              ;* DO NOT ALLOW CR
PNCH3   JSR PVALIN              ;* READ NEXT ADR
        BLE PNCHER              ;* VALID ADR?
        CMPA #$D                ;* REQUIRE CR AFTER ADR
        BEQ PNCRTN
PNCHER  LDAA #$FF               ;* ERR RTN
        PULX                    ;* REMOVE SUBR CALL ADR
PNCRTN  RTS
; SPC
;*************** PUNCH ***************
;* P <ADR1> <ADR2>
;* PUNCH FROM <ADR1> TO <ADR2>
;* ERROR IF <ADR2> LT <ADR1>
;* SET UP TRANSFER PACKET
;* 1ST WRD - FCN FOR PUNCH = 0
;* 2ND, 3RD WRDS = <ADR1>
;* 4TH, 5TH WRDS = <ADR2>
;* LDX W/ ADR OF TRANSFER PACKET
;* JMP THRU IO VECTOR TO BSDTA
PUNCH   CLR  BBLK               ;* SET BULK STR FCN
        BSR  RD2ADR             ;* READ 2 ADDRESSES
;* HEX STILL IN TEMPA (BBLK+3) - END ADR
PNCH4   JSR  PCRLF
;* SET NO ECHO FLAG/ TAPE FLAG
        LDAA #$10               ;* # NULLS W/TAPE CR
        STAA OUTSW
        LDAB #BS.ON             ;* TURN PUNCH ON
        BSR  IO2
        LDX  #BBLK              ;* ADR OF BULK STORE BLK
        LDAB #BS.DTA            ;* OFFSET TO BULK ROUTINE
        BSR  IO2
        PSHA                    ;* SAVE FOR RETURN CC
        LDAB #BS.OFF            ;* TURN OFF TAPE
        BSR  IO2
        JSR  CHKABT             ;* CLEAR IO BUF
        JSR  CHKABT             ;* DOUBLE BUF
        CLR  OUTSW              ;* TURN PR ON
        PULA
        TSTA                    ;* SET RETURN PR
        RTS
; SPC
;*************** LOAD ***************
;* L  LOAD A TAPE FILE
;* L <OFFSET>  LOAD WITH AN OFFSET
;* SET FUNCTION IN BULK STORE PACKET
;* IF OFFSET - 3RD, 4TH WRDS OF PACKET = OFFSET
;* LDX W/ ADR OF TRANSFER PACKET
;* JMP THRU IO VECTOR TO BSDTA
LOAD    LDAB #1                 ;* SET LOAD FCN = 1
LOAD2   STAB BBLK
        LDX  #0                 ;* INIT OFFSET=0
        STX  BBLK+3             ;
        CMPA #$D                ;* CR?
        BEQ  PNCH4              ;* YES
        BSR  PNCH3
        BRA  PNCH4
; SPC
;*************** VERIFY ***************
;* V  VERIFY THAT TAPE LOADED CORRECTLY
;* V <OFFSET> CHECK PROG LOADED WITH OFFSET CORRECTLY
;* SET FCN IN BULK STORE PACKET
;* IF OFFSET - 3RD, 4TH WRDS = OFFSET
;* LDX W/ ADR OF PACKET
;* JMP THRU IO VECTOR TO BSDTA
VERF    LDAB #$FF
        BRA  LOAD2
; SPC
;********** BSON **********
;* TURN PUNCH ON FOR READ OR WRITE
;* BBLK MUST BE SET - BBLK=0 WRITE
;*                BBLK#0 ON FOR READ
BSON    LDAA #$11               ;* SET FOR READ
        TST  BBLK
        BNE  BSON2              ;* JUMP IF VERF/LOAD
        INCA                    ;* SET REG A=$12 FOR WRT TAPE
BSON2   JMP  OUTCH
; SPC
;************** BSOFF ***************
BSOFF   LDX  #PUNOFF            ;* TURN PUNCH OFF
        JSR  PDATA1             ;* OUTPUT STRG & RTN
        JMP  DELAY              ;* WAIT FOR PRT SYNC
        SPC
;********** BSDTA **********
BSDTA   TSX                     ;* BULK STORE DATA
        LDX  2,X                ;* GET IO PACK VECTOR
        LDAA 0,X                ;* GET FCN
        STAA BBLK               ;* USED BY VERF/LOAD
        BEQ  BSPUN              ;* JUMP TO PUNCH, FCN=0
;* FALL THRU TO VERF-BBLK=-1, LOAD-BBLK=1
; SPC
;* VERIFY, LOAD
;* GET OFFSET FROM IO PACKET
;* FIND S1 REC - DATA
;* READ BYTE CNT (TEMP)
;* READ ADDRESS - SET REG X
;* READ & STORE DATA, COMPUTE CHK SUM
;* COMPARE TAPE TO COMPUTED CKSUM
        LDD  3,X                ;* GET OFFSET
        STD  PNTR
LOAD3   JSR  INCHNP             ;* READ
LOAD4   CMPA #'S'               ;* GET 1ST GOOD REC
        BNE  LOAD3
        JSR  INCHNP
        CMPA #'9'
        BEQ  LOAD20             ;* FINI AFTER S9
        CMPA #'1'               ;* DATA REC
        BNE  LOAD4              ;* NO
        CLR  CKSUM              ;* INIT CHECK SUM
        BSR  BYTE               ;* GET BYTE CNT
        SUBB #2                 ;* DECR BYTE CNT FROM IT
        STAB TEMP               ;* STORAGE FOR BYTE CNT
;* READ 4 HEX DIGITS FROM INPUT
;* FORM ADDRESS AND STORE IN REG X
        BSR  BYTE               ;* 1 BYTE
        PSHB                    ;* SAVE 1ST BYTE
        BSR  BYTE               ;* 2ND BYTE
        PULA                    ;* GET 1ST BYTE
        ADDD PNTR               ;* ADD OFFSET
        PSHB                    ;* MOVE A:B TO X
        PSHA 
        PULX                    ;* SET REG X = ADR
;* STORE DATA
LOAD11  BSR  BYTE               ;* GET BYTE IN REG B
        DEC  TEMP               ;* DEC BYTE CNT
        BEQ  LOAD15             ;* END REC?
        TST  BBLK               ;* SKIP STORE IF VERF
        BMI  LOAD12             ;* JUST COMPARE
        STAB 0,X
LOAD12  CMPB 0,X
        BNE  LOAD19             ;* ERROR
        INX
        BRA  LOAD11
;* CHECKSUMS GOOD?
;* CKSUM IS ONE'S COMPLE
LOAD15  INCA                    ;* CHKSUM ADDED INTO B 
        BEQ  LOAD3              ;* GET NEXT REC
;* CHECKSUM ERROR, VERF FAILURE, LOAD FAIL ERR
LOAD19  LDAA #$FF               ;* SET NEG FOR ER RTN
LOAD20  RTS
        SPC
;*************** BYTE ***************
;* FORM A HEX BYTE FROM 2 DISPLAY BYTES
;* CALL INHEX TO READ 1 HEX DIGIT FROM INPUT
BYTE    CLRB                    ;* READ A-F AS HEX
        JSR  INHEX
        LDAB #16
        MUL                     ;* LSB IN REG B
        PSHB                    ;* SAVE
        CLRB                    ;* FLAG FOR INHEX
        JSR  INHEX
        PULB
        ABA                     ;* GET 1 BYTE
        TAB                     ;* SAVE IN B
        ADDA CKSUM 
        STAA CKSUM
        RTS
        SPC
;********** BSDTA - PUNCH **********
;* MOVE FROM & TO ADDRESSES TO STORAGE
;* PNTR - FROM ADR   TEMPA - TO ADR
;* BBLK - REUSED FOR FRAME CNT
;* TEMP - REUSED FOR BYTE CNT
;* PUNCH NULLS AS LEADER ON TAPE
;* PUNCH CR/LF, NULL, S1(RECORD TYPE),
;*       FRAME COUNT, ADDRESS, DATA, CHECKSUM
;* EOF RECORD - S9030000FC
BSPUN   LDD  1,X                ;* GET FROM ADR
        STD  PNTR
        LDD  3,X                ;* GET TO ADR
        STD  TEMPA
;* PUNCH LEADER
        LDAB #25
PNULL   CLRA                    ;* OUTPUT NULL CHAR
        JSR  OUTCH
        DECB
        BNE  PNULL              ;* LOOP IF NOT FINI
PUN11   LDD  TEMPA
        SUBB PNTR+1
        SBCA PNTR               ;* FROM ADR < TO ADR?
        BNE  PUN22
        CMPB #24
        BCS  PUN23              ;
PUN22   LDAB #23                ;* SET FRAME CNT
PUN23   ADDB #4
        STAB BBLK
        SUBB #3
        STAB TEMP               ;* BYTE CNT THIS REC
;* PUNCH CR/LF, NULLS,S,1
        LDX  #MTAPE
        JSR  PDATA
        CLRB                    ;* ZERO CHKSUM
;* PUNCH FRAME CNT
        LDX  #BBLK
        BSR  PUNT2              ;* PUNCH 2 HEX CHAR
;* PUNCH ADDRESS
        LDX  #PNTR
        BSR  PUNT2
        INX
        BSR  PUNT2
;* PUNCH DATA
        LDX  PNTR
PUN32   BSR  PUNT2              ;* PUNCH 1BYTE (2 FRAMES)
        INX                     ;* INCR X PNTR
        DEC  TEMP               ;* DECR BYTE CNT
        BNE  PUN32
        STX  PNTR
        COMB
        PSHB
        TSX
        BSR  PUNT2              ;* PUNCH CHKSUM
        PULB                    ;* RESTORE
        LDX  PNTR
        DEX
        CPX  TEMPA
        BNE  PUN11
        LDX  #MEOF              ;* PUNCH EOF
        JSR  PDATA
        CLRA                    ;* CLEAR CC FOR RETURN
        RTS
;* PUNCH 2 HEX CHAR, UPDATE CHKSUM
PUNT2   ADDB 0,X
        JMP  OUT2H              ;* OUTPUT 2 HEX & RTN
; SPC
;********** ROM DATA **********
PRTON   FCB  $10,$3A,$10,$39,4  ;* TURN ON PRT
PUNOFF  FCB  $14,$13            ;* TAPE CONTROL
	FCB  4                  ;* EOF
QMARK   FCB  $3F,4              ;* PR ?
;*
LIL     EQU  *
    IFDEF DEF9600
        FCC  "Lilbug 1.1"
    ELSE
        FCC  "Lilbug 1.0"
    ENDIF
;*
	FCB  4
NOCHG   FCC  "NO CHG"
        FCB  4                  ;* EOF
MTAPE   FCB  'S','1',4
MEOF    FCC  "S9030000FC"
        FCB  $D,4
PRTOP   FCC  "OP-"              ;* PRT FOR TRACE LINE
        FCB  4
ARRAY   FCB  'P',1              ;* ARRAY OF REG AND WRD LEN
        FCB  'X',1
        FCB  'A',0
        FCB  'B',0
        FCB  'C',0
        FCB  'S',1
SPACE6  FCC  "      "           ;* 6 SPACES FOR SHOW HEADER
        FCB  4
; SPC
;*************** VECTORS ***************
;* VECTOR INDEPENDENCE
;* ALSO SAVE ON RAM USAGE
;* VECPTR - RAM PNTR TO VECTOR TABLE
;* VECTOR TABLE - ADR OF INTERRUPT VECTORS
;* MAY BE REDEFINED BY USER TABLE IN SAME FORM
SERIAL  FDB  DUMMY              ;* NOT USED BY MONITOR
TIMOVF  FDB  DUMMY
TIMOUT  FDB  DUMMY
TIMIN   FDB  DUMMY
IRQ1    FDB  DUMMY
SWI     FDB  IN.SWI
NMI     FDB  IN.NMI
;* DUMMY IS AN RTI

        ORG $FFD6
;* USE ADR ON STK TO OBTAIN INDEX
;* USE INDEX TO GET CORRECT VECTOR
;*    ROUTINE ADR FROM VECTOR TABLE.
	IFNDEF NORMAL
VECTOR  PULD                    ;* Throw away MSB of addr, get LSB
        ELSE
VECTOR  PULA                    ;* THROW AWAY MSB OF ADR
        PULB                    ;* GET LSB
        ENDIF
;
        SUBD #I.SER+2
        LDX  VECPTR             ;* ADR OF VECTOR TABLE
        ABX                     ;* ADD OFFSET
        LDX  0,X                ;* GET VECTOR ADR
        JMP  0,X                ;* GO THRU VECTOR

;* INTERRUPTS GO THRU VECTORS, THEN HERE
;* BSR STORES ADR ON STACK
;* ADR USED TO OBTAIN INDEX INTO VECTOR TABL
I.SER   BSR  VECTOR
I.TOVF  BSR  VECTOR
I.TOVT  BSR  VECTOR
I.TIN   BSR  VECTOR
I.IRQ1  BSR  VECTOR
I.SWI   BSR  VECTOR
I.NMI   BSR  VECTOR
; SPC
;* INTERRUPT VECTORS
VECTR   FDB  I.SER
        FDB  I.TOVF
        FDB  I.TOVT
        FDB  I.TIN
        FDB  I.IRQ1
        FDB  I.SWI
        FDB  I.NMI
        FDB  STRT
        END  START
;/* Local Variables: */
;/* mode:asm           */
;/* End:             */
