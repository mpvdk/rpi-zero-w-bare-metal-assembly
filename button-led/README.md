# Button LED

This program has a single SPST normally-open momentary push button that controls an LED.

- GPIO 20 = input button
- GPIO 21 = output LED

Interrupts are used to act on button press.

The LED follows the state of the input button - i.e. you have to hold the button to light up the LED.
