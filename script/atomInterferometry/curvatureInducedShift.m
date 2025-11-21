load magicDressedDivisor5.mat
%% Set up atom parameters
atom = Alkali("Lithium7");
laser = GaussianBeam( ...
    wavelength = 1064e-9,...
    direction = [0;1;0],...
    polarization = [0;0;1],...
    power = 1, ...
    waist = 110e-6 ...
    );
ol = OpticalLattice(atom,laser);
kL = laser.AngularWavenumber;
Er = ol.RecoilEnergy;
dq = 1e-3;
g = 9.81;
M = atom.mass;
divisor = 5;
F = M * g / divisor;
hbar = Constants.SI("hbar");
h = hbar * 2 * pi;
tPulse = 2.5e-3 * divisor;
tRamp = 0.1e-3 * divisor;
nq = 1e4;
nKappa = 1e3;
kappa0 = (2 * pi * 1) ^2 * M;
kappaList = linspace(0,kappa0,nKappa);
kappaList2 = kappaList * 1e-7;
sigma = 0.13 / 2.355;

%% constrast
[~,idx] = min(abs(loopSizeTheory - 15.8/2));
lz = loopSizeTheory(idx);
depth = magicDepthTheory(idx);
ol.DepthKd = depth * Er;
ol.updateIntensity;
qR = (1 - lz);
qR = mod(qR+1,2)-1;
qRp = qR + lz * 2;
qR = qR * kL;
qRp = qRp * kL;
qList = linspace(qR,qRp,nq);
dq = qList(2) - qList(1);
t = (qList - qList(1)) * hbar / F;
E = computeBand(depth,qList/kL) * Er * h;
E(1,:) = E(1,:) + E(2,1)-E(1,1);
dE = (E(1,:) - E(2,:));
q1 = cumtrapz(dE) * dq * hbar / F^2;
deltaQList = q1(end) * kappaList;
C = arrayfun(@(x) calc_overlap_twonormal(sigma,sigma,-x/2,x/2,-1,1,1e-3),deltaQList/hbar/kL);

%% phase shift
dt = t(2) - t(1);
dEdq2P = gradient(gradient(E(1,:),dq*hbar),dq*hbar);
dEdq2D = gradient(gradient(E(2,:),dq*hbar),dq*hbar);
q1P = cumtrapz(E(1,:)) * dq * hbar / F^2;
q1D = cumtrapz(E(2,:)) * dq * hbar / F^2;
x1P = cumtrapz(q1P.*dEdq2P) * dt;
x1D = cumtrapz(q1D.*dEdq2D) * dt;
x0P = E(1,:) / F;
x0D = E(2,:) / F;
phi0 = 1/hbar/F * trapz(dE) * dq * hbar;
dphiOverPhi0 = kappaList2 * abs(trapz(x1P-x1D)/trapz(x0P-x0D));

save(fullfile(findFolderInPath("atomInterferometry"),"curvatureError.mat"),"kappaList","kappaList2","C","dphiOverPhi0")

function E = computeBand(v0,q)
nMax = 55;
n = [2,3];
j = 1-nMax:2:nMax-1;
Vmat = -v0/4*gallery('tridiag',nMax,1,2,1); % I added a minus sign here
E = zeros(nMax,length(q)); % Band energy
Fjn = zeros(nMax,nMax,length(q)); % Bloch states in the plane wave basis.
for qIdx = 1:length(q)
    Tmat = sparse(1:nMax,1:nMax,(q(qIdx)+j).^2,nMax,nMax);
    [Fjn(:,:,qIdx),tempE] = eig(full(Vmat+Tmat));
    E(:,qIdx) = diag(tempE);
end
E = E(n,:);
end

function [overlap2] = calc_overlap_twonormal(s1,s2,mu1,mu2,xstart,xend,xinterval)
% clf
x_range=xstart:xinterval:xend;
% plot(x_range,[normpdf(x_range,mu1,s1)' normpdf(x_range,mu2,s2)']);
% hold on
% area(x_range,min([normpdf(x_range,mu1,s1)' normpdf(x_range,mu2,s2)']'));
overlap=cumtrapz(x_range,min([normpdf(x_range,mu1,s1)' normpdf(x_range,mu2,s2)']'));
overlap2 = overlap(end);
% legend([num2str(overlap2)]);
end