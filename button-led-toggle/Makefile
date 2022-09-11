CFLAGS = -Wall -O2 -ffreestanding -nostdinc -nostdlib -nostartfiles

all: clean kernel.img

button_led_toggle.o: button_led_toggle.S
	arm-none-eabi-gcc $(CFLAGS) -c button_led_toggle.S -o button_led_toggle.o

kernel.img: button_led_toggle.o
	arm-none-eabi-ld -nostdlib button_led_toggle.o -T link.ld -o kernel.elf
	arm-none-eabi-objcopy -O binary kernel.elf kernel.img

clean:
	rm kernel.elf *.o >/dev/null 2>/dev/null || true
