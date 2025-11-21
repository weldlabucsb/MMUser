atom = Alkali("Potassium39");
bz = 57.01e-4;
b = MagneticField(bias=[0,0,bz]);
min_detuning = 800.e6;
max_detuning = 1.e9;
detuning_list = linspace(min_detuning,max_detuning,100);
laserList = cell(1,numel(detuning_list));
for ii = 1:numel(detuning_list)
    laserList{ii} = GaussianBeam( ...
        frequency = atom.D2.Frequency + detuning_list(ii),...
        polarization = [0,1,0],...
        direction = [1,0,0],...
        intensity = 17.5 ...
        );
end
[~,U] = atom.D2.BiasDressedStateList(b,false);

%%
parfor ii = 1:numel(detuning_list)
    atom.D2.LaserDressedStateListSmallDetuning(laserList{ii},true,B = b,U = U);
end