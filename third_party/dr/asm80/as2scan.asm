	TITLE	'ASM SCANNER MODULE'
	ORG	1100H
	JMP	ENDMOD	;END OF THIS MODULE
	JMP	INITS	;INITIALIZE THE SCANNER
	JMP	SCAN	;CALL THE SCANNER
;
;
;	ENTRY POINTS IN I/O MODULE
IOMOD	EQU	200H
GNCF	EQU	IOMOD+6H
WOBUFF	EQU	IOMOD+15H
PERR	EQU	IOMOD+18H
;
LASTC:	DS	1	;LAST CHAR SCANNED
NEXTC:	DS	1	;LOOK AHEAD CHAR
STYPE:	DS	1	;RADIX INDICATOR
;
;	COMMON EQUATES
PBMAX	EQU	120	;MAX PRINT SIZE
PBUFF	EQU	10CH	;PRINT BUFFER
PBP	EQU	PBUFF+PBMAX	;PRINT BUFFER POINTER
;
TOKEN	EQU	PBP+1	;CURRENT TOKEN UDER SCAN
VALUE	EQU	TOKEN+1	;VALUE OF NUMBER IN BINARY
ACCLEN	EQU	VALUE+2	;ACCUMULATOR LENGTH
ACMAX	EQU	64	;MAX ACCUMULATOR LENGTH
ACCUM	EQU	ACCLEN+1
;
EVALUE	EQU	ACCUM+ACMAX	;VALUE FROM EXPRESSION ANALYSIS
;
SYTOP	EQU	EVALUE+2	;CURRENT SYMBOL TOP
SYMAX	EQU	SYTOP+2		;MAX ADDRESS+1
;
PASS	EQU	SYMAX+2	;CURRENT PASS NUMBER
FPC	EQU	PASS+1	;FILL ADDRESS FOR NEXT HEX BYTE
ASPC	EQU	FPC+2	;ASSEMBLER'S PSEUDO PC
;
;	GLOBAL EQUATES
IDEN	EQU	1	;IDENTIFIER
NUMB	EQU	2	;NUMBER
STRNG	EQU	3	;STRING
SPECL	EQU	4	;SPECIAL CHARACTER
;
PLABT	EQU	0001B	;PROGRAM LABEL
DLABT	EQU	0010B	;DATA LABEL
EQUT	EQU	0100B	;EQUATE
SETT	EQU	0101B	;SET
MACT	EQU	0110B	;MACRO
;
EXTT	EQU	1000B	;EXTERNAL
REFT	EQU	1011B	;REFER
GLBT	EQU	1100B	;GLOBAL
;
BINV	EQU	2
OCTV	EQU	8
DECV	EQU	10
HEXV	EQU	16
CR	EQU	0DH
LF	EQU	0AH
EOF	EQU	1AH
TAB	EQU	09H	;TAB CHARACTER
;
;
;	UTILITY SUBROUTINES
GNC:	;GET NEXT CHARACTER AND ECHO TO PRINT FILE
	CALL	GNCF
	PUSH	PSW
	CPI	CR
	JZ	GNC0
	CPI	LF	;IF LF THEN DUMP CURRENT BUFFER
	JZ	GNC0
;
	;NOT A CR OR LF, PLACE INTO BUFFER IF THERE IS ENOUGH ROOM
	LDA	PBP
	CPI	PBMAX
	JNC	GNC0
;	ENOUGH ROOM, PLACE INTO BUFFER
	MOV	E,A
	MVI	D,0	;DOUBLE PRECISION PBP IN D,E
	INR	A
	STA	PBP	;INCREMENTED PBP IN MEMORY
	LXI	H,PBUFF
	DAD	D	;PBUFF(PBP)
	POP	PSW
	MOV	M,A	;PBUFF(PBP) = CHAR
	RET
GNC0:	;CHAR NOT PLACED INTO BUFFER
	POP	PSW
	RET
;
INITS:	;INITIALIZE THE SCANNER
	CALL	ZERO
	STA	NEXTC	;CLEAR NEXT CHARACTER
	STA	PBP
	MVI	A,LF	;SET LAST CHAR TO LF
	STA	LASTC
	CALL	WOBUFF	;CLEAR BUFFER
	MVI	A,16	;START OF PRINT LINE
	STA	PBP
	RET
;
ZERO:	XRA	A
	STA	ACCLEN
	STA	STYPE
	RET
;
SAVER:	;STORE THE NEXT CHARACTER INTO THE ACCUMULATOR AND UPDATE ACCLEN
	LXI	H,ACCLEN
	MOV	A,M
	CPI	ACMAX
	JC	SAV1	;JUMP IF NOT UP TO LAST POSITION
	MVI	M,0
	CALL	ERRO
SAV1:	MOV	E,M	;D,E WILL HOLD INDEX
	MVI	D,0
	INR	M	;ACCLEN INCREMENTED
	INX	H	;ADDRESS ACCUMULATOR
	DAD	D	;ADD INDEX TO ACCUMULATOR
	LDA	NEXTC	;GET CHARACTER
	MOV	M,A	;INTO ACCUMULATOR
	RET
;
TDOLL:	;TEST FOR DOLLAR SIGN, ASSUMING H,L ADDRESS NEXTC
	MOV	A,M
	CPI	'$'
	RNZ
	XRA	A	;TO GET A ZERO
	MOV	M,A	;CLEARS NEXTC
	RET		;WITH ZERO FLAG SET
;
NUMERIC:	;CHECK NEXTC FOR NUMERIC, RETURN ZERO FLAG IF NOT NUMERIC
	LDA	NEXTC
	SUI	'0'
	CPI	10
;	CARRY RESET IF NUMERIC
	RAL
	ANI	1B	;ZERO IF NOT NUMERIC
	RET
;
HEX:	;RETURN ZERO FLAG IF NEXTC IS NOT HEXADECIMAL
	CALL	NUMERIC
	RNZ		;RETURNS IF 0-9
	LDA	NEXTC
	SUI	'A'
	CPI	6
;	CARRY SET IF OUT OF RANGE
	RAL
	ANI	1B
	RET
;
LETTER:	;RETURN ZERO FLAG IF NEXTC IS NOT A LETTER
	LDA	NEXTC
	SUI	'A'
	CPI	26
	RAL
	ANI	1B
	RET
;
ALNUM:	;RETURN ZERO FLAG IF NOT ALPHANUMERIC
	CALL	LETTER
	RNZ
	CALL	NUMERIC
	RET
;
TRANS:	;TRANSLATE TO UPPER CASE
	LDA	NEXTC
	CPI	'A' OR 1100000B	;LOWER CASE A
	RC				;CARRY IF LESS THAN LOWER A
	CPI	('Z' OR 1100000B)+1	;LOWER CASE Z
	RNC				;NO CARRY IF GREATER THAN LOWER Z
	ANI	1011111B		;CONVERT TO UPPER CASE
	STA	NEXTC
	RET
;
GNCN:	;GET CHARACTER AND STORE TO NEXTC
	CALL	GNC
	STA	NEXTC
	CALL	TRANS	;TRANSLATE TO UPPER CASE
	RET
;
EOLT:	;END OF LINE TEST FOR COMMENT SCAN
	CPI	CR
	RZ
	CPI	EOF
	RZ
	CPI	'!'
	RET
;
SCAN:	;FIND NEXT TOKEN IN INPUT STREAM
	XRA	A
	STA	TOKEN
	CALL	ZERO
;
;	DEBLANK
DEBL:	LDA	NEXTC
	CPI	TAB	;TAB CHARACTER TREATED AS BLANK OUTSIDE STRING
	JZ	DEB0
	CPI	';'	;MAY BE A COMMENT
	JZ	DEB1	;DEBLANK THROUGH COMMENT
	CPI	'*'	;PROCESSOR TECH COMMENT
	JNZ	DEB2	;NOT *
	LDA	LASTC
	CPI	LF	;LAST LINE FEED?
	JNZ	DEB2	;NOT LF*
;	COMMENT FOUND, REMOVE IT
DEB1:	CALL	GNCN
	CALL	EOLT	;CR, EOF, OR !
	JZ	FINDL	;HANDLE END OF LINE
	JMP	DEB1	;OTHERWISE CONTINUE SCAN
DEB2:	ORI	' '	;MAY BE ZERO
	CPI	' '
	JNZ	FINDL
DEB0:	CALL	GNCN	;GET NEXT AND STORE TO NEXTC
	JMP	DEBL
;
;	LINE DEBLANKED, FIND TOKEN TYPE
FINDL:	;LOOK FOR LETTER, DECIMAL DIGIT, OR STRING QUOTE
	CALL	LETTER
	JZ	FIND0
	MVI	A,IDEN
	JMP	STOKEN
;
FIND0:	CALL	NUMERIC
	JZ	FIND1
	MVI	A,NUMB
	JMP	STOKEN
;
FIND1:	LDA	NEXTC
	CPI	''''
	JNZ	FIND2
	XRA	A
	STA	NEXTC	;DON'T STORE THE QUOTE
	MVI	A,STRNG
	JMP	STOKEN
;
FIND2:	;ASSUME IT IS A SPECIAL CHARACTER
	CPI	LF	;IF LF THEN DUMP THE BUFFER
	JNZ	FIND3
;	LF FOUND
	LDA	PASS
	ORA	A
	CNZ	WOBUFF
	LXI	H,PBUFF	;CLEAR ERROR CHAR ON BOTH PASSES
	MVI	M,' '
	MVI	A,16
	STA	PBP	;START NEW LINE
FIND3:	MVI	A,SPECL
;
STOKEN:	STA	TOKEN
;
;
;	LOOP WHILE CURRENT ITEM IS ACCUMULATING
SCTOK:	LDA	NEXTC
	STA	LASTC	;SAVE LAST CHARACTER
	ORA	A
	CNZ	SAVER	;STORE CHARACTER INTO ACCUM IF NOT ZERO
	CALL	GNCN	;GET NEXT TO NEXTC
	LDA	TOKEN
	CPI	SPECL
	RZ		;RETURN IF SPECIAL CHARACTER
	CPI	STRNG
	CNZ	TRANS	;TRANSLATE TO UPPER CASE IF NOT IN STRING
	LXI	H,NEXTC
	LDA	TOKEN
;
	CPI	IDEN
	JNZ	SCT2
;
;	ACCUMULATING AN IDENTIFIER
	CALL	TDOLL	;$?
	JZ	SCTOK	;IF SO, SKIP IT
	CALL	ALNUM	;ALPHA NUMERIC?
	RZ		;RETURN IF END
;	NOT END OF THE IDENTIFIER
	JMP	SCTOK
;
SCT2:	;NOT SPECIAL OR IDENT, CHECK NUMBER
	CPI	NUMB
	JNZ	SCT3
;
;	ACCUMULATING A NUMBER, CHECK FOR $
	CALL	TDOLL
	JZ	SCTOK	;SKIP IF FOUND
	CALL	HEX	;HEX CHARACTER?
	JNZ	SCTOK	;STORE IT IF FOUND
;	END OF NUMBER, LOOK FOR RADIX INDICATOR
;
	LDA	NEXTC
	CPI	'O'	;OCTAL INDICATOR
	JZ	NOCT
	CPI	'Q'	;OCTAL INDICATOR
	JNZ	NUM2
;
NOCT:	;OCTAL
	MVI	A,OCTV
	JMP	SSTYP
;
NUM2:	CPI	'H'
	JNZ	NUM3
	MVI	A,HEXV
SSTYP:	STA	STYPE
	XRA	A
	STA	NEXTC	;CLEARS THE LOOKAHEAD CHARACTER
	JMP	NCON
;
;	RADIX MUST COME FROM ACCUM
NUM3:	LDA	LASTC
	CPI	'B'
	JNZ	NUM4
	MVI	A,BINV
	JMP	SSTY1
;
NUM4:	CPI	'D'
	MVI	A,DECV
	JNZ	SSTY2
SSTY1:	LXI	H,ACCLEN
	DCR	M	;ACCLEN DECREMENTED TO REMOVE RADIX INDICATOR
SSTY2:	STA	STYPE
;
NCON:	;NUMERIC CONVERSION OCCURS HERE
	LXI	H,0
	SHLD	VALUE	;VALUE ACCUMULATES BINARY EQUIVALENT
	LXI	H,ACCLEN
	MOV	C,M	;C=ACCLEN
	INX	H	;ADDRESSES ACCUM
CLOP:	;NEXT DIGIT IS PROCESSED HERE
	MOV	A,M
	INX	H	;READY FOR NEXT LOOP
	CPI	'A'
	JNC	CLOP1	;NOT HEX A-F
	SUI	'0'	;NORMALIZE
	JMP	CLOP2
;
CLOP1:	;HEX A-F
	SUI	'A'-10
CLOP2:	;CHECK SIZE AGAINST RADIX
	PUSH	H	;SAVE ACCUM ADDR
	PUSH	B	;SAVE CURRENT POSITION
	MOV	C,A
	LXI	H,STYPE
	CMP	M
	CNC	ERRV	;VALUE ERROR IF DIGIT>=RADIX
	MVI	B,0	;DOUBLE PRECISION DIGIT
	MOV	A,M	;RADIX TO ACCUMULATOR
	LHLD	VALUE
	XCHG		;VALUE TO D,E - ACCUMULATE RESULT IN H,L
	LXI	H,0	;ZERO ACCUMULATOR
CLOP3:	;LOOP UNTIL RADIX GOES TO ZERO
	ORA	A
	JZ	CLOP4
	RAR		;TEST LSB
	JNC	TTWO	;SKIP SUMMING OPERATION IF LSB=0
	DAD	D	;ADD IN VALUE
TTWO:	;MULTIPLY VALUE * 2 FOR SHL OPERATION
	XCHG
	DAD	H
	XCHG
	JMP	CLOP3
;
;
CLOP4:	;END OF NUMBER CONVERSION
	DAD	B	;DIGIT ADDED IN
	SHLD	VALUE
	POP	B
	POP	H
	DCR	C	;MORE DIGITS?
	JNZ	CLOP
	RET		;DONE WITH THE NUMBER
;
SCT3:	;MUST BE A STRING
	LDA	NEXTC
	CPI	CR	;END OF LINE?
	JZ	ERRO	;AND RETURN
	CPI	''''
	JNZ	SCTOK
	CALL	GNCN
	CPI	''''
	RNZ		;RETURN IF SINGLE QUOTE ENCOUNTERED
	JMP	SCTOK	;OTHERWISE TREAT AS ONE QUOTE
;
;	END OF SCANNER
;
;	ERROR MESSAGE ROUTINES
ERRV:	;'V' VALUE ERROR
	PUSH	PSW
	MVI	A,'V'
	JMP	ERR
;
ERRO:	;'O' OVERFLOW ERROR
	PUSH	PSW
	MVI	A,'O'
	JMP	ERR
;
ERR:	;PRINT ERROR MESSAGE
	PUSH	B
	PUSH	H
	CALL	PERR
	POP	H
	POP	B
	POP	PSW
	RET
;
ENDMOD	EQU	($ AND 0FFE0H) + 20H
	END
