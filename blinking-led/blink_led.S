@=======================================================
@
@ This program has 1 led connected to GPIO 21 that blinks
@ with a 50% duty cycle (~1s PW / ~2s T * 100%) 
@
@ A counter value of 0xbebc20 seems result in about 1
@ second. That would make the clock about 12.5 MHz.
@ I discovered this experimentally with a stopwatch. I
@ have no idea where to find this exactly in the datasheet.
@ The systimer runs at 250 MHz - 20 times as much. Yet
@ I can't find any default pre-scalers.
@
@ Anyone who can explain this to me please do.
@
@ GPIO 21 is in GPFSEL2
@
@=======================================================

.globl _start

@------------------------
@ GPIO register addresses
@------------------------
.equ GPIO_BASE,0x20200000

.equ GPFSEL2,0x08
.equ GPSET0,0x1c
.equ GPCLR0,0x28

.equ MAKE_GPIO21_OUTPUT,0b1000

@-------------
@ Misc. values
@-------------
.equ SET_BIT_1,0x1
.equ SET_BIT_3,0x08
.equ SET_BIT_21,0x200000
.equ COUNTER,0xbebc20

@------------
@ Entry point
@------------
_start:
    LDR r0,=GPIO_BASE			@ Load GPIO Base address in r0
    LDR r1,=MAKE_GPIO21_OUTPUT		@ Prepare r1 to make GPIO 21 output
    STR r1,[r0,#GPFSEL2]		@ make GPIO 21 output
    LDR r1,=SET_BIT_21			@ Prepare r1 to use it to blink GPIO 21
    LDR r2,=COUNTER			@ Load counter value in r2, used by delay subroutine
main_loop:
    STR r1,[r0,#GPSET0]			@ Set GPIO 21 output high
    BL  delay 				@ Delay for ~1sec
    STR r1,[r0,#GPCLR0]			@ Set GPIO 21 output low
    BL  delay				@ Delay for ~1sec
    B   main_loop			@ Repeat

@-----------------
@ Delay subroutine
@-----------------
delay:
    MOV r3,#0				@ Start counter from 0
delay_loop:
    ADD r3,r3,#1			@ Add 1
    CMP r3,r2				@ Compare values
    BNE delay_loop			@ If r10 != r2, repeat
    BX  lr 				@ Else, resume main_loop

