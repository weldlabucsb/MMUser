clear
close all
ScopeAddress = "TCPIP0::172.16.0.6::inst0::INSTR";
scope = SiglentSDS2104XPlus(ScopeAddress);
scope.connect;
scope.TriggerMode = "Auto";
scope.IsEnabled = [false,false,true,false];
scope.NSample = 2e4;
scope.Duration = 0.1e-3;
scope.VerticalRange(3) = 1.2;
scope.VerticalOffset(3) = -0.6;
scope.TriggerLevel = 0.09;
scope.set
t0 = datetime;
data = [];
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
scpiCommand = ":MEASure:ADVanced:P1:VALue?";
str2num(writeread(scope.VisaObj,scpiCommand));

while (t-t0) < hours(8)
    pause(1)
    t = datetime;
    % scope.read
    data(end+1) = str2num(writeread(scope.VisaObj,scpiCommand));
    tList(end+1) = t;
    l = plot(tList,data,'.');
    xlabel("time")
    ylabel("Precilaser Power [a.u.]")
    render
    l.LineStyle = '-';
    l.MarkerSize = 4;
end
