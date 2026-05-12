function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime,isInverted,initialDepth,isBm)
arguments
    chIdx
    V0
    f
    alpha
    beta
    nCycle
    rampTime
    isInverted = true
    initialDepth = V0
    isBm = false
end
folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
% dataName = "KppData_2026_04_20_16_40_41.mat";
% dataPath = fullfile(folderPath,dataName);
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.IsInverted = isInverted;
kpp.InitialDepth = initialDepth;
kpp.IsRampUpModulation = true;
wfl = kpp.predictKp(chIdx,V0,f,alpha,beta,nCycle,rampTime,isBm);
end

