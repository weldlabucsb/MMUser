%% Pd to Keysight
trialNumberPd2Keysight = 8574; % 100% moglabs mod depth
% trialNumberPd2Keysight = 8579; % 150% moglabs mod depth
% trialNumberPd2Keysight = 8616; % 200% moglabs mod depth
sName = "LatticeScope";
becExp = loadBecExp(trialNumberPd2Keysight);
s = loadVar(fullfile(becExp.HardwareLogPath,becExp.DataPrefix + "_" + num2str(1)) + "_" + sName + ".mat");
rampTime = becExp.HardwareData.hw_KPRamp1Time;
scopeDuration = s.Duration;
nSample = s.NSample;
idx = s.TimeList >= (scopeDuration/2) & s.TimeList <= (scopeDuration/2 + rampTime);
V = linspace(-1,1,numel(find(idx))); % 100% moglabs mod depth
% V = linspace(-0.65,1,numel(find(idx))); % 150% moglabs mod depth
% V = linspace(-1,0.8,numel(find(idx))); % 200% moglabs mod depth
KP1Pd = s.Sample(1,idx);
KP2Pd = s.Sample(2,idx);
KP1Pd2Keysight = slmengine(KP1Pd,V, 'plot', 'on', 'increasing', 'on');
KP2Pd2Keysight = slmengine(KP2Pd,V, 'plot', 'on', 'increasing', 'on');


%% Depth to Pd
trialNumberKP1Kd = 8573;
trialNumberKP2Kd = 8572;

becExp = loadBecExp(trialNumberKP1Kd);
k = becExp.KapitzaDirac.DepthOverAmplitude;
off = mean(becExp.KapitzaDirac.PulseOffset);
KP1Depth2Pd = @(x) x./k + off;

becExp = loadBecExp(trialNumberKP2Kd);
k = becExp.KapitzaDirac.DepthOverAmplitude;
off = mean(becExp.KapitzaDirac.PulseOffset);
KP2Depth2Pd = @(x) x./k + off;

%% Save
save("C:\Users\WOODHOUSE\Documents\MMUser\script\lattice\LatticeCalib.mat",...
    "KP1Pd2Keysight","KP2Pd2Keysight","KP1Depth2Pd","KP2Depth2Pd")





