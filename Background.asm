SetBackground:
		JSR	TransferNametable
		JMP	TransferPalette

TransferNametable_DstAddr	= $21B4
BackgroundRleDataIndex		= ScratchMemory + 0
BackgroundTileNumber		= ScratchMemory + 1

TransferNametable:
		; A		= zero
		; X		= tile count
		; Y		= tile number
		; Scratch[0]	= RLE data count / index
		; Scratch[1]	= temporary Y
		PPU_SetDestinationAddress	TransferNametable_DstAddr

		LDA	#(TransferNametableDataLength-1)
		STA	<BackgroundRleDataIndex
		TAY
		LDA	#$00
		TAX
		STA	<BackgroundTileNumber

.RleSetLoop
		LDX	.Data,y
		DEY
.ZeroLoop	STA	IO_PPU_VRAMAccess
		DEX
		BNE	.ZeroLoop

		LDX	.Data,y
		DEY
		STY	<BackgroundRleDataIndex
		LDY	<BackgroundTileNumber
.TileLoop	INY
		STY	IO_PPU_VRAMAccess
		DEX
		BNE	.TileLoop

		STY	<BackgroundTileNumber
		LDY	<BackgroundRleDataIndex
		BPL	.RleSetLoop
		RTS

.Data
	;	tile,zero,tile,zero,...
	.db	$12, $0E, $12, $0E, $12, $0E, $12, $0E
	.db	$12, $0E, $11, $0F, $11, $10, $10, $10
	.db	$0F, $11, $0F, $12, $0D, $13, $0D, $13
	.db	$0D, $14, $0D, $13, $0B, $16, $09, $18
	.db	$07, $13
.DataEnd
TransferNametableDataLength	= .DataEnd-.Data

TransferPalette:
		PPU_SetDestinationAddress	$3F00
		TAX	; A, X = #$00

.Loop		LDA	.Data,x
		STA	IO_PPU_VRAMAccess
		INX
		CPX	#TransferPaletteDataLength
		BNE	.Loop
		RTS

.Data
	.db	$21, $04, $24, $34
.DataEnd
TransferPaletteDataLength	= .DataEnd-.Data
