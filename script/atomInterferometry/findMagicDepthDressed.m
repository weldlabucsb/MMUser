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
dq = 1e-4;
g = 9.81;
M = atom.mass;
F = M * g;
hbar = Constants.SI("hbar");
h = hbar * 2 * pi;
tPulse = 2.5e-3;
tRamp = 0.1e-3;

%% Loop size list
nl = 2000;
loopSizeTheory = linspace(0.01,10,nl);
magicDepthTheory = zeros(1,nl);
load magicStatic.mat

%% Compute magic depth
parfor ii = 1:nl
    qR = (1 - loopSizeTheory(ii));
    magicDepthTheory(ii) = fminsearch(@(x) aiPhaseDressed(...
        x,1-loopSizeTheory(ii),frequency(ii),modDepth(ii),tPulse,tRamp,F,dq),magicDepthTheory(ii));
    disp(ii)
end

for ii = 1:nl
    [~,loopSizeTheory(ii)] = aiPhaseDressed(...
        magicDepthTheory(ii),1-loopSizeTheory(ii),frequency(ii),modDepth(ii),tPulse,tRamp,F,dq);
end
save(fullfile(findFolderInPath("atomInterferometry"),"magicDressed.mat"),"loopSizeTheory","magicDepthTheory")

%% Compute modulation parameters
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
    modDepth(ii) = 1 / (magicDepthTheory(ii) * Er * h) / abs(Apd(qRIdx)) .*...
        sqrt(log(4)/pi.*F.*abs(dEdq(qRIdx)));
    disp(ii)
end
save(fullfile(findFolderInPath("atomInterferometry"),"magicDressed.mat"),"frequency","modDepth","-append")

%% Compute fringe frequency
fringeFrequency = zeros(1,nl);
parfor ii = 1:nl
    fringeFrequency(ii) =   aiPhaseDressed(...
        magicDepthTheory(ii),1-loopSizeTheory(ii),frequency(ii),modDepth(ii),tPulse,tRamp,F,dq)...
        * h / 2 / hbar / 2 / pi / 2 / pi;
    disp(ii)
end
save(fullfile(findFolderInPath("atomInterferometry"),"magicDressed.mat"),"fringeFrequency","-append")

%% Compute tolerance
toleranceTheory = zeros(1,nl);
toleranceTheoryRelative = toleranceTheory;
phaseTol = pi/4;
fval = zeros(1,nl);
flag = zeros(1,nl);
parfor ii = 1:100
    qR = (1 - loopSizeTheory(ii));
    phi0 = fringeFrequency(ii) * 4 * pi * hbar / F * kL;
    [tolBound,fval(ii),flag(ii)] = fzero(@(x) hbar / F * kL * aiPhaseDressed(...
        x,1-loopSizeTheory(ii),frequency(ii),modDepth(ii),tPulse,tRamp,F,dq) - phaseTol - phi0,magicDepthTheory(ii));
    toleranceTheory(ii) = abs(max(tolBound) - magicDepthTheory(ii));
    toleranceTheoryRelative(ii) = toleranceTheory(ii)/magicDepthTheory(ii);
    disp(ii)
end
save(fullfile(findFolderInPath("atomInterferometry"),"magicDressed.mat"),"toleranceTheory","toleranceTheoryRelative","-append")
