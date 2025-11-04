load magicDressed.mat
%% Set up atom parameters
atom = Alkali("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 1, ...
    waist = 110e-6 ...
    );
ol = OpticalLattice(atom,laser);
kL = laser.AngularWavenumber;
Er = ol.RecoilEnergy;
dq = 1e-3;
g = 9.81;
M = atom.mass;
divisor = 5;
F = M * g / divisor;
hbar = Constants.SI("hbar");
h = hbar * 2 * pi;
tPulse = 2.5e-3 * divisor;
tRamp = 0.1e-3 * divisor;
nV = 100;
tol = zeros(1,numel(loopSizeTheory));

%% Compute
parfor ii = 1:numel(loopSizeTheory)
    vList = linspace(magicDepthTheory(ii) - toleranceTheory(100), ...
        magicDepthTheory(ii) + toleranceTheory(100),nV);
    phiList = arrayfun(@(x) aiPhaseDressed(...
        x,1-loopSizeTheory(ii),frequency(ii),modDepth(ii),tPulse,tRamp,F,dq), ...
        vList);
    try
        fd = ParabolicFit1D([vList',phiList']);
        fd.do
        tol(ii) = sqrt(abs(phiList(50))/ abs(fd.Coefficient(1)));
    catch
    end
    disp(ii)
end
fileName = "AOverKappaSquared";
save(fullfile(findFolderInPath("atomInterferometry"),fileName),"loopSizeTheory","tol")