close all

%% PD
t2 = readtable("MeasurementLog202523 (2)");
% t3 = readtable("MeasurementLog20241218 (2)");
t0 = [t2.Time_UTC_08_00M_d_yyyyH_mm_ssTt_];
t0 = seconds(t0 - t0(1));
vPD = [t2.Mean_A_BetweenRulers__V_];
% vPD2 = [t2.Mean_D_BetweenRulers__V_ + 0.125];
% vrms = [t2.RMSRipple_A_BetweenRulers__V_];

vPDMean = mean(vPD);
% vPD2Mean = mean(vPD2);
% figure
% l = errorbar(t0,(vPD-vPDMean)/vPDMean,vrms/vPDMean,'.');
figure
% l = plot(t0,(vPD-vPDMean)/vPDMean);
l = plot(t0,(vPD),'.');
% lg = legend("Post-chamber","PBS Reflection");
xlabel("Time [s]")
ylabel("PD voltage [V]")
render

co = colororder;
% l.Color = co(2,:);
% l.Marker = "x";

l = findobj(gcf,'Type','Line');
[l.MarkerSize] = deal(4);
% l = findobj(fig2,'Type','Errorbar');
% [l.MarkerSize] = deal(4);
l = findobj(gcf,'Type','Line');
[l.MarkerSize] = deal(4);
% lg.Location = 'best';

% load Config ComputerConfig
% saveas(gcf,fullfile(ComputerConfig.TempPath,'Power_Stability.png'),'png')
