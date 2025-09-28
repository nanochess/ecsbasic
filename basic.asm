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
	;

	ROMW 16
	ORG $5000

	CFGVAR "jlp" = 1	; Enable JLP RAM on real hardware.

basic_buffer:	EQU $8040
variables:	EQU $8080
program_start:	EQU $80C0
memory_limit:	EQU $9F00
start_for:	EQU memory_limit-64
end_for:	EQU memory_limit
start_gosub:	EQU memory_limit-128
end_gosub:	EQU memory_limit-64
bas_strings:	EQU memory_limit-192
TOKEN_START:	EQU $0100
TOKEN_COLON:	EQU $0100
TOKEN_GOTO:	EQU $0108
TOKEN_IF:	EQU $0109
TOKEN_THEN:	EQU $010a
TOKEN_ELSE:	EQU $010b
TOKEN_TO:	EQU $010d
TOKEN_STEP:	EQU $010e

TOKEN_DATA:	EQU $0115

TOKEN_AND:	EQU $011e
TOKEN_NOT:	EQU $011f
TOKEN_OR:	EQU $0120
TOKEN_XOR:	EQU $0121

TOKEN_LE:	EQU $0122
TOKEN_GE:	EQU $0123
TOKEN_NE:	EQU $0124
TOKEN_EQ:	EQU $0125
TOKEN_LT:	EQU $0126
TOKEN_GT:	EQU $0127

TOKEN_FUNC:	EQU $0128
TOKEN_INT:	EQU $0128
TOKEN_ABS:	EQU $0129
TOKEN_SGN:	EQU $012a
TOKEN_RND:	EQU $012b
TOKEN_STICK:	EQU $012c
TOKEN_STRIG:	EQU $012d
TOKEN_KEY:	EQU $012e
TOKEN_BK:	EQU $012f

ERR_TITLE:	EQU 0
ERR_SYNTAX:	EQU 1
ERR_STOP:	EQU 2
ERR_LINE:	EQU 3
ERR_GOSUB:	EQU 4
ERR_RETURN:	EQU 5
ERR_FOR:	EQU 6
ERR_NEXT:	EQU 7
ERR_DATA:	EQU 8
ERR_DIM:	EQU 9
ERR_MEMORY:	EQU 10
ERR_ARRAY:	EQU 11
ERR_BOUNDS:	EQU 12

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

	CLRR R0
	MVO R0,_mode
	MVII #$1111,R0
	MVO R0,_mode_color

	CALL _set_isr
	DECLE _int_vector

	CLRR R0
	MVO R0,$01fb
	MVO R0,$01fc
	MVO R0,$01fd
	MVII #$38,R0
	MVO R0,$01f8

	MVII #1,R0
	MVO R0,_border_color
	MVII #$07,R0
	MVO R0,bas_curcolor

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
	MVII #$FFFF,R0	; So it is executed.
	MVO@ R0,R4
	DECR R4
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
	DECLE bas_for		; FOR
	DECLE bas_syntax_error
	DECLE bas_syntax_error
	DECLE bas_next		; NEXT
	DECLE bas_gosub
	DECLE bas_return
	DECLE bas_rem
	DECLE bas_restore
	DECLE bas_read
	DECLE bas_data
	DECLE bas_dim
	DECLE bas_mode
	DECLE bas_color
	DECLE bas_define
	DECLE bas_sprite
	DECLE bas_wait
	DECLE bas_sound	
	DECLE bas_border

	; Operators and BASIC functions cannot be executed directly
	DECLE bas_syntax_error	; AND
	DECLE bas_syntax_error	; NOT
	DECLE bas_syntax_error	; OR
	DECLE bas_syntax_error	; XOR
	DECLE bas_syntax_error	; <=
	DECLE bas_syntax_error	; >=
	DECLE bas_syntax_error	; <>
	DECLE bas_syntax_error	; =
	DECLE bas_syntax_error	; <
	DECLE bas_syntax_error	; >
	DECLE bas_syntax_error	; INT
	DECLE bas_syntax_error	; ABS
	DECLE bas_syntax_error	; SGN
	DECLE bas_syntax_error	; RND
	DECLE bas_syntax_error	; STICK
	DECLE bas_syntax_error	; TRIG
	DECLE bas_syntax_error	; KEY
	DECLE bas_bk	; BK

keywords:
	DECLE ":",0	; $0100
	DECLE "LIST",0
	DECLE "NEW",0
	DECLE "CLS",0
	DECLE "RUN",0	; $0104
	DECLE "STOP",0
	DECLE "PRINT",0
	DECLE "INPUT",0
	DECLE "GOTO",0	; $0108
	DECLE "IF",0
	DECLE "THEN",0
	DECLE "ELSE",0
	DECLE "FOR",0	; $010C
	DECLE "TO",0
	DECLE "STEP",0
	DECLE "NEXT",0
	DECLE "GOSUB",0	; $0110
	DECLE "RETURN",0
	DECLE "REM",0
	DECLE "RESTORE",0
	DECLE "READ",0	; $0114
	DECLE "DATA",0
	DECLE "DIM",0
	DECLE "MODE",0	
	DECLE "COLOR",0	; $0118
	DECLE "DEFINE",0
	DECLE "SPRITE",0
	DECLE "WAIT",0
	DECLE "SOUND",0	; $011C
	DECLE "BORDER",0
	DECLE "AND",0	; $011e
	DECLE "NOT",0
	DECLE "OR",0
	DECLE "XOR",0
	DECLE "<=",0	; $0122
	DECLE ">=",0
	DECLE "<>",0
	DECLE "=",0
	DECLE "<",0
	DECLE ">",0
	DECLE "INT",0
	DECLE "ABS",0
	DECLE "SGN",0
	DECLE "RND",0
	DECLE "STICK",0
	DECLE "STRIG",0
	DECLE "KEY",0
	DECLE "BK",0
	DECLE 0

at_line:
	DECLE " at ",0
errors:
	DECLE "ECS extended BASIC",$0d,$0a,"by nanochess 2025",0
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
	MVI bas_curcolor,R0
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
	CMPI #$FFFF,R0
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
	SLL R2,2
	ADDR R1,R2		; x5
	ADDR R2,R2		; x10
	ADDR R0,R2
	CMP bas_ttypos,R4
	BEQ @@19
	CALL bas_read_card
	B @@2

@@19:	CLRR R0
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

@@14:	CMPI #$10,R0		; ASCII character $20-$2f?
	BNC @@20
	DECR R4
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
@@20:
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
	MVO@ R2,R3
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
@@0:
	MVI@ R4,R0
	TSTR R0
	BEQ @@3
	MVO R0,bas_curline
	INCR R4
@@2:	MVI@ R4,R0
	TSTR R0
	BEQ @@0
	DECR R4
	CALL bas_execute
	CALL get_next
	TSTR R0
	BEQ @@0
	CMPI #TOKEN_ELSE,R0
	BEQ @@1
	CMPI #TOKEN_COLON,R0
	BEQ @@2
	MVII #ERR_SYNTAX,R0
	CALL bas_error

@@1:	MVI@ R4,R0
	TSTR R0
	BNE @@1
	B @@0

@@3:	PULR PC
	ENDP

	;
	; Execute a BASIC statement
	;
bas_execute:	PROC
	PSHR R5
@@0:
	MVI@ R4,R0
	CMPI #32,R0
	BEQ @@0
	CMPI #TOKEN_START,R0	; Token found?
	BC @@2
	; Try an assignment
	CALL get_var_addr
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

@@2:	MVII #keywords_exec-TOKEN_START,R3
	ADDR R0,R3
	PULR R5
	MVI@ R3,PC
	ENDP

	;
	; List the program
	;
bas_list:	PROC
	PSHR R5
	CALL get_next	; Check for line number.
	CMPI #$30,R0
	BNC @@10
	CMPI #$3A,R0
	BC @@10
	CALL parse_integer
	MVO R0,bas_listen
	PSHR R4
	CALL line_search
	B @@11

@@10:	DECR R4
	PSHR R4
	MVII #$FFFF,R0
	MVO R0,bas_listen
	MVII #program_start,R4
@@11:	MOVR R4,R5	; Save start pointer.
	PULR R4
	PSHR R5
	CALL get_next
	CMPI #$2D,R0	; Range?
	BNE @@12	; No, jump.
	MVII #$FFFF,R0
	MVO R0,bas_listen
	CALL get_next
	CMPI #$30,R0	; Number?
	BNC @@12	; No, jump.
	CMPI #$3A,R0
	BC @@12
	CALL parse_integer
	MVO R0,bas_listen
	INCR R7

@@12:	DECR R4
	PULR R5
	PSHR R4
	MOVR R5,R4

@@1:	MVI@ R4,R0
	TSTR R0		; End of the program?
	BEQ @@2		; Yes, jump.
	CMP bas_listen,R0	; Line limit?
	BEQ @@15
	BC @@2
@@15:
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
	MVI bas_curcolor,R0
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
	MVII #start_for,R0
	MVO R0,bas_forptr
	MVII #start_gosub,R0
	MVO R0,bas_gosubptr

	MVO R0,bas_memlimit

	CALL data_locate
	MVO R0,bas_dataptr
	
	MVI program_end,R3
	INCR R3			; Jump over the final word.
	MVO R3,bas_arrays	
	CLRR R0			; No arrays.
	MVO@ R0,R3
	MVO R3,bas_last_array

	MVII #program_start,R4
@@1:
	CALL bas_execute_line
	B basic_restart
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
	CALL get_next
@@5:
	TSTR R0
	BEQ @@6
	CMPI #TOKEN_COLON,R0
	BEQ @@6
	CMPI #TOKEN_ELSE,R0
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
	CALL get_next
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
	CALL get_next
@@5:
	TSTR R0
	BEQ @@6
	CMPI #TOKEN_COLON,R0
	BEQ @@6
	CMPI #TOKEN_ELSE,R0
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
	
@@2:	CALL get_next
	CMPI #$3B,R0
	BNE @@6
	CALL get_next
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
	SLL R0,1
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
	CALL get_next
	CMPI #$30,R0
	BNC @@1
	CMPI #$3A,R0
	BC @@1
	CALL parse_integer
	CALL line_search
	CMPR R1,R0
	BEQ @@3
	MVII #ERR_LINE,R0
	CALL bas_error
@@3:
	PSHR R4
	CALL SCAN_KBD
	PULR R4
	CMPI #KEY.ESC,R0
	BNE @@4
	MVII #ERR_STOP,R0
	CALL bas_error
@@4:
	MVII #STACK,R6
	B bas_run.1

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

	;
	; IF
	;
bas_if:	PROC
	PSHR R5
	CALL bas_expr
	ANDI #$7F,R3		; Is it zero?
	BEQ @@1			; Yes, jump.
	CALL get_next
	CMPI #TOKEN_THEN,R0
	BNE @@2
	CALL get_next
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

@@1:	CLRR R5
@@6:
	PSHR R5
	CALL get_next
	PULR R5
	TSTR R0		; Reached end of line?
	BEQ @@4		; Yes, no ELSE found.
	CMPI #TOKEN_THEN,R0
	BNE @@5
	INCR R5		; Increase depth.
@@5:	CMPI #TOKEN_ELSE,R0
	BNE @@6
	DECR R5		; Decrease depth.
	BNE @@6
	PULR R5
	B bas_execute

@@4:	DECR R4
	PULR PC
	ENDP

	;
	; Get next point for execution
	;
get_next_point:	PROC
	PSHR R5
	MVI bas_curline,R1
@@2:
	MVI@ R4,R0
	TSTR R0
	BEQ @@1
	CMPI #32,R0
	BEQ @@2
	CMPI #TOKEN_COLON,R0
	BEQ @@3
	B @@4

@@1:	MVI@ R4,R1
	TSTR R1		; No more lines?
	BEQ @@4
	INCR R4
	B @@3
@@4:
	MVII #ERR_SYNTAX,R0
	CALL bas_error
@@3:
	PULR PC
	ENDP

	;
	; Get variable address
	;
get_var_addr:	PROC
	CMPI #$41,R0
	BNC @@1
	CMPI #$5B,R0
	BC @@1
@@0:
	PSHR R5
	MOVR R0,R2
	CALL get_next
	CMPI #$28,R0		; Array?
	BNE @@2			; No, jump.
	PSHR R2
	CALL bas_expr
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2uint
	PULR R2
	PSHR R0
	CALL get_next
	CMPI #$29,R0
	BNE @@1
	PSHR R4
	MVI bas_arrays,R3
@@3:	MVI@ R3,R4
	TSTR R4
	BEQ @@5
	CMP@ R3,R2
	BEQ @@4
	INCR R3
	MVI@ R3,R0
	INCR R3
	SLL R0,1	; Length x2.
	ADDR R0,R3
	B @@3

@@4:	INCR R3		; Jump over name.
	PULR R4		; Restore parsing position.
	PULR R0		; Restore desired index.
	CMP@ R3,R0
	BC @@6
	INCR R3
	SLL R0,1
	ADDR R0,R3
	MOVR R3,R5
	PULR PC

@@2:	DECR R4
	SUBI #$41,R2
	SLL R2,1
	MVII #variables,R5
	ADDR R2,R5
	PULR PC

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error

@@5:	MVII #ERR_ARRAY,R0
	CALL bas_error

@@6:	MVII #ERR_BOUNDS,R0
	CALL bas_error

	ENDP

	;
	; FOR
	;
bas_for:	PROC
	PSHR R5
	MVI bas_forptr,R5
	CMPI #end_for-5,R5
	BC @@1
	; Try an assignment
	CALL get_next
	CALL get_var_addr
	MVI bas_forptr,R3
	MVO@ R5,R3		; Take note of the variable.
	PSHR R5
	CALL get_next
	CMPI #TOKEN_EQ,R0
	BNE @@2
	CALL bas_expr
	PULR R5
	MVO@ R2,R5		; Assign initial value.
	MVO@ R3,R5
	CALL get_next
	CMPI #TOKEN_TO,R0
	BNE @@2
	MVI bas_forptr,R3
	INCR R3
	INCR R3
	MVO@ R4,R3		; Take note of TO expression
	CALL bas_expr		; Evaluate once
	CALL get_next
	MVI bas_forptr,R3
	INCR R3
	CMPI #TOKEN_STEP,R0
	BNE @@3
	MVO@ R4,R3		; Take note of STEP expression
	CALL bas_expr		; Evaluate once
	B @@4

@@3:	CLRR R2
	MVO@ R2,R3		; No STEP expression
	DECR R4
@@4:	PSHR R4
	CALL get_next_point
	MVI bas_forptr,R3
	INCR R3
	INCR R3
	INCR R3
	MVO@ R4,R3		; Parsing position
	INCR R3
	MVO@ R1,R3		; Line 
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
bas_next:	PROC
	PSHR R5
	MVI bas_forptr,R5
	CMPI #start_for,r5
	BNE @@1
@@0:
	MVII #ERR_NEXT,R0
	CALL bas_error
@@1:	CALL get_next
	CMPI #$41,R0		; Variable name?
	BNC @@2
	CMPI #$5B,R0
	BC @@2			; No, jump.
	CALL get_var_addr.0
	MVI bas_forptr,R3
@@3:	CMPI #start_for,R3
	BEQ @@0
	SUBI #5,R3
	CMP@ R3,R5		; Find in FOR stack
	BNE @@3
	B @@4

@@2:	DECR R4
	MVI bas_forptr,R3	; Use most recent FOR.
	DECR R3
	DECR R3
	DECR R3
	DECR R3
	DECR R3
@@4:	PSHR R4
	MOVR R3,R5
	MVI@ R5,R3		; Variable address.
	PSHR R3
	MVI@ R3,R0		; Read value
	INCR R3
	MVI@ R3,R1
	MVI@ R5,R4		; Read STEP value.
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
	MVII #$003F,R3		; 1.0
@@6:
	MOVR R3,R4
	ANDI #$80,R4
	MVO R4,temp1
	CALL fpadd
	PULR R5
	PULR R3
	MVO@ R0,R3		; Save new value.
	INCR R3
	MVO@ R1,R3
	MVI@ R5,R4		; Read TO value.
	PSHR R5
	PSHR R0
	PSHR R1
	CALL bas_expr
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

@@8:	PULR R5
	PULR R4		; Previous parsing position.
	MVI@ R5,R4
	MVI@ R5,R1
	MVO R1,bas_curline
	PULR R5
	B bas_execute

@@9:	PULR R5
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
bas_gosub:	PROC
	PSHR R5
	; !!! Change for expression evaluation
	CALL get_next
	CMPI #$30,R0
	BNC @@1
	CMPI #$3A,R0
	BC @@1
	CALL parse_integer
	CALL get_next_point
	MVI bas_gosubptr,R5
	CMPI #end_gosub-2,R5
	BC @@5
	MVO@ R4,R5
	MVO@ R1,R5
	MVO R5,bas_gosubptr
	MOVR R2,R0
	CALL line_search
	CMPR R1,R0
	BEQ @@3
	MVII #ERR_LINE,R0
	CALL bas_error
@@3:
	PSHR R4
	CALL SCAN_KBD
	PULR R4
	CMPI #KEY.ESC,R0
	BNE @@4
	MVII #ERR_STOP,R0
	CALL bas_error
@@4:
	MVII #STACK,R6
	B bas_run.1
	PULR PC

@@5:	MVII #ERR_GOSUB,R0
	CALL bas_error

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error

	ENDP

	;
	; RETURN
	;
bas_return:	PROC
	PSHR R5
	MVI bas_gosubptr,R5
	CMPI #start_gosub,r5
	BNE @@1
	MVII #ERR_RETURN,R0
	CALL bas_error
@@1:	DECR R5
	DECR R5
	MVO R5,bas_gosubptr
	MVI@ R5,R4
	MVI@ R5,R1
	MVO R1,bas_curline
	PULR R5
	B bas_execute
	ENDP

	;
	; REM
	;
bas_rem:	PROC
@@1:	MVI@ R4,R0
	TSTR R0
	BNE @@1
	DECR R4
	MOVR R5,PC
	ENDP

	;
	; Locate the first DATA statement in the program
	;
data_locate:	PROC
	PSHR R5
	MVII #program_start,R4
@@3:	MVI@ R4,R0
	INCR R4
	TSTR R0
	BEQ @@1
@@2:	MVI@ R4,R0
	TSTR R0
	BEQ @@3
	CMPI #TOKEN_DATA,R0
	BNE @@2
	MOVR R4,R0
	PULR PC

@@1:	CLRR R0
	PULR PC
	ENDP

	;
	; RESTORE
	;
bas_restore:	PROC
	PSHR R5
	CALL get_next
	CMPI #$30,R0
	BNC @@1
	CMPI #$3A,R0
	BC @@1
	CALL parse_integer
	PSHR R4
	CALL line_search
	CMPR R1,R0
	BNE @@5		; Jump if not found.
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
@@1:	DECR R4
	PSHR R4
	CALL data_locate
	TSTR R0
	BEQ @@6
	MOVR R0,R4
@@2:	MVO R4,bas_dataptr
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
bas_read:	PROC
	PSHR R5
@@12:
	CALL get_next
	CMPI #$41,R0		; Variable name?
	BNC @@2
	CMPI #$5B,R0
	BC @@2			; No, jump.
	CALL get_var_addr.0
	PSHR R4
	PSHR R5
	MVI bas_dataptr,R4
	TSTR R4
	BEQ @@6
@@8	MVI@ R4,R0
	TSTR R0		; End of line found?
	BEQ @@5
	CMPI #$20,R0	; Avoid spaces
	BEQ @@8
	CMPI #$2D,R0
	BEQ @@3
	CMPI #$30,R0
	BNC @@4
	CMPI #$3A,R0
	BNC @@3
	CMPI #$2E,R0
	BEQ @@3

	; Number identified.
@@3:	CALL parse_number
	PULR R5
	MVO@ R0,R5	; Save into variable
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
@@9:	DECR R4
@@10:	MVO R4,bas_dataptr
	PULR R4
	CALL get_next
	CMPI #$2C,R0
	BEQ @@12
	DECR R4
	PULR PC

@@4:
	; End of line
@@5:	MVI@ R4,R0
	TSTR R0		; End of program?
	BEQ @@6
	INCR R4
@@7:	MVI@ R4,R0
	TSTR R0
	BEQ @@5
	CMPI #TOKEN_DATA,R0
	BNE @@7
	B @@8

	PULR R5
	PULR R4

@@6:	MVII #ERR_DATA,R0
	CALL bas_error

@@2:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	PULR PC
	ENDP

	;
	; DATA
	;
	; On execution it is ignored.
	;
bas_data:	PROC
@@1:	MVI@ R4,R0
	CMPI #TOKEN_COLON,R0
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
bas_dim:	PROC
	PSHR R5
	CALL get_next
	CMPI #$41,R0	; Variable name?
	BNC @@1
	CMPI #$5B,R0
	BC @@1		; No, jump.
	PSHR R0
	CALL get_next
	CMPI #$28,R0
	BNE @@1
	CALL get_next
	CMPI #$30,R0
	BNC @@1
	CMPI #$3A,R0
	BC @@1
	CALL parse_integer
	INCR R0		; Count zero.
	PSHR R0
	CALL get_next
	CMPI #$29,R0
	BNE @@1
	PULR R1		; Length.
	PULR R2		; Name.
	;
	; Search for previous definition.
	;
	PSHR R4
	MVI bas_arrays,R3
@@5:	MVI@ R3,R4
	TSTR R4
	BEQ @@4
	CMP@ R3,R2
	BEQ @@2
	INCR R3
	MVI@ R3,R0
	INCR R3
	SLL R0,1	; Length x2.
	ADDR R0,R3
	B @@5

@@4:	MOVR R3,R0
	ADDI #3,R0
	ADDR R1,R0
	ADDR R1,R0
	CMP bas_memlimit,R0
	BC @@3
	MVO@ R2,R3
	INCR R3
	MVO@ R1,R3
	INCR R3
	SLL R1,1	; Length x2.
	ADDR R1,R3
	CLRR R1
	MVO@ R1,R3
	MVO R3,bas_last_array
	PULR R4
	PULR PC

@@3:	MVII #ERR_MEMORY,R0
	CALL bas_error

@@2: 	MVII #ERR_DIM,R0
	CALL bas_error

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error

	ENDP

	;
	; MODE
	;
bas_mode:	PROC
	PSHR R5
	CALL bas_expr_int
	CMPI #2,R0
	BC @@1
	MVO R0,_mode
	CALL get_next
	CMPI #$2C,R0
	BNE @@2
	CALL bas_expr_int
	MVO R0,_mode_color
	PULR PC

@@2:	DECR R4
	PULR PC

@@1:	MVII #ERR_BOUNDS,R0
	CALL bas_error
	ENDP

	;
	; COLOR
	;
bas_color:	PROC
	PSHR R5
	CALL bas_expr_int
	MVO R0,bas_curcolor
	PULR PC
	ENDP

	;
	; DEFINE
	;
bas_define:	PROC
	PSHR R5
	CALL bas_expr_int
	PSHR R0
	CALL get_next
	CMPI #$2C,R0
	BNE @@1
	CALL get_next
	CMPI #$22,R0
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

@@2:	CMPI #$22,R0
	BNE @@1

	MVI bas_last_array,R2
	INCR R2
	SUBR R2,R3
	SLR R3,2
	BEQ @@1
	MVO R3,_gram_total
	MVO R2,_gram_bitmap
	PULR R0
	MVO R0,_gram_target

	PULR PC

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error

@@convert_hex:
	MVI@ R4,R0
	CMPI #$61,R0
	BNC @@c1
	SUBI #$20,R0
@@c1:	CMPI #$30,R0
	BNC @@c2
	CMPI #$47,R0
	BC @@c2
	CMPI #$3A,R0
	BNC @@c3
	CMPI #$41,R0
	BNC @@c2
@@c3:	SUBI #$30,R0
	CMPI #10,R0
	BNC @@c4
	SUBI #7,R0
@@c4:
	CLRC
	MOVR R5,PC

@@c2:	SETC
	MOVR R5,PC

	ENDP

	;
	; SPRITE
	;
bas_sprite:	PROC
	PSHR R5
	CALL bas_expr_int
	CMPI #8,R0
	BC @@1
	ADDI #_mobs,R0
	PSHR R0
	CALL get_next
	CMPI #$2C,R0
	BNE @@2

	CALL get_next
	CMPI #$2C,R0
	BEQ @@4
	DECR R4
	CALL bas_expr_int
	PULR R3
	PSHR R3
	MVO@ R0,R3
	CALL get_next
	CMPI #TOKEN_COLON,R0
	BEQ @@3
	TSTR R0
	BEQ @@3
	CMPI #$2C,R0
	BNE @@2
@@4:
	CALL get_next
	CMPI #$2C,R0
	BEQ @@5
	DECR R4
	CALL bas_expr_int
	PULR R3
	PSHR R3
	ADDI #8,R3
	MVO@ R0,R3
	CALL get_next
	CMPI #TOKEN_COLON,R0
	BEQ @@3
	TSTR R0
	BEQ @@3
	CMPI #$2C,R0
	BNE @@2
@@5:
	CALL bas_expr_int
	PULR R3
	PSHR R3
	ADDI #16,R3
	MVO@ R0,R3
	INCR R7

@@3:	DECR R4
	PULR R3
	PULR PC

@@1:	MVII #ERR_BOUNDS,R0
	CALL bas_error

@@2:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

	;
	; WAIT
	;
bas_wait:	PROC
	PSHR R5
@@1:
	MVI _int,R0
	TSTR R0
	BEQ @@1
	CLRR R0
	MVO R0,_int
	PULR PC
	ENDP

	;
	; SOUND
	;
bas_sound:	PROC
	PSHR R5
	CALL bas_expr_int
	PSHR R0
	CALL get_next
	CMPI #$2C,R0
	BNE @@5
	CALL get_next
	CMPI #$2C,R0
	BEQ @@12
	DECR R4
@@12:
	PULR R1
	TSTR R1
	BEQ @@0
	DECR R1
	BEQ @@1
	DECR R1
	BEQ @@2
	DECR R1
	BEQ @@3
	DECR R1
	BEQ @@4
	MVII #ERR_BOUNDS,R0
	CALL bas_error

@@5:	MVII #ERR_SYNTAX,R0
	CALL bas_error

	; SOUND 0,freq,vol
@@0:	CMPI #$2C,R0
	BEQ @@6
	CALL bas_expr_int
	MVO R0,$01f0
	SWAP R0
	MVO R0,$01F4
	CALL get_next
	CMPI #$2C,R0
	BNE @@11
@@6:
	CALL bas_expr_int
	MVO R0,$01FB
	PULR PC

	; SOUND 1,freq,vol
@@1:	CMPI #$2C,R0
	BEQ @@7
	CALL bas_expr_int
	MVO R0,$01F1
	SWAP R0
	MVO R0,$01F5
	CALL get_next
	CMPI #$2C,R0
	BNE @@11
@@7:
	CALL bas_expr_int
	MVO R0,$01fc
	PULR PC

	; SOUND 2,freq,vol
@@2:	CMPI #$2C,R0
	BEQ @@8
	CALL bas_expr_int
	MVO R0,$01F2
	SWAP R0
	MVO R0,$01F6
	CALL get_next
	CMPI #$2C,R0
	BNE @@11
@@8:
	CALL bas_expr_int
	MVO R0,$01fd
	PULR PC

	; SOUND 3,freq,env
@@3:	CMPI #$2C,R0
	BEQ @@9
	CALL bas_expr_int
	MVO R0,$01F3
	SWAP R0
	MVO R0,$01F7
	CALL get_next
	CMPI #$2C,R0
	BNE @@11
@@9:
	CALL bas_expr_int
	MVO R0,$01fa
	PULR PC

	; SOUND 4,noise,mix
@@4:	CMPI #$2C,R0
	BEQ @@10
	CALL bas_expr_int
	MVO R0,$01F9
	CALL get_next
	CMPI #$2C,R0
	BNE @@11
@@10:
	CALL bas_expr_int
	MVO R0,$01f8
	PULR PC

@@11:	DECR R4
	PULR PC
	ENDP

	;
	; BORDER
	;
bas_border:	PROC
	PSHR R5
	CALL bas_expr_int
	CMPI #16,R0
	BC @@1
	MVO R0,_border_color
	PULR PC

@@1:	MVII #ERR_BOUNDS,R0
	CALL bas_error
	ENDP

	;
	; BK(v) = v
	;
bas_bk:	PROC
	PSHR R5
	CALL bas_expr_paren
	CALL fp2int
	CMPI #$240,R0
	BC @@1
	PSHR R0
	CALL get_next
	CMPI #TOKEN_EQ,R0
	BNE @@2
	CALL bas_expr_int
	PULR R5
	ADDI #$0200,R5
	MVO@ R0,R5
	PULR PC

@@1:	MVII #ERR_BOUNDS,R0
	CALL bas_error

@@2:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

	;
	; Syntax error (reserved keyword at wrong place) 
	;
bas_syntax_error:	PROC
	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

	;
	; Expresion evaluation and conversion to integer
	;
bas_expr_int:	PROC
	PSHR R5
	CALL bas_expr
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PULR PC
	ENDP

	;
	; Expression evaluation
	;
bas_expr:	PROC
	PSHR R5
	CALL bas_expr1
	CALL get_next
	CMPI #TOKEN_OR,R0
	BNE @@1
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PSHR R0
	CALL bas_expr1
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
	PULR PC

@@1:	DECR R4
	PULR PC
	ENDP

bas_expr1:	PROC
	PSHR R5
	CALL bas_expr2
	CALL get_next
	CMPI #TOKEN_XOR,R0
	BNE @@1
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PSHR R0
	CALL bas_expr2
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PULR R1
	XORR R1,R0
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@1:	DECR R4
	PULR PC
	ENDP

bas_expr2:	PROC
	PSHR R5
	CALL bas_expr3
	CALL get_next
	CMPI #TOKEN_AND,R0
	BNE @@1
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PSHR R0
	CALL bas_expr3
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	PULR R1
	ANDR R1,R0
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@1:	DECR R4
	PULR PC
	ENDP

bas_expr3:	PROC
	PSHR R5
	CALL bas_expr4
	CALL get_next
	CMPI #TOKEN_LE,R0
	BNC @@1
	CMPI #TOKEN_GT+1,R0
	BC @@1
	CMPI #TOKEN_LE,R0
	BNE @@2
	PSHR R2
	PSHR R3
	CALL bas_expr4
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
	CALL bas_expr4
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
	CALL bas_expr4
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
	CALL bas_expr4
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
	CALL bas_expr4
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
	CALL bas_expr4
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

@@true:	CLRR R2
	MVII #$00BF,R3
	PULR PC

@@false:	CLRR R2
	CLRR R3
	PULR PC

	ENDP

bas_expr4:	PROC
	PSHR R5
	CALL bas_expr5
@@0:
	CALL get_next
	CMPI #$2b,R0
	BNE @@1
	PSHR R2
	PSHR R3
	CALL bas_expr5
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
	CALL bas_expr5
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

bas_expr5:	PROC
	PSHR R5
	CALL bas_expr6
@@0:
	CALL get_next
	CMPI #$2a,R0
	BNE @@1
	PSHR R2
	PSHR R3
	CALL bas_expr6
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
	CALL bas_expr6
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

bas_expr6:	PROC
	PSHR R5
	CALL get_next
	CMPI #$2D,R0	; Minus?
	BNE @@1
	CALL bas_expr7
	MOVR R2,R0
	MOVR R3,R1
	CALL fpneg
	MOVR R0,R2
	MOVR R1,R3
	PULR PC
	
@@1:	CMPI #TOKEN_NOT,R0	; NOT?
	BNE @@2
	CALL bas_expr7
	MOVR R2,R0
	MOVR R3,R1
	CALL fp2int
	COMR R0
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@2:	DECR R4
	CALL bas_expr7
	PULR PC
	ENDP

bas_expr_paren:	PROC
	PSHR R5
	CALL get_next
	CMPI #$28,R0
	BNE @@1
	CALL bas_expr
	CALL get_next
	CMPI #$29,R0
	BNE @@1
	MOVR R2,R0
	MOVR R3,R1
	PULR PC

@@1:	MVII #ERR_SYNTAX,R0
	CALL bas_error
	ENDP

bas_expr7:	PROC
	PSHR R5
	CALL get_next
	
	CMPI #TOKEN_FUNC,R0
	BNC @@6
	MOVR R0,R1
	ADDI #@@0-TOKEN_FUNC,R1
	CMPI #@@0+8,R1
	BC @@6
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

@@RND:
	PSHR R4
	CALL fprnd
	PULR R4
	MOVR R0,R2
	MOVR R1,R3
	PULR PC
@@INT:
	CALL bas_expr_paren
	CALL fpint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC
@@SGN:
	CALL bas_expr_paren
	CALL fpsgn
	MOVR R0,R2
	MOVR R1,R3
	PULR PC
@@ABS:
	CALL bas_expr_paren
	CALL fpabs
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@STICK:
	CALL bas_expr_paren
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
@@7:	CLRR R0
	MVII #@@TABLE,R1
	ADDR R0,R1
	MVI@ R1,R0
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@TABLE:
	DECLE 0,9,5,8,1,0,4,0
	DECLE 13,12,0,0,16,0,0,0
	DECLE 0,10,6,7,2,0,3,0
	DECLE 14,11,0,0,15,0,0,0

@@STRIG:
	CALL bas_expr_paren
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
	PULR PC
@@KEY:
	CALL bas_expr_paren
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
	PULR PC

@@KEYS:
	DECLE $48,$81,$41,$21,$82,$42,$22,$84,$44,$24,$88,$28

	; BK(v) Read screen
@@BK:
	CALL bas_expr_paren
	CALL fp2int
	CMPI #240,R0
	BC @@3
	MOVR R0,R1
	ADDI #$0200,R1
	MVI@ R1,R0
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR PC
@@6:
	CMPI #$28,R0	; Parenthesis?
	BNE @@5
	CALL bas_expr
	CALL get_next
	CMPI #$29,R0
	BNE @@2
	PULR PC
@@5:	
	CMPI #$41,R0	; A-Z?
	BNC @@1
	CMPI #$5B,R0
	BC @@1
	CALL get_var_addr.0
	MVI@ R5,R2
	MVI@ R5,R3
	PULR PC

@@1:	CMPI #$2E,R0
	BEQ @@11
	CMPI #$30,R0	; 0-9?
	BNC @@2
	CMPI #$3A,R0
	BC @@2
@@11:
	CALL parse_number
	MOVR R0,R2
	MOVR R1,R3
	PULR PC

@@2:	MVII #ERR_SYNTAX,R0
	CALL bas_error

@@3:	MVII #ERR_BOUNDS,R0
	CALL bas_error
	ENDP

	;
	; Parse an integer.
	;
parse_integer:	PROC
	CLRR R2
@@1:
	SUBI #$30,R0
	MOVR R2,R1
	SLL R2,2	; x4
	ADDR R1,R2	; x5
	ADDR R2,R2	; x10
	ADDR R0,R2
@@2:	MVI@ R4,R0
	CMPI #$30,R0
	BNC @@3
	CMPI #$3A,R0
	BNC @@1
@@3:
	DECR R4
	MOVR R2,R0
	MOVR R5,PC
	ENDP

parse_number:	PROC
	PSHR R5
	CLRR R2
	CMPI #$2D,R0
	BNE @@1
	MVII #1,R3
	B @@2

@@1:	CLRR R3
@@4:
	SUBI #$30,R0
	MOVR R2,R1
	SLL R2,2
	ADDR R1,R2
	ADDR R2,R2
	ADDR R0,R2
@@2:	MVI@ R4,R0
	CMPI #$30,R0
	BNC @@3
	CMPI #$3A,R0
	BC @@3
	B @@4
@@3:
	DECR R4
	PSHR R4
	PSHR R3
	MOVR R2,R0
	CALL fpfromuint
	PULR R3
	TSTR R3
	BEQ @@5
	CALL fpneg
@@5:
	PULR R4
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
@@0:	MVI _int,R0
	TSTR R0
	BEQ @@0
	CLRR R0
	MVO R0,_int

	MVI bas_card,R1
	MVI _frame,R0
	ANDI #16,R0
	BEQ @@1
	MVI bas_curcolor,R1
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
	ADD bas_curcolor,R0
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
	MVI bas_curcolor,R0
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
	MVI _mode,R0
	TSTR R0
	BEQ @@1
	MVO R0,$21	; Foreground/background mode
	B @@2

@@1:	MVI $21,R0	; Color stack mode
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

	; Increase frame number
	MVI _frame,R0
	INCR R0
	MVO R0,_frame

	; Adjust random number generator
	MVI lfsr,R0
	INCR R0
	INCR R0
	INCR R0
	MVO R0,lfsr

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
_mobs:	RMB 24
bas_firstpos:	RMB 1	; First position of cursor.
bas_ttypos:	RMB 1	; Current position on screen.
bas_curcolor:	RMB 1	; Current color.
bas_card:	RMB 1	; Card under the cursor.
bas_curline:	RMB 1	; Current line in execution (0 for direct command)
bas_forptr:	RMB 1	; Stack for FOR loops.
bas_gosubptr:	RMB 1	; Stack for GOSUB/RETURN.
bas_dataptr:	RMB 1	; Pointer for DATA.
bas_arrays:	RMB 1	; Pointer to where arrays start.
bas_last_array:	RMB 1	; Pointer to end of array list.
bas_memlimit:	RMB 1	; Mmemory limit.
bas_listst:	RMB 1	; Start of LIST.
bas_listen:	RMB 1	; End of LIST.
program_end:	RMB 1	; Pointer to program's end.
lfsr:		RMB 1	; Random number
_mode_color:	RMB 1	; Colors for Color Stack mode.
_gram_bitmap:	RMB 1	; Pointer to bitmap for GRAM.

SCRATCH:    ORG $100,$100,"-RWBN"
	;
	; 8-bits variables
	;
ISRVEC:     RMB 2       ; Pointer to ISR vector (required by Intellivision ROM)
_int:       RMB 1       ; Signals interrupt received
_ntsc:      RMB 1       ; bit 0 = 1=NTSC, 0=PAL. Bit 1 = 1=ECS detected.
_mode:	RMB 1	; Video mode setup.
_border_color:  RMB 1   ; Border color
_border_mask:   RMB 1   ; Border mask
_gram_target:	RMB 1	; Target GRAM card.
_gram_total:	RMB 1	; Total of GRAM cards.
ECS_KEY_LAST:	RMB 1	; ECS last key pressed.
temp1:		RMB 1	; Temporary value.
