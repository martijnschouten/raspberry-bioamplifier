clear all
close all

channels = 4;
timeFrame = 1;
channelPlotList = [1,2,3,4];

filterSize = 2000;
fs = 2000;
fstop = 50;
fstart = 1;
coefs = fir1(filterSize-1,[fstart/fs*2 fstop/fs*2]);
%coefs = fir1(filterSize-1,fstop/fs*2);
figure
freqz(coefs,1)

load counter
counter = counter + 1;
save('counter.mat','counter');

ADS = ADS131a04('IEEEsensor.local',4);

figure
numberOfPlots = length(channelPlotList);
for i1 = 1:numberOfPlots
    ax(i1) = subplot(numberOfPlots,1,i1);
    handle(i1) = animatedline;
    hold on
    xlabel('time(s)')
    ylabel('voltage(V)')
    %ylim([-0.05 .05])
end
linkaxes(ax,'x');

leftOverData = [];
i1 = 1;
fileID = fopen(['data' num2str(counter) '.txt'],'a');

buffer = zeros(filterSize,channels);
while(1)
    [data,s,m,us] = ADS.read();
    if length(s) > 0
        for i2 = 1:length(s)
            %write data to file
            fprintf(fileID,'%u;%u',m(i2),us(i2));
            for i3 = 1:channels
                fprintf(fileID,';%1.6f',data(i2,i3));
            end
            fprintf(fileID,'\r\n');
        end
        
        filteredData = zeros(length(s),channels);
        for i2 = 1:length(s)
            for i3 = 1:channels
                buffer(:,i3) = [buffer(2:end,i3);data(i2,i3)];
                filteredData(i2,i3) = sum(buffer(:,i3).*coefs');
            end
        end
        

        
        %plot data
        for i3 = 1:numberOfPlots
            %with filtering
            %addpoints(handle(i3),s,filteredData(:,channelPlotList(i3)));
            
            %without filtering
            addpoints(handle(i3),s,data(:,channelPlotList(i3)));
        end

        if s(end) > timeFrame
            xlim([s(end)-timeFrame,s(end)]);
        else
            xlim([0,timeFrame]);
        end
        
        drawnow limitrate
        i1 = i1 + 1;
    end
end

