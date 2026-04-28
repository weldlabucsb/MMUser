%% KD data
trialNumberKP1Kd = 9114;
trialNumberKP2Kd = 9115;

becExp = loadBecExp(trialNumberKP1Kd);
k1 = becExp.KapitzaDirac.DepthOverAmplitude;
off1 = mean(becExp.KapitzaDirac.PulseOffset);

becExp = loadBecExp(trialNumberKP2Kd);
k2 = becExp.KapitzaDirac.DepthOverAmplitude;
off2 = mean(becExp.KapitzaDirac.PulseOffset);

%% Load data and pre-compute
becExp = loadBecExp(9118);
atom = getAtom("Lithium7");
ol = OpticalLattice(atom,GaussianBeam(wavelength=1064e-9,waist=60e-6));
omf = 4;
for ii = 1:2
    pulseDuration{ii} = becExp.ScopeData.("LatticeScope_ch" + ii + "_TrapezoidalDuration");
    pulseAmplitude{ii} = becExp.ScopeData.("LatticeScope_ch" + ii + "_TrapezoidalAmplitude");
    pulseOffset{ii} = becExp.ScopeData.("LatticeScope_ch" + ii + "_TrapezoidalOffset");
end
temp = becExp.AtomNumber.Raw;
leftWing = temp(:,:,1:omf);
rightWing = temp(:,:,(omf+2):end);
rawFraction = zeros([size(temp,[1,2]),omf+1]);
rawFraction(:,:,1) = temp(:,:,omf+1);
rawFraction(:,:,2:end) = (flip(leftWing,3) + rightWing)/2;
rawFraction = rawFraction ./ (sum(rawFraction(:,:,2:end),3) * 2 + rawFraction(:,:,1));
rawFraction = squeeze(rawFraction).';
% kp1AmpV = becExp.HardwareData.hw_KP1AmpV;
% kp2AmpV = becExp.HardwareData.hw_KP2AmpV;
% [kp1AmpV,kp2AmpV,rawFraction] = computeAveErr2D(kp1AmpV,kp2AmpV,rawFraction,"None");

Er = ol.RecoilEnergy;
depthList = (0:0.01:240) * Er;
tdseOM = 20;
kdDataPrecompute = computeKd(...
    ol,...
    depthList,...
    mean([pulseDuration{1}(:);pulseDuration{2}(:)]),...
    tdseOM,...
    false,...
    33e-6);

% Renormalize
orderIdx = tdseOM + 1 - omf : tdseOM + 1 + omf;
kdDataPrecompute(:,orderIdx) = kdDataPrecompute(:,orderIdx) ./ sum(kdDataPrecompute(:,orderIdx),2);

% Interpolate
KdInterp = cell(1,omf + 1);
for nn = 1:(omf+1)
    nthOrder = kdDataPrecompute(:,tdseOM + nn);
    KdInterp{nn} = @(q) interp1(depthList / Er, nthOrder, q, 'pchip', 'extrap');
end

%% Analysis
depthFit = zeros(1,size(rawFraction,2));
for ii = 1:size(rawFraction,2)
    errFun = @(V0) sum(arrayfun(@(jj) sum(abs(KdInterp{jj}(V0) - rawFraction(jj,ii)).^2),1:omf+1));
    V1Guess = k1 * pulseAmplitude{1}(ii);
    V2Guess = k2 * pulseAmplitude{2}(ii);
    VGuess = abs(V1Guess - V2Guess);
    depthFit(ii) = fminsearch(errFun,VGuess);
end

%% Group data
kp1AmpV = becExp.HardwareData.hw_KP1AmpV;
kp2AmpV = becExp.HardwareData.hw_KP2AmpV;
[kp1AmpV,kp2AmpV,depthFit2D] = computeAveErr2D(kp1AmpV,kp2AmpV,depthFit,"None");
