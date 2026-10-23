folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
% kpp.UpdateKpRampDataset; % (NEW) Used to modify kprampdataset parameters
% to match new ramp settings. Only run once when trying to adjust it.

% kpp.ClearKpDataset; %Run if suspecting that incorrect waveforms are being
% %retrieved. Should Use IsGuessUsingOldData=false
kpp.RampTime = 10e-3;
kpp.IsInverted = true;
kpp.InitialDepth = 20;
V0=30;

kpp.IsGuessUsingOldData = false; %somewhat out of date, code now determines if old data available
kpp.setHardware
kpp.setHardware

pause(0.5);
kpp.DelayTimeEstimated = [2.8,2.9]*1e-6;
kpp.measureDelay

kpp.IsUseCorrection=1;
kpp.CorrFactor =  [0.954633, 0.984628];

kpp.IsUseGenDatabase=0;
kpp.AlphaMaximum=60; % this corresponds to the hw_alpha variable, which is beta dependent. 

kpp.IsOverride= true;  % 1= using alpha & freq override list   0 = using phase diagram params

% various overrides

%kpp.AlphaListOverride=30;
% kpp.FrequencyListOverride=[16e3, 480e3, 10];
% kpp.FrequencyListOverride=linspace(16e3, 480e3, 10);
kpp.FrequencyListOverride= [550e3, 1.4e6, 2.4e6]; %usual fmod list
% kpp.AlphaListOverride=linspace(0.5, 8, 10); %pts for fine alpha scan
kpp.AlphaListOverride=10;
% kpp.AlphaListOverride=linspace(8,60,100);
% kpp.FrequencyListOverride=2.1e6;
% kpp.AlphaListOverride=30;
kpp.getKpRampData(V0);
kpp.setHardware
kpp.setHardware
kpp.IsGuessUsingOldData = false;
kpp.getKpModData(V0);

% kpp.IsInverted = false;
% kpp.getKpRampData(V0);
% kpp.setHardware
% kpp.setHardware
% kpp.getKpModData(V0);


%% timemod scans
% kpp.IsOverride=true;
% kpp.IsInverted=true;
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% kpp.AlphaListOverride = [60, 48.4444444444444, 8, 60];
% kpp.FrequencyListOverride=[355555.555555556, 1377777.77777778, 2400000, 2400000];
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);
% 
% kpp.IsInverted=false;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);

%% testing Vi dependence 
% 
% Ramp data for various lattice depths
% for Vi = 6:3:30
%     kpp.RampTime = 10e-3;
%     kpp.IsOverride=true;
%     kpp.IsInverted=true;
%     V0 = 10;
%     kpp.AlphaListOverride = [48.4444444444444];
%     kpp.FrequencyListOverride=[1377777.77777778];
% 
%     kpp.InitialDepth = Vi;
%     kpp.getKpRampData(V0);
%     kpp.getKpModData(V0);
% end
% %reset for later
% kpp.InitialDepth = 20;
% kpp.IsOverride=false;

% % Standard KPPhaseDiagram
% 
% kpp.IsOverride = true;
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);

% % Training for Constant Alpha/Omega Scan

% kpp.IsOverride = true;
% V0=10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% AlphaSet=linspace(8, 60, 100);
% AlphaSet=AlphaSet(end-3:end);
% FreqSet=AlphaSet*2.147e6/60; %Keeps Frequency Proportional,  60*beta->30  2.4MHz-> 15  alpha/omega =2
% 
% for ii=1:length(AlphaSet)
% kpp.AlphaListOverride=AlphaSet(ii);
% kpp.FrequencyListOverride=FreqSet(ii);
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);
% end

%% Train Ramp for Bandmapping

% kpp.RampTime=400e-6;
% kpp.getKpRampData(V0, 1e5);
% 
% kpp.RampTime=10e-3; % setting ramp time back to 10ms
% kpp.UpdateKpRampDataset
%% Retrain Bad Runs and save all final settings
% V0=10;
% kpp.IsOverride=true;  % 1= using alpha & freq override list   0 = using phase diagram params
% kpp.AlphaListOverride=20;
% % kpp.FrequencyListOverride=[100e3, 2.4e6, 10];
% kpp.FrequencyListOverride=2.4e6;
% kpp.getKpModData(V0);

%% Try with overridden known waveforms

% kpp.IsOverride = true;
% kpp.AlphaListOverride=linspace(8, 60, 10);
% kpp.FrequencyListOverride=linspace(100e3, 2.4e6, 10); %usual fmod list
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% % kpp.getKpRampData(V0);
% kpp.getKpModData(V0);


% %%
% % V0 = 10;
% % kpp.InitialDepth = 20;
% % kpp.RampTime=10e-3;
% % kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);
% 
% 
% % V0 = 10;
% % kpp.InitialDepth = 20;
% % kpp.RampTime=1e-3;
% % kpp.IsOverride=false;
% % kpp.getKpRampData(V0, 1e4);
% % % kpp.getKpModData(V0);
% 
% V0 = 10;
% kpp.RampTime=400e-6;
% kpp.IsOverride=true;
% kpp.getKpRampData(V0, 2.5e5);
% 
% 
% % V0 = 10;
% % kpp.RampTime=100e-6;
% % kpp.IsOverride=false;
% % kpp.getKpRampData(V0, 2.5e5, 1, 15);
% % 
% V0 = 10;
% kpp.InitialDepth = 20;
% kpp.RampTime=10e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);
% 
% 
% 
% %% Try with shortest RampTraining for bandmapping
% % kpp.RampTime=100e-6;
% % % kpp.IsOverride=false;
% % kpp.getKpRampData(V0, 2.5e5);
% % kpp.RampTime=400e-6;
% % % kpp.IsOverride=false;
% % kpp.getKpRampData(V0, 1e5);
% 
% %% Do Normal KpRampTimeTraining
% 
% % kpp.InitialDepth=20;
% % kpp.RampTime = 5e-3;
% % kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);
% 
% 
% % Ramp data for various lattice depths
% % for Vi = 6:2:30
% %     kpp.RampTime = 10e-3;
% %     kpp.InitialDepth = Vi;
% %     kpp.getKpRampData(V0)
% % end
% 
% % mod data for first override above, reseting Vi to 20
% % kpp.InitialDepth = 20;
% % kpp.RampTime = 10e-3;
% % kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);
% % 
% % 
% % kpp.IsInverted=true;
% % kpp.AlphaListOverride=linspace(8, 60, 10);
% % kpp.FrequencyListOverride=0.88e6;
% % kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);
% 
% % %% second fixed alpha cut, weak drive
% % kpp.InitialDepth = 20;
% % kpp.RampTime = 10e-3;
% % kpp.AlphaListOverride=[8];
% % kpp.FrequencyListOverride=linspace(0.9e6, 2.4e6, 15);
% % kpp.getKpModData(V0);
% % 
% % 
% % %% fixed omega cut
% % 
% % kpp.FrequencyListOverride=[1.3778e6];
% % kpp.AlphaListOverride=linspace(8, 60, 15);
% % kpp.getKpModData(V0);
% % 
% % % kpp.SamplingRateRamp = 10e6;
% % % kpp.InitialDepth = 20;
% % % kpp.RampTime = 50e-3; make sure scope range is long enough
% % % kpp.getKpRampData(V0);
% % % % kpp.getKpModData(V0);
% % 
% % % kpp.kpTest(V0)
% % % kpp.SamplingRateRamp = 50e6;
% % % kpp.InitialDepth = 20;
% % % kpp.RampTime = 10e-3;
% % % kpp.getKpRampData(V0)
% % 
% % %% Normal Scan
% % kpp.SamplingRateRamp = 50e6;
% % kpp.IsOverride=false;
% % kpp.InitialDepth = 20;
% % kpp.RampTime = 10e-3;
% % % kpp.getKpRampData(V0);
% % kpp.getKpModData(V0);
% % 
% % %% Try with shortest RampTraining for bandmapping
% % % kpp.RampTime=100e-6;
% % % kpp.IsOverride=true;
% % kpp.getKpRampData(V0, 2.5e5);

clear all