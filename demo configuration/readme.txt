FMG:
U1C (channel 3) is configured as an transimpedance amplifier to the analog ground with an feedback resistor of 3.9 kOhm. The shielding of the u.fl connector is not used since there was a short from the shield to the core near the FMG sensor. 

U1B (channel 2) is not used, but is configured as a unity gain amplifier for debug purposes. It's u.fl connector is used to connect the general ground to FMG resistor. The general ground is 1.8 volt below the analog ground and therefore can be used to apply a voltage over the FMG resistor.


EMG:
U1A (channel 1) is used as reference channel. The measured signal is send back to the patient with a negative gain via the driven right leg. This results in feedback loop pulling this signal to zero.

U1D (channel 4) is used as a measurement channel. This amplifier contains a high pass filter in order to filter out the DC offset of the signal and therefore allow a larger gain.