                ;
                ; ECS Extended BASIC interpreter for Intellivision
                ;
                ; UART routines.
                ;
                ; by Oscar Toledo G.
                ; https://nanochess.org/
                ;
                ; Creation date: Oct/08/2025.
                ; Revision date: Oct/10/2025. Added UART delays _after_ _every_ UART access.
                ;

                ;
                ; These routines are coded with information from intvnut, Lathe26 and decle.
                ;
                ; Original sparse ECS hardware information:
                ;   http://spatula-city.org/~im14u2c/intv/tech/ecs.html
                ;
                ; UART registers and bits:
                ;   https://forums.atariage.com/topic/289278-inty-ecs-gps/
                ;
                ; Tape routines:
                ;   https://forums.atariage.com/topic/310486-ecs-text-editor-written-in-intybasic-with-tape-support/
                ;
                ; Aquarius printer with ECS:
                ;   https://forums.atariage.com/topic/323929-aquarius-printer-technical-info-and-reverse-engineering/
                ;

CAS_HEADER_BYTE: equ $aa
CAS_HEADER_COUNT: equ 8
CAS_TIMEOUT:    equ 20*60
                ;
                ; Init routines for cassette.
                ;
cassette_init:  PROC
                PSHR R5
                MVII #$03,R0            ; Reset UART.
                MVO R0,$00E0
                CALL uart_delay
                MVII #10,R1
@@1:            CALL wait_frame
                DECR R1
                BNE @@1
                PULR PC
                ENDP

                ;
                ; Reset UART to play from cassette.
                ; Order is important for jzintv emulator.
                ;
cassette_play:  PROC
                PSHR R5
                MVII #$1D,R0            ; Start cassette motor. 300 baud, mode RX, TAPE port.
                MVO R0,$00E2
                CALL uart_delay
                MVII #$1D,R0            ; 8 bit, odd parity, 1 stop bit.
                MVO R0,$00E0
                CALL uart_delay
                PULR PC
                ENDP

                ;
                ; Reset UART to record to cassette.
                ; Order is important for jzintv emulator.
                ;
cassette_record: PROC
                PSHR R5
                MVII #$39,R0            ; Start cassette motor. 300 baud, mode TX, TAPE port.
                MVO R0,$00E2
                CALL uart_delay
                MVII #$1D,R0            ; 8 bit, odd parity, 1 stop bit.
                MVO R0,$00E0
                CALL uart_delay
                MVII #90,R1
@@0:            CALL wait_frame
                DECR R1
                BNE @@0
                PULR PC
                ENDP

cassette_stop:  PROC
                PSHR R5
                MVII #60,R1
@@0:            CALL wait_frame
                DECR R1
                BNE @@0
                CLRR R0                 ; Stop cassette motor.
                MVO R0,$00E2            ;
                CALL uart_delay
                MVII #60,R1
@@1:            CALL wait_frame
                DECR R1
                BNE @@1
                CALL printer_reset
                PULR PC
                ENDP

                ;
                ; Save a file.
                ;
                ; Input:
                ;   _filename contains the filename (eight bytes).
                ;
cassette_save:  PROC
                PSHR R5
                CALL cassette_record

                MVII #8,R2
@@1:            MVII #CAS_HEADER_BYTE,R0
                CALL cassette_write
                CALL wait_frame
                CALL wait_frame
                CALL wait_frame
                CALL wait_frame
                CALL wait_frame
                CALL wait_frame
                DECR R2
                BNE @@1

                MVII #$00,R0
                CALL cassette_write

                MVII #_filename,R4
                MVII #4,R2
@@2:            MVI@ R4,R0
                CALL cassette_write
                DECR R2
                BNE @@2

                CLRR R0
                CALL cassette_write

                PULR PC
                ENDP

                ;
                ; Load a file.
                ;
                ; Input:
                ;   _filename contains the filename (eight bytes).
                ;
                ; Output:
                ;   0 = File found.
                ;   1 = Couldn't find leader.
                ;   2 = The header contains other file.
                ;
cassette_load:  PROC
                PSHR R5
                MVI _frame,R0
                ADDI #CAS_TIMEOUT,R0    ; 20 seconds for timeout
                MVO R0,_timeout

                CALL cassette_play

                CALL cassette_find_leader
                TSTR R0
                BNE @@1

                CLRR R2
@@2:            CALL cassette_read_timeout
                CMPI #1,R0
                BEQ @@1
                MVII #_filename,R4
                ADDR R2,R4
                CMP@ R4,R0
                BNE @@3
                INCR R2
                CMPI #4,R2
                BNE @@2
                CALL cassette_read_timeout
                B @@1

@@3:            MVII #2,R0

@@1:
                PULR PC
                ENDP

                ;
                ; Find the leader
                ;
cassette_find_leader: PROC
                PSHR R5
                ; Restart search for header byte.
@@1:            MVII #CAS_HEADER_COUNT,R4
@@2:            CALL cassette_read_timeout
                CMPI #1,R0
                BEQ @@0
                CMPI #CAS_HEADER_BYTE,R0
                BNE @@1
                DECR R4
                BNE @@2

@@3:            CALL cassette_read_timeout
                CMPI #1,R0
                BEQ @@0
                CMPI #CAS_HEADER_BYTE,R0
                BEQ @@3
                TSTR R0                 ; Leader ends with a zero byte.
                BNE @@1                 ; Isn't zero? Restart search.

@@0:            PULR PC
                ENDP

cassette_read_word: PROC
                PSHR R5
                CALL cassette_read
                MOVR R0,R1
                CALL cassette_read
                SWAP R0
                ADDR R1,R0
                PULR PC
                ENDP

cassette_read:  PROC
                PSHR R5
@@0:
                MVI $00E0,R0
                CALL uart_delay
                ANDI #1,R0
                BEQ @@0
                MVI $00E1,R0
                CALL uart_delay
                PULR PC
                ENDP

cassette_read_timeout: PROC
                PSHR R5
@@0:
                MVI _timeout,R1
                SUB _frame,R1
                BNC @@1
                MVI $00E0,R0
                CALL uart_delay
                ANDI #1,R0
                BEQ @@0
                MVI $00E1,R0
                CALL uart_delay
                PULR PC

@@1:            MVII #1,R0
                PULR PC

                ENDP

cassette_write_word: PROC
                PSHR R5
                CALL cassette_write
                SWAP R0
                CALL cassette_write
                SWAP R0
                PULR PC
                ENDP

cassette_write: PROC
                PSHR R5
@@0:
                MVI $00E0,R1
                CALL uart_delay
                ANDI #2,R1
                BEQ @@0
                MVO R0,$00E1
                CALL uart_delay
                PULR PC
                ENDP

                ;
                ; Wait for a video frame to happen.
                ;
wait_frame:     PROC
@@0:            MVI _int,R0
                TSTR R0
                BEQ @@0
                CLRR R0
                MVO R0,_int
                MOVR R5,PC
                ENDP

                ;
                ; Reset UART to target printer.
                ; Order is important for jzintv emulator.
                ;
printer_reset:  PROC
                PSHR R5
                ; Only to make sure jzintv actually prints (saving to file)
                ; jzintv has a bug, so it never prints to file (detected Oct/08/2025)
                ;	MVII #$03,R0	; Reset jzintv
                ;	MVO R0,$00E0
                ;	CALL uart_delay
                MVII #$23,R0            ; 1200 baud, mode TX/CTS, AUX port.
                MVO R0,$00E2
                CALL uart_delay
                MVII #$11,R0            ; 8 bits, 2 stop bits, no parity.
                MVO R0,$00E0
                CALL uart_delay
                PULR PC
                ENDP

                ;
                ; Send data to the printer.
                ;
printer_output: PROC
                CMPI #$FFFF,R0
                BNE @@4
                MVI _printer_col,R0
                MOVR R5,PC
@@4:
                PSHR R5
@@0:
                MVI $00E0,R1            ; Read UART status.
                CALL uart_delay
                ANDI #2,R1              ; TX ready?
                BEQ @@0                 ; No, jump.
                MVO R0,$00E1            ; Write data to UART
                CALL uart_delay

                CMPI #$0A,R0
                BEQ @@2
                MVI _printer_col,R1
                INCR R1
                CMPI #40,R1
                BEQ @@3
                CMPI #$0D,R0
                BNE @@1
@@3:            CLRR R1
@@1:            MVO R1,_printer_col
@@2:
                PULR PC
                ENDP

                ;
                ; UART delay.
                ;
uart_delay:     PROC
                PSHR R5
                MVII #10,R5
@@0:            DECR R5
                BNE @@0
                PULR PC
                ENDP

