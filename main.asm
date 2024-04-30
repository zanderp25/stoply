;
; File Name  : Stoply.asm
;
; Author     : Jordan <3, Zander <3, Daniel
; Description: Traffic signal using LEDs, timers, ...
; ------------------------------------------------------------

.equ delay_cnt = 65536 - (1000000 / 16)         ; clk/256
.equ DELAY_S = 64                               ; Delay ms main delay (1 second)

; Intersection A = Intersection 1/3                
.equ IntersectionAGreenLed = PB2
.equ IntersectionAYellowLed = PB1
.equ IntersectionARedLed = PB0

; Intersection B = Intersection 2/4  
.equ IntersectionBGreenLed = PB4
.equ IntersectionBYellowLed = PB3
.equ IntersectionBRedLed = PB5

; Pedestrian Lights
.equ PedestrianLightB = PD7
.equ PedestrianLightA = PD6

; Pedestrian buttons
.equ PedestrianButton = PD3

.def PedCnt = R21

; Pedestrian Timer Display
;         - 
;        | |
;         _
;        | |
;         _
; Enum for single digit display bars
.equ TopLeftBar = PD4
.equ TopBar = PC1
.equ TopRightBar = PC2
.equ MiddleBar = PD5
.equ BottomLeftBar = PC0
.equ BottomBar = PC3
.equ BottomRightBar = PC4

; Emergency Button
.equ Emergencybutton = PD2

; Set up an array of counters for each light
.equ aGreenCount = 0x0100
.equ aYellowCount = 0x0101
.equ aRedCount = 0x0102

; enum for the state of the traffic signal
.equ a_green = 0                                  ; Intersection A Green
.equ a_yellow = 1                                 ; Intersection A Yellow
.equ a_red = 2                                    ; Intersection A Red
.equ b_green = 3                                  ; Intersection B Green
.equ b_yellow = 4                                 ; Intersection B Yellow
.equ b_red = 5                                    ; Intersection B Red
.equ MAX_STATE = 6

.def mainCnt = r19
.def state = r18                                  ; State of the traffic signal
.def isUpdate = r17                               ; Flag to update the traffic signal

; Vector Table
; ------------------------------------------------------------

.org 0x0000
          jmp       main
.org INT0addr                                     ; Ext Int0 (PD2) for Emergency Button
          jmp       emergencyISR
.org OVF1addr                                     ; Timer/Counter1 Overflow
          jmp       timer1ISR   

.org INT_VECTORS_SIZE                             ; end vector table
; ------------------------------------------------------------
main:
; main application method
;         one-time setup & configuration
; ------------------------------------------------------------

          call      gpioInit                      ; Initalize Ports

; Set up:
;------------------------------------------------------------

          call      tm1_init                      ; Initialize timer 1

          call      counters_init                 ; Call the counters
          sei
main_loop:                                        ; loop continuously
          tst       isUpdate                      ; if (!isUpdate)
          breq      main_loop                     ;   continue
                                                  ; else {
          clr       isUpdate                      ;   isUpdate = false

          sbis      PIND, PedestrianButton        
          call      ped_btn_pressed

          tst       mainCnt                       ;   if (mainCnt > 0)
          brne      mainDecrement                 ;     goto decrement counter
                                                  ;   else
          call      led_update_but_better         ;     led_update_but_better()
          rjmp      endMain                       ;     continue

mainDecrement:
          dec       mainCnt                     

endMain:
          rjmp      main_loop                     

; hello world hi world hi world hi world hi world hi world hi world こんにちは世界

end_main:
          rjmp      main_loop           ; stay in main loop
; Initializing everything, LEDs, buttons, and single digit display.

; GPIO Init
; ------------------------------------------------------------
gpioInit:
; Intersection A
          sbi       DDRB, IntersectionAGreenLed
          cbi       PORTB, IntersectionAGreenLed

          sbi       DDRB, IntersectionAYellowLed
          cbi       PORTB, IntersectionAYellowLed

          sbi       DDRB, IntersectionARedLed
          sbi       PORTB, IntersectionARedLed

; Intersection B
          sbi       DDRB, IntersectionBGreenLed
          sbi       PORTB, IntersectionBGreenLed

          sbi       DDRB, IntersectionBYellowLed
          cbi       PORTB, IntersectionBYellowLed

          sbi       DDRB, IntersectionBRedLed
          cbi       PORTB, IntersectionBRedLed

; Pedestrian Lights
          sbi       DDRD, PedestrianLightA
          cbi       PORTD, PedestrianLightA

          sbi       DDRB, PedestrianLightB
          cbi       PORTB, PedestrianLightB
          
; Pedestrian Button
          cbi       DDRD, PedestrianButton  ; set Pedestrian LED Btn to input (D3)
          sbi       PORTD, PedestrianButton ; set pull-up

; Emergency Button
          cbi       DDRD, EmergencyButton   ; set Emergency LED Btn to input (D2)
          sbi       PORTD, EmergencyButton  ; set pull-up
          sbi       EIMSK,INT0              ; enable external interrupt 0 for Emergency LED Btn
          ldi       r20,0b00000010          ; set falling edge sense bits for ext int 0
          sts       EICRA,r20
          
          ret

; Pedestrian Timer Display
          sbi       DDRC, BottomLeftBar
          cbi       PORTC, IntersectionAGreenLed

          sbi       DDRC, BottomBar
          cbi       PORTC, BottomBar

          sbi       DDRC, BottomRightBar
          sbi       PORTC, BottomRightBar

          sbi       DDRD, MiddleBar
          cbi       PORTD, MiddleBar

          sbi       DDRC, TopBar
          cbi       PORTC, TopBar

          sbi       DDRD, TopLeftBar
          sbi       PORTD, TopLeftBar

          sbi       DDRC, TopRightBar
          cbi       PORTC, TopRightBar

          ret

counters_init:
; Setting the amount of time each light will be on for
          ; a_green
          ldi       r16,5
          sts       aGreenCount,r16

          ldi       r16,1
          sts       aYellowCount,r16
          ; a_red
          ldi       r16,1
          sts       aRedCount,r16

          ldi       state,MAX_STATE             ; initialize to no light
          ldi       mainCnt, 0                  ; Delay of 0 between cycles

          clr       isUpdate                    ; false

          ret                                   ; counters_init

; End GPIO Init
; ------------------------------------------------------------

tm1_init:
; ------------------------------------------------------------
          ldi       r20,HIGH(delay_cnt)
          sts       TCNT1H,r20
          ldi       r20,LOW(delay_cnt)
          sts       TCNT1L,r20

          clr       r20                 ; normal mode
          sts       TCCR1A,r20

          ldi       r20,(1<<CS12)       ; normal mode, clk/256
          sts       TCCR1B,r20          ; clock is started

          ldi       r20,(1<<TOIE1)      ; enable timer overflow interrupt
          sts       TIMSK1,r20

          ret                           ; timer1Init

; led_update_but_better
; ------------------------------------------------------------
; Function to implement main light functionality
led_update_but_better:
          inc       state                             
          cpi       state, MAX_STATE
          brlo      build_lights

          clr       state

build_lights:
          ; Determine next state of traffic light
          cpi       state, a_green  
          breq      a_green_on
          cpi       state, a_yellow
          breq      a_yellow_on
          cpi       state, a_red 
          breq      a_red_on
          cpi       state, b_green
          breq      b_green_on
          cpi       state, b_yellow
          breq      b_yellow_on
          cpi       state, b_red
          breq      b_red_on

a_green_on:
          cbi       PORTB, IntersectionARedLed               ; A Red Off
          sbi       PORTB, IntersectionAGreenLed             ; A Green On
          
          lds       mainCnt,aGreenCount                     ; load green timer value (5 seconds)
          rjmp      update_display_return                   ; break
a_yellow_on:
          cbi       PORTB, IntersectionAGreenLed            ; A Green Off
          sbi       PORTB, IntersectionAYellowLed           ; A Yellow On
          
          lds       mainCnt,aYellowCount                    ; load yellow timer value (1 second)
          rjmp      update_display_return                   ; break

a_red_on:
          cbi       PORTB, IntersectionAYellowLed            ; A Yellow Off
          sbi       PORTB, IntersectionARedLed               ; A Red On
          
          lds       mainCnt,aRedCount                       ; load red timer value (1 second)
          rjmp      update_display_return

b_green_on:
          cbi       PORTB, IntersectionBRedLed               ; B Red Off
          sbi       PORTB, IntersectionBGreenLed             ; B Green On
          
          lds       mainCnt,aGreenCount                     ; load green timer value (5 second)
          rjmp      update_display_return                   ; break
b_yellow_on:
          cbi       PORTB, IntersectionBGreenLed            ; B Green Off
          sbi       PORTB, IntersectionBYellowLed           ; B Yellow On
          
          lds       mainCnt,aYellowCount                    ; load yellow timer value (1 second)
          rjmp      update_display_return                   ; break

b_red_on:
          cbi       PORTB, IntersectionBYellowLed            ; B Yellow Off
          sbi       PORTB, IntersectionBRedLed               ; B Red On
          
          lds       mainCnt,aRedCount                       ; load red timer value (1 second)

update_display_return:
          ret                                               ; Ret
; End led_update_but_better
; ------------------------------------------------------------

; Pedestrian Button
; ------------------------------------------------------------
ped_btn_pressed:
          sbis      PINB, IntersectionAGreenLed
          rjmp      delay_loop_B
          
; Pedestrian Lights for Intersection A
delay_loop_A:
          sbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 9
          sbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, TopRightBar
          sbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar

          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 8
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms

          ;  Display 7
          cbi       PORTC, BottomBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTD, TopLeftBar
          cbi       PORTD, MiddleBar

          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 6
          cbi       PORTC, TopRightBar
          sbi       PORTD, TopLeftBar
          sbi       PORTD, MiddleBar
          sbi       PORTC, BottomLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 5
          sbi       PORTC, TopBar
          cbi       PORTC, BottomLeftBar
          
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ;Display 4
          cbi       PORTC, TopBar
          cbi       PORTC, BottomBar
          sbi       PORTC, TopRightBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 3
          cbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, BottomBar

          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 2
          cbi       PORTC, BottomRightBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 1
          cbi       PORTC, TopBar
          cbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 0
          sbi       PORTD, TopLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar  
          sbi       PORTC, TopBar
          
          call      delay_ms
          rjmp      exit_loop

; Pedestrian Lights for Intersection B
delay_loop_B:
          sbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 9
          sbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, TopRightBar
          sbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 8
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms

          ;  Display 7
          cbi       PORTC, BottomBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTD, TopLeftBar
          cbi       PORTD, MiddleBar

          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 6
          cbi       PORTC, TopRightBar
          sbi       PORTD, TopLeftBar
          sbi       PORTD, MiddleBar
          sbi       PORTC, BottomLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 5
          sbi       PORTC, TopBar
          cbi       PORTC, BottomLeftBar
          
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ;Display 4
          cbi       PORTC, TopBar
          cbi       PORTC, BottomBar
          sbi       PORTC, TopRightBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 3
          cbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, BottomBar

          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 2
          cbi       PORTC, BottomRightBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 1
          cbi       PORTC, TopBar
          cbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 0
          sbi       PORTD, TopLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar  
          sbi       PORTC, TopBar

          call      delay_ms

exit_loop:
          call     displayClear
          ldi      state, 0                       ; Reset Traffic Lights   
          ret

displayClear:
          cbi       PORTD, TopLeftBar
          cbi       PORTC, TopBar
          cbi       PORTC, TopRightBar
          cbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          cbi       PORTC, BottomRightBar
          ret
; End Pedestrian Button
; ------------------------------------------------------------

; Emergency Button
; ------------------------------------------------------------
; When emergency button is pressed:      
emergencyISR:
          ; Clear Traffic Lights
          cbi       PORTB, IntersectionAGreenLed
          cbi       PORTB, IntersectionAYellowLed
          cbi       PORTB, IntersectionBGreenLed
          cbi       PORTB, IntersectionBYellowLed
          sbi       PORTB, IntersectionARedLed
          sbi       PORTB, IntersectionBRedLed

loop_forever:
          ; Blink Red LEDs until button press
          cbi       PORTB, IntersectionBRedLed
          cbi       PORTB, IntersectionARedLed
          call      delay_ms
          sbi       PORTB, IntersectionARedLed
          sbi       PORTB, IntersectionBRedLed
          call      delay_ms
          sbic      PIND, EmergencyButton
          rjmp      loop_forever
          ldi       state, 0
          reti
; End Emergency Button
; ------------------------------------------------------------

timer1ISR:
          ldi       isUpdate, 1

          ldi       r20, HIGH(delay_cnt)          ; High byte of delay_cnt
          sts       TCNT1H, r20                   ; Store r20 to TCNT1H

          ldi       r20, LOW(delay_cnt)           ; Low byte of delay_cnt
          sts       TCNT1L, r20                   ; Store r20 to TCNT1L 
          reti                                    ; timer1ISR          
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