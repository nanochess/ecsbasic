	;
	; Floating-point mathematic routines for CP1610 processor
	;
	; by Oscar Toledo G.
	; https://nanochess.org/
	;
	; Creation date: Sep/20/2025. Added fpsin and fpcos.
	; Revision date: Oct/05/2025. Corrected bug in both fpsin and fpcos. Added fptan, fpln,
	;                             fpexp, and fpsqrt.
	;

	; These routines are based on the mathematic routines
	; I made for my Pascal compiler for transputer.

	;
	; sin function
	;
	; r0,r1 = Floating-point value
	;
fpsin:	PROC
	PSHR R5
	MVII #$45f3,R2
	MVII #$183E,R3
	CALL fpmul
	PSHR R0
	PSHR R1
	MVII #$0000,R2
	MVII #$003F,R3
	CALL fpadd
	CALL fpdivby2
	CALL fpdivby2
	CALL fpfloor	
	CALL fpmulby2
	CALL fpmulby2
	MOVR R0,R2
	MOVR R1,R3
	PULR R1
	PULR R0
	CALL fpsub
	PSHR R0
	PSHR R1
	MVII #$0000,R2
	MVII #$003F,R3
	CALL fpcomp
	PULR R1
	PULR R0
	BNC @@1
	MOVR R0,R2
	MOVR R1,R3
	MVII #$0000,R0
	MVII #$0040,R1
	CALL fpsub
@@1:
	PSHR R0
	PSHR R1
	MOVR R0,R2
	MOVR R1,R3
	CALL fpmul
	CALL fpmulby2
	MVII #$0000,R2
	MVII #$003F,R3
	CALL fpsub
	PSHR R0
	PSHR R1
	MVII #$CC9C,R2
	MVII #$C4A7,R3
	CALL fpmul
	MVII #$3E15,R2
	MVII #$F62E,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$1E5F,R2
	MVII #$DEB4,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$2a9f,R2
	MVII #$b439,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$23b0,R2
	MVII #$34bd,R3
	CALL fpadd
	PULR R3
	PULR R2
	CALL fpmul
	MVII #$4464,R2
	MVII #$bc3f,R3
	CALL fpadd
	PULR R3
	PULR R2
	CALL fpmul
	PULR PC
	ENDP	

	;
	; cos function
	;
	; r0,r1 = floating-point value
	;
fpcos:	PROC
	PSHR R5
	MVII #$921F,R2
	MVII #$9E3F,R3
	CALL fpadd
	PULR R5
	B fpsin
	ENDP

	;
	; tan function
	;
	; r0,r1 = floating-point value
	;
fptan:	PROC
	PSHR R5
	PSHR R0
	PSHR R1
	CALL fpcos
	PULR R3
	PULR R2
	PSHR R0
	PSHR R1
	MOVR R2,R0
	MOVR R3,R1
	CALL fpsin
	PULR R3
	PULR R2
	CALL fpdiv
	PULR PC
	ENDP

	;
	; sqrt function
	;
	; r0,r1 = floating-point value
	;
fpsqrt:	PROC
	PSHR R5
	CALL fpln	; ln
	CALL fpdivby2	; * 0.5
	CALL fpexp	; exp
	PULR PC
	ENDP

	;
	; ln function
	;
fpln:	PROC
	PSHR R5
	MOVR R1,R2
	ANDI #$80,R2
	BEQ @@1
	CLRR R0
	CLRR R1
	PULR PC
@@1:
	MOVR R1,R2
	ANDI #$7F,R2
	BEQ @@0
	SUBI #FPEXP_BIAS-1,R2
	PSHR R2
	ANDI #$FF00,R1
	ADDI #$003E,R1	; Now number is in the range 0.5-0.99
	PSHR R0
	PSHR R1
	MVII #$6a09,R2
	MVII #$e63e,R3
	CALL fpsub
	PULR R3
	PULR R2
	PSHR R0
	PSHR R1
	MVII #$6a09,R0
	MVII #$e63e,R1
	CALL fpadd
	MOVR R0,R2
	MOVR R1,R3
	PULR R1
	PULR R0
	CALL fpdiv
	PSHR R0
	PSHR R1
	MOVR R0,R2
	MOVR R1,R3
	CALL fpmul
	MVII #$2387,R2
	MVII #$583D,R3
	PSHR R0
	PSHR R1
	CALL fpmul
	MVII #$476F,R2
	MVII #$3C3D,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$A61B,R2
	MVII #$4C3D,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$2776,R2
	MVII #$C03E,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$EC70,R2
	MVII #$9C3E,R3
	CALL fpadd
	PULR R3
	PULR R2
	CALL fpmul
	MVII #$7154,R2
	MVII #$7640,R3
	CALL fpadd
	PULR R3
	PULR R2
	CALL fpmul
	MVII #$0000,R2
	MVII #$00BE,R3
	CALL fpadd
@@test:
	PULR R4
	PSHR R0
	PSHR R1
	MOVR R4,R0
	CALL fpfromint
	PULR R3
	PULR R2
	CALL fpadd	; Add exponent.
	MVII #$62E4,R2	; 1 / 1.442695
	MVII #$313E,R3	; precision is important here.
	CALL fpmul
@@0:
	PULR PC
	ENDP

	;
	; exp function
	;
fpexp:	PROC
	PSHR R5
	MVII #$7154,R2	; 1.442695
	MVII #$753F,R3	; precision is important here.
	CALL fpmul
	PSHR R0
	PSHR R1
	CALL fp2int
	MOVR R0,R4
	CALL fpfromint
	MOVR R0,R2
	MOVR R1,R3
	PULR R1
	PULR R0
	PSHR R4
	CALL fpsub
	PSHR R0
	PSHR R1
	MVII #$2AAC,R2
	MVII #$8A28,R3
	CALL fpmul
	MVII #$4F25,R2
	MVII #$402B,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$0127,R2
	MVII #$dc2f,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$42f1,R2
	MVII #$4e32,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$5d89,R2
	MVII #$0435,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$3b2a,R2
	MVII #$b038,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$c6b0,R2
	MVII #$8c3a,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$ebfb,R2
	MVII #$de3c,R3
	CALL fpadd
	PULR R3
	PULR R2
	PSHR R2
	PSHR R3
	CALL fpmul
	MVII #$62e4,R2
	MVII #$2e3e,R3
	CALL fpadd
	PULR R3
	PULR R2
	CALL fpmul
	MVII #$0000,R2
	MVII #$003F,R3
	CALL fpadd
	PULR R4
	ADDR R4,R1
	PULR PC
	ENDP
