folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.RampTime = 10e-3;
kpp.IsInverted = false;
kpp.IsGuessUsingOldData = false;
kpp.setHardware
kpp.DelayTimeEstimated = [2.8,2.9]*1e-6;
kpp.measureDelay

%%
V0 = 6;
kpp.getKpRampData(V0)
