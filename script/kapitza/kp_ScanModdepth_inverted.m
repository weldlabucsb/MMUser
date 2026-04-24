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
ol.DepthSpec = 6 * ol.RecoilEnergy;
ol.updateIntensity;
kL = ol.Laser.AngularWavenumber;
laser = {ol.Laser};
f0 = ol.HarmonicFrequency;

%% compute inverted initial state initial condition 
temp = ol.DepthSpec;
ol.DepthSpec = -temp;
ic = InitialCondition("LatticeFourierSeSim1D");
ic.QuasiMomentum = 0;
[~,ic.WaveFunction] = ol.computeBand1D(ic.QuasiMomentum,0);
ol.DepthSpec = temp;

%% set modulation
modTimeAll = 100e-6;
nModCycle = 900;
nGrid = 20;
modFreqList = linspace(2,15,nGrid) * f0;
modAmpList = linspace(2,30,nGrid);

[modAmpList,modFreqList] = meshgrid(modAmpList,modFreqList);
% modTime = nModCycle * 1./modFreqList;
modTime = round(modTimeAll.*modFreqList)./modFreqList;
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
% s = ConstantWave(offset=-2,duration = modTime(ii));
latticeMod{ii} = WaveformList("LatticeMod");
latticeMod{ii}.WaveformOrigin = {s};
latticeMod{ii}.SamplingRate = 20e6;
end

%% Simulation
se = LatticeFourierSeSim1D("Test", ...
    atom = atom,...
    laser = laser,...
    latticeModulation = latticeMod,...
    timeStep=1e-9,...
    totalTime=modTime(1),...
    initialCondition = ic);
se.SavePeriod = 1e4;
se.AveragePeriod = 200;
for ii = 1:nMod
    se.SimRun(ii).TotalTime = modTime(ii);
end
se.start

%% Data analysis
se = loadSim(73,"LatticeFourierSeSim1D","Test");
overlap = zeros(1,se.NRun);
wfi = se.InitialCondition.WaveFunction;
wfi = wfi./sqrt(sum(abs(wfi).^2));
for ii = 1:se.NRun
    wff = se.SimRun(ii).readRun("FinalWaveFunction");
    wff = wff ./ sqrt(sum(abs(wff).^2));
    overlap(ii) = (abs(wff * wfi))^2;
end
overlap = reshape(overlap,nGrid,nGrid);
figure(2354)
ax = gca;
img = imagesc(ax,overlap);

modFreqList = linspace(2,26,nGrid);
modAmpList = linspace(2,30,nGrid);
img.XData = modAmpList;
img.YData = modFreqList;
ax.XLim = [min(modAmpList)-0.5,max(modAmpList)+0.5];
ax.YLim = [min(modFreqList)-0.5,max(modFreqList)+0.5];
xlabel("\alpha")
ylabel("\Omega")
title("V_0 = " + ol.DepthLu + " E_R")
cb = colorbar;
cb.Label.String = "Overlap between initial and final states";

%% Data analysis, time-averaged
se = loadSim(75,"LatticeFourierSeSim1D","Test");
overlap = zeros(1,se.NRun);
wfi = se.InitialCondition.WaveFunction;
wfi = wfi./sqrt(sum(abs(wfi).^2));
sr = 1 / se.TimeStep / se.AveragePeriod;
u0 = fft(se.InitialCondition.WaveFunction,101);
u0 = u0 ./ sqrt(sum(abs(u0).^2));
for ii = 1:se.NRun
    wff = se.SimRun(ii).readRun("WaveFunction");
    wff = wff ./ sqrt(sum(abs(wff).^2,2));
    % ct = (abs(wff).^2) * (abs(wfi).^2);
    % ct = (abs(wff * wfi)).^2;
    modFreq = se.LatticeModulation{ii}.WaveformOrigin{1}.Frequency;
    % tList = 0:se.TimeStep * se.AveragePeriod:nModCycle/modFreq;
    % ml = min(numel(ct),numel(tList));
    % tList = tList(1:ml);
    % ct = ct(1:ml);
    % ctinterp = @(x) interp1(tList.',ct,x,"pchip",'extrap');
    % tSample = (nModCycle-100)/modFreq:1/modFreq:(nModCycle-1)/modFreq;
    % overlap(ii) = mean(ctinterp(tSample));
    
    % N = length(ct);
    % f = (0:N-1) * (sr / N); % Frequency vector
    % Xf = fft(ct);
    % Xf_shifted = Xf .* exp(1i * 2 * pi * f.' * 1/modFreq);
    % x_shifted = real(ifft(Xf_shifted));
    % sampledRange = (N - round(N * 0.2)) : N;
    % overlap(ii) = mean(ct(sampledRange) .* x_shifted(sampledRange));

    u = fft(wff,101,2);
    u = u ./ sqrt(sum(abs(u).^2,2));
    % u = sum(abs(u).^4,2);
    u = ((abs(u).^2) * (abs(u0).^2));
    nModCycle = round(se.SimRun(ii).TotalTime * modFreq);
    tList = 0:se.TimeStep * se.AveragePeriod:nModCycle/modFreq;
    ml = min(numel(u),numel(tList));
    tList = tList(1:ml);
    u = u(1:ml);
    u = u./u(1);
    ctinterp = @(x) interp1(tList.',u,x,"pchip",'extrap');
    tSample = (nModCycle-20)/modFreq:1/modFreq:(nModCycle-1)/modFreq;
    % overlap(ii) = mean(ctinterp(tSample));
    overlap(ii) = mean(ctinterp(tSample));
    disp(ii)
end
overlap = reshape(overlap,nGrid,nGrid);
figure(2354)
ax = gca;
img = imagesc(ax,overlap);

modFreqList = linspace(2,26,nGrid);
modAmpList = linspace(2,30,nGrid);
img.XData = modAmpList;
img.YData = modFreqList;
ax.XLim = [min(modAmpList)-0.5,max(modAmpList)+0.5];
ax.YLim = [min(modFreqList)-0.5,max(modFreqList)+0.5];
xlabel("\alpha")
ylabel("\Omega")
title("V_0 = " + ol.DepthLu + " E_R")
cb = colorbar;
cb.Label.String = "IPR";

figure(2435)
[~,idx] = min(abs(modFreqList-7.55));
plot(modAmpList,overlap(idx,:))
xlabel("\alpha")
ylabel("IPR")

%% plot time evolution
modFreqList = linspace(2,26,nGrid) * f0;
modAmpList = linspace(2,30,nGrid);

[modAmpList,modFreqList] = meshgrid(modAmpList,modFreqList);

row = 11;
idx = sub2ind([nGrid,nGrid],ones(1,nGrid) * row,1:nGrid);

% figure
gl = uigridlayout([4,5]);
for ii = idx
    ax = nexttile;
wff = se.SimRun(ii).readRun("WaveFunction");
wff = wff ./ sqrt(sum(abs(wff).^2,2));
ct = (abs(wff * wfi)).^2;
% ct = (abs(wff).^2) * (abs(wfi).^2);
plot(ax,ct)
end