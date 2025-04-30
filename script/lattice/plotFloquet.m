 %%
atom = Alkali("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 1, ...
    waist = 110e-6 ...
    );
ol = OpticalLattice(atom,laser);
kL = ol.Laser.AngularWavenumber;
Er = ol.RecoilEnergy;
% ol.DepthSpec = 8.8458 * Er;
ol.DepthSpec = 8.25 * Er;
ol.updateIntensity;
% nq = 2e4;
nq = 1e3;
ol.computeAll1D(nq,2)
Fjn = ol.BlochStateFourier;
lambda = laser.Wavelength;

%%
driveFreq = 143e3;
wf = SineWave(amplitude = 0.05 * 2,frequency = driveFreq,startTime=0,duration = 0.2,samplingRate=1e7);
% wf = SineWave(amplitude = 0.02071 * 2,frequency = driveFreq,startTime=0,duration = 0.2,samplingRate=1e7);
qList = linspace(-kL,kL,nq);
% [EF,VF] = ol.computeFloquetAmpMod1D(qList,1:2,wf);
[EF,VF] = ol.computeFloquetAmpMod1D(qList,0:2,wf);

%% 
figure(123542)
plot(qList/kL,EF(1,:)/Er,'.',qList/kL,EF(2,:)/Er,'.',qList/kL,EF(3,:)/Er,'.')
EF_Eric = table2array(readtable('C:\Users\Weld Lab User\Downloads\floquetblochbands.csv'));
EF_Eric = EF_Eric + driveFreq/Er/2 + 0.33 - 1 * driveFreq/Er;
qList2 = linspace(-kL,kL,size(EF_Eric,2));
hold on
plot(qList2/kL,EF_Eric(1,:),'.',qList2/kL,EF_Eric(2,:),'.',qList2/kL,EF_Eric(3,:),'.')