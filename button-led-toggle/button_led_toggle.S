@=======================================================
@
@ This program has a single SPST normally-open
@ momentary push button that controls an LED.
@
@ GPIO 20 = input button
@ GPIO 21 = output LED
@
@ Interrupts are used to act on button press.
@ The LED is toggled at every button press.
@
@=======================================================

.section .init 
.globl _start

@------------------------
@ GPIO register addresses
@------------------------
.equ GPIO_BASE,0x20200000

.equ GPFSEL2_OFFSET,0x08
.equ GPSET0_OFFSET,0x1c
.equ GPCLR0_OFFSET,0x28
.equ GPLEV0_OFFSET,0x34
.equ GPEDS0_OFFSET,0x40
.equ GPREN0_OFFSET,0x4c
.equ GPPUD_OFFSET,0x94
.equ GPPUDCLK0_OFFSET,0x98

.equ BIT_20,0x100000
.equ BIT_21,0x200000

.equ MAKE_GPIO21_OUTPUT,0b1000
.equ ENABLE_PULL_DOWN_CONTROL,0b01

@-----------------------------
@ Interrupt register addresses
@-----------------------------
.equ INTERRUPT_BASE,0x2000b000
.equ EIRQ2_OFFSET,0x214

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

    @ GPIO is input by default - no need to set it
    @ Enable GPIO20 pull-down resistor
    MOV  r1,#1                           @ 0b01 = Enable pull down control
    STR  r1,[r0,#GPPUD_OFFSET]
    PUSH {r0,r1}                         @ Save reg values on stack
    MOV  r0,#150
    BL   wait_r0_cycles                  @ Per bcm2835 documentation
    POP  {r0,r1}                         @ Restore reg values from stack
    LDR  r1,=BIT_20                      @ Prepare r1 to set correct bits
    LDR  r1,=0xFFFFFFFF                  @ Prepare r1 to set correct bits
    STR  r1,[r0,#GPPUDCLK0_OFFSET]       @ Set bit 20 in GPPUDCLK0 reg
    PUSH {r0,r1}                         @ Save reg values on stack
    MOV  r0,#150
    BL   wait_r0_cycles                  @ Per bcm2835 documentation
    POP  {r0,r1}                         @ Restore reg values from stack
    MOV  r1,#0                           @ 0b0 = Disable pull down control
    STR  r1,[r0,#GPPUD_OFFSET]           @ Clear GPPUD register
    STR  r1,[r0,#GPPUDCLK0_OFFSET]       @ Clear GPPUDCLK0 register

    @ Enable GPIO20 Rising Edge Detect
    LDR  r1,=BIT_20                      @ Prepare r1 to set correct bit
    LDR  r2,[r0,#GPREN0_OFFSET]          @ Load current value of GPREN0 into r2
    ORR  r3,r1,r2                        @ OR in the desired bit (20)
    STR  r3,[r0,#GPREN0_OFFSET]          @ Enable GPIO20 rising edge detect

    @ Make GPIO21 output
    LDR  r1,=MAKE_GPIO21_OUTPUT          @ Prepare r1 to set correct bits
    STR  r1,[r0,#GPFSEL2_OFFSET]         @ Make GPIO21 output

    @------------------------
    @ INTERRUPT CONFIGURATION
    @------------------------
    LDR  r0,=INTERRUPT_BASE              @ Load interrupt registers base address into r0

    @ Enable interrupts in CPSR
    MRS  r4,CPSR                         @ Load CPSR into r4 for manipulation
    BIC  r4,#0b10000000                  @ Turn off the interrupt disable bit, leaving others untouched
    MSR  CPSR,r4                         @ Save back to CPSR reg

    @ Enable interrupts for GPIO bank 0
    MOV  r1,#1
    MOV  r1,r1,LSL#17                    @ Need to set bit 17
    STR  r1,[r0,#EIRQ2_OFFSET]           @ Set bit 20 of EIRQ2, enabling interrupts for GPIO bank 0

    BL   turn_led_on                     @ Start with LED on

@ Idle trap
idle: B idle

@ GPIO interrupt handler
interrupt_handler:
    BL   debounce

    LDR  r1,[r0,#GPLEV0_OFFSET]          @ Load current value of GPIOs into r1
    AND  r2,r1,#BIT_21                   @ Single out GPIO21 (LED output)
    CMP  r2,#BIT_21                      @ Compare result with bit 21
    BLEQ turn_led_off                    @ If equal, LED is on - turn it off
    BLNE turn_led_on                     @ If not equal, LED is off - turn it on
    BL   wait_for_button_release         @ Wait to enable interrupts until button is released
    BL   enable_interrupts               @ Re enable interrupts

    B    idle

@ Software button debounce
debounce:
    LDR  r0,=0xbebc2                     @ 0xbebc2 clock cycles ~ 1ms
    BL   wait_r0_cycles                  @ Software debouncing
    LDR  r0,=GPIO_BASE                   @ Load GPIO_BASE address into r0
    LDR  r1,[r0,#GPLEV0_OFFSET]          @ Load current value of GPIOs into r1
    AND  r2,r1,#BIT_20                   @ Single out GPIO20 (button input)
    CMP  r2,#BIT_20                      @ Compare result with bit 20
    BLNE enable_interrupts               @ If not equal, it's button bounce. Reset interrupts.
    BNE  idle                            @ And go back to idle
    BX   LR                              @ Bounce passed - legitimate button press

@ Delay processing until button is released
wait_for_button_release:
    LDR  r0,=GPIO_BASE                   @ Load GPIO_BASE address into r0
    LDR  r1,[r0,#GPLEV0_OFFSET]          @ Load current value of GPIOs into r1
    AND  r2,r1,#BIT_20                   @ Single out GPIO20 (buttin input)
    CMP  r2,#BIT_20                      @ Compare result with bit 20
    BEQ  wait_for_button_release         @ Wait till button is released
    BX   LR                              @ Return control to caller

@ Re-enable interrupts
enable_interrupts:
    MRS  r4,CPSR                         @ Load CPSR into r4 for manipulation
    BIC  r4,#0b10000000                  @ Turn off the interrupt disable bit, leaving others untouched
    MSR  CPSR,r4                         @ Save back to CPSR reg
    BX   LR                              @ Return control to caller

turn_led_on:
    LDR  r0,=GPIO_BASE                   @ Load GPIO_BASE address into r0
    LDR  r1,=BIT_21                      @ Prepare r1 to set correct bit
    STR  r1,[r0,#GPSET0_OFFSET]          @ Set GPIO21 output to high
    BX   LR                              @ Return control to caller

turn_led_off:
    LDR  r0,=GPIO_BASE                   @ Load GPIO_BASE address into r0
    LDR  r1,=BIT_21                      @ Prepare r1 to set correct bit
    STR  r1,[r0,#GPCLR0_OFFSET]          @ Set GPIO21 output to low
    BX   LR                              @ Return control to caller

wait_r0_cycles:
    MOV  r1,#0                           @ Start at count 0
loop:
    ADD  r1,r1,#1                        @ Add 1
    CMP  r0,r1                           @ Compare r1 to r0
    BXMI LR                              @ If r0-r1 results in N bit, return execution to caller
    B    loop                            @ Else, continue counting
