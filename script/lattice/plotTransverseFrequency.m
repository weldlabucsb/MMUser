atom = Alkali("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 1, ...
    waist = 195e-6 ...
    );
ol = OpticalLattice(atom,laser);
kL = ol.Laser.AngularWavenumber;
Er = ol.RecoilEnergy;
ol.DepthSpec = 8.8458 * Er;
ol.updateIntensity;
waistList = (20:400)*1e-6;
freqList = zeros(1,numel(waistList));

for ii = 1:numel(waistList)
    ol.Laser.Waist = [waistList(ii);waistList(ii)];
    ol.DepthKd = 8.8458 * Er;
    ol.updateIntensity;
    freqList(ii) = ol.RadialFrequency;
end

plot(waistList*1e6,freqList)
xlabel("Waist [$\mu \mathrm{m}$]")
ylabel("Radial Trapping Frequency [$\mathrm{Hz}$]")
render