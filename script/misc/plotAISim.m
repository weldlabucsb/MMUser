close all
%% Bench mark
trialNumber = [36,37];
lgs = ["$t = 14.5\,\mathrm{ms}$","$t = 16.4\,\mathrm{ms}$"];
fig = figure(4382);
ax = gca;
hold on
for ii = 1:numel(trialNumber)
    obj = loadTrial(createReader("simulation"),"lattice_fourier_simulation_1d",trialNumber(ii));
    openfig(fullfile(obj.DataAnalysisPath,"AI_Force_Scan.fig"));
    figOrigin = gcf;
    l = findobj(figOrigin,'type','Line');
    if ii ==2 
        benchmarkData = [l.XData;l.YData];
    end
    ll = plot(ax,l.XData,l.YData);
    close(figOrigin)
end
xlabel("$T_{\mathrm{B}}$ (ms)")
ylabel("$D$ Band Fraction")
legend(lgs)
render
ax.XLim = [min(benchmarkData(1,:)),max(benchmarkData(1,:))];
ax.YLim = [0,1];
exportgraphics(gcf,"temp\AI_Benchmark.png","Resolution",300)
close all

%% Compare
trialNumber = 45:53;
sigmaList = [1.53,5,10];
curvList = [0,2];
lgs = ["$\sigma =\,1.53\mu\mathrm{m},~f=0$,~no Gaussian";
    "$\sigma =\,5\mu\mathrm{m},~f=0$,~no Gaussian";
    "$\sigma =\,10\mu\mathrm{m},~f=0$,~no Gaussian";
    "$\sigma =\,1.53\mu\mathrm{m},~f=2$,~no Gaussian";
    "$\sigma =\,5\mu\mathrm{m},~f=2$,~no Gaussian";
    "$\sigma =\,10\mu\mathrm{m},~f=2$,~no Gaussian";
    "$\sigma =\,1.53\mu\mathrm{m},~f=2$,~Gaussian";
    "$\sigma =\,5\mu\mathrm{m},~f=2$,~Gaussian";
    "$\sigma =\,10\mu\mathrm{m},~f=2$,~Gaussian";
    "Benchmark"
    ];
fig = figure(4512);
ax = gca;
hold on
for ii = 1:numel(trialNumber)
    obj = loadTrial(createReader("simulation"),"lattice_schrodinger_equation_simulation_1d",trialNumber(ii));
    figOrigin = openfig(fullfile(obj.DataAnalysisPath,"AI_Force_Scan.fig"));
    l = findobj(figOrigin,'type','Line');
    ll(ii) = plot(ax,l.XData,l.YData);
    close(figOrigin)
end
plot(ax,benchmarkData(1,:),benchmarkData(2,:))
xlabel("$T_{\mathrm{B}}$ (ms)")
ylabel("$D$ Band Fraction")
legend(lgs)
render
ax.XLim = [min(benchmarkData(1,:)),max(benchmarkData(1,:))];
ax.YLim = [0,1];
[ll(4:6).LineStyle] = deal('--');
[ll(7:9).LineStyle] = deal('-.');
fig.Position(3:4) = fig.Position(3:4) * 2.3;
exportgraphics(gcf,"temp\AI_Compare_Systematics.png","Resolution",300)
movegui("center")
close all

%% Compare with Xuanwei
fig = figure(5427);
ax = gca;
hold on

trialNumber = 51:53;
lgs = [
    "$\sigma =\,1.53\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian";
    "$\sigma =\,5\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian";
    "$\sigma =\,10\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian";
    "$\sigma =\,1.53\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian,~interacting";
    "$\sigma =\,5\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian,~interacting";
    "$\sigma =\,10\mu\mathrm{m},~f=2\,\mathrm{Hz}$,~Gaussian,~interacting";
    "Benchmark"
    ];
intCSVName = [
    "AI_BO_Force_Scan_p5BO_Curvature_Interaction_GaussianBeam_1p53um_GPE";
    "AI_BO_Force_Scan_p5BO_Curvature_Interaction_GaussianBeam_5um_GPE";
    "AI_BO_Force_Scan_p5BO_Curvature_Interaction_GaussianBeam_10um_GPE";
    ];
for ii = 1:3
    obj = loadTrial(createReader("simulation"),"lattice_schrodinger_equation_simulation_1d",trialNumber(ii));
    figOrigin = openfig(fullfile(obj.DataAnalysisPath,"AI_Force_Scan.fig"));
    l = findobj(figOrigin,'type','Line');
    ll(ii) = plot(ax,l.XData,l.YData);
    close(figOrigin)
end

for ii = 1:3
    data = readtable(intCSVName(ii));
    data = table2array(data);
    ll(ii+3) = plot(ax,data(1,:),data(2,:));
end
plot(ax,benchmarkData(1,:),benchmarkData(2,:))
xlabel("$T_{\mathrm{B}}$ (ms)")
ylabel("$D$ Band Fraction")
legend(lgs)
render
ax.XLim = [min(benchmarkData(1,:)),max(benchmarkData(1,:))];
ax.YLim = [0,1];
[ll(4:6).LineStyle] = deal('--');
fig.Position(3:4) = fig.Position(3:4) * 2.3;
exportgraphics(gcf,"temp\AI_Compare_Systematics_Interacting.png","Resolution",300)
movegui("center")
close all


