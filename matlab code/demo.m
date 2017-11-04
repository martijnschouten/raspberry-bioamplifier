clear all
close all

channels = 4;
resistanceChannel = 3;
ground = 3;
Vres = 1.8;
Rres = 3.9e3;

timeFrame = 5;
treshholdEmg = 0.8e-4;
treshholdRes = 80;

yaxisRes = [-300 600];
yaxisEmg = [0 0.5e-3];

fs = 2000;%sample frequency
g1 = 100;%gain of channel 1
R = 10e3; %resistor in transinpedance amplifier
g4 = 100;%gain of channel 4
startFiltering = 10; %to improve startup behavious the filter is started after x cycles

%emg bandpass filter parameters
fmin = 10;%start frequency
fmax = 500;%stop frequency
order = 2;%filter order
[b1,a1] = butter(order,[fmin fmax]/fs*2, 'bandpass');

%emg notch filter parameters
fmin = 47;%start frequency 
fmax = 53;%stop frequency
order = 2;
[b2,a2] = butter(order,[fmin fmax]/fs*2, 'stop');

%emg low pass filter parameters
fmax = 5;%stop frequency
order = 2;
[A2,B2,C2,D2] = butter(order,fmax/fs*2, 'low');
ordereff2 = order;

%resistance band pass filter
fmin = 0.001;
fmax = 10;
order = 2;
[A3,B3,C3,D3] = butter(order,[fmin fmax]/fs*2, 'bandpass');
ordereff3 = 2*order;

%load images
elleboog = imread('elleboog.jpg');
pols = imread('pols.jpg');
niks = imread('niks.jpg');
beide = imread('beide.jpg');

%combine the bandpass and the notch filter
sys1 = tf(b1,a1,1/fs);
sys2 = tf(b2,a2,1/fs);
sys3 = sys1*sys2;
bode(sys3)

%convert the system to state space
sys4 = ss(sys3);
A = sys4.A;
B = sys4.B;
C = sys4.C;
D = sys4.D;
ordereff1 = length(b2)+length(b1)-2;

load counter
counter = counter + 1;
save('counter.mat','counter');

%open connection with the amplifier
ADS = ADS131a04('IEEEsensor.local',4);


%make the figure
figure
ax1Emg = subplot(2,1,1);
handleEmg = animatedline;
hold on
xlabel('time(s)')
ylabel('voltage(V)')
ylim(yaxisEmg)

%ax2Emg = subplot(2,2,2);
%imageWindowEmg = imshow(rest);

ax1Res = subplot(2,1,2);
handleRes = animatedline;
hold on
xlabel('time(s)')
ylabel('Resistance change(Ohm)')
ylim(yaxisRes)

figure
imageWindow = imshow(niks);

i1 = 1;
%open file to save data to
fileID = fopen(['data' num2str(counter) '.txt'],'a');

%declare variables
state1 = zeros(ordereff1,1);
state2 = zeros(ordereff2,1);
state3 = zeros(ordereff3,1);
%main loop
while(1)
    %read data from raspberry
    [data,s,m,us] = ADS.read();
    if length(s) > 0
        %write data to file
        for i2 = 1:length(s)
            fprintf(fileID,'%u;%u',m(i2),us(i2));
            for i3 = 1:channels
                fprintf(fileID,';%1.6f',data(i2,i3));
            end
            fprintf(fileID,'\r\n');
        end
        
        if i1 > startFiltering
            %apply state transfer function to data
            
            %apply emg bandpass filter
            filteredDataEmg = zeros(length(s),1);
            data41 = data(:,4)/g4-data(:,1)/g1;
            for i2 = 1:length(s)
                filteredDataEmg(i2) = C*state1+D*data41(i2);
                state1 = A*state1+B.*data41(i2);
            end
            
            %calculate the envelope of the signal
            rectFilteredData = abs(filteredDataEmg);
            
            %apply a low pass to the envelope 
            filteredData2 = zeros(length(s),1);
            for i2 = 1:length(s)
                filteredData2(i2) = C2*state2+D2*rectFilteredData(i2);
                state2 = A2*state2+B2.*rectFilteredData(i2);
            end
            
            %apply a band pass to the resistance signal.
            filteredDataRes = zeros(length(s),1);
            for i2 = 1:length(s)
                filteredDataRes(i2) = C3*state3+D3*Vres/data(i2,resistanceChannel)*Rres;
                state3 = A3*state3+B3.*Vres/data(i2,resistanceChannel)*Rres;
            end
            
        elseif i1 == startFiltering
            %compute initial state of the resistance for faster startup
            fixPosition = mean(data(:,resistanceChannel));
            fixPosition = Vres/fixPosition*Rres;
            temp = eye(ordereff3)-A3;
            state3 = inv(temp)*B3*fixPosition;
        end
        
        if i1 > startFiltering
            %plot emg data
            addpoints(handleEmg,s,filteredData2);
            if filteredData2(end,1) > treshholdEmg
                if filteredDataRes(end,1) > treshholdRes
                    set(imageWindow, 'CData', beide);
                else
                    set(imageWindow, 'CData', pols);
                end
            else
                if filteredDataRes(end,1) > treshholdRes
                    set(imageWindow, 'CData', elleboog);
                else
                    set(imageWindow, 'CData', niks);
                end
            end
            
            %plot resistance data
            addpoints(handleRes,s,filteredDataRes);
            
            

            if s(end) > timeFrame
                xlim(ax1Res,[s(end)-timeFrame,s(end)]);
                xlim(ax1Emg,[s(end)-timeFrame,s(end)]);
            else
                xlim(ax1Res,[0,timeFrame]);
                xlim(ax1Emg,[0,timeFrame]);
            end
            
            
        end
        
        drawnow limitrate
        i1 = i1 + 1;
    end
end


