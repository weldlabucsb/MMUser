trialNumber = 8343;
sName = "LatticeScope";
becExp = loadBecExp(trialNumber);
s = loadVar(fullfile(becExp.HardwareLogPath,becExp.DataPrefix + "_" + num2str(1)) + "_" + sName + ".mat");
rampTime = becExp.HardwareData.hw_KPRampTime;
scopeDuration = s.Duration;
nSample = s.NSample;
idx = s.TimeList >= (scopeDuration/2) & s.TimeList <= (scopeDuration/2 + rampTime);
V = linspace(-1,1,numel(find(idx)));
KP1Pd = s.Sample(1,idx);
KP2Pd = s.Sample(2,idx);
KP1 = slmengine(KP1Pd,V, 'plot', 'on', 'increasing', 'on');
KP2 = slmengine(KP2Pd,V, 'plot', 'on', 'increasing', 'on');

save("C:\Users\WOODHOUSE\Documents\MMUser\script\lattice\ScopeLatticeCalib.mat","KP1","KP2")

