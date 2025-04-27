; JUMP 'N' BUMP
; Original game by Brainchild Design
; Demake by Midnight Mirage Softworks
	processor 6502
	include vcs.h
	include macro.h

; CONSTANTS

NTSC = 1

	IF NTSC
BKCOL = #79
P2BCOL = #1
	ELSE
BKCOL = #158
P2BCOL = $28
	ENDIF

P1BCOL = $0E

ScreenHeight = #98


NegativeMask	= %10000000

; Bunny state masks

BunnyJoyMask	= %00000001
BunnyDeathMask	= %00000010

; Bunny Consts
JumpForce		= #64
GravityForce	= %11111100	;-12

	seg.u	   	RAM
    org     $80

; Bunny Struct (5 Bytes)
; Velocity(Vertical Fixed 4:4) - 1 Byte
; Position - 2 Bytes
; State - 1 Byte
; Score - 1 Byte
; Draw - 1 Byte

B0_VelY			.byte
B1_VelY			.byte

B0_PosX			.byte
B1_PosX			.byte

B0_PosY			.byte
B1_PosY			.byte

B0_State		.byte
B1_State		.byte

B0_Score		.byte
B1_Score		.byte

B0_Draw			.byte
B1_Draw			.byte

B0_SprtPtr		.word
B1_SprtPtr		.word

CurrentBunny	.byte

Joystick		.byte			;stores joystick directions
Button			.byte			;stores button state

Workspace		.byte			;for random calculations that need some memory

	seg 	CODE
	org 	$F000, 0

fineAdjustBegin
            DC.B %01110000; Left 7 

            DC.B %01100000; Left 6

            DC.B %01010000; Left 5

            DC.B %01000000; Left 4

            DC.B %00110000; Left 3

            DC.B %00100000; Left 2

            DC.B %00010000; Left 1

            DC.B %00000000; No movement.

            DC.B %11110000; Right 1

            DC.B %11100000; Right 2

            DC.B %11010000; Right 3

            DC.B %11000000; Right 4

            DC.B %10110000; Right 5

            DC.B %10100000; Right 6

            DC.B %10010000; Right 7



fineAdjustTable EQU fineAdjustBegin - %11110001; NOTE: %11110001 = -15

Start
	CLEAN_START

	lda 	BKCOL
	sta 	COLUBK  			;set blackground 	
	lda 	P1BCOL
	sta 	COLUP0				;set player0 colour
	lda 	#$22
	sta 	COLUP1				;set player1 colour
	lda 	#$C2
	sta		COLUPF
	lda		#40
	sta		B0_PosX
	sta		B0_PosY
	sta 	B1_PosY
	lda 	#48
	sta		B1_PosX

;MainLoop starts with usual VBLANK code,
;and the usual timer seeding
MainLoop
	VERTICAL_SYNC
	lda #15		
	sta TIM64T

UpdatePlayer
	lda		SWCHA
	sta		Joystick			;load joystick state - cut off up and down as we don't need it

	ldx		CurrentBunny
	bne		ReadJoystick2Button

Joystick1Shifting
	lda		SWCHA
	lsr
	lsr
	lsr
	lsr
	sta 	Joystick

ReadJoystick1Button
	lda		INPT4
    sta    	Button
	jmp		CalculateVelocity

ReadJoystick2Button
	lda		INPT5
    sta    	Button

CalculateVelocity
	ldy 	B0_PosX,x		;load PosX into a
	lda 	Joystick
	lsr
	lsr

CheckLeft
	lda		Joystick			;check if left is pressed
	lsr
	lsr
	lsr
	bcs		CheckRight

	dey							;x--

CheckRight
	lda		Joystick			;check if right is pressed
	lsr
	lsr
	lsr
	lsr
	bcs 	AdjustPos

	iny							;x++

AdjustPos
	sty		B0_PosX,x			;store modified x coord
	lda		B0_PosX,x
	cmp		#169
	bcc		CheckButton

	lda		#168
	sta		B0_PosX,x

CheckButton
	lda 	#0
	cmp 	Button
	bne		ApplyVelocity		;check if button pressed

	lda		B0_VelY,x
	;adc		#64
	sta		B0_VelY,x

ApplyVelocity
	lda		B0_VelY,x
	sta		Workspace
	bit		Workspace
	beq		NegativeVelocity

PositiveVeloicty
	lsr
	lsr
	lsr

	lda		B0_PosY,x
	adc		Workspace
	sta		B0_PosY,x
	jmp		CollisionCheck

NegativeVelocity
	eor		#$FF				;bitwise NOT
	tax
	inx							;increment, part of 2's complement conversion
	txa
	lsr
	lsr
	lsr

	ldx		CurrentBunny
	lda		B0_PosY,x
	sbc		Workspace
	sta		B0_PosY,x

CollisionCheck
	bit 	CXPPMM				;bit check P0-P1 collsion - N flag should equal colision bit

	lda 	CurrentBunny
	bne		PrepDraw	
	
	inc 	CurrentBunny
	jmp 	UpdatePlayer

	; Taken from Darrell Spice's Let's Make a Game! Step 4 (https://www.randomterrain.com/atari-2600-lets-make-a-game-spiceware-04.html)
PrepDraw
	lda		#(ScreenHeight + BunnyHeight)
	sec
	sbc		B0_PosY
	sta		B0_Draw

	lda		#<(BunnySprite + BunnyHeight - 1)
	sec
	sbc		B0_PosY
	sta		B0_SprtPtr
	lda		#>(BunnySprite + BunnyHeight - 1)
	sbc		#0
	sta		B0_SprtPtr + 1

	lda		#(ScreenHeight + BunnyHeight)
	sec
	sbc		B1_PosY
	sta		B1_Draw

	lda		#<(BunnySprite + BunnyHeight - 1)
	sec
	sbc		B1_PosY
	sta		B1_SprtPtr
	lda		#>(BunnySprite + BunnyHeight - 1)
	sbc		#0
	sta		B1_SprtPtr + 1

	lda		B0_PosX
	ldx		#0
	jsr		PrePosObject
	;sta		WSYNC
	lda		B0_PosX
	jsr		PosObject

	lda		B1_PosX
	ldx		#1
	jsr		PrePosObject
	;sta		WSYNC
	lda		B1_PosX
	jsr		PosObject
	sta		WSYNC
	sta		HMOVE

WaitForVblankEnd
	lda 	#0
	sta		CurrentBunny
	lda 	INTIM	
	bne 	WaitForVblankEnd	
	;lda		#%00000010
	sta 	VBLANK  
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	sta		WSYNC	
	;sta		WSYNC				

	IF NTSC

	ELSE

	ldx		#50
PALSky
	sta		WSYNC
	dex
	bne		PALSky

	ENDIF


	ldy 	#98
	ldx 	#0
	sta 	WSYNC

BeginScreenLoop


ScreenLoop
	lda 	#BunnyHeight-1
	dcp		B0_Draw
	bcs		DoDrawP1
	lda		#0
	.byte 	$2C

DoDrawP1
	lda		(B0_SprtPtr),y
	nop
	;sta 	WSYNC
	;sta		VDELP0
; Line 1 ----------------------------------------------
	sta		GRP0					;3
	lda		LvlNormalDataPF0,x		;4
	sta		PF0						;3
	lda		LvlNormalDataPF1,x		;4
	sta		PF1						;3
	lda		LvlNormalDataPF2,x		;4
	sta		PF2						;3 (24)
	sta		Workspace				;3
	lda		LvlNormalDataPF0+1,x	;4
	sta		PF0						;3
	lda		LvlNormalDataPF1+1,x	;4
	sta		PF1						;3
	lda		LvlNormalDataPF2+1,x	;4
	sta		PF2						;3


	;dex
	lda		#BunnyHeight-1
	dcp		B1_Draw
	bcs		DoDrawP2
	lda		#0
	.byte	$2C

DoDrawP2
	lda		(B1_SprtPtr),y
	sta 	WSYNC
; Line 2 ----------------------------------------------
	sta		GRP1					;3
	lda		LvlNormalDataPF0,x		;4
	sta		PF0						;3
	lda		LvlNormalDataPF1,x		;4
	sta		PF1						;3
	lda		LvlNormalDataPF2,x		;4
	sta		PF2						;3 (24)
	sta		Workspace				;3 (27)
	lda		LvlNormalDataPF0+1,x	;4
	sta		PF0						;3
	lda		LvlNormalDataPF1+1,x	;4
	sta		PF1						;3
	lda		LvlNormalDataPF2+1,x	;4
	sta		PF2						;3

	inx
	inx
	dey
	bpl		ScreenLoop

 ; usual vblank
	sta 	WSYNC
 	lda #2		
 	sta VBLANK 	
 	ldx #30		
 	lda #0
 	sta CurrentBunny
 	lda #158
 	sta COLUBK
OverScanWait
	sta 	WSYNC
	dex
	bne	 OverScanWait
	jmp  MainLoop      

;Subroutines

; By R. Mundschau (https://www.randomterrain.com/atari-2600-memories-tutorial-andrew-davie-24.html)
; Positions an object horizontally
; Inputs: A = Desired position.
; X = Desired object to be positioned (0-5).
; scanlines: If control comes on or before cycle 73 then 1 scanline is consumed.
; If control comes after cycle 73 then 2 scanlines are consumed.
; Outputs: X = unchanged
; A = Fine Adjustment value.
; Y = the "remainder" of the division by 15 minus an additional 15.
PosObject   SUBROUTINE
	sta		WSYNC
	sec                      ; 02     Set the carry flag so no borrow will be
								;        applied during the division.

divideby15 
	sbc 	#15                 ; 04     Waste the necessary amount of time
								;        dividing X-pos by 15!
	bcs 	divideby15          ; 06/07  11/16/21/26/31/36/41/46/51/56/61/66

	tay
	lda 	fineAdjustTable,y    ; 13 -> Consume 5 cycles by guaranteeing we
								;       cross a page boundary
	sta 	RESP0,x              ; 21/ 26/31/36/41/46/51/56/61/66/71
								; Set the rough position.
	rts

PrePosObject   SUBROUTINE
	sec                      ; 02     Set the carry flag so no borrow will be
								;        applied during the division.

divideby152 
	sbc 	#15                  ; 04     Waste the necessary amount of time
								;        dividing X-pos by 15!
	bcs 	divideby152          ; 06/07  11/16/21/26/31/36/41/46/51/56/61/66

	tay
	lda 	fineAdjustTable,y    ; 13 -> Consume 5 cycles by guaranteeing we
								;       cross a page boundary
	sta 	HMP0,x

	rts

;Sprites
BunnySprite:
	.byte %01111110 ;
	.byte %00101111 ;
	.byte %00111110 ;
	.byte %11111100 ;
	.byte %10110000 ;
	.byte %01111000 ;
	.byte %00011100 ;
	.byte %00001100 ;
BunnyHeight		= * - BunnySprite

;Levels

;Normal
; mode: asymmetric repeat line-height 2

LvlNormalDataPF0:
	.byte $F0,$00,$F0,$00,$F0,$00,$F0,$00
	.byte $F0,$00,$70,$E0,$70,$E0,$30,$E0
	.byte $30,$E0,$30,$E0,$30,$E0,$30,$F0
	.byte $30,$F0,$30,$F0,$30,$F0,$30,$F0
	.byte $30,$F0,$30,$F0,$70,$F0,$70,$F0
	.byte $70,$F0,$F0,$F0,$F0,$F0,$F0,$F0
	.byte $F0,$F0,$F0,$F0,$F0,$F0,$70,$F0
	.byte $70,$F0,$30,$30,$30,$10,$30,$00
	.byte $30,$00,$30,$00,$30,$00,$30,$00
	.byte $30,$00,$30,$00,$30,$00,$30,$00
	.byte $30,$00,$30,$00,$30,$00,$30,$00
	.byte $F0,$00,$F0,$00,$F0,$00,$F0,$00
	.byte $F0,$00,$F0,$00,$F0,$00,$F0,$00
	.byte $F0,$00,$30,$00,$30,$00,$30,$80
	.byte $30,$80,$30,$F0,$30,$F0,$30,$F0
	.byte $30,$F0,$30,$F0,$30,$F0,$30,$F0
	.byte $30,$F0,$30,$F0,$30,$F0,$30,$F0
	.byte $30,$F0,$30,$F0,$30,$F0,$30,$60
	.byte $30,$00,$30,$00,$30,$00,$30,$00
	.byte $30,$00,$30,$00,$F0,$00,$F0,$00
	.byte $F0,$00,$F0,$00,$F0,$00,$F0,$00
	.byte $F0,$00,$70,$00,$30,$00,$30,$F0
	.byte $30,$F0,$30,$F0,$30,$F0,$30,$F0
	.byte $30,$F0,$F0,$F0,$F0,$F0,$F0,$F0
LvlNormalDataPF1:
	.byte $80,$00,$80,$00,$80,$00,$80,$00
	.byte $00,$01,$00,$01,$00,$01,$00,$01
	.byte $00,$01,$00,$C0,$00,$C0,$00,$C0
	.byte $00,$C0,$00,$F8,$00,$F8,$00,$F8
	.byte $00,$F8,$00,$F8,$00,$F8,$00,$F0
	.byte $00,$F0,$80,$E0,$80,$C0,$80,$C0
	.byte $80,$C0,$80,$80,$80,$80,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $F8,$00,$F8,$00,$F8,$00,$F8,$00
	.byte $F8,$E0,$E0,$E0,$E0,$E0,$C0,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$F8,$00,$FF,$00,$FF,$00,$FF
	.byte $1F,$FF,$1F,$FF,$1F,$FE,$1F,$FC
	.byte $0E,$F8,$00,$F0,$00,$80,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$80,$00,$80,$00
	.byte $80,$00,$80,$00,$80,$00,$80,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$FF
	.byte $00,$FF,$00,$FF,$00,$FF,$00,$FF
	.byte $00,$FF,$FF,$FF,$FF,$FF,$FF,$FF
LvlNormalDataPF2:
	.byte $00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$07,$00,$07,$00,$07,$00,$07
	.byte $00,$03,$00,$03,$00,$00,$80,$00
	.byte $80,$00,$80,$00,$80,$00,$E0,$00
	.byte $E0,$00,$E0,$F8,$E0,$F8,$F0,$F8
	.byte $FF,$F8,$FF,$F8,$FF,$F8,$FF,$F8
	.byte $FE,$F0,$FE,$E0,$F0,$E0,$F0,$E0
	.byte $F0,$E0,$F0,$E0,$E0,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$FC,$00,$FC,$00,$FC
	.byte $1F,$FC,$1F,$FC,$1F,$FC,$0E,$FC
	.byte $0E,$FC,$06,$F8,$00,$F8,$00,$F8
	.byte $00,$F8,$00,$F0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$E0,$E0
	.byte $E1,$E0,$E1,$E0,$C1,$E0,$C1,$E0
	.byte $C0,$E0,$80,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$00,$E0
	.byte $00,$E0,$00,$E0,$00,$E0,$07,$E0
	.byte $07,$E0,$07,$E0,$07,$E0,$FF,$FF
	.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
	.byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF

; LevelNormal:
; 	.byte $F0,$80,$00,$00,$00,$00 ;|XXXXX               ||                    | ( 0)
; 	.byte $F0,$80,$00,$00,$00,$00 ;|XXXXX               ||                    | ( 1)
; 	.byte $F0,$80,$00,$00,$00,$00 ;|XXXXX               ||                    | ( 2)
; 	.byte $F0,$80,$00,$00,$00,$00 ;|XXXXX               ||                    | ( 3)
; 	.byte $F0,$00,$00,$00,$01,$07 ;|XXXX                ||           XXXX     | ( 4)
; 	.byte $70,$00,$00,$E0,$01,$07 ;|XXX                 || XXX       XXXX     | ( 5)
; 	.byte $70,$00,$00,$E0,$01,$07 ;|XXX                 || XXX       XXXX     | ( 6)
; 	.byte $30,$00,$00,$E0,$01,$07 ;|XX                  || XXX       XXXX     | ( 7)
; 	.byte $30,$00,$00,$E0,$01,$03 ;|XX                  || XXX       XXX      | ( 8)
; 	.byte $30,$00,$00,$E0,$C0,$03 ;|XX                  || XXXXX      XX      | ( 9)
; 	.byte $30,$00,$00,$E0,$C0,$00 ;|XX                  || XXXXX              | (10)
; 	.byte $30,$00,$80,$F0,$C0,$00 ;|XX                 X||XXXXXX              | (11)
; 	.byte $30,$00,$80,$F0,$C0,$00 ;|XX                 X||XXXXXX              | (12)
; 	.byte $30,$00,$80,$F0,$F8,$00 ;|XX                 X||XXXXXXXXX           | (13)
; 	.byte $30,$00,$80,$F0,$F8,$00 ;|XX                 X||XXXXXXXXX           | (14)
; 	.byte $30,$00,$E0,$F0,$F8,$00 ;|XX               XXX||XXXXXXXXX           | (15)
; 	.byte $30,$00,$E0,$F0,$F8,$00 ;|XX               XXX||XXXXXXXXX           | (16)
; 	.byte $30,$00,$E0,$F0,$F8,$F8 ;|XX               XXX||XXXXXXXXX      XXXXX| (17)
; 	.byte $70,$00,$E0,$F0,$F8,$F8 ;|XXX              XXX||XXXXXXXXX      XXXXX| (18)
; 	.byte $70,$00,$F0,$F0,$F0,$F8 ;|XXX             XXXX||XXXXXXXX       XXXXX| (19)
; 	.byte $70,$00,$FF,$F0,$F0,$F8 ;|XXX         XXXXXXXX||XXXXXXXX       XXXXX| (20)
; 	.byte $F0,$80,$FF,$F0,$E0,$F8 ;|XXXXX       XXXXXXXX||XXXXXXX        XXXXX| (21)
; 	.byte $F0,$80,$FF,$F0,$C0,$F8 ;|XXXXX       XXXXXXXX||XXXXXX         XXXXX| (22)
; 	.byte $F0,$80,$FF,$F0,$C0,$F8 ;|XXXXX       XXXXXXXX||XXXXXX         XXXXX| (23)
; 	.byte $F0,$80,$FE,$F0,$C0,$F0 ;|XXXXX        XXXXXXX||XXXXXX          XXXX| (24)
; 	.byte $F0,$80,$FE,$F0,$80,$E0 ;|XXXXX        XXXXXXX||XXXXX            XXX| (25)
; 	.byte $F0,$80,$F0,$F0,$80,$E0 ;|XXXXX           XXXX||XXXXX            XXX| (26)
; 	.byte $70,$00,$F0,$F0,$00,$E0 ;|XXX             XXXX||XXXX             XXX| (27)
; 	.byte $70,$00,$F0,$F0,$00,$E0 ;|XXX             XXXX||XXXX             XXX| (28)
; 	.byte $30,$00,$F0,$30,$00,$E0 ;|XX              XXXX||XX               XXX| (29)
; 	.byte $30,$00,$E0,$10,$00,$E0 ;|XX               XXX||X                XXX| (30)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (31)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (32)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (33)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (34)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (35)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (36)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (37)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (38)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (39)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (40)
; 	.byte $30,$00,$00,$00,$00,$FC ;|XX                  ||              XXXXXX| (41)
; 	.byte $30,$00,$00,$00,$00,$FC ;|XX                  ||              XXXXXX| (42)
; 	.byte $30,$00,$00,$00,$00,$FC ;|XX                  ||              XXXXXX| (43)
; 	.byte $F0,$F8,$1F,$00,$00,$FC ;|XXXXXXXXX   XXXXX   ||              XXXXXX| (44)
; 	.byte $F0,$F8,$1F,$00,$00,$FC ;|XXXXXXXXX   XXXXX   ||              XXXXXX| (45)
; 	.byte $F0,$F8,$1F,$00,$00,$FC ;|XXXXXXXXX   XXXXX   ||              XXXXXX| (46)
; 	.byte $F0,$F8,$0E,$00,$00,$FC ;|XXXXXXXXX    XXX    ||              XXXXXX| (47)
; 	.byte $F0,$F8,$0E,$00,$E0,$FC ;|XXXXXXXXX    XXX    ||    XXX       XXXXXX| (48)
; 	.byte $F0,$E0,$06,$00,$E0,$F8 ;|XXXXXXX      XX     ||    XXX        XXXXX| (49)
; 	.byte $F0,$E0,$00,$00,$E0,$F8 ;|XXXXXXX             ||    XXX        XXXXX| (50)
; 	.byte $F0,$C0,$00,$00,$E0,$F8 ;|XXXXXX              ||    XXX        XXXXX| (51)
; 	.byte $F0,$00,$00,$00,$E0,$F8 ;|XXXX                ||    XXX        XXXXX| (52)
; 	.byte $30,$00,$00,$00,$E0,$F0 ;|XX                  ||    XXX         XXXX| (53)
; 	.byte $30,$00,$00,$00,$E0,$E0 ;|XX                  ||    XXX          XXX| (54)
; 	.byte $30,$00,$00,$80,$E0,$E0 ;|XX                  ||   XXXX          XXX| (55)
; 	.byte $30,$00,$00,$80,$E0,$E0 ;|XX                  ||   XXXX          XXX| (56)
; 	.byte $30,$00,$00,$F0,$E0,$E0 ;|XX                  ||XXXXXXX          XXX| (57)
; 	.byte $30,$00,$00,$F0,$E0,$E0 ;|XX                  ||XXXXXXX          XXX| (58)
; 	.byte $30,$00,$00,$F0,$E0,$E0 ;|XX                  ||XXXXXXX          XXX| (59)
; 	.byte $30,$00,$00,$F0,$F8,$E0 ;|XX                  ||XXXXXXXXX        XXX| (60)
; 	.byte $30,$00,$00,$F0,$FF,$E0 ;|XX                  ||XXXXXXXXXXXX     XXX| (61)
; 	.byte $30,$00,$00,$F0,$FF,$E0 ;|XX                  ||XXXXXXXXXXXX     XXX| (62)
; 	.byte $30,$00,$E0,$F0,$FF,$E0 ;|XX               XXX||XXXXXXXXXXXX     XXX| (63)
; 	.byte $30,$1F,$E1,$F0,$FF,$E0 ;|XX     XXXXXX    XXX||XXXXXXXXXXXX     XXX| (64)
; 	.byte $30,$1F,$E1,$F0,$FF,$E0 ;|XX     XXXXXX    XXX||XXXXXXXXXXXX     XXX| (65)
; 	.byte $30,$1F,$C1,$F0,$FE,$E0 ;|XX     XXXXXX     XX||XXXXXXXXXXX      XXX| (66)
; 	.byte $30,$1F,$C1,$F0,$FC,$E0 ;|XX     XXXXXX     XX||XXXXXXXXXX       XXX| (67)
; 	.byte $30,$0E,$C0,$F0,$F8,$E0 ;|XX      XXX       XX||XXXXXXXXX        XXX| (68)
; 	.byte $30,$00,$80,$F0,$F0,$E0 ;|XX                 X||XXXXXXXX         XXX| (69)
; 	.byte $30,$00,$00,$F0,$80,$E0 ;|XX                  ||XXXXX            XXX| (70)
; 	.byte $30,$00,$00,$60,$00,$E0 ;|XX                  || XX              XXX| (71)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (72)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (73)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (74)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (75)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (76)
; 	.byte $30,$00,$00,$00,$00,$E0 ;|XX                  ||                 XXX| (77)
; 	.byte $F0,$80,$00,$00,$00,$E0 ;|XXXXX               ||                 XXX| (78)
; 	.byte $F0,$80,$00,$00,$00,$E0 ;|XXXXX               ||                 XXX| (79)
; 	.byte $F0,$80,$00,$00,$00,$E0 ;|XXXXX               ||                 XXX| (80)
; 	.byte $F0,$80,$00,$00,$00,$E0 ;|XXXXX               ||                 XXX| (81)
; 	.byte $F0,$80,$00,$00,$00,$E0 ;|XXXXX               ||                 XXX| (82)
; 	.byte $F0,$80,$07,$00,$00,$E0 ;|XXXXX       XXX     ||                 XXX| (83)
; 	.byte $F0,$00,$07,$00,$00,$E0 ;|XXXX        XXX     ||                 XXX| (84)
; 	.byte $70,$00,$07,$00,$00,$E0 ;|XXX         XXX     ||                 XXX| (85)
; 	.byte $30,$00,$07,$00,$00,$E0 ;|XX          XXX     ||                 XXX| (86)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (87)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (88)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (89)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (90)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (91)
; 	.byte $30,$00,$FF,$F0,$FF,$FF ;|XX          XXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (92)
; 	.byte $F0,$FF,$FF,$F0,$FF,$FF ;|XXXXXXXXXXXXXXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (93)
; 	.byte $F0,$FF,$FF,$F0,$FF,$FF ;|XXXXXXXXXXXXXXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (94)
; 	.byte $F0,$FF,$FF,$F0,$FF,$FF ;|XXXXXXXXXXXXXXXXXXXX||XXXXXXXXXXXXXXXXXXXX| (95)

	org $FFFA
	.word Start
	.word Start
	.word Start