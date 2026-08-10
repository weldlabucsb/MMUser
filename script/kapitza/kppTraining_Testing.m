folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
kpp.ClearGenDataset;
% kpp.UpdateKpRampDataset; % (NEW) Used to modify kprampdataset parameters
% to match new ramp settings. Only run once when trying to adjust it.
kpp.RampTime = 10e-3;
kpp.CorrFactor = [1.069390 , 1.065501];
kpp.IsInverted = true;
kpp.IsGuessUsingOldData = false; %somewhat out of date, code now determines if old data available
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
kpp.IsUseGenDatabase = 0; %Actually don't thinnk this does anything

%%


t0 = datetime('now');
kpp.TrainTanhRamp(0, 70, 10e-3);
kpp.TrainModWaveform(70,2.4e6, 40);
t1 = datetime('now');

disp(t1-t0);
%%
% kpp.TrainModWaveform(10, 300e3, 0.5);
% kpp.TrainModWaveform(90, 300e3, 40); 
   kpp.ErrorThreshold  = 0.01;   % Acceptable average RMSE (e.g., 10 mV)

% kpp.TrainModWaveform(150, 500e3, 1); %Currently the find 
%    kpp.ErrorThreshold  = 0.01;   % Acceptable average RMSE (e.g., 10 mV)
% kpp.TrainModWaveform(150, 500e3, 1); %Currently the find 


%% Train up to 10Er Modulation Depth difference, scanning slight variations of mean lattice depth, constant lattice depth of 

MeanDepth=70;
ScanRange=10; %Scan +/- above and below the target range for each lattice depth to scan for variations in mean lattice depth
ScanStep=1; %Scan small variatios of 1 percent steps above and below the scan range
ModDepth=30; %Mod depth of both lattices in Er;
ModDepthList=30;

DepthList=(MeanDepth-ScanRange):ScanStep:(MeanDepth+ScanRange);
% DepthList=61:1:(MeanDepth+ScanRange);
% DepthList=60;


for ii=1:length(DepthList)
    disp(kpp.CorrFactor);
    which("LatticeCalib.mat")
    kpp.TrainTanhRamp(0, DepthList(ii), 10e-3);
    kpp.TrainTanhRamp(DepthList(ii), DepthList(ii), 4e-3);
    for jj=1:length(ModDepthList)
        kpp.TrainModWaveform(DepthList(ii), 2.4e6, ModDepthList(jj));
    end
end

%% Close hardware connections

clear all


