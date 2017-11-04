In order to run and compile the code:

1. copy the content of this folder to /usr/local/bin

2. give readSPI and readSPIhack the correct rights:
sudo chmod 775 /usr/local/bin/readSPI
sudo chmod 775 /usr/local/bin/readSPIhack

3. install the boost libraries
sudo apt-get install libboost-all-dev

4. install wiring pi:
sudo apt-get install wiringpi

5. enable SPI under interfacing options in the config menu accessed using:
sudo raspi-config


To make the program starts at startup by add:
/bin/bash /usr/local/bin/readSPIhack.sh
to /etc/rc.local, just above the exit 0 command

To recompile use the compile.sh script

To recompile the preheader use the compileStdafx.sh script