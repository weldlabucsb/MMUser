%% Compute lattice depth
atom = Alkali("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 1, ...
    waist = 127e-6 ...
    );
ol = OpticalLattice(atom,laser);
kL = laser.AngularWavenumber;
lambda = laser.Wavelength;
a = lambda / 2;
Er = ol.RecoilEnergy;
ol.DepthKd = 8.8458 * Er;
ol.updateIntensity;

depthList = linspace(11.8,12.5,1000) * Er;
sdFreqList = zeros(1,numel(depthList));
for ii = 1:numel(depthList)
    ol.DepthKd = depthList(ii);
    sdFreqList(ii)= ol.computeTransitionFrequency1D(0,0,2);
end

fitData = LinearFit1D([sdFreqList.',depthList.']);
fitData.do;
k = fitData.Coefficient(1);

trialNumber = 7168;
becExp = loadBecExp(trialNumber);
atomNumber = (becExp.AtomNumber.Raw(:,:,1) + becExp.AtomNumber.Raw(:,:,3))./sum(becExp.AtomNumber.Raw,3);
freq = becExp.HardwareData.hw_SdCalibFreqStart + 500;
[freq,atomNumber] = computeAveErr(freq,atomNumber);
idx = freq>2.19e5 & + freq < 2.32e5;
freq = freq(idx);
atomNumber = atomNumber(idx);
fd = GaussianFit1D([freq(:),atomNumber(:)]);
fd.do;
resFreq = fd.Coefficient(2);
V0 = interp1(sdFreqList,depthList,resFreq)/Er;
rawError = confint(fd.Result);
rawError = (rawError(2,2) - rawError(1,2))/2/1.96;
fitError = rawError * k /Er;
disp([V0,fitError])

