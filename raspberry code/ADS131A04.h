#define CHANNELS 4
#define BUFFERSIZE 500000
#define TIMEUPDATECOUNT 2000
#define PERIOD 250000

#include <string>
#include <boost/circular_buffer.hpp>

class ADS131A04{
	public:
	//initialise connection with the adc
	static void init(void);
	
	
	//get all data that arrived since the last time the function was called. The returned string's format is:
	//%i - hours since epoch
	//%i - microseconds since last hour
	//n x %1.6f - measured voltages in volts
	//values are separated by a ;
	static std::string getDataString(void);
	
	//get all data that arrived since the last time the function was called. 
	//for numbers the values 128-256 in a unsigned char are used.
	//i.e. 200 201 202 is (200-128)*128^2+ (201-128)*128 + (202-128)
	//The returned string's format is:
	//4 x 7bit - hours since epoch
	//4 x 7bit - microseconds since last hour
	//n x 3 x 7bit - measured values in adc units
	//note that the adc units are two complements.
	static std::string getDataBinary(void);
	
	
	private:
	//the callback function
	static void dataReady(void);
	
	//empty constructor
	ADS131A04(void);
	
	//circular buffer containing the timestamps
	static boost::circular_buffer<uint64_t> timeStamps;
	//circular buffer containing the measured data
	static boost::circular_buffer<uint8_t> data;
	
	//buffer used to store and read data for the spi connection
	static unsigned char *buffer;
	//the length of a frame of the spi connection
	static unsigned char frameSize;
	
	//write data to a register and check by reading out the register
	static void writeAndCheck(void);
	
	//write data to a register
	static void writeRegister(unsigned char address, unsigned char value);
	
	//print the last read data
	static void printBuffer(void);
};