atom = Alkali("Potassium39");
bz = 57.01e-4;
b = MagneticField(bias=[0,0,bz]);
min_detuning = 800.e6;
max_detuning = 1.e9;
nDetuning = 100;
detuning_list = linspace(min_detuning,max_detuning,nDetuning);
laserList = cell(1,nDetuning);
for ii = 1:nDetuning
    laserList{ii} = GaussianBeam( ...
        frequency = atom.D2.Frequency + detuning_list(ii),...
        polarization = [0,1,0],...
        direction = [1,0,0],...
        intensity = 17.5 ...
        );
end
[~,U] = atom.D2.BiasDressedStateList(b,false);

%%  calculate
nState = atom.D2.NNState;
AcData = zeros(nState,nDetuning);
for ii = 1:nDetuning
    sList = atom.D2.LaserDressedStateListSmallDetuning(laserList{ii},false,B = b,U = U);
    AcData(:,ii) = sList.EnergyShift;
    disp(ii)
end

%% Plot
close(figure(3156))
figure(3156)
plot(detuning_list * 1e-6,AcData*1e-3)
xlabel('Detuning [MHz]',Interpreter='latex')
ylabel('AC Stark Energy Shift [kHz]',Interpreter='latex')
legend(sList.Label(:),'interpreter','latex')
render