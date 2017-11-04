#include "stdafx.h"
#include "ADS131A04.h"
#include <wiringPi.h>
#include <chrono>
#include <iostream>
#include <sstream>


unsigned char ADS131A04::frameSize = 3;
unsigned char * ADS131A04::buffer = new unsigned char[30];
boost::circular_buffer<uint8_t> ADS131A04::data(BUFFERSIZE*CHANNELS*3);
boost::circular_buffer<uint64_t> ADS131A04::timeStamps(BUFFERSIZE);

ADS131A04::ADS131A04(void){
}

void ADS131A04::init(){
	int result;
	wiringPiSetup();
	
	pinMode(0,OUTPUT);
	pinMode(1,OUTPUT);
	pinMode(2,OUTPUT);
	pinMode(5,OUTPUT);
	digitalWrite(0,HIGH);
	digitalWrite(1,LOW);
	digitalWrite(2,LOW);
	delay(1);
	//reset in order to clock in 0,1 and 2
	digitalWrite(5,LOW);
	delay(1);
	digitalWrite(5,HIGH);

	//init spi and data ready interupt
	result = wiringPiSPISetupMode(0,1000000,1);

	
	//unlock device
	buffer[0] = 0x06;
	buffer[1] = 0x55;
	buffer[2] = 0x00;
	writeAndCheck();
	
	//reset device
	buffer[0] = 0x00;
	buffer[1] = 0x11;
	buffer[2] = 0x00;
	wiringPiSPIDataRW(0,buffer,frameSize);
	delay(10);

	 //unlock device
	buffer[0] = 0x06;
	buffer[1] = 0x55;
	buffer[2] = 0x00;
	writeAndCheck();

	unsigned char temp;
	//write CLK2 register
	temp  = (0b001 << 5); //fmod = ficlk/2
	temp |= 0x01; //fdata = fmod/1024
	writeRegister(0x0E,temp);

	//write CLK1 register
	temp  = (0b0<<7);//use XTAL1/CLKIN
	temp |= (0b001<<1); // ficlk = fclkin/2
	writeRegister(0x0D,temp);

	//write A_SYS_CFG
	writeRegister(0x0B,0b01111000);//enable 4V  internal reference
	
	//write ADC_ENA
	writeRegister(0x0F,0x0F);//enable all ADC's
	wiringPiSPIDataRW(0,buffer,frameSize);


	//wake up
	buffer[0] = 0x00;
	buffer[1] = 0x33;
	buffer[2] = 0x00;
	writeAndCheck();
	frameSize = 3*5;
	
	result = wiringPiISR(4,INT_EDGE_FALLING,&ADS131A04::dataReady);
	//std::cout << "ISR init result:" << result << std::endl;
}


void ADS131A04::dataReady(void){
	//read out a register
	//check if F_SPI error flag is set
	bool error = FALSE;
	if (buffer[1] == 32) error = TRUE;
		for( int i = 0; i<frameSize;i++)buffer[i] = 0;
	//if there is an F_SPI error flag, reset error flag
	if(error){
		buffer[0] =  (0b001 <<5);
		buffer[0] |= (0x05);
		buffer[1] = 0x00;
		buffer[2] = 0x00;
		error = TRUE;
	}
	//reset error flag and read out data
	wiringPiSPIDataRW(0,buffer,frameSize);
	//request current time
	timeStamps.push_back(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::system_clock::now().time_since_epoch()).count());
	
	//store data in the cyclic buffer
	for(int i1 = 0; i1<CHANNELS;i1++){
		for(int i2 = 0;i2<3;i2++){
			data.push_back(buffer[(i1+1)*3+i2]);
		}
	}
}

//old inefficient function that returns the data as a fixed point float converted to text
std::string ADS131A04::getDataString(void){
	int dataPoints = timeStamps.size()-1;
	char datastring[dataPoints*100];
	//std::cout << "datapoints: " << dataPoints << '\n';
	int i2 = 0;
	for(int i1 = 0; i1<dataPoints;i1++){
		i2 += sprintf(&datastring[i2],"%i",timeStamps.front()/(uint64_t)60000000);
		datastring[i2] = ';';
		i2++;
		i2 += sprintf(&datastring[i2],"%i",timeStamps.front()%(uint64_t)60000000);
		timeStamps.pop_front();
		for(int i3 = 0; i3 < CHANNELS; i3++){
			datastring[i2] = ';';
			i2++;
			
			uint32_t temp1 = 0;
			temp1 += (data.front()<<16);
			data.pop_front();
			temp1 += (data.front()<<8);
			data.pop_front();
			temp1 += data.front();
			data.pop_front();
			temp1 = temp1<<8;
			int32_t temp2 = (int32_t)temp1;
			double temp3 = 4.768371582e-7*temp2/256;
			i2 += sprintf(&datastring[i2],"%1.6f",temp3);
		}
		i2 += sprintf(&datastring[i2],"\n");
	}
	std::string dataString2(datastring);
	//std::cout << "new batch\n";
	//std::cout << dataString2;
	return dataString2;
}
		

//more efficient way of reading out data, using the values of 128-255 of a char to store the data.
std::string ADS131A04::getDataBinary(void){
	int dataPoints = timeStamps.size()-1;
	
	if (dataPoints > 0){
		unsigned char datastring[dataPoints*30];
		int i2 = 0;
		
		for(int i1 = 0; i1<dataPoints;i1++){
			uint32_t min = timeStamps.front()/(uint64_t)60000000;
			uint32_t us = timeStamps.front()%(uint64_t)60000000;
			timeStamps.pop_front();
			for(int i3 = 3;i3>=0;i3--){
				datastring[i2] = 128+((min & (0x7F << (i3*7)))>>(i3*7));
				i2++;
			}
			datastring[i2] = ';';
			i2++;
			for(int i3 = 3;i3>=0;i3--){
				datastring[i2] = 128+((us & (0x7F << (i3*7)))>>(i3*7));
				i2++;
			}
			for(int i3 = 0; i3 < CHANNELS; i3++){
				datastring[i2] = ';';
				i2++;
				datastring[i2] = 128+((data.front() & 0xFE)>>1);
				i2++;
				datastring[i2] = 128+((data.front() & 0x1) << 6);
				data.pop_front();
				datastring[i2] = datastring[i2] + ((data.front() & 0xFC) >> 2);
				i2++;
				datastring[i2] = 128+((data.front() & 0x3) << 5);
				data.pop_front();
				datastring[i2] = datastring[i2] + ((data.front() & 0xF8) >> 3);
				data.pop_front();
				i2++;
			}
			datastring[i2] = 10;
			i2++;
		}
		datastring[i2] = 0;
		std::string dataString2(reinterpret_cast<char*>(datastring));
		return dataString2;
	}
	else{
		std::string empty;
		return empty;
	}
}

void ADS131A04::writeAndCheck(void){
	//write data to a register in the ADC and check it by reading out the same register
	bool notGood = TRUE;
	unsigned char data[frameSize];
	memcpy(data, buffer,frameSize);
	printBuffer();
	while(notGood){
		memcpy(buffer,data,frameSize);
		//printBuffer();
		wiringPiSPIDataRW(0,buffer,frameSize);
		for(int i = 0; i<frameSize;i++){
			buffer[i] = 0;
		}
		wiringPiSPIDataRW(0,buffer,frameSize);
		printBuffer();
		if (buffer[1]==data[1]){
			notGood = FALSE;
			//cout << "good" << endl;
		}
	}
	printBuffer();
}

void ADS131A04::writeRegister(unsigned char address, unsigned char value){
	//write data to a register in the adc
	buffer[0] = (0b010 << 5);
	address &= 0b00011111;
	buffer[0] |= address;
	buffer[1] = value;
	buffer[2] = 0;
	writeAndCheck();
}

void ADS131A04::printBuffer(void){
	//print the buffer containing the last read data
	for(int i = 0; i < frameSize;i++){
		std::string s = std::to_string(buffer[i]);
		std::cout << s  << ';';
	}
	std::cout << std::endl;
}

