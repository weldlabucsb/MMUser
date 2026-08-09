function wfl = kpControlGen(chIdx,V0,f, modDepth, nCycle,rampTime, HoldTime)

if nargin<7
    HoldTime=0;
end
%Written by Eber Nolasco-Martinez 8-2-2026

% arguments
%     chIdx
%     V0
%     f
%     alpha
%     beta
%     nCycle
%     rampTime
%     isInverted = true
%     initialDepth = V0
%     isBm = false
%     bmTime double = 1e-6
% end


folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
% dataName = "KppData_2026_04_20_16_40_41.mat";
% dataPath = fullfile(folderPath,dataName);
dataPath = findLatestFile(folderPath);
kpp = loadVar(dataPath,"kpp");
% kpp.IsInverted = isInverted;
% kpp.InitialDepth = initialDepth;
% kpp.IsRampUpModulation = false;
phi=0;
if chIdx==2
    phi=pi;
end

if HoldTime==0

    wfl = kpp.getRampandMod(chIdx,V0,rampTime,f,modDepth,nCycle,phi);
else
    wfl = kpp.getRampandModandHold(chIdx,V0,rampTime,f,modDepth,nCycle,HoldTime,phi);
end
end

