clear
close all
tTotal = [14.5,16.4] * 1e-3;
for tt = 1:numel(tTotal)
    %% Atom
    atom = Alkali("Lithium7");

    %% B field
    quad = zeros(3,3,3);
    % quad(3,2,2) = -1.415^2 * (2/9)^2;
    bList = num2cell(linspace(1.25e-2,1.26e-2,100));
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
    ol.DepthSpec = 7.735 * ol.RecoilEnergy;
    ol.updateIntensity;
    kL = ol.Laser.AngularWavenumber;
    laser = {ol.Laser};

    %% Modulation
    load WaveformLibrary.mat
    latticeMod = WaveformLibrary(18);
    latticeMod.WaveformOrigin{1}.Amplitude = 0.24;
    latticeMod.WaveformOrigin{1}.Frequency = 110e3;
    latticeMod.WaveformOrigin{1}.Duration = 5.3e-3;
    latticeMod.WaveformOrigin{2}.Frequency = 95.563e3;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{1}.Duration = 0.001e-3;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{2}.Duration = 3.106e-3;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{3}.Duration = 2 * 2.194e-3;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{4}.Duration = 3.106e-3;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{4}.Amplitude = 0.023 * 4;
    latticeMod.WaveformOrigin{2}.AmplitudeModulation.WaveformOrigin{2}.Amplitude = 0.023 * 4;
    latticeMod.WaveformOrigin{2}.StartTime = 0;
    latticeMod = {latticeMod};

    %% Initial Condition
    ic = InitialCondition("LatticeFourierSeSim1D");
    ic.QuasiMomentum = - kL;
    [~,ic.WaveFunction] = ol.computeBand1D(ic.QuasiMomentum,0);

    %% Simulation
    se = LatticeFourierSeSim1D("Test", ...
        laser = laser,...
        magneticField = bField,...
        latticeModulation = latticeMod,...
        timeStep=1e-7,...
        totalTime=tTotal(tt),...
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
    title(['$t=',num2str(tTotal(tt) * 1e3),'\,\mathrm{ms}$, Trial ',num2str(se.SerialNumber)],'Interpreter','latex')
    render
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"png")
    saveas(gcf,fullfile(se.DataAnalysisPath,"AI_Force_Scan"),"fig")
    close all
end