%UpdateKpRampDataset.m

% Assume latest Kpp dataset already retrieved.
% Adjusts kpp to add kpRampParameter to all tables, run before newly
% adjusted KpPredistortion

%Script doesn't work, use internal method in class fo same name.

for idx=1:2
    datasetlength=length(kpp.Dataset(idx).KpParameter);
    A=cell2mat(kpp.Dataset(idx).KpRampParameter);
    for ii=1:datasetlength
        clear Aset
        Aset=squeeze(A(:, ii));
        if length(Aset)<6
            Aset=[Aset;kpp.RampTime];
            kpp.Dataset(idx).KpRampParameter{ii}=Aset;
        end
    end




end