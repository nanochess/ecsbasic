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
                ; Revision date: Oct/05/2025. Added fpfromuint24.
                ; Revision date: Oct/12/2025. Optimized integer to floating-point conversion.
                ; Revision date: Oct/13/2025. Optimized addition and multiplication.
                ; Revision date: Oct/14/2025. Optimized division, normalization, fp2int, and fpsgn.
                ; Revision date: Oct/15/2025. Optimized integer conversion to avoid shifts.
                ; Revision date: Oct/16/2025. Added double bit shift for faster integer conversion.
                ; Revision date: Oct/19/2025. fpcomp now handles the zero cases.
                ;

                ; Temporary
fptemp1:        EQU $035e
fptemp2:        EQU $035f

FPEXP_BIAS:     EQU $3F                 ; The base exponent for value 1.0

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
fpsub:          PROC
                XORI #$0080,R3          ; Make negative the second operand
                ENDP

                ;
                ; Floating-point addition
                ;
                ; R0,R1 = First operand
                ; R2,R3 = Second operand
                ; Result in R0,R1
fpadd:          PROC
                PSHR R5
                MOVR R1,R4
                ANDI #$007F,R4          ; Is first operand zero?
                BNE @@1                 ; Jump if not.
                MOVR R2,R0              ; Return R2+R3 as result.
                MOVR R3,R1
                B @@2

@@1:            MOVR R3,R5
                ANDI #$007F,R5          ; Is second operand zero?
                BEQ @@2                 ; Jump if yes (returns first operand unchanged)

                SUBR R4,R5              ; Exponents comparison.
                BLE @@4                 ; Jump if the second operand has an equal or lesser exponent.
                MOVR R0,R4              ; Interchange operands.
                MOVR R2,R0
                MOVR R4,R2
                MOVR R1,R4
                MOVR R3,R1
                MOVR R4,R3
                NEGR R5                 ; Negate bit difference.
@@4:
                CMPI #$FFE8,R5          ; Too small (25 bits off)? (second operand wouldn't cause effect)
                BLT @@2                 ; Return with first operand unchanged.
                ; Overflow Flag = 0
                PSHR R1                 ; Save first operand's sign and exponent.
                MOVR R1,R4
                XORR R3,R4              ; XOR both signs.

                ANDI #$FF00,R1          ; Remove exponents.
                ANDI #$FF00,R3

                SETC
                RRC R0,2                ; Insert leading zero and restore bit one in mantissa.
                RRC R1,2
                SETC
                RRC R2,2                ; Insert leading zero and restore bit one in mantissa.
                RRC R3,2
                TSTR R5                 ; Displace second operand to the right.
                BEQ @@3
@@5:
                CLRC
                RRC R2,1
                RRC R3,1
                INCR R5
                BNE @@5
                ; At this point both numbers have the same exponent
@@3:
                PULR R5
                PSHR R5
                ANDI #$007F,R5
                ADDI #2,R5              ; Exponent for the number.

                ANDI #$80,R4            ; Is required an addition or subtraction?
                BEQ @@6                 ; Jump for addition.
                SUBR R3,R1              ; 32-bit subtraction.
                DECR R0
                ADCR R0
                SUBR R2,R0
                BPL @@8                 ; Carry?
                COMR R0
                COMR R1
                ADDI #$0001,R1
                ADCR R0
                PULR R3
                XORI #$0080,R3          ; Reverse sign
                PSHR R3
                B @@8

@@6:
                ADDR R3,R1              ; 32-bit addition
                ADCR R0
                ADDR R2,R0
                ;
                ; Normalize mantissa
                ;
@@8:            TSTR R0
                BNE @@11
                TSTR R1                 ; Is the result zero?
                BEQ @@12                ; Yes, this is an special case.
@@11:
                DECR R5
                ADDR R1,R1
                RLC R0,1
                BC @@15
                DECR R5
                ADDR R1,R1
                RLC R0,1
                BC @@15
                DECR R5
                ADDR R1,R1
                RLC R0,1
                BC @@15
                DECR R5
                ADDR R1,R1
                RLC R0,1
                BNC @@11                ; This loop manages to eliminate the top bit.
@@15:
                ; Rounding, so 1.0 / 3.0 * 3.0 becomes 1.0
                ; >>> START
                MOVR R1,R2
                ANDI #$0080,R2
                BEQ @@14
                ADDI #$0100,R1
                ADCR R0
                BNC @@14
                CLRC                    ; A zero is inserted.
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
                CLRR R0                 ; Minimum number.
                CLRR R1
                B @@7
@@10:
                CMPI #$80,R5
                BLT @@7
                MVII #$7F,R5
                MVII #$FFFF,R0          ; Maximum number.
                MVII #$FF00,R1
@@7:
                PULR R3
                ANDI #$0080,R3
                ADDR R3,R1              ; Add sign back.
                ADDR R5,R1              ; Add exponent back.
@@2:            PULR PC
                ENDP

                ;
                ; Floating-point multiplication
                ;
                ; r0,r1 = first operand.
                ; r2,r3 = second operand.
                ;
fpmul:          PROC
                PSHR R5

                MOVR R1,R4
                ANDI #$007F,R4          ; Is first operand zero?
                BEQ @@1
                MOVR R3,R5
                ANDI #$007F,R5          ; Is second operand zero?
                BNE @@3                 ; Jump over if not.
@@1:            CLRR R0
                CLRR R1
                PULR PC

                ; Exponents in R4 and R5
@@3:            ADDR R5,R4
                SUBI #FPEXP_BIAS-2,R4   ; Subtract exponent bias.
                ; Overflow Flag = zero.
                MOVR R1,R5
                XORR R3,R5
                PSHR R5                 ; Saved XOR'ed sign bit.
                PSHR R4                 ; Save exponent.

                ANDI #$FF00,R1          ; Remove exponent.
                ANDI #$FF00,R3          ; Remove exponent.

                SETC                    ; Restore bit one in mantissa
                RRC R0,1
                RRC R1,1
                SETC                    ; Restore bit one in mantissa
                RRC R2,2                ; ...For the extra bit because a multiplication can
                RRC R3,2                ; ...generate (x + y) - 1 bits or (x + y) bits.

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
                CLRR R0                 ; Result
                CLRR R1

@@4:            ADDR R4,R4
                BNC @@5
                ADDR R3,R1
                ADCR R0
                ADDR R2,R0
@@5:            ; CLRC		; Carry is always zero here.
                RRC R2,1
                RRC R3,1
                ADDR R5,R5
                ADCR R4
                BNE @@4
                TSTR R5
                BNE @@4

                PULR R5                 ; Restore exponent
                ; Reuse the normalize code.
                B fpadd.11              ; Normalize

                ENDP

                ;
                ; Floating-point division
                ;
                ; r0,r1 = Dividend
                ; r2,r3 = Divisor
                ;
fpdiv:          PROC
                PSHR R5

                MOVR R1,R4
                ANDI #$007F,R4          ; Is first operand zero?
                BEQ fpadd.2             ; Return same zero.
                MOVR R3,R5
                ANDI #$007F,R5          ; Is second operand zero?
                BEQ fpadd.2             ; Leave first operand untouched.
                ; !!! Alternative: throw a division-by-zero error.

                ; Exponents in R4 and R5
                SUBR R5,R4
                ADDI #FPEXP_BIAS+1,R4   ; Add exponent bias.

                MOVR R1,R5
                XORR R3,R5
                PSHR R5                 ; Saved XOR'ed sign bit.
                PSHR R4                 ; Save resulting exponent.

                ANDI #$FF00,R1          ; Remove exponent.
                ANDI #$FF00,R3          ; Remove exponent.

                SETC                    ; Restore bit one in mantissa
                RRC R0,1
                RRC R1,1
                SETC                    ; Restore bit one in mantissa
                RRC R2,1
                RRC R3,1

                ;
                ; Hack: It needs a single bit shifting, but we have
                ;       few registers. So the code is split in two parts
                ;       to avoid using temporary variables.
                ;
                MOVR R0,R4
                MOVR R1,R5
                MVII #$8000,R1
                CLRR R0

                ;
                ; First 16 bits.
                ;
@@2:            CMPR R2,R4
                BNC @@4
                BNE @@3
                CMPR R3,R5
                BNC @@4
@@3:
                ; It is bigger than the divisor.
                SUBR R3,R5
                DECR R4
                ADCR R4
                SUBR R2,R4
                ADDR R1,R0
@@4:            SLR R1,1
                BEQ @@14
                CLRC
                RRC R2,1
                RRC R3,1
                ; Again try to exit early
                TSTR R4
                BNE @@5
                TSTR R5
                BEQ @@12
@@5:
                TSTR R2
                BNE @@2
                CMPI #$40,R3
                BC @@2
@@12:           CLRR R1                 ; Build full mantissa.
                B @@6

                ;
                ; Next 9 bits.
                ;
@@14:           MVO R0,fptemp1
                MVII #$8000,R0
                ; R1 guaranteed to be zero
                B @@11

@@7:            CMPR R2,R4
                BNC @@9
                BNE @@8
                CMPR R3,R5
                BNC @@9
@@8:
                ; It is bigger than the divisor.
                SUBR R3,R5
                DECR R4
                ADCR R4
                SUBR R2,R4
                ADDR R0,R1
@@9:            SLR R0,1
@@11:           CLRC
                RRC R2,1
                RRC R3,1
                ; Again try to exit early
                TSTR R4
                BNE @@10
                TSTR R5
                BEQ @@15
@@10:
                TSTR R2
                BNE @@7
                CMPI #$40,R3
                BC @@7
@@15:
                MVI fptemp1,R0          ; Build full mantissa.
@@6:
                PULR R5                 ; Restore exponent
                ; Reuse the normalize code.
                B fpadd.11              ; Normalize

                ENDP

                ;
                ; Floating-point comparison
                ;
                ; R0,R1 = Left operand
                ; R2,R3 = Right operand
                ;
                ; Return flags for using BEQ, BNE, BC, and BNC.
                ;
fpcomp:         PROC
                PSHR R5
                MVII #$00FF,R5
                MOVR R1,R4
                ANDR R5,R4
                CMPI #$0080,R4
                BEQ @@2                 ; Zero is special case.
                XORI #$0080,R4          ; So negative sign is lesser.
@@2:
                ANDR R3,R5
                CMPI #$0080,R5
                BEQ @@3                 ; Zero is special case.
                XORI #$0080,R5          ; So negative sign is lesser.
@@3:
                CMPR R5,R4
                BNE @@1
                ;
                ; Hack: It doesn't need to insert the fixed one bit.
                ;
                CMPR R2,R0              ; Are both mantissas equal?
                BNE @@1                 ; No, jump.
                ANDI #$FF00,R1
                ANDI #$FF00,R3
                CMPR R3,R1
@@1:
                PULR PC
                ENDP

                ;
                ; Normalization for integers.
                ; These can come with multiple zero bits, so try moving 2 bits at a time.
                ; These never are too small or too big, so the comparisons are removed.
                ;
fpnorm:         PROC
@@1:
                SUBI #2,R2
                SLLC R1,2
                RLC R0,2
                BC @@2
                BOV @@4
                SUBI #2,R2
                SLLC R1,2
                RLC R0,2
                BC @@2
                BOV @@4
                SUBI #2,R2
                SLLC R1,2
                RLC R0,2
                BC @@2
                BOV @@4
                SUBI #2,R2
                SLLC R1,2
                RLC R0,2
                BC @@2
                BOV @@4
                B @@1

                ; One extra bit.
@@2:            BOV @@3
                CLRC
@@3:            RRC R0,1
                RRC R1,1
                INCR R2
@@4:
                ADDR R3,R1              ; Add sign back.
                ADDR R2,R1              ; Add exponent back.
                MOVR R5,PC
                ENDP

                ;
                ; Convert integer to floating-point
                ;
                ; Input: R0 = Signed value.
                ; Output: R0,R1 = Floating-point value.
                ;
fpfromint:      PROC
                CLRR R1
                TSTR R0
                BNE @@1
                MOVR R5,PC

@@1:            BPL @@3
                MVII #$80,R3            ; Sign is negative.
                NEGR R0
                B @@4

@@3:            CLRR R3                 ; Sign is positive.
@@4:
                ;
                ; Preshift 8 bits if the number is small.
                ;
                CMPI #$0100,R0
                BC @@5
                SWAP R0
                MVII #FPEXP_BIAS+$08,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
@@5:
                MVII #FPEXP_BIAS+$10,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
                ENDP

                ;
                ; Convert unsigned integer to floating-point
                ;
                ; Input: R0 = unsigned value.
                ; Output: R0,R1 = Floating-point value.
                ;
fpfromuint:     PROC
                CLRR R1
                TSTR R0
                BNE @@1
                MOVR R5,PC

@@1:            CLRR R3                 ; Sign is positive.
                ;
                ; Preshift 8 bits if the number is small.
                ;
                CMPI #$0100,R0
                BC @@5
                SWAP R0
                MVII #FPEXP_BIAS+$08,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
@@5:
                MVII #FPEXP_BIAS+$10,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
                ENDP

                ;
                ; Convert long unsigned integer to floating-point
                ;
                ; Input: R0 = unsigned value.
                ; Output: R0,R1 = Floating-point value.
                ;
fpfromuint24:   PROC
                CLRR R3                 ; Sign is positive.
                TSTR R0
                BNE @@2
                TSTR R1
                BNE @@1
                MOVR R5,PC

@@1:
                ;
                ; Preshift 8 bits if the number is small.
                ;
                MOVR R1,R0
                CLRR R1
                CMPI #$0100,R0
                BC @@3
                SWAP R0
                MVII #FPEXP_BIAS+$08,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
@@3:
                MVII #FPEXP_BIAS+$10,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
@@2:
                SWAP R0
                ANDI #$FF00,R0
                SWAP R1
                MOVR R1,R2
                ANDI #$00FF,R2
                ADDR R2,R0
                ANDI #$FF00,R1
                MVII #FPEXP_BIAS+$18,R2
                ; Reuse the normalize code.
                B fpnorm                ; Normalize
                ENDP

                ;
                ; Get integer part of a floating-point number
                ; Round towards zero.
                ;
                ; R0,R1 = Floating-point value.
                ;
fpint:          PROC
                PSHR R5
                MOVR R1,R5
                ANDI #$007F,R5
                CMPI #FPEXP_BIAS+$18,R5
                BC @@2                  ; No fraction in this number.
                CLRR R2
                CLRR R3
                SUBI #FPEXP_BIAS,R5
                BC @@3                  ; Jump if there is an integer part.
                CLRR R0                 ; Zero.
                CLRR R1
                B @@2

@@3:            BEQ @@5                 ; Jump if no bits to shift.
@@4:            SETC
                RRC R2,1
                RRC R3,1
                DECR R5
                BNE @@4
@@5:            ADDI #$00FF,R3
                ANDR R2,R0
                ANDR R3,R1
@@2:            PULR PC
                ENDP

                ;
                ; Get integer part of a floating-point number (ceil)
                ;
fpceil:         PROC
                MOVR R1,R3
                ANDI #$80,R3            ; Negative number?
                BNE fpint               ; Yes, do it with fpint.
                B fpfloor.0
                ENDP

                ;
                ; Get integer part of a floating-point number (floor)
                ;
                ; R0,R1 = Floating-point value.
                ;
fpfloor:        PROC
                MOVR R1,R3
                ANDI #$80,R3            ; Positive number?
                BEQ fpint               ; Yes, do it with fpint.
@@0:
                MOVR R1,R4
                ANDI #$007F,R4
                CMPI #FPEXP_BIAS+$18,R4
                BC @@2                  ; No fraction in this number.
                CMPI #FPEXP_BIAS,R4
                BC @@3                  ; Jump if there is an integer part.
                CLRR R0                 ;
                MVII #$003F,R1          ; 1.0
                ADDR R3,R1              ; Add sign.
                B @@2

@@3:            PSHR R5
                PSHR R3
                MOVR R4,R5
                ANDI #$FF00,R1          ; Remove exponent
                SETC                    ; Restore bit one in mantissa.
                RRC R0,1
                RRC R1,1
                RRC R0,1                ; Extra bit to detect carry.
                RRC R1,1
                INCR R5
                INCR R5
                MVII #$FFFF,R2          ; Mask for fraction.
                MOVR R2,R3
                SUBI #FPEXP_BIAS-2,R4
@@4:            CLRC
                RRC R2,1
                RRC R3,1
                DECR R4
                BNE @@4
@@5:            ADDR R3,R1              ; Add fraction rounding.
                ADCR R0
                ADDR R2,R0
                COMR R2                 ; Invert fraction mask...
                COMR R3
                ANDR R2,R0
                ANDR R3,R1
                ; Reuse the normalize code.
                B fpadd.11              ; Normalize

@@2:            MOVR R5,PC
                ENDP

                ;
                ; Convert a floating-point number to an integer.
                ;
                ; r0,r1 = Floating-point number
                ;
                ; Output: r0 = Integer.
                ;
fp2int:         PROC
                MOVR R1,R3
                ANDI #$007F,R3
                SETC
                RRC R0,1
                MVII #FPEXP_BIAS+$0f,R2
                SUBR R3,R2
                BEQ @@2
                BPL @@1
                MVII #$7FFF,R0          ; Too big.
                B @@2

@@1:            CMPI #$10,R2
                BNC @@4
                CLRR R0                 ; Too small.
                B @@2

@@4:            SLR R0,1
                DECR R2
                BEQ @@2
                SLR R0,1
                DECR R2
                BNE @@4
@@2:            ANDI #$0080,R1
                BEQ @@3
                NEGR R0
@@3:            MOVR R5,PC
                ENDP

                ;
                ; Convert a floating-point number to an unsigned integer.
                ;
                ; r0,r1 = Floating-point number
                ;
                ; Output: r0 = Integer.
                ;
fp2uint:        PROC
                MOVR R1,R3
                ANDI #$007F,R3
                SETC
                RRC R0,1
                MVII #FPEXP_BIAS+$0f,R2
                SUBR R3,R2
                BEQ @@2
                BPL @@1
                MVII #$FFFF,R0          ; Too big.
                B @@2

@@1:            CMPI #$10,R2
                BNC @@4
                CLRR R0                 ; Too small.
                B @@2

@@4:            SLR R0,1
                DECR R2
                BEQ @@2
                SLR R0,1
                DECR R2
                BNE @@4
@@2:            MOVR R5,PC
                ENDP

                ;
                ; Gets the absolute value of a floating-point number
                ;
                ; r0,r1 = Floating-point number
                ;
fpabs:          PROC
                ANDI #$007F,R1
                MOVR R5,PC
                ENDP

                ;
                ; Negates a floating-point number
                ;
                ; r0,r1 = Floating-point number
                ;
fpneg:          PROC
                XORI #$80,R1
                MOVR R5,PC
                ENDP

                ;
                ; Gets the sign of a floating-point number
                ;
                ; r0,r1 = Floating-point number.
                ;
fpsgn:          PROC
                CLRR R0
                MOVR R1,R2
                ANDI #$007F,R2
                BNE @@1
                CLRR R1                 ; 0.0
                MOVR R5,PC
@@1:
                ANDI #$0080,R1
                ADDI #$003F,R1          ; 1.0 / -1.0
                MOVR R5,PC
                ENDP

                ;
                ; Divide a number by 2 (moving the exponent)
                ;
fpdivby2:       PROC
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
fpmulby2:       PROC
                MOVR R1,R2
                ANDI #$7F,R2
                BEQ @@2
                CMPI #$7F,R2
                BNE @@1
                MVII #$FFFF,R0
                ANDI #$0080,R1
                ADDI #$FF7E,R1
@@1:            INCR R1
@@2:            MOVR R5,PC
                ENDP

                ;
                ; Generate a random number.
                ;
fprnd:          PROC
                PSHR R5
                MVI lfsr,r0
                ADDI #83,R0             ; A prime number.
                MOVR R0,R1
                SWAP R0
                ANDI #$FF00,R0          ; x256
                ADDR R1,R0              ; x257
                MVO R0,lfsr
                CLRR R2
                PSHR R2
                MVII #$3F,R5
                ; Reuse the normalize code.
                B fpadd.11              ; Normalize
                ENDP
