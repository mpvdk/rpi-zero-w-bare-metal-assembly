@=======================================================
@
@ This program has 3 SPST normally-open momentary push
@ buttons that control the PWM output to a led.
@
@ GPIO 14,15,16 = input button 1,2,3
@ GPIO 12       = output PWM LED
@
@ All 4 of these GPIOs are in GPFSEL1
@
@ A button press causes an interrupt that checks which
@ button is being pressed and sets the PWM accordingly.
@
@ Button 1 causes wide pulse width (light glow of LED)
@ Button 2 causes medium pulse width (medium glow of LED)
@ Button 3 causes narrow pulse width (max glow of LED)
@
@=======================================================

.section .init
.globl _start

@-------------------------
@ GPIO registers addresses
@-------------------------
.equ GPIO_BASE,0x20200000

.equ GPFSEL1_OFFSET,0x04
.equ GPLEV0_OFFSET,0x34
.equ GPEDS0_OFFSET,0x40
.equ GPREN0_OFFSET,0x4c
.equ GPFEN0_OFFSET,0x58
.equ GPPUD_OFFSET,0x94
.equ GPPUDCLK0_OFFSET,0x98

.equ ENABLE_PULL_DOWN_CONTROL,0b01

@------------------------
@ PWM registers addresses
@------------------------
.equ PWM_BASE,0x2020c000

.equ PWMCTL_OFFSET,0x0
.equ PWMRNG1_OFFSET,0x10
.equ PWMDAT1_OFFSET,0x14
.equ PWMRNG2_OFFSET,0x20
.equ PWMDAT2_OFFSET,0x24

@--------------------------------------------------------------
@ Clock Manager registers addresses
@
@ NOTE: these are not in the BCM2835 datasheet
@ see https://www.scribd.com/doc/127599939/BCM2835-Audio-clocks
@--------------------------------------------------------------
.equ CM_PWMCTL,0x201010a0
.equ CM_PWMDIV,0x201010a4
.equ PASSWD,0x5a000000

@------------------------------
@ Interrupt registers addresses
@------------------------------
.equ INTERRUPT_BASE,0x2000b000
.equ EIRQ2_OFFSET,0x214

@---------------
@ General values
@---------------
.equ BIT_14,0x4000
.equ BIT_15,0x8000
.equ BIT_16,0x10000

@-------------------------------------------------------
@ Entry point
@
@ All of the above are assembler directives.
@ The first LDR below is the ver first instruction 
@ executed upon reset/power-on. It will be placed 
@ at the start of our .text section.
@---------------------------------------------------
_start:
@-----------------------------------------------------
@ Interrupt Vector Table
@
@ We use this structure so that it is clear which
@ interrupt handler should go where. We could use
@ "B _reset" and get rid the .word definitions,
@ but then it would be unclear which interrupt handler
@ should go where as most use the idle subroutine.
@-----------------------------------------------------
    LDR  PC,reset_vector_handler
    LDR  PC,undefined_instruction_vector_handler
    LDR  PC,software_interrupt_vector_handler
    LDR  PC,prefetch_abort_vector_handler
    LDR  PC,data_abort_vector_handler
    LDR  PC,unused_vector
    LDR  PC,interrupt_vector_handler
    LDR  PC,fast_interrupt_vector_handler

reset_vector_handler:                 .word _reset
undefined_instruction_vector_handler: .word idle
software_interrupt_vector_handler:    .word idle
prefetch_abort_vector_handler:        .word idle
data_abort_vector_handler:            .word idle
unused_vector:                        .word idle
interrupt_vector_handler:             .word interrupt_handler
fast_interrupt_vector_handler:        .word idle

@------------
@ SUBROUTINES
@------------

@ Reset vector
_reset:
    @ Move IVT to beginning of RAM
    MOV   r0,#0x8000
    MOV   r1,#0x0000
    LDMIA r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    STMIA r1!,{r2,r3,r4,r5,r6,r7,r8,r9}
    @ And move the .word assignments as well, because
    @ the LDR argument will be PC-relative
    LDMIA r0!,{r2,r3,r4,r5,r6,r7,r8,r9}
    STMIA r1!,{r2,r3,r4,r5,r6,r7,r8,r9}
    LDR   SP,=_start			 @ Start stack at _start (0x8000).
					 @ Stack grows down so there's no conflict

    @-------------------
    @ GPIO CONFIGURATION
    @-------------------
    LDR  r0,=GPIO_BASE
    @ GPIO is input by default - no need to set it for 14,15,16
    @ Enable GPIO 14,15,16 pull-down resistors
    MOV  r1,#1				 @ 0b01 = Enable pull down control
    STR  r1,[r0,#GPPUD_OFFSET]
    PUSH {r0}                            @ Save reg value on stack
    MOV  r0,#150			 @ Pass r0 = 150 as argument to function
    BL   wait_r0_cycles                  @ Per bcm2835 documentation
    POP  {r0}                            @ Restore reg value from stack
    MOV  r1,#0b111                       @ Prepare r1 to set correct bits
    MOV  r1,r1,LSL#14                    @ Set bits 14,15,16 in r1
    STR  r1,[r0,#GPPUDCLK0_OFFSET]       @ Set bits 14,15,16 in GPPUDCLK0 reg
    PUSH {r0}                            @ Save reg value on stack
    MOV  r0,#150			 @ Pass r0 = 150 as argument to function
    BL   wait_r0_cycles                  @ Per bcm2835 documentation
    POP  {r0}                            @ Restore reg value from stack
    MOV  r1,#0                           @ 0b00 = Disable pull down control
    STR  r1,[r0,#GPPUD_OFFSET]           @ Clear GPPUD reg
    STR  r1,[r0,#GPPUDCLK0_OFFSET]       @ Clear GPPUDCLK0 reg

    @ Enable GPIO 14,15,16 Rising Edge Detect
    MOV  r1,#0b111                       @ Prepare r1 to set correct bits
    MOV  r1,r1,LSL#14                    @ Set bits 14,15,16 in r1
    LDR  r2,[r0,#GPREN0_OFFSET]          @ Load current value of GPREN0 into r2
    ORR  r3,r1,r2                        @ Enable bit 14,15,16, leaving others untouched
    STR  r3,[r0,#GPREN0_OFFSET]          @ Save value back to GPREN0 reg

    @Select PWM (alt fun 0) for GPIO 12
    MOV  r1,#0b100                       @ 0b100 = alternate function 0
    LSL  r1,r1,#6                        @ Shift left to apply to GPIO 12
    STR  r1,[r0,#GPFSEL1_OFFSET]         @ Store value in GPFSEL1 reg

    @---------------------------
    @ CLOCK MANAGER CONFIGURATION
    @---------------------------
    LDR  r0,=CM_PWMCTL			 @ Load address of CM_PWMCTL into r0
    LDR  r1,[r0]			 @ Load value stored in CM_PWMCTL into r1
    LDR  r2,=PASSWD			 @ Load address of PASSWD into r2
    LDR  r3,=0x00FFFFEF			 @ Prepare to clear PASSWD and ENAB bits
    AND  r3,r3,r1			 @ AND CM_PWMCTL with r3 to clear PASSWD and ENAB bits
    ORR  r3,r3,r2			 @ OR in the PASSWD
    STR  r3,[r0]			 @ Save back to CM_PWMCTL to stop the clock 	

    PUSH {r0,r2}			 @ Store values of registers on stack
    BL   wait_for_clock_stop		 @ Wait for the clock to stop
    POP  {r0,r2}			 @ Retrieve register values from stack

    @ Normally you would need some calculations here to determine
    @ the right clock frequency to get to the desired pulse width.
    @ But we don't care about that for this program. 
    @ It actually resets to 0, but I've just put this in here
    @ do remind ourselves this is a thing.
    LDR  r1,=0x1			 @ Prepare r1 to set DIVI bits of CM_PWMDIV
    LSL  r1,r1,#12			 @ Shift left 12 to target DIVI bits
    ORR  r1,r1,r2		 	 @ OR in the PASSWD
    LDR  r3,=CM_PWMDIV			 @ Load address of CM_PWMDIV into r3
    STR  r1,[r3]			 @ Store DIVI in CM_PWMDIV

    LDR  r1,[r0]			 @ Load value stored in CM_PWMCTL into r1
    ORR  r1,#0x11			 @ Prepare r1 to set ENAB bit and SRC bit
    ORR  r1,r1,r2			 @ OR in the PASSWD
    STR  r1,[r0]			 @ Enable clock and set oscillator as clock SRC

    BL   wait_for_clock_start		 @ Wait for the clock to start back up

    @------------------
    @ PWM CONFIGURATION
    @------------------
    LDR  r0,=PWM_BASE

    @ Enable PWM channel 1 in PWM mode
    LDR  r1,=35
    STR  r1,[r0,#PWMRNG1_OFFSET]         @ Set range of 35
    LDR  r1,=35
    STR  r1,[r0,#PWMDAT1_OFFSET]         @ Set 1/1 pulse width for full brightness LED at startup
    LDR  r1,=0b01                        @ 0b01 = enabled in PWM mode
    STR  r1,[r0,#PWMCTL_OFFSET]          @ Store value in PWMCTL

    @------------------------
    @ INTERRUPT CONFIGURATION
    @------------------------
    LDR  r0,=INTERRUPT_BASE              @ Load interrupt registers base address into r0

    @ Enable interrupts in CPSR
    MRS  r4,CPSR                         @ Load CPSR into r4 for manipulation
    BIC  r4,#0b10000000                  @ Turn off the interrupt disable bit, leaving others untouched
    MSR  CPSR,r4                         @ Save back to CPSR reg

    @ Enable all GPIO interrupts
    MOV  r1,#0b1                         @ Going to enable interrupt for GPIO bank 0
    MOV  r1,r1,LSL#20                    @ Need to set bit 17
    STR  r1,[r0,#EIRQ2_OFFSET]           @ Set bits 17 of EIRQ2

@ Idle trap
idle: B idle

@ GPIO interrupt handler
interrupt_handler:
    @ Check which button is pressed and call corresponding subroutine
    LDR  r0,=GPIO_BASE			 @ Load GPIO_BASE address into r0
    LDR  r1,[r0,#GPLEV0_OFFSET]		 @ Load curret value of GPLEV0 into r1

    LDR  r2,=BIT_14			 @ Prepare r2 to check GPLEV0 for bit 14
    AND  r3,r1,r2			 @ AND GPLEV0 with bit 14
    CMP  r2,r3				 @ Compare result with bit 14
    BEQ  set_led_dim			 @ If equal, set led brightness to dim

    LDR  r2,=BIT_15			 @ Prepare r2 to check GPLEV0 for bit 15
    AND  r3,r1,r2			 @ AND GPLEV0 with bit 15
    CMP  r2,r3				 @ Compare result with bit 15
    BEQ  set_led_med			 @ If equal, set led brightness to medium

    LDR  r2,=BIT_16			 @ Prepare r2 to check GPLEV0 for bit 16
    AND  r3,r1,r2			 @ AND GPLEV0 with bit 16
    CMP  r2,r3				 @ Compare result with bit 16
    BEQ  set_led_max			 @ If equal, set led brightness to max
    
    B    enable_interrupts		 @ If none match, re-enable interrupts and wait

set_led_dim:
    LDR   r0,=PWM_BASE			 @ Load PWM_BASE address into r0 
    LDR   r1,=1				 @ Prepare r1 to set PWMDAT1 to val 1
    STR   r1,[r0,#PWMDAT1_OFFSET]        @ Set 1/35 pulse width
    B     enable_interrupts		 @ (re-)Enable interrupts 

set_led_med:
    LDR   r0,=PWM_BASE			 @ Load PWM_BASE address into r0
    LDR   r1,=10			 @ Prepare r1 to set PWMDAT to val 10
    STR   r1,[r0,#PWMDAT1_OFFSET]        @ Set 10/35 pulse width
    B     enable_interrupts		 @ (re-)Enable interrupts 

set_led_max:
    LDR   r0,=PWM_BASE			 @ Load PWM_BASE addres into r0
    LDR   r1,=35			 @ Prepare r1 to set PWMDAT1 to val 35
    STR   r1,[r0,#PWMDAT1_OFFSET]        @ Set 35/35 pulse width
    B     enable_interrupts		 @ (re-)Enable interrupts 

@ Enable interrupts for GPIO bank 0
enable_interrupts:
    @ Enable interrupts in CPSR
    MRS  r1,CPSR                         @ Load value CPSR into r1 for manipulation
    BIC  r1,#0b10000000                  @ Turn off the interrupt disable bit, leaving others untouched
    MSR  CPSR,r1                         @ Save back to CPSR reg

    LDR  r0,=GPIO_BASE			 @ Load GPIO_BASE addr into r0
    LDR  r1,=0xFFFFFFFF			 @ Prepare to clear all GPEDS0 bits 
    STR  r1,[r0,#GPEDS0_OFFSET]		 @ Clear all GPEDS0 bits

    B    idle				 @ Go back to idle

@ Delay processing for [r0] clock cycles
wait_r0_cycles:
    MOV   r1,#0				 @ Start counting from 0
loop:
    ADD   r1,r1,#1			 @ Add 1
    CMP   r0,r1				 @ Compare r0 (argument) and r1 (current count)
    BXMI  LR				 @ If r0-r1 results in N bit, return execution to caller
    B     loop				 @ Else, repeat

@ Wait till BUSY flag is cleared in CM_PWMCTL
wait_for_clock_stop:
    LDR  r0,=CM_PWMCTL			 @ Load address of CM_PWMCTL into r0
    LDR  r1,[r0]                         @ Load clock manager pwm control into r5
    AND  r1,r1,#0x80                     @ Mask to isolate BUSY flag
    CMP  r1,#0x80                        @ Check to see if BUSY flag is set
    BEQ  wait_for_clock_stop             @ Wait till BUSY flag = 0
    BX	 LR				 @ Return execution to caller

wait_for_clock_start:
    LDR  r0,=CM_PWMCTL			 @ Load address of CM_PWMCTL into r0
    LDR  r1,[r0]                         @ Load clock manager pwm control into r5
    AND  r1,r1,#0x80                     @ Mask to isolate BUSY flag
    CMP  r1,#0x80                        @ Check to see if BUSY flag is set
    BNE  wait_for_clock_start            @ Wait till BUSY flag = 1
    BX   LR				 @ Return execution to caller
