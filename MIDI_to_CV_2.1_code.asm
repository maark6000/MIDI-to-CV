;************************************************************************
;MIDI to CV
;August 5th, 2015  © Mark J. Jensen
;Coin Slot 2.1 Version
;status:  tested and working.  
;************************************************************************
    
    list    p=16f873A
    #include <p16f873a.inc>
    
    ; CONFIG
    ; __config 0xFF31
 __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_OFF & _CP_OFF
    
    
    ;crystal speed 4 MHz
    
    ;RA0    gate out		    (o)
    ;RA1    trig out		    (o)
    ;RA2    LED test		    (o)
    ;RA3    timing blip		    (o)
    ;RA4    (unused)		    (o)
    ;RA5    (unused)		    (o)
    
    ;RB0    channel LSB		    (i)
    ;RB1    .			    (i)
    ;RB2    .			    (i)
    ;RB3    channel MSB		    (i)
    ;RB4    channel voltage high    (o)
    ;RB5    (unused)		    (o) 
    ;RB6    (unused)		    (o) 
    ;RB7    (unused)		    (o) 
    
    ;RC0    MIDI OUT LSB	    (o)
    ;RC1    .			    (o)
    ;RC2    .			    (o)
    ;RC3    .			    (o)
    ;RC4    .			    (o)
    ;RC5    .			    (o)
    ;RC6    MIDI OUT MSB	    (o)
    ;RC7    MIDI IN		    (i)
    
    ;register assignment
    
chan	    equ	20	;holds desired MIDI channel
bytea	    equ	21	;current byte A
byteb	    equ	22	;current byte B
bytec	    equ	23	;current byte C
tempbyte    equ	24	;register read loop loads
currstat    equ	25	;the current status
currnote    equ	26	;the current note
statnum	    equ	27	;assigns a number given a status
RSflag	    equ	28	;flag is set if Running Status is on
Ztmr	    equ	30	;fastest timer
Ytmr	    equ	31	;next level up timer
	
	org 0000
	goto intport
	org 0010
	
intport
	BCF     STATUS, RP0	;
	BCF     STATUS, RP1	; Bank0
	CLRF    PORTA		; Initialize PORTA by clearing output data latches
	BSF     STATUS, RP0	; Select Bank 1
	MOVLW   0x06		; Configure all pins as digital inputs
	MOVWF   ADCON1		;
	MOVLW   0x00		; Value used to initialize data direction
	MOVWF   TRISA		;   
	
	
	movlw 0x0F	    ;0000 1111
	movwf trisb
	
	movlw 0x80	    ;1000 0000
	movwf trisc
	
	bcf status, rp0
	bcf status, rp1	    ;select bank 00
	
	
	clrf porta
	clrf portb
	clrf currstat
	clrf currnote
	clrf statnum
	clrf RSflag
	bsf porta,1	    ;sets trig high as trigs on low
	clrdc
	clrc 
	clrz
	clrw
	
	call test


;read channel
	clrf chan
	bsf portb,4	    ;set channel reader voltage high
	clrc
	btfsc portb,3	    ;read MSB
	incf chan,f
	rlf chan,f
	btfsc portb,2	    ;.
	incf chan,f
	rlf chan,f
	btfsc portb,1	    ;.
	incf chan,f
	rlf chan,f
	btfsc portb,0	    ;read LSB
	incf chan,f
	bcf portb,4	    ;set channel reader voltage low
	
;read MIDI note
	
full	clrf RSflag
	
half	bsf porta,1	    ;clears trig
mn	btfss portc,7	    ;wait for midi input to be 1
	goto mn
	clrf statnum	    ;clears statnum
	;bsf porta,3	    ;timing blips
	;bcf porta,3
	
waita	btfsc portc,7	    ;wait for start bit of byte A
	goto waita
	clrf bytea
	call dela
	call readloop	    ;read byte A
	movf tempbyte,w	    ;move tempbyte to byte A
	movwf bytea
	call rtatst	    ;tests for RealTime byte
	call datatst	    ;tests if word is data
	call tstchn	    ;tests if channels match
	bsf porta,3	    ;timing
	bcf porta,3
	
waitb	btfsc portc,7	    ;wait for start of byte B
	goto waitb
	clrf byteb
	call delb
	call readloop	    ;read byte B
	movf tempbyte,w	    ;move tempbyte to byte B
	movwf byteb
	call rtbtst	    ;filter out RealTime byte
	call btest
	bsf porta,3	    ;timing
	bcf porta,3
	
waitc	btfsc portc,7
	goto waitc
	clrf bytec
	call delc
	call readloop	    ;read byte C
	movf tempbyte,w	    ;move tempbyte to byte C
	movwf bytec
	call rtctst	    ;filter out RealTime byte
	call stattst
	
	
;commands
	
noteon	movf bytec,f	    ;tests if velocity = 00
	btfsc status,z
	goto velzero
	movf bytea,w
	movwf currstat
	movf byteb,w
	movwf currnote
	movwf portc	    ;sends note data to portc
	bsf porta,0	    ;set gate high
	bcf porta,1	    ;trigger trig
	bsf RSflag,0	    ;sets Running Status flag
	goto half
	
noteoff	movf byteb,w	    ;test if note to turn off is curr. note
	xorwf currnote,w
	btfss status,z
	goto half	    ;received an 8n but not for curr. note
	bcf porta,0	    ;sets gate low
	bsf porta,1	    ;resets trig
	goto full
	
velzero movf byteb,w	    ;test if note to turn off is curr. note
	xorwf currnote,w
	btfss status,z
	goto half
	bcf porta,0	    ;sets gate low
	bsf porta,1	    ;resets trig
	goto half
	
;tests
	
datatst	btfss bytea,7	    ;test if MSB of byte A is a 0
	goto rstst
	return
	
rstst	btfss RSflag,0	    ;tests if byte is Running Status
	goto full	    ;byte is data but not Running Status
	movf bytea,w
	movwf byteb
	movf currstat,w
	movwf bytea
	call twoadd
	goto waitc
	
rtatst	swapf bytea,w	    ;filters out RealTime byte
	andlw 0x0F
	xorlw 0x0F
	btfsc status,z
	goto half
	return
	
btest	swapf bytea,w
	andlw 0x0F
	sublw D'14'	    
	addwf PCL,f
	
	goto fivadd	    ;En
	goto full	    ;Dn
	goto full	    ;Cn
	goto fouadd	    ;Bn
	goto thradd	    ;An
	goto twoadd	    ;9n
	goto oneadd	    ;8n
	
rtbtst	swapf bytea,w	    ;filters out RealTime byte
	andlw 0x0F
	xorlw 0x0F
	btfsc status,z
	goto waitb
	return
	
rtctst	swapf bytea,w	    ;filters out RealTime byte
	andlw 0x0F
	xorlw 0x0F
	btfsc status,z
	goto waitc
	return
	
tstchn	movlw 0x0F	    ;tests channel
	andwf bytea,w
	xorwf chan,w
	btfss status,z
	goto sixadd
	return
	
oneadd	movlw D'1'
	addwf statnum,f
	return
	
twoadd	movlw D'2'
	addwf statnum,f
	return
	
thradd	movlw D'3'
	addwf statnum,f
	return
	
fouadd	movlw D'4'
	addwf statnum,f
	return
	
fivadd	movlw D'5'
	addwf statnum,f
	return
	
sixadd	movlw D'6'
	addwf statnum,f
	clrf RSflag	    ;clears RS if MIDI channel switches
	return
	
stattst	movf statnum,w
	addwf PCL,f
	
	nop		    ;0
	goto noteoff	    ;8n
	goto noteon	    ;9n
	goto full	    ;An
	goto full	    ;Bn
	goto full	    ;En
	goto half	    ;channel mismatch
	goto half	    ;statnum was a 7?
	goto half	    ;statnum = 8, 9n plus channel mismatch
	goto half	    ;9 (everything hereafter, just in case!)
	goto half	    ;10
	goto half	    ;11
	goto half	    ;12
	
	
;read loop
	
readloop    
	clrf tempbyte
	clrc
	
	nop
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 1
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 2
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit    
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 3
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 4
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 5
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 6
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 7
	bsf tempbyte,7
	bcf porta,3	    ;timing
	nop 
	call delbit
	
	rrf tempbyte,f
	bsf porta,3	    ;timing
	btfsc portc,7	    ;read bit 8
	bsf tempbyte,7
	bcf porta,3	    ;timing
	
	return
	
	
	
	
;delays
	
dela	movlw D'10'
	movwf Ztmr
	call ZZZ
	return
	
delb	movlw D'10'
	movwf Ztmr
	call ZZZ
	return
	
delc	movlw D'10'
	movwf Ztmr
	call ZZZ
	return
	
delbit	movlw D'5'	;interbit delay
	nop
	movwf Ztmr
	call ZZZ
	return
	
YYY	movlw 0xFF
	movwf Ztmr
YY	decf Ytmr,f
	btfsc status,z
	return
	call ZZZ
	goto YY
	
ZZZ	nop
ZZ	decfsz Ztmr,f
	goto ZZ
	return
	
;function test
	
test	bsf porta,2	    ;flashes gate LED twice for 200ms
	movlw D'255'
	movwf Ytmr
	call YYY
	bcf porta,2
	movlw D'255'
	movwf Ytmr
	call YYY
	bsf porta,2
	movlw D'255'
	movwf Ytmr
	call YYY
	bcf porta,2
	return
	

	
	
	end
	
	
	
    
    
    
    
    
    
    
    
    





