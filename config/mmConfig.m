% This is a script to set the user-defined configurations

%% Path
HardwareLogOrigin = "B:\_Li\_LithiumData\HardwareLogs"; %The path where all Hardware logs are temporarily saved

%% Database
BecExpDatabaseName = "lithium_experiment"; %The postgresql database name for saving the experimental metadata. Just give it a name.
BecExpDatabaseTableName = "main"; %The table. Usually I use 'main'.
ServerName = ["localhost";"128.111.8.45"]; %The first server has to be localhost. The second is assumed to be remote.
Port = [5432;5432];
Username = ["postgres";"postgres";]; %The master username/password you use when you install PostgreSQL
Password = ["SupermassiveBlackHole";"SupermassiveBlackHole"];

%% Acquisition
% Define your acquisition here as a table with columns:
% Name: name of your AWG
% DeviceModel: Manufacture + model. It has to be a supported class
% DeviceID: ID of the devicce if multiple devices share the same adaptor
% SerialNumber: Camera serial number
% ExposureTime: Exposure time in [us]
% Magnification: Your optical system's magnification
% Transmission: Your optical system's transmission
% BadRow: Rows that have bad pixels
AcquisitionConfig = cell2table( ...
    { ...
    "TOP",   "PcoEdge5p5",         0, 924,      30e-6, 3.337676782237963, 1, 1081; ...
    "XODT",  "BaslerAcA1920_25um", 1, 21663581, 70e-6, 100/250,           1, []; ...
    "SBB",   "BaslerAcA1920_25um", 1, 21975809, 70e-6, 500/300,           1, []; ...
    "GREEN", "BaslerAcA1920_25um", 1, 24528051, 70e-6, 1,                 1, []; ...
    "ODT",   "BaslerAcA1920_25um", 1, 21750852, 70e-6, 100/250,           1, []; ...
    },...
    "VariableNames",["Name","DeviceModel","DeviceID",...
    "SerialNumber","ExposureTime","Magnification","Transmission","BadRow"]);

%% Waveform generator
% Define your waveform generator here as a table with columns:
% Name: name of your AWG
% DeviceModel: Manufacture + model. It has to be a supported class
% ResourceName: The VISA address or the TCP address
WaveformGeneratorConfig = cell2table( ...
    { ...
    "LatticeMod","Keysight33600A","TCPIP0::172.16.0.3::inst0::INSTR"; ...
    "XvWingMod","Keysight33500B","TCPIP0::172.16.0.4::inst0::INSTR";...
    "GreenWallMod","SpectrumDN2662_02","TCPIP::172.16.0.0::inst0";...
    },...
    "VariableNames",["Name","DeviceModel","ResourceName"]);

%% Scope
% Define your scope here as a table with columns:
% Name: name of your scope
% DeviceModel: Manufacture + model. It has to be a supported class
% ResourceName: The VISA address or the TCP address
ScopeConfig = cell2table( ...
    { ...
    "LatticeScope","Tektronix1104","USB0::0x0699::0x03B4::C011351::0::INSTR"; ...
    },...
    "VariableNames",["Name","DeviceModel","ResourceName"]);

%% Phase lock
% Define your phase lock here as a table with columns:
% Name: name of your scope
% DeviceModel: Manufacture + model. It has to be a supported class
% ResourceName: The VISA address or the TCP address
PhaseLockConfig = cell2table( ...
    { ...
    "ImagingLock","VescentSlice","COM6"; ...
    },...
    "VariableNames",["Name","DeviceModel","ResourceName"]);

%% BecExp
CiceroComputerName = "GOB"; %The name of the computer running Cicero
CiceroLogOrigin = "\\172.16.0.2\RunLogs"; %The path where Cicero logs are temporarily saved
BecExpControlComputerName = "WOODHOUSE"; %The name of the computer running BecExp analysis
BecExpParentPath = "B:\_Li\_LithiumData"; %The path where BecExp analysis data are saved
BecExpDataPrefix = "run";
BecExpDataFormat = ".tif"; 
BecExpIsAutoDelete = false; %If you want to auto delete empty BecExp data folders
BecExpDataGroupSize = 3;
BecExpIsAutoAcquire = true;
BecExpOdColormap = {jet}; %Change to your favorite colormap
BecExpAtomName = "Lithium7";
BecExpImagingStageList = ["LF","HF","NI"]; %List your possible imaging stages here. For example, if you do imaging at low/high magnetic fields, type ["LF","HF"].
