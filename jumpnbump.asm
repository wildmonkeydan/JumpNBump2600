; JUMP 'N' BUMP
; Original game by Brainchild Design
; Demake by Midnight Mirage Softworks
	processor 6502
	include vcs.h
	include macro.h

; CONSTANTS

;NTSC = 1

;	IF NTSC
BKCOL = 79
P2BCOL = $FE
;	ELSE
;BKCOL = #154
;P2BCOL = $28
;	ENDIF

P1BCOL = $0E

	seg		CONSTS
	org		$0



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
; --- end ----

NegativeMask	= %10000000

;Input -- Taken from Pitfall!

MoveLeft       	= %1011
MoveRight      	= %0111
NoMove			= %1111
JoyLeft        	= ~MoveLeft  & NoMove
JoyRight      	= ~MoveRight & NoMove

; Bunny state masks

BunnyJoyMask	= %00000001
BunnyDeathMask	= %00000010

; Bunny Consts
JumpForce		= 64
GravityForce	= %11111100	;-12

	seg	   	RAM
    org     $80

; Bunny Struct (5 Bytes)
; Velocity(Vertical Fixed 4:4) - 1 Byte
; Position - 2 Bytes
; State - 1 Byte
; Score - 1 Byte

B0_VelY			.byte
B0_PosX			.byte
B0_PosY			.byte
B0_State		.byte
B0_Score		.byte

B1_VelY			.byte
B1_PosX			.byte
B1_PosY			.byte
B1_State		.byte
B1_Score		.byte

CurrentBPtr		.word
CurrentBunny	.byte

Joystick		.byte			;stores joystick directions
Button			.byte			;stores button state

Workspace		.byte			;for random calculations that need some memory

	seg 	CODE
	org 	$F000, 0

Start
	CLEAN_START

	lda 	BKCOL
	sta 	COLUBK  			;set blackground 	
	;lda 	$22    
	;sta 	COLUPF  			;set playfield colour
	lda 	P1BCOL
	sta 	COLUP0				;set player0 colour
	lda 	P2BCOL
	sta 	COLUP1				;set player1 colour

;MainLoop starts with usual VBLANK code,
;and the usual timer seeding
MainLoop
	VERTICAL_SYNC
	lda #15		
	sta TIM64T
	lda #<B0_PosX
	ldx #>B0_PosX
	sta CurrentBPtr
	sta CurrentBPtr + 1

UpdatePlayer
	lda		SWCHA
	lsr
	lsr
	sta		Joystick			;load joystick state - cut off up and down as we don't need it

	ldx		#3
	lda		CurrentBPtr,x		;check if player 1, if the bunny is then shift the bits appropriately
	eor		#BunnyJoyMask
	and		#BunnyJoyMask
	bne		ReadJoystick2Button

Joystick1Shifting
	lda		SWCHA
	lsr
	lsr
	lsr
	lsr
	sta 	Joystick

ReadJoystick1Button
	lda		INPT4-$30
	and    	NegativeMask
    cmp   	Button
    sta    	Button
	jmp		CalculateVelocity

ReadJoystick2Button
	lda		INPT5-$30
	and    	NegativeMask
    cmp   	Button
    sta    	Button

CalculateVelocity
	ldx 	#1
	ldy 	CurrentBPtr,x		;load PosX into a

CheckLeft
	lda		Joystick			;check if left is pressed
	lsr
	bcs		CheckRight

	dey							;x--

CheckRight
	lda		Joystick			;check if right is pressed
	bcs 	CheckButton

	iny							;x++

CheckButton
	sty		CurrentBPtr,x		;store modified x coord
	lda 	#0
	ldx		#0
	cmp 	Button
	beq		ApplyVelocity		;check if button pressed

	lda		CurrentBPtr,x
	adc		JumpForce
	sta		CurrentBPtr,x

ApplyVelocity
	lda		CurrentBPtr,x
	sta		Workspace
	bit		Workspace
	beq		NegativeVelocity

PositiveVeloicty
	lsr
	lsr
	lsr

	ldx		#2
	lda		CurrentBPtr,x
	adc		Workspace
	sta		CurrentBPtr,x
	jmp		CollisionCheck

NegativeVelocity
	eor		#$FF				;bitwise NOT
	tax
	inx							;increment, part of 2's complement conversion
	txa
	lsr
	lsr
	lsr

	ldx		#2
	lda		CurrentBPtr,x
	sbc		Workspace
	sta		CurrentBPtr,x

CollisionCheck
	bit 	CXPPMM				;bit check P0-P1 collsion - N flag should equal colision bit

	sta CurrentBunny
	bne	WaitForVblankEnd	
	
	ldx #>B1_PosX
	lda #<B1_PosX
	sta CurrentBPtr + 1
	sta CurrentBPtr
	inc CurrentBunny
	jmp UpdatePlayer

WaitForVblankEnd
	lda 	INTIM	
	bne 	WaitForVblankEnd	
	sta 	VBLANK  	


;so, scanlines. We have three loops; 
;TitlePreLoop , TitleShowLoop, TitlePostLoop
;
; I found that if the 3 add up to 174 WSYNCS,
; you should get the desired 262 lines per frame
;
; The trick is, the middle loop is 
; how many pixels are in the playfield,
; times how many scanlines you want per "big" letter pixel 

pixelHeightOfTitle = #6
scanlinesPerTitlePixel = #6

; ok, that's a weird place to define constants, but whatever


;just burning scanlines....you could do something else
	ldx #40
	ldy #57

TitlePreLoop
; we color the pre title area
	sta WSYNC
	;stx COLUBK
	inx 	
	dey
	bne TitlePreLoop


	lda #00 		; reset background color
	sta COLUBK
	sta WSYNC 		; create some padding
	sta WSYNC
	sta WSYNC


;
;the next part is careful cycle counting from those 
;who have gone before me....
	
; Ball code
	lda #150			; set ball color
	sta COLUPF 
	lda #%0101000		; set ball stretch
	sta CTRLPF

	lda #%00000010		; enable the ball
	sta ENABL
	sta WSYNC 			; not elegan to set the ball thinkness :)
	sta WSYNC
	sta WSYNC

; move the ball!
	lda #10
	ldx #4 				; Ball sprite id for SetHozPos subroutine
	jsr SetHorizPos
	sta WSYNC
	sta HMOVE
	sleep 15
	lda #%00000000		; disable the ball 
	sta ENABL

	ldx #pixelHeightOfTitle ; X will hold what letter pixel we're on
	ldy #scanlinesPerTitlePixel ; Y will hold which scan line we're on for each pixel

	lda #45   
	sta COLUPF 

TitleShowLoop	
	sta WSYNC
	lda PFData0Left-1,X           ;[0]+4
	sta PF0                 ;[4]+3 = *7*   < 23	;PF0 visible
	lda PFData1Left-1,X           ;[7]+4
	sta PF1                 ;[11]+3 = *14*  < 29	;PF1 visible
	lda PFData2Left-1,X           ;[14]+4
	sta PF2                 ;[18]+3 = *21*  < 40	;PF2 visible
	nop			;[21]+2
	nop			;[23]+2
	nop			;[25]+2
	;six cycles available  Might be able to do something here
	lda PFData0Right-1,X          ;[27]+4
	;PF0 no longer visible, safe to rewrite
	sta PF0                 ;[31]+3 = *34* 
	lda PFData1Right-1,X		;[34]+4
	;PF1 no longer visible, safe to rewrite
	sta PF1			;[38]+3 = *41*  
	lda PFData2Right-1,X		;[41]+4
	;PF2 rewrite must begin at exactly cycle 45!!, no more, no less
	sta PF2			;[45]+2 = *47*  ; >
	 
	dey ;ok, we've drawn one more scaneline for this 'pixel'
	bne NotChangingWhatTitlePixel ;go to not changing if we still have more to do for this pixel
	dex ; we *are* changing what title pixel we're on...

	beq DoneWithTitle ; ...unless we're done, of course
	
	ldy #scanlinesPerTitlePixel ;...so load up Y with the count of how many scanlines for THIS pixel...

NotChangingWhatTitlePixel
	
	jmp TitleShowLoop

DoneWithTitle	
	
	;clear out the playfield registers for obvious reasons	
	lda #0
	sta PF2 ;clear out PF2 first, I found out through experience
	sta PF0
	sta PF1

;just burning scanlines....you could do something else
	ldy #137
	ldx #100 		; 40 + 60 (pretitle lines) so we start from the last color
TitlePostLoop
	sta WSYNC
	stx COLUBK
	inx 
	dey
	bne TitlePostLoop

; usual vblank
	lda #2		
	sta VBLANK 	
	ldx #30		
	lda #0
	sta CurrentBunny
	lda #157
	sta COLUBK
OverScanWait
	sta WSYNC
	dex
	bne OverScanWait
	jmp  MainLoop      

; Subroutine to move horizontally a sprite  
SetHorizPos 
	sta WSYNC		; start a new line
	bit 0
	bit 0			; waste 6 cycles for tuning object speed
	sec				; set carry flag
DivideLoop
	sbc #50			; this value determines the direction of motion, 35 is steady
	bcs DivideLoop	; branch until negative
	eor #7			; calculate fine offset
	asl
	asl
	asl
	asl
	sta HMP0,x	; set fine offset
	rts		; return to calle
;
; the graphics for Kynetics title 
; PlayfieldPal at https://alienbill.com/2600/playfieldpal.html
; to draw these things. Just rename them left and right

PFData0Left
        .byte #%00000000
        .byte #%10000000
        .byte #%10000000
        .byte #%10000000
        .byte #%10000000
        .byte #%10000000
        .byte #%00000000
        .byte #%00000000

PFData1Left
        .byte #%00000000
        .byte #%00100100
        .byte #%00100100
        .byte #%11000000
        .byte #%10001110
        .byte #%00101010
        .byte #%00000000
        .byte #%00000000

PFData2Left
        .byte #%00000000
        .byte #%01100101
        .byte #%00010101
        .byte #%01010101
        .byte #%00010111
        .byte #%01100001
        .byte #%00000000
        .byte #%00000000

PFData0Right
        .byte #%00000000
        .byte #%00100000
        .byte #%00100000
        .byte #%00100000
        .byte #%00000000
        .byte #%01110000
        .byte #%00000000
        .byte #%00000000

PFData1Right
        .byte #%00000000
        .byte #%10011001
        .byte #%10100100
        .byte #%10100000
        .byte #%00100101
        .byte #%10011000
        .byte #%00000000
        .byte #%00000000

PFData2Right
        .byte #%00000000
        .byte #%00000011
        .byte #%00000100
        .byte #%00000011
        .byte #%00000000
        .byte #%00000111
        .byte #%00000000
        .byte #%00000000



	org $FFFC
	.word Start
	.word Start