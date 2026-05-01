folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.RampTime = 10e-3;
kpp.IsInverted = true;
kpp.IsGuessUsingOldData = true;
kpp.setHardware
kpp.setHardware
pause(0.5);
kpp.DelayTimeEstimated = [2.8,2.9]*1e-6;
kpp.measureDelay

%%
V0 = 10;
kpp.getKpRampData(V0)
kpp.getKpModData(V0)
kpp.IsGuessUsingOldData = true;

