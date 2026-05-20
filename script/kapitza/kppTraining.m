folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
% kpp.UpdateKpRampDataset; % (NEW) Used to modify kprampdataset parameters
% to match new ramp settings. Only run once when trying to adjust it.
kpp.RampTime = 10e-3;
kpp.IsInverted = true;
kpp.IsGuessUsingOldData = false; %somewhat out of date, code now determines if old data available
kpp.setHardware
kpp.setHardware
kpp.InitialDepth = 20;
pause(0.5);
kpp.DelayTimeEstimated = [2.8,2.9]*1e-6;
kpp.measureDelay


kpp.IsOverride=true;  % 1= using alpha & freq override list   0 = using phase diagram params
kpp.AlphaListOverride=[54];
kpp.FrequencyListOverride=linspace(0.9e6, 2.4e6, 15);
% kpp.FrequencyListOverride=linspace(100e3, 2.4e6, 10); %usual fmod list


%%
V0 = 10;

%% Try with shortest RampTraining for bandmapping
kpp.RampTime=100e-6;
% kpp.IsOverride=false;
kpp.getKpRampData(V0, 2.5e5);
kpp.RampTime=400e-6;
% kpp.IsOverride=false;
kpp.getKpRampData(V0, 1e5);

%% Do Normal KpRampTimeTraining

% kpp.InitialDepth=20;
% kpp.RampTime = 5e-3;
% kpp.getKpRampData(V0);
% kpp.getKpModData(V0);


% Ramp data for various lattice depths
for Vi = 6:2:30
    kpp.RampTime = 10e-3;
    kpp.InitialDepth = Vi;
    kpp.getKpRampData(V0)
end

% mod data for first override above, reseting Vi to 20
kpp.InitialDepth = 20;
kpp.RampTime = 10e-3;
%kpp.getKpRampData(V0);
kpp.getKpModData(V0);

%% second fixed alpha cut, weak drive
kpp.InitialDepth = 20;
kpp.RampTime = 10e-3;
kpp.AlphaListOverride=[8];
kpp.FrequencyListOverride=linspace(0.9e6, 2.4e6, 15);
kpp.getKpModData(V0);


%% fixed omega cut

kpp.FrequencyListOverride=[1.3778e6];
kpp.AlphaListOverride=linspace(8, 60, 15);
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

%% Try with shortest RampTraining for bandmapping
% kpp.RampTime=100e-6;
% kpp.IsOverride=true;
% kpp.getKpRampData(V0, 2.5e5);
