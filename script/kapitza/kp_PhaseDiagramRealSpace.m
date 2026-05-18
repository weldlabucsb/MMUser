%% set laser and atom
atom = getAtom("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 0.6, ...
    waist = 60e-6 ...
    );
laser = {laser};

%% set optical lattice
ol = OpticalLattice(atom,laser{1});
ol.DepthSpec = 10 * ol.RecoilEnergy;
ol.updateIntensity;
kL = ol.Laser.AngularWavenumber;
laser = {ol.Laser};
f0 = ol.HarmonicFrequency;

%% compute inverted initial state initial condition
sRange = round(1.5e-3 / (ol.Laser.Wavelength / 2)) * ol.Laser.Wavelength / 2;
sStep = 2.5e-8;
% sStep = 1e-8;
q0 = 0;
sStep = convertSpaceStep(sRange,sStep);
x = (-sRange(1)/2 : sStep : sRange(1)/2).';
% sigma = 2e-6;
% tExp = 17e-3;
% sigma = 13.3e-6;
nIC = 10;
tExp = 0;
sigmaList = linspace(2e-6,20e-6,nIC);


temp = ol.DepthSpec;
ol.DepthSpec = -temp;

[~,~,phi] = ol.computeBand1D(q0,0,x);
ol.DepthSpec = temp;
hbar = Constants.SI("hbar");
M = atom.mass;

% clear ic
% for ii = 1:nIC
% ic(ii) = InitialCondition("SeSim1D");
% sigma = sigmaList(ii);
% psi = (sqrt(2*pi*sigma^2)*(1+1i*hbar*tExp/2/M/sigma^2))^(-1/2) * ...
%     exp(-(x).^2/4/sigma^2/(1+1i*hbar*tExp/2/M/sigma^2)) .* phi;
% ic(ii).WaveFunction = psi;
% end

clear ic
ic = InitialCondition("SeSim1D");
sigma = 30e-6;
psi = (sqrt(2*pi*sigma^2)*(1+1i*hbar*tExp/2/M/sigma^2))^(-1/2) * ...
    exp(-(x).^2/4/sigma^2/(1+1i*hbar*tExp/2/M/sigma^2)) .* phi;
ic.WaveFunction = psi;

%% set modulation
modTimeAll = 1000e-6;
nGrid = 10;
modFreqList = linspace(100e3,2.4e6,nGrid);
modAmpList = linspace(2,30,nGrid);
% modAmpList = 27.1111;
% modFreqList = 2.4e6;

[modAmpList,modFreqList] = meshgrid(modAmpList,modFreqList);
modTime = ceil(modTimeAll.*modFreqList)./modFreqList;
modPhaseList = asin(-2./modAmpList);
nMod = numel(modAmpList);

latticeMod = cell(1,nMod);
for ii = 1:nMod
    s = SineWave( ...
        amplitude = 2 * modAmpList(ii), ...
        duration  = modTime(ii), ...
        frequency = modFreqList(ii), ...
        phase     = modPhaseList(ii),...
        startTime = 0);
    latticeMod{ii} = WaveformList("LatticeMod");
    latticeMod{ii}.WaveformOrigin = {s};
    latticeMod{ii}.SamplingRate = 20e6;
end
% dt = sqrt((1./modFreqList/20).^2 + (1./modAmpList/ol.RecoilEnergy/10/20).^2);

%% Simulation
se = LatticeSeSim1D("Kapitza", ...
    atom=atom,...
    laser = laser,...
    initialCondition = ic,...
    latticeModulation = latticeMod,...
    timeStep   = 2e-9,...
    totalTime  = modTime(1),...
    spaceRange = sRange,...
    spaceStep = sStep);
se.SavePeriod = 5e4;
se.AveragePeriod = 5e3;
se.Description = "Kapitza TDSE simulation.";
se.IsUsingGpu = false;
se.updateTrialType;

for ii = 1:nMod
    se.SimRun(ii).TotalTime = modTime(ii);
    se.SimRun(ii).IsUsingGpu = false;
end

se.start

%% Data analysis
% se = loadSim(134 ...
%     ,"LatticeSeSim1D");
metric = zeros(1,se.NRun);
wfi = se.InitialCondition.WaveFunction;
wfi = wfi./sqrt(sum(abs(wfi).^2));
sr = 1 / se.TimeStep / se.AveragePeriod;

ol = OpticalLattice(se.Atom,se.Laser{1});
f0 = ol.HarmonicFrequency;
modFreq = zeros(1,se.NCompletedRun);
modAmp = zeros(1,se.NCompletedRun);
metricMethod = "IPRBlur";
dx = se.SimRun(1).SpaceStep;
windowSize = round(5e-6/dx);
se.showSpaceTime

for ii = 1:se.NRun
    wff = se.SimRun(ii).readRun("FinalWaveFunction");
    wff = wff ./ sqrt(sum(abs(wff).^2,2));
    modFreq(ii) = se.LatticeModulation{ii}.WaveformOrigin{1}.Frequency;
    modAmp(ii) = se.LatticeModulation{ii}.WaveformOrigin{1}.Amplitude / 2;

    switch metricMethod
        case "IPR"
            metric(ii) = sum(abs(wff).^4,2);
        case "IPRBlur"
            smoothedData = smoothdata(abs(wff).^2, 'gaussian', windowSize);
            smoothedData = smoothedData./sum(smoothedData);
            % plot(x,abs(wff).^2,x,smoothedData)
            metric(ii) = sum(abs(smoothedData).^2,2);
        case "Correlation"
            metric(ii) = ((abs(wff).^2) * (abs(wfi).^2));
    end
    % nModCycle = round(se.SimRun(ii).TotalTime * modFreq(ii));
    % tList = se.TimeStep * se.AveragePeriod:se.TimeStep * se.AveragePeriod:nModCycle/modFreq(ii);
    % ml = min(numel(metric),numel(tList));
    % tList = tList(1:ml);
    % metric = metric(1:ml);
    % metric = metric./metric(1);
    % ctinterp = @(x) interp1(tList.',metric,x,"pchip",'extrap');
    % tSample = (nModCycle-20)/modFreq(ii):1/modFreq(ii):(nModCycle-1)/modFreq(ii);
    % overlap(ii) = mean(ctinterp(tSample));
    % metric(ii) = mean(ctinterp(tSample));
    disp(ii)
end
alphaTheory = linspace(min(modAmp),max(modAmp),1000);
b1 = kpClassicalBoundary(alphaTheory,1);
b2 = kpClassicalBoundary(alphaTheory,2);

metric = reshape(metric,nGrid,nGrid);
figure(2354)
ax = gca;
img = imagesc(ax,metric);

modFreqList = sort(unique(modFreq)/f0);
modAmpList = sort(unique(modAmp));
img.XData = modAmpList;
img.YData = modFreqList;
ax.XLim = [min(modAmpList)-0.5,max(modAmpList)+0.5];
ax.YLim = [min(modFreqList)-0.5,max(modFreqList)+0.5];
xlabel("\alpha")
ylabel("\Omega")
title("V_0 = " + ol.DepthLu + " E_R")
cb = colorbar;
cb.Label.String = metricMethod;

hold on
plot(alphaTheory,b1,'--','LineWidth',1,'Color','w')
plot(alphaTheory,b2,'--','LineWidth',1,'Color','w')

%% Compute IPR evolution
sigmaPList = (hbar / 2 ./ sigmaList) / hbar / kL;
metric = cell(nIC,1);
metricMethod = "IPRBlur";
figure
hold on
for ii = 1:se.NRun
    wff = se.SimRun(ii).readRun("WaveFunction");
    wff = wff ./ sqrt(sum(abs(wff).^2,2));
    t =se.SimRun(1).readRun("Time") * 1e3;
    switch metricMethod
        case "IPR"
            metric{ii} = sum(abs(wff).^4,2);
        case "IPRBlur"
            smoothedData = smoothdata(abs(wff).^2,2, 'gaussian', windowSize);
            smoothedData = smoothedData./sum(smoothedData,2);
            % plot(x,abs(wff).^2,x,smoothedData)
            metric{ii} = sum(abs(smoothedData).^2,2);
        case "Correlation"
            metric{ii} = ((abs(wff).^2) * (abs(wfi).^2));
    end
    disp(ii)
    metric{ii} = metric{ii}./metric{ii}(1);
    l = plot(t,metric{ii});
end
Omega = se.LatticeModulation{1}.WaveformOrigin{1}.Frequency / f0;
alpha = se.LatticeModulation{1}.WaveformOrigin{1}.Amplitude / 2;
box on
xlabel("Time [ms]",'Interpreter','latex')
ylabel("Normalized Blurred IPR",'Interpreter','latex')
title("$V_0 = " + ol.DepthLu + " E_{\mathrm{R}},~\Omega=" + Omega + ",~\alpha = "+alpha + "$",'Interpreter','latex')
legend("$\sigma_p = " + string(sigmaPList) + " \hbar k_{\mathrm{L}}$")
render

