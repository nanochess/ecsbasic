	;
	; Floating-point string routines
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Sep/23/2025.
	; Revision date: Sep/24/2025. Now it handles zero.
	; Revision date: Oct/03/2025. Output function can be changed (for STR$)
	; Revision date: Oct/06/2025. Added a floating-point parse function.
	; Revision date: Oct/13/2025. Optimized number parsing.
	; Revision date: Oct/15/2025. Again optimized number parsing.
	; Revision date: Oct/16/2025. Speed up of number parsing using 16-bit routine
	;                             for the first 4 digits.
	;

	;
	; Print a floating-point number.
	;
fpprint:	PROC
	PSHR R5
	MOVR R1,R2
	ANDI #$7F,R2	; Special case: Is it zero?
	BNE @@14
	MVII #$20,R0
	CALL indirect_output
	MVII #$30,R0
	CALL indirect_output
	PULR PC
@@14:
	MOVR R1,R2
	MVII #$20,R3
	ANDI #$80,R2
	BEQ @@7
	ANDI #$FF7F,R1	; Make it positive
	MVII #$2D,R3
@@7:	PSHR R0
	PSHR R1
	MOVR R3,R0
	CALL indirect_output
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
	CALL indirect_output
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
	CALL indirect_output
	MVII #$2D,R0
	CALL indirect_output
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
	CALL indirect_output
	MVII #$2b,R0
	CALL indirect_output
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
	CALL indirect_output
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
	CALL indirect_output
	PULR R4
	PULR R3
	PULR R2
	PULR R1
	PULR R0
@@d3:	PULR PC

	ENDP

	;
	; Parse a floating-point number.
	;
fpparse:	PROC
	PSHR R5
	CMPI #$2D,R0	; Negative number?
	BNE @@17	; No, jump.
	MVII #$0080,R0	; Yes, signal it.
	B @@18

@@17:	DECR R4
	CLRR R0	
@@18:	PSHR R0		; Negative number status.

	CLRR R2		; 32-bit integer, but only 24 bits used.
	CLRR R3
	MVII #$FFFF,R5	; Period position (-1 for none).
	CLRR R1		; Number of processed digits.
@@1:
	MVI@ R4,R0	; Read input.
	SUBI #$30,R0
	BNC @@16
	CMPI #$0A,R0
	BNC @@3
	CMPI #$15,R0	; E
	BEQ @@4
	CMPI #$35,R0	; e
	BEQ @@4
@@16:	CMPI #$FFFE,R0	; Period?
	BNE @@2		; No, jump.
	TSTR R5		; Already found a period?
	BPL @@2		; Yes, jump.
	MOVR R1,R5	; Save period position.
	B @@1
@@3:
	INCR R1
	CMPI #8,R1	; Ignore more than 7 digits.
	BC @@1
	MVO R3,fptemp2
	CMPI #5,R1
	BNC @@21
	MVO R2,fptemp1
	SLLC R3,2	; x4
	RLC R2,2
	ADD fptemp2,R3
	ADCR R2
	ADD fptemp1,R2	; x5
	SLLC R3,1
	RLC R2,1	; x10
	ADDR R0,R3	; + digit
	ADCR R2
	B @@1

@@21:	
	SLL R3,2
	ADD fptemp2,R3
	SLL R3,1
	ADDR R0,R3
	B @@1

	;
	; Exponent handling.
	;
@@4:	MVI@ R4,R0
	CMPI #$2B,R0	; +
	BEQ @@5
	CMPI #$2D,R0	; -
	BEQ @@5
	DECR R4
	MVII #$2B,R0	; +
@@5:	PSHR R1
	PSHR R0
	CLRR R1
	MVI@ R4,R0
	CMPI #$30,R0
	BNC @@6
	CMPI #$3A,R0
	BC @@6
	SUBI #$30,R0
	MOVR R0,R1
	MVI@ R4,R0
	CMPI #$30,R0
	BNC @@6
	CMPI #$3A,R0
	BC @@6
	DECR R4
	MOVR R1,R0
	SLL R1,2	; x4
	ADDR R0,R1	; x5
	SLL R1,1	; x10
	ADD@ R4,R1
	SUBI #$30,R1
	INCR R4
@@6:	DECR R4
	PULR R0
	CMPI #$2B,R0
	BEQ @@7
	NEGR R1
@@7:	MOVR R1,R0
	PULR R1
	B @@8

	;
	; Parsing ended.
	;
@@2:	DECR R4
	CLRR R0		; No exponent offset.
@@8:	PSHR R0		; Exponent offset.
	PSHR R1		; Digits processed.
	PSHR R5		; Period position.
	MOVR R2,R0
	MOVR R3,R1
	CALL fpfromuint24
	PULR R5		; Period position.
	PULR R3		; Digits processed.
	PULR R2		; Exponent offset.
	TSTR R5		; Any fraction?
	BMI @@11	; No, jump.
	CMPI #7,R5	; Fraction point inside the number?
	BNC @@10	; Yes, jump.
	SUBI #7,R5	; Only add extra integer digits to the exponent offset.
	ADDR R5,R2
	B @@9

@@10:	CMPI #7,R3	; Processed more than 7 digits?
	BNC @@20	; No, jump.
	MVII #7,R3	; Yes, limit to the 7 digits available.
@@20:	SUBR R5,R3	; Subtract the period position.
	SUBR R3,R2	; Adjust exponent offset.
	B @@9

@@11:	SUBI #7,R3	; Processed more than 7 digits?
	BNC @@9		; No, jump and use as it is.
	ADDR R3,R2	; Adjust exponent offset.
	; Final exponent here.
@@9:	TSTR R2
	BEQ @@12
	PSHR R4
	; It should use a table to avoid precision loss.
	BPL @@14
@@15:
	PSHR R2
	MVII #$4000,R2	; 10.0
	MVII #$0042,R3
	CALL fpdiv
	PULR R2
	INCR R2
	BNE @@15
	PULR R4
	B @@12

@@14:
	PSHR R2
	MVII #$4000,R2	; 10.0
	MVII #$0042,R3
	CALL fpmul
	PULR R2
	DECR R2
	BNE @@14
	PULR R4
@@12:	PULR R2
	XORR R2,R1
	PULR PC

	ENDP
