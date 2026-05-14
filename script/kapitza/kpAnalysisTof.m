close all
%% Load Trial and get parameters
trialNumber = [9209,9212,9213,9214];
nTrial = numel(trialNumber);
becExp = loadBecExp(trialNumber(1));
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
labels = ["Stable","Weak-Drive","Chaotic","Expected-Stable"];
center = 223;
ps = becExp.Acquisition.PixelSizeReal;
tTof = becExp.CiceroData.TOF(1) * 1e-6;
pUnit = Constants.SI("hbar") * laser.AngularWavenumber / atom.mass * tTof * 2 / ps;


%% Plot AdMix
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    switch becExp.HardwareData.hw_KPIsInverted(1)
        case 1
            isInvertedLabel = "Inverted";
        case 0
            isInvertedLabel = "Non-inverted";
    end

    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"),"adData")
    close(figure(ii+2342))
    figure(ii+2342)
    ax = gca;
    adData = flip(adData,1);
    [xTick,adData] = computeAveErr(...
        becExp.ScannedVariableList(1,:), ...
        adData,"None");
    nRun = numel(xTick);
    cData = cell(1,nRun);

    for jj = 1:numel(xTick)
        cData{jj} = adData(:,:,jj);
    end
    mData = horzcat(cData{:}) /becExp.Ad.Unit;

    img = imagesc(ax,mData);
    clim([0,0.5])
    cb = colorbar;
    colormap(jet)

    x = becExp.ScannedVariableListSorted;
    nRun = numel(x);
    step = x(2) - x(1);
    x = linspace(min(x)-step/2,max(x)+step/2,100);
    x = x - 0.03;
    x = x * 1e3;
    yRange = size(mData,1);
    y = ((1:yRange) - center) / pUnit;
    img.XData = x;
    img.YData = y;
    ax.XLim = [min(x),max(x)];
    ax.YLim = [min(y),max(y)];
    alpha = becExp.HardwareData.hw_KPModDepthAlpha(1) * becExp.HardwareData.hw_KPModDepthBeta(1);
    Omega = becExp.HardwareData.hw_KPModFreq(1) / f0;
    V0 = becExp.HardwareData.hw_KPDepthEr(1);
    ax.Title.String = isInvertedLabel + ", $V_0 = " +V0 + "\,E_{\mathrm R},~\alpha = " + alpha + ",~\Omega = " + Omega + "$, " + labels(ii);
    ax.XLabel.String = "Time [$\mu$s]";
    ax.YLabel.String = "Momentum [$2\hbar k_{\mathrm L}$]";
    ax.FontSize = 14;
    ax.LineWidth = 1;
    ax.TickDir = "out";
    fig = gcf;
    cb.Label.String = "Atomic Density [a.u.]";
    cb.Label.FontSize = 14;
    cb.Label.Interpreter = "latex";    
    fig.Units = "inches";
    fig.Position(3) = 6.825 * 0.85   * 1.5 * 1.2;
    fig.Position(4) = 700/96 * 0.9 * 0.9 * 0.8 * 1.2;
    exportgraphics(gcf,labels(ii)+".png","Resolution",600)
end

%% Plot momentum order
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    switch becExp.HardwareData.hw_KPIsInverted(1)
        case 1
            isInvertedLabel = "Inverted";
        case 0
            isInvertedLabel = "Non-inverted";
    end

    N = squeeze(becExp.AtomNumber.Raw./sum(becExp.AtomNumber.Raw,3));
    NOrder = floor(size(N,2)/2);
    Nplot = zeros(size(N,1),NOrder + 1);
    leftWing = N(:,1:NOrder);
    rightWing = N(:,(NOrder+2):end);
    Nplot(:,1) = N(:,NOrder+1);
    Nplot(:,2:end) = (flip(leftWing,2) + rightWing) / 2;
    orderLabel = "$n=" + (0:NOrder)+ "$";

    close(figure(ii+22345))
    figure(ii+22345)
    ax = gca;

    x = becExp.ScannedVariableListSorted * 1e3 - 30;
    plot(x,Nplot,'LineWidth',1.5);
    legend(orderLabel(:),'Interpreter','latex','FontSize',14);

    alpha = becExp.HardwareData.hw_KPModDepthAlpha(1) * becExp.HardwareData.hw_KPModDepthBeta(1);
    Omega = becExp.HardwareData.hw_KPModFreq(1) / f0;
    V0 = becExp.HardwareData.hw_KPDepthEr(1);
    ax.Title.String = isInvertedLabel + ", $V_0 = " +V0 + "\,E_{\mathrm R},~\alpha = " + alpha + ",~\Omega = " + Omega + "$, " + labels(ii);
    ax.XLabel.String = "Time [$\mu$s]";
    ax.YLabel.String = "Population";
    ax.FontSize = 14;
    ax.LineWidth = 1;
    ax.TickDir = "out";
        
    fig = gcf;    
    fig.Units = "inches";
    fig.Position(3) = 6.825 * 0.85   * 1.5 * 1.2;
    fig.Position(4) = 700/96 * 0.9 * 0.9 * 0.8 * 1.2;
    exportgraphics(gcf,labels(ii) + "_Population"+".png","Resolution",600)
end
