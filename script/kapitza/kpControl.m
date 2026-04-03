function wfl = kpControl(chIdx,V0,f,alpha,beta,nCycle,rampTime)
dataName = "KppData_2026_04_02_18_27_59.mat";
userPath = fullfile(getHome,"Documents","MMUser");
dataPath = fullfile(userPath,"script","lattice",dataName);
kpp = loadVar(dataPath,"kpp");
wfl = kpp.predictKpRamp(chIdx,V0,f,alpha,beta,nCycle,rampTime);
end

