close all

%% MRC
t = readtable("BeamStab_2024-12-27T13-47-10.csv");
t0 = t.ms * 1e-3 * 2 ;
v0 = t.I1_V_;
x = t.X1_V_;
y = t.Y1_V_;
figure
plot(t0,v0);
 
T = 25.2188;
T =  25.21;
tIni = 25.24-2;
dt = 4;
mrc = [];
allidx = find(v0 > 1.38);
startidx = 1+[0;find(diff(allidx)>1)];
endidx = [startidx(2:end)-1;numel(allidx)];
nrun = numel(startidx);

tMRC = zeros(1,nrun);
vMRC = zeros(1,nrun);
vMRCrms = zeros(1,nrun);
xMRC = zeros(1,nrun);
xMRCrms = zeros(1,nrun);
yMRC = zeros(1,nrun);
yMRCrms = zeros(1,nrun);
for ii = 1:nrun
    idx = allidx(startidx(ii):endidx(ii));
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
% fig = openfig("B:\_Li\_LithiumData\2024\2024.12\12.21\01 - NiLattice_1\dataAnalysis\ScopeValue.fig");
% ax = gca;
% l = ax.Children;
% tScope = l(1).XData;
% vScope = l(3).YData;
% vScopeMean = mean(vScope);
% vScopeRms = l(2).YData;
% close(fig)
% plot(tScope-tScope(1),(vScope-vScopeMean)/vScopeMean,'.')


%% PD
t2 = readtable("MeasurementLog20241227");
% t3 = readtable("MeasurementLog20241218 (2)");
t0 = [t2.Time_UTC_08_00M_d_yyyyH_mm_ssTt_];
t0 = seconds(t0 - t0(1));
vPD = [t2.Mean_A_BetweenRulers__V_ + 0.235];
vrms = [t2.RMSRipple_A_BetweenRulers__V_];

vPDMean = mean(vPD);
% figure
% l = errorbar(t0,(vPD-vPDMean)/vPDMean,vrms/vPDMean,'.');
l = plot(t0,(vPD-vPDMean)/vPDMean,'.');
lg = legend("MRC PD","Post-chamber PD");
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
