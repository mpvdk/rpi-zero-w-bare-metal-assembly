# Button LED toggle

This program has a single SPST normally-open momentary push button that controls an LED.

- GPIO 20 = input button
- GPIO 21 = output LED

Interrupts are used to act on button press.

The LED is toggled at every button press.
