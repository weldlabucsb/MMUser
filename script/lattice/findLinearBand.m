atom = getAtom("Lithium7");
laser = GaussianBeam(wavelength=1064e-9,waist = [110e-6;110e-6],power=0.6,direction = [0;0;1]);
ol = OpticalLattice(atom,laser);
ol.DepthKd = 13 * ol.RecoilEnergy;
ol.updateIntensity
nq = 1e3;
nMax = 3;
% ol.computeAll1D(nq,nMax);
% q = ol.QuasiMomentumList;
kL = laser.AngularWavenumber;
q = linspace(0,kL,nq);
dq = q(2) - q(1);
qMin = 0.45 * kL;
qMax = kL - qMin;
[~,qMinIdx] = min(abs(q-qMin));
[~,qMaxIdx] = min(abs(q-qMax));
% unit = 3 * Constants.SI("hbar") * kL /2 /pi / atom.mass;
E = ol.computeBand1D(q,0:3);
dEdq = gradient(E(3,:),dq);
qRange = 0.1 * kL;
% unit = (E(end) - E(1)) / dq / (numel(E) - 1);
unit1 = dEdq(round(nq/2));
lambda = 1;
c0 = computeCost1(E(3,:),qMinIdx,qMaxIdx,dq,unit1,lambda);
disp(c0)

dEdq1 = gradient(E(3,:),dq);
dEdq2 = gradient(dEdq1,dq);
[~,qIdx] = min(abs(dEdq2));
unit2 = dEdq1(qIdx);
c0 = computeCost2(E(3,:),q,qRange,unit2,lambda);
disp(c0)

nf = 20;
namp = 20;
amp = linspace(0.03,0.6,namp);
% amp = 0.6;
f = linspace(25,250,nf) * 1e3;
c1 = zeros(nf,namp);
c2 = c1;
for ii = 1:nf
    for jj = 1:namp
        wf = SineWave(frequency = f(ii),amplitude = amp(jj));
        E = ol.computeFloquetAmpMod1D(q,0:nMax,wf,true);
        c1(ii,jj) = computeCost1(E(3,:),qMinIdx,qMaxIdx,dq,unit1,lambda);
        c2(ii,jj) = computeCost2(E(3,:),q,qRange,unit2,lambda);
        disp([ii,jj,c1(ii,jj)])
        disp([ii,jj,c2(ii,jj)])
    end
end

%% Test
ol.computeFloquetAmpMod1D(q,0:nMax,wf,true)

function c = computeCost1(E,qMinIdx,qMaxIdx,dq,unit,lambda)
dEdq = gradient(E,dq);
dEdq = dEdq(qMinIdx:qMaxIdx);
c1 = std(dEdq) / mean(dEdq);
dEdqMean = mean(dEdq);
c2 = lambda * (1-abs(dEdqMean)/unit);
c2 = 0;
c = c1 + c2;
end

function c = computeCost2(E,q,qRange,unit,lambda)
dq = q(2) - q(1);
dEdq1 = gradient(E,dq);
dEdq2 = gradient(dEdq1,dq);
qI = min(abs(dEdq2));
[~,qMinIdx] = min(abs(q-(qI - qRange/2)));
[~,qMaxIdx] = min(abs(q-(qI + qRange/2)));

dEdq = dEdq1(qMinIdx:qMaxIdx);
c1 = std(dEdq) / mean(dEdq);
dEdqMean = mean(dEdq);
c2 = lambda * (1-abs(dEdqMean)/unit);
c2 = 0;
c = c1 + c2;
end