#include "stdafx.h"
#include "ADS131A04.h"

using namespace boost::asio::ip;

//initialise tcp connection
boost::asio::io_service ioservice;
tcp::endpoint tcp_endpoint{tcp::v4(),8080 };
tcp::acceptor tcp_acceptor{ioservice, tcp_endpoint};
tcp::socket tcp_socket{ioservice};
std::array<char,4096> bytes;

int connectionWatchdog = 0;

void accept_handler(const boost::system::error_code &ec);

void read_handler(const boost::system::error_code &ec,
  std::size_t bytes_transferred)
{
	//if a package is received correctly reset watchdog
  if (!ec)
  {
    connectionWatchdog = 0;
  }
  //std::cout << "read some" << std::endl;
  //continue receiving packages
  tcp_socket.async_read_some(boost::asio::buffer(bytes), read_handler);
}

void quit(){
	tcp_socket.shutdown(tcp::socket::shutdown_send);
	ioservice.stop();
}

void write_handler(const boost::system::error_code &ec,
  std::size_t bytes_transferred)
{
	if(ec){
		//an error occured during writing
		quit();
	}
	else{
		//std::cout<< "wrote some\r\n";
		if (connectionWatchdog > 1000){
			//watchdog expired
			quit();
		}
		else{
			connectionWatchdog++;
			//write anonther package and wait in order not to overload the connection.
			tcp_socket.async_write_some(boost::asio::buffer(ADS131A04::getDataBinary()),write_handler);
			//std::cout << connectionWatchdog << "\r\n";
			usleep(1000);
		}
		
	}
}

void accept_handler(const boost::system::error_code &ec)
{
  if (!ec)
  {
	std::cout << "started session" << std::endl;
	//initialise the adc
	ADS131A04::init();
	//when a data packet is received, execute read_handler
	tcp_socket.async_read_some(boost::asio::buffer(bytes), read_handler);
	//write the received data, afterwards execute write_handler
	tcp_socket.async_write_some(boost::asio::buffer(ADS131A04::getDataString()),write_handler);
  }
}

int main()
{
	//start listening on the tcp port
	tcp_acceptor.listen();
	//when a connection to the port is made start the accept handler
	tcp_acceptor.async_accept(tcp_socket,accept_handler);
	//block
	ioservice.run();
	std::cout << "finished session" << std::endl;
}
