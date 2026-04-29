%% Load Trial and get parameters
% trialNumber = [8945,8946,8948];
% trialNumber = [9108,9109,9110]; % Inverted
trialNumber = [9117]; % Non-inverted
nTrial = numel(trialNumber);
% refTrialNumber = 8949;
refTrialNumber = 9107;
becExp = loadBecExp(refTrialNumber);
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
isNormalize = true;

%% Compute reference IPR
becExp = loadBecExp(refTrialNumber);
load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
ipr0 = computeIPR(adData);
[alpha0,ipr0,iprError] = computeAveErr(...
    becExp.ScannedVariableList(1,:), ...
    ipr0,"StdDev");
figure(48922)
errorbar(alpha0 * beta,ipr0,iprError,'.')
xlabel("$\alpha$")
ylabel("Initial State IPR")
render

%% Compute theoretical boundaries
alphaTheory = linspace(min(alpha0),max(alpha0),1000) * beta;
b1 = kpClassicalBoundary(alphaTheory,1);
b2 = kpClassicalBoundary(alphaTheory,2);
b3 = kpClassicalBoundary(alphaTheory,3);

%% Analyze trials
ipr = cell(1,nTrial);
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
    ipr{ii} = computeIPR(adData);
    if isNormalize
        ipr{ii} = ipr{ii}./repmat(ipr0,numel(f),1);
    end
    figure(ii + 2432)
    imagesc(ipr{ii},XData=alpha,YData=Omega)
    xlabel("$\alpha$")
    ylabel("$\Omega$")
    cb = colorbar;
    cb.Label.String = "Normalized IPR";
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
iprAverage = zeros(size(ipr{1}));
for ii = 1:nTrial
    iprAverage = iprAverage + ipr{ii};
end
iprAverage = iprAverage / nTrial;
figure(23452)
imagesc(iprAverage,XData=alpha,YData=Omega)
xlabel("$\alpha$")
ylabel("$\Omega$")
cb = colorbar;
cb.Label.String = "Normalized IPR";
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
clim([0,15])
ax = gca;
fz = 10;
roiSize = becExp.Roi.CenterSize(3:4);
yxBoundary = becExp.Roi.YXBoundary;
ax.Units = "normalized";
ax.XLabel.String = "$\Omega$";
ax.XLabel.Interpreter = "latex";
ax.XLabel.FontSize = fz;
ax.YLabel.String = "$\alpha$";
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



