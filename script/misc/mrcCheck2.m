%% path
parentPath = "C:/Users/WOODHOUSE/Documents/BeamStabil/Data";
filePath = findLatestFile(parentPath);
% filePath = "C:\Users\WOODHOUSE\Documents\BeamStabil\Data\BeamStab_2025-04-11T14-46-48.csv";
tempPath = findFolderInPath("temp");
tempPath = tempPath(1);

%% Trigger settings
triggerPower = 3;
triggerDelay = 200e-3;
triggerDuration = 200e-3;

%% Read data
t = readtable(filePath);
time = t.ms * 1e-3;
time = time - time(1);
power1 = t.I1_V_;
power2 = t.I2_V_;
x1 = t.X1_V_;
x2 = t.X2_V_;
y1 = t.Y1_V_;
y2 = t.Y2_V_;
rx1 = t.RX1_V_;
ry1 = t.RY1_V_;
rx2 = t.RX2_V_;
ry2 = t.RY2_V_;

%% Trigger Simulation
power1Before = 0;
ii = 1;
jj = 1;
idx = {};
while ii < numel(time)
    if power1(ii) > triggerPower && power1Before <= triggerPower
        idx{jj} = find(time >= (time(ii) + triggerDelay) & time <= (time(ii) + triggerDelay + triggerDuration));
        power1Before = power1(ii);
        ii = idx{jj}(end) + 1;
        jj = jj + 1;
    else
        power1Before = power1(ii);
        ii = ii + 1;
        continue
    end
end

%% Select data
nTrigger = numel(idx);
timeC = cell(nTrigger,1);
power1C = cell(nTrigger,1);
power2C = cell(nTrigger,1);
x1C = cell(nTrigger,1);
x2C = cell(nTrigger,1);
y1C = cell(nTrigger,1);
y2C = cell(nTrigger,1);
rx1C = cell(nTrigger,1);
rx2C = cell(nTrigger,1);
ry1C = cell(nTrigger,1);
ry2C = cell(nTrigger,1);
for jj = 1:numel(idx)
    timeC{jj} = time(idx{jj});
    power1C{jj} = power1(idx{jj});
    power2C{jj} = power2(idx{jj});
    x1C{jj} = x1(idx{jj});
    x2C{jj} = x2(idx{jj});
    y1C{jj} = y1(idx{jj});
    y2C{jj} = y2(idx{jj});
    rx1C{jj} = rx1(idx{jj});
    rx2C{jj} = rx2(idx{jj});
    ry1C{jj} = ry1(idx{jj});
    ry2C{jj} = ry2(idx{jj});
end

timePlot = cellfun(@mean,timeC);

%% Plot pointing
% close figure(1000)
figure(1000)
hold on 
% plotRelative(time,power1)
plotRelative(timePlot,x1C)
plotRelative(timePlot,y1C)
plotRelative(timePlot,x2C)
plotRelative(timePlot,y2C)
legend("X1","Y1","X2","Y2")
xlabel("Time [s]")
ylabel("Beam Position [V]")
render
saveas(gcf,fullfile(tempPath,"Beam_Position.png"))

%% Plot piezo
figure(1001)
hold on 
plotRelative(timePlot,rx1C)
plotRelative(timePlot,ry1C)
plotRelative(timePlot,rx2C)
plotRelative(timePlot,ry2C)
legend("X1","Y1","X2","Y2")
xlabel("Time [s]")
ylabel("Piezo Voltage [V]")
render
saveas(gcf,fullfile(tempPath,"Piezo_Voltage.png"))

%% Plot power
% figure(1002)
% hold on 
% plotRelativeNormalize(timePlot,power1C)
% plotRelativeNormalize(timePlot,power2C)
% legend("P1","P2")
% xlabel("Time [s]")
% ylabel("Normalized power drift")
% render

%% functions

function plotRelative(time,dataC)
dataMean = mean(cell2mat(dataC));
dataPlot = cellfun(@mean,dataC) - dataMean;
dataStd = cellfun(@std,dataC);
errorbar(time,dataPlot,dataStd,'.')
end

function plotRelativeNormalize(time,dataC)
dataMean = mean(cell2mat(dataC));
dataPlot = cellfun(@mean,dataC) - dataMean;
dataStd = cellfun(@std,dataC);
errorbar(time,dataPlot/dataMean,dataStd/dataMean,'.')
end
% plot(t0,t.X1_V_)
% plot(t0,t.X2_V_)
% plot(t0,t.Y1_V_)
% plot(t0,t.Y2_V_)
% plot(time,t.I1_V_)
% plot(time,t.RY2_V_)
% legend
% 
% render