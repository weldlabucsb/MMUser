close all
timeList = datetime.empty;
ch1 = [];
ch2 = [];
ch3 = [];
temp = [];

dt = datetime(2025,12,16):calmonths(1):datetime(2025,12,18);
dt.Format = 'yyyy-MM';

for jj = 1:numel(dt)
    parentPath = fullfile("B:\_Li\Logging\Pressure",string(dt(jj)));
    files = dir(parentPath);

    for ii = 3:numel(files)
        name = fullfile(parentPath,files(ii).name);
        data = readtable(name);
        hr = data.Var5;
        minu = data.Var6;
        seco = data.Var7;
        timeList = [timeList;datetime(year(dt(jj)),month(dt(jj)),ii-2,hr,minu,seco)];
        ch1 = [ch1;data.Var1];
        ch2 = [ch2;data.Var2];
        ch3 = [ch3;data.Var3];
    end
end

figure
plot(timeList,ch1)
xlabel('Time')
ylabel('Pressure')
render