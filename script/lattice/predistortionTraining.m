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