%% Load Trial and get parameters
trialNumber = 8887;
becExp = loadBecExp(trialNumber);
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;

%% Load AdData and scan parameters
load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
[xTick,yTick,adData] = computeAveErr2D(...
    becExp.ScannedVariableList(1,:), ...
    becExp.ScannedVariableList(2,:), ...
    adData,"None");
f = xTick/f0;
alpha = yTick * beta;

%% Parameter verification
load LatticeCalib.mat
runIdx = 1;
sName = "LatticeScope";
scope = becExp.loadScope(sName,runIdx);
tRangeStatic = [0,24e-6];
tRangeSine = [30,120]*1e-6;
t = scope.TimeList;
idxStatic = t>=tRangeStatic(1) & t<=tRangeStatic(2);
idxSine = t>=tRangeSine(1) & t<=tRangeSine(2);

alphaRun = becExp.HardwareData.hw_KPModDepthAlpha(runIdx);
fRun = becExp.HardwareData.hw_KPModFreq(runIdx);
phiRun = asin(-2./alphaRun./beta);

V1 = mean(scope.Sample(1,idxStatic));
V1Target = KP1Depth2Pd(alphaRun / 2 * V0 * (1 + beta *sin(phiRun + pi)));
disp([V1,V1Target])

V2 = mean(scope.Sample(2,idxStatic));
V2Target = KP2Depth2Pd((alphaRun / 2 + 1) * V0 * (1 + beta * alphaRun ./(2 + alphaRun) * sin(phiRun)));
disp([V2,V2Target])

fd1 = SineFit1D([t(idxSine).',scope.Sample(1,idxSine).']);
fd1.IsOverride = true;
fd1.setDefaultOverride;
fd1.StartPointOverride(2) = fRun;
fd1.LowerOverride(2) = fRun;
fd1.UpperOverride(2) = fRun;
fd1.StartPointOverride(3) = pi/2;
fd1.do;

k1 = KP1Depth2Pd(2) - KP1Depth2Pd(1);
amp1 = fd1.Coefficient(1);
amp1Target = k1 * (alphaRun / 2 * beta * V0);
disp([amp1,amp1Target])

offset1 = fd1.Coefficient(4);
offset1Target = KP1Depth2Pd(alphaRun/2 * V0);

fd2 = SineFit1D([t(idxSine).',scope.Sample(2,idxSine).']);
fd2.IsOverride = true;
fd2.setDefaultOverride;
fd2.StartPointOverride(2) = fRun;
fd2.LowerOverride(2) = fRun;
fd2.UpperOverride(2) = fRun;
fd2.StartPointOverride(3) = pi/2;
fd2.do;

k2 = KP2Depth2Pd(2) - KP2Depth2Pd(1);
amp2 = fd2.Coefficient(1);
amp2Target = k2 * ((1 + alphaRun / 2) * beta * alphaRun / (2 + alphaRun) * V0);
disp([amp2,amp2Target])

offset2 = fd2.Coefficient(4);
offset2Target = KP2Depth2Pd((alphaRun/2 + 1) * V0);

disp((fd2.Coefficient(3) - fd1.Coefficient(3)-pi)/pi/2 / fRun * 1e9)

%% Plot adMix
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
ax.YDir = "normal";
ax.Colormap = jet;

renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
ax.TickDir = "out";
tickSpace = roiSize(2);
ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nx)-tickSpace/2);
ax.XTickLabel = string(f);
tickSpace = roiSize(1);
ax.YTick = (tickSpace/2):tickSpace:(tickSpace*double(ny)-tickSpace/2);
ax.YTickLabel = string(alpha);
set(ax,'box','off')

%% Plot IPR
cutoff = 100;
onedData = squeeze(sum(adData,2));
onedData = onedData(cutoff:end,:,:);
onedData = onedData./sum(onedData,1);
ipr = squeeze(sum(onedData.^2,1));

close(figure(103))
figure(103)

img = imagesc(ipr.',XData=alpha,YData=f);
title("$V_0 = "+V0 + "~E_{\mathrm{R}}$",'Interpreter','latex')
cb = colorbar;
cb.Label.String = "IPR";
xlabel("$\alpha$",'Interpreter','latex')
ylabel("$\Omega$",'Interpreter','latex')
clim([min(ipr(:)),.033])

