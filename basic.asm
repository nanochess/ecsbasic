                ;
                ; ECS Extended BASIC interpreter for Intellivision
                ;
                ; by Oscar Toledo G.
                ; https://nanochess.org/
                ;
                ; Creation date: Sep/19/2025.
                ; Revision date: Sep/22/2025. Routines for adding/deleting/inserting lines, converting and
                ;                             listing tokenized BASIC, and executing BASIC lines. Added
                ;            	              LIST, NEW, CLS, RUN, STOP, PRINT, and GOTO. Execution can
                ;                             be interrupted using the Esc key.
                ; Revision date: Sep/23/2025. Added INPUT statement. Solved bug checking for Esc in GOTO.
                ; Revision date: Sep/24/2025. Added ELSE statement. Added GOSUB/RETURN. Added FOR/NEXT.
                ;                             Added negation operator. Added functions INT, ABS, SGN, and
                ;                             RND. Added REM, RESTORE, READ, and DATA.
                ; Revision date: Sep/26/2025. Added arrays with DIM.
                ; Revision date: Sep/27/2025. Added AND, XOR, OR, and NOT. Implemented COLOR, WAIT,
                ;                             SPRITE, SOUND, STICK, STRIG, KEY, BK, MODE, BORDER, and
                ;                             DEFINE. Corrections for working in real hardware. Added
                ;                             keyboard debouncing. LIST allows for ranges.
                ; Revision date: Sep/28/2025. Added POKE, PEEK, and USR.
                ; Revision date: Oct/02/2025. Allows to assign, concatenate, compare, print, input, and
                ;                             read strings. Added limit detection to bas_get_line.
                ;                             Added limit detection to the tokenizer.
                ; Revision date: Oct/03/2025. Added ASC, LEN, CHR$, LEFT$, MID$, RIGHT$, INKEY$, VAL,
                ;                             STR$, and INSTR. Detects if new program line exceeds
                ;                             available memory. Added garbage collector for strings.
                ; Revision date: Oct/04/2025. Added ON GOTO and ON GOSUB. Inserting a line resets
                ;                             the variable data.
                ; Revision date: Oct/05/2025. Added SIN, COS, TAN, LOG, EXP, SQR, ATN, and the power
                ;                             operator. Added PLOT. Added PRINT AT and TIMER.
                ; Revision date: Oct/06/2025. Added floating-point number parsing (now can be avoided
                ;                             doing 31416 / 10000). Added FRE operator.
                ; Revision date: Oct/08/2025. Moved tokens back to range $0080 to ease saving and
                ;                             loading programs into cassette. Added LLIST and LPRINT.
                ;                             Added SAVE, LOAD, and VERIFY. Added SPC, TAB, POS, and
                ;                             LPOS.
                ; Revision date: Oct/10/2025. Solved bug in AND, OR, and XOR (it didn't accepted several
                ;                             in line) Solved bug in IF (it didn't warn of syntax error)
                ;                             Solved bug where INPUT was still writing strings in the
                ;                             old way without garbage collection. DIM now clears
                ;                             assigned space. Solved bug where some string weren't
                ;                             cleared when doing RUN. INSTR allows syntax without
                ;                             starting index. Added function POINT(x,y) to read bloxels.
                ;                             Added HEX$.
                ; Revision date: Oct/11/2025. Added DRAW and CIRCLE.
                ; Revision date: Oct/13/2025. Optimized expression parsing.
                ; Revision date: Oct/16/2025. Numbers now are tokenized to avoid parsing in execution time.
                ; Revision date: Oct/17/2025. Line starting with a colon would crash the interpreter.
                ;                             Added literal copy after REM. Solved bug where any
                ;                             space after a quoted string was removed. Typing Esc alone and
                ;                             pressing Enter crashed the interpreter. Cleaned tokenizer,
                ;                             and solved bug where strings had no limit. Solved bug in
                ;                             PRINT where semicolon didn't worked, and missing quote would
                ;                             go into printing all the memory.
                ; Revision date: Oct/18/2025. Solved bug where only the first array could be accessed.
                ;                             DIM now can define multiple arrays in the same statement.
                ;                             Solved bug in get_next_point when ELSE followed.
                ;

                ;
                ; TODO:
                ; * Maybe if tokenizes DATA, avoid tokenizing until finding colon.
                ;

                ROMW 16

                ORG $5000

                ;
                ; The area $8000-$803f is reserved because STIC mirroring.
                ;

basic_buffer:   EQU $8040               ; Tokenized buffer.
basic_buffer_end: EQU $807F
variables:      EQU $8080               ; A-Z
strings:        EQU $80B4               ; A$-Z$
program_start:  EQU $80D0
memory_limit:   EQU $9F00

start_for:      EQU memory_limit-64
end_for:        EQU memory_limit
start_gosub:    EQU memory_limit-128
end_gosub:      EQU memory_limit-64
start_strings:  EQU memory_limit-128
program_limit:  EQU memory_limit-256

STRING_TRASH:   EQU $CAFE

                ;
                ; Token definitions needed for comparisons inside the interpreter.
                ;
TOKEN_START:    EQU $0080

TOKEN_COLON:    EQU TOKEN_START+$00
TOKEN_GOTO:     EQU TOKEN_START+$08
TOKEN_IF:       EQU TOKEN_START+$09
TOKEN_THEN:     EQU TOKEN_START+$0a
TOKEN_ELSE:     EQU TOKEN_START+$0b
TOKEN_TO:       EQU TOKEN_START+$0d
TOKEN_STEP:     EQU TOKEN_START+$0e
TOKEN_GOSUB:    EQU TOKEN_START+$10
TOKEN_REM:      EQU TOKEN_START+$12

TOKEN_DATA:     EQU TOKEN_START+$15

TOKEN_AND:      EQU TOKEN_START+$30
TOKEN_NOT:      EQU TOKEN_START+$31
TOKEN_OR:       EQU TOKEN_START+$32
TOKEN_XOR:      EQU TOKEN_START+$33

TOKEN_LE:       EQU TOKEN_START+$34
TOKEN_GE:       EQU TOKEN_START+$35
TOKEN_NE:       EQU TOKEN_START+$36
TOKEN_EQ:       EQU TOKEN_START+$37
TOKEN_LT:       EQU TOKEN_START+$38
TOKEN_GT:       EQU TOKEN_START+$39

TOKEN_FUNC:     EQU TOKEN_START+$3a

TOKEN_SPC:      EQU TOKEN_START+$5e
TOKEN_TAB:      EQU TOKEN_START+$5f
TOKEN_AT:       EQU TOKEN_START+$60

TOKEN_NUMBER:   EQU $0d
TOKEN_INTEGER:  EQU $08

COLOR_TEXT:     EQU $07
COLOR_TOKEN:    EQU $06
COLOR_NUMBER:   EQU $03

                ;
                ; Error numbers.
                ;
ERR_TITLE:      EQU 0
ERR_SYNTAX:     EQU 1
ERR_STOP:       EQU 2
ERR_LINE:       EQU 3
ERR_GOSUB:      EQU 4
ERR_RETURN:     EQU 5
ERR_FOR:        EQU 6
ERR_NEXT:       EQU 7
ERR_DATA:       EQU 8
ERR_DIM:        EQU 9
ERR_MEMORY:     EQU 10
ERR_ARRAY:      EQU 11
ERR_BOUNDS:     EQU 12
ERR_TYPE:       EQU 13
ERR_TOOBIG:     EQU 14
ERR_NODATA:     EQU 15
ERR_NOFILE:     EQU 16
ERR_MISMATCH:   EQU 17

                ;
                ; Keyboard constants.
                ;
KEY.LEFT        EQU $1C                 ; \   Can't be generated otherwise, so perfect
KEY.RIGHT       EQU $1D                 ;  |_ candidates.  Could alternately send 8 for
KEY.UP          EQU $1E                 ;  |  left... not sure...
KEY.DOWN        EQU $1F                 ; /
KEY.ENTER       EQU $A                  ; Newline
KEY.ESC         EQU 27
KEY.NONE        EQU $FF

                ;
                ; Output constants.
                ;
BAS_CR:         EQU $0d                 ; Carriage Return.
BAS_LF:         EQU $0a                 ; Line Feed.
BAS_BS:         EQU $1C                 ; Same as KEY.LEFT

STACK:          equ $02f0               ; Base stack pointer.

                ;
                ; ROM header
                ;
                BIDECLE _ZERO           ; MOB picture base
                BIDECLE _ZERO           ; Process table
                BIDECLE _MAIN           ; Program start
                BIDECLE _ZERO           ; Background base image
                BIDECLE _ONES           ; GRAM
                BIDECLE _TITLE          ; Cartridge title and date
                DECLE $03C0             ; No ECS title, jump to code after title,
                ; ... no clicks

_ZERO:          DECLE $0000             ; Border control
                DECLE $0000             ; 0 = color stack, 1 = f/b mode

_ONES:          DECLE $0001, $0001      ; Initial color stack 0 and 1: Blue
                DECLE $0001, $0001      ; Initial color stack 2 and 3: Blue
                DECLE $0001             ; Initial border color: Blue

                ;
                ; Clear the screen.
                ;
CLRSCR:         MVII #$200,R4           ; Screen address.
                MVII #$F0,R1            ; 240 cards.
FILLZERO:
                CLRR R0                 ; Zero (or space)
                ;
                ; memset-alike in CP1610 assembler with unrolled loop.
                ;
MEMSET:
                SARC R1,2               ; Get lower 2 bits.
                BNOV $+4                ; Jump if zero or one.
                MVO@ R0,R4              ; It is two, write two words.
                MVO@ R0,R4
                BNC $+3                 ; Jump if zero.
                MVO@ R0,R4              ; It is one or three, write one word.
                BEQ $+7                 ; Zero means it finished.
                MVO@ R0,R4              ; Write four words at a time.
                MVO@ R0,R4
                MVO@ R0,R4
                MVO@ R0,R4
                DECR R1
                BNE $-5
                JR R5

                ;
                ; Title, Intellivision EXEC will jump over it and start
                ; execution directly in _MAIN
                ;
                ; The 125 means year 2025.
                ;
_TITLE:
                BYTE 125, 'ECS Extended BASIC', 0

                ;
                ; Main program
                ;
_MAIN:
                DIS                     ; Disable interrupts
                MVII #STACK,R6

                ;
                ; Clean memory
                ;
                CALL CLRSCR             ; Clean up screen, right here to avoid brief
                ; screen display of title in Sears Intellivision.
                MVII #$00e,R1           ; 14 of sound (ECS)
                MVII #$0f0,R4           ; ECS PSG
                CALL FILLZERO
                MVII #$0fe,R1           ; 240 words of 8 bits plus 14 of sound
                MVII #$100,R4           ; 8-bit scratch RAM
                CALL FILLZERO

                MVII #$058,R1           ; 88 words of 16 bits
                MVII #$308,R4           ; 16-bit scratch RAM
                CALL FILLZERO

                ;
                ; PAL/NTSC detect. Not used actually.
                ;
                CALL _set_isr
                DECLE _pal1
                EIS
                DECR PC                 ; This is a kind of HALT instruction

                ; First interrupt may come at a weird time on Tutorvision, or
                ; if other startup timing changes.
_pal1:          SUBI #8,R6              ; Drop interrupt stack.
                CALL _set_isr
                DECLE _pal2
                DECR PC

                ; Second interrupt is safe for initializing MOBs.
                ; We will know the screen is off after this one fires.
_pal2:          SUBI #8,R6              ; Drop interrupt stack.
                CALL _set_isr
                DECLE _pal3
                ; clear MOBs
                CLRR R0
                CLRR R4
                MVII #$18,R2
_pal2_lp:
                MVO@ R0,R4
                DECR R2
                BNE _pal2_lp
                MVO R0,$30              ; Reset horizontal delay register
                MVO R0,$31              ; Reset vertical delay register

                MVII #-1100,R2          ; PAL/NTSC threshold
_pal2_cnt:
                INCR R2
                B _pal2_cnt

                ; The final count in R2 will either be negative or positive.
                ; If R2 is still -ve, NTSC; else PAL.
_pal3:          SUBI #8,R6              ; Drop interrupt stack.
                RLC R2,1
                RLC R2,1
                ANDI #1,R2              ; 1 = NTSC, 0 = PAL

                ;
                ; Detect ECS. Not used actually.
                ;
                MVII #$55,R1
                MVO R1,$4040
                MVII #$AA,R1
                MVO R1,$4041
                MVI $4040,R1
                CMPI #$55,R1
                BNE _ecs1
                MVI $4041,R1
                CMPI #$AA,R1
                BNE _ecs1
                ADDI #2,R2              ; ECS detected flag
_ecs1:
                MVO R2,_ntsc

                ;
                ; Default video mode is Color Stack mode.
                ;
                CLRR R0
                MVO R0,_mode
                MVII #$1111,R0          ; Blue background.
                MVO R0,_mode_color

                CALL _set_isr
                DECLE _int_vector

                ;
                ; Init primary and secondary sound chips.
                ;
                CLRR R0
                MVO R0,$01fb
                MVO R0,$00fb
                MVO R0,$01fc
                MVO R0,$00fc
                MVO R0,$01fd
                MVO R0,$00fd
                MVII #$38,R0
                MVO R0,$01f8
                MVO R0,$00f8

                ;
                ; Set initial state for UART.
                ;
                CALL printer_reset

                ;
                ; Output reset.
                ;
                MVII #1,R0
                MVO R0,_border_color
                MVII #$07,R0
                MVO R0,bas_curcolor

                CALL new_program        ; Erase program.
                CALL bas_cls            ; Erase screen.
                CLRR R0
                MVO R0,bas_curline      ; Nothing in execution.
                MVII #ERR_TITLE,R0
                CALL bas_error          ; Show welcome message.
                ;
                ; Point for BASIC restart.
                ;
basic_restart:
                MVII #STACK,R6          ; Reset stack.
                MVII #$52,R0            ; R
                CALL bas_output
                MVII #$45,R0            ; E
                CALL bas_output
                MVII #$41,R0            ; A
                CALL bas_output
                MVII #$44,R0            ; D
                CALL bas_output
                MVII #$59,R0            ; Y
                CALL bas_output
                MVII #BAS_CR,R0
                CALL bas_output
                MVII #BAS_LF,R0
                CALL bas_output

                MVI bas_ttypos,R0
                MVO R0,bas_firstpos

                ; Build an example program
                IF 0
                    MVII #program_start,R4
                    MVII #10,R0
                    MVO@ R0,R4
                    MVII #2,R0
                    MVO@ R0,R4
                    MVII #TOKEN_START+$03,R0; CLS Currently
                    MVO@ R0,R4
                    CLRR R0
                    MVO@ R0,R4
                    CLRR R0
                    MVO@ R0,R4
                    CALL bas_list
                ENDI

                ;
                ; Main loop.
                ;
main_loop:
                CALL bas_save_cursor    ; Save content under the cursor.
@@0:
                CALL bas_blink_cursor   ; Blink the cursor.
                CALL SCAN_KBD_DEBOUNCE  ; Explore the keyboard.
                CMPI #KEY.NONE,R0
                BEQ @@0
                CALL bas_restore_cursor ; Restore the content under the cursor.
                CMPI #KEY.ENTER,R0      ; Pressed Enter/Return?
                BNE @@1                 ; No, jump.
                CALL bas_output_newline
                MVI bas_firstpos,R4
                CALL bas_tokenize
                MVI basic_buffer+0,R0
                TSTR R0                 ; Line number found?
                BNE @@2                 ; Yes, jump.
                MVI basic_buffer+1,R0
                CMPI #1,R0              ; Empty line.
                BEQ main_loop
                MVII #basic_buffer,R4
                MVII #$FFFF,R0          ; So it is executed.
                MVO@ R0,R4
                DECR R4
                CALL bas_execute_line   ; Execute direct command.
                B @@3

@@2:            MVI basic_buffer+0,R0
                CALL line_search        ; Search for the line number.
                CMPR R1,R0
                BNE @@4                 ; Jump if not found.
                CALL line_delete        ; Delete it.
@@4:            MVI basic_buffer+2,R0
                TSTR R0                 ; The typed line is empty?
                BEQ @@3                 ; Yes, jump.
                MVI basic_buffer+0,R0
                CALL line_search        ; Search for insertion point.
                MVI basic_buffer+0,R1
                MVI basic_buffer+1,R3
                MVII #basic_buffer+2,R2
                CALL line_insert        ; Insert new line.
                CALL restart_pointers   ; Restart execution pointers.
@@3:
                MVI bas_ttypos,R0
                MVO R0,bas_firstpos
                B main_loop
@@1:
                CALL bas_output         ; Output the typed key.
                B main_loop             ; Repeat the loop.

                ;
                ; Table of statements addresses.
                ;
keywords_exec:
                DECLE bas_syntax_error  ; Colon
                DECLE bas_list
                DECLE bas_new
                DECLE bas_cls
                DECLE bas_run           ; $04
                DECLE bas_stop
                DECLE bas_print
                DECLE bas_input
                DECLE bas_goto          ; $08
                DECLE bas_if
                DECLE bas_syntax_error
                DECLE bas_syntax_error
                DECLE bas_for           ; $0c FOR
                DECLE bas_syntax_error
                DECLE bas_syntax_error
                DECLE bas_next          ; NEXT
                DECLE bas_gosub         ; $10
                DECLE bas_return
                DECLE bas_rem
                DECLE bas_restore
                DECLE bas_read          ; $14
                DECLE bas_data
                DECLE bas_dim
                DECLE bas_mode
                DECLE bas_color         ; $18
                DECLE bas_define
                DECLE bas_sprite
                DECLE bas_wait
                DECLE bas_sound         ; $1c
                DECLE bas_border
                DECLE bas_poke
                DECLE bas_on
                DECLE bas_plot          ; $20
                DECLE bas_load          ; LOAD
                DECLE bas_save          ; SAVE
                DECLE bas_verify        ; VERIFY
                DECLE bas_syntax_error  ; $24
                DECLE bas_llist         ; LLIST
                DECLE bas_lprint        ; LPRINT
                DECLE bas_draw          ; DRAW
                DECLE bas_circle        ; $28 CIRCLE
                DECLE bas_syntax_error
                DECLE bas_syntax_error
                DECLE bas_syntax_error
                DECLE bas_syntax_error  ; $2c
                DECLE bas_syntax_error
                DECLE bas_syntax_error
                DECLE bas_syntax_error

                ; Operators and BASIC functions cannot be executed directly
                DECLE bas_syntax_error  ; AND
                DECLE bas_syntax_error  ; NOT
                DECLE bas_syntax_error  ; OR
                DECLE bas_syntax_error  ; XOR
                DECLE bas_syntax_error  ; <=
                DECLE bas_syntax_error  ; >=
                DECLE bas_syntax_error  ; <>
                DECLE bas_syntax_error  ; =
                DECLE bas_syntax_error  ; <
                DECLE bas_syntax_error  ; >
                DECLE bas_syntax_error  ; INT
                DECLE bas_syntax_error  ; ABS
                DECLE bas_syntax_error  ; SGN
                DECLE bas_syntax_error  ; RND
                DECLE bas_syntax_error  ; STICK
                DECLE bas_syntax_error  ; TRIG
                DECLE bas_syntax_error  ; KEY
                DECLE bas_bk            ; BK
                DECLE bas_syntax_error  ; PEEK
                DECLE bas_syntax_error  ; USR
                DECLE bas_syntax_error  ; ASC
                DECLE bas_syntax_error  ; LEN
                DECLE bas_syntax_error  ; CHR$
                DECLE bas_syntax_error  ; LEFT$
                DECLE bas_syntax_error  ; MID$
                DECLE bas_syntax_error  ; RIGHT$
                DECLE bas_syntax_error  ; VAL
                DECLE bas_syntax_error  ; INKEY$
                DECLE bas_syntax_error  ; STR$
                DECLE bas_syntax_error  ; INSTR
                DECLE bas_syntax_error  ; SIN
                DECLE bas_syntax_error  ; COS
                DECLE bas_syntax_error  ; TAN
                DECLE bas_syntax_error  ; LOG
                DECLE bas_syntax_error  ; EXP
                DECLE bas_syntax_error  ; SQR
                DECLE bas_syntax_error  ; ATN
                DECLE bas_syntax_error  ; TIMER
                DECLE bas_syntax_error  ; FRE
                DECLE bas_syntax_error  ; POS
                DECLE bas_syntax_error  ; LPOS
                DECLE bas_syntax_error  ; SPC
                DECLE bas_syntax_error  ; TAB
                DECLE bas_syntax_error  ; AT

                ;
                ; BASIC keywords.
                ;
keywords:
                DECLE ":",0             ; $00
                DECLE "LIST",0
                DECLE "NEW",0
                DECLE "CLS",0
                DECLE "RUN",0           ; $04
                DECLE "STOP",0
                DECLE "PRINT",0
                DECLE "INPUT",0
                DECLE "GOTO",0          ; $08
                DECLE "IF",0
                DECLE "THEN",0
                DECLE "ELSE",0
                DECLE "FOR",0           ; $0C
                DECLE "TO",0
                DECLE "STEP",0
                DECLE "NEXT",0
                DECLE "GOSUB",0         ; $10
                DECLE "RETURN",0
                DECLE "REM",0
                DECLE "RESTORE",0
                DECLE "READ",0          ; $14
                DECLE "DATA",0
                DECLE "DIM",0
                DECLE "MODE",0
                DECLE "COLOR",0         ; $18
                DECLE "DEFINE",0
                DECLE "SPRITE",0
                DECLE "WAIT",0
                DECLE "SOUND",0         ; $1C
                DECLE "BORDER",0
                DECLE "POKE",0
                DECLE "ON",0
                DECLE "PLOT",0          ; $20
                DECLE "LOAD",0
                DECLE "SAVE",0
                DECLE "VERIFY",0
                DECLE "PLACEHOLDER0",0  ; $24
                DECLE "LLIST",0
                DECLE "LPRINT",0
                DECLE "DRAW",0
                DECLE "CIRCLE",0        ; $28
                DECLE "HOLDER3",0
                DECLE "HOLDER4",0
                DECLE "HOLDER5",0
                DECLE "HOLDER6",0       ; $2C
                DECLE "HOLDER7",0
                DECLE "HOLDER8",0
                DECLE "HOLDER9",0

                DECLE "AND",0           ; $30
                DECLE "NOT",0
                DECLE "OR",0
                DECLE "XOR",0
                DECLE "<=",0            ; $34
                DECLE ">=",0
                DECLE "<>",0
                DECLE "=",0
                DECLE "<",0
                DECLE ">",0
                DECLE "INT",0           ; $3A
                DECLE "ABS",0
                DECLE "SGN",0
                DECLE "RND",0

                DECLE "STICK",0
                DECLE "STRIG",0
                DECLE "KEY",0
                DECLE "BK",0

                DECLE "PEEK",0
                DECLE "USR",0
                DECLE "ASC",0
                DECLE "LEN",0

                DECLE "CHR$",0
                DECLE "LEFT$",0
                DECLE "MID$",0
                DECLE "RIGHT$",0

                DECLE "VAL",0           ; $4A
                DECLE "INKEY$",0
                DECLE "STR$",0
                DECLE "INSTR",0

                DECLE "SIN",0
                DECLE "COS",0
                DECLE "TAN",0
                DECLE "LOG",0

                DECLE "EXP",0           ; $52
                DECLE "SQR",0
                DECLE "ATN",0
                DECLE "TIMER",0

                DECLE "FRE",0           ; $56
                DECLE "POS",0           ; $57
                DECLE "LPOS",0          ; $58
                DECLE "POINT",0         ; $59

                DECLE "HEX$",0          ; $5a
                DECLE "FUNC2",0         ; $5b
                DECLE "FUNC3",0         ; $5c
                DECLE "FUNC4",0         ; $5d

                DECLE "SPC",0           ; $5e
                DECLE "TAB",0           ; $5f
                DECLE "AT",0            ; $60 Must be after ATN
                DECLE 0

                ;
                ; Messages.
                ;
at_line:
                DECLE " at ",0
errors:
                DECLE "ECS extended BASIC",$0d,$0a,"(c)2025 nanochess",0
                DECLE "Syntax error",0
                DECLE "STOP",0
                DECLE "Undefined",0
                DECLE "Too many GOSUB",0
                DECLE "RETURN w/o GOSUB",0
                DECLE "Too many FOR",0
                DECLE "NEXT w/o FOR",0
                DECLE "No DATA found",0
                DECLE "Redefined DIM",0
                DECLE "Out of memory",0
                DECLE "Undefined array",0
                DECLE "Out of bounds",0
                DECLE "Type error",0
                DECLE "Line too big",0
                DECLE "No header found",0
                DECLE "File not found",0
                DECLE "Verify error",0

                ;
                ; Read a line from the input
                ;
                ; Output:
                ;   R4 = Pointer to start of buffer.
                ;   R5 = Pointer after the last character.
                ;
bas_get_line:   PROC
                PSHR R5
                MVII #$3F,R0            ; Question mark.
                CALL bas_output
                MVII #$20,R0            ; Space.
                CALL bas_output
                MVII #basic_buffer,R4
@@2:
                PSHR R4
                CALL bas_save_cursor    ; Save the content under the cursor.
@@0:
                CALL bas_blink_cursor   ; Blink the cursor.
                CALL SCAN_KBD_DEBOUNCE  ; Explore the keyboard.
                CMPI #KEY.NONE,R0
                BEQ @@0
                CALL bas_restore_cursor ; Restore the content under the cursor.
                PULR R4
                CMPI #KEY.ESC,R0        ; Pressing ESC stops the program.
                BEQ bas_stop
                CMPI #KEY.ENTER,R0      ; Pressing Return ends line typing.
                BEQ @@1
                CMPI #KEY.LEFT,R0       ; Left arrow is taken as backspace.
                BNE @@3
                CMPI #basic_buffer,R4   ; Nothing left to backtrack?
                BEQ @@2                 ; No, jump.
                DECR R4
                PSHR R4
                CALL bas_output         ; Move to left.
                MVI bas_ttypos,R4
                MVI bas_curcolor,R0
                MVO@ R0,R4              ; Erase letter.
                PULR R4
                B @@2

@@3:            CMPI #basic_buffer_end,R4; Reached buffer limit?
                BEQ @@2                 ; Yes, don't put anything more.
                MVO@ R0,R4              ; Put into the buffer.
                PSHR R4
                CALL bas_output         ; Display on the screen.
                PULR R4
                B @@2

@@1:            PSHR R4
                CLRR R0                 ; Mark buffer end with a zero word.
                MVO@ R0,R4
                CALL bas_output_newline ; Change line.
                MVII #basic_buffer,R4   ; Return pointer to buffer start.
                PULR R5
                PULR PC
                ENDP

                ;
                ; Search for a line number.
                ; Input:
                ;   R0 = Line number.
                ; Output:
                ;   R1 = Line number (equal or higher).
                ;   R4 = Pointer to the first word of the line.
                ;
line_search:    PROC
                MVII #program_start,R4
                CMP program_end,R4      ; Empty program?
                BEQ @@1                 ; Yes, exit (for insertion).
@@0:            MVI@ R4,R1
                CMPR R0,R1              ; Compare the line number.
                BC @@3                  ; Found the line number? Yes, jump.
                ADD@ R4,R4              ; Jump over the tokens.
                CMP program_end,R4
                BNE @@0
@@1:            CLRR R1                 ; So it is non-equal (for insertion).
@@2:            MOVR R5,PC

@@3:            DECR R4
                MOVR R5,PC
                ENDP

                ;
                ; Delete a line.
                ; R4 = Pointer to first word of the line.
                ;
line_delete:    PROC
                PSHR R5
                INCR R4
                MVI@ R4,R5              ; Get the tokenized length.
                ADDR R4,R5              ; Now R5 points to the next line.
                DECR R4
                DECR R4                 ; R4 points to the line for deletion.
                MOVR R5,R2
                SUBR R4,R2              ; Number of words to delete.
                MVI program_end,R3
                INCR R3
                SUBR R5,R3              ; Number of words to move.
                MVI program_end,R1
                SUBR R2,R1              ; Move end pointer.
                MVO R1,program_end
@@1:            MVI@ R5,R0              ; Block move.
                MVO@ R0,R4
                DECR R3
                BNE @@1
                PULR PC
                ENDP

                ;
                ; Insert a line.
                ; R4 = Pointer to where to insert the line.
                ; R1 = Line number.
                ; R2 = Tokenized line.
                ; R3 = Tokenized length.
                ;
line_insert:    PROC
                PSHR R5
                MVI program_end,R5      ; Get current end pointer.
                MOVR R4,R0
                MOVR R5,R4              ; Copy source pointer to target pointer.
                ADDR R3,R4
                ADDI #2,R4              ; Account for line and length words.
                CMPI #program_limit,R4  ; Exceeds available memory?
                BC @@3                  ; Yes, jump.
                MVO R4,program_end      ; Update end pointer.
                PSHR R1
                MOVR R5,R1
                SUBR R0,R1
                INCR R1
                PSHR R0
@@1:            MVI@ R5,R0              ; Block move.
                DECR R5
                DECR R5
                MVO@ R0,R4
                DECR R4
                DECR R4
                DECR R1
                BNE @@1
                PULR R4
                PULR R1
                MVO@ R1,R4              ; Write the line number.
                MVO@ R3,R4              ; Write the tokenized length.
                MOVR R2,R5
@@2:            MVI@ R5,R0              ; Copy the tokens.
                MVO@ R0,R4
                DECR R3
                BNE @@2
                PULR PC

@@3:            MVII #ERR_MEMORY,R0
                CALL bas_error
                ENDP

                ;
                ; Get next character or token.
                ;
                if 0
get_next:           PROC
                    MVI@ R4,R0              ; Read token.
                    CMPI #$20,R0            ; Is it space?
                    BEQ get_next            ; Yes, jump.
                    MOVR R5,PC              ; Return.
                    ENDP
                endi
                MACRO macro_get_next
                    ; Comment required or as1600 fails.
macgn%%:
                    MVI@ R4,R0
                    CMPI #$20,R0
                    BEQ macgn%%
                ENDM

                ;
                ; Emit a BASIC error and stop execution.
                ;
bas_error:      PROC
                MVII #errors,R4         ; Point to the error messages.
                TSTR R0                 ; Is error number zero?
                BEQ @@2                 ; Yes, jump.
@@1:            MVI@ R4,R1              ; Jump over a message.
                TSTR R1
                BNE @@1
                DECR R0                 ; Decrement error number.
                BNE @@1                 ; Repeat until it is zero.
@@2:
                MVI@ R4,R0              ; Read a character.
                TSTR R0                 ; Is it zero?
                BEQ @@3                 ; Yes, jump.
                PSHR R4
                CALL bas_output         ; Display letter.
                PULR R4
                B @@2

@@3:
                MVI bas_curline,R0
                TSTR R0                 ; Is it running inside a program?
                BEQ @@4                 ; No, jump.
                CMPI #$FFFF,R0
                BEQ @@4
                MVII #at_line,R4        ; Message "at line"
@@5:
                MVI@ R4,R0              ; Read a character.
                TSTR R0                 ; Is it zero?
                BEQ @@6                 ; Yes, jump.
                PSHR R4
                CALL bas_output         ; Display letter.
                PULR R4
                B @@5
@@6:
                MVII #bas_output,R2     ; Setup output function.
                MVO R2,bas_func
                MVI bas_curline,R0      ; Get current line in execution.
                CALL PRNUM16.l          ; Display number.
@@4:
                CALL bas_output_newline
                B basic_restart
                ENDP

                ;
                ; Read a screen card (for tokenization)
                ;
bas_read_card:  PROC
                MVI@ R4,R0              ; Get a screen card.
                ANDI #$0FF8,R0          ; Extract card number.
                SLR R0,2                ; /4
                SLR R0,1                ; /8
                CMPI #$60,R0            ; Beyond valid cards?
                BNC @@1                 ; No, jump.
                MVII #$5F,R0            ; Solid block.
@@1:            ADDI #$20,R0            ; Convert to ASCII.
                MOVR R5,PC              ; Return.
                ENDP

                ;
                ; Tokenize a BASIC line
                ; R4 = Pointer to first character in the screen.
                ;
bas_tokenize:   PROC
                PSHR R5
                CLRR R3
                MVO R3,basic_buffer     ; Line zero
                INCR R3
                MVO R3,basic_buffer+1   ; Tokenized length
                CLRR R3
                MVO R3,basic_buffer+2   ; Mark end of tokenized line.

                MVII #basic_buffer,R3
                CLRR R2                 ; Line number.
@@1:            CMP bas_ttypos,R4       ; Reached the cursor.
                BEQ @@0
                CALL bas_read_card
                CMPI #$20,R0            ; Space character?
                BEQ @@1
                ;
                ; Process the line number if any.
                ;
@@2:
                CMPI #$30,R0            ; Is it a number?
                BNC @@3
                CMPI #$3A,R0
                BC @@3                  ; No, jump.
                SUBI #$30,R0
                MOVR R2,R1
                SLL R2,2
                ADDR R1,R2              ; x5
                ADDR R2,R2              ; x10
                ADDR R0,R2              ; Add number.
                CMP bas_ttypos,R4
                BEQ @@19
                CALL bas_read_card
                B @@2

@@19:           CLRR R0
@@3:            MVO@ R2,R3              ; Take note of the line number
                INCR R3
                INCR R3                 ; Avoid the tokenized length.
                CMPI #$20,R0            ; Space character?
                BNE @@4
@@6:
                CMP bas_ttypos,R4
                BEQ @@5
                CALL bas_read_card
                CMPI #$20,R0            ; Is it space?
                BEQ @@6                 ; Yes, ignore.
                ; Start tokenizing
@@4:            CMPI #$22,R0            ; Quotes?
                BNE @@14
@@15:           CMPI #basic_buffer_end,R3
                BC @@21
                MVO@ R0,R3              ; Pass along string.
                INCR R3
                CMP bas_ttypos,R4
                BEQ @@5
                CALL bas_read_card
                CMPI #$22,R0
                BNE @@15
                CMPI #basic_buffer_end,R3
                BC @@21
                MVO@ R0,R3
                INCR R3
                B @@16

@@14:           CMPI #$2E,R0
                BEQ @@22
                CMPI #$30,R0            ; ASCII character $20-$2f?
                BNC @@20                ; Yes, jump to copy it directly.
                CMPI #$3A,R0
                BC @@23
@@22:           DECR R4
                PSHR R3
                CALL fptokenparse       ; Parse a floating-point number.
                PULR R3
                BNC @@24                ; Jump if integer found.
                CMPI #basic_buffer_end-4,R3
                BC @@21
                MVII #TOKEN_NUMBER,R2   ; Store tokenized floating-point number.
                MVO@ R2,R3
                INCR R3
                MOVR R1,R2
                ANDI #$00FF,R2
                MVO@ R2,R3
                INCR R3
                SWAP R1
                ANDI #$00FF,R1
                MVO@ R1,R3
                INCR R3
                MOVR R0,R2
                ANDI #$00FF,R2
                MVO@ R2,R3
                INCR R3
                SWAP R0
                ANDI #$00FF,R0
                MVO@ R0,R3
                INCR R3
                B @@16
@@24:
                CMPI #basic_buffer_end-2,R3
                BC @@21
                MVII #TOKEN_INTEGER,R2  ; Store tokenized integer.
                MVO@ R2,R3
                INCR R3
                MOVR R0,R2
                ANDI #$00FF,R2
                MVO@ R2,R3
                INCR R3
                SWAP R0
                ANDI #$00FF,R0
                MVO@ R0,R3
                INCR R3
                B @@16
@@23:
                DECR R4
                MVII #keywords,R2
                MVII #TOKEN_START,R5
@@8:            PSHR R4
                ;
                ; Compare input against possible token.
                ;
@@11:           MVI@ R4,R0
                ANDI #$0FF8,R0
                SLR R0,2
                SLR R0,1
                CMPI #$41,R0            ; Convert lowercase to uppercase.
                BLT @@9
                CMPI #$5B,R0
                BGE @@9
                SUBI #$20,R0
@@9:            ADDI #$20,R0            ; Now it is ASCII value.
                CMP@ R2,R0
                BNE @@10
                INCR R2
                MVI@ R2,R0
                TSTR R0                 ; End of token?
                BNE @@11
                CMPI #basic_buffer_end,R3
                BEQ @@21
                MVO@ R5,R3              ; Write token.
                INCR R3
                CMPI #TOKEN_REM,R5
                PULR R5                 ; Ignore restart position.
                BNE @@16
                ; Literal copy after REM
@@27:
                CMP bas_ttypos,R4
                BEQ @@5
                CALL bas_read_card
                CMPI #basic_buffer_end,R3
                BEQ @@21
                MVO@ R0,R3
                INCR R3
                B @@27

@@10:           MVI@ R2,R0
                INCR R2
                TSTR R0
                BNE @@10
                INCR R5                 ; Next token
                PULR R4                 ; Restart input position.
                MVI@ R2,R0
                TSTR R0
                BNE @@8
                ; No token found
@@7:            CALL bas_read_card
@@20:
                CMPI #$61,R0
                BNC @@18
                CMPI #$7B,R0
                BC @@18
                SUBI #$20,R0
@@18:
                CMPI #basic_buffer_end,R3
                BEQ @@21
                MVO@ R0,R3
                INCR R3
@@16:
                CMP bas_ttypos,R4
                BEQ @@5
                CALL bas_read_card
                B @@4

                ; End of tokenized line
                ; Remove trailing spaces.
@@5:            CMPI #basic_buffer+2,R3
                BEQ @@17
                DECR R3
                MVI@ R3,R2
                CMPI #$20,R2
                BEQ @@5
                INCR R3
@@17:
                CLRR R2
                MVO@ R2,R3
                INCR R3
                MVO@ R2,R3
                SUBI #basic_buffer+2,R3
                MVO R3,basic_buffer+1   ; Take note of the length
@@0:            PULR PC

@@21:           MVII #ERR_TOOBIG,R0
                CALL bas_error
                ENDP

                ;
                ; Execute a BASIC line
                ; r4 = Pointer to start of line.
                ;
bas_execute_line: PROC
                PSHR R5
@@0:
                MVI@ R4,R0              ; Get line number.
                TSTR R0                 ; Is it zero?
                BEQ @@3                 ; Yes, end of program reached, jump.
                MVO R0,bas_curline      ; No, save as current line number.
                INCR R4                 ; Jump over tokenized length.
@@2:            MVI@ R4,R0              ; Read a token.
                TSTR R0                 ; End of line?
                BEQ @@0                 ; Yes, jump.
                MVI bas_strbase,R1
                MVO R1,bas_strptr       ; Reset strings stack.
                CALL bas_execute.5      ; Execute a statement.
                macro_get_next
                TSTR R0                 ; End of line?
                BEQ @@0                 ; Yes, jump.
                CMPI #TOKEN_ELSE,R0     ; ELSE?
                BEQ @@1                 ; Yes, jump over.
                CMPI #TOKEN_COLON,R0    ; :
                BEQ @@2                 ; Yes, jump to execute another statement.
                MVII #ERR_SYNTAX,R0
                CALL bas_error

                ;
                ; Jump over the remainder of the line.
                ;
@@1:            MVI@ R4,R0
                CMPI #TOKEN_INTEGER,R0
                BNE @@4
                ADDI #2,R4
@@4:            CMPI #TOKEN_NUMBER,R0
                BNE @@5
                ADDI #4,R4
@@5:            TSTR R0
                BNE @@1
                B @@0

@@3:            PULR PC
                ENDP

                ;
                ; Execute a BASIC statement
                ;
bas_execute:    PROC
                MVI bas_strbase,R1
                MVO R1,bas_strptr       ; Reset strings stack.
@@0:
                MVI@ R4,R0
@@5:
                CMPI #$20,R0            ; Space found?
                BEQ @@0                 ; Yes, ignore.
                CMPI #TOKEN_START,R0    ; Token found?
                BC @@2                  ; Yes, jump.
                ; Try an assignment
                CMPI #$41,R0            ; A-Z?
                BNC @@1
                CMPI #$5B,R0
                BC @@1                  ; No, jump.
                MVI@ R4,R1
                CMPI #$24,R1            ; Is it string?
                BNE @@3                 ; No, jump.
                PSHR R5
                CALL get_string_addr.0  ; Get string variable address.
                PSHR R5
                macro_get_next
                CMPI #TOKEN_EQ,R0       ; Look for =
                BNE @@1
                CALL bas_expr           ; Process expression.
                BNC @@4                 ; Jump if not string.
                PULR R1
                PSHR R4
                CALL string_assign      ; Assign the string.
                PULR R4
                PULR PC

@@3:            PSHR R5
                DECR R4
                CALL get_var_addr.0     ; Get variable address.
                PSHR R1
                macro_get_next
                CMPI #TOKEN_EQ,R0       ; Look for =
                BNE @@1
                CALL bas_expr           ; Process expression.
                BC @@4                  ; Jump if not numeric.
                PULR R5
                MVO@ R2,R5              ; Assign value.
                MVO@ R3,R5
                PULR PC

@@1:
                MVII #ERR_SYNTAX,R0
                CALL bas_error

@@4:
                MVII #ERR_TYPE,R0
                CALL bas_error

@@2:            MVII #keywords_exec-TOKEN_START,R3
                ADDR R0,R3
                MVI@ R3,PC              ; Execute statement.

                ENDP

                ;
                ; LIST
                ;
                ; List the program to the screen.
                ;
bas_list:       PROC
                MVII #bas_output,R2
                MVO R2,bas_func
                B bas_generic_list
                ENDP

                ;
                ; LLIST
                ;
                ; List the program to the printer.
                ;
bas_llist:      PROC
                MVII #printer_output,R2
                MVO R2,bas_func
                B bas_generic_list
                ENDP

                ;
                ; List the program.
                ;
bas_generic_list: PROC
                PSHR R5
                CALL parse_integer      ; Look for a line number.
                BC @@10                 ; Jump if no integer.
                MVO R0,bas_listen       ; Use same line number to end.
                PSHR R4
                CALL line_search        ; Get the start point.
                B @@11

@@10:           DECR R4
                PSHR R4
                MVII #$FFFF,R0
                MVO R0,bas_listen
                MVII #program_start,R4  ; List from the start of the program.
@@11:           MOVR R4,R5              ; Save start pointer.
                PULR R4
                PSHR R5
                macro_get_next
                CMPI #$2D,R0            ; Range?
                BNE @@12                ; No, jump.
                MVII #$FFFF,R0
                MVO R0,bas_listen
                CALL parse_integer      ; Look for a line number.
                BC @@12                 ; Jump if no integer.
                MVO R0,bas_listen       ; Take note of ending line.
                INCR R7                 ; Jump over next instruction.

@@12:           DECR R4
                PULR R5
                PSHR R4
                MOVR R5,R4

                ;
                ; Inner loop.
                ;
@@1:            MVI@ R4,R0              ; Read line number.
                TSTR R0                 ; End of the program?
                BEQ @@2                 ; Yes, jump.
                CMP bas_listen,R0       ; Reached line limit?
                BEQ @@15
                BC @@2                  ; Yes, exit.
@@15:
                PSHR R4
                MVII #COLOR_TEXT,R1
                MVO R1,bas_curcolor
                CALL PRNUM16.l          ; Print line number.
                MVII #$20,R0            ; Space.
                CALL indirect_output
                PULR R4
                MVI@ R4,R1              ; Tokenized length.
@@4:
                MVI@ R4,R0              ; Read token.
                TSTR R0                 ; Is it end of line?
                BEQ @@3                 ; Yes, jump.
                CMPI #$22,R0            ; Is it a string?
                BNE @@19                ; No, jump.
                MVII #COLOR_TEXT,R1
                MVO R1,bas_curcolor
@@20:
                PSHR R4
                CALL indirect_output    ; Output string data.
                PULR R4
                MVI@ R4,R0
                TSTR R0                 ; Is it end of line?
                BEQ @@3                 ; Yes, jump.
                CMPI #$22,R0            ; Is it end of string?
                BNE @@20                ; No, jump.
                PSHR R4
                CALL indirect_output
                PULR R4
                B @@4
@@19:
                CMPI #TOKEN_NUMBER,R0
                BEQ @@5
                CMPI #TOKEN_INTEGER,R0
                BEQ @@14
                CMPI #TOKEN_START,R0    ; Is it a token?
                BC @@16                 ; Yes, jump.
                CMPI #$2B,R0
                BEQ @@17
                CMPI #$2D,R0
                BEQ @@17
                CMPI #$2A,R0
                BEQ @@17
                CMPI #$2F,R0
                BEQ @@17
                CMPI #$5E,R0
                BEQ @@17
                MVII #COLOR_TEXT,R1
                B @@18
@@17:
                MVII #COLOR_TOKEN,R1
@@18:           MVO R1,bas_curcolor
                PSHR R4
                CALL indirect_output
                PULR R4
                B @@4

                ; Tokenized floating-point number.
@@5:            MVII #COLOR_NUMBER,R1
                MVO R1,bas_curcolor
                MVI@ R4,R1              ; Rebuild in two registers.
                MVI@ R4,R2
                SWAP R2
                ADDR R2,R1
                MVI@ R4,R0
                MVI@ R4,R2
                SWAP R2
                ADDR R2,R0
                PSHR R4
                CLRR R3
                CALL fpprint            ; Output floating-point number.
                PULR R4
                B @@4

                ; Tokenized integer.
@@14:           MVII #COLOR_NUMBER,R1
                MVO R1,bas_curcolor
                MVI@ R4,R0              ; Rebuild integer.
                MVI@ R4,R1
                SWAP R1
                ADDR R1,R0
                PSHR R4
                CALL PRNUM16.l          ; Output number.
                PULR R4
                B @@4

                ; Token
@@16:           MVII #COLOR_TOKEN,R1
                MVO R1,bas_curcolor
                MVII #keywords,R5       ; Point to keywords list.
                SUBI #TOKEN_START,R0
                BEQ @@6
@@7:            MVI@ R5,R1
                TSTR R1                 ; Jump over keyword.
                BNE @@7
                DECR R0                 ; Decrement counter.
                BNE @@7
@@6:            PSHR R4
@@8:            MVI@ R5,R0              ; Read char.
                TSTR R0                 ; Is it zero?
                BEQ @@9                 ; Yes, jump.
                PSHR R5
                CALL indirect_output    ; Display character.
                PULR R5
                B @@8

@@9:            PULR R4
                B @@4

@@3:            PSHR R4
                MVII #BAS_CR,R0
                CALL indirect_output
                MVII #BAS_LF,R0
                CALL indirect_output
                PULR R4
                B @@1

@@2:            MVII #COLOR_TEXT,R1
                MVO R1,bas_curcolor
                PULR R4
                PULR PC

                ENDP

                ;
                ; Erase the whole program.
                ;
new_program:    PROC
                PSHR R5
                MVII #program_start,R4
                MVO R4,program_end
                CLRR R0
                MVO@ R0,R4
                CALL restart_pointers
                PULR PC
                ENDP

                ;
                ; NEW
                ;
                ; Erase the whole program.
                ; Execution cannot continue.
                ;
bas_new:        PROC
                CALL new_program
                B basic_restart
                ENDP

                ;
                ; CLS
                ;
                ; Clear the screen.
                ;
bas_cls:        PROC
                PSHR R5
                PSHR R4
                MVII #$0200,R4          ; Pointer to the screen.
                MVO R4,bas_ttypos
                MVI bas_curcolor,R0
                MVII #$00F0,R1
                CALL MEMSET
                PULR R4
                PULR PC
                ENDP

                ;
                ; RUN
                ;
                ; Run the program
                ;
bas_run:        PROC
                CALL parse_integer      ; Look for a line number.
                BC @@2                  ; Jump if not found.
                CALL line_search        ; Search the line.
                CMPR R1,R0
                BEQ @@3                 ; Jump if found.
                MVII #ERR_LINE,R0
                CALL bas_error

@@2:            MVII #program_start,R4
@@3:            PSHR R4
                MVII #start_for,R0
                MVO R0,bas_forptr
                MVII #start_gosub,R0
                MVO R0,bas_gosubptr

                CALL restart_pointers
                PULR R4

                MVII #STACK,R6
                CALL bas_execute_line
                B basic_restart
                ENDP

                ;
                ; Restart program context.
                ;
restart_pointers: PROC
                PSHR R5
                CLRR R0
                MVO R0,bas_dataptr

                MVI program_end,R3      ; Get pointer to final word (zero)
                INCR R3                 ; Jump over the final word.
                MVO R3,bas_arrays       ; Use as start for array list.
                CLRR R0                 ; No arrays in the list.
                MVO@ R0,R3              ; Take note.
                MVO R3,bas_last_array   ; Pointer to the last array.

                MVII #variables,R4
                CLRR R0
                MVII #26*2+26,R1        ; Reset variables and string variables
                CALL MEMSET

                MVII #start_strings,R4  ; Reset string base stack.
                MVO R4,bas_strbase

                PULR PC
                ENDP

                ;
                ; Stop the program
                ;
bas_stop:       PROC
                MVII #ERR_STOP,R0
                CALL bas_error
                ENDP

                ;
                ; PRINT
                ;
                ; Print to the screen.
                ;
bas_print:      PROC
                MVII #bas_output,R2
                MVO R2,bas_func
                B bas_generic_print
                ENDP

                ;
                ; LPRINT
                ;
                ; Print to the printer.
                ;
bas_lprint:     PROC
                MVII #printer_output,R2
                MVO R2,bas_func
                B bas_generic_print
                ENDP

                ;
                ; Generic print routine.
                ;
bas_generic_print: PROC
                PSHR R5
                macro_get_next
                CMPI #TOKEN_AT,R0       ; PRINT AT?
                BNE @@17                ; No, jump.
                CALL bas_expr_int       ; Get integer.
                CMPI #240,R0            ; Exceeds screen?
                BC @@10                 ; Yes, jump.
                ADDI #$0200,R0
                MVO R0,bas_ttypos       ; Set up as new cursor position.
                macro_get_next          ; Check for end of statement.
                CMPI #TOKEN_COLON,R0
                BEQ @@15
                CMPI #TOKEN_ELSE,R0
                BEQ @@15
                TSTR R0
                BNE @@5
@@15:
                DECR R4
                PULR PC
                ;
                ; Main parser
                ;
@@3:
                macro_get_next
                ; Ending the statement at this point generates a new line.
@@17:
                TSTR R0
                BEQ @@6
                CMPI #TOKEN_COLON,R0
                BEQ @@6
                CMPI #TOKEN_ELSE,R0
                BEQ @@6
@@5:
                CMPI #$22,R0            ; Quotes start?
                BNE @@2
@@1:
                MVI@ R4,R0
                TSTR R0
                BEQ @@6
                CMPI #$22,R0            ; Quotes end?
                BEQ @@3
                PSHR R4
                CALL indirect_output    ; Output the string.
                PULR R4
                B @@1

@@2:            CMPI #$3B,R0            ; Semicolon?
                BNE @@4                 ; No, jump.
                macro_get_next
                CMPI #TOKEN_ELSE,R0
                BEQ @@16
                CMPI #TOKEN_COLON,R0
                BEQ @@16
                TSTR R0
                BNE @@5
@@16:
                DECR R4
                PULR PC
@@6:
                DECR R4
                PSHR R4
                MVII #BAS_CR,R0         ; New line.
                CALL indirect_output
                MVII #BAS_LF,R0
                CALL indirect_output
                PULR R4
                PULR PC

@@4:            CMPI #TOKEN_SPC,R0      ; SPC?
                BNE @@11
                CALL bas_expr_paren     ; Get expression.
                BC bas_type_err
                CALL fp2int             ; Convert to integer.
@@12:           CMPI #0,R0
                BLE @@3
                PSHR R4
                PSHR R0
                MVII #$20,R0            ; Output space.
                CALL indirect_output
                PULR R0
                PULR R4
                DECR R0
                B @@12

@@11:           CMPI #TOKEN_TAB,R0      ; TAB?
                BNE @@14
                CALL bas_expr_paren     ; Get expression.
                BC bas_type_err
                CALL fp2int             ; Convert to integer.
                PSHR R0
                MVII #$FFFF,R0
                CALL indirect_output    ; Get current column.
                INCR R0                 ; Column starts with 1.
                MOVR R0,R1
                PULR R0
                SUBR R1,R0
                B @@12                  ; Reuse SPC.

@@14:
                DECR R4
                ;
                ; Process expression.
                ;
                CALL bas_expr
                BC @@9                  ; Is it a string? Jump.
                ;
                ; Print number.
                ;
                PSHR R4
                MOVR R2,R0
                MOVR R3,R1
                MVII #1,R3
                CALL fpprint
                PULR R4
                B @@3

                ;
                ; Print string.
                ;
@@9:            PSHR R4
                MVI@ R3,R0
                INCR R3
                TSTR R0                 ; Is length zero?
                BEQ @@8                 ; Yes, jump.
@@7:
                PSHR R0
                PSHR R3
                MVI@ R3,R0
                CALL indirect_output
                PULR R3
                PULR R0
                INCR R3
                DECR R0
                BNE @@7
@@8:
                PULR R4
                B @@3

                MVII #ERR_SYNTAX,R0
                CALL bas_error

@@10:           MVII #ERR_BOUNDS,R0
                CALL bas_error

                PULR PC
                ENDP

                ;
                ; INPUT
                ;
bas_input:      PROC
                PSHR R5
@@3:
                macro_get_next
@@5:
                TSTR R0
                BEQ @@6
                CMPI #TOKEN_COLON,R0
                BEQ @@6
                CMPI #TOKEN_ELSE,R0
                BEQ @@6
                CMPI #$22,R0            ; Quotes start?
                BNE @@4                 ; No, jump.
@@1:
                MVI@ R4,R0
                TSTR R0                 ; End of line found?
                BEQ @@5                 ; Yes, jump.
                CMPI #$22,R0            ; Quotes end?
                BEQ @@2                 ; Yes, jump.
                PSHR R4
                CALL bas_output         ; Display letter.
                PULR R4
                B @@1

@@2:            macro_get_next
                CMPI #$3B,R0
                BNE @@6
                macro_get_next
@@4:
                CMPI #$41,R0            ; Variable name A-Z?
                BNC @@6
                CMPI #$5B,R0
                BC @@6                  ; No, jump.
                MVI@ R4,R1
                CMPI #$24,R1            ; String variable?
                BEQ @@7
                DECR R4
                PSHR R4
                PSHR R0
                CALL bas_get_line       ; Read line.
                macro_get_next
                CALL fpparse            ; Parse floating-point number.
                PULR R2
                SUBI #$41,R2
                SLL R2,1
                MVII #variables,R5
                ADDR R2,R5
                MVO@ R0,R5              ; Assign number.
                MVO@ R1,R5
                PULR R4
                PULR PC

@@7:            PSHR R4
                PSHR R0
                CALL bas_get_line       ; Read line.
                SUBR R4,R5              ; Get length of string.
                MOVR R5,R1
                MOVR R4,R0
                CALL string_create
                PULR R0
                MVII #strings-$41,R1
                ADDR R0,R1
                CALL string_assign      ; Assign string.
                PULR R4
                PULR PC

@@6:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                PULR PC
                ENDP

                ;
                ; Check for Esc key pressed to stop execution
                ;
bas_check_esc:  PROC
                ; Check at 15 hz.
                MVI _frame,R0
                ANDI #$00FC,R0
                CMP _check_esc,R0
                BEQ @@1
                MVO R0,_check_esc

                PSHR R4
                PSHR R5
                CALL SCAN_KBD           ; Explore the keyboard.
                PULR R5
                PULR R4
                CMPI #KEY.ESC,R0
                BNE @@1
                MVII #ERR_STOP,R0
                CALL bas_error
@@1:            MOVR R5,PC
                ENDP

                ;
                ; GOTO
                ;
bas_goto:       PROC
                PSHR R5
@@0:
                CALL parse_integer      ; Look for line number.
                BC @@5                  ; Jump if not found.
@@1:            ; Entry point for ON GOTO
                CALL line_search
                CMPR R1,R0
                BNE @@3
                CALL bas_check_esc
                MVII #STACK,R6
                CALL bas_execute_line
                B basic_restart

@@3:            MVII #ERR_LINE,R0
                CALL bas_error

@@5:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; IF
                ;
bas_if:         PROC
                PSHR R5
                CALL bas_expr           ; Process expression.
                BC @@0                  ; Jump if not numeric.
                ANDI #$7F,R3            ; Is it zero?
                BEQ @@1                 ; Yes, jump.
                macro_get_next
                CMPI #TOKEN_THEN,R0     ; Is it THEN?
                BNE @@2                 ; No, jump.
                macro_get_next
                CMPI #TOKEN_INTEGER,R0  ; Is it line number?
                BNE @@3                 ; No, jump.
                DECR R4
                B bas_goto.0            ; Yes, handle like GOTO.
@@3:
                PULR R5
                DECR R4
                B bas_execute
@@2:
                CMPI #TOKEN_GOTO,R0     ; Is it GOTO?
                BNE @@0                 ; No, jump.
                PULR R5
                B bas_goto

@@1:            CLRR R5
@@6:
                macro_get_next
                CMPI #TOKEN_INTEGER,R0
                BNE @@7
                ADDI #2,R4
@@7:
                CMPI #TOKEN_NUMBER,R0
                BNE @@8
                ADDI #4,R4
@@8:
                TSTR R0                 ; Reached end of line?
                BEQ @@4                 ; Yes, no ELSE found.
                CMPI #TOKEN_THEN,R0
                BNE @@5
                INCR R5                 ; Increase depth.
@@5:            CMPI #TOKEN_ELSE,R0
                BNE @@6
                DECR R5                 ; Decrease depth.
                BNE @@6
                PULR R5
                B bas_execute

@@4:            DECR R4
                PULR PC

@@0:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Get next point for execution
                ;
get_next_point: PROC
@@2:
                MVI@ R4,R0              ; Get next token.
                TSTR R0                 ; Is it end of line?
                BEQ @@1                 ; Yes, jump.
                CMPI #$20,R0
                BEQ @@2
                CMPI #TOKEN_COLON,R0
                BEQ @@3
                CMPI #TOKEN_ELSE,R0
                BNE @@4
                ; If the ELSE token is found, ignore remaining of the line.
@@5:            MVI@ R4,R0
                CMPI #TOKEN_INTEGER,R0
                BNE @@6
                ADDI #2,R4
@@6:            CMPI #TOKEN_NUMBER,R0
                BNE @@7
                ADDI #4,R4
@@7:            TSTR R0
                BNE @@5
                B @@1

@@1:            MVI@ R4,R1              ; Get line number.
                TSTR R1                 ; End of program?
                BEQ @@4                 ; Yes, jump.
                INCR R4                 ; Jump over tokenized length.
                B @@3
@@4:
                MVII #ERR_SYNTAX,R0
                CALL bas_error
@@3:
                MOVR R5,PC
                ENDP

                ;
                ; Get variable address
                ;
get_var_addr:   PROC
                CMPI #$41,R0            ; A-Z?
                BNC @@1
                CMPI #$5B,R0
                BC @@1                  ; No, jump.
@@0:
                MOVR R0,R2
                macro_get_next
                CMPI #$28,R0            ; Array?
                BNE @@2                 ; No, jump.
                PSHR R5
                PSHR R2
                CALL bas_expr           ; Get index.
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2uint            ; Convert to integer.
                PULR R2
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@1
                PSHR R4
                MVI bas_arrays,R1
@@3:            MVI@ R1,R4              ; Read name.
                TSTR R4                 ; End of arrays?
                BEQ @@5                 ; Yes, error.
                CMP@ R1,R2              ; Name comparison.
                BEQ @@4                 ; Jump if found.
                INCR R1                 ; Jump over name.
                MVI@ R1,R0              ; Get length.
                INCR R1                 ; Jump over length.
                SLL R0,1                ; Length x2.
                ADDR R0,R1              ; Jump over contents.
                B @@3                   ; Keep searching.

@@4:            INCR R1                 ; Jump over name.
                PULR R4                 ; Restore parsing position.
                PULR R0                 ; Restore desired index.
                CMP@ R1,R0              ; Is index bigger than length?
                BC @@6                  ; Yes, error.
                INCR R1                 ; Point to array contents.
                SLL R0,1                ; Adjust index.
                ADDR R0,R1              ; Point to desired element.
                PULR PC                 ; Return.

@@2:            DECR R4
                SLL R2,1
                MVII #variables-$41*2,R1
                ADDR R2,R1              ; Get variable address.
                MOVR R5,PC              ; Return.

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error

@@5:            MVII #ERR_ARRAY,R0
                CALL bas_error

@@6:            MVII #ERR_BOUNDS,R0
                CALL bas_error

                ENDP

                ;
                ; FOR
                ;
bas_for:        PROC
                PSHR R5
                MVI bas_forptr,R5
                CMPI #end_for-5,R5      ; Check if space available for FOR?
                BC @@1                  ; No, jump.
                ; Try an assignment
                macro_get_next
                CALL get_var_addr       ; Get variable address.
                MVI bas_forptr,R3
                MVO@ R1,R3              ; Take note of the variable.
                PSHR R1
                macro_get_next
                CMPI #TOKEN_EQ,R0       ; =
                BNE @@2
                CALL bas_expr           ; Process expression.
                BC @@2                  ; Error if not numeric.
                PULR R5
                MVO@ R2,R5              ; Assign initial value.
                MVO@ R3,R5
                macro_get_next
                CMPI #TOKEN_TO,R0       ; TO
                BNE @@2
                MVI bas_forptr,R3
                INCR R3
                INCR R3
                MVO@ R4,R3              ; Take note of TO expression.
                CALL bas_expr           ; Evaluate once.
                macro_get_next
                MVI bas_forptr,R3
                INCR R3
                CMPI #TOKEN_STEP,R0
                BNE @@3
                MVO@ R4,R3              ; Take note of STEP expression.
                CALL bas_expr           ; Evaluate once.
                B @@4

@@3:            CLRR R2
                MVO@ R2,R3              ; No STEP expression.
                DECR R4
@@4:            PSHR R4
                CALL get_next_point
                MVI bas_forptr,R3
                INCR R3
                INCR R3
                INCR R3
                MVO@ R4,R3              ; Parsing position.
                INCR R3
                MVO@ R1,R3              ; Line.
                INCR R3
                MVO R3,bas_forptr
                PULR R4
                PULR PC
@@1:
                MVII #ERR_FOR,R0
                CALL bas_error
@@2:
                MVII #ERR_SYNTAX,R0
                CALL bas_error
                PULR PC
                ENDP

                ;
                ; NEXT
                ;
bas_next:       PROC
                PSHR R5
                CALL bas_check_esc      ; Check for Esc key.
                MVI bas_forptr,R5       ; Get latest FOR loop.
                CMPI #start_for,r5      ; Nothing?
                BNE @@1                 ; No, jump.
@@0:
                MVII #ERR_NEXT,R0
                CALL bas_error
@@1:            macro_get_next
                CMPI #$41,R0            ; Variable name?
                BNC @@2
                CMPI #$5B,R0
                BC @@2                  ; No, jump.
                CALL get_var_addr.0     ; Get variable address.
                MVI bas_forptr,R3
@@3:            CMPI #start_for,R3
                BEQ @@0
                SUBI #5,R3
                CMP@ R3,R1              ; Find in FOR stack
                BNE @@3
                B @@4

@@2:            DECR R4
                MVI bas_forptr,R3       ; Use most recent FOR.
                DECR R3
                DECR R3
                DECR R3
                DECR R3
                DECR R3
@@4:            PSHR R4
                MOVR R3,R5
                MVI@ R5,R3              ; Variable address.
                PSHR R3
                MVI@ R3,R0              ; Read value
                INCR R3
                MVI@ R3,R1
                MVI@ R5,R4              ; Read STEP value.
                PSHR R5
                TSTR R4
                BEQ @@5
                PSHR R0
                PSHR R1
                CALL bas_expr
                PULR R1
                PULR R0
                B @@6
@@5:
                CLRR R2
                MVII #$003F,R3          ; 1.0
@@6:
                MOVR R3,R4
                ANDI #$80,R4
                MVO R4,temp1
                CALL fpadd              ; Do addition/subtraction.
                PULR R5
                PULR R3
                MVO@ R0,R3              ; Save new value.
                INCR R3
                MVO@ R1,R3
                MVI@ R5,R4              ; Read TO value.
                PSHR R5
                PSHR R0
                PSHR R1
                CALL bas_expr           ; Process TO expression.
                PULR R1
                PULR R0
                MVI temp1,R4
                TSTR R4
                BEQ @@7
                CALL fpcomp
                BC @@8
                B @@9
@@7:
                CALL fpcomp
                BEQ @@8
                BC @@9

@@8:            PULR R5
                PULR R4                 ; Previous parsing position.
                MVI@ R5,R4
                MVI@ R5,R1
                MVO R1,bas_curline
                PULR R5
                B bas_execute

@@9:            PULR R5
                PULR R4
                DECR R5
                DECR R5
                DECR R5
                MVO R5,bas_forptr
                PULR PC

                ENDP

                ;
                ; GOSUB
                ;
bas_gosub:      PROC
                PSHR R5
                CALL parse_integer      ; Find line number.
                BC @@0                  ; No, jump.
@@1:            ; Entry point for ON GOSUB
                MOVR R0,R2
                CALL get_next_point
                MVI bas_gosubptr,R5
                CMPI #end_gosub-2,R5    ; GOSUB stack filled?
                BC @@5                  ; Yes, jump.
                MVO@ R4,R5
                MVO@ R1,R5
                MVO R5,bas_gosubptr
                MOVR R2,R0
                CALL line_search        ; Search for the line.
                CMPR R1,R0
                BEQ @@3
                MVII #ERR_LINE,R0
                CALL bas_error
@@3:
                CALL bas_check_esc
                MVII #STACK,R6
                CALL bas_execute_line
                B basic_restart

@@5:            MVII #ERR_GOSUB,R0
                CALL bas_error

@@0:            MVII #ERR_SYNTAX,R0
                CALL bas_error

                ENDP

                ;
                ; RETURN
                ;
bas_return:     PROC
                PSHR R5
                MVI bas_gosubptr,R5
                CMPI #start_gosub,r5    ; Something on the stack?
                BNE @@1                 ; No, jump.
                MVII #ERR_RETURN,R0
                CALL bas_error
@@1:            DECR R5
                DECR R5
                MVO R5,bas_gosubptr     ; Pop stack.
                MVI@ R5,R4
                MVI@ R5,R1
                MVO R1,bas_curline
                PULR R5
                B bas_execute
                ENDP

                ;
                ; REM
                ;
bas_rem:        PROC
@@1:            MVI@ R4,R0
                CMPI #TOKEN_NUMBER,R0
                BEQ @@2
                CMPI #TOKEN_INTEGER,R0
                BEQ @@3
                TSTR R0
                BNE @@1
                DECR R4
                MOVR R5,PC

@@2:            ADDI #4,R4
                B @@1

@@3:            ADDI #2,R4
                B @@1
                ENDP

                ;
                ; Locate the first DATA statement in the program
                ;
                ; Output:
                ;   R4 = Pointer to first DATA element (or zero if none).
                ;
data_locate:    PROC
                PSHR R5
                MVII #program_start,R4
@@3:            MVI@ R4,R0              ; Get pointer.
                INCR R4                 ; Jump over the line number.
                TSTR R0                 ; End of program?
                BEQ @@1                 ; Yes, jump.
@@2:            MVI@ R4,R0              ; Read tokenized line.
                TSTR R0                 ; End of line?
                BEQ @@3                 ; Yes, jump.
                CMPI #TOKEN_NUMBER,R0
                BNE @@4
                ADDI #4,R4
@@4:            CMPI #TOKEN_INTEGER,R0
                BNE @@5
                ADDI #2,R4
@@5:            CMPI #TOKEN_DATA,R0     ; Found DATA statement?
                BNE @@2                 ; No, jump.
                PULR PC

@@1:            CLRR R4
                PULR PC
                ENDP

                ;
                ; RESTORE
                ;
bas_restore:    PROC
                PSHR R5
                CALL parse_integer      ; Find line number.
                BC @@1                  ; Jump if there is none.
                PSHR R4
                CALL line_search
                CMPR R1,R0
                BNE @@5                 ; Jump if not found.
                INCR R4
                INCR R4
@@7:
                MVI@ R4,R0
                TSTR R0
                BEQ @@6
                CMPI #TOKEN_DATA,R0
                BNE @@7
                B @@2
                ; No line number
@@1:            DECR R4
                PSHR R4
                CALL data_locate
                TSTR R4
                BEQ @@6
@@2:            MVO R4,bas_dataptr
                PULR R4
                PULR PC

@@6:
                MVII #ERR_DATA,R0
                CALL bas_error
@@5:
                MVII #ERR_LINE,R0
                CALL bas_error
                ENDP

                ;
                ; READ
                ;
bas_read:       PROC
                PSHR R5
@@12:
                macro_get_next
                CMPI #$41,R0            ; Variable name?
                BNC @@2
                CMPI #$5B,R0
                BC @@2                  ; No, jump.
                MVI@ R4,R1
                CMPI #$24,R1            ; Is it string?
                BNE @@14                ; No, jump.
                CALL get_string_addr.0
                PSHR R4
                PSHR R5
                MVI bas_dataptr,R4
                TSTR R4
                BNE @@15
                CALL data_locate
                TSTR R4
                BEQ @@6
@@15:           MVI@ R4,R0
                TSTR R0                 ; End of line found?
                BEQ @@16
                CMPI #$20,R0            ; Avoid spaces
                BEQ @@15
                CMPI #$22,R0            ; Quotes?
                BEQ @@18
                DECR R4
                MOVR R4,R5
@@19:           MVI@ R4,R0
                TSTR R0
                BEQ @@20
                CMPI #$2C,R0
                BEQ @@20
                CMPI #TOKEN_COLON,R0
                BEQ @@20
                B @@19

@@18:           MOVR R4,R5
@@22:           MVI@ R4,R0
                CMPI #$22,R0
                BEQ @@21
                TSTR R0
                BNE @@22
                B @@20

@@21:           PSHR R4
                DECR R4
                B @@25

@@20:           DECR R4
                PSHR R4
@@25:           SUBR R5,R4              ; Get length of string.
                MOVR R4,R1
                MOVR R5,R0
                CALL string_create
                PULR R4
                PULR R1
                PSHR R4
                CALL string_assign
                PULR R4
                B @@11

                ; End of line.
@@16:           MVI@ R4,R0
                TSTR R0                 ; End of program?
                BEQ @@6
                INCR R4
@@17:           MVI@ R4,R0
                TSTR R0
                BEQ @@16
                CMPI #TOKEN_DATA,R0
                BNE @@17
                B @@15


@@14:           DECR R4
                CALL get_var_addr.0
                PSHR R4
                PSHR R1
                MVI bas_dataptr,R4
                TSTR R4
                BEQ @@6
@@8:            MVI@ R4,R0
                TSTR R0                 ; End of line found?
                BEQ @@5
                CMPI #$20,R0            ; Avoid spaces
                BEQ @@8
                CMPI #$2D,R0
                BEQ @@24
                CLRR R3
                CMPI #TOKEN_INTEGER,R0
                BEQ @@23
                CMPI #TOKEN_NUMBER,R0
                BEQ @@23
                B @@2

@@24:           MVII #1,R3
                MVI@ R4,R0
@@23:           PSHR R3
                CMPI #TOKEN_INTEGER,R0
                BNE @@26
                MVI@ R4,R0
                MVI@ R4,R1
                SWAP R1
                ADDR R1,R0
                CALL fpfromuint
                B @@3

@@26:           CMPI #TOKEN_NUMBER,R0
                BNE @@2
                MVI@ R4,R1
                MVI@ R4,R2
                SWAP R2
                ADDR R2,R1
                MVI@ R4,R0
                MVI@ R4,R2
                SWAP R2
                ADDR R2,R0
                ; Number identified.
@@3:            PULR R3
                TSTR R3
                BEQ @@27
                CALL fpneg
@@27:
                PULR R5
                MVO@ R0,R5              ; Save into variable
                MVO@ R1,R5
@@11:
                MVI@ R4,R0
                TSTR R0
                BEQ @@9
                CMPI #$20,R0
                BEQ @@11
                CMPI #$2C,R0
                BNE @@11
                B @@10
@@9:            DECR R4
@@10:           MVO R4,bas_dataptr
                PULR R4
                macro_get_next
                CMPI #$2C,R0
                BEQ @@12
                DECR R4
                PULR PC

@@4:
                ; End of line
@@5:            MVI@ R4,R0
                TSTR R0                 ; End of program?
                BEQ @@6
                INCR R4
@@7:            MVI@ R4,R0
                TSTR R0
                BEQ @@5
                CMPI #TOKEN_DATA,R0
                BNE @@7
                B @@8

                PULR R5
                PULR R4

@@6:            MVII #ERR_DATA,R0
                CALL bas_error

@@2:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                PULR PC
                ENDP

                ;
                ; DATA
                ;
                ; On execution it is ignored.
                ;
bas_data:       PROC
@@1:            MVI@ R4,R0
                CMPI #TOKEN_NUMBER,R0
                BNE @@3
                ADDI #4,R4
@@3:            CMPI #TOKEN_INTEGER,R0
                BNE @@4
                ADDI #2,R4
@@4:            CMPI #TOKEN_COLON,R0
                BEQ @@2
                TSTR R0
                BNE @@1
@@2:
                DECR R4
                MOVR R5,PC
                ENDP

                ;
                ; DIM
                ;
bas_dim:        PROC
                PSHR R5
@@0:
                macro_get_next
                CMPI #$41,R0            ; Variable name?
                BNC @@1
                CMPI #$5B,R0
                BC @@1                  ; No, jump.
                PSHR R0
                macro_get_next
                CMPI #$28,R0
                BNE @@1
                CALL parse_integer
                BC @@1
                INCR R0                 ; Count zero.
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@1
                PULR R1                 ; Length.
                PULR R2                 ; Name.
                ;
                ; Search for previous definition.
                ;
                PSHR R4
                MVI bas_arrays,R3
@@5:            MVI@ R3,R4              ; Read array name.
                TSTR R4                 ; End of list?
                BEQ @@4                 ; Yes, jump.
                CMP@ R3,R2              ; Same name?
                BEQ @@2                 ; Yes, error.
                INCR R3                 ; Jump over name.
                MVI@ R3,R0              ; Get length.
                INCR R3                 ; Jump over length.
                SLL R0,1                ; Length x2.
                ADDR R0,R3              ; Jump over array contents.
                B @@5                   ; Keep searching.

@@4:            MOVR R3,R0              ; Get current address.
                ADDI #3,R0              ; Add name, length, and end word.
                ADDR R1,R0              ; Add length two times.
                ADDR R1,R0
                CMP bas_strptr,R0       ; Exceed memory available?
                BC @@3                  ; Yes, error.
                MVO@ R2,R3              ; Take note of array name.
                INCR R3
                MVO@ R1,R3              ; Take note of length.
                INCR R3
                CLRR R2
@@6:            MVO@ R2,R3              ; Clear array.
                INCR R3
                MVO@ R2,R3
                INCR R3
                DECR R1
                BNE @@6
                CLRR R1                 ; End word.
                MVO@ R1,R3
                MVO R3,bas_last_array
                PULR R4
                macro_get_next
                CMPI #$2C,R0            ; Comma?
                BEQ @@0                 ; Yes, jump to define another array.
                DECR R4
                PULR PC

@@3:            MVII #ERR_MEMORY,R0
                CALL bas_error

@@2:            MVII #ERR_DIM,R0
                CALL bas_error

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error

                ENDP

                ;
                ; MODE
                ;
bas_mode:       PROC
                PSHR R5
                CALL bas_expr_int
                CMPI #2,R0              ; Only MODE 0 and MODE 1 are valid.
                BC @@1
                MVO R0,_mode
                macro_get_next
                CMPI #$2C,R0            ; Is there a comma?
                BNE @@2                 ; No, jump.
                CALL bas_expr_int       ; Process an integer.
                MVO R0,_mode_color      ; Use for background colors.
                PULR PC

@@2:            DECR R4
                PULR PC

@@1:            MVII #ERR_BOUNDS,R0
                CALL bas_error
                ENDP

                ;
                ; COLOR
                ;
bas_color:      PROC
                PSHR R5
                CALL bas_expr_int       ; Process expression.
                MVO R0,bas_curcolor     ; Use as current color.
                PULR PC
                ENDP

                ;
                ; DEFINE
                ;
bas_define:     PROC
                PSHR R5
                CALL bas_expr_int       ; Get GRAM number.
                PSHR R0
                macro_get_next
                CMPI #$2C,R0            ; Look for comma.
                BNE @@1
                macro_get_next
                CMPI #$22,R0            ; Look for quotes.
                BNE @@1
                MVI bas_last_array,R3
                INCR R3
@@0:
                CALL @@convert_hex
                BC @@2
                SLL R0,2
                SLL R0,2
                MOVR R0,R2

                CALL @@convert_hex
                BC @@2
                ADDR R0,R2

                SWAP R2
                CALL @@convert_hex
                BC @@2
                SLL R0,2
                SLL R0,2
                ADDR R0,R2

                CALL @@convert_hex
                BC @@2
                ADDR R0,R2
                SWAP R2

                MVO@ R2,R3
                INCR R3
                B @@0

@@2:            CMPI #$22,R0            ; Look for ending quotes.
                BNE @@1

                MVI bas_last_array,R2
                INCR R2
                SUBR R2,R3
                SLR R3,2
                BEQ @@1
                MVO R3,_gram_total      ; Setup total GRAM for definition.
                MVO R2,_gram_bitmap     ; Pointer to GRAM bitmap.
                PULR R0
                MVO R0,_gram_target     ; Select GRAM number for definition.

                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error

                ;
                ; Convert hexadecimal digit.
                ;
@@convert_hex:
                MVI@ R4,R0
                CMPI #$61,R0
                BNC @@c1
                SUBI #$20,R0
@@c1:           CMPI #$30,R0
                BNC @@c2
                CMPI #$47,R0
                BC @@c2
                CMPI #$3A,R0
                BNC @@c3
                CMPI #$41,R0
                BNC @@c2
@@c3:           SUBI #$30,R0
                CMPI #10,R0
                BNC @@c4
                SUBI #7,R0
@@c4:
                CLRC
                MOVR R5,PC

@@c2:           SETC
                MOVR R5,PC

                ENDP

                ;
                ; SPRITE
                ;
bas_sprite:     PROC
                PSHR R5
                CALL bas_expr_int       ; Get sprite number.
                CMPI #8,R0
                BC @@1
                ADDI #_mobs,R0
                PSHR R0
                macro_get_next
                CMPI #$2C,R0
                BNE @@2

                macro_get_next
                CMPI #$2C,R0
                BEQ @@4
                DECR R4
                CALL bas_expr_int       ; Get X.
                PULR R3
                PSHR R3
                MVO@ R0,R3
                macro_get_next
                CMPI #TOKEN_COLON,R0
                BEQ @@3
                TSTR R0
                BEQ @@3
                CMPI #$2C,R0
                BNE @@2
@@4:
                macro_get_next
                CMPI #$2C,R0
                BEQ @@5
                DECR R4
                CALL bas_expr_int       ; Get Y.
                PULR R3
                PSHR R3
                ADDI #8,R3
                MVO@ R0,R3
                macro_get_next
                CMPI #TOKEN_COLON,R0
                BEQ @@3
                TSTR R0
                BEQ @@3
                CMPI #$2C,R0
                BNE @@2
@@5:
                CALL bas_expr_int       ; Get frame.
                PULR R3
                PSHR R3
                ADDI #16,R3
                MVO@ R0,R3
                INCR R7

@@3:            DECR R4
                PULR R3
                PULR PC

@@1:            MVII #ERR_BOUNDS,R0
                CALL bas_error

@@2:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; WAIT
                ;
bas_wait:       PROC
                PSHR R5
                ; Cannot use _int here because it could be an old interrupt.
                MVI _frame,R0
@@1:
                CMP _frame,R0           ; Wait for video interrupt to happen.
                BEQ @@1
                PULR PC
                ENDP

                ;
                ; SOUND
                ;
bas_sound:      PROC
                PSHR R5
                CALL bas_expr_int       ; Get register number.
                PSHR R0
                macro_get_next
                CMPI #$2C,R0
                BNE @@5
                macro_get_next
                CMPI #$2C,R0
                BEQ @@12
                DECR R4
@@12:
                PULR R1
                TSTR R1                 ; SOUND 0
                BEQ @@0
                DECR R1                 ; SOUND 1
                BEQ @@1
                DECR R1                 ; SOUND 2
                BEQ @@2
                DECR R1                 ; SOUND 3
                BEQ @@3
                DECR R1                 ; SOUND 4
                BEQ @@4
                MVII #ERR_BOUNDS,R0
                CALL bas_error

@@5:            MVII #ERR_SYNTAX,R0
                CALL bas_error

                ; SOUND 0,freq,vol
@@0:            CMPI #$2C,R0
                BEQ @@6
                CALL bas_expr_int
                MVO R0,$01f0
                SWAP R0
                MVO R0,$01F4
                macro_get_next
                CMPI #$2C,R0
                BNE @@11
@@6:
                CALL bas_expr_int
                MVO R0,$01FB
                PULR PC

                ; SOUND 1,freq,vol
@@1:            CMPI #$2C,R0
                BEQ @@7
                CALL bas_expr_int
                MVO R0,$01F1
                SWAP R0
                MVO R0,$01F5
                macro_get_next
                CMPI #$2C,R0
                BNE @@11
@@7:
                CALL bas_expr_int
                MVO R0,$01fc
                PULR PC

                ; SOUND 2,freq,vol
@@2:            CMPI #$2C,R0
                BEQ @@8
                CALL bas_expr_int
                MVO R0,$01F2
                SWAP R0
                MVO R0,$01F6
                macro_get_next
                CMPI #$2C,R0
                BNE @@11
@@8:
                CALL bas_expr_int
                MVO R0,$01fd
                PULR PC

                ; SOUND 3,freq,env
@@3:            CMPI #$2C,R0
                BEQ @@9
                CALL bas_expr_int
                MVO R0,$01F3
                SWAP R0
                MVO R0,$01F7
                macro_get_next
                CMPI #$2C,R0
                BNE @@11
@@9:
                CALL bas_expr_int
                MVO R0,$01fa
                PULR PC

                ; SOUND 4,noise,mix
@@4:            CMPI #$2C,R0
                BEQ @@10
                CALL bas_expr_int
                MVO R0,$01F9
                macro_get_next
                CMPI #$2C,R0
                BNE @@11
@@10:
                CALL bas_expr_int
                MVO R0,$01f8
                PULR PC

@@11:           DECR R4
                PULR PC
                ENDP

                ;
                ; BORDER
                ;
bas_border:     PROC
                PSHR R5
                CALL bas_expr_int       ; Get number.
                CMPI #16,R0
                BC @@1
                MVO R0,_border_color    ; Set as border color.
                PULR PC

@@1:            MVII #ERR_BOUNDS,R0
                CALL bas_error
                ENDP

                ;
                ; POKE
                ;
bas_poke:       PROC
                PSHR R5
                CALL bas_expr_int       ; Get address.
                PSHR R0
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get word.
                PULR R1
                MVO@ R0,R1              ; Write into memory.
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error

                ENDP

                ;
                ; ON
                ;
bas_on:         PROC
                PSHR R5
                CALL bas_expr_int       ; Get expression.
                PSHR R0
                macro_get_next
                CMPI #TOKEN_GOTO,R0     ; ON GOTO?
                BEQ @@1
                CMPI #TOKEN_GOSUB,R0    ; ON GOSUB?
                BEQ @@1

@@6:            MVII #ERR_SYNTAX,R0
                CALL bas_error

@@1:            PULR R1
                PSHR R0
                ;
                ; First option is 1.
                ;
@@3:            DECR R1
                BEQ @@2
@@5:
                macro_get_next
                CMPI #TOKEN_INTEGER,R0
                BNE @@9
                ADDI #2,R4
@@9:
                CMPI #TOKEN_NUMBER,R0
                BNE @@10
                ADDI #4,R4
@@10:
                CMPI #$2C,R0
                BEQ @@3
                TSTR R0                 ; Reached end of line?
                BEQ @@4
                CMPI #TOKEN_COLON,R0
                BEQ @@4
                CMPI #TOKEN_ELSE,R0
                BEQ @@4
                B @@5

@@2:            CALL parse_integer      ; Get the target line number.
                BC @@6
                PULR R1
                CMPI #TOKEN_GOSUB,R1
                BNE bas_goto.1
                PSHR R0
@@7:            macro_get_next          ; Jump over the remaining line data.
                TSTR R0
                BEQ @@8
                CMPI #TOKEN_INTEGER,R0
                BNE @@11
                ADDI #2,R4
@@11:
                CMPI #TOKEN_NUMBER,R0
                BNE @@12
                ADDI #4,R4
@@12:
                CMPI #TOKEN_COLON,R0
                BEQ @@8
                CMPI #TOKEN_ELSE,R0
                BNE @@7
@@8:            DECR R4
                PULR R0
                B bas_gosub.1

@@4:            PULR R0
                DECR R4
                PULR PC
                ENDP

                ;
                ; PLOT
                ;
bas_plot:       PROC
                PSHR R5
                CALL bas_expr_int       ; Get X-coordinate.
                MVO R0,plot_x
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get Y-coordinate.
                MVO R0,plot_y
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get color.
                ANDI #7,R0
                MOVR R0,R2
                MVI plot_x,R0           ; Save current coordinates.
                MVI plot_y,R1
                CALL draw_pixel         ; Draw pixel.
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; DRAW
                ;
bas_draw:       PROC
                PSHR R5
                CALL bas_expr_int       ; Get target X-coordinate.
                MVO R0,draw_x
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get target Y-coordinate.
                MVO R0,draw_y
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get color.
                ANDI #7,R0
                MOVR R0,R2
                PSHR R4
                CALL draw_line          ; Draw line.
                PULR R4
                MVI draw_x,R0
                MVI draw_y,R1
                MVO R0,plot_x           ; Save new coordinates.
                MVO R1,plot_y
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; CIRCLE
                ;
                ; Bresenham's circle drawing algorithm.
                ;
bas_circle:     PROC
                PSHR R5
                CALL bas_expr_int       ; Get X-coordinate.
                MVO R0,plot_x
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get Y-coordinate.
                MVO R0,plot_y
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get radius.
                MVO R0,sign_x
                macro_get_next
                CMPI #$2C,R0            ; Get comma.
                BNE @@1
                CALL bas_expr_int       ; Get color.
                ANDI #7,R0
                MOVR R0,R2
                MVI sign_x,R0
                SLL R0,1
                NEGR R0
                ADDI #3,R0
                MVO R0,err              ; err = 3 - 2 * r
                CLRR R0
                MVO R0,draw_x
                MVI sign_x,R1
                MVO R1,draw_y
                CALL draw_circle
@@2:            MVI draw_x,R0
                MVI draw_y,R1
                CMPR R0,R1
                BLT @@3
                MVI err,R5
                CMPI #0,R5
                BLE @@4
                DECR R1
                MOVR R0,R3
                SUBR R1,R3
                SLL R3,2
                ADDI #10,R3
                ADDR R3,R5              ; err = err + (x - y) * 4 + 10
                B @@5

@@4:            MOVR R0,R3
                SLL R3,2
                ADDI #6,R3
                ADDR R3,R5              ; err = err + x * 4 + 6
@@5:            MVO R5,err

                INCR R0
                MVO R0,draw_x
                MVO R1,draw_y
                CALL draw_circle
                B @@2
@@3:
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Draw the eight octants for a circle
                ;
draw_circle:    PROC
                PSHR R5
                MVI plot_x,R0
                ADD draw_x,R0
                MVI plot_y,R1
                ADD draw_y,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                SUB draw_x,R0
                MVI plot_y,R1
                ADD draw_y,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                ADD draw_x,R0
                MVI plot_y,R1
                SUB draw_y,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                SUB draw_x,R0
                MVI plot_y,R1
                SUB draw_y,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                ADD draw_y,R0
                MVI plot_y,R1
                ADD draw_x,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                SUB draw_y,R0
                MVI plot_y,R1
                ADD draw_x,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                ADD draw_y,R0
                MVI plot_y,R1
                SUB draw_x,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                MVI plot_x,R0
                SUB draw_y,R0
                MVI plot_y,R1
                SUB draw_x,R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                PULR PC
                ENDP

                ;
                ; Draw a line using the Bresenham algorithm.
                ;
draw_line:      PROC
                PSHR R5
                PSHR R2
                MVI plot_x,R0
                MVI plot_y,R1
                MVI draw_x,R2
                MVI draw_y,R3
                SUBR R0,R2
                BC @@1
                NEGR R2
                MVII #-1,R4
                B @@2

@@1:            MVII #1,R4
@@2:            MVO R2,delta_x
                MVO R4,sign_x

                SUBR R1,R3
                BC @@3
                NEGR R3
                MVII #-1,R5
                B @@4

@@3:            MVII #1,R5
@@4:            MVO R3,delta_y
                MVO R5,sign_y
                MVI delta_x,R2
                CMP delta_y,R2
                BLE @@5
                SLR R2,1
                B @@6

@@5:            MVI delta_y,R2
                SLR R2,1
                NEGR R2
@@6:            MVO R2,err
                PULR R2

@@7:            PSHR R0
                PSHR R1
                PSHR R2
                CALL draw_pixel
                PULR R2
                PULR R1
                PULR R0
                CMP draw_x,R0
                BNE @@8
                CMP draw_y,R1
                BEQ @@9
@@8:
                MVI delta_x,R5
                NEGR R5
                MVI err,R3
                MOVR R3,R4
                CMPR R5,R3
                BLE @@10
                SUB delta_y,R4
                ADD sign_x,R0

@@10:           CMP delta_y,R3
                BGE @@11
                ADD delta_x,R4
                ADD sign_y,R1
@@11:
                MVO R4,err
                B @@7
@@9:
                PULR PC
                ENDP

                ;
                ; Draw a bloxel (4x4 pixel)
                ;
draw_pixel:     PROC
                PSHR R5
                CMPI #40,R0             ; Out of the screen
                BC @@2
                CMPI #24,R1             ; Out of the screen
                BC @@2
                MOVR R1,R3
                SLR R3,1
                MOVR R3,R5
                SLL R3,2                ; x4
                ADDR R5,R3              ; x5
                SLL R3,2                ; x20
                ADDI #$0200,R3          ; For the backtab
                MOVR R3,R5
                MOVR R0,R3
                SLR R3,1
                ADDR R3,R5
                MVI@ R5,R3
                DECR R5
                PSHR R4
                MOVR R3,R4
                ANDI #$1800,R4
                CMPI #$1000,R4          ; Word already in coloured squares mode?
                BEQ @@7                 ; Yes, jump.
                MVII #$37FF,R3          ; Get erased pixel for working.
@@7:            PULR R4
                RRC R1,1
                BC @@3
                ; Y bit 0 = 0
                RRC R0,1
                BC @@4
                ANDI #$FFF8,R3
                ADDR R2,R3
                MVO@ R3,R5
                PULR PC
@@4:
                SLL R2,2
                SLL R2,1
                ANDI #$FFC7,R3
                ADDR R2,R3
                MVO@ R3,R5
                PULR PC
                ; Y bit 0 = 1
@@3:            RRC R0,1
                BC @@5
                SLL R2,2
                SLL R2,2
                SLL R2,2
                ANDI #$FE3F,R3
                ADDR R2,R3
                MVO@ R3,R5
                PULR PC

@@5:            SWAP R2
                SLL R2,1
                CMPI #$0800,R2
                BNC @@6
                ADDI #$1800,R2
@@6:
                ANDI #$D9FF,R3
                ADDR R2,R3
                MVO@ R3,R5
@@2:            PULR PC
                ENDP

                ;
                ; BK(v) = v
                ;
bas_bk:         PROC
                PSHR R5
                CALL bas_expr_paren     ; Get index.
                CALL fp2int
                CMPI #$240,R0
                BC @@1
                PSHR R0
                macro_get_next
                CMPI #TOKEN_EQ,R0       ; =
                BNE @@2
                CALL bas_expr_int       ; Get card.
                PULR R5
                ADDI #$0200,R5
                MVO@ R0,R5              ; Put into the screen.
                PULR PC

@@1:            MVII #ERR_BOUNDS,R0
                CALL bas_error

@@2:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Read a filename.
                ;
bas_filename:   PROC
                PSHR R5
                MVII #_filename,R5      ; Erase space for filename.
                MVII #$20,R0
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVII #_filename,R3

                macro_get_next
                CMPI #$22,R0            ; Quotes start?
                BNE @@1
@@2:
                MVI@ R4,R0
                CMPI #$22,R0            ; Quotes ending?
                BEQ @@3
                CMPI #_filename+4,R3    ; Already four letters in filename?
                BEQ @@2                 ; Yes, jump.
                CMPI #$61,R0            ; Make uppercase.
                BNC @@4
                CMPI #$7B,R0
                BC @@4
                SUBI #$20,R0
@@4:            MVO@ R0,R3
                INCR R3
                B @@2

                ; Copy the filename here.
                ; The jzintv emulator uses it to create files in the main directory.
@@3:            MVII #_filename,R4
                MVII #$4080,R1
                MVII #$40FA,R2
                MVII #4,R3
@@5:            MVI@ R4,R0
                MVO@ R0,R1
                MVO@ R0,R2
                INCR R1
                INCR R2
                DECR R3
                BNE @@5
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Load a program from tape.
                ;
bas_load:       PROC
                CALL bas_filename       ; Process filename.
                CALL new_program        ; Erase program.
                CALL cassette_init      ; Start cassette.
                CALL cassette_load      ; Find header and start load.
                CMPI #1,R0
                BEQ @@1
                CMPI #2,R0
                BEQ @@2
                MVII #program_start,R4
@@3:            CALL cassette_read_word ; Read word.
                MVO@ R0,R4              ; Save line number.
                TSTR R0
                BEQ @@0
                CALL cassette_read_word ; Read word.
                MVO@ R0,R4              ; Save line length.
                MOVR R0,R2
@@4:            CALL cassette_read      ; Read byte.
                MVO@ R0,R4              ; Save tokenized data.
                DECR R2
                BNE @@4
                B @@3

@@0:            DECR R4
                MVO R4,program_end
                CALL restart_pointers   ; Prepare for future execution.
                CALL cassette_stop      ; Stop the cassette.
                ; Program read completely.
                B basic_restart

                ; Header not found
@@1:            CALL cassette_stop
                MVII #ERR_NODATA,R0
                CALL bas_error

                ; File not found
@@2:            CALL cassette_stop
                MVII #ERR_NOFILE,R0
                CALL bas_error
                ENDP

                ;
                ; Save a program to tape.
                ;
bas_save:       PROC
                CALL bas_filename       ; Process filename.
                CALL cassette_init      ; Start cassette.
                CALL cassette_save      ; Start saving header.
                MVII #program_start,R4
@@1:            MVI@ R4,R0              ; Get line number.
                CALL cassette_write_word; Send to cassette.
                TSTR R0
                BEQ @@2
                MVI@ R4,R0              ; Get line length.
                CALL cassette_write_word; Send to cassette.
                MOVR R0,R2
@@3:            MVI@ R4,R0              ; Get tokenized data.
                CALL cassette_write     ; Send to cassette.
                DECR R2
                BNE @@3
                B @@1

@@2:            CALL cassette_stop      ; Stop the cassette.
                B basic_restart
                ENDP

                ;
                ; Verify a program from tape.
                ;
bas_verify:     PROC
                CALL bas_filename       ; Process filename.
                CALL cassette_init      ; Start cassette.
                CALL cassette_load      ; Find header and start load.
                CMPI #1,R0
                BEQ @@1
                CMPI #2,R0
                BEQ @@2
                MVII #program_start,R4
@@3:            CALL cassette_read_word ; Read line number.
                CMP@ R4,R0              ; Same?
                BNE @@5                 ; No, jump.
                TSTR R0
                BEQ @@0
                CALL cassette_read_word ; Read tokenized length.
                CMP@ R4,R0              ; Same?
                BNE @@5                 ; No, jump.
                MOVR R0,R2
@@4:            CALL cassette_read      ; Read tokenized program.
                CMP@ R4,R0              ; Same?
                BNE @@5                 ; No, jump.
                DECR R2
                BNE @@4
                B @@3

@@0:            CALL cassette_stop      ; Stop the cassette.
                ; Program verified completely
                B basic_restart

                ; Header not found
@@1:            CALL cassette_stop
                MVII #ERR_NODATA,R0
                CALL bas_error

                ; File not found
@@2:            CALL cassette_stop
                MVII #ERR_NOFILE,R0
                CALL bas_error

                ; Mismatch
@@5:            CALL cassette_stop
                MVII #ERR_MISMATCH,R0
                CALL bas_error

                ENDP

                ;
                ; Syntax error (reserved keyword at wrong place)
                ;
bas_syntax_error: PROC
                MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Expresion evaluation and conversion to integer
                ;
bas_expr_int:   PROC
                PSHR R5
                CALL bas_expr           ; Process expression.
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int             ; Conversion to integer.
                PULR PC
                ENDP

                ;
                ; Type error
                ;
bas_type_err:   PROC
                MVII #ERR_TYPE,R0
                CALL bas_error
                ENDP

                ;
                ; Expression evaluation
                ; The type is passed in the Carry flag.
                ; Carry flag clear = Number.
                ; Carry flag set = String.
                ;
bas_expr:       PROC
                PSHR R5
                CALL bas_expr1
                BC @@0                  ; Jump if string.
@@2:            macro_get_next
                CMPI #TOKEN_OR,R0       ; OR
                BNE @@1
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                CALL bas_expr1
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PULR R1
                COMR R1
                ANDR R1,R0
                COMR R1
                ADDR R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                B @@2

@@1:            DECR R4
                CLRC
@@0:            PULR PC
                ENDP

bas_expr1:      PROC
                PSHR R5
                CALL bas_expr2
                BC @@0                  ; Jump if string.
@@2:            macro_get_next
                CMPI #TOKEN_XOR,R0      ; XOR
                BNE @@1
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                CALL bas_expr2
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PULR R1
                XORR R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                B @@2

@@1:            DECR R4
                CLRC
@@0:            PULR PC
                ENDP

bas_expr2:      PROC
                PSHR R5
                CALL bas_expr3
                BC @@0                  ; Jump if string.
@@2:            macro_get_next
                CMPI #TOKEN_AND,R0      ; AND
                BNE @@1
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                CALL bas_expr3
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PULR R1
                ANDR R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                B @@2

@@1:            DECR R4
                CLRC
@@0:            PULR PC
                ENDP

                ;
                ; Relational operators = <> < > <= >=
                ;
bas_expr3:      PROC
                PSHR R5
                CALL bas_expr4
                BC @@7
                macro_get_next
                CMPI #TOKEN_LE,R0
                BNC @@1
                CMPI #TOKEN_GT+1,R0
                BC @@1
                PSHR R2
                PSHR R3
                MVII #@@table1-TOKEN_LE,R1
                ADDR R0,R1
                MVI@ R1,PC
@@table1:
                DECLE @@le1
                DECLE @@ge1
                DECLE @@ne1
                DECLE @@eq1
                DECLE @@lt1
                DECLE @@gt1
@@le1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BEQ @@true
                BNC @@true
                B @@false

@@ge1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BC @@true
                B @@false

@@ne1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BNE @@true
                B @@false

@@eq1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BEQ @@true
                B @@false

@@lt1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BNC @@true
                B @@false

@@gt1:
                CALL bas_expr4
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpcomp
                PULR R4
                BEQ @@false
                BNC @@false
                B @@true

@@1:            CLRC
                DECR R4
                PULR PC

                ;
                ; String comparison
                ;
@@7:
                macro_get_next
                CMPI #TOKEN_LE,R0
                BNC @@0
                CMPI #TOKEN_GT+1,R0
                BC @@0
                PSHR R0
                PSHR R2
                PSHR R3
                CALL bas_expr4
                BNC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL string_comparison
                PULR R4
                PULR R1
                CMPI #TOKEN_LT,R1
                BEQ @@8
                CMPI #TOKEN_GT,R1
                BEQ @@9
                CMPI #TOKEN_LE,R1
                BEQ @@10
                CMPI #TOKEN_GE,R1
                BEQ @@11
                CMPI #TOKEN_EQ,R1
                BEQ @@12
                TSTR R0
                BEQ @@false
                B @@true

@@12:           TSTR R0
                BEQ @@true
                B @@false

@@11:           TSTR R0
                BPL @@true
                B @@false

@@10:           CMPI #1,R0
                BEQ @@false
                B @@true

@@9:            CMPI #1,R0
                BEQ @@true
                B @@false

@@8:            TSTR R0
                BPL @@false
                B @@true

@@0:            SETC
                DECR R4
                PULR PC

@@true:         CLRR R2
                MVII #$00BF,R3
                CLRC
                PULR PC

@@false:        CLRR R2
                CLRR R3
                CLRC
                PULR PC

                ENDP

                ;
                ; Addition and subtraction operators
                ;
bas_expr4:      PROC
                PSHR R5
                CALL bas_expr5
                BC @@3
@@0:
                macro_get_next
                CMPI #$2b,R0
                BEQ @@1
                CMPI #$2d,R0
                BNE @@2

                PSHR R2
                PSHR R3
                CALL bas_expr5
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpsub
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                B @@0

@@1:
                PSHR R2
                PSHR R3
                CALL bas_expr5
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpadd
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                B @@0

@@2:            DECR R4
                CLRC
                PULR PC

@@3:            macro_get_next
                CMPI #$2b,R0
                BNE @@4
                PSHR R2
                PSHR R3
                CALL bas_expr5
                BNC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL string_concat
                PULR R4
                B @@3

@@4:            DECR R4
                SETC
                PULR PC
                ENDP

                ;
                ; Multiplication, division, and power-of operators.
                ;
bas_expr5:      PROC
                PSHR R5
                CALL bas_expr6
                BC @@3
@@0:
                macro_get_next
                CMPI #$2a,R0
                BEQ @@1
                CMPI #$2f,R0
                BEQ @@2
                CMPI #$5e,R0
                BNE @@4
                PSHR R2
                PSHR R3
                CALL bas_expr6
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fppow
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                B @@0

@@1:
                PSHR R2
                PSHR R3
                CALL bas_expr6
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpmul
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                B @@0

@@2:
                PSHR R2
                PSHR R3
                CALL bas_expr6
                BC bas_type_err
                PULR R1
                PULR R0
                PSHR R4
                CALL fpdiv
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                B @@0

@@4:            DECR R4
                CLRC
@@3:            PULR PC
                ENDP

                ;
                ; Unary operators.
                ;
bas_expr6:      PROC
                macro_get_next
                CMPI #$2D,R0            ; Minus?
                BEQ @@1
                CMPI #TOKEN_NOT,R0      ; NOT?
                BEQ @@2
                PSHR R5
                B bas_expr7.99
@@1:
                PSHR R5
                CALL bas_expr7
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fpneg
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC
@@2:
                PSHR R5
                CALL bas_expr7
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                COMR R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ENDP

                ;
                ; Process expression between parenthesis.
                ;
bas_expr_paren: PROC
                PSHR R5
                macro_get_next
                CMPI #$28,R0
                BNE @@1
                CALL bas_expr
                GSWD R1                 ; Save carry flag.
                macro_get_next
                CMPI #$29,R0
                BNE @@1
                RSWD R1
                MOVR R2,R0
                MOVR R3,R1
                PULR PC

@@1:            MVII #ERR_SYNTAX,R0
                CALL bas_error
                ENDP

                ;
                ; Process functions, variables, strings, and numbers.
                ;
bas_expr7:      PROC
                PSHR R5
                macro_get_next
@@99:
                CMPI #TOKEN_FUNC,R0
                BNC @@6
                CMPI #TOKEN_FUNC+33,R0
                BC @@2                  ; Syntax error.
                MVII #@@0-TOKEN_FUNC,R1
                ADDR R0,R1
                MVI@ R1,R7
@@0:
                DECLE @@INT
                DECLE @@ABS
                DECLE @@SGN
                DECLE @@RND

                DECLE @@STICK
                DECLE @@STRIG
                DECLE @@KEY
                DECLE @@BK

                DECLE @@PEEK
                DECLE @@USR
                DECLE @@ASC
                DECLE @@LEN

                DECLE @@CHR
                DECLE @@LEFT
                DECLE @@MID
                DECLE @@RIGHT

                DECLE @@VAL
                DECLE @@INKEY
                DECLE @@STR
                DECLE @@INSTR

                DECLE @@SIN
                DECLE @@COS
                DECLE @@TAN
                DECLE @@LOG

                DECLE @@EXP
                DECLE @@SQR
                DECLE @@ATN
                DECLE @@TIMER

                DECLE @@FRE
                DECLE @@POS
                DECLE @@LPOS
                DECLE @@POINT

                DECLE @@HEX

                ; RND
@@RND:
                PSHR R4
                CALL fprnd
                PULR R4
@@generic_copy:
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; INT(x)
@@INT:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fpint
                B @@generic_copy

                ; SGN(x)
@@SGN:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fpsgn
                B @@generic_copy

                ; ABS(x)
@@ABS:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fpabs
                B @@generic_copy

                ; SIN(x)
@@SIN:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fpsin
                PULR R4
                B @@generic_copy

                ; COS(x)
@@COS:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fpcos
                PULR R4
                B @@generic_copy

                ; TAN(x)
@@TAN:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fptan
                PULR R4
                B @@generic_copy

                ; LOG(x)
@@LOG:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fpln
                PULR R4
                B @@generic_copy

                ; EXP(x)
@@EXP:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fpexp
                PULR R4
                B @@generic_copy

                ; SQR(x)
@@SQR:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fpsqrt
                PULR R4
                B @@generic_copy

                ; ATN(x)
@@ATN:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                CALL fparctan
                PULR R4
                B @@generic_copy

                ; TIMER
@@TIMER:
                MVI _frame+1,R0
                MVI _frame,R1
                CALL fpfromuint24
                B @@generic_copy

                ; FRE(x)
@@FRE:
                CALL bas_expr_paren
                BC bas_type_err
                MVI bas_strptr,R0
                MVI bas_last_array,R1
                INCR R1
                SUBR R1,R0
                CALL fpfromint
                B @@generic_copy

                ; POS(x)
@@POS:
                CALL bas_expr_paren
                BC bas_type_err
                MVII #$FFFF,R0
                CALL bas_output
                INCR R0
                CALL fpfromint
                B @@generic_copy

                ; LPOS(x)
@@LPOS:
                CALL bas_expr_paren
                BC bas_type_err
                MVII #$FFFF,R0
                CALL printer_output
                INCR R0
                CALL fpfromint
                B @@generic_copy

                ; POINT(x,y)
@@POINT:
                macro_get_next
                CMPI #$28,R0
                BNE @@2
                CALL bas_expr_int
                PSHR R0
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr_int
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@2
                PULR R1
                PULR R0
                CMPI #40,R0             ; Out of the screen
                BC @@P1
                CMPI #24,R1             ; Out of the screen
                BC @@P1
                MOVR R1,R3
                SLR R3,1
                MOVR R3,R5
                SLL R3,2                ; x4
                ADDR R5,R3              ; x5
                SLL R3,2                ; x20
                ADDI #$0200,R3          ; For the backtab
                MOVR R3,R5
                MOVR R0,R3
                SLR R3,1
                ADDR R3,R5
                MVI@ R5,R3
                DECR R5
                PSHR R4
                MOVR R3,R4
                ANDI #$1800,R4
                CMPI #$1000,R4
                BNE @@P3
                PULR R4
                RRC R1,1
                BC @@P5
                ; Y bit 0 = 0
                RRC R0,1
                BNC @@P4
                SLR R3,2
                SLR R3,1
@@P4:           ANDI #7,R3
                MOVR R3,R0
                B @@P2

                ; Y bit 0 = 1
@@P5:           RRC R0,1
                BC @@P6
                SLR R3,2
                SLR R3,2
                SLR R3,2
                B @@P4

@@P6:           SWAP R3
                ANDI #$0026,R3
                SLR R3,1
                CMPI #$10,R3
                BNC @@P4
                SUBI #$0C,R3
                B @@P4

@@P3:           PULR R4
@@P1:           MVII #7,R0
@@P2:           CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; HEX$(expr)
@@HEX:
                CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                MVII #basic_buffer+3,R3
                CALL @@hexdigit
                CALL @@hexdigit
                CALL @@hexdigit
                CALL @@hexdigit
                MVII #basic_buffer,R3
                MVII #4,R1
@@hx1:          MVI@ R3,R0
                CMPI #$30,R0
                BNE @@hx3
                INCR R3
                DECR R1
                CMPI #1,R1
                BNE @@hx1
@@hx3:          MOVR R3,R0
                CALL string_create
                PULR R4
                SETC
                PULR PC

@@hexdigit:
                PSHR R0
                ANDI #$0F,R0
                ADDI #$30,R0
                CMPI #$3A,R0
                BNC @@hx2
                ADDI #$07,R0
@@hx2:          MVO@ R0,R3
                DECR R3
                PULR R0
                SLR R0,2
                SLR R0,2
                MOVR R5,PC

@@STICK:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                CMPI #2,R0
                BC @@3
                MOVR R0,R1
                XORI #$01FF,R1
                MVI@ R1,R0
                XORI #$FF,R0
                MOVR R0,R1
                ANDI #$E0,R1
                CMPI #$80,R1
                BEQ @@7
                CMPI #$40,R1
                BEQ @@7
                CMPI #$20,R1
                BEQ @@7
                ANDI #$1F,R0
                INCR R7
@@7:            CLRR R0
                MVII #@@TABLE,R1
                ADDR R0,R1
                MVI@ R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

@@TABLE:
                DECLE 0,9,5,8,1,0,4,0
                DECLE 13,12,0,0,16,0,0,0
                DECLE 0,10,6,7,2,0,3,0
                DECLE 14,11,0,0,15,0,0,0

@@STRIG:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                CMPI #2,R0
                BC @@3
                MOVR R0,R1
                XORI #$01FF,R1
                MVI@ R1,R1
                XORI #$FF,R1
                CLRR R0
                ANDI #$e0,R1
                BEQ @@4
                INCR R0
                CMPI #$a0,R1
                BEQ @@4
                INCR R0
                CMPI #$60,R1
                BEQ @@4
                INCR R0
                CMPI #$C0,R1
                BEQ @@4
                CLRR R0
@@4:
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC
@@KEY:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                CMPI #2,R0
                BC @@3
                MOVR R0,R1
                XORI #$01FF,R1
                MVI@ R1,R1
                XORI #$FF,R1
                CLRR R0
                MVII #@@KEYS,R5
@@9:
                CMP@ R5,R1
                BEQ @@8
                INCR R0
                CMP@ R5,R1
                BEQ @@8
                INCR R0
                CMPI #12,R0
                BNE @@9
@@8:
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

@@KEYS:
                DECLE $48,$81,$41,$21,$82,$42,$22,$84,$44,$24,$88,$28

                ; BK(v) Read screen
@@BK:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                CMPI #240,R0
                BC @@3
                MOVR R0,R1
                ADDI #$0200,R1
                MVI@ R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; PEEK(v) Read memory
@@PEEK:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                MOVR R0,R1
                MVI@ R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; USR(v) Call and receive value
@@USR:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                CALL @@indirect
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; ASC(str) Get ASCII value
@@ASC:
                CALL bas_expr_paren
                BNC bas_type_err
                MVI@ R1,R0
                TSTR R0
                BEQ bas_type_err
                INCR R1
                MVI@ R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; LEN(str) Get length of string
@@LEN:
                CALL bas_expr_paren
                BNC bas_type_err
                MVI@ R1,R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

                ; CHR$(val) Create string from ASCII
@@CHR:
                CALL bas_expr_paren
                BC bas_type_err
                CALL fp2int
                PSHR R0
                MVII #1,R0
                CALL string_create_simple
                PULR R0
                MVO@ R0,R5
                SETC
                PULR PC

                ; LEFT$(val,l)
@@LEFT:
                macro_get_next
                CMPI #$28,R0
                BNE @@2
                CALL bas_expr
                BNC bas_type_err
                PSHR R3
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@2
                PULR R2
                CLRR R1
                PULR R3
                B @@strcommon

                ; MID$(val,p) or MID$(val,p,l)
@@MID:
                macro_get_next
                CMPI #$28,R0
                BNE @@2
                CALL bas_expr
                BNC bas_type_err
                PSHR R3
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                DECR R0                 ; Starts at one.
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BEQ @@19
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@2
                PULR R2
                B @@20
@@19:           MVII #$7FFF,R2
@@20:           PULR R1
                PULR R3
@@strcommon:
                ; Limit start position.
                MVI@ R3,R0
                TSTR R1
                BPL @@21
                CLRR R1
@@21:           CMPR R0,R1
                BEQ @@22
                BNC @@22
                MOVR R0,R1
                ; Limit length.
@@22:           TSTR R2
                BPL @@23
                CLRR R2
@@23:           ADDR R1,R2
                CMPR R0,R2
                BEQ @@24
                BNC @@24
                MOVR R0,R2
@@24:           SUBR R1,R2
                INCR R3
                MOVR R3,R0
                ADDR R1,R0
                MOVR R2,R1
                PSHR R4
                CALL string_create
                PULR R4
                SETC                    ; String.
                PULR PC

                ; RIGHT$(val,l)
@@RIGHT:
                macro_get_next
                CMPI #$28,R0
                BNE @@2
                CALL bas_expr
                BNC bas_type_err
                PSHR R3
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BC bas_type_err
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                macro_get_next
                CMPI #$29,R0
                BNE @@2
                PULR R0
                PULR R3
                MVI@ R3,R1
                PSHR R3
                MOVR R0,R2
                SUBR R2,R1
                PULR R0
                B @@strcommon

                ; VAL(str)
@@VAL:          CALL bas_expr_paren
                BNC bas_type_err
                PSHR R4
                MOVR R3,R4
                MOVR R3,R5
                MVI@ R4,R0
                TSTR R0
                BEQ @@25
@@26:           MVI@ R4,R1
                MVO@ R1,R5
                DECR R0
                BNE @@26
@@25:           CLRR R0
                MVO@ R0,R5
                MOVR R3,R4
                macro_get_next
                CALL fpparse
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                CLRC
                PULR PC

                ; INKEY$
@@INKEY:
                PSHR R4
                CALL SCAN_KBD           ; Explore the keyboard.
                CLRR R1
                CMPI #KEY.NONE,R0
                BEQ @@27
                MVO R0,temp1
                INCR R1
@@27:           MVII #temp1,R0
                CALL string_create
                PULR R4
                SETC
                PULR PC

                ; STR$
@@STR:          CALL bas_expr_paren
                BC bas_type_err
                PSHR R4
                MVI bas_func,R2
                PSHR R2
                MVII #@@STR2,R2
                MVO R2,bas_func
                CLRR R2
                MVO R2,temp1
                MVII #1,R3
                CALL fpprint
                MVII #basic_buffer,R0
                MVI temp1,R1
                CALL string_create
                PULR R2
                MVO R2,bas_func
                PULR R4
                SETC
                PULR PC

@@STR2:
                MVI temp1,R1
                INCR R1
                MVO R1,temp1
                ADDI #basic_buffer-1,R1
                MVO@ R0,R1
                MOVR R5,PC

                ; INSTR(A$,B$)
                ; INSTR(expr,A$,B$)
@@INSTR:
                macro_get_next
                CMPI #$28,R0
                BNE @@2
                CALL bas_expr
                BC @@INSTR1             ; Jump if it is string.
                MOVR R2,R0
                MOVR R3,R1
                CALL fp2int
                PSHR R0
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BNC bas_type_err
                B @@INSTR2
@@INSTR1:
                CLRR R0
                PSHR R0
@@INSTR2:
                PSHR R3
                macro_get_next
                CMPI #$2C,R0
                BNE @@2
                CALL bas_expr
                BNC bas_type_err
                macro_get_next
                CMPI #$29,R0
                BNE @@2
                PULR R2
                PULR R0
                PSHR R4
                ; Limit search pointer.
                DECR R0
                BPL @@28
                CLRR R0
@@28:           CMP@ R2,R0
                BLT @@29
                MVI@ R2,R0
@@29:           CMP@ R2,R0              ; Position equal to string length?
                BGE @@31                ; Yes, stop.
                MOVR R0,R1              ; Position...
                ADD@ R3,R1              ; ...plus comparison string length...
                CMP@ R2,R1              ; ...exceeds string length?
                BGT @@31                ; Yes, stop.
                CALL @@string_comparison_portion
                BC @@30
                INCR R0
                B @@29

                ; String comparison for INSTR.
@@string_comparison_portion:
                PSHR R5
                PSHR R0
                MOVR R2,R4
                INCR R4
                ADDR R0,R4
                MOVR R3,R5
                MVI@ R5,R1
                TSTR R1
                BEQ @@32
@@33:           MVI@ R4,R0
                CMP@ R5,R0              ; Compare string.
                BNE @@34
                DECR R1
                BNE @@33
@@32:           SETC                    ; Match found.
                PULR R0
                PULR PC

@@34:           CLRC                    ; Not matched.
                PULR R0
                PULR PC

@@31:           MVII #$FFFF,R0
@@30:           INCR R0
                CALL fpfromint
                MOVR R0,R2
                MOVR R1,R3
                PULR R4
                CLRC
                PULR PC

@@indirect:
                MOVR R0,PC

@@6:            CMPI #$41,R0            ; A-Z?
                BNC @@35
                CMPI #$5B,R0
                BNC @@5
@@35:           CMPI #TOKEN_NUMBER,R0   ; Period?
                BEQ @@11
                CMPI #TOKEN_INTEGER,R0
                BEQ @@37
                CMPI #$22,R0            ; Quote?
                BEQ @@36
                CMPI #$28,R0            ; Parenthesis?
                BEQ @@12
                B @@2

@@36:           MOVR R4,R5              ; Start of string.
@@14:           MVI@ R4,R0
                CMPI #$22,R0            ; Locate end of string.
                BNE @@14
                PSHR R4
                DECR R4
                SUBR R5,R4              ; Get length of string.
                MOVR R4,R1
                MOVR R5,R0
                CALL string_create
                PULR R4
                SETC                    ; String
                PULR PC

@@12:           CALL bas_expr           ; Process expression.
                GSWD R1
                macro_get_next
                CMPI #$29,R0            ; Closing parenthesis.
                BNE @@2
                RSWD R1
                PULR PC

@@5:            MVI@ R4,R1
                CMPI #$24,R1            ; $
                BNE @@17
                CALL get_string_addr.0
                PSHR R4
                MVI@ R5,R4              ; Get string
                TSTR R4
                BEQ @@18
                MOVR R4,R5
                MVI@ R5,R4              ; Get length
@@18:
                MOVR R4,R1
                MOVR R5,R0
                CALL string_create      ; Copy string.
                PULR R4
                SETC                    ; String
                PULR PC

@@17:           DECR R4
                CALL get_var_addr.0     ; Get variable address.
                MVI@ R1,R2              ; Read value.
                INCR R1
                MVI@ R1,R3
                CLRC
                PULR PC

@@11:           MVI@ R4,R3              ; Read floating-point number.
                MVI@ R4,R1
                SWAP R1
                ADDR R1,R3
                MVI@ R4,R2
                MVI@ R4,R1
                SWAP R1
                ADDR R1,R2
                CLRC
                PULR PC

@@37:           MVI@ R4,R0              ; Read integer.
                MVI@ R4,R1
                SWAP R1
                ADDR R1,R0
                CALL fpfromuint
                MOVR R0,R2
                MOVR R1,R3
                CLRC
                PULR PC

@@2:            MVII #ERR_SYNTAX,R0
                CALL bas_error

@@3:            MVII #ERR_BOUNDS,R0
                CALL bas_error
                ENDP

                ;
                ; Parse an integer.
                ;
parse_integer:  PROC
                macro_get_next
                CMPI #TOKEN_INTEGER,R0  ; Integer here?
                BNE @@1
                MVI@ R4,R0              ; Get first byte.
                MVI@ R4,R1              ; Get second byte.
                SWAP R1
                ADDR R1,R0              ; Carry flag cleared.
                MOVR R5,PC

@@1:            SETC                    ; No integer here.
                MOVR R5,PC
                ENDP

                ;
                ; Get string variable address.
                ; Input:
                ;   R0 = String letter (A-Z)
                ; Output:
                ;   R5 = Pointer.
                ;
get_string_addr: PROC
@@0:            PSHR R5
                MVII #strings-$41,R5
                ADDR R0,R5
                PULR PC
                ENDP

                ;
                ; Create a string on the heap.
                ;
                ; Input:
                ;   R0 = Pointer to the string.
                ;   R1 = Length of the string.
                ; Output:
                ;   R3 = Pointer to the new string.
                ;
string_create:  PROC
                PSHR R5
                MOVR R0,R4
                MVI bas_strptr,R5       ; Get string stack pointer.
                SUBR R1,R5
                DECR R5
                MVO R5,bas_strptr       ; Push string.
                MVO@ R1,R5              ; Take note of length.
                TSTR R1
                BEQ @@2
@@1:
                MVI@ R4,R0              ; Copy string.
                MVO@ R0,R5
                DECR R1
                BNE @@1
@@2:
                MVI bas_strptr,R3
                CMP bas_last_array,R3
                BEQ @@3
                BNC @@3
                PULR PC

@@3:            MVII #ERR_MEMORY,R0
                CALL bas_error
                ENDP

                ;
                ; Create a simple string on the heap.
                ;
                ; Input:
                ;   R0 = Length of the string.
                ; Output:
                ;   R3 = Pointer to the new string.
                ;
string_create_simple: PROC
                PSHR R5
                MVI bas_strptr,R5       ; Get string stack pointer.
                SUBR R0,R5
                DECR R5
                MVO R5,bas_strptr       ; Push string.
                MVO@ R0,R5              ; Take note of length.
                MVI bas_strptr,R3
                CMP bas_last_array,R3
                BEQ @@3
                BNC @@3
                PULR PC

@@3:            MVII #ERR_MEMORY,R0
                CALL bas_error
                ENDP

                ;
                ; String comparison
                ; R1 = Pointer to string (left operand)
                ; R3 = Pointer to string (right operand)
                ;
string_comparison: PROC
                MVI@ R1,R0              ; Read length 1
                INCR R1
                MVI@ R3,R2              ; Read length 2
                INCR R3
@@1:            TSTR R0
                BEQ @@2
                TSTR R2
                BEQ @@5
                MVI@ R1,R4
                CMP@ R3,R4              ; Compare characters.
                BEQ @@6
                BNC @@3
@@5:            MVII #1,R0              ; >
                MOVR R5,PC

@@6:            INCR R1
                INCR R3
                DECR R0
                DECR R2
                B @@1

@@2:            TSTR R2
                BEQ @@4

@@3:            MVII #$FFFF,R0          ; <
                MOVR R5,PC

@@4:            CLRR R0                 ; =
                MOVR R5,PC
                ENDP

                ;
                ; String concatenation.
                ; R1 = Pointer to string (left operand)
                ; R3 = Pointer to string (right operand)
                ;
string_concat:  PROC
                PSHR R5
                MVI@ R1,R0              ; Read length 1
                INCR R1
                MVI@ R3,R2              ; Read length 2
                INCR R3
                MOVR R0,R4
                ADDR R2,R4
                MVI bas_strptr,R5       ; Get string stack pointer.
                SUBR R4,R5              ; Space for string
                DECR R5                 ; Space for length
                MVO R5,bas_strptr       ; Push string.
                MVO@ R4,R5
                TSTR R0                 ; Left string has zero length?
                BEQ @@1                 ; Yes, jump.
@@2:
                MVI@ R1,R4              ; Copy string.
                MVO@ R4,R5
                INCR R1
                DECR R0
                BNE @@2
@@1:
                TSTR R2                 ; Right string has zero length?
                BEQ @@3                 ; Yes, jump.
@@4:
                MVI@ R3,R4              ; Copy string.
                MVO@ R4,R5
                INCR R3
                DECR R2
                BNE @@4
@@3:
                MVI bas_strptr,R3
                CMP bas_last_array,R3
                BEQ @@5
                BNC @@5
                SETC                    ; String
                PULR PC

@@5:            MVII #ERR_MEMORY,R0
                CALL bas_error
                ENDP

                ;
                ; String assign.
                ; R1 = Pointer to string variable.
                ; R3 = New string.
                ;
string_assign:  PROC
                PSHR R5
                MVII #STRING_TRASH,R4

                ;
                ; Erase the used space of the stack.
                ;
                MOVR R3,R2              ; Get new string.
                MVI@ R2,R0              ; Get length of string.
                INCR R2                 ; Jump over length.
                ADDR R0,R2              ; Jump over string.
                MVI bas_strbase,R0
                CMPR R0,R2              ; There is space between this pointer and strbase?
                BC @@3                  ; No, jump.
@@4:            MVO@ R4,R2              ; Fill the unused space.
                INCR R2
                CMPR R0,R2
                BNC @@4
@@3:
                ;
                ; Erase the old string.
                ;
                MVI@ R1,R2              ; Get old string.
                TSTR R2                 ; Nothing?
                BEQ @@1                 ; No, jump.
                MVI@ R2,R0
                MVO@ R4,R2              ; Erase length.
                INCR R2
                TSTR R0
                BEQ @@1
@@2:            MVO@ R4,R2              ; Erase string.
                INCR R2
                DECR R0
                BNE @@2
                ;
                ; Search for space at higher-addresses.
                ;
@@1:            MVII #start_strings-1,R2
                CMP bas_strbase,R2      ; All examined?
                BNC @@6                 ; Yes, jump.
@@5:            CMP@ R2,R4              ; Space found?
                BNE @@7                 ; No, keep searching.
                CLRR R5
@@8:
                INCR R5
                DECR R2
                CMP bas_strbase,R2
                BNC @@9
                CMP@ R2,R4              ; Found a space?
                BEQ @@8                 ; Yes, jump.
@@9:            INCR R2
                MVI@ R3,R0              ; Get new string length.
                INCR R0                 ; Integrate the length.
                CMPR R0,R5              ; The new string fits?
                BNC @@7                 ; No, jump.
                ;
                ; The string fits in previous space.
                ;
                MOVR R3,R4
                MOVR R2,R5
                MVO@ R2,R1              ; New address.
@@10:           MVI@ R4,R2              ; Copy string and length.
                MVO@ R2,R5
                DECR R0
                BNE @@10
                PULR PC

@@7:            DECR R2
                CMP bas_strbase,R2
                BC @@5

                ;
                ; No space available.
                ;
@@6:            MVO R3,bas_strbase      ; Grow space for string variables.
                MVO@ R3,R1
                PULR PC
                ENDP

                ;
                ; Save content under the cursor.
                ;
bas_save_cursor: PROC
                MVI bas_ttypos,R4
                MVI@ R4,R0
                MVO R0,bas_card
                MOVR R5,PC
                ENDP

                ;
                ; Show blinking cursor.
                ;
bas_blink_cursor: PROC
@@0:            MVI _int,R0
                TSTR R0                 ; Wait for a video frame to happen.
                BEQ @@0
                CLRR R0
                MVO R0,_int

                MVI bas_card,R1
                MVI _frame,R0
                ANDI #16,R0
                BEQ @@1
                MVI bas_curcolor,R1
                ADDI #$5F*8,R1
@@1:            MVI bas_ttypos,R4
                MVO@ R1,R4
                MOVR R5,PC
                ENDP

                ;
                ; Remove cursor.
                ;
bas_restore_cursor: PROC
                MVI bas_card,R1
                MVI bas_ttypos,R4
                MVO@ R1,R4
                MOVR R5,PC
                ENDP

indirect_output: PROC
                MVI bas_func,R7
                ENDP

                ;
                ; Output a new line
                ;
bas_output_newline: PROC
                PSHR R5
                MVII #BAS_CR,R0
                CALL bas_output
                MVII #BAS_LF,R0
                CALL bas_output
                PULR PC
                ENDP

                ;
                ; Output a character to the screen
                ;
bas_output:     PROC
                CMPI #$FFFF,R0          ; Get horizontal position.
                BNE @@19
                MVI bas_ttypos,R0
                SUBI #$0200,R0
@@20:           SUBI #20,R0
                BC @@20
                ADDI #20,R0
                MOVR R5,PC
@@19:
                PSHR R5
                CMPI #$0100,R0          ; Characters 256-511
                BC @@18
                CMPI #$20,R0
                BC @@0
                CMPI #BAS_CR,R0         ; Carriage return?
                BEQ @@5                 ; Yes, jump.
                CMPI #BAS_LF,R0         ; Line feed?
                BEQ @@3                 ; Yes, jump.
                CMPI #KEY.LEFT,R0       ; Moving to left?
                BEQ @@7                 ; Yes, jump.
                CMPI #KEY.RIGHT,R0      ; Moving to right?
                BEQ @@10                ; Yes, jump.
                CMPI #KEY.UP,R0         ; Moving up?
                BEQ @@12                ; Yes, jump.
                CMPI #KEY.DOWN,R0       ; Moving down?
                BEQ @@15                ; Yes, jump.
@@0:
                ;
                ; Normal letter
                ;
                SUBI #$20,R0
                ANDI #$FF,R0
@@18:
                SLL R0,2                ; Convert character to card number.
                SLL R0,1
                ADD bas_curcolor,R0
                MVI bas_ttypos,R4
                MVO@ R0,R4              ; Put on the screen.
                CMPI #$02F0,R4          ; Reached the screen limit?
                BNE @@1                 ; No, jump.
                CALL @@scroll
                MVII #$02DC,R4
@@1:            MVO R4,bas_ttypos
                PULR PC

                ;
                ; Carriage return.
                ;
@@5:            MVI bas_ttypos,R4
                SUBI #$0200,R4
                MVII #$01EC,R0
@@6:            ADDI #20,R0
                SUBI #20,R4
                BC @@6
                MVO R0,bas_ttypos
                PULR PC

                ;
                ; Line feed.
                ;
@@3:            MVI bas_ttypos,R4
                ADDI #20,R4
                CMPI #$02F0,R4
                BNC @@4
                PSHR R4
                CALL @@scroll
                PULR R4
                SUBI #20,R4
@@4:            MVO R4,bas_ttypos
                PULR PC

                ;
                ; Move left.
                ;
@@7:            MVI bas_ttypos,R4
                CMPI #$0200,R4
                BEQ @@8
                DECR R4
@@8:            MVO R4,bas_ttypos
                PULR PC

                ;
                ; Move right.
                ;
@@10:           MVI bas_ttypos,R4
                CMPI #$02EF,R4
                BEQ @@11
                INCR R4
@@11:           MVO R4,bas_ttypos
                PULR PC

                ;
                ; Move upward.
                ;
@@12:           MVI bas_ttypos,R4
                CMPI #$0214,R4
                BNC @@14
                SUBI #20,R4
@@14:           MVO R4,bas_ttypos
                PULR PC

                ;
                ; Move downward.
                ;
@@15:           MVI bas_ttypos,R4
                CMPI #$02DC,R4
                BC @@16
                ADDI #20,R4
@@16:           MVO R4,bas_ttypos
                PULR PC

                ;
                ; Scroll up.
                ;
@@scroll:
                PSHR R5
                MVII #$0214,R4
                MVII #$0200,R5
                MVII #$00DC/4,R2
@@2:            MVI@ R4,R0
                MVO@ R0,R5
                MVI@ R4,R0
                MVO@ R0,R5
                MVI@ R4,R0
                MVO@ R0,R5
                MVI@ R4,R0
                MVO@ R0,R5
                DECR R2
                BNE @@2
                ; Clear the bottom row.
                MVI bas_curcolor,R0
                MVII #$0014/2,R2
@@9:            MVO@ R0,R5
                MVO@ R0,R5
                DECR R2
                BNE @@9
                MVI bas_firstpos,R0
                CMPI #$0214,R0
                BNC @@17
                SUBI #20,R0
                MVO R0,bas_firstpos
@@17:
                PULR PC

                ENDP

                ;
                ; ECS keyboard scanning routines by Joe Zbiciak (intvnut)
                ;
KBD_DECODE      PROC
@@no_mods       DECLE KEY.NONE, "ljgda" ; col 7
                DECLE KEY.ENTER, "oute", KEY.NONE; col 6
                DECLE "08642", KEY.RIGHT; col 5
                DECLE KEY.ESC, "97531"  ; col 4
                DECLE "piyrwq"          ; col 3
                DECLE ";khfs", KEY.UP   ; col 2
                DECLE ".mbcz", KEY.DOWN ; col 1
                DECLE KEY.LEFT, ",nvx " ; col 0

@@shifted       DECLE KEY.NONE, "LJGDA" ; col 7
                DECLE KEY.ENTER, "OUTE", KEY.NONE; col 6
                DECLE ")*-$\"\'"        ; col 5
                DECLE KEY.ESC, "(/+#="  ; col 4
                DECLE "PIYRWQ"          ; col 3
                DECLE ":KHFS^"          ; col 2
                DECLE ">MBCZ?"          ; col 1
                DECLE "%<NVX "          ; col 0

@@control       DECLE KEY.NONE, $C, $A, $7, $4, $1; col 7
                DECLE KEY.ENTER, $F, $15, $14, $5, KEY.NONE; col 6
                DECLE "}~_!'", KEY.RIGHT; col 5
                DECLE KEY.ESC, "{&@`~"  ; col 4
                DECLE $10, $9, $19, $12, $17, $11; col 3
                DECLE "|", $B, $8, $6, $13, KEY.UP; col 2
                DECLE "]", $D, $2, $3, $1A, KEY.DOWN; col 1
                DECLE KEY.LEFT, "[", $0E, $16, $18, $20; col 0
                ENDP

                ;
                ; Explore the keyboard with debouncing.
                ;
SCAN_KBD_DEBOUNCE: PROC
                PSHR R5
                CALL SCAN_KBD

                CMPI #KEY.NONE, R0
                BNE @@debounce
                MVII #64,R4
                MVO R4, ECS_KEY_LAST
                B @@new

@@debounce:
                CMP ECS_KEY_LAST, R4
                MVO R4,         ECS_KEY_LAST
                BNEQ @@new
                MVII #KEY.NONE,  R0
@@new:
                PULR PC
                ENDP

                ;
                ; Explore the keyboard.
                ;
SCAN_KBD:       PROC

                ;; ------------------------------------------------------------ ;;
                ;;  Try to find CTRL and SHIFT first.                           ;;
                ;;  Shift takes priority over control.                          ;;
                ;; ------------------------------------------------------------ ;;

                ; maybe DIS here
                MVI $F8,        R0
                ANDI #$3F,       R0
                XORI #$40,       R0     ; normal scan mode
                MVO R0,         $F8
                ; maybe EIS here

                CLRR R4                 ; col pointer

                MVII #$EF,       R0     ; \_ drive row
                MVO R0,         $FE     ; /
                MVI $FF,        R1      ; \
                ANDI #$80,       R1     ;  > look for a 0 in column 7
                BNE @@no_d_key          ; /
                MVII #4, R4
@@no_d_key:

                ; maybe DIS here
                MVI $F8,        R1
                ANDI #$3F,       R1
                XORI #$80,       R1     ; transpose scan mode
                MVO R1,         $F8
                ; maybe EIS here

                MVII #KBD_DECODE.no_mods, R3; neither shift nor ctrl

                MVII #$7F,       R1     ; \_ drive column 7 to 0
                MVO R1,         $FF     ; /
                MVI $FE,        R1      ; \
                ANDI #$40,       R1     ;  > look for a 0 in row 6
                BEQ @@have_shift        ; /

                MVII #$BF,       R1     ; \_ drive column 6 to 0
                MVO R1,         $FF     ; /
                MVI $FE,        R1      ; \
                ANDI #$20,       R1     ;  > look for a 0 in row 5
                BNEQ @@done_shift_ctrl  ; /

                MVII #KBD_DECODE.control, R3
                B @@done_shift_ctrl

@@have_shift:
                MVII #KBD_DECODE.shifted, R3

@@done_shift_ctrl:

                ;; ------------------------------------------------------------ ;;
                ;;  Start at col 7 and work our way to col 0.                   ;;
                ;; ------------------------------------------------------------ ;;
                CLRR R2
                MVII #$FF7F, R1

                TSTR R4
                BNE @@got_key

@@col:          MVO R1,     $FF
                MVI $FE,    R0
                XORI #$FF,   R0
                BNEQ @@maybe_key

@@cont_col:     ADDI #6,     R2
                RRC R1,1
                BC @@col

                MVII #KEY.NONE,  R0
                B @@new

                ;; ------------------------------------------------------------ ;;
                ;;  Looks like a key is pressed.  Let's decode it.              ;;
                ;; ------------------------------------------------------------ ;;
@@maybe_key:
                MOVR R2,R4
                SARC R0,     2
                BC @@got_key            ; row 0
                BOV @@got_key1          ; row 1
                ADDI #2,     R4
                SARC R0,     2
                BC @@got_key            ; row 2
                BOV @@got_key1          ; row 3
                ADDI #2,     R4
                SARC R0,     2
                BC @@got_key            ; row 4
                BNOV @@cont_col         ; row 5
@@got_key1:     INCR R4
@@got_key:
                ADDR R4,     R3         ; add modifier offset
                MVI@ R3,     R0

                CMPI #KEY.NONE, R0      ; if invalid, keep scanning
                BEQ @@cont_col

@@new:          ; maybe DIS here
                MVI $F8,        R1      ; \
                ANDI #$3F,       R1     ;  > set both I/O ports to "input"
                MVO R1,         $F8     ; /
                ; maybe EIS here
                JR R5
                ENDP

                ;
                ; Print an integer.
                ;
PRNUM16:        PROC
@@l:            PSHR R5
                CLRR R2
                MVII #10000,R1
                CALL @@d
                MVII #1000,R1
                CALL @@d
                MVII #100,R1
                CALL @@d
                MVII #10,R1
                CALL @@d
                MVII #1,R1
                MOVR R1,R2
                CALL @@d
                PULR PC

                ;
                ; Print an integer digit.
                ;
@@d:            PSHR R5
                MVII #$2F,R3
@@1:            INCR R3
                SUBR R1,R0
                BC @@1
                ADDR R1,R0
                PSHR R0
                CMPI #$30,R3
                BNE @@2
                TSTR R2
                BEQ @@3
@@2:            INCR R2
                PSHR R2
                MOVR R3,R0
                CALL indirect_output
                PULR R2
@@3:            PULR R0
                PULR PC

                ENDP

                ;
                ; Set the interrupt service routine.
                ;
_set_isr:       PROC
                MVI@ R5,R0
                MVO R0,ISRVEC
                SWAP R0
                MVO R0,ISRVEC+1
                JR R5
                ENDP

                ;
                ; Interruption routine
                ;
_int_vector:    PROC

                MVII #1,R1
                MVO R1,_int             ; Indicates interrupt happened.

                MVO R0,$20              ; Enables display
                MVI _mode,R0
                TSTR R0
                BEQ @@1
                MVO R0,$21              ; Foreground/background mode
                B @@2

@@1:            MVI $21,R0              ; Color stack mode
                MVI _mode_color,R0
                MVO R0,$28
                SLR R0,2
                SLR R0,2
                MVO R0,$29
                SLR R0,2
                SLR R0,2
                MVO R0,$2A
                SLR R0,2
                SLR R0,2
                MVO R0,$2B
@@2:

@@0:
                BEGIN

                MVI _border_color,R0
                MVO R0,     $2C         ; Border color
                MVI _border_mask,R0
                MVO R0,     $32         ; Border mask
                ;
                ; Save collision registers for further use and clear them
                ;
                MVII #$18,R4
                MVII #_col0,R5
                MVI@ R4,R0
                MVO@ R0,R5              ; _col0
                MVI@ R4,R0
                MVO@ R0,R5              ; _col1
                MVI@ R4,R0
                MVO@ R0,R5              ; _col2
                MVI@ R4,R0
                MVO@ R0,R5              ; _col3
                MVI@ R4,R0
                MVO@ R0,R5              ; _col4
                MVI@ R4,R0
                MVO@ R0,R5              ; _col5
                MVI@ R4,R0
                MVO@ R0,R5              ; _col6
                MVI@ R4,R0
                MVO@ R0,R5              ; _col7

                ;
                ; Updates sprites (MOBs)
                ;
                MOVR R5,R4              ; MVII #_mobs,R4
                CLRR R5                 ; X-coordinates
                REPEAT 8
                    MVI@ R4,R0
                    MVO@ R0,R5
                    MVI@ R4,R0
                    MVO@ R0,R5
                    MVI@ R4,R0
                    MVO@ R0,R5
                ENDR
                CLRR R0                 ; Erase collision bits (R5 = $18)
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5
                MVO@ R0,R5

                ;
                ; Detect GRAM definition
                ;
                MVI _gram_bitmap,R4
                TSTR R4
                BEQ @@vi1
                MVI _gram_target,R1
                SLL R1,2
                SLL R1,1
                ADDI #$3800,R1
                MOVR R1,R5
                MVI _gram_total,R0
@@vi3:
                MVI@ R4,     R1
                MVO@ R1,     R5
                SWAP R1
                MVO@ R1,     R5
                MVI@ R4,     R1
                MVO@ R1,     R5
                SWAP R1
                MVO@ R1,     R5
                MVI@ R4,     R1
                MVO@ R1,     R5
                SWAP R1
                MVO@ R1,     R5
                MVI@ R4,     R1
                MVO@ R1,     R5
                SWAP R1
                MVO@ R1,     R5
                DECR R0
                BNE @@vi3
                MVO R0,_gram_bitmap
@@vi1:

                ; Increase frame number (32 bits)
                MVI _frame,R0
                INCR R0
                MVO R0,_frame
                BNE @@3
                MVI _frame+1,R0
                INCR R0
                MVO R0,_frame+1
@@3:

                ; Adjust random number generator
                MVI lfsr,R0
                ADDI #61,R0             ; A prime number.
                MVO R0,lfsr

                RETURN
                ENDP

                ORG $D000

                INCLUDE "fplib.asm"
                INCLUDE "fpio.asm"
                INCLUDE "fpmath.asm"
                INCLUDE "uart.asm"

                ORG $320,$320,"-RWB"
_frame:         RMB 2                   ; Current frame number.
_col0:          RMB 1                   ; Collision status for MOB0
_col1:          RMB 1                   ; Collision status for MOB1
_col2:          RMB 1                   ; Collision status for MOB2
_col3:          RMB 1                   ; Collision status for MOB3
_col4:          RMB 1                   ; Collision status for MOB4
_col5:          RMB 1                   ; Collision status for MOB5
_col6:          RMB 1                   ; Collision status for MOB6
_col7:          RMB 1                   ; Collision status for MOB7
_mobs:          RMB 24                  ; Data for sprites.
bas_firstpos:   RMB 1                   ; First position of cursor.
bas_ttypos:     RMB 1                   ; Current position on screen.
bas_curcolor:   RMB 1                   ; Current color.
bas_card:       RMB 1                   ; Card under the cursor.
bas_curline:    RMB 1                   ; Current line in execution (0 for direct command)
bas_forptr:     RMB 1                   ; Stack for FOR loops.
bas_gosubptr:   RMB 1                   ; Stack for GOSUB/RETURN.
bas_dataptr:    RMB 1                   ; Pointer for DATA.
bas_arrays:     RMB 1                   ; Pointer to where arrays start.
bas_last_array: RMB 1                   ; Pointer to end of array list.
bas_strptr:     RMB 1                   ; Pointer to space for strings processing.
bas_strbase:    RMB 1                   ; Pointer to base for strings space.
bas_listen:     RMB 1                   ; End of LIST.
bas_func:       RMB 1                   ; Output function (for fpprint)
program_end:    RMB 1                   ; Pointer to program's end.
lfsr:           RMB 1                   ; Random number
_mode_color:    RMB 1                   ; Colors for Color Stack mode.
_gram_bitmap:   RMB 1                   ; Pointer to bitmap for GRAM.
_timeout:       RMB 1                   ; For cassette functions.
                ; For the PLOT/DRAW statements.
plot_x:         RMB 1
plot_y:         RMB 1
draw_x:         RMB 1
draw_y:         RMB 1
delta_x:        RMB 1
delta_y:        RMB 1
sign_x:         RMB 1
sign_y:         RMB 1
err:            RMB 1


SCRATCH:        ORG $100,$100,"-RWBN"
                ;
                ; 8-bits variables
                ;
ISRVEC:         RMB 2                   ; Pointer to ISR vector (required by Intellivision ROM)
_int:           RMB 1                   ; Signals interrupt received
_ntsc:          RMB 1                   ; bit 0 = 1=NTSC, 0=PAL. Bit 1 = 1=ECS detected.
_mode:          RMB 1                   ; Video mode setup.
_border_color:  RMB 1                   ; Border color
_border_mask:   RMB 1                   ; Border mask
_gram_target:   RMB 1                   ; Target GRAM card.
_gram_total:    RMB 1                   ; Total of GRAM cards.
ECS_KEY_LAST:   RMB 1                   ; ECS last key pressed.
temp1:          RMB 1                   ; Temporary value.
_filename:      RMB 4                   ; File name.
_printer_col:   RMB 1                   ; Printer column.
_check_esc:     RMB 1                   ; For checking Esc key.

                ; Enable JLP RAM on real hardware. Nice for LTO-Flash.
                ;	CFGVAR "jlp" = 1

                ; Map CC3 RAM
                ; It is better to be cartridge agnostic.
MAIN_RAM:       ORG $8000,$8000,"=RW"

                RMB 8192
