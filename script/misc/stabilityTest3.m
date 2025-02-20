close all

%% MRC
t = readtable("BeamStab_2024-12-18T10-36-44.csv");
t0 = t.ms * 1e-3;
v0 = t.I1_V_;
x = t.X1_V_;
y = t.Y1_V_;
% figure
% plot(t0,v0);
 
% T = 24.050445;
T = 26.6320 - (1.5-0.11);
% T = 25.2;
T = 25.2188;
tIni = 20.9;
% tIni = 23.238;
dt = 4;
% dt = 0.08;
tiList = tIni:T:t0(end);
tMRC = zeros(size(tiList));
vMRC = zeros(size(tiList));
vMRCrms = zeros(size(tiList));
xMRC = zeros(size(tiList));
xMRCrms = zeros(size(tiList));
yMRC = zeros(size(tiList));
yMRCrms = zeros(size(tiList));
mrc = [];
for ii = 1:numel(tiList)
    idx = t0 >= tiList(ii) & t0 <= (tiList(ii)+dt) & v0 > 1.1;
    idx = find(idx);
    while ~isempty(idx) && (v0(idx(1)) - v0(idx(1)-1)) < 1
        idx(1) = [];
    end
    while ~isempty(idx) && (v0(idx(end)) - v0(idx(end)+1)) < 1
        idx(end) = [];
    end
    tMRC(ii) = mean(t0(idx));
    vMRC(ii) = mean(v0(idx));
    vMRCrms(ii) = rms(v0(idx)-vMRC(ii));
    xMRC(ii) = mean(x(idx));
    xMRCrms(ii) = rms(x(idx)-xMRC(ii));
    yMRC(ii) = mean(y(idx));
    yMRCrms(ii) = rms(y(idx)-yMRC(ii));
end
idx = ~isnan(vMRC);
vMRC = vMRC(idx);
tMRC = tMRC(idx);
vMRCrms = vMRCrms(idx);
xMRC = xMRC(idx);
xMRCrms = xMRCrms(idx);
yMRC = yMRC(idx);
yMRCrms = yMRCrms(idx);
vMRCMean = mean(vMRC);
xMRCMean = mean(xMRC);
yMRCMean = mean(yMRC);
fig1 = figure;
hold on
% errorbar(tMRC-tMRC(1),(xMRC-xMRCMean),xMRCrms,'.')
% errorbar(tMRC-tMRC(1),(yMRC-yMRCMean),yMRCrms,'.')
plot(tMRC-tMRC(1),(xMRC-xMRCMean),'.')
plot(tMRC-tMRC(1),(yMRC-yMRCMean),'.')
hold off
legend("x position","y position")
xlabel("Time [s]")
ylabel("Position [V]")
render

fig2 = figure;
hold on
% errorbar(tMRC,(vMRC-vMRCMean)/vMRCMean,vMRCrms/vMRCMean,'.')
plot(tMRC-tMRC(1),(vMRC-vMRCMean)/vMRCMean,'.')


%% Scope
fig = openfig("B:\_Li\_LithiumData\2024\2024.12\12.18\03 - NiLattice_3\dataAnalysis\ScopeValue.fig");
ax = gca;
l = ax.Children;
tScope = l(1).XData(2:end);
vScope = l(3).YData(2:end);
vScopeMean = mean(vScope);
vScopeRms = l(2).YData(2:end);
close(fig)
plot(tScope-tScope(1),(vScope-vScopeMean)/vScopeMean,'.')


%% PD
t2 = readtable("MeasurementLog20241218");
t3 = readtable("MeasurementLog20241218 (2)");
t0 = [t2.Time_UTC_08_00M_d_yyyyH_mm_ssTt_;t3.Time_UTC_08_00M_d_yyyyH_mm_ssTt_];
t0 = seconds(t0 - t0(1));
vPD = [t2.Mean_A_BetweenRulers__V_ + 0.22;t3.Mean_A_BetweenRulers__V_ + 0.23];
vrms = [t2.RMSRipple_A_BetweenRulers__V_;t3.RMSRipple_A_BetweenRulers__V_];

vPDMean = mean(vPD);
% figure
% l = errorbar(t0,(vPD-vPDMean)/vPDMean,vrms/vPDMean,'.');
l = plot(t0,(vPD-vPDMean)/vPDMean,'.');
lg = legend("MRC PD","PID PD","Post-chamber PD");
xlabel("Time [s]")
ylabel("Normalized Power Deviation")
render

co = colororder;
% l.Color = co(2,:);
l.Marker = "x";

l = findobj(fig1,'Type','Line');
[l.MarkerSize] = deal(4);
% l = findobj(fig2,'Type','Errorbar');
% [l.MarkerSize] = deal(4);
l = findobj(fig2,'Type','Line');
[l.MarkerSize] = deal(4);
lg.Location = 'best';

load Config ComputerConfig
saveas(fig1,fullfile(ComputerConfig.TempPath,'MRC_Pointing.png'),'png')
saveas(fig2,fullfile(ComputerConfig.TempPath,'Power_Stability.png'),'png')
