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

%% Plot AdMix
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"),"adData")
    becExp.Ad.plotAdMix(adData);
    ax = gca;
    % ax.XTick = [];
    ax.XTickMode = "auto";
    ax.XTickLabelMode = "auto";
    img = ax.Children(1);
    x = becExp.ScannedVariableListSorted;
    nRun = numel(x);
    step = x(2) - x(1);
    x = linspace(min(x)-step/2,max(x)+step/2,100);
    x = x - 0.03;
    x = x * 1e3;
    img.XData = x;
    ax.XLim = [min(x),max(x)];
    alpha = becExp.HardwareData.hw_KPModDepthAlpha(1) * becExp.HardwareData.hw_KPModDepthBeta(1);
    Omega = becExp.HardwareData.hw_KPModFreq(1) / f0;
    V0 = becExp.HardwareData.hw_KPDepthEr(1);
    ax.Title.String = "$V_0 = " +V0 + "\,E_{\mathrm R},~\alpha = " + alpha + ",~\Omega = " + Omega + "$, " + labels(ii);
    ax.XLabel.String = "Time [$\mu$s]";
    exportgraphics(gcf,labels(ii)+".png","Resolution",600)
end
