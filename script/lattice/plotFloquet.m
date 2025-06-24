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
% ol.DepthSpec = 8.25 * Er;
% ol.DepthSpec = 8.866207 * Er;
ol.DepthSpec = 8.445762549956317 * Er;
ol.updateIntensity;
nq = 2e4;
% nq = 1e3;
ol.computeAll1D(nq,2)
Fjn = ol.BlochStateFourier;
lambda = laser.Wavelength;
% driveFreq = 143.2231e3;
driveFreq = 127.4382e3;
fBO = 93.626964183326550;


%% Compute drive strength
qR = ol.computeTransitionQuasiMomentum1D(driveFreq,1,2);
h = Constants.SI("hbar");
F = h * fBO / a;
A = ol.AmpModCoupling;
V0 = h * ol.Depth;
Apd = squeeze(A(2,3,:));
[~,qRIdx] = min(abs(qList-qR));
[~,qRIdx2] = min(abs(qList+qR));

E = h * ol.BandEnergy;
Ed = E(3,:);
Ep = E(2,:);
dq = qList(2) - qList(1);
dEdq = gradient(Ed-Ep,dq);
alpha = 1 / (V0) / abs(Apd(qRIdx)) .*...
    sqrt(log(4)/pi.*F.*abs(dEdq(qRIdx)));

%%

wf = SineWave(amplitude = alpha * 2,frequency = driveFreq,startTime=0,duration = 0.2,samplingRate=1e7);
% wf = SineWave(amplitude = 0.02071 * 2,frequency = driveFreq,startTime=0,duration = 0.2,samplingRate=1e7);
qList = linspace(-kL,kL,nq);
% [EF,VF] = ol.computeFloquetAmpMod1D(qList,1:2,wf);
[EF,VF] = ol.computeFloquetAmpMod1D(qList,0:2,wf);
save('FData.mat','EF','VF')

%% 
figure(123542)
plot(qList/kL,EF(1,:)/Er,'.',qList/kL,EF(2,:)/Er,'.',qList/kL,EF(3,:)/Er,'.')
EF_Eric = table2array(readtable('C:\Users\Weld Lab User\Downloads\floquetblochbands.csv'));
EF_Eric = EF_Eric + driveFreq/Er/2 + 0.33 - 1 * driveFreq/Er;
qList2 = linspace(-kL,kL,size(EF_Eric,2));
hold on
plot(qList2/kL,EF_Eric(1,:),'.',qList2/kL,EF_Eric(2,:),'.',qList2/kL,EF_Eric(3,:),'.')