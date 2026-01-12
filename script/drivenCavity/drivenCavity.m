clear
close all
%% Generate trial type
laser = Laser( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    intensity = 3.852874965460643e7 ...
    );
laser = {laser};

atom = Alkali("Lithium7");
se = LatticeSeSim1D("DrivenCavity", ...
    atom = atom,...
    laser = laser,...
    timeStep=1e-7,...
    totalTime=101e-3,...
    spaceRange = 750e-06,...
    spaceStep = 1e-8);
se.SavePeriod = 1e4;
se.AveragePeriod = 200;
se.Description = "Driven cavity TDSE simulation.";
se.updateTrialType;

%% Static Cavity
laser = Laser( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    intensity = 3.852874965460643e7 ...
    );
laser = {laser};
ol = OpticalLattice(atom,laser{1});
ol.DepthSpec = 12.32 * ol.RecoilEnergy;
ol.updateIntensity;
kL = ol.Laser.AngularWavenumber;
laser = {ol.Laser};

power = (1.26 + 1.44)/2;
rescaledPower = power * 20 / 55;
separation = 680.6762e-6;

wLaser1 = GaussianBeam( ...
    wavelength = 532e-9,...
    direction = [0;0;1],...
    polarization = [0;1;0],...
    power = rescaledPower,...
    waist = [20;20]*1e-6,...
    center = [0;-separation/2;0]...
    );
wLaser2 = GaussianBeam( ...
    wavelength = 532e-9,...
    direction = [0;0;1],...
    polarization = [0;1;0],...
    power = rescaledPower,...
    waist = [20;20]*1e-6,...
    center = [0;separation/2;0]...
    );
wLaser = [wLaser1,wLaser2];
wLaser = {wLaser};

ic = InitialCondition("SeSim1D");
se = LatticeSeSim1D("DrivenCavity", ...
    laser = laser,...
    wallLaser = wLaser,...
    initialCondition = ic);

% initial condition

sigma = 25e-6;
x = se.SimRun(1).SpaceList;
x = x.';
kL = ol.Laser.AngularWavenumber;
qIni = 0.75*kL;
[~,~,phi] = ol.computeBand1D(qIni,2,x);

psi = exp(-(x).^2 / 4 / sigma^2) .* phi;
ic.WaveFunction = psi;
for ii = 1:numel(se.SimRun)
    se.SimRun(ii).InitialCondition.WaveFunction = psi;
end

% se.start

%% Driven cavity
% Modulation parameters
modFrequency = 95.5;
modDepthRel = 0.0278; %peak-to-peak
modDepthAbs = modDepthRel * separation;
holdTime = (1/modFrequency) * 3/4;

% nPhase = 8;
% phase = linspace(0,2 * pi,nPhase);
phase = 0:pi/6:(2*pi-pi/6);
phase = -phase;
nPhase = numel(phase);
wallMod = cell(1,nPhase);

for ii = 1:nPhase
    modWave1 = WaveformList("mod1",waveformOrigin = {ConstantWave},samplingRate=1e6);
    modWave2 = WaveformList("mod2",samplingRate=1e6,waveformOrigin = ...
        {ConstantWave(duration=holdTime),SineWave(frequency=modFrequency,amplitude=modDepthAbs,duration=0.2,phase=phase(ii))});   
    wallMod{ii} = [modWave1,modWave2];
end

se = LatticeSeSim1D("DrivenCavity", ...
    laser = laser,...
    wallLaser = wLaser,...
    initialCondition = ic,...
    wallModulation=wallMod,...
    spaceStep = 10e-9);

% initial condition
sigma = 2e-6;
x = se.SimRun(1).SpaceList;
x = x.';
kL = ol.Laser.AngularWavenumber;
qIni = 0.73607*kL;
[~,~,phi] = ol.computeBand1D(qIni,2,x);

tExp = 20e-3;
hbar = Constants.SI("hbar");
M = atom.mass;
psi = (sqrt(2*pi*sigma^2)*(1+1i*hbar*tExp/2/M/sigma^2))^(-1/2) * ...
    exp(-(x).^2/4/sigma^2/(1+1i*hbar*tExp/2/M/sigma^2)) .* phi;


% psi = exp(-(x).^2 / 4 / sigma^2) .* phi;
ic.WaveFunction = psi;
for ii = 1:numel(se.SimRun)
    se.SimRun(ii).InitialCondition.WaveFunction = psi;
end

se.start
se.showSpaceTime
se.showQuasimomentumTime(2)