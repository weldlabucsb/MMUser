folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.RampTime = 10e-3;
kpp.IsInverted = true;
kpp.IsGuessUsingOldData = true; %somewhat out of date, code now determines if old data available
kpp.setHardware
kpp.setHardware
kpp.InitialDepth = 20;
pause(0.5);
kpp.DelayTimeEstimated = [2.8,2.9]*1e-6;
kpp.measureDelay
kpp.IsOverride=true;  % 1= using alpha & freq override list   0 = using phase diagram params
kpp.AlphaListOverride=[36];
kpp.FrequencyListOverride=linspace(0.9e6, 2.4e6, 25);
% kpp.FrequencyListOverride=linspace(100e3, 2.4e6, 10);


%%
V0 = 10;

% kpp.InitialDepth=20;
% kpp.RampTime = 5e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);



for Vi = 6:2:30
    kpp.RampTime = 10e-3;
    kpp.InitialDepth = Vi;
    kpp.getKpRampData(V0)
    % kpp.getKpModData(V0)
end

kpp.InitialDepth = 20;
kpp.RampTime = 10e-3;
kpp.getKpRampData(V0);
kpp.getKpModData(V0);

% kpp.SamplingRateRamp = 10e6;
% kpp.InitialDepth = 20;
% kpp.RampTime = 50e-3; make sure scope range is long enough
% kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);

% kpp.kpTest(V0)
% kpp.SamplingRateRamp = 50e6;
% kpp.InitialDepth = 20;
% kpp.RampTime = 10e-3;
% kpp.getKpRampData(V0)

%% Normal Scan
kpp.SamplingRateRamp = 50e6;
kpp.IsOverride=false;
kpp.InitialDepth = 20;
kpp.RampTime = 10e-3;
% kpp.getKpRampData(V0);
kpp.getKpModData(V0);
