%% Load Trial and get parameters
trialNumber = 9029:9031;
nTrial = numel(trialNumber);
becExp = loadBecExp(trialNumber(1));
beta = becExp.HardwareData.hw_KPModDepthBeta(1);
V0 = becExp.HardwareData.hw_KPDepthEr(1);
atom = getAtom("Lithium7");
laser = Laser(wavelength = 1064e-9,power = 1);
ol = OpticalLattice(atom,laser);
ol.DepthSpec = V0 * ol.RecoilEnergy;
f0 = ol.HarmonicFrequency;
isNormalize = true;
yCut = 200;
xCut = 5;

%% Analyze trials
ipr = cell(1,nTrial);
t = cell(1,nTrial);
for ii = 1:nTrial
    becExp = loadBecExp(trialNumber(ii));
    load(fullfile(becExp.DataAnalysisPath,"AdData.mat"));
    [t{ii},adData] = computeAveErr(...
    becExp.ScannedVariableList(1,:), ...
    adData,"StdDev");
    ipr{ii} = computeIPR(adData(yCut+1:end-yCut,xCut+1:end-xCut,:));
    if isNormalize
        ipr{ii} = ipr{ii}./ipr{ii}(1);
    end
end

%% Plot
close(figure(234))
figure(234)
hold on
for ii = 1:nTrial
    plot(t{ii} * 1e3,ipr{ii})
end
xlabel("Time [ms]")
if isNormalize
    ylabel("Normalized IPR")
else
    ylabel("IPR")
end
legend("Chaotic","Stable","Weak Drive")
render



