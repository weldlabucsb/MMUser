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
V0Guess = 6;
dq = 1e-3;
divisor = 5;
g = 9.81;
M = atom.mass;
F = M * g / divisor;
hbar = Constants.SI("hbar");
h = hbar * 2 * pi;
fileName = "magicStaticDivisor"+ num2str(divisor) + ".mat";

%% Loop size list
nl = 2000;
loopSizeTheory = linspace(0.01,10,nl);
magicDepthTheory = zeros(1,nl);

%% Compute magic depth
parfor ii = 1:nl
    qR = (1 - loopSizeTheory(ii));
    magicDepthTheory(ii) = fminsearch(@(x) aiPhaseStatic(x,qR,dq),V0Guess);
    disp(ii)
end
save(fullfile(findFolderInPath("atomInterferometry"),fileName),"loopSizeTheory","magicDepthTheory")

%% Compute modulation parameters
frequency = zeros(1,nl);
modDepth = zeros(1,nl);
nq = 2000;
qList = linspace(-1,1,nq);
for ii = 1:nl
    ol.DepthSpec = magicDepthTheory(ii) * Er;
    qR = (1 - loopSizeTheory(ii));
    qR = mod(qR+1,2)-1;
    [~,qRIdx] = min(abs(qList-qR));
    ol.computeAll1D(nq,2)
    A = ol.AmpModCoupling;
    Apd = squeeze(A(2,3,:));
    E = ol.BandEnergy * h;
    Ed = E(3,:);
    Ep = E(2,:);
    dq2 = (qList(2) - qList(1)) * kL;
    dEdq = gradient(Ed-Ep,dq2);
    frequency(ii) = ol.computeTransitionFrequency1D(qR*kL,1,2);
    modDepth(ii) = 1 / (magicDepthTheory(ii) * Er * h) / abs(Apd(qRIdx)) .*...
        sqrt(log(4)/pi.*F.*abs(dEdq(qRIdx)));
    disp(ii)
end
save(fullfile(findFolderInPath("atomInterferometry"),fileName),"frequency","modDepth","-append")

%% Compute fringe frequency
fringeFrequency = zeros(1,nl);
parfor ii = 1:nl
    qR = (1 - loopSizeTheory(ii));
    fringeFrequency(ii) = (aiPhaseStatic(magicDepthTheory(ii),qR,dq) * Er - frequency(ii) * loopSizeTheory(ii) * 2)...
        * h / 2 / hbar / 2 / pi;
end
save(fullfile(findFolderInPath("atomInterferometry"),fileName),"fringeFrequency","-append")