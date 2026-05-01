close all
%% Load Trial and get parameters
% trialNumber = [8945,8946,8948];
% trialNumber = [9108,9109,9110]; % Inverted
% trialNumber = [9117]; % Non-inverted
% trialNumber = 9144;
trialNumber = 9157;
nTrial = numel(trialNumber);
% refTrialNumber = 8949;
% refTrialNumber = 9107;
% refTrialNumber = 9142;
refTrialNumber = 9155;
becExp = loadBecExp(refTrialNumber);
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
isNormalize = true;
metricName = "AtomNumber";
yCenter = 325;
windowWidth = 10;
numberWindow = yCenter - windowWidth:yCenter + windowWidth;

%% Compute reference IPR
becExp = loadBecExp(refTrialNumber);
load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
switch metricName
    case "IPR"
        metric0 = computeIPR(adData);
    case "AtomNumber"
        metric0 = computeCentralAtomNumber(adData,numberWindow);
    case "AtomNumberFraction"
        metric0 = computeCentralAtomNumberFraction(adData,numberWindow);
    case "AtomNumberFraction2"
        metric0 = computeCentralAtomNumberFraction2(adData,numberWindow);
end
[alpha0,metric0,metricError] = computeAveErr(...
    becExp.ScannedVariableList(1,:), ...
    metric0,"StdDev");
figure(48922)
errorbar(alpha0 * beta,metric0,metricError,'.')
xlabel("$\alpha$")
ylabel("Initial State Metric")
render

%% Compute theoretical boundaries
alphaTheory = linspace(min(alpha0),max(alpha0),1000) * beta;
b1 = kpClassicalBoundary(alphaTheory,1);
b2 = kpClassicalBoundary(alphaTheory,2);
b3 = kpClassicalBoundary(alphaTheory,3);

%% Analyze trials
metric = cell(1,nTrial);
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    isInverted = becExp.HardwareData.hw_KPIsInverted;
    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
    [alpha0,f,adData] = computeAveErr2D(...
    becExp.ScannedVariableList(1,:), ...
    becExp.ScannedVariableList(2,:), ...
    adData,"None");
    Omega = f/f0;
    alpha = alpha0 * beta;
    switch metricName
        case "IPR"
            metric{ii} = computeIPR(adData);
            cbStr = "IPR";
        case "AtomNumber"
            metric{ii} = computeCentralAtomNumber(adData,numberWindow);
            cbStr = "Central Peak Atom Number";
        case "AtomNumberFraction"
            metric{ii} = computeCentralAtomNumberFraction(adData,numberWindow);
            cbStr = "Central Peak Atom Fraction";
        case "AtomNumberFraction2"
            metric{ii} = computeCentralAtomNumberFraction2(adData,numberWindow);
            cbStr = "Central/Tail";
    end
    if isNormalize
        metric{ii} = metric{ii}./repmat(metric0(:).',numel(f),1);
        cbStr = cbStr + ", Normalized";
    end
    figure(ii + 2432)
    imagesc(metric{ii},XData=alpha,YData=Omega)
    xlabel("$\alpha$")
    ylabel("$\Omega$")
    cb = colorbar;
    cb.Label.String = cbStr;
    title("$V_0 = "+V0 + "~E_{\mathrm{R}},~\mathrm{LastCycle}-" + (ii-1) + "$",'Interpreter','latex')
    render
    hold on
    if isInverted
        plot(alphaTheory,b1,'--','LineWidth',1,'Color','w')
        plot(alphaTheory,b2,'--','LineWidth',1,'Color','w')
    else
        plot(alphaTheory,b3,'--','LineWidth',1,'Color','w')
    end
end

%% Plot average
metricAverage = zeros(size(metric{1}));
for ii = 1:nTrial
    metricAverage = metricAverage + metric{ii};
end
metricAverage = metricAverage / nTrial;
figure(23452)
imagesc(metricAverage,XData=alpha,YData=Omega)
xlabel("$\alpha$")
ylabel("$\Omega$")
cb = colorbar;
cb.Label.String = cbStr;
title("$V_0 = "+V0 + "~E_{\mathrm{R}},~\mathrm{Mean}" + "$",'Interpreter','latex')
render
hold on
if isInverted
    plot(alphaTheory,b1,'--','LineWidth',1,'Color','w')
    plot(alphaTheory,b2,'--','LineWidth',1,'Color','w')
else
    plot(alphaTheory,b3,'--','LineWidth',1,'Color','w')
end

%% Plot adMix
becExp = loadBecExp(trialNumber(1));
load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
[xTick,yTick,adData] = computeAveErr2D(...
    becExp.ScannedVariableList(1,:), ...
    becExp.ScannedVariableList(2,:), ...
    adData,"None");
Omega = yTick/f0;
alpha = xTick * beta;

close(figure(104))
figure(104)
[r, c, ny, nx] = size(adData);
mData = reshape(permute(adData, [1, 3, 2, 4]), r*ny, c*nx);
img = imagesc(gca,mData/becExp.Ad.Unit);
clim([0,4])
ax = gca;
fz = 10;
roiSize = becExp.Roi.CenterSize(3:4);
yxBoundary = becExp.Roi.YXBoundary;
ax.Units = "normalized";
ax.XLabel.String = "$\alpha$";
ax.XLabel.Interpreter = "latex";
ax.XLabel.FontSize = fz;
ax.YLabel.String = "$\Omega$";
ax.YLabel.Interpreter = "latex";
ax.YLabel.FontSize = fz;
ax.Title.String = "TrialName: " + becExp.Name + ...
    ", Trial \#" + num2str(becExp.SerialNumber);
ax.Title.Interpreter = "latex";
ax.Title.FontSize = fz;
ax.FontSize = fz;
ax.Colormap = jet;

renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
ax.TickDir = "out";
tickSpace = roiSize(2);
ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nx)-tickSpace/2);
ax.XTickLabel = string(alpha);
tickSpace = roiSize(1);
ax.YTick = (tickSpace/2):tickSpace:(tickSpace*double(ny)-tickSpace/2);
ax.YTickLabel = string(Omega);
set(ax,'box','off')
render

function N = computeCentralAtomNumber(adData,wd)
sz = size(adData);
adData = adData(wd,:,:);
sz(1) = numel(wd);
adData = reshape(adData,sz);
N = sum(adData,[1,2]);
N = squeeze(N);
% N = reshape(N,[1,sz(3:end)]);
end

function frac = computeCentralAtomNumberFraction(adData,wd)
onedData = squeeze(sum(adData,2));
onedData = onedData./sum(onedData,1);
sz = size(onedData);
fracData = onedData(wd,:);
sz(1) = numel(wd);
fracData = reshape(fracData,sz);
frac = squeeze(sum(fracData,1));
end

function frac = computeCentralAtomNumberFraction2(adData,wd)
onedData = squeeze(sum(adData,2));
onedData = onedData./sum(onedData,1);
sz = size(onedData);
fracData = onedData(wd,:);
sz(1) = numel(wd);
fracData = reshape(fracData,sz);
frac = squeeze(sum(fracData,1));
frac = frac./(1-frac);
end
