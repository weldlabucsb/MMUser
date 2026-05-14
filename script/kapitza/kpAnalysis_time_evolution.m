%% Load Trial and get parameters
trialNumber = 9041:9043;
nTrial = numel(trialNumber);
becExp = loadBecExp(trialNumber(1));
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
isNormalize = true;
yCut = 200;
xCut = 5;
ps = becExp.Acquisition.PixelSizeReal;
labels = ["Chaotic","Stable","Weak-Drive"];

%% Plot Admix
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    if isfield(becExp.HardwareData,"hw_KPIsInverted")
        switch becExp.HardwareData.hw_KPIsInverted(1)
            case 1
                isInvertedLabel = "Inverted";
            case 0
                isInvertedLabel = "Non-inverted";
        end
    else
        isInvertedLabel = "Inverted";
    end

    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"),"adData")
    close(figure(ii+2342))
    figure(ii+2342)
    ax = gca;
    adData = flip(adData,1);
    [xTick,adData] = computeAveErr(...
        becExp.ScannedVariableList(1,:), ...
        adData,"StdErr");
    nRun = numel(xTick);
    cData = cell(1,nRun);

    for jj = 1:numel(xTick)
        cData{jj} = adData(:,:,jj);
    end
    mData = horzcat(cData{:}) /becExp.Ad.Unit;

    img = imagesc(ax,mData);
    clim([0,2])
    cb = colorbar;
    colormap(jet)

    x = xTick;
    nRun = numel(x);
    step = x(2) - x(1);
    x = linspace(min(x)-step/2,max(x)+step/2,100);
    x = x * 1e3;
    yRange = size(mData,1);
    y = (1:yRange) * ps / 1e-6;
    y = y - mean(y);
    img.XData = x;
    img.YData = y;
    ax.XLim = [min(x),max(x)];
    ax.YLim = [min(y),max(y)];
    alpha = becExp.HardwareData.hw_KPModDepthAlpha(1) * becExp.HardwareData.hw_KPModDepthBeta(1);
    Omega = becExp.HardwareData.hw_KPModFreq(1) / f0;
    V0 = becExp.HardwareData.hw_KPDepthEr(1);
    ax.Title.String = isInvertedLabel + ", $V_0 = " +V0 + "\,E_{\mathrm R},~\alpha = " + alpha + ",~\Omega = " + Omega + "$, " + labels(ii);
    ax.XLabel.String = "Time [ms]";
    ax.YLabel.String = "Position [$\mu$m]";
    ax.YLabel.Interpreter = "latex";
    ax.FontSize = 14;
    ax.LineWidth = 1;
    ax.TickDir = "out";
    fig = gcf;
    cb.Label.String = "Atomic Density [a.u.]";
    cb.Label.FontSize = 14;
    cb.Label.Interpreter = "latex";    
    fig.Units = "inches";
    fig.Position(3) = 6.825 * 0.85   * 1.5 * 1.2/1.5;
    fig.Position(4) = 700/96 * 0.9 * 0.9 * 0.8 * 1.2;
    exportgraphics(gcf,labels(ii) + "_RealSpace" +".png","Resolution",600)
end


%% Plot IPR
ipr = cell(1,nTrial);
t = cell(1,nTrial);
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
    [t{ii},adData] = computeAveErr(...
    becExp.ScannedVariableList(1,:), ...
    adData,"StdDev");
    ipr{ii} = computeIPR(adData(yCut+1:end-yCut,xCut+1:end-xCut,:));
    if isNormalize
        ipr{ii} = ipr{ii}./ipr{ii}(1);
    end
end
close(figure(234))
figure(234)
hold on
for ii = 1:nTrial
    plot(t{ii} * 1e3,ipr{ii})
end
xlabel("Time [ms]")
if isNormalize
    ylabel("Normalized IPR")
else
    ylabel("IPR")
end
legend("Chaotic","Stable","Weak Drive")
render



