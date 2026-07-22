%% Parameters
% trialNumber = [9117]; % Non-inverted
trialNumber = [9992]; % inverted
load LatticeCalib.mat
sName = "LatticeScope";
tRange = [1,1.1]*1e-3;

% trialNumberKP1Kd = 9114;
% trialNumberKP2Kd = 9115;
trialNumberKP1Kd = 9983;
trialNumberKP2Kd = 9985;

becExp = loadBecExp(trialNumberKP1Kd);
k(1) = becExp.KapitzaDirac.DepthOverAmplitude;
off(1) = mean(becExp.KapitzaDirac.PulseOffset);
becExp = loadBecExp(trialNumberKP2Kd);
k(2) = becExp.KapitzaDirac.DepthOverAmplitude;
off(2) = mean(becExp.KapitzaDirac.PulseOffset);

becExp = loadBecExp(trialNumber);
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0Target = becExp.HardwareData.hw_KPDepthEr(1);

atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0Target * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;

%% Get Data
V0 = zeros(1,becExp.NCompletedRun);
modDepth = zeros(2,becExp.NCompletedRun);
phaseDiff = zeros(1,becExp.NCompletedRun);
for runIdx = 1:becExp.NCompletedRun
    scope = becExp.loadScope(sName,runIdx);
    t = scope.TimeList;
    fs = 1/(t(2) - t(1));
    idx = t>=tRange(1) & t<=tRange(2);
    t = t(idx);
    f = becExp.HardwareData.hw_KPModFreq(runIdx);
    V = zeros(1,2);
    phase = zeros(1,2);
    alpha = becExp.HardwareData.hw_KPModDepthAlpha(runIdx);
    for ii = 1:2
        s = scope.Sample(ii,idx);
        % Y = fft(s);
        % L = length(s);
        % bin = round(f * L / fs) + 1; % Find the bin corresponding to frequency f
        % guessPhase = wrapTo2Pi(angle(Y(bin))+pi/2);
        basis = [sin(2*pi*f*t.'), cos(2*pi*f*t.')];
        coeffs = basis \ s.';
        guessPhase = wrapTo2Pi(atan2(coeffs(2), coeffs(1)));

        fd = SineFit1D([t.',s.']);
        fd.IsOverride = true;
        fd.setDefaultOverride;
        fd.StartPointOverride(2) = f;
        fd.LowerOverride(2) = f;
        fd.UpperOverride(2) = f;
        fd.StartPointOverride(3) = guessPhase;
        fd.do;
        V(ii) = k(ii) * (fd.Coefficient(4) - off(ii));
        phase(ii) = wrapToPi(fd.Coefficient(3));
        if ii == 1
            modDepthTarget = alpha / 2 * beta;
        else
            modDepthTarget = (1+alpha/2) * alpha / (2 + alpha) * beta;
        end
        modDepth(ii,runIdx) = (k(ii) * fd.Coefficient(1)/V0Target/modDepthTarget - 1);
        figure(ii)
        fd.NPlot = 1e6;
        plot(t.',s.',fd.FitPlotData(:,1),fd.FitPlotData(:,2));
        xlim([t(1),t(1)+10e-6])
    end
    V0(runIdx) = (abs(V(1) - V(2)) - V0Target)/V0Target;
    phaseDiff(runIdx) = (abs(diff(phase)) - pi)/pi;
    disp(runIdx)
end

%% Plot
plotError(V0,becExp,f0,"$V_0$")
plotError(phaseDiff,becExp,f0,"Phase Difference")
plotError(modDepth(1,:),becExp,f0,"Modulation Depth, KP1")
plotError(modDepth(2,:),becExp,f0,"Modulation Depth, KP2")

function plotError(data,becExp,f0,tt)
    alpha = becExp.HardwareData.hw_KPModDepthAlpha;
    freq = becExp.HardwareData.hw_KPModFreq;
    [x,y,data] = computeAveErr2D(alpha,freq,data,"None");
    figure
    imagesc(data,XData=x * becExp.HardwareData.hw_KPModDepthBeta(1),YData= y / f0)
    xlabel("$\alpha$")
    ylabel("$\Omega$")
    cb = colorbar;
    cb.Label.String = "Normalized Error";
    title(tt,'Interpreter','latex')
    render
    clim([-max(abs(data(:))),max(abs(data(:)))])
    colormap(bluewhitered)
    saveas(gcf,tt,"png")
end