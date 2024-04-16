;
; File Name  : Stoply.asm
;
; Author     : Jordan <3, Zander <3, Daniel
; Description: Traffic signal using LEDs, timers, ...
; ------------------------------------------------------------

.equ DELAY_CNT = 65536 - (1000000 / 16)         ; clk/256

.equ DELAY_S = 64                      ; sleep 1 second

; Vecotr Table
; ------------------------------------------------------------

.org 0x0000
          jmp       main

.org OVF1addr                                     ; Timer/Counter1 Overflow
          jmp       tm1_ISR   

.org INT_VECTORS_SIZE                             ; end vector table
; ------------------------------------------------------------
main:
; main application method
;         one-time setup & configuration
; ------------------------------------------------------------
       
; Intersection 1
;------------------------------------------------------------
          sbi       DDRB, DDB0                    ; Setting Red LED pin to output (B8)
          cbi       PORTB, PB0                    ; Turn LED off (B8)
          
          sbi       DDRB, DDB1                    ; Setting Yellow LED pin to output (B9)
          cbi       PORTB, PB1                    ; Turn LED off (B9)
          
          sbi       DDRB, DDB2                    ; Setting Green LED pin to output (B10)
          cbi       PORTB, PB2                    ; Turn LED off (B10)

; Intersection 2
;------------------------------------------------------------

          sbi       DDRB, DDB3                    ; Setting Green LED pin to output (B11)
          cbi       PORTB, PB3                    ; Turn LED off (B11)

          sbi       DDRB, DDB4                    ; Setting Yellow LED pin to output (B12)
          cbi       PORTB, PB4                    ; Turn LED off (B12)
          
          sbi       DDRB, DDB5                    ; Setting Red LED pin to output (B13)
          cbi       PORTB, PB5                    ; Turn LED off (B13)
          

; Set up:
;------------------------------------------------------------

          cbi       DDRD, DDD2                    ; Set Left Pedestrian Button pin to input (D2)
          sbi       PORTD, PD2                    ; Enable pull-up circuit

          sbi       EIMSK, INT0                   ; Enable external interrupt 0 for D2
          ldi       r20, 0b00000010               ; Falling-edge sense bits
          sts       EICRA, r20                    ; Store to EICRA (external interrupt control register A)

          call      tm1_init                      ; Initialize timer 1

          sei                                     ; Enable global interrupts
          

main_loop:                                        ; loop continuously  
; ------------------------------------------------------------
          


end_main:
          rjmp      main_loop           ; stay in main loop


; Timer Stuff
;-------------------------------------------------------------

tm1_init:
; ------------------------------------------------------------
          ldi       r20, HIGH(DELAY_CNT)          ; High byte of delay_cnt
          sts       TCNT1H, r20                   ; Store r20 to TCNT1H

          ldi       r20, LOW(DELAY_CNT)           ; Low byte of delay_cnt
          sts       TCNT1L, r20                   ; Store r20 to TCNT1L 

          clr       r20                           ; Normal Mode
          sts       TCCR1A, r20                   

          ldi       r20, (1<<CS12)                ; Normal Mode and C1k/256
          sts       TCCR1B, r20

          ldi       r20, (1<<TOIE1)               ; Enabling time roverflow interrupt
          sts       TIMSK1, r20                   

          ret                                     ; return tm1_init

tm1_ISR:
; ------------------------------------------------------------
          sbis      PINB, PINB2                   ; IF LED is not on
          rjmp      tm1_ISR_ON                    ; turn LED on
          rjmp      tm1_ISR_OFF                   ; Else turn LED off


          
tm1_ISR_ON:
          cbi       PORTB, PB4                    ; Turn green light off
          sbi       PORTB, PB3                    ; Turn yellow light on

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, PB3                    ; Turn yellow light off
          sbi       PORTB, PB5                    ; Turn red light on

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, PB0                    ; Turn red light off
          sbi       PORTB, PB2                    ; Turn green light on

          call      delay_ms                      ; Wait 1 second
          call      delay_ms                      ; Wait 1 second

          rjmp      tm1_ISR_ret

tm1_ISR_OFF:
          cbi       PORTB, PB2                    ; Turn green light off
          sbi       PORTB, PB1                    ; Turn yellow light on

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, PB1                    ; Turn yellow light off
          sbi       PORTB, PB0                    ; Turn red light on

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, PB5                    ; Turn red light off
          sbi       PORTB, PB4                    ; Turn green light on

          call      delay_ms                      ; Wait 1 second
          call      delay_ms                      ; Wait 1 second

          rjmp      tm1_ISR_ret


tm1_ISR_ret:
          ldi       r20, HIGH(DELAY_CNT)          ; Reset timer counter
          sts       TCNT1H, r20                   
                                                  
          ldi       r20, LOW(DELAY_CNT)           
          sts       TCNT1L, r20                   

          reti                                    ; tm1_ISR

; ------------------------------------------------------------
delay_ms:
; creates a timed delay using multiple nested loops
; ------------------------------------------------------------
          ldi       r18,DELAY_S
delay_ms_1:

          ldi       r17,200
delay_ms_2:

          ldi       r16,250
delay_ms_3:
          nop
          nop
          dec       r16
          brne      delay_ms_3          ; 250 * 5 = 1250

          dec       r17
          brne      delay_ms_2          ; 200 * 1250 = 250K

          dec       r18
          brne      delay_ms_1          ; 16 * 250K = 4M (1/4s ex)
dealy_ms_end:
          ret
