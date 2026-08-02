close all
%% Load Trial and get parameters
% trialNumber = [8945,8946,8948];
% trialNumber = [9108,9109,9110]; % Inverted
trialNumber = 10123; % inverted, 2ms mod, 10Er
refTrialNumber = 10122;
%trialNumber = [9117]; % Non-inverted
% trialNumber=9108
% trialNumber = 9144;
% trialNumber = 9249;
%trialNumber = 9402; %non-inverted, 1ms
outputFolder = 'B:\__Lab Member Folders\Nicole\Lithium\newpd';
mkdir(outputFolder)
nTrial = numel(trialNumber);
display(trialNumber);
% refTrialNumber = 8949;
%refTrialNumber = 9107;
% refTrialNumber = 9142;
%refTrialNumber = 9189; 
%refTrialNumber=9403; %non-inverted
becExp = loadBecExp(trialNumber); %prev loadBecExp(refTrialNumber)
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
% V0=10; % To overwrite to check theory curves
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
isNormalize = false;
metricName = "StdDev2";
yCenter = 325 ; % previously 325, width of 10? bec center here 456 - 120 (ROI y1 = 120; this is zero pt)
windowWidth = 10;
numberWindow = yCenter - windowWidth:yCenter + windowWidth;

% new input params
noiseFloor = 0; % for std dev v2; which includes baseline correction. this # sets the cutoff. any pts w/ density=(noiseFloor * peak density) set to 0
cropRadiusY = 55; % this is for adMix plot. increasing this "zooms out". 

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
    case "StdDev"
            metric0 = computeStDev(adData, 4e-6);
    case "StdDev2"
            metric0 = computeStDevWithBgSub(adData, 4e-6, noiseFloor); 
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
boundalphaTheory = linspace(max(beta*min(alpha0),250/139+1e-9),beta*max(alpha0),1000);
b1 = kpClassicalBoundary(alphaTheory,1);
b2 = kpClassicalBoundary(boundalphaTheory,2);
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
    %Omega=f;
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
        case "StdDev"
            metric{ii} = computeStDev(adData, 4e-6);
            cbStr = "StdDev";
        case "StdDev2"
            metric{ii} = computeStDevWithBgSub(adData, 4e-6, noiseFloor); 
            cbStr = "StdDev w/ Bkg. Corr. (" + num2str(noiseFloor * 100) + "\%) ";
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
    title("$(\#"+(trialNumber)+")\  V_0 = "+V0 + "~E_{\mathrm{R}},~\mathrm{LastCycle}-" + (ii-1) + "$",'Interpreter','latex');
    render
    hold on
    if isInverted
        plot(alphaTheory,b1,'--','LineWidth',1,'Color','w')
        plot(boundalphaTheory,b2,'--','LineWidth',1,'Color','w')
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
% colormap(hot)
cb = colorbar;
cb.Label.String = cbStr;
title("$(\#"+(trialNumber)+")\ V_0 = "+V0 + "~E_{\mathrm{R}},~\mathrm{Mean}" + "$",'Interpreter','latex')
render
hold on
if isInverted
    plot(alphaTheory,b1,'--','LineWidth',1,'Color','w')
    plot(boundalphaTheory,b2,'--','LineWidth',1,'Color','w')
else
    plot(alphaTheory,b3,'--','LineWidth',1,'Color','w')
end


writematrix(alpha(:), fullfile(outputFolder, 'phase_alpha_axis.csv'));
writematrix(Omega(:), fullfile(outputFolder, 'phase_omega_axis.csv'));
writematrix(metricAverage, fullfile(outputFolder, 'phase_ipr_matrix.csv'));

theory_matrix = [alphaTheory(:), b1(:), b2(:), b3(:)];
writematrix(theory_matrix, fullfile(outputFolder, 'phase_theory_boundaries.csv'));
%%  (OLD) Plot adMix
% becExp = loadBecExp(trialNumber(1));
% load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
% adData = flip(adData,1);
% [xTick,yTick,adData] = computeAveErr2D(...
%     becExp.ScannedVariableList(1,:), ...
%     becExp.ScannedVariableList(2,:), ...
%     adData,"None");
% Omega = yTick/f0;
% %Omega = yTick;
% alpha = xTick * beta;
% 
% close(figure(104))
% figure(104)
% [r, c, ny, nx] = size(adData);
% mData = reshape(permute(adData, [1, 3, 2, 4]), r*ny, c*nx);
% img = imagesc(gca,mData/becExp.Ad.Unit);
% clim([0,4])
% ax = gca;
% fz = 10;
% roiSize = becExp.Roi.CenterSize(3:4);
% yxBoundary = becExp.Roi.YXBoundary;
% ax.Units = "normalized";
% ax.XLabel.String = "$\alpha$";
% ax.XLabel.Interpreter = "latex";
% ax.XLabel.FontSize = fz;
% ax.YLabel.String = "$\Omega$";
% ax.YLabel.Interpreter = "latex";
% ax.YLabel.FontSize = fz;
% ax.Title.String = "TrialName: " + becExp.Name + ...
%     ", Trial \#" + num2str(becExp.SerialNumber);
% ax.Title.Interpreter = "latex";
% ax.Title.FontSize = fz;
% ax.FontSize = fz;
% ax.Colormap = jet;
% 
% renderTicks(img,[1,2],yxBoundary(1):yxBoundary(2))
% ax.TickDir = "out";
% tickSpace = roiSize(2);
% ax.XTick = (tickSpace/2):tickSpace:(tickSpace*double(nx)-tickSpace/2);
% ax.XTickLabel = string(alpha);
% tickSpace = roiSize(1);
% ax.YTick = (tickSpace/2):tickSpace:(tickSpace*double(ny)-tickSpace/2);
% ax.YTickLabel = string(Omega);
% set(ax,'box','off')
% render
%  % new (nh) testing theory curves on ad data plot ---------------------
% % --- OVERLAY THEORY BOUNDARIES ON IMAGE GRID ---
% hold on
% 
% % Sort alpha and Omega to ensure they are strictly monotonic for interpolation
% [sortAlpha, idxAlpha] = sort(alpha);
% sortXTick = ax.XTick(idxAlpha);
% 
% [sortOmega, idxOmega] = sort(Omega);
% sortYTick = ax.YTick(idxOmega);
% 
% % Interpolate physical alpha onto X pixel coordinates
% xPixTheory = interp1(sortAlpha, sortXTick, alphaTheory, 'linear', 'extrap');
% 
% % Interpolate boundary values onto Y pixel coordinates
% yPixB1 = interp1(sortOmega, sortYTick, b1, 'linear', 'extrap');
% yPixB2 = interp1(sortOmega, sortYTick, b2, 'linear', 'extrap');
% yPixB3 = interp1(sortOmega, sortYTick, b3, 'linear', 'extrap');
% 
% % Plot using the transformed pixel coordinates
% if isInverted
%     plot(xPixTheory, yPixB1, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
%     plot(xPixTheory, yPixB2, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
% else
%     plot(xPixTheory, yPixB3, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
% end

%-------------------end new
%% new admix test
% Plot adMix
becExp = loadBecExp(trialNumber(1));
load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
adData = flip(adData,1);
[xTick,yTick,adData] = computeAveErr2D(...
    becExp.ScannedVariableList(1,:), ...
    becExp.ScannedVariableList(2,:), ...
    adData,"None");
Omega = yTick/f0;
%Omega = yTick;
alpha = xTick * beta;

% --- NEW CROPPING LOGIC ---
% The raw ROI has too much empty vertical space (noise floor).
% Let's crop the Y-axis to zoom in on the atomic clouds.
[r_orig, c_orig, ny, nx] = size(adData);
yCenter = round(r_orig / 2);

% Define how many pixels above and below the center you want to keep.
% Adjust this value to zoom in more or less! 
 
yCropIdx = max(1, yCenter - cropRadiusY) : min(r_orig, yCenter + cropRadiusY);

% (Optional) You can also crop the X-axis if they are too wide
% xCenter = round(c_orig / 2);
% cropRadiusX = 40;
% xCropIdx = max(1, xCenter - cropRadiusX) : min(c_orig, xCenter + cropRadiusX);
xCropIdx = 1:c_orig; % Keeping full width for now

% Apply the crop
adData = adData(yCropIdx, xCropIdx, :, :);
% --------------------------

close(figure(104))
figure(104)

% Get the NEW cropped dimensions
[r, c, ny, nx] = size(adData);
mData = reshape(permute(adData, [1, 3, 2, 4]), r*ny, c*nx);
img = imagesc(gca,mData/becExp.Ad.Unit);
clim([0,4])
ax = gca;
fz = 10;
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

% Update ticks to use the new cropped dimensions (c and r) instead of roiSize
ax.XTick = (c/2):c:(c*double(nx)-c/2);
ax.XTickLabel = num2str(alpha(:), '%.1f');

ax.YTick = (r/2):r:(r*double(ny)-r/2);
ax.YTickLabel = num2str(Omega(:), '%.1f');

set(ax,'box','off')
render

% new (nh) testing theory curves on ad data plot ---------------------
% --- OVERLAY THEORY BOUNDARIES ON IMAGE GRID ---
hold on
% Sort alpha and Omega to ensure they are strictly monotonic for interpolation
[sortAlpha, idxAlpha] = sort(alpha);
sortXTick = ax.XTick(idxAlpha);
[sortOmega, idxOmega] = sort(Omega);
sortYTick = ax.YTick(idxOmega);
% Interpolate physical alpha onto X pixel coordinates
xPixTheory = interp1(sortAlpha, sortXTick, alphaTheory, 'linear', 'extrap');
boundxPixTheory=interp1(sortAlpha, sortXTick, boundalphaTheory, 'linear', 'extrap');
% Interpolate boundary values onto Y pixel coordinates
yPixB1 = interp1(sortOmega, sortYTick, b1, 'linear', 'extrap');
yPixB2 = interp1(sortOmega, sortYTick, b2, 'linear', 'extrap');
yPixB3 = interp1(sortOmega, sortYTick, b3, 'linear', 'extrap');
% Plot using the transformed pixel coordinates
if isInverted
    plot(xPixTheory, yPixB1, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
    plot(boundxPixTheory, yPixB2, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
else
    plot(xPixTheory, yPixB3, '--', 'LineWidth', 0.75, 'Color', [1 1 1 0.5])
end
%% functions
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

function width = computeStDev(adData,pxsize)
onedData = squeeze(sum(adData,2));
onedData=onedData./sum(onedData,1);
counts=size(onedData,2);
pos=pxsize*(1:length(onedData));
% size(pos)
meanpos=sum(repmat(pos',1, counts) .*onedData,1)./sum(onedData,1);
% size(repmat(pos',1, counts))
% size(onedData)
% size(sum(onedData, 1));
var=sum((repmat(pos',1, counts)-meanpos).^2.*onedData,1)./sum(onedData,1);
size(abs(var))
width=sqrt(squeeze((abs(var))));
size(width);
min(var, [],'all')
max(var, [], 'all')
end

function width = computeStDevWithBgSub(adData, px, noiseFloorPct)
    if nargin < 3
        noiseFloorPct = 0.02; % Default to 2% noise threshold
    end

    % 1. Integrate along X (dim 2)
    onedData = squeeze(sum(adData, 2));
    nPos = size(onedData, 1);
    
    % 2. Dynamic Baseline Correction (Edge-based)
    % Create a mask for the first and last 10% of the window
    edgeIdx = max(1, round(nPos * 0.10));
    edgeMask = false(nPos, 1);
    edgeMask([1:edgeIdx, nPos-edgeIdx+1:nPos]) = true;
    
    % Calculate the mean of the edges. Multiplying by the mask inherently
    % handles any number of parameter scan dimensions you throw at it!
    bgOffset = sum(onedData .* edgeMask, 1) / sum(edgeMask);
    onedData = onedData - bgOffset;
    
    % 3. Noise Thresholding
    % Find the peak of each profile and zero out anything below 2% of it.
    % (This also completely removes any negative values left over from subtraction)
    peakDensities = max(onedData, [], 1);
    onedData(onedData < noiseFloorPct .* peakDensities) = 0;
    
    % 4. Calculate Moments (Implicit Expansion)
    mass = sum(onedData, 1);
    pos = px * (1:nPos)'; % Column vector
    
    % pos .* onedData automatically expands without needing repmat
    meanpos = sum(pos .* onedData, 1) ./ mass;
    variance = sum(((pos - meanpos).^2) .* onedData, 1) ./ mass;
    
    % 5. Output
    width = sqrt(squeeze(variance));
end