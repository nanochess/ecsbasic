	;
	; Floating-point string routines
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Sep/23/2025.
	;

	;
	; Print a floating-point number.
	;
fpprint:	PROC
	PSHR R5
	MOVR R1,R2
	MVII #$20,R3
	ANDI #$80,R2
	BEQ @@7
	ANDI #$FF7F,R1	; Make it positive
	MVII #$2D,R3
@@7:	PSHR R0
	PSHR R1
	MOVR R3,R0
	CALL bas_output
	PULR R1
	PULR R0
	PSHR R0
	PSHR R1
	MVII #$312D,R2	; Biggest integer in 24-bit
	MVII #$0056,R3	; 10,000,000
	CALL fpcomp
	BC @@1
	PULR R1
	PULR R0
	PSHR R0
	PSHR R1
	MVII #$47AE,R2
	MVII #$1438,R3	; 0.01
	CALL fpcomp
	BNC @@2
	PULR R1
	PULR R0
	PSHR R0
	PSHR R1		; Save original number.
	CALL fpint
	PSHR R0
	PSHR R1		; Save integer part.
	MOVR R1,R2
	ANDI #$7F,R2
	SETC
	RRC R0,1
	RRC R1,1
	MVII #$5E,R3
	SUBR R2,R3
	BEQ @@5
@@6:	CLRC
	RRC R0,1
	RRC R1,1
	DECR R3
	BNE @@6
@@5:	CLRR R4
	MVII #$000F,R2
	MVII #$4240,R3	; 1,000,000
	CALL @@digit
	MVII #$0001,R2
	MVII #$86a0,R3	; 100,000
	CALL @@digit
	CLRR R2
	MVII #$2710,R3	; 10,000
	CALL @@digit
	MVII #$03e8,R3	; 1,000
	CALL @@digit
	MVII #$0064,R3	; 100
	CALL @@digit
	MVII #$000a,R3	; 10
	CALL @@digit
	INCR R4
	MVII #$0001,R3	; 1
	CALL @@digit
	PULR R3
	PULR R2
	PULR R1
	PULR R0
	CALL fpsub	; Subtract integer part from original number
	MOVR R1,R2
	ANDI #$7F,R2
	BEQ @@0		; Jump if no fraction.
	SETC
	RRC R0,1
	RRC R1,1
	CMPI #$3e,R2
	BEQ @@3
@@4:
	CLRC
	RRC R0,1
	RRC R1,1
	INCR R2
	CMPI #$3e,R2
	BNE @@4
@@3:
	SWAP R0
	ANDI #$00FF,R0
	MOVR R0,R1
	ADDR R0,R0	; x2
	ADDR R0,R0	; x4
	ADDR R1,R0	; x5
	MOVR R0,R1
	ADDR R0,R0	; x10
	ADDR R0,R0	; x20
	ADDR R1,R0	; x25
	ADDR R0,R0	; x50
	ADDR R0,R0	; x100

	ADDI #$80,R0	; Rounding.
	SWAP R0
	ANDI #$FF,R0	; /256.
	BEQ @@0
	CMPI #100,R0	; Cannot round to 100, go back to 99.
	BNE @@8
	DECR R0
@@8:
	PSHR R0
	MVII #$2E,R0
	CALL bas_output
	PULR R1
	CLRR R0
	CLRR R2
	MVII #$000a,R3	; 10
	MOVR R3,R4
	CALL @@digit
	MVII #$0001,R3	; 1
	CALL @@digit
	PULR PC

	; Lesser than 0.01
@@2:
	PULR R1
	PULR R0
	MVII #-6,R4
	PSHR R4
	PSHR R0
	PSHR R1
@@9:
	PULR R1
	PULR R0
	PULR R4
	INCR R4		; Exponent
	PSHR R4
	MVII #$4000,R2
	MVII #$0042,R3	; 10.0
	CALL fpmul
	PSHR R0
	PSHR R1
	MVII #$E848,R2
	MVII #$0052,R3	; 1,000,000
	CALL fpcomp
	BNC @@9	
	PULR R1
	PULR R0
	CALL @@exponent
	MVII #$45,R0
	CALL bas_output
	MVII #$2D,R0
	CALL bas_output
	PULR R0
	CALL PRNUM16.l
	PULR PC

	; Bigger than 10,000,000
@@1:
	PULR R1
	PULR R0
	MVII #6,R4
	PSHR R4
	PSHR R0
	PSHR R1
@@10:
	PULR R1
	PULR R0
	PULR R4
	INCR R4		; Exponent
	PSHR R4
	MVII #$4000,R2
	MVII #$0042,R3	; 10.0
	CALL fpdiv
	PSHR R0
	PSHR R1
	MVII #$312D,R2
	MVII #$0056,R3	; 10,000,000
	CALL fpcomp
	BC @@10
	PULR R1
	PULR R0
	CALL @@exponent
	MVII #$45,R0
	CALL bas_output
	MVII #$2b,R0
	CALL bas_output
	PULR R0
	CALL PRNUM16.l
@@0:
	PULR PC

@@exponent:
	PSHR R5
	CALL fpint
	MOVR R1,R2
	ANDI #$7F,R2
	SETC
	RRC R0,1
	RRC R1,1
	MVII #$5E,R3
	SUBR R2,R3
	BEQ @@11
@@12:	CLRC
	RRC R0,1
	RRC R1,1
	DECR R3
	BNE @@12
@@11:	
	MVII #$000F,R2
	MVII #$4240,R3	; 1,000,000
	MOVR R2,R4
	CALL @@digit
	PSHR R0
	PSHR R1
	MVII #$2E,R0
	CALL bas_output
	PULR R1
	PULR R0
	MVII #$0001,R2
	MOVR R2,R4
	MVII #$86a0,R3	; 100,000
	CALL @@digit
	CLRR R2
	MVII #$2710,R3	; 10,000
	CALL @@digit
	MVII #$03e8,R3	; 1,000
	CALL @@digit
	MVII #$0064,R3	; 100
	CALL @@digit
	MVII #$000a,R3	; 10
	CALL @@digit
	MVII #$0001,R3	; 1
	CALL @@digit
	PULR PC

@@digit:
	PSHR R5
	MVII #$2F,R5
@@d1:	INCR R5
	SUBR R3,R1
	DECR R0
	ADCR R0
	SUBR R2,R0
	BPL @@d1
	ADDR R3,R1
	ADCR R0
	ADDR R2,R0
	CMPI #$30,R5
	BNE @@d2
	TSTR R4
	BEQ @@d3
@@d2:	INCR R4
	PSHR R0
	PSHR R1
	PSHR R2
	PSHR R3
	PSHR R4
	MOVR R5,R0
	CALL bas_output
	PULR R4
	PULR R3
	PULR R2
	PULR R1
	PULR R0
@@d3:	PULR PC
	ENDP
