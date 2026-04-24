%% LSTM
clear
kpp = KpPredistortion;
kpp.Method = "LSTM";
kpp.IsIncludeAmpOffset = false;
kpp.NChannel = 1;
kpp.ChirpDuration = 1e-3;
kpp.SineDuration = 1e-4;


kpp.setHardware
kpp.measureOffset
kpp.initializeDataset
kpp.getChirpData
kpp.getAmpModChirpData
kpp.pretrain
kpp.train

%% MLP
clear
close all
kpp = KpPredistortion;
kpp.Method = "MLP";
kpp.IsIncludeAmpOffset = false;
kpp.NChannel = 1;
kpp.NSampleScope = 1e6; % Number of samples on the scope
kpp.SamplingRateScope = 1e9;
kpp.ChirpDuration = 0.8e-3;
kpp.SineDuration = 0.8e-4;
kpp.SamplingRateAwg = 100e6;
kpp.SamplingRateMl = 100e6;
kpp.IgnoredTime = 1e-6;


kpp.setHardware
kpp.measureOffset
kpp.initializeDataset
kpp.measureDelay
kpp.getFourierData
kpp.pretrain

%% ILC
clear
close all
kpp = KpPredistortion;
kpp.Method = "ILC";
kpp.IsIncludeAmpOffset = false;
kpp.IsGuessUsingOldData = false;
kpp.IsUsingSpectrum = true;
kpp.NChannel = 2;
kpp.NSampleScope = 1e6; % Number of samples on the scope
kpp.SamplingRateScope = 1e9;
kpp.ChirpDuration = 0.8e-3;
kpp.SineDuration = 0.8e-4;
kpp.SamplingRateAwg = 200e6;
kpp.SamplingRateMl = 200e6;
kpp.IgnoredTime = 1e-6;
kpp.FrequencyRange = [100e3,2.4e6];
kpp.AlphaMaximum = 60;
kpp.Beta = 0.5;
% kpp.DelayTimeEstimated = [4.115,4.115] * 1e-6;
kpp.DelayTimeEstimated = [2.9,2.9] * 1e-6;
kpp.ErrorThreshold = 5e-3;
kpp.NGrid = 10;

kpp.setHardware
kpp.measureOffset
kpp.initializeDataset
kpp.measureDelay

V0 = 6;
% kpp.getKpModData(V0)
kpp.getKpRampData(V0)

%% ILC data analysis
para = cell2mat(kpp.Dataset(1).X.');
f = unique(para(:,1));
for ii = 1:numel(f)
    idx = para(:,1) == f(ii);
    paraF = para(idx,:);
    er = kpp.Error{1}(idx);
    offset = unique(paraF(:,3));
    nOffset = numel(offset);
    close(figure(5283))
    fig = figure(5283);
    fig.Position = [400,200,800,800];
    for jj = 1:nOffset
        ax = nexttile;
        idx2 = paraF(:,3) == offset(jj);
        paraO = paraF(idx2,:);
        ero = er(idx2);
        plot(paraO(:,2),ero)
        xlabel("amplitude")
        ylabel("error")
        title(ax,"f = " + f(ii)/1e6 + "MHz, offset = " + offset(jj))
    end
end
