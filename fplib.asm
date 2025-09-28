	;
	; Floating-point arithmetic routines for CP1610 processor
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Sep/17/2025.
	; Revision date: Sep/18/2025. fpsub/fpadd preliminary.
	; Revision date: Sep/19/2025. fpsub/fpadd operative. Added fpmul, fpdiv, fpfromint,
	;                             fpfromuint, fpint, fp2int, and fp2uint.
	; Revision date: Sep/20/2025. Added fpsgn, fpmulby2, fpdivby2, fpneg, fpfloor, and
	;                             fpceil. Corrrected bug in fpmul.
	; Revision date: Sep/22/2025. fpmul speed-up. Corrected bug in rounding (so now
	;                             1.0 / 3.0 * 3.0 = 1.0)
	; Revision date: Sep/24/2025. Added fprnd.
	;

	; Temporary
fptemp1:	EQU $0317
fptemp2:	EQU $0318

FPEXP_BIAS:	EQU $3F	; The base exponent for value 1.0

	;
	; Floating-point representation:
	;
	;        R0                R1
	; High-word                  Low-word
	; 54321098 76543210 54321098 76543210
	; |--------mantissa----------|Exponent
	;                           Sign (0= Positive, 1= Negative)
	; Exponent zero is the number zero.
	;
	; $0000 $003E = 0.5

	; $0000 $003F = 1.0
	; $0000 $00BF = -1.0

	;
	; Floating-point subtraction
	;
fpsub:	PROC
	XORI #$0080,R3	; Make negative the second operand
	ENDP

	;
	; Floating-point addition
	;
	; R0,R1 = First operand
	; R2,R3 = Second operand
	; Result in R0,R1
fpadd:	PROC
	PSHR R5
	MOVR R1,R4	
	ANDI #$007F,R4	; Is first operand zero?
	BNE @@1		; Jump if not.
	MOVR R2,R0	; Return R2+R3 as result.
	MOVR R3,R1
	B @@2
	
@@1:	MOVR R3,R5
	ANDI #$007F,R5	; Is second operand zero?
	BEQ @@2		; Jump if yes (returns first operand unchanged)

	SUBR R4,R5	; Exponents comparison.
	BLE @@4		; Jump if the second operand has an equal or lesser exponent.
	MOVR R0,R4	; Interchange operands.
	MOVR R2,R0
	MOVR R4,R2
	MOVR R1,R4
	MOVR R3,R1
	MOVR R4,R3
	NEGR R5		; Negate bit difference.
@@4:
	CMPI #$FFE8,R5	; Too small (25 bits off)? (second operand wouldn't cause effect)
	BLT @@2		; Return with first operand unchanged.

	PSHR R1		; Save first operand's sign and exponent.
	MOVR R1,R4
	XORR R3,R4	; XOR both signs.

	ANDI #$FF00,R1	; Remove exponents.
	ANDI #$FF00,R3

	SETC		; Restore bit one in mantissa.
	RRC R0,1
	RRC R1,1
	SETC		; Restore bit one in mantissa.
	RRC R2,1
	RRC R3,1
	TSTR R5		; Displace second operand to the right.
	BEQ @@3
@@5:
	CLRC
	RRC R2,1
	RRC R3,1
	INCR R5
	BNE @@5
	; At this point both numbers have the same exponent
@@3:	
	CLRC
	RRC R0,1	; Insert a leading zero (to detect carry)
	RRC R1,1	; Mantissa is now 26 bits.

	CLRC
	RRC R2,1	; Insert a leading zero (to detect carry)
	RRC R3,1	; Mantissa is now 26 bits.

	PULR R5
	PSHR R5
	ANDI #$007F,R5
	INCR R5		; Exponent for the number.
	INCR R5

	ANDI #$80,R4	; Is required an addition or subtraction?
	BEQ @@6		; Jump for addition.
	SUBR R3,R1
	DECR R0
	ADCR R0
	SUBR R2,R0
	BPL @@8		; Carry?
	COMR R0
	COMR R1
	ADDI #$0001,R1
	ADCR R0
	PULR R3
	XORI #$0080,R3	; Reverse sign
	PSHR R3
	B @@8

@@6:
	ADDR R3,R1	; Addition
	ADCR R0
	ADDR R2,R0
	;
	; Normalize mantissa
	;
@@8:	TSTR R0
	BNE @@11
	TSTR R1		; Is the result zero?
	BEQ @@12	; Yes, this is an special case.
@@11:
	DECR R5
	ADDR R1,R1
	RLC R0,1
	BNC @@11	; This loop manages to eliminate the top bit.
	; Rounding, so 1.0 / 3.0 * 3.0 becomes 1.0
	; >>> START
	MOVR R1,R2
	ANDI #$0080,R2
	BEQ @@14
	ADDI #$0100,R1
	ADCR R0
	BNC @@14
	CLRC		; A zero is inserted.
	RRC R0,1
	RRC R1,1
	INCR R5
@@14:
	; <<< END
	ANDI #$ff00,R1
@@9:
	CMPI #$01,R5
	BGE @@10
@@12:
	CLRR R5
	CLRR R0		; Minimum number.
	CLRR R1
	B @@7
@@10:
	CMPI #$80,R5
	BLT @@7
	MVII #$7F,R5
	MVII #$FFFF,R0	; Maximum number.
	MVII #$FF00,R1
@@7:
	PULR R3
	ANDI #$0080,R3
	ADDR R3,R1	; Add sign back.
	ADDR R5,R1	; Add exponent back.
@@2:	PULR PC
	ENDP

	;
	; Floating-point multiplication
	;
	; r0,r1 = first operand.
	; r2,r3 = second operand.
	;
fpmul:	PROC
	PSHR R5

	MOVR R1,R4	
	ANDI #$007F,R4	; Is first operand zero?
	BEQ @@1
	MOVR R3,R5
	ANDI #$007F,R5	; Is second operand zero?
	BNE @@3		; Jump over if not.
@@1:	CLRR R0
	CLRR R1
	PULR PC

	; Exponents in R4 and R5
@@3:	ADDR R5,R4
	SUBI #FPEXP_BIAS-2,R4	; Subtract exponent bias.

	MOVR R1,R5
	XORR R3,R5
	PSHR R5		; Saved XOR'ed sign bit.
	PSHR R4		; Save exponent.

	ANDI #$FF00,R1	; Remove exponent.
	ANDI #$FF00,R3	; Remove exponent.

	SETC		; Restore bit one in mantissa
	RRC R0,1
	RRC R1,1
	SETC		; Restore bit one in mantissa
	RRC R2,1
	RRC R3,1	; For the extra bit...
	RRC R2,1	; ...because a multiplication can generate
	RRC R3,1	; ...(x + y) - 1 bits or (x + y) bits.

	;
	; Multiply both mantissas
	;
	; Hacker trick here:
	; o As the mantissas are already aligned to the highest-bit,
	;   I can stop the multiplication when the first one becomes zero.
	;   So the full time for multiplication will happen only with
	;   a full-fledged fraction.
	; o This incomplete mantissa result generates exactly the same
	;   result than a full mantissa multiplication and it is faster.
	;
	MOVR R0,R4
	MOVR R1,R5
	CLRR R0		; Result
	CLRR R1

@@4:	ADDR R4,R4
	BNC @@5
	ADDR R3,R1
	ADCR R0
	ADDR R2,R0
@@5:	CLRC
	RRC R2,1
	RRC R3,1
	ADDR R5,R5
	ADCR R4
	BNE @@4
	TSTR R5
	BNE @@4

	PULR R5		; Restore exponent
	; Reuse the normalize code.
	B fpadd.11	; Normalize

	ENDP

	;
	; Floating-point division
	;
	; r0,r1 = Dividend
	; r2,r3 = Divisor
	;
fpdiv:	PROC
	PSHR R5

	MOVR R1,R4	
	ANDI #$007F,R4	; Is first operand zero?
	BEQ fpadd.2	; Return same zero.
	MOVR R3,R5
	ANDI #$007F,R5	; Is second operand zero?
	BEQ fpadd.2	; Leave first operand untouched.
			; !!! Alternative: throw a division-by-zero error.

	; Exponents in R4 and R5
	SUBR R5,R4
	ADDI #FPEXP_BIAS+1,R4	; Add exponent bias.

	MOVR R1,R5
	XORR R3,R5
	PSHR R5		; Saved XOR'ed sign bit.
	PSHR R4		; Save resulting exponent.	

	ANDI #$FF00,R1	; Remove exponent.
	ANDI #$FF00,R3	; Remove exponent.

	SETC		; Restore bit one in mantissa
	RRC R0,1
	RRC R1,1
	SETC		; Restore bit one in mantissa
	RRC R2,1
	RRC R3,1

	MOVR R0,R4
	MOVR R1,R5
	MVII #$8000,R0
	MVO R0,fptemp1
	CLRR R0
	MVO R0,fptemp2
	CLRR R1
@@2:	CMPR R2,R4
	BNC @@3
	BNE @@4
	CMPR R3,R5
	BNC @@3
@@4:
	; It is bigger than the divisor.
	SUBR R3,R5
	DECR R4
	ADCR R4
	SUBR R2,R4
	ADD fptemp1,R0
	ADD fptemp2,R1
@@3:	PSHR R0
	CLRC
	MVI fptemp1,R0
	RRC R0,1
	MVO R0,fptemp1
	MVI fptemp2,R0
	RRC R0,1
	MVO R0,fptemp2
	PULR R0
	CLRC
	RRC R2,1
	RRC R3,1
	; Again try to exit early
	TSTR R4
	BNE @@5
	TSTR R5
	BEQ @@6
@@5:
	TSTR R2
	BNE @@2
	CMPI #$40,R3
	BC @@2
@@6:
	PULR R5		; Restore exponent
	; Reuse the normalize code.
	B fpadd.11	; Normalize

	ENDP

	;
	; Floating-point comparison
	;
	; R0,R1 = Left operand
	; R2,R3 = Right operand
	;
	; Return flags for using BEQ, BNE, BC, and BNC.
	;
fpcomp:	PROC
	PSHR R5
	MOVR R1,R4
	ANDI #$00FF,R4
	XORI #$0080,R4	; So negative sign is lesser.
	MOVR R3,R5
	ANDI #$00FF,R5
	XORI #$0080,R5	; So negative sign is lesser.
	CMPR R5,R4
	BNE @@1
	SETC		; Restore bit one in mantissa
	RRC R0,1
	RRC R1,1
	SETC		; Restore bit one in mantissa
	RRC R2,1
	RRC R3,1
	CMPR R2,R0
	BNE @@1
	ANDI #$FF80,R1
	ANDI #$FF80,R3
	CMPR R3,R1
@@1:
	PULR PC
	ENDP

	;
	; Convert integer to floating-point
	;
	; Input: R0 = Signed value.
	; Output: R0,R1 = Floating-point value.
	;
fpfromint:	PROC
	PSHR R5
	TSTR R0
	BNE @@1
	CLRR R1
	B @@2

@@1:	BPL @@3
	MVII #$80,R2
	NEGR R0
	B @@4

@@3:	CLRR R2
@@4:
	SWAP R0
	MOVR R0,R1
	ANDI #$00FF,R0
	ANDI #$FF00,R1
	PSHR R2
	MVII #FPEXP_BIAS+$18,R5
	; Reuse the normalize code.
	B fpadd.11	; Normalize

@@2:	PULR PC
	ENDP

	;
	; Convert unsigned integer to floating-point
	;
	; Input: R0 = unsigned value.
	; Output: R0,R1 = Floating-point value.
	;
fpfromuint:	PROC
	PSHR R5
	TSTR R0
	BNE @@1
	CLRR R1
	B @@2

@@1:	CLRR R2
	SWAP R0
	MOVR R0,R1
	ANDI #$00FF,R0
	ANDI #$FF00,R1
	PSHR R2
	MVII #FPEXP_BIAS+$18,R5
	; Reuse the normalize code.
	B fpadd.11	; Normalize

@@2:	PULR PC
	ENDP

	;
	; Get integer part of a floating-point number
	; Round towards zero.
	;
	; R0,R1 = Floating-point value.
	;
fpint:	PROC
	PSHR R5
	MOVR R1,R5
	ANDI #$007F,R5
	CMPI #FPEXP_BIAS+$18,R5
 	BC @@2		; No fraction in this number.
	CLRR R2
	CLRR R3
	SUBI #FPEXP_BIAS,R5
	BC @@3		; Jump if there is an integer part.
	CLRR R0		; Zero.
	CLRR R1
	B @@2

@@3:	BEQ @@5		; Jump if no bits to shift.
@@4:	SETC
	RRC R2,1
	RRC R3,1
	DECR R5
	BNE @@4
@@5:	ADDI #$00FF,R3
	ANDR R2,R0
	ANDR R3,R1
@@2:	PULR PC
	ENDP

	;
	; Get integer part of a floating-point number (ceil)
	;
fpceil:	PROC
	MOVR R1,R3
	ANDI #$80,R3	; Negative number?
	BNE fpint	; Yes, do it with fpint.
	B fpfloor.0
	ENDP

	;
	; Get integer part of a floating-point number (floor)
	;
	; R0,R1 = Floating-point value.
	;
fpfloor:	PROC
	MOVR R1,R3
	ANDI #$80,R3	; Positive number?
	BEQ fpint	; Yes, do it with fpint.
@@0:
	MOVR R1,R4
	ANDI #$007F,R4
	CMPI #FPEXP_BIAS+$18,R4
 	BC @@2		; No fraction in this number.
	CMPI #FPEXP_BIAS,R4
	BC @@3		; Jump if there is an integer part.
	CLRR R0		; 
	MVII #$003F,R1	; 1.0
	ADDR R3,R1	; Add sign.
	B @@2

@@3:	PSHR R5
	PSHR R3
	MOVR R4,R5
	ANDI #$FF00,R1	; Remove exponent
	SETC		; Restore bit one in mantissa
	RRC R0,1
	RRC R1,1
	INCR R5
	MVII #$FFFF,R2	; Mask for fraction.
	MOVR R2,R3
	SUBI #FPEXP_BIAS,R4
@@4:	CLRC
	RRC R2,1
	RRC R3,1
	DECR R4
	BPL @@4
@@5: 	ANDI #$FF80,R3
	ADDR R3,R1	; Add fraction rounding.
	ADCR R0
	BNC @@6
	RRC R0,1
	RRC R1,1
	CLRC
	RRC R2,1
	RRC R3,1
	INCR R5		; Increase exponent.
@@6:	ADDR R2,R0
	BNC @@7
	RRC R0,1
	RRC R1,1
	CLRC
	RRC R2,1
	RRC R3,1
	INCR R5
@@7:
	ANDI #$FF80,R3	; Now remove fraction.
	COMR R2
	COMR R3
	ANDR R2,R0
	ANDR R3,R1
	; Reuse the normalize code.
	B fpadd.11	; Normalize

@@2:	MOVR R5,PC
	ENDP

	;
	; Convert a floating-point number to an integer.
	;
	; r0,r1 = Floating-point number
	;
	; Output: r0 = Integer.
	;
fp2int:	PROC
	PSHR R5
	MOVR R1,R5
	ANDI #$007F,R5
	SETC
	RRC R0,1
	MVII #FPEXP_BIAS+$0f,R2
	SUBR R5,R2
	BEQ @@2
	BPL @@1
	MVII #$7FFF,R0	; Too big.
	B @@2

@@1:	CMPI #$10,R2
	BNC @@4
	CLRR R0
	B @@2

@@4:	SLR R0,1
	DECR R2
	BNE @@4
@@2:	ANDI #$0080,R1
	BEQ @@3
	NEGR R0
@@3:	PULR PC
	ENDP

	;
	; Convert a floating-point number to an unsigned integer.
	;
	; r0,r1 = Floating-point number
	;
	; Output: r0 = Integer.
	;
fp2uint:	PROC
	PSHR R5
	MOVR R1,R5
	ANDI #$007F,R5
	SETC
	RRC R0,1
	MVII #FPEXP_BIAS+$0f,R2
	SUBR R5,R2
	BEQ @@2
	BPL @@1
	MVII #$7FFF,R0	; Too big.
	B @@2

@@1:	CMPI #$10,R2
	BNC @@4
	CLRR R0
	B @@2

@@4:	SLR R0,1
	DECR R2
	BNE @@4
@@2:	PULR PC
	ENDP

	;
	; Gets the absolute value of a floating-point number
	;
	; r0,r1 = Floating-point number
	;
fpabs:	PROC
	ANDI #$007F,R1
	MOVR R5,PC
	ENDP

	;
	; Negates a floating-point number
	;
	; r0,r1 = Floating-point number
	;
fpneg:	PROC
	XORI #$80,R1
	MOVR R5,PC
	ENDP

	;
	; Gets the sign of a floating-point number
	;
	; r0,r1 = Floating-point number.
	;
fpsgn:	PROC
	CLRR R0
	MOVR R1,R2
	ANDI #$007F,R2
	BNE @@1
	CLRR R1		; 0.0
	MOVR R5,PC
@@1:
	CLRR R0
	ANDI #$0080,R1
	BNE @@2
	MVII #$003F,R1	; 1.0
	MOVR R5,PC

@@2:	MVII #$00BF,R1	; -1.0
	MOVR R5,PC	
	ENDP

	;
	; Divide a number by 2 (moving the exponent)
	;
fpdivby2:	PROC
	DECR R1
	MOVR R1,R2
	ANDI #$7F,R2
	BNE @@1
	CLRR R0
	CLRR R1
@@1:
	MOVR R5,PC
	ENDP

	;
	; Multiply a number by 2 (moving the exponent)
	;
fpmulby2:	PROC
	MOVR R1,R2
	ANDI #$7F,R2
	CMPI #$7F,R2
	BNE @@1
	MVII #$FFFF,R0
	ANDI #$0080,R1
	ADDI #$FF7E,R1
@@1:	INCR R1
	MOVR R5,PC
	ENDP

	;
	; Generate a random number
	; From my game Mecha Eight.
	;
fprnd:	PROC
	PSHR R5
	MVI lfsr,r0
	TSTR R0
	BNE @@1
	MVII #$7811,R0
@@1:	MOVR R0,R2
	ANDI #$8000,R2
	MOVR R0,R1
	ANDI #$0020,R1
	BEQ @@3
	XORI #$8000,R2
@@3:	MOVR R0,R1
	ANDI #$0100,R1
	BEQ @@4
	XORI #$8000,R2
@@4:	MOVR R0,R1
	ANDI #$0004,R1
	BEQ @@5
	XORI #$8000,R2
@@5:	RLC R2,1
	RRC R0,1
	MVO R0,lfsr
	CLRR R1
	PSHR R1
	MVII #$3F,R5
	; Reuse the normalize code.
	B fpadd.11	; Normalize
	ENDP
