close all
timeList = datetime.empty;
flow = [];
pIn = [];
pOut = [];
temp = [];

dt = datetime(2024,8,1):calmonths(1):datetime(2025,3,31);
dt.Format = 'yyyy-MMM';

for jj = 1:numel(dt)
    parentPath = fullfile("B:\_Li\Logging\Core_Sensors",string(dt(jj)));
    files = dir(parentPath);

    for ii = 3:numel(files)
        name = fullfile(parentPath,files(ii).name);
        data = readtable(name);
        hr = data.Var6;
        minu = data.Var7;
        seco = data.Var8;
        timeList = [timeList;datetime(year(dt(jj)),month(dt(jj)),ii-2,hr,minu,seco)];
        flow = [flow;data.Var4];
        pIn = [pIn;data.Var1];
        pOut = [pOut;data.Var2];
        temp = [temp;data.Var3];
    end
end
figure
plot(timeList,flow)
xlabel('Time')
ylabel('Flow [GPM]')
render
saveas(gcf,"flow.fig")
saveas(gcf,"flow.png")
writetable(table(timeList,flow),"flow.csv")


figure
plot(timeList,pIn,timeList,pOut)
legend("Input","Output")
xlabel('Time')
ylabel('Pressure [PSI]')
render
saveas(gcf,"pressure.fig")
saveas(gcf,"pressure.png")
writetable(table(timeList,pIn,pOut),"pressure.csv")

figure
plot(timeList,pIn-pOut)
xlabel('Time')
ylabel('Pressure Difference [PSI]')
render
saveas(gcf,"pressure_diff.fig")
saveas(gcf,"pressure_diff.png")
writetable(table(timeList,pIn-pOut),"pressure_diff.csv")

figure
plot(timeList,temp)
xlabel('Time')
ylabel('Temperature [C]')
render
saveas(gcf,"temperature.fig")
saveas(gcf,"temperature.png")
writetable(table(timeList,temp),"temperature.csv")
