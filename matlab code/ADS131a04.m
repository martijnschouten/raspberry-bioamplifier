classdef ADS131a04 < handle
   properties
      leftOverData;
      min0
      us0
      t
      iterator
      channels
   end
   methods
        function [adcData,s,m,us] = read(ADS)
            if (ADS.t.BytesAvailable > 0)
                fwrite(ADS.t,'a');
                receivedData = fread(ADS.t,ADS.t.BytesAvailable);
                totalData = [ADS.leftOverData;receivedData];

                [data, lastLine] = ADS.str2data(totalData,ADS.channels);
                [ndata,~] = size(data);
                ADS.leftOverData = totalData(lastLine:end);

                if ndata > 1
                    if ADS.iterator == 1
                        ADS.min0 = data(1,1);
                        ADS.us0 =  data(1,2);
                    end
                    s = (data(:,1) - ADS.min0)*60+(data(:,2)-ADS.us0)/1e6;
                    ADS.iterator = ADS.iterator + 1;
                    adcData = data(:,3:end);
                    m = data(:,1);
                    us = data(:,2);
                else
                    adcData = [];
                    s = [];
                    m = [];
                    us = [];
                end
            else
                adcData = [];
                s = [];
                m = [];
                us = [];
            end
        end
        function ADS = ADS131a04(address,channels)
            ADS.channels = channels;
            ADS.iterator = 1;
            ADS.leftOverData = [];
            ADS.t = tcpip(address, 8080,'NetworkRole','client');
            ADS.t.InputBufferSize = 100000;
            ADS.t.OutputBufferSize = 50;
            fopen(ADS.t);
        end
        function [data, lastLine] = str2data(ADS, totalData,channels)
            dataLength = length(totalData);
            state = 0;
            measurement = 1;
            item = 1;
            word = [];
            buffer = zeros(round(dataLength/50),channels + 2);
            lastLine = 1;
            i2 = 1;
            while i2 <= dataLength
                %state = 0 is no end of line found yet
                %state = 1 found end of line
                %state = 2 reset state
                switch state
                    case 0
                        if totalData(i2) == 10
                            state = 1;
                        end
                    case 1
                        if totalData(i2) == 59
                            if item < channels + 2 && (length(word) == 3 || length(word) == 4)
                                %at a ; store word and go to next item
                                if length(word) == 3
                                    if word(1)>64
                                    buffer(measurement,item) = 8/2^21*((word(1)-64)*128^2+word(2)*128+word(3))-4;
                                else
                                    buffer(measurement,item) = 8/2^21*(word(1)*128^2+word(2)*128+word(3));
                                 end
                                else
                                    buffer(measurement,item) = word(1)*128^3+word(2)*128^2+word(3)*128+word(4);
                                end
                                item = item + 1;
                                word = [];
                            else
                                %if somethings is wrong forget about it
                                state = 2;
                                disp('wrong number of items in package');
        %                         if i2 > 40 && dataLength - i2 > 40
        %                             disp(totalData(i2-40:i2+40)');
        %                         end
                            end
                        elseif (totalData(i2) >= 128 && totalData(i2) <= 255)
                            word = [word, (totalData(i2)-128)];
                        elseif totalData(i2) == 10
                            if item == 6 && length(word) == 3
                                 if word(1)>64
                                    buffer(measurement,item) = 8/2^21*((word(1)-64)*128^2+word(2)*128+word(3))-4;
                                else
                                    buffer(measurement,item) = 8/2^21*(word(1)*128^2+word(2)*128+word(3));
                                 end
                                measurement = measurement + 1;
                                lastLine = i2-1;
                                word = [];
                                item = 1;
                            else
                                disp('early end of line encountered')
                                word = [];
                                item = 1;
                            end
                        else
                            state = 2;
                            disp(['unexpected sign received: ' num2str(totalData(i2))])
        %                     if i2 > 40 && dataLength - i2 > 40
        %                         disp(totalData(i2-40:i2+40)');
        %                     end
                        end
                    case 2
                        word = [];
                        item = 1;
                        if totalData(i2) == 10
                            state = 1;
                        else
                            state = 0;
                        end 
                    otherwise
                        error('entered and unkown state')

                end
                i2 = i2 + 1;
            end
            data = buffer(1:measurement-1,:);
        end
   end
end