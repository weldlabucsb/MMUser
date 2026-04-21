function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime)
dataName = "KppData_2026_04_20_16_40_41.mat";
% folderPath = fullfile(getHome,"Documents","MMUser","script","lattice");
folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = fullfile(folderPath,dataName);
kpp = loadVar(dataPath,"kpp");
wfl = kpp.predictKp(chIdx,V0,f,alpha,beta,nCycle,rampTime);
end

