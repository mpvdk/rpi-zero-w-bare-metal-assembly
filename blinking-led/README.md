# Blinking LED

This program has 1 led connected to GPIO 21 that blinks with a 50% duty cycle (~1s PW / ~2s T \* 100%)

A counter value of 0xbebc20 seems result in about 1 second. That would make the clock about 12.5 MHz. I discovered this experimentally with a stopwatch. I have no idea where to find this exactly in the datasheet.

The systimer runs at 250 MHz - 20 times as much. Yet I can't find any default pre-scalers.

Anyone who can explain this to me please do.

GPIO 21 is in GPFSEL2

# Schematic

![Blinking LED schematic](https://raw.githubusercontent.com/mpvdk/rpi-zero-w-bare-metal/main/schematics/blinking-led.webp "Blinking LED schematic")
