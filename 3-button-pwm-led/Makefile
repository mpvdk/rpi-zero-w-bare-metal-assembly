CFLAGS = -Wall -O2 -ffreestanding -nostdinc -nostdlib -nostartfiles
LDFLAGS = -nostdlib -T link.ld -o kernel.elf -t -Map kernel.map
OBJCFLAGS = -O binary kernel.elf kernel.img

all: clean kernel.img

3_button_pwm_led.o: 3_button_pwm_led.S
	arm-none-eabi-gcc $(CFLAGS) -c 3_button_pwm_led.S -o 3_button_pwm_led.o

kernel.img: 3_button_pwm_led.o
	arm-none-eabi-ld $(LDFLAGS) *.o
	arm-none-eabi-objcopy $(OBJCFLAGS)

clean:
	rm kernel.elf *.o >/dev/null 2>/dev/null || true
