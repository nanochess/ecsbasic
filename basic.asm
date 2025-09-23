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
	; Revision date: Sep/23/2025. Added INPUT statement.
	;

	ROMW 16
	ORG $5000

basic_buffer:	EQU $8040
variables:	EQU $8080
program_start:	EQU $80C0
TOKEN_START:	EQU $0100
TOKEN_COLON:	EQU $0100
TOKEN_GOTO:	EQU $0108
TOKEN_IF:	EQU $0109
TOKEN_THEN:	EQU $010a
TOKEN_ELSE:	EQU $010b
TOKEN_LE:	EQU $010c
TOKEN_GE:	EQU $010d
TOKEN_NE:	EQU $010e
TOKEN_EQ:	EQU $010f
TOKEN_LT:	EQU $0110
TOKEN_GT:	EQU $0111

ERR_TITLE:	EQU 0
ERR_SYNTAX:	EQU 1
ERR_STOP:	EQU 2
ERR_LINE:	EQU 3

KEY.LEFT    EQU     $1C     ; \   Can't be generated otherwise, so perfect
KEY.RIGHT   EQU     $1D     ;  |_ candidates.  Could alternately send 8 for
KEY.UP      EQU     $1E     ;  |  left... not sure...
KEY.DOWN    EQU     $1F     ; /   
KEY.ENTER   EQU     $A      ; Newline
KEY.ESC     EQU     27
KEY.NONE    EQU     $FF

BAS_CR:	EQU $0d
BAS_LF:	EQU $0a
BAS_BS:	EQU $1C		; Same as KEY.LEFT

STACK:		equ $02f0	; Base stack pointer.

	;
	; ROM header
	;
	BIDECLE _ZERO		; MOB picture base
	BIDECLE _ZERO		; Process table
	BIDECLE _MAIN		; Program start
	BIDECLE _ZERO		; Background base image
	BIDECLE _ONES		; GRAM
	BIDECLE _TITLE		; Cartridge title and date
	DECLE   $03C0		; No ECS title, jump to code after title,
				; ... no clicks
                                
_ZERO:	DECLE   $0000		; Border control
	DECLE   $0000		; 0 = color stack, 1 = f/b mode
        
_ONES:	DECLE   $0001, $0001	; Initial color stack 0 and 1: Blue
	DECLE   $0001, $0001	; Initial color stack 2 and 3: Blue
	DECLE   $0001		; Initial border color: Blue

CLRSCR:	MVII #$200,R4		; Used also for CLS
	MVII #$F0,R1
FILLZERO:
	CLRR R0
MEMSET:
	SARC R1,2
	BNOV $+4
	MVO@ R0,R4
	MVO@ R0,R4
	BNC $+3
	MVO@ R0,R4
	BEQ $+7
	MVO@ R0,R4
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
	; Note mark is for automatic replacement by IntyBASIC
_TITLE:
        BYTE 125, 'ECS Extended BASIC', 0 
        
	;
	; Main program
	;
_MAIN:
	DIS			; Disable interrupts
	MVII #STACK,R6

	;
	; Clean memory
	;
	CALL CLRSCR		; Clean up screen, right here to avoid brief
				; screen display of title in Sears Intellivision.
	MVII #$00e,R1		; 14 of sound (ECS)
	MVII #$0f0,R4		; ECS PSG
	CALL FILLZERO
	MVII #$0fe,R1		; 240 words of 8 bits plus 14 of sound
	MVII #$100,R4		; 8-bit scratch RAM
	CALL FILLZERO

	; Seed random generator using 16 bit RAM (not cleared by EXEC)
;	CLRR R0
;	MVII #$02F0,R4
;	MVII #$0110/4,R1	; Includes phantom memory for extra randomness
;_MAIN4:				; This loop is courtesy of GroovyBee
;	ADD@ R4,R0
;	ADD@ R4,R0
;	ADD@ R4,R0
;	ADD@ R4,R0
;	DECR R1
;	BNE _MAIN4
;	MVO R0,_rand

	MVII #$058,R1		; 88 words of 16 bits
	MVII #$308,R4		; 16-bit scratch RAM
	CALL FILLZERO

	; PAL/NTSC detect
	CALL _set_isr
	DECLE _pal1
	EIS
	DECR PC			; This is a kind of HALT instruction

	; First interrupt may come at a weird time on Tutorvision, or
	; if other startup timing changes.
_pal1:	SUBI #8,R6		; Drop interrupt stack.
	CALL _set_isr
	DECLE _pal2
	DECR PC

	; Second interrupt is safe for initializing MOBs.
	; We will know the screen is off after this one fires.
_pal2:	SUBI #8,R6		; Drop interrupt stack.
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
	MVO R0,$30		; Reset horizontal delay register
	MVO R0,$31		; Reset vertical delay register

	MVII #-1100,R2		; PAL/NTSC threshold
_pal2_cnt:
	INCR R2
	B _pal2_cnt

	; The final count in R2 will either be negative or positive.
	; If R2 is still -ve, NTSC; else PAL.
_pal3:	SUBI #8,R6		; Drop interrupt stack.
	RLC R2,1
	RLC R2,1
	ANDI #1,R2		; 1 = NTSC, 0 = PAL

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
	ADDI #2,R2		; ECS detected flag
_ecs1:
	MVO R2,_ntsc	

	CALL _set_isr
	DECLE _int_vector

	MVII #1,R0
	MVO R0,_border_color
	MVII #$07,R0
	MVO R0,bas_color

	CALL bas_new
	CALL bas_cls
	CLRR R0
	MVO R0,bas_curline
	MVII #ERR_TITLE,R0
	CALL bas_error
basic_restart:
	MVII #STACK,R6
	MVII #$52,R0
	CALL bas_output
	MVII #$45,R0
	CALL bas_output
	MVII #$41,R0
	CALL bas_output
	MVII #$44,R0
	CALL bas_output
	MVII #$59,R0
	CALL bas_output
	MVII #$0d,R0
	CALL bas_output
	MVII #$0a,R0
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
	MVII #$0102,R0	; CLS Currently
	MVO@ R0,R4
	CLRR R0
	MVO@ R0,R4
	CLRR R0
	MVO@ R0,R4
	CALL bas_list
    ENDI

main_loop:
	CALL bas_save_cursor
@@0:
	CALL bas_blink_cursor
	CALL SCAN_KBD
	CMPI #KEY.NONE,R0
	BEQ @@0
	CALL bas_restore_cursor
	CMPI #KEY.ENTER,R0
	BNE @@1
	MVII #BAS_CR,R0
	CALL bas_output
	MVII #BAS_LF,R0
	CALL bas_output
	MVI bas_firstpos,R4
	CALL bas_tokenize
	MVI basic_buffer+0,R0
	TSTR R0		; Line number found?
	BNE @@2		; Yes, jump.
	MVII #basic_buffer,R4
	CALL bas_execute_line
	B @@3

@@2:	MVI basic_buffer+0,R0
	CALL line_search
	CMPR R1,R0
	BNE @@4		; Jump if not found.
	CALL line_delete
@@4:	MVI basic_buffer+2,R0
	TSTR R0
	BEQ @@3
	MVI basic_buffer+0,R0
	CALL line_search
	MVI basic_buffer+0,R1
	MVI basic_buffer+1,R3
	MVII #basic_buffer+2,R2
	CALL line_insert
@@3:
	MVI bas_ttypos,R0
	MVO R0,bas_firstpos
	B main_loop
@@1:
	CALL bas_output
	B main_loop

keywords_exec:
	DECLE $0000	; Colon
	DECLE bas_list
	DECLE bas_new
	DECLE bas_cls
	DECLE bas_run
	DECLE bas_stop
	DECLE bas_print
	DECLE bas_input
	DECLE bas_goto
	DECLE bas_if
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_syntax_error

keywords:
	DECLE ":",0
	DECLE "LIST",0
	DECLE "NEW",0
	DECLE "CLS",0
	DECLE "RUN",0
	DECLE "STOP",0
	DECLE "PRINT",0
	DECLE "INPUT",0
	DECLE "GOTO",0
	DECLE "IF",0
	DECLE "THEN",0
	DECLE "ELSE",0
	DECLE "<=",0
	DECLE ">=",0
	DECLE "<>",0
	DECLE "=",0
	DECLE "<",0
	DECLE ">",0
	DECLE 0

at_line:
	DECLE " at ",0
errors:
	DECLE "ECS extended BASIC",0
	DECLE "Syntax error",0
	DECLE "STOP",0
	DECLE "Undefined",0

	;
	; Read a line from the input
	;
bas_get_line:	PROC
	PSHR R5
	MVII #basic_buffer,R4
@@2:
	PSHR R4
	CALL bas_save_cursor
@@0:
	CALL bas_blink_cursor
	CALL SCAN_KBD
	CMPI #KEY.NONE,R0
	BEQ @@0
	CALL bas_restore_cursor
	PULR R4
	CMPI #KEY.ENTER,R0
	BEQ @@1
	CMPI #KEY.LEFT,R0
	BNE @@3
	CMPI #basic_buffer,R4
	BEQ @@2
	DECR R4
	PSHR R4
	CALL bas_output
	MVI bas_ttypos,R4
	MVI bas_color,R0
	MVO@ R0,R4
	PULR R4
	B @@2

@@3:	MVO@ R0,R4
	PSHR R4
	CALL bas_output
	PULR R4
	B @@2

@@1:	CLRR R0
	MVO@ R0,R4
	MVII #BAS_CR,R0
	CALL bas_output
	MVII #BAS_LF,R0
	CALL bas_output
	MVII #basic_buffer,R4
	PULR PC
	ENDP

	;
	; Search for a line number.
	; Input:
	;   R0 = Line number.
	; Output:
	;   R4 = Pointer to the first word of the line.
	;
line_search:	PROC
	MVII #program_start,R4
	CMP program_end,R4	; Empty program?
	BEQ @@1			; Yes, exit (for insertion).
@@0:	MVI@ R4,R1
	CMPR R1,R0	; Compare the line number.
	BEQ @@3		; Found the line number? Yes, jump.
	BNC @@3		; Found a higher line number? Yes, jump (for insertion).
	ADD@ R4,R4	; Jump over the tokens.
	CMP program_end,R4
	BNE @@0
@@1:	CLRR R1		; So it is non-equal (for insertion).
@@2:	MOVR R5,PC

@@3:	DECR R4
	MOVR R5,PC
	ENDP

	;
	; Delete a line.
	; R4 = Pointer to first word of the line.
	;
line_delete:	PROC
	PSHR R5
	INCR R4
	MVI@ R4,R5	; Get the tokenized length.
	ADDR R4,R5	; Now R5 is pointer to the next line.
	DECR R4
	DECR R4		; R4 is pointer to the line for deletion.
	MOVR R5,R2
	SUBR R4,R2	; Number of words to delete.
	MVI program_end,R3
	INCR R3
	SUBR R5,R3	; Number of words to move.
	MVI program_end,R1
	SUBR R2,R1	; Move end pointer.
	MVO R1,program_end
@@1:	MVI@ R5,R0
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
line_insert:	PROC
	PSHR R5
	MVI program_end,R5
	MOVR R4,R0
	MOVR R5,R4	; Copy source pointer to target pointer.
	ADDR R3,R4
	ADDI #2,R4	; Account for line and length words.
	MVO R4,program_end
	PSHR R1
	MOVR R5,R1
	SUBR R0,R1
	INCR R1
	PSHR R0
@@1:	MVI@ R5,R0
	DECR R5
	DECR R5
	MVO@ R0,R4
	DECR R4
	DECR R4
	DECR R1
	BNE @@1
	PULR R4
	PULR R1
	MVO@ R1,R4	; Write the line number.
	MVO@ R3,R4	; Write the tokenized length.
	MOVR R2,R5
@@2:	MVI@ R5,R0
	MVO@ R0,R4
	DECR R3
	BNE @@2
	PULR PC
	ENDP

	;
	; Get next character or token.
	;
get_next:	PROC
	MVI@ R4,R0
	CMPI #$20,R0
	BEQ get_next
	MOVR R5,PC
	ENDP

	;
	; Emit a BASIC error
	;
bas_error:	PROC
	MVII #errors,R4
	TSTR R0
	BEQ @@2
@@1:	MVI@ R4,R1
	TSTR R1
	BNE @@1
	DECR R0
	BNE @@1
@@2:
	MVI@ R4,R0
	TSTR R0
	BEQ @@3
	PSHR R4
	CALL bas_output
	PULR R4
	B @@2

@@3:
	MVI bas_curline,R0
	TSTR R0
	BEQ @@4
	MVII #at_line,R4
@@5:
	MVI@ R4,R0
	TSTR R0
	BEQ @@6
	PSHR R4
	CALL bas_output
	PULR R4
	B @@5
@@6:
	MVI bas_curline,R0
	CALL PRNUM16.l
@@4:
	MVII #BAS_CR,R0
	CALL bas_output
	MVII #BAS_LF,R0
	CALL bas_output
	B basic_restart
	ENDP

bas_read_card:	PROC
	MVI@ R4,R0
	ANDI #$0FF8,R0
	SLR R0,2
	SLR R0,1
	MOVR R5,PC
	ENDP

	;
	; Tokenize a BASIC line
	; R4 = Pointer to first character in the screen.
	;
bas_tokenize:	PROC
	PSHR R5
	CLRR R3
	MVO R3,basic_buffer	; Line zero
	INCR R3
	MVO R3,basic_buffer+1	; Tokenized length
	CLRR R3
	MVO R3,basic_buffer+2	; Mark end of tokenized line.

	MVII #basic_buffer,R3
	CLRR R2			; Line number.
@@1:	CMP bas_ttypos,R4	; Reached the cursor.
	BEQ @@0
	CALL bas_read_card
	TSTR R0			; Space character?
	BEQ @@1
@@2:
	CMPI #$10,R0
	BNC @@3
	CMPI #$1A,R0
	BC @@3
	SUBI #$10,R0
	MOVR R2,R1
	ADDR R2,R2		; x2
	ADDR R2,R2		; x4
	ADDR R1,R2		; x5
	ADDR R2,R2		; x10
	ADDR R0,R2
	CMP bas_ttypos,R4
	BEQ @@3
	CALL bas_read_card
	B @@2

@@3:	MVO@ R2,R3		; Take note of the line number
	INCR R3
	INCR R3			; Avoid the tokenized length.
	TSTR R0			; Space character?
	BNE @@4
@@6:
	CMP bas_ttypos,R4
	BEQ @@5
	CALL bas_read_card
	TSTR R0
	BEQ @@6
	; Start tokenizing
@@4:	CMPI #$02,R0		; Quotes?
	BNE @@14
@@15:	ADDI #$20,R0
	MVO@ R0,R3		; Pass along string.
	INCR R3
	CMP bas_ttypos,R4
	BEQ @@5
	CALL bas_read_card
	CMPI #$02,R0
	BNE @@15
	ADDI #$20,R0
	MVO@ R0,R3
	INCR R3
	B @@6

@@14:	DECR R4
	MVII #keywords,R2
	MVII #TOKEN_START,R5
@@8:	PSHR R4
	;
	; Compare input against possible token.
	;
@@11:	MVI@ R4,R0
	ANDI #$0FF8,R0
	SLR R0,2
	SLR R0,1
	CMPI #$41,R0	; Convert lowercase to uppercase.
	BLT @@9
	CMPI #$5B,R0
	BGE @@9
	SUBI #$20,R0
@@9:	ADDI #$20,R0	; Now it is ASCII value.
	CMP@ R2,R0
	BNE @@10
	INCR R2
	MVI@ R2,R0
	TSTR R0		; End of token?
	BNE @@11
	MVO@ R5,R3	; Write token.
	INCR R3
	PULR R5		; Ignore restart position.
	B @@16

@@10:	MVI@ R2,R0
	INCR R2
	TSTR R0
	BNE @@10
	INCR R5		; Next token
	PULR R4		; Restart input position.
	MVI@ R2,R0
	TSTR R0
	BNE @@8
	; No token found	
@@7:	CALL bas_read_card
	ADDI #$20,R0
	CMPI #$61,R0
	BNC @@18
	CMPI #$7B,R0
	BC @@18
	SUBI #$20,R0
@@18:
	MVO@ R0,R3
	INCR R3
@@16:
	CMP bas_ttypos,R4
	BEQ @@5
	CALL bas_read_card
	B @@4

	; End of tokenized line
	; Remove trailing spaces.
@@5:	CMPI #basic_buffer+2,R3
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
	SUBI #basic_buffer+2,R3
	MVO R3,basic_buffer+1	; Take note of the length

@@0:	PULR PC	
	ENDP

	;
	; Execute a BASIC line
	; r4 = Pointer to start of line.
	;
bas_execute_line:	PROC
	PSHR R5
	MVI@ R4,R0
	MVO R0,bas_curline
	INCR R4
@@2:	MVI@ R4,R0
	TSTR R0
	BEQ @@1
	DECR R4
	CALL bas_execute
	CALL get_next
	TSTR R0
	BEQ @@1
	CMPI #TOKEN_COLON,R0
	BEQ @@2
	MVII #ERR_SYNTAX,R0
	CALL bas_error
@@1:	PULR PC
	ENDP

	;
	; Execute a BASIC statement
	;
bas_execute:	PROC
	PSHR R5
	MVI@ R4,R0
	CMPI #TOKEN_START,R0	; Token found?
	BC @@2
	; Try an assignment
	CMPI #$41,R0
	BNC @@1
	CMPI #$5B,R0
	BC @@1
	SUBI #$41,R0
	SLL R0,2
	MVII #variables,R5
	ADDR R0,R5
	PSHR R5
	CALL get_next
	CMPI #TOKEN_EQ,R0
	BNE @@1
	CALL bas_expr
	PULR R5
	MVO@ R2,R5
	MVO@ R3,R5
	PULR PC
	
@@1:
	MVII #ERR_SYNTAX,R0
	CALL bas_error

@@2:	SUBI #TOKEN_START,R0
	MVII #keywords_exec,R3
	ADDR R0,R3
	PULR R5
	MVI@ R3,PC
	ENDP

	;
	; Get the next token, avoids spaces
	;
next_token:	PROC
@@1:
	MVI@ R4,R0
	CMPI #32,R0
	BEQ @@1
	MOVR R5,PC
	ENDP

	;
	; List the program
	;
bas_list:	PROC
	PSHR R5
	PSHR R4
	MVII #program_start,R4
@@1:	MVI@ R4,R0
	TSTR R0		; End of the program?
	BEQ @@2		; Yes, jump.
	PSHR R4
	CALL PRNUM16.l
	MVII #$20,R0	; Space.
	CALL bas_output
	PULR R4
	MVI@ R4,R1	; Tokenized length.
@@4:
	MVI@ R4,R0
	TSTR R0
	BEQ @@3
	CMPI #TOKEN_START,R0
	BC @@5
	PSHR R4
	CALL bas_output
	PULR R4
	B @@4

	; Token
@@5:	MVII #keywords,R5
	SUBI #TOKEN_START,R0
	BEQ @@6
@@7:	MVI@ R5,R1
	TSTR R1
	BNE @@7
	DECR R0
	BNE @@7
@@6:	PSHR R4
@@8:	MVI@ R5,R0
	TSTR R0
	BEQ @@9
	PSHR R5
	CALL bas_output
	PULR R5
	B @@8

@@9:	PULR R4
	B @@4

@@3:	PSHR R4
	MVII #BAS_CR,R0
	CALL bas_output
	MVII #BAS_LF,R0
	CALL bas_output
	PULR R4
	B @@1

@@2:	PULR R4
	PULR PC
	ENDP

	;
	; Erase the whole program
	;
bas_new:	PROC
	PSHR R4
	MVII #program_start,R4
	MVO R4,program_end
	CLRR R0
	MVO@ R0,R4
	PULR R4
	MOVR R5,PC
	ENDP

	;
	; Clear the screen
	;
bas_cls:	PROC
	PSHR R4
	MVII #$0200,R4	; Pointer to the screen.
	MVO R4,bas_ttypos
	MVI bas_color,R0
	MVII #$00F0/2,R1
@@1:	MVO@ R0,R4	; Erase the screen.
	MVO@ R0,R4
	DECR R1
	BNE @@1
	PULR R4
	MOVR R5,PC
	ENDP
	
	;
	; Run the program
	;
bas_run:	PROC
	MVII #STACK,R6
	MVII #program_start,R4
@@1:
	MVI@ R4,R0
	DECR R4
	TSTR R0
	BEQ basic_restart
	PSHR R4
	CALL bas_execute_line
	PULR R4
	INCR R4
	ADD@ R4,R4
	B @@1
	ENDP

	;
	; Stop the program
	;
bas_stop:	PROC
	MVII #ERR_STOP,R0
	CALL bas_error
	ENDP

	;
	; PRINT
	;
bas_print:	PROC
	PSHR R5
@@3:
	CALL next_token
@@5:
	TSTR R0
	BEQ @@6
	CMPI #$22,R0
	BNE @@2
@@1:
	MVI@ R4,R0
	CMPI #$22,R0
	BEQ @@3
	PSHR R4
	CALL bas_output
	PULR R4
	B @@1
	
@@2:	CMPI #$3B,R0
	BNE @@4
	CALL next_token
	TSTR R0
	BNE @@5
	PULR PC
@@6:
	DECR R4
	PSHR R4
	MVII #BAS_CR,R0
	CALL bas_output
	MVII #BAS_LF,R0
	CALL bas_output
	PULR R4
	PULR PC
@@4:
	DECR R4
	CALL bas_expr
	PSHR R4
	MOVR R2,R0
	MOVR R3,R1
	CALL fpprint
	PULR R4
	B @@3

	MVII #ERR_SYNTAX,R0
	CALL bas_error
	PULR PC
	ENDP

	;
	; INPUT
	;
bas_input:	PROC
	PSHR R5
@@3:
	CALL next_token
@@5:
	TSTR R0
	BEQ @@6
	CMPI #$22,R0
	BNE @@4
@@1:
	MVI@ R4,R0
	CMPI #$22,R0
	BEQ @@2
	PSHR R4
	CALL bas_output
	PULR R4
	B @@1
	
@@2:	CALL next_token
	CMPI #$3B,R0
	BNE @@6
	CALL next_token
@@4:
	CMPI #$41,R0
	BNC @@6
	CMPI #$5B,R0
	BC @@6
	PSHR R4
	PSHR R0
	MVII #$3F,R0
	CALL bas_output
	MVII #$20,R0
	CALL bas_output
	CALL bas_get_line
	CALL bas_expr
	PULR R0
	SUBI #$41,R0
	SLL R0,2
	MVII #variables,R5
	ADDR R0,R5
	MVO@ R2,R5
	MVO@ R3,R5
	PULR R4
	PULR PC

@@6:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	PULR PC
	ENDP

	;
	; GOTO
	;
bas_goto:	PROC
	PSHR R5
	; !!! Change for expression evaluation
	CLRR R2
	CALL next_token
@@1:	CMPI #$30,R0
	BNC @@2
	CMPI #$3A,R0
	BC @@2
	SUBI #$30,R0
	MOVR R2,R1
	ADDR R2,R2		; x2
	ADDR R2,R2		; x4
	ADDR R1,R2		; x5
	ADDR R2,R2		; x10
	ADDR R0,R2
	MVI@ R4,R0
	B @@1

@@2:	MOVR R2,R0
	CALL line_search
	CMPR R1,R0
	BEQ @@3
	MVII #ERR_LINE,R0
	CALL bas_error
@@3:
	CALL SCAN_KBD
	CMPI #KEY.ESC,R0
	BNE @@4
	MVII #ERR_STOP,R0
	CALL bas_error
@@4:
	MVII #STACK,R6
	B bas_run.1
	ENDP

	;
	; IF
	;
bas_if:	PROC
	PSHR R5
	CALL bas_expr
	ANDI #$7F,R3		; Is it zero?
	BEQ @@1			; Yes, jump.
	CALL next_token
	CMPI #TOKEN_THEN,R0
	BNE @@2
	CALL next_token
	CMPI #$30,R0
	BNC @@3
	CMPI #$3A,R0
	BC @@3
	PULR R5
	DECR R4
	B bas_goto
@@3:
	PULR R5
	DECR R4
	B bas_execute
@@2:
	CMPI #TOKEN_GOTO,R0
	BNE @@1
	PULR R5
	B bas_goto
@@1:	
	; !!! Implement ELSE
	MVI@ R4,R0
	TSTR R0
	BNE @@1
	DECR R4
	PULR PC
	ENDP

	;
	; Syntax error (reserved keyword at wrong place) 
	;
bas_syntax_error:	PROC
	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

	;
	; Expression evaluation
	;
bas_expr:	PROC
	PSHR R5
	CALL bas_expr1
	CALL next_token
	CMPI #TOKEN_LE,R0
	BNC @@1
	CMPI #TOKEN_GT+1,R0
	BC @@1
	CMPI #TOKEN_LE,R0
	BNE @@2
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BEQ @@true
	BNC @@true
	B @@false

@@2:
	CMPI #TOKEN_GE,R0
	BNE @@3
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BC @@true
	B @@false

@@3:
	CMPI #TOKEN_NE,R0
	BNE @@4
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BNE @@true
	B @@false

@@4:
	CMPI #TOKEN_EQ,R0
	BNE @@5
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BEQ @@true
	B @@false

@@5:
	CMPI #TOKEN_LT,R0
	BNE @@6
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BNC @@true
	B @@false

@@6:
	PSHR R2
	PSHR R3
	CALL bas_expr1
	PULR R1
	PULR R0
	PSHR R4
	CALL fpcomp
	PULR R4
	BEQ @@false
	BNC @@false
	B @@true

@@1:	DECR R4
	PULR PC

@@true:	CLRR R0
	MVII #$00BF,R1
	PULR PC

@@false:	CLRR R0
	CLRR R1
	PULR PC

	ENDP

bas_expr1:	PROC
	PSHR R5
	CALL bas_expr2
@@0:
	CALL next_token
	CMPI #$2b,R0
	BNE @@1
	PSHR R2
	PSHR R3
	CALL bas_expr2
	PULR R1
	PULR R0
	PSHR R4
	CALL fpadd
	MOVR R0,R2
	MOVR R1,R3
	PULR R4
	B @@0

@@1:
	CMPI #$2d,R0
	BNE @@2
	PSHR R2
	PSHR R3
	CALL bas_expr2
	PULR R1
	PULR R0
	PSHR R4
	CALL fpsub
	MOVR R0,R2
	MOVR R1,R3
	PULR R4
	B @@0

@@2:	DECR R4
	PULR PC
	ENDP

bas_expr2:	PROC
	PSHR R5
	CALL bas_expr3
@@0:
	CALL next_token
	CMPI #$2a,R0
	BNE @@1
	PSHR R2
	PSHR R3
	CALL bas_expr3
	PULR R1
	PULR R0
	PSHR R4
	CALL fpmul
	MOVR R0,R2
	MOVR R1,R3
	PULR R4
	B @@0

@@1:
	CMPI #$2f,R0
	BNE @@2
	PSHR R2
	PSHR R3
	CALL bas_expr3
	PULR R1
	PULR R0
	PSHR R4
	CALL fpdiv
	MOVR R0,R2
	MOVR R1,R3
	PULR R4
	B @@0

@@2:	DECR R4
	PULR PC
	ENDP

bas_expr3:	PROC
	PSHR R5
	CALL next_token
	CMPI #$28,R0	; Parenthesis?
	BNE @@5
	CALL bas_expr
	CALL next_token
	CMPI #$29,R0
	BNE @@2
	PULR PC
@@5:	
	CMPI #$41,R0	; A-Z?
	BNC @@1
	CMPI #$5B,R0
	BC @@1
	SUBI #$41,R0
	SLL R0,2
	MVII #variables,R5
	ADDR R0,R5
	MVI@ R5,R2
	MVI@ R5,R3
	PULR PC

@@1:	CMPI #$30,R0	; 0-9?
	BNC @@2
	CMPI #$3A,R0
	BC @@2
	CLRR R2
@@4:
	SUBI #$30,R0
	MOVR R2,R1
	ADDR R2,R2
	ADDR R2,R2
	ADDR R1,R2
	ADDR R2,R2
	ADDR R0,R2
	MVI@ R4,R0
	CMPI #$30,R0
	BNC @@3
	CMPI #$3A,R0
	BC @@3
	B @@4
@@3:
	DECR R4
	PSHR R4
	MOVR R2,R0
	CALL fpfromuint
	MOVR R0,R2
	MOVR R1,R3
	PULR R4
	PULR PC

@@2:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	PULR PC
	ENDP

	;
	; Save content under the cursor.
	;
bas_save_cursor:	PROC
	MVI bas_ttypos,R4
	MVI@ R4,R0
	MVO R0,bas_card
	MOVR R5,PC
	ENDP

	;
	; Show blinking cursor.
	;
bas_blink_cursor:	PROC
	MVI bas_card,R1
	MVI _frame,R0
	ANDI #16,R0
	BEQ @@1
	MVI bas_color,R1
	ADDI #$5F*8,R1
@@1:	MVI bas_ttypos,R4
	MVO@ R1,R4
	MOVR R5,PC
	ENDP

	;
	; Remove cursor.
	;
bas_restore_cursor:	PROC
	MVI bas_card,R1
	MVI bas_ttypos,R4
	MVO@ R1,R4
	MOVR R5,PC
	ENDP

	;
	; Output a character to the screen
	;
bas_output:	PROC
	PSHR R5
	CMPI #$20,R0
	BC @@0
	CMPI #BAS_CR,R0
	BEQ @@5
	CMPI #BAS_LF,R0
	BEQ @@3
	CMPI #KEY.LEFT,R0
	BEQ @@7
	CMPI #KEY.RIGHT,R0
	BEQ @@10
	CMPI #KEY.UP,R0
	BEQ @@12
	CMPI #KEY.DOWN,R0
	BEQ @@15
@@0:
	;
	; Normal letter
	;
	SUBI #$20,R0
	ANDI #$FF,R0	
	SLL R0,2	; Convert character to card number.
	SLL R0,1
	ADD bas_color,R0
	MVI bas_ttypos,R4
	MVO@ R0,R4	; Put on the screen.
	CMPI #$02F0,R4	; Reached the screen limit?
	BNE @@1		; No, jump.
	CALL @@scroll
	MVII #$02DC,R4
@@1:	MVO R4,bas_ttypos
	PULR PC

	;
	; Carriage return.
	;
@@5:	MVI bas_ttypos,R4
	SUBI #$0200,R4
	MVII #$01EC,R0
@@6:	ADDI #20,R0
	SUBI #20,R4
	BC @@6
	MVO R0,bas_ttypos
	PULR PC
	
	;
	; Line feed.
	;
@@3:	MVI bas_ttypos,R4
	ADDI #20,R4
	CMPI #$02F0,R4
	BNC @@4
	PSHR R4
	CALL @@scroll
	PULR R4
	SUBI #20,R4
@@4:	MVO R4,bas_ttypos
	PULR PC

	;
	; Move left.
	;
@@7:	MVI bas_ttypos,R4
	CMPI #$0200,R4
	BEQ @@8
	DECR R4
@@8:	MVO R4,bas_ttypos
	PULR PC

	;
	; Move right.
	;
@@10:	MVI bas_ttypos,R4
	CMPI #$02EF,R4
	BEQ @@11
	INCR R4
@@11:	MVO R4,bas_ttypos
	PULR PC

	;
	; Move upward.
	;
@@12:	MVI bas_ttypos,R4
	CMPI #$0214,R4
	BNC @@14
	SUBI #20,R4
@@14:	MVO R4,bas_ttypos
	PULR PC

	;
	; Move downward.
	;
@@15:	MVI bas_ttypos,R4
	CMPI #$02DC,R4
	BC @@16
	ADDI #20,R4
@@16:	MVO R4,bas_ttypos
	PULR PC

	;
	; Scroll up.
	;
@@scroll:
	PSHR R5
	MVII #$0214,R4
	MVII #$0200,R5
	MVII #$00DC/4,R2
@@2:	MVI@ R4,R0
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
	MVI bas_color,R0
	MVII #$0014/2,R2
@@9:	MVO@ R0,R5
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
KBD_DECODE  PROC
@@no_mods   DECLE   KEY.NONE, "ljgda"                       ; col 7
           DECLE   KEY.ENTER, "oute", KEY.NONE             ; col 6
           DECLE   "08642", KEY.RIGHT                      ; col 5
           DECLE   KEY.ESC, "97531"                        ; col 4
           DECLE   "piyrwq"                                ; col 3
           DECLE   ";khfs", KEY.UP                         ; col 2
           DECLE   ".mbcz", KEY.DOWN                       ; col 1
           DECLE   KEY.LEFT, ",nvx "                       ; col 0

@@shifted   DECLE   KEY.NONE, "LJGDA"                       ; col 7
           DECLE   KEY.ENTER, "OUTE", KEY.NONE             ; col 6
           DECLE   ")*-$\"\'"                               ; col 5
           DECLE   KEY.ESC, "(/+#="                        ; col 4
           DECLE   "PIYRWQ"                                ; col 3
           DECLE   ":KHFS^"                                ; col 2
           DECLE   ">MBCZ?"                                ; col 1
           DECLE   "%<NVX "                                ; col 0

@@control   DECLE   KEY.NONE, $C, $A, $7, $4, $1            ; col 7
           DECLE   KEY.ENTER, $F, $15, $14, $5, KEY.NONE   ; col 6
           DECLE   "}~_!'", KEY.RIGHT                      ; col 5
           DECLE   KEY.ESC, "{&@`~"                        ; col 4
           DECLE   $10, $9, $19, $12, $17, $11             ; col 3
           DECLE   "|", $B, $8, $6, $13, KEY.UP            ; col 2
           DECLE   "]", $D, $2, $3, $1A, KEY.DOWN          ; col 1
           DECLE   KEY.LEFT, "[", $0E, $16, $18, $20       ; col 0
           ENDP

SCAN_KBD    PROC

           ;; ------------------------------------------------------------ ;;
           ;;  Try to find CTRL and SHIFT first.                           ;;
           ;;  Shift takes priority over control.                          ;;
           ;; ------------------------------------------------------------ ;;
           MVII    #KBD_DECODE.no_mods, R3 ; neither shift nor ctrl

           ; maybe DIS here
           MVI     $F8,        R0
           ANDI    #$3F,       R0
           XORI    #$80,       R0          ; transpose scan mode
           MVO     R0,         $F8
           ; maybe EIS here

           MVII    #$7F,       R1          ; \_ drive column 7 to 0
           MVO     R1,         $FF         ; /
           MVI     $FE,        R2          ; \
           ANDI    #$40,       R2          ;  > look for a 0 in row 6
           BEQ     @@have_shift            ; /

           MVII    #$BF,       R1          ; \_ drive column 6 to 0
           MVO     R1,         $FF         ; /
           MVI     $FE,        R2          ; \
           ANDI    #$20,       R2          ;  > look for a 0 in row 5
           BNEQ    @@done_shift_ctrl       ; /

           MVII    #KBD_DECODE.control, R3
           B       @@done_shift_ctrl

@@have_shift:
           MVII    #KBD_DECODE.shifted, R3

@@done_shift_ctrl:

           ;; ------------------------------------------------------------ ;;
           ;;  Start at col 7 and work our way to col 0.                   ;;
           ;; ------------------------------------------------------------ ;;
           CLRR    R2              ; col pointer
           MVII    #$FF7F, R1

@@col:      MVO     R1,     $FF
           MVI     $FE,    R0
           XORI    #$FF,   R0
           BNEQ    @@maybe_key

@@cont_col: ADDI    #6,     R2
           SLR     R1
           CMPI    #$FF,   R1
           BNEQ    @@col

           MVII    #KEY.NONE,  R0
           B       @@none

           ;; ------------------------------------------------------------ ;;
           ;;  Looks like a key is pressed.  Let's decode it.              ;;
           ;; ------------------------------------------------------------ ;;
@@maybe_key:
           MOVR    R2,     R4
           SARC    R0,     2
           BC      @@got_key       ; row 0
           BOV     @@got_key1      ; row 1
           ADDI    #2,     R4 
           SARC    R0,     2
           BC      @@got_key       ; row 2
           BOV     @@got_key1      ; row 3
           ADDI    #2,     R4 
           SARC    R0,     2
           BC      @@got_key       ; row 4
           BNOV    @@cont_col      ; row 5
@@got_key1: INCR    R4
@@got_key:
           ADDR    R3,     R4      ; add modifier offset
           MVI@    R4,     R0

           CMPI    #KEY.NONE, R0   ; if invalid, keep scanning
           BEQ     @@cont_col

           CMP     ECS_KEY_LAST, R0
@@none:     MVO     R0,         ECS_KEY_LAST
           BNEQ    @@new
           MVII    #KEY.NONE,  R0

@@new:      ; maybe DIS here
           MVI     $F8,        R1  ; \
           ANDI    #$3F,       R1  ;  > set both I/O ports to "input"
           MVO     R1,         $F8 ; /
           ; maybe EIS here
           JR      R5
           ENDP

PRNUM16:	PROC
@@l:	PSHR R5
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

@@d:	PSHR R5
	MVII #$2F,R3
@@1:	INCR R3
	SUBR R1,R0
	BC @@1
	ADDR R1,R0
	PSHR R0
	CMPI #$30,R3
	BNE @@2
	TSTR R2
	BEQ @@3
@@2:	INCR R2
	PSHR R2
	MOVR R3,R0
	CALL bas_output
	PULR R2
@@3:	PULR R0
	PULR PC

	ENDP

_set_isr:	PROC
	MVI@ R5,R0
	MVO R0,ISRVEC
	SWAP R0
	MVO R0,ISRVEC+1
	JR R5
	ENDP

	;
	; Interruption routine
	;
_int_vector:     PROC

	MVII #1,R1
	MVO R1,_int	; Indicates interrupt happened.

	MVO R0,$20	; Enables display
;	MVO R0,$21	; Foreground/background mode
	MVI $21,R0	; Color stack mode
	MVII #$1111,R0
	MVO R0,$28
	SWAP R0
	MVO R0,$29
	SLR R0,2
	SLR R0,2
	MVO R0,$2A
	SWAP R0
	MVO R0,$2B

	BEGIN

	MVI _border_color,R0
	MVO     R0,     $2C     ; Border color
	MVI _border_mask,R0
	MVO     R0,     $32     ; Border mask
	;
	; Save collision registers for further use and clear them
	;
	MVII #$18,R4
	MVII #_col0,R5
	MVI@ R4,R0
	MVO@ R0,R5  ; _col0
	MVI@ R4,R0
	MVO@ R0,R5  ; _col1
	MVI@ R4,R0
	MVO@ R0,R5  ; _col2
	MVI@ R4,R0
	MVO@ R0,R5  ; _col3
	MVI@ R4,R0
	MVO@ R0,R5  ; _col4
	MVI@ R4,R0
	MVO@ R0,R5  ; _col5
	MVI@ R4,R0
	MVO@ R0,R5  ; _col6
	MVI@ R4,R0
	MVO@ R0,R5  ; _col7
	
	;
	; Updates sprites (MOBs)
	;
	MOVR R5,R4	; MVII #_mobs,R4
	CLRR R5		; X-coordinates
    REPEAT 8
	MVI@ R4,R0
	MVO@ R0,R5
	MVI@ R4,R0
	MVO@ R0,R5
	MVI@ R4,R0
	MVO@ R0,R5
    ENDR
	CLRR R0		; Erase collision bits (R5 = $18)
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
    if 0
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
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	DECR R0
	BNE @@vi3
	MVO R0,_gram_bitmap
@@vi1:
	MVI _gram2_bitmap,R4
	TSTR R4
	BEQ @@vii1
	MVI _gram2_target,R1
	SLL R1,2
	SLL R1,1
	ADDI #$3800,R1
	MOVR R1,R5
	MVI _gram2_total,R0
@@vii3:
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	MVI@    R4,     R1
	MVO@    R1,     R5
	SWAP    R1
	MVO@    R1,     R5
	DECR R0
	BNE @@vii3
	MVO R0,_gram2_bitmap
@@vii1:
    endi

	; Increase frame number
	MVI _frame,R0
	INCR R0
	MVO R0,_frame

	RETURN
	ENDP

	INCLUDE "fplib.asm"
	INCLUDE "fpio.asm"

	ORG $319,$319,"-RWB"
_frame:	 RMB 1   ; Current frame
_col0:      RMB 1       ; Collision status for MOB0
_col1:      RMB 1       ; Collision status for MOB1
_col2:      RMB 1       ; Collision status for MOB2
_col3:      RMB 1       ; Collision status for MOB3
_col4:      RMB 1       ; Collision status for MOB4
_col5:      RMB 1       ; Collision status for MOB5
_col6:      RMB 1       ; Collision status for MOB6
_col7:      RMB 1       ; Collision status for MOB7
bas_firstpos:	RMB 1	; First position of cursor.
bas_ttypos:	RMB 1	; Current position on screen.
bas_color:	RMB 1	; Current color.
bas_card:	RMB 1	; Card under the cursor.
bas_curline:	RMB 1	; Current line in execution (0 for direct command)
program_end:	RMB 1	; Pointer to program's end.

SCRATCH:    ORG $100,$100,"-RWBN"
	;
	; 8-bits variables
	;
ISRVEC:     RMB 2       ; Pointer to ISR vector (required by Intellivision ROM)
_int:       RMB 1       ; Signals interrupt received
_ntsc:      RMB 1       ; bit 0 = 1=NTSC, 0=PAL. Bit 1 = 1=ECS detected.
_border_color:  RMB 1   ; Border color
_border_mask:   RMB 1   ; Border mask
ECS_KEY_LAST:	RMB 1	; ECS last key pressed.
