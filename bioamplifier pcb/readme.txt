The PCB is designed using Kicad and it's dimensions are such that it can be ordered as a 5x5cm pcb at the big chinese PCB manufacturers.

The PCB contains an 24 bit ADC, a quad opamp for measurements and one aditional single opamp that can be used as a driven right leg. As this was a prototype, each opamp has many resistors placed around it that do not all have to be soldered. By soldering certain resistors the opamp can be configured as for example a FMG sensor or as an EMG sensor.

Known bugs:
1. The capacitances (C6-C9) of the low pass filters in front of the ADC result in noise on the analog ground, when high capacitance values are used (1 uF).
2. Daisy chaining the boards is not possible since:
	-No external clock can supplied
	-A mix up of the CS and the DRDY signal...