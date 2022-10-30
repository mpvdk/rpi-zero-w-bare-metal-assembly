# BCM2835 bare-metal examples

## What

This repository offers various examples of bare-metal assembly programs for the BCM2835. This chip is used for the Raspberry Pi models Zero, Zero W, 1A(+), 1B(+), Compute Model 1. [See here for more info.](https://www.raspberrypi.com/documentation/computers/processors.html)

**The goal** is to create simple example programs for every peripheral/functionality on the chip.

## Why

**First of all** because I want to understand the interface between software and hardware. I chose to start by learning Arm assembly and I just so happened to have some Raspberry Pis on hand.

**Second**, during this process I encountered some difficulties in finding the right resources. There is a lot to find but it was difficult, sometimes, to tie it all together. I hope that others may find these examples beneficial to their learning process.

**Third but personally important:** I hope that people will address issues with my code so that I can learn from my mistakes.

# The toolchain

As you can see in the **Makefile** all you need is the Arm GNU toolchain, which [you can find here](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) for all three major operating systems.

I'm using Linux and I've installed it in `/usr/local/bin`, and then I added `/usr/local/bin/arm-none-eabi/bin` to my PATH variable. If your situation is different, you might need to edit the Makefile a little to make it work for you.

Also, you will obviously need a text editor. Any text editor will do but some syntax highlighting is definitely advantageous. If you're clueless, look at Atom, Notepad++, Visual studio code - to name just a few.

# The SD card

You will need a micro SD card that is formatted with a FAT32 partition. You can do this using whatever tools you wish. I used fdisk and mkfs.

1. Delete all existing partitions
2. Create a new primary partition of pretty much whatever size, as long as it fits the firmware and
   your .img (I used 256M for no particular reason)
3. Set the partition type to W95 FAT32 (LBA) - or hex code 0x0c
4. Create a FAT32 filesystem on your new partition (e.g. mkfs.vfat -F32 /dev/your-partition)
5. Download bootcode.bin, fixup.dat and start.elf from https://github.com/raspberrypi/firmware/tree/master/boot and copy them to the partition
6. See next section **Running the code**.

# Running the code

If you have prepared your SD card, these are the steps to actually run the code:

1. Go into a program directory
2. Run "make"
3. Copy the resulting kernel.img onto the bootable partition of your SD card (where you've also put the other bootloader files)
4. Physically wire up whatever is needed for the particular example
5. Put the SD card in the Pi
6. Connect the Pi to power

# The code

Yeah, I know, it is excessively annotated. I got a little carried away. But I stand by my motivation: these examples serve an educational purpose too. And in that light I believe it better to have twice the comments required than one comment too few.

Also, assembly tends to be as readable as a goddamn captcha, so  yeah...

# The linker script

If you want to learn about linker scripts (which I'd recommend), this is probably not a good place for you.

Raspberry Pis boot from an SD card, and there are no memory sections to worry about, nor any data relocation to perform. Hence, there is no extensive linker script required. All the linker scripts in all of these example projects are exactly the same, and they are very minimal. They could probably be even more minimal.

# The boot process

There is a lot of proprietary code involved in the boot sequence of the Raspberry Pi - especially for an educational system as the Pi purports to be.

This appears to be the sequence upon power-up:

1. GPU turns on, CPU remains off.
2. GPU executes the **first stage bootloader**, which is code stored in the on-chip ROM. This loads bootcode.bin from the SD card into L2 cache.
3. GPU executes **second stage bootloader**, bootbode.bin, which enables the SDRAM and loads start.elf from the SD card.
4. GPU executes the **third stage bootloader**, start.elf, which starts up the CPU, uses fixup.dat to partition SDRAM between GPU and CPU, optionally reads config.txt from the SD card, copies kernel.img to RAM, and transfers execution to the CPU
5. User code (kernel.img) is run on the Arm CPU

All this code, except of course fot the user code, is proprietary closed-source code. You will just have to accept that it works and does whatever is required for your code to run.

Of course I did not figure this out by myself. [Here is one source](https://elinux.org/RPi_Software), but if you're interested in the process then a search engine is your friend.

The bootloader and kernel file(name)s vary based upon the Pi version that you are using. For the RPi Zero W, you need `startup.elf`, `fixup.dat`, and `kernel.img`. But for the 4B you might need `startup4.elf`, `fixup4.dat` and `kernel8.img`.

See [this site](https://www.riscosopen.org/wiki/documentation/show/Software%20information:%20Raspberry%20Pi:%20Firmware) for some more information. But then again, if you're using a 4B you will have to, at the very least, change most of the addresses in the code to match the BCM2711.

Anyway, it's just an FYI.

# Peripherals and where they're used

1. **General-Purpose I/O**

   - 3-button-pwm-led
   - blinking-led
   - button-led
   - button-led-toggle

1. **Interrupts**

   - 3-button-pwm-led
   - button-led
   - button-led-toggle

1. **Pulse Width Modulator**

   - 3-button-pwm-led

1. **Timers**

   - 3-button-pwm-led

1. **UART**
1. **SPI**
1. **BSC**
1. **PCM/I2S**
1. **DMA**

# Misc

- [BCM2835 peripherals/datasheet](https://datasheets.raspberrypi.com/bcm2835/bcm2835-peripherals.pdf)
- Some pages are missing from the datasheet. More specifically, ones containing information regarding the audio and pwm clocks. You can find them [here](https://www.scribd.com/doc/127599939/BCM2835-Audio-clocks)
- The datasheet has some known errors. You can find most of them collected and corrected [here](https://elinux.org/BCM2835_datasheet_errata)
- These are some other good RPi bare-metal tutorials/projects:
  - [From zero to main()](https://interrupt.memfault.com/tag/zero-to-main/) by François Baldassari and James Munns
  - [Github repo with example programs](https://github.com/dwelch67/raspberrypi-zero) by David Welch
  - [Tutorial on writing a RPi 4 OS](https://www.rpi4os.com/) by Adam Greenwood-Byrne
