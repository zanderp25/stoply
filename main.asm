;
; StoplyV4.asm
;
; Created: 4/21/2024 3:05:20 AM
; Author : Jordan, Daniel, Zander
;
         
.equ TmDelay = 65536 - (1000000 / 16)
.equ DELAY_S = 64                      ; sleep 1 second

.equ DELAY = 9

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
.equ TopLeftBar = PD2
.equ TopBar = PC1
.equ TopRightBar = PC2
.equ MiddleBar = PD5
.equ BottomLeftBar = PC0
.equ BottomBar = PC3
.equ BottomRightBar = PC4

; Emergency Button
.equ Emergencybutton = PD4

; Vector Table
; ------------------------------------------------------------
.org 0x0000        
          jmp       main

.org INT0addr                                     ; External Interrupt 0 (Left Ped Button)
          jmp       leftPedISR


.org OVF1addr                                     ; Timer/Counter1 Overflow
          jmp       timer1ISR   

.org INT_VECTORS_SIZE                   ; end Vector Table

; End Vector Table
; ------------------------------------------------------------

; Main
; ------------------------------------------------------------
main:
          call      gpioInit            ; initialize LEDs and button
          
          call      timer1Init          ; setup the countdown timer

          sei                           ; enable global interrupts

main_loop:
          sbis      PIND, PedestrianButton
          call      ped_btn_pressed

          sbic      PIND, EmergencyButton
          call      emerg_btn_pressed

          call      switchLights




end_main: 
          rjmp      main_loop

; End Main
; ------------------------------------------------------------

; gpioInit
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
          
; Pedestrian Buttons
          cbi       DDRD, PedestrianButton
          sbi       PORTD, PedestrianButton          ; engage pull-up
          
          sbi       EIMSK,INT0                ; enable external interrupt 0 for Blue LED Btn
          ldi       r20,0b00000010            ; set falling edge sense bits for ext int 0
          sts       EICRA,r20

; Emergency Buttons
          cbi       DDRD, EmergencyButton           ; set Green LED Btn to input (D4)
          cbi       PORTD, EmergencyButton           ; set high-impedance
          ldi       r20,(1<<PCINT20)    ; enable pin-change on PD4
          sts       PCMSK2,r20
          ldi       r20,(1<<PCIE2)      ; enable pin-change interrupt for Port D
          sts       PCICR,r20

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

; IR Scanner

timer1Init:

          ldi       r20,HIGH(TmDelay)
          sts       TCNT1H,r20
          ldi       r20,LOW(TmDelay)
          sts       TCNT1L,r20

          clr       r20                 ; normal mode
          sts       TCCR1A,r20

          ldi       r20,(1<<CS12)       ; normal mode, clk/256
          sts       TCCR1B,r20          ; clock is started

          ldi       r20,(1<<TOIE1)      ; enable timer overflow interrupt
          sts       TIMSK1,r20

          ret                           ; timer1Init

switchLights:
          sbic      PINB, IntersectionAGreenLed
          rjmp      iAtoB
          rjmp      iBtoA

iAtoB:
          cbi       PORTB, IntersectionAGreenLed
          sbi       PORTB, IntersectionAYellowLed

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, IntersectionAYellowLed
          sbi       PORTB, IntersectionARedLed

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, IntersectionBRedLed
          sbi       PORTB, IntersectionBGreenLed

          call      delay_ms                      ; Wait 1 second
          call      delay_ms                      ; Wait 1 second

          rjmp tm1ISRret

iBtoA:
          cbi       PORTB, IntersectionBGreenLed
          sbi       PORTB, IntersectionBYellowLed

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, IntersectionBYellowLed
          sbi       PORTB, IntersectionBRedLed

          call      delay_ms                      ; Wait 1 second

          cbi       PORTB, IntersectionARedLed
          sbi       PORTB, IntersectionAGreenLed

          call      delay_ms                      ; Wait 1 second
          call      delay_ms                      ; Wait 1 second

tm1ISRret:
          ldi       r20, HIGH(TmDelay)          ; Reset timer counter
          sts       TCNT1H, r20                   
                                                  
          ldi       r20, LOW(TmDelay)           
          sts       TCNT1L, r20    

          reti

leftPedISR:
          reti

timer1ISR:
         reti
          
          
ped_btn_pressed:
          ldi       PedCnt, DELAY
          sbis      PINB, IntersectionAGreenLed
          rjmp      delay_loop_B
          

delay_loop_A:
          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms
          ; Display 9
          sbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, TopRightBar
          sbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms
         ; Display 8
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms
        ;  Display 7
          cbi       PORTC, BottomBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTD, TopLeftBar
          cbi       PORTD, MiddleBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms
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
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 5
          sbi       PORTC, TopBar
          cbi       PORTC, BottomLeftBar
          

          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ;Display 4
          cbi       PORTC, TopBar
          cbi       PORTC, BottomBar
          sbi       PORTC, TopRightBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 3
          cbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, BottomBar

          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 2
          cbi       PORTC, BottomRightBar
          sbi       PORTC, BottomLeftBar
          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 1
          cbi       PORTC, TopBar
          cbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          sbi       PORTD, PedestrianLightB
          call      delay_ms
          cbi       PORTD, PedestrianLightB
          call      delay_ms

          ; Display 0
          sbi       PORTD, TopLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar  
          sbi       PORTC, TopBar
          
          call      delay_ms
          rjmp      exit_loop


delay_loop_B:
          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 9
          sbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, TopRightBar
          sbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

         ; Display 8
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

        ;  Display 7
          cbi       PORTC, BottomBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTD, TopLeftBar
          cbi       PORTD, MiddleBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms
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
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 5
          sbi       PORTC, TopBar
          cbi       PORTC, BottomLeftBar
          

          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ;Display 4
          cbi       PORTC, TopBar
          cbi       PORTC, BottomBar
          sbi       PORTC, TopRightBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 3
          cbi       PORTD, TopLeftBar
          sbi       PORTC, TopBar
          sbi       PORTC, BottomBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 2
          cbi       PORTC, BottomRightBar
          sbi       PORTC, BottomLeftBar

          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 1
          cbi       PORTC, TopBar
          cbi       PORTD, MiddleBar
          cbi       PORTC, BottomLeftBar
          cbi       PORTC, BottomBar
          sbi       PORTC, BottomRightBar
          
          sbi       PORTD, PedestrianLightA
          call      delay_ms
          cbi       PORTD, PedestrianLightA
          call      delay_ms

          ; Display 0
          sbi       PORTD, TopLeftBar
          sbi       PORTC, BottomBar
          sbi       PORTC, BottomLeftBar  
          sbi       PORTC, TopBar
          
          call      delay_ms
          rjmp      exit_loop

          call      delay_ms
          rjmp      exit_loop
         

exit_loop:
          call     displayClear      
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

emerg_btn_pressed:
          cbi       PORTB, IntersectionAGreenLed
          cbi       PORTB, IntersectionAYellowLed
          cbi       PORTB, IntersectionBGreenLed
          cbi       PORTB, IntersectionBYellowLed
          sbi       PORTB, IntersectionARedLed
          sbi       PORTB, IntersectionBRedLed

loop_forever:
          cbi       PORTB, IntersectionBRedLed
          cbi       PORTB, IntersectionARedLed
          call      delay_ms
          sbi       PORTB, IntersectionARedLed
          sbi       PORTB, IntersectionBRedLed
          call      delay_ms
          sbis      PIND, EmergencyButton
          rjmp      loop_forever
          reti

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