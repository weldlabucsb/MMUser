function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime,isInverted,initialDepth,isBm, bmTime)
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
    bmTime double = 1e-6
end
folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
% dataName = "KppData_2026_04_20_16_40_41.mat";
% dataPath = fullfile(folderPath,dataName);
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.IsInverted = isInverted;
kpp.InitialDepth = initialDepth;
kpp.IsRampUpModulation = false;
wfl = kpp.predictKp(chIdx,V0,f,alpha,beta,nCycle,rampTime,isBm, 1, bmTime);
end

