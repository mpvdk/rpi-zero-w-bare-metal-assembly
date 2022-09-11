# 3-button pwm LED

This program has 3 SPST normally-open momentary push buttons that control the PWM output to a led.

- GPIO 14,15,16 = input button 1,2,3
- GPIO 12 = output PWM LED

All 4 of these GPIOs are in GPFSEL1.

A button press causes an interrupt that checks which button is being pressed and sets the PWM accordingly.

- Button 1 causes wide pulse width (light glow of LED)
- Button 2 causes medium pulse width (medium glow of LED)
- Button 3 causes narrow pulse width (max glow of LED)

# Schematic

![3-button pwm LED schematic](https://raw.githubusercontent.com/mpvdk/rpi-zero-w-bare-metal/main/schematics/3-button-pwm-led.webp "3-button pwm LED schematic")
