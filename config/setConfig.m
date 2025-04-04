% This is a function to set the configuration file
function setConfig
disp(newline + "Setting configurations...")
%% Find the repo path
ConfigPath = string(findFunctionPath());
RepoPath = findFolderInPath("MuscleMuseum");
TempPath = fullfile(getenv('USERPROFILE'),"Documents","MMTemp");
if numel(RepoPath) == 0
    error("MuscleMuseum is not in MATLAB Path.")
elseif numel(RepoPath) >= 2
    error("Multiple MuscleMuseum packages are in MATLAB Path. Please resolve.")
end
configName = fullfile(ConfigPath,'Config.mat');

%% Set the main local data path
mainPath = fullfile(getHome,"Documents","MMData");

%% Set the computer configuration
% PLEASE EDIT HERE
BecExpControlComputerName = "YourComputer"; %The name of the computer running BecExp analysis
BecExpParentPath = "YourPath"; %The path where BecExp analysis data are saved
BecExpDatabaseName = "alkali_experiment"; %The postgresql database name for saving the experimental metadata. Just give it a name.
BecExpDatabaseTableName = "main"; %The table. Usually I use 'main'.
CiceroComputerName = "YourComputer2"; %The name of the computer running Cicero
CiceroLogOrigin = "YourPath2"; %The path where Cicero logs are temporarily saved
HardwareLogOrigin = "YourPath3"; %The path where all other Hardware logs are temporarily saved
ComputerConfig = table(BecExpControlComputerName,BecExpParentPath,...
    BecExpDatabaseName,BecExpDatabaseTableName,CiceroComputerName,...
    CiceroLogOrigin,HardwareLogOrigin,RepoPath,ConfigPath,TempPath);
save(configName,"ComputerConfig",'-mat')

%% Set the database configuration
% PLEASE EDIT THE PGSQL SERVER INFORMATION
Name = [
    BecExpDatabaseName;...
    "simulation";...
    ];
Table = {
BecExpDatabaseTableName;    
["master_equation_simulation",...
    "gross_pitaevskii_equation_simulation",...
    "schrodinger_equation_simulation",...
    "fokker_planck_equation_simulation",...
    "lattice_schrodinger_equation_simulation_1d",...
    "lattice_fourier_simulation_1d"]...
    };
DatabaseConfig = table(Name,Table); %This saves exp/sim database names and the names of the tables

Name = ["localhost";"YourRemoteServer"];
Port = [5432;5432];
Username = ["postgres";"postgres";]; %The master username/password you use when you install PostgreSQL
Password = ["SupermassiveBlackHole";"SupermassiveBlackHole"];
DatabaseServerConfig = table(Name,Port,Username,Password);
save(configName,"DatabaseConfig","DatabaseServerConfig",'-mat','-append')

%% Set the acquisition configuration
% PLEASE EDIT HERE IF YOU NEED AUTO CAMERA CONTROL
Name = [
    "Camera1";
    "Camera2";
    ]; %Name your cameras.
DeviceModel = [
    "PcoEdge5p5";
    "BaslerAcA1920_25um";
    ]; %Camera types. Now only PCO and Basler are supported.
DeviceID = int32([0;1]); %To distinguish devices if multiple devices are connected through the same adaptor
SerialNumber = int32([ ...
    1; ...
    2;]);
ExposureTime = [30;70] * 1e-6; % in SI unit
Magnification = [3.33;100/250;]; % Dependent on your setup
Transmission = [1;1]; % Dependent on your setup
load("quantumEfficiency.mat","pcoQE")
QuantumEfficiencyData = {
    pcoQE;
    [];
};
BadRow = {
    [];
    [];
};
AcquisitionConfig = table(Name,DeviceModel,DeviceID,...
    SerialNumber,ExposureTime,...
    BadRow,Magnification,Transmission,QuantumEfficiencyData);
save(configName,"AcquisitionConfig",'-mat','-append')

%% Set the waveform generator configuration
% PLEASE EDIT HERE IF YOU NEED AUTO AWG CONTROL
Name = [
    "Modulation1";...
    "Modulation2";...
    ]; %Name your AWGs.
DeviceModel = [
"Keysight33600A";...
"Keysight33500B";...
];
ResourceName = [
"YourResourceName1";...
"YourResourceName2";...
]; %The VISA address or the TCP address
WaveformGeneratorConfig = table(Name,DeviceModel,ResourceName);
save(configName,"WaveformGeneratorConfig",'-mat','-append')

%% Set the scope configuration
% PLEASE EDIT HERE IF YOU NEED AUTO SCOPE CONTROL
Name = [
    "Scope1"
    ]; %Name your scope.
DeviceModel = [
"Tektronix1104"
];
ResourceName = [
"YourResourceName3"
]; %The VISA address or the TCP address
ScopeConfig = table(Name,DeviceModel,ResourceName);
save(configName,"ScopeConfig",'-mat','-append')

%% Set the phase lock configuration
Name = [
    "PhaseLock1"
];
DeviceModel = [
    "VescentSlice"
];
ResourceName = [
    "YourResourceName4"
];
PhaseLockConfig = table(Name,DeviceModel,ResourceName);
save(configName,"PhaseLockConfig",'-mat','-append')

%% Set the hardware list
Name = [WaveformGeneratorConfig.Name;ScopeConfig.Name;PhaseLockConfig.Name];
Type = [repmat("WaveformGenerator",numel(WaveformGeneratorConfig.Name),1);...
    repmat("Scope",numel(ScopeConfig.Name),1);repmat("PhaseLock",numel(PhaseLockConfig.Name),1)];
DataPath = fullfile(ComputerConfig.HardwareLogOrigin,Name);
HardwareList = table(Name,Type,DataPath);
save(configName,"HardwareList",'-mat','-append')

%% Set the ROI configuration
RoiConfig = readtable("roi.csv.xlsx",'TextType','string');
RoiConfig.SubRoiSeparation = cell2mat(arrayfun(@str2num,RoiConfig.SubRoiSeparation,'UniformOutput',false));
RoiConfig.SubRoiNRowColumn = cell2mat(arrayfun(@str2num,RoiConfig.SubRoiNRowColumn,'UniformOutput',false));
RoiConfig.SubRoiCenterSize = arrayfun(@str2num,string(RoiConfig.SubRoiCenterSize),'UniformOutput',false);
save(configName,"RoiConfig",'-mat','-append')

%% Set the BEC experiment configuration
% PLEASE EDIT HERE IF YOU NEED AUTO BECEXP ANALYSIS

%copy the .dll for Cicero log reading
dsLibPath = fullfile(matlabroot,'\bin\win64\DataStructures.dll');
if ~exist(dsLibPath,'file')
    try
        copyfile(fullfile(RepoPath,"lib","datastructures","DataStructures.dll"),...
            fullfile(matlabroot,'\bin\win64\DataStructures.dll'),'f');
    catch
        error("No permission to copy file. Try runing MATLAB as admin.")
    end
end

BecExpConfig.ParentPath = BecExpParentPath;
BecExpConfig.DataPrefix = "run";
BecExpConfig.DataFormat = ".tif"; 
BecExpConfig.IsAutoDelete = false; %If you want to auto delete empty BecExp data folders
BecExpConfig.DatabaseName = BecExpDatabaseName;
BecExpConfig.DatabaseTableName = BecExpDatabaseTableName;
BecExpConfig.CiceroLogOrigin = CiceroLogOrigin;
BecExpConfig.DataGroupSize = 3;
BecExpConfig.IsAutoAcquire = true;
BecExpConfig.OdColormap = {jet}; %Change to your favorite colormap
BecExpConfig.AtomName = "Lithium7"; 
BecExpConfig.ControlAppName = "BecControl";
BecExpConfig.ImagingStageList = ["LF","HF"]; %List your possible imaging stages here. For example, if you do imaging at low/high magnetic fields, type ["LF";"HF"].

becExpType = readtable("becExpType.csv.xlsx",'TextType','string');
BecExpConfig = [becExpType,repmat(struct2table(BecExpConfig),size(becExpType,1),1)];
BecExpParameterUnit = readtable("parameterUnit.csv.xlsx",'TextType','string');
BecExpConfig = join(BecExpConfig,BecExpParameterUnit,'Keys',{'ScannedParameter','ScannedParameter'});

BecExpConfig.FringeRemovalMask = arrayfun(@eval,(fillmissing(BecExpConfig.FringeRemovalMask,'constant',"[]")),'UniformOutput',false);
save(configName,"BecExpConfig","BecExpParameterUnit",'-mat','-append')

%% Set the BEC experiment local test configuration
BecExpLocalTestConfig = BecExpConfig;
BecExpLocalTestConfig.DatabaseName(:) = BecExpDatabaseName + "_local";
BecExpLocalTestConfig.ParentPath(:) = fullfile(mainPath,"becExp");
BecExpLocalTestConfig.CiceroLogOrigin(:) = fullfile(RepoPath,"test","testData","testLogFiles");
BecExpLocalTestConfig.IsAutoAcquire(:) = false;
BecExpLocalTestConfig.IsAutoDelete(:) = false;

save(configName,"BecExpLocalTestConfig",'-mat','-append')

%% Set the master equation simulation configuration
MeSimConfig.ParentPath = fullfile(mainPath,"meSim");
MeSimConfig.DataPrefix = "run";
MeSimConfig.DataFormat = ".mat";
MeSimConfig.IsAutoDelete = false;
MeSimConfig.DatabaseName = "simulation";
MeSimConfig.DatabaseTableName = "master_equation_simulation";
MeSimConfig.DataGroupSize = 1;

MeSimType = readtable("meSimType.csv.xlsx",'TextType','string');
MeSimConfig = [MeSimType,repmat(struct2table(MeSimConfig),size(MeSimType,1),1)];

MeSimOutput = readtable("meSimOutput.csv.xlsx",'TextType','string');
save(configName,"MeSimConfig","MeSimOutput",'-mat','-append')

%% Set the lattice schrodinger equation simulation configuration
LatticeSeSim1DConfig.ParentPath = fullfile(mainPath,"latticeSeSim1D");
LatticeSeSim1DConfig.DatabaseName = "simulation";
LatticeSeSim1DConfig.DataPrefix = "run";
LatticeSeSim1DConfig.DataFormat = ".mat";
LatticeSeSim1DConfig.IsAutoDelete = false;
LatticeSeSim1DConfig.DatabaseTableName = "lattice_schrodinger_equation_simulation_1d";
LatticeSeSim1DConfig.DataGroupSize = 1;

LatticeSeSim1DType = readtable("latticeSeSim1DType.csv.xlsx",'TextType','string');
LatticeSeSim1DConfig = [LatticeSeSim1DType,repmat(struct2table(LatticeSeSim1DConfig),size(LatticeSeSim1DType,1),1)];

LatticeSeSim1DOutput = readtable("latticeSeSim1DOutput.csv.xlsx",'TextType','string');
save(configName,"LatticeSeSim1DConfig","LatticeSeSim1DOutput",'-mat','-append')

%% Set the lattice Fourier schrodinger equation simulation configuration
LatticeFourierSeSim1DConfig.ParentPath = fullfile(mainPath,"latticeFourierSeSim1D");
LatticeFourierSeSim1DConfig.DatabaseName = "simulation_local";
LatticeFourierSeSim1DConfig.DataPrefix = "run";
LatticeFourierSeSim1DConfig.DataFormat = ".mat";
LatticeFourierSeSim1DConfig.IsAutoDelete = false;
LatticeFourierSeSim1DConfig.DatabaseTableName = "lattice_fourier_simulation_1d";
LatticeFourierSeSim1DConfig.DataGroupSize = 1;

LatticeFourierSeSim1DType = readtable("latticeFourierSeSim1DType.csv.xlsx",'TextType','string');
LatticeFourierSeSim1DConfig = [LatticeFourierSeSim1DType,repmat(struct2table(LatticeFourierSeSim1DConfig),size(LatticeFourierSeSim1DConfig,1),1)];

LatticeFourierSeSim1DOutput = readtable("latticeFourierSeSim1DOutput.csv.xlsx",'TextType','string');
save(configName,"LatticeFourierSeSim1DConfig","LatticeFourierSeSim1DOutput",'-mat','-append')


disp("Done.")
end