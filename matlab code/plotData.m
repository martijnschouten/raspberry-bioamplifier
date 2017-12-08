clear all
close all

channels = 4;
resistanceChannel = 3;
Vres = 1.8;
Rres = 3.9e3;

timeFrame = 5;
treshholdEmg = 45;
treshholdRes = 60;

yaxisRes = [-300 600];
yaxisEmg = [0 0.5e-3];

fileName = 'data596.txt';
mins = 0;
maxs = 300;

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

%combine the bandpass and the notch filter
sys1 = tf(b1,a1,1/fs);
sys2 = tf(b2,a2,1/fs);
sys3 = sys1*sys2;
%bode(sys3)

%convert the system to state space
sys4 = ss(sys3);
A = sys4.A;
B = sys4.B;
C = sys4.C;
D = sys4.D;
ordereff1 = length(b2)+length(b1)-2;



readData = dlmread(fileName,';');
channels = 4;
plotchannels = [1,2,3,4];


minutes = readData(:,1);
microseconds = readData(:,2);
for i1 = 1:channels 
    data(:,i1) = readData(:,i1+2);
end

min0 = minutes(1);
us0 = microseconds(1);
s = (minutes - min0)*60+(microseconds-us0)/1e6;

use = find((s>mins)&(s<maxs));
s = s(use);
data = data(use,:);

%declare variables
state1 = zeros(ordereff1,1);
state2 = zeros(ordereff2,1);
state3 = zeros(ordereff3,1);


fixPosition = mean(data(:,resistanceChannel));
fixPosition = Vres/fixPosition*Rres;
temp = eye(ordereff3)-A3;
state3 = inv(temp)*B3*fixPosition;


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
filteredDataEmg2 = zeros(length(s),1);
for i2 = 1:length(s)
    filteredDataEmg2(i2) = C2*state2+D2*rectFilteredData(i2);
    state2 = A2*state2+B2.*rectFilteredData(i2);
end

%apply a band pass to the resistance signal.
filteredDataRes = zeros(length(s),1);
for i2 = 1:length(s)
    filteredDataRes(i2) = C3*state3+D3*Vres/data(i2,resistanceChannel)*Rres;
    state3 = A3*state3+B3.*Vres/data(i2,resistanceChannel)*Rres;
end

figure
plot(s,filteredDataRes);
ylabel('Resistance change (\Omega)')
xlabel('time(s)')

figure
plot(s,filteredDataEmg2);
ylabel('Voltage(V)')
xlabel('time(s)')

figure
[hAx,~,~] = plotyy(s,filteredDataRes,s,filteredDataEmg2);
xlabel('Time (s)')
ylabel(hAx(1),'Voltage(V)') % left y-axis 
ylabel(hAx(2),'Resistance change (\Omega)') % right y-axis