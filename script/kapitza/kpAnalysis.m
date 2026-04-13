trialNumber = 8887;
becExp = loadBecExp(trialNumber);
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);


atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;


load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
[xTick,yTick,adData] = computeAveErr2D(...
    becExp.ScannedVariableList(1,:), ...
    becExp.ScannedVariableList(2,:), ...
    adData,"None");
f0 = ol.HarmonicFrequency;
f = xTick/f0;
alpha = yTick * beta;

close(figure(104))
figure(104)
[r, c, ny, nx] = size(adData);
mData = reshape(permute(adData, [1, 3, 2, 4]), r*ny, c*nx);
img = imagesc(gca,mData/becExp.Ad.Unit);
clim([0,12])
ax = gca;
%% Render
fz = 20;
roiSize = becExp.Roi.CenterSize(3:4);
yxBoundary = becExp.Roi.YXBoundary;
% targetWidth = figPos(3)*0.85;
% targetHeight = figPos(4)*0.8;
% ax.Units = "pixels";
% if targetWidth > targetHeight * aspect
%     ax.Position(4) = targetHeight;
%     ax.Position(3) = targetHeight * aspect;
% else
%     ax.Position(3) = targetWidth;
%     ax.Position(4) = targetWidth / aspect;
% end
% ax.Position(1:2) = [figPos(3)/2 - ax.Position(3)/2,...
%     figPos(4)/2 - ax.Position(4)/2];
% pbaspect(ax,[aspect,1,1])

ax.Units = "normalized";
ax.XLabel.String = becExp.XLabel;
ax.XLabel.Interpreter = "latex";
ax.XLabel.FontSize = fz;
ax.YLabel.String = becExp.YLabel;
ax.YLabel.Interpreter = "latex";
ax.YLabel.FontSize = fz;
ax.Title.String = "TrialName: " + becExp.Name + ...
    ", Trial \#" + num2str(becExp.SerialNumber);
ax.Title.Interpreter = "latex";
ax.Title.FontSize = fz;
ax.FontSize = fz;
ax.YDir = "normal";

renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
ax.TickDir = "out";
tickSpace = roiSize(2);
ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nx)-tickSpace/2);
ax.XTickLabel = string(xTick);
tickSpace = roiSize(1);
ax.YTick = (tickSpace/2):tickSpace:(tickSpace*double(ny)-tickSpace/2);
ax.YTickLabel = string(yTick);
set(ax,'box','off')







cutoff = 90;
onedData = squeeze(sum(adData,2));
onedData = onedData(cutoff:end,:,:);
onedData = onedData./sum(onedData,1);
ipr = squeeze(sum(onedData.^2,1));



close(figure(103))
figure(103)

img = imagesc(ipr.',XData=alpha,YData=f);
title("$V_0 = "+V0 + "~E_R$")
cb = colorbar;
cb.Label.String = "IPR";
xlabel("$\alpha$")
ylabel("$\Omega$")
% clim([min(ipr(:)),9])

