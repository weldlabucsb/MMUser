folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
% kpp.UpdateKpRampDataset; % (NEW) Used to modify kprampdataset parameters
% to match new ramp settings. Only run once when trying to adjust it.
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
kpp.AlphaListOverride=linspace(8, 60, 25);
% kpp.FrequencyListOverride=[100e3, 2.4e6, 10];
kpp.FrequencyListOverride=[2.4e6, 1.2e6];
% kpp.FrequencyListOverride=linspace(100e3, 2.4e6, 10); %usual fmod list
kpp.IsUseCorrection = 1;

%%
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);


% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=1e-3;
% kpp.IsOverride=false;
% kpp.getKpRampData(V0, 1e4);
% % kpp.getKpModData(V0);

% V0 = 10;
% kpp.RampTime=400e-6;
% kpp.IsOverride=true;
% kpp.getKpRampData(V0, 2.5e5);


% V0 = 10;
% kpp.RampTime=100e-6;
% kpp.IsOverride=false;
% kpp.getKpRampData(V0, 2.5e5, 1, 15);
% 
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);


kpp.TrainTanhRamp(0, 10, 10e-3);

%%
% kpp.TrainModWaveform(10, 300e3, 0.5);
% kpp.TrainModWaveform(90, 300e3, 40); 
kpp.TrainModWaveform(150, 500e3, 1); %Currently the find 





