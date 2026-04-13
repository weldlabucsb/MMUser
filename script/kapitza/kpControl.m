function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime)
dataName = "KppData_2026_04_12_21_57_32.mat";
% folderPath = fullfile(getHome,"Documents","MMUser","script","lattice");
folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = fullfile(folderPath,dataName);
kpp = loadVar(dataPath,"kpp");
wfl = kpp.predictKpRamp(chIdx,V0,f,alpha,beta,nCycle,rampTime);
end

