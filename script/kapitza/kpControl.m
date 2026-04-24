function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime,isInverted)
if nargin == 7
    isInverted = true;
end
folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
% dataName = "KppData_2026_04_20_16_40_41.mat";
% dataPath = fullfile(folderPath,dataName);
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.IsInverted = isInverted;
wfl = kpp.predictKp(chIdx,V0,f,alpha,beta,nCycle,rampTime);
end

