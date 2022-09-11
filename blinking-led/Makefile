CFLAGS = -Wall -O2 -ffreestanding -nostdinc -nostdlib -nostartfiles

all: clean kernel.img

blink_led.o: blink_led.S
	arm-none-eabi-gcc $(CFLAGS) -c blink_led.S -o blink_led.o

kernel.img: blink_led.o
	arm-none-eabi-ld -nostdlib blink_led.o -T link.ld -o kernel.elf
	arm-none-eabi-objcopy -O binary kernel.elf kernel.img

clean:
	rm kernel.elf *.o >/dev/null 2>/dev/null || true
