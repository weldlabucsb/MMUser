clear
close all

divisor = 5;
fileName =  "magicDressedDivisor"+ num2str(divisor) + ".mat";
load(fileName)
loopSize = 2.7:2:8.7;
idx = zeros(1,numel(loopSize));

hbar = Constants.SI("hbar");
h = hbar * 2 * pi;
tPulse = 2.5e-3 * divisor;
tRamp = 0.1e-3;


%% Atom
atom = Alkali("Lithium7");

%% Compute force
centralB = 0.012287639710280/divisor;
bField = MagneticField(...
    bias = [0;0;500],...
    gradient = [0,0,0;0,0,0;0,1,0],quadratic=0);
mp = MagneticPotential(atom,bField);
stateIdx = mp.StateIndex;
stateList = atom.(mp.Manifold).StateList;
mJ = stateList.MJ(stateIdx);
gJ = stateList.gJ(stateIdx);
mI = stateList.MI(stateIdx);
gI = stateList.gI(stateIdx);
muB = Constants.SI("muB");
prefactor = abs((mJ * gJ + mI * gI) * muB / h);
F0 = prefactor * h * centralB;
a = 532e-9;
fB0 = F0 * a / h;
TB0 = 1/fB0;

for ii = 1:numel(loopSize)
    %% Parameters
    [~,idx(ii)] = min(abs(loopSizeTheory - loopSize(ii)));
    loopSizeActual = loopSizeTheory(idx(ii));
    tWait = 1e-3;
    tTotal = TB0 * loopSizeActual + tPulse + tWait * 2;
    
    %% B field
    TBRange = 4/fringeFrequency(idx(ii));
    bLim = 1./[TB0 + TBRange/2,TB0 - TBRange/2]./a./prefactor;
    quad = zeros(3,3,3);
    % quad(3,2,2) = -1.415^2 * (2/9)^2;
    bList = num2cell(linspace(bLim(1),bLim(2),100));
    niB = 543.6e-4; %non-interacting feshbach field
    bField = cellfun(@(x) MagneticField(...
        bias = [0;0;niB],...
        gradient = [0,0,0;0,0,0;0,x,0],quadratic=quad),bList,'UniformOutput',false);

    %% Laser
    laser = Laser( ...
        wavelength = 1064e-9,...
        direction = [0;1;0],...
        polarization = [0;0;1],...
        intensity = 3.852874965460643e7 ...
        );
    laser = {laser};

    %% Lattice
    ol = OpticalLattice(atom,laser{1});
    ol.DepthSpec = magicDepthTheory(idx(ii)) * ol.RecoilEnergy;
    ol.updateIntensity;
    kL = ol.Laser.AngularWavenumber;
    laser = {ol.Laser};

    %% Modulation
    ampMod1 = ConstantWave(duration = tWait,offset=0);
    ampMod2 = TrapezoidalPulse(duration=tPulse,amplitude=modDepth(idx(ii)) * 2,riseTime=tRamp,fallTime=tRamp);
    ampMod3 = ConstantWave(duration = (tTotal-tPulse * 2 - tWait * 2),offset=0);
    ampMod = WaveformList("ampmod" ,waveformOrigin = {ampMod1,ampMod2,ampMod3,ampMod2,ampMod1});
    latticeMod = SineWaveModulated(duration=tTotal,frequency=frequency(idx(ii)));
    latticeMod.AmplitudeModulation = ampMod;
    latticeModList = WaveformList("latticeMod",waveformOrigin = {latticeMod});
    latticeModList = {latticeModList};

    %% Initial Condition
    ic = InitialCondition("LatticeFourierSeSim1D");
    ic.QuasiMomentum = (1 - loopSizeActual - (tPulse/2 + tWait)/TB0*2) * kL;
    [~,ic.WaveFunction] = ol.computeBand1D(ic.QuasiMomentum,1,[],nMax = 25);

    %% Simulation
    se = LatticeFourierSeSim1D("Test", ...
        laser = laser,...
        magneticField = bField,...
        latticeModulation = latticeModList,...
        timeStep=1e-7,...
        totalTime=tTotal,...
        initialCondition = ic);
    se.start

    %% Plot
    data = se.readBand(2);
    mp = MagneticPotential(atom,bField{1});
    stateIdx = mp.StateIndex;
    stateList = atom.(mp.Manifold).StateList;
    mJ = stateList.MJ(stateIdx);
    gJ = stateList.gJ(stateIdx);
    mI = stateList.MI(stateIdx);
    gI = stateList.gI(stateIdx);
    muB = Constants.SI("muB");
    h = Constants.SI("hbar") * 2 * pi;
    hbar = Constants.SI("hbar");
    prefactor = (mJ * gJ + mI * gI) * muB / h;
    FList0 = abs(h * prefactor * cell2mat(bList));
    g = 9.81;
    M = atom.mass;
    a = se.Laser{1}.Wavelength/2;
    h = Constants.SI('hbar')*2*pi;
    fB = FList0*a/h;
    figure(11240)
    plot(1e3./fB,data)
    xlabel("$T_{\mathrm{B}}$ (ms)")
    ylabel("$D$ Band Fraction")
    axis([min(1e3./fB),max(1e3./fB),0,1])
    render
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"png")
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"fig")
    close all
end