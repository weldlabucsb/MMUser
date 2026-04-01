clear
close all

%% Scope
ScopeAddress = "TCPIP0::172.16.0.6::inst0::INSTR";
scope = SiglentSDS2104XPlus(ScopeAddress);
scope.connect;
scope.TriggerMode = "Normal";
scope.TriggerSource = "External";
scope.IsEnabled = [true,false,true,false];
scope.NSample = 2e4;
scope.Duration = 1e-3;
scope.VerticalRange(3) = 1.2;
scope.VerticalOffset(3) = -0.6;
scope.VerticalRange(1) = 1;
scope.VerticalOffset(3) = -0.5;
scope.TriggerLevel = 0.3;
scope.set
scope.startFromEdge

%% AWG
pulseAwg = Keysight33500B("TCPIP0::172.16.0.4::inst0::INSTR");
pulseAwg.SamplingRate = [1000,1e8];
pulseAwg.TriggerSource(2) = "Software";
pulseAwg.IsOutput = [false,true];
pulseAwg.OutputMode = ["Normal","Normal"];
pulseWf = WaveformList("pulse",waveformOrigin = { ...
    ConstantWave(duration = 5e-6, offset = 3)...
    });
pulseAwg.WaveformList = {[],pulseWf};
pulseAwg.OutputLoad(2) = "Infinity";
pulseAwg.connect
pulseAwg.set
pulseAwg.upload

%% Main AWG
wfl = WaveformList("const",waveformOrigin = { ...
    ConstantWave(duration = 1e-3, offset = 0)...
    });
mainAwg = Keysight33600A("TCPIP0::172.16.0.3::inst0::INSTR");
mainAwg.WaveformList = {wfl,wfl};
mainAwg.SamplingRate = [20e6,20e6];
mainAwg.TriggerSource = ["External","External"];
mainAwg.IsOutput = [true,true];
mainAwg.OutputMode = ["Normal","Normal"];
mainAwg.OutputLoad = ["Infinity","Infinity"];
mainAwg.Offset = [-1,-1];
mainAwg.connect
mainAwg.set
mainAwg.upload


t0 = datetime;
data1 = [];
data2 = [];
t = datetime;
tList = datetime.empty;
figure

scpiCommand = ":MEASure ON";
writeline(scope.VisaObj,scpiCommand);
scpiCommand = ":MEASure:ADVanced:P1:SOURce1 C3";
writeline(scope.VisaObj,scpiCommand);
scpiCommand = ":MEASure:ADVanced:P1 ON";
writeline(scope.VisaObj,scpiCommand);
scpiCommand = ":MEASure:ADVanced:P1:TYPE MEAN";
writeline(scope.VisaObj,scpiCommand);
scpiCommand1 = ":MEASure:ADVanced:P1:VALue?";

scpiCommand = ":MEASure:ADVanced:P2:SOURce1 C1";
writeline(scope.VisaObj,scpiCommand);
scpiCommand = ":MEASure:ADVanced:P2 ON";
writeline(scope.VisaObj,scpiCommand);
scpiCommand = ":MEASure:ADVanced:P2:TYPE MEAN";
writeline(scope.VisaObj,scpiCommand);
scpiCommand2 = ":MEASure:ADVanced:P2:VALue?";

close(figure(2354))
figure(2354)
hold on 
% l1 = plot(datetime,0);
l2 = plot(datetime,0);
% legend("Total power","KP1 power")
xlabel("time")
ylabel("Laser Power [a.u.]")
[l.LineStyle] = deal('-');
[l.MarkerSize] = deal(4);
% render

% yyaxis right
% l3 = plot(datetime,0,'-','MarkerSize',4);
% ylabel("ratio")
% l3.LineStyle = '-';
% l3.LineWidth = 1;

box on


while (t-t0) < hours(8)
    pulseAwg.trigger

    pause(1)
    t = datetime;
    % scope.read
    data1(end+1) = str2num(writeread(scope.VisaObj,scpiCommand1));
    data2(end+1) = str2num(writeread(scope.VisaObj,scpiCommand2));
    tList(end+1) = t;
    
    % l1.XData = tList;
    % l1.YData = data1;
    l2.XData = tList;
    l2.YData = data2;
    % l3.XData = tList;
    % l3.YData = data2./data1;
end
