;--------------------------------------------------
; H-Blank palette transfer demo (revision 3)
;--------------------------------------------------

;--------------------------------------------------
; Setting
;--------------------------------------------------
PrgCount	= 1
Mapper		= 4

	.inesprg PrgCount	; PRG Bank
	.ineschr 1		; CHR Bank
	.inesmir 1		; Mirror
	.inesmap Mapper		; Mapper

;--------------------------------------------------
; Include
;--------------------------------------------------
	.include	"Include/IOName_Standard.asm"
	.if Mapper = 4
	.include	"Include/IOName_MMC3.asm"
	.endif
	.include	"Include/Library_Macro.asm"
	.include	"RamMap.asm"

;--------------------------------------------------
; Interrupt
;--------------------------------------------------
	.bank PrgCount*2-1
	.org $FFF9
IRQ:		RTI

	.dw NMI
	.dw RST
	.dw IRQ

;--------------------------------------------------
; Define
;--------------------------------------------------

Palette_Black	= $0F

;--------------------------------------------------
; PRG
;--------------------------------------------------
	.bank PrgCount*2-1
	.org $FC00

RST:
		SEI
		CLD

		WaitVBlank

		LDA	#$00
		STA	IO_PPU_Setting
		STA	IO_PPU_Display

		TAX
.InitializeMemory
		STA	<$00,x
		PHA					; STA	$0100,x
		STA	$0200,x
		STA	$0300,x
		STA	$0400,x
		STA	$0500,x
		STA	$0600,x
		STA	$0700,x
		INX
		BNE	.InitializeMemory
		DEX
		TXS					; SP = #$FF

		WaitVBlank

		PPU_SetDestinationAddress	$2000	; A = #$00
.NametableClear	STA	IO_PPU_VRAMAccess		; $2000
		STA	IO_PPU_VRAMAccess		; $2100
		STA	IO_PPU_VRAMAccess		; $2200
		STA	IO_PPU_VRAMAccess		; $2300
		STA	IO_PPU_VRAMAccess		; $2400
		STA	IO_PPU_VRAMAccess		; $2500
		STA	IO_PPU_VRAMAccess		; $2600
		STA	IO_PPU_VRAMAccess		; $2700
		DEX
		BNE	.NametableClear

		PPU_SetDestinationAddress	$3F00
		LDA	#Palette_Black
		LDX	#$20
.PaletteClear	STA	IO_PPU_VRAMAccess
		DEX
		BNE	.PaletteClear

	.if Mapper = 4
		; Initialize mapper
		LDX	#$00				;\
		LDY	#$00				; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PPU[$0000](#0) = $00
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		INY					; |   PPU[$0800](#1) = $02
		STX	IO_MMC3_BankSelect		; |
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		INY					; |   PPU[$1000](#2) = $04(Sprite)
		STX	IO_MMC3_BankSelect		; |
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PPU[$1400](#3) = $05(Sprite)
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PPU[$1800](#4) = $06(Sprite)
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PPU[$1C00](#5) = $07(Sprite)
		STY	IO_MMC3_BankData		;/
		INX					;\
		LDY	#$00				; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PRG[$8000](#6) = $00
		STY	IO_MMC3_BankData		;/
		INX					;\
		INY					; | Set Bank
		STX	IO_MMC3_BankSelect		; |   PRG[$A000](#7) = $01
		STY	IO_MMC3_BankData		;/
		STY	IO_MMC3_Mirroring		;\  Mirroring = Horizontal
		STY	IO_MMC3_IRQDisable		;/  IRQ Disable
	.endif

		WaitVBlank

		JSR	CopyUpdateBackgroundColor
		JSR	SetBackground

		WaitVBlank
		LDA	IO_PPU_Status

		LDA	#%10001000			; NMI on, SP CHR = $1000
		STA	IO_PPU_Setting
		LDA	#$40				;\
		STA	IO_Controller_Port2		;/  APU IRQ Disable
		CLI

.InfLoop	JMP	.InfLoop

;--------------------------------------------------

	Align 256
		NOP
		NOP
		NOP

NMI:
		WaitCycle	340*10/3
		WaitCycle	340*9/3
		WaitCycle	119
		LDA	IO_PPU_Status

		LDY	#$10
.ScanlineLoop
		; #1
		WaitCycle	11-3-1
		STY	<ScanlineCounter
		JSR	UpdateBackgroundColor
		LDY	<ScanlineCounter
		INY

		; #2
		WaitCycle	11
		STY	<ScanlineCounter
		JSR	UpdateBackgroundColor
		LDY	<ScanlineCounter
		INY

		; #3
		WaitCycle	11
		STY	<ScanlineCounter
		JSR	UpdateBackgroundColor
		LDY	<ScanlineCounter
		INY
		BNE	.ScanlineLoop

		INC	<FrameCounter
		RTI

BackgroundPalette:	.db	$35,$36,$38,$3A,$3C,$31,$33,$34
.BackgroundPalette_End
BackgroundPaletteLength	= (.BackgroundPalette_End-BackgroundPalette)

UpdateBackgroundColor:
		TYA						;\
		ADD	<FrameCounter				; | X = scanline & #$07
		AND	#(BackgroundPaletteLength-1)		; | scanline++
		TAX						;/

		TYA						;\
		AND	#$F8					; |
		ASL	A					; | Precalculation scroll position of step 4
		ASL	A					; |
		STA	UpdateBackgroundColor_Offset_Scroll	;/

		LDA	<ScanlineCounter
		STA	UpdateBackgroundColor_Offset_Frame

		JMP	UpdateBackgroundColor_Ram

UpdateBackgroundColor_Rom:
		LDA	BackgroundPalette,x
		LDY	#$3F
		LDX	#$00					;\  BG,SP = OFF
		STX	IO_PPU_Display				;/
		STY	IO_PPU_VRAMAddress			;\  PPU Addr = $3F00
		STX	IO_PPU_VRAMAddress			;/
		STA	IO_PPU_VRAMAccess			;   Palette[0,0] = BackgroundPalette[X]

		; Set scroll
		STX	IO_PPU_VRAMAddress			;   1 Nametable
UpdateBackgroundColor_Rom_Frame:
		LDA	#$AA
		STA	IO_PPU_Scroll				;   2 Y
		STX	IO_PPU_Scroll				;   3 X
UpdateBackgroundColor_Rom_Scroll:
		LDA	#$BB
		STA	IO_PPU_VRAMAddress			;   4 (Y & 0xF8) << 2
		; 22

		LDA	#%00011110				;\  BG,SP = ON
		STA	IO_PPU_Display				;/
		RTS
.End
UpdateBackgroundColor_Length		= .End - UpdateBackgroundColor_Rom
UpdateBackgroundColor_Offset_Frame	= UpdateBackgroundColor_Ram + UpdateBackgroundColor_Rom_Frame  - UpdateBackgroundColor_Rom + 1
UpdateBackgroundColor_Offset_Scroll	= UpdateBackgroundColor_Ram + UpdateBackgroundColor_Rom_Scroll - UpdateBackgroundColor_Rom + 1

CopyUpdateBackgroundColor:
		LDX	#UpdateBackgroundColor_Length-1
.Loop		LDA	UpdateBackgroundColor_Rom,x
		STA	UpdateBackgroundColor_Ram,x
		DEX
		BPL	.Loop
		RTS

	.include "Background.asm"

;--------------------------------------------------
; CHR
;--------------------------------------------------
	.bank PrgCount*2

	; Background
	.org $0000
	.incbin	"Graphics/GFX_Background.bin"	; $00-$03 (BG)

	; Sprite
	.org $1000
	.incbin "Graphics/GFX_Blank.bin"	; $04-$05
	.org $1800
	.incbin "Graphics/GFX_Blank.bin"	; $06-$07


