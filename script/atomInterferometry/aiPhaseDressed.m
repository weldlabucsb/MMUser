function [phi,loopSize] = aiPhaseDressed(V0,qR,freq,alpha,tPulse,tRamp,F,dq)
%AIPHASESTATIC Summary of this function goes here
%   Only compute the dynamical phase

%% Parameters
nMax = 55;
lambda = 1064e-9;
n = [2,3];
q = -1 : dq : 1;
kL = 2*pi / lambda;
hbar = 1.054571628000000e-34;
Er = 2.511908463380107e+04;
h = hbar * 2 * pi;
nBO = floor(1-qR);
bzIdx = floor((qR + 1)/2);

%% Compute band
j = 1-nMax:2:nMax-1;
Vmat = -V0/4*gallery('tridiag',nMax,1,2,1); % I added a minus sign here
E = zeros(nMax,length(q)); % Band energy
Fjn = zeros(nMax,nMax,length(q)); % Bloch states in the plane wave basis.
for qIdx = 1:length(q)
    Tmat = sparse(1:nMax,1:nMax,(q(qIdx)+j).^2,nMax,nMax);
    [Fjn(:,:,qIdx),tempE] = eig(full(Vmat+Tmat));
    E(:,qIdx) = diag(tempE);
end
E = E(n,:) * Er;
Fjn = Fjn * sqrt(2 / lambda); % Normalization

% Phase convention. Making sure the eigenstates are continuously varying along q
[~,qCenterIdx] = min(abs(q));
if numel(q) >= 3
    for nIdx = 1:nMax
        m = sum(abs(diff((squeeze(Fjn(:,nIdx,:))),1,2))>0.1 * sqrt(2 / lambda),1);
        % m = m > 2 ;
        m(1) = 0;
        if all(m==0)
            continue
        else
            flipPos = find(m,1);
            flipPos(abs(flipPos - qCenterIdx) <= 1) = [];
            if ~isempty(flipPos)
                Fjn(:,nIdx,flipPos+1:end) = -Fjn(:,nIdx,flipPos+1:end);
            end
        end
    end
end
Fjn = Fjn(:,n,:);

%% Compute band coupling
% Parameters
nq = numel(q);
nBand = numel(n);

% Matrices for computing
FjnShift = circshift(Fjn,1) + circshift(Fjn,-1);
idenMat = eye(nBand,nBand);

% Compute coupling
A = zeros(nBand,nBand,nq);
for qq = 1:nq
    AA = squeeze(Fjn(:,:,qq))';
    BB = squeeze(FjnShift(:,:,qq));
    A(:,:,qq) = lambda / 8 * AA * BB + idenMat;
end
Apd = squeeze(A(1,2,:));
Omega = alpha * V0 * abs(Apd) * Er * 2 * pi;

%% Compute coupling quasi-energy
qIdx = q<=0;
qq = q(qIdx);
EE = E(:,qIdx);
deltaE = abs(EE(2,:) - EE(1,:));
bandDist = max(deltaE);
bandGap = min(deltaE);
qR1 = zeros(1,numel(freq));
for ii = 1:numel(freq)
    if freq(ii) > bandDist || freq(ii) < bandGap
        qR1(ii) = NaN;
        phi = NaN;
        return
    else
        [~,resIdx] = sort(abs(freq(ii) - deltaE));
        resIdx = resIdx(1:2);
        q1 = qq(resIdx(1));
        q2 = qq(resIdx(2));
        qResTemp = (q1 + q2) / 2;
        dEdq = gradient(deltaE,dq);
        dEdq = (dEdq(resIdx(1)) + dEdq(resIdx(2)))/2;
        deltaE0 = (deltaE(resIdx(1)) + deltaE(resIdx(2)))/2;
        qR1(ii) = (freq(ii) - deltaE0)/dEdq + qResTemp;
    end
end
qR2 = -qR1;
qR1 = qR1 + bzIdx * 2;
qR2 = qR2 + bzIdx * 2;
if abs(qR - qR1) < abs(qR - qR2)
    qR = qR1;
else
    qR = qR2;
end
qREnd = 2 - qR;

%% Compute dressed energy
E = E * 2 * pi;
loopSize = (1 - qR);
tTotal = hbar * loopSize * kL / F;
q2 = qR : dq : qREnd;
q2mod = mod(q2+1,2)-1;
[~,qIdx] = min(abs(q' - q2mod));
Omegaq = Omega(qIdx).';
t = linspace(0,tTotal,numel(q2));
if tTotal < tPulse
    driveWindow = 1;
    energyWindow = 1;
else
    tHold = tTotal - tPulse;
    driveWindow = (t>=0 & t<=(tPulse/2)) .* ...
        ((- (t-(tPulse/2-tRamp))./(tRamp) .* (t>=(tPulse/2-tRamp)) + 1) .*...
        1) + ...
        (t>=(tHold+tPulse/2) & t<=(tTotal)) .* ...
        ((((t-tHold-tPulse/2)./(tRamp)-1) .* (t<=(tHold+tPulse/2+tRamp)) + 1) .*...
        1);
    energyWindow = t < tPulse/2 | t>(tHold + tPulse/2);
end
Omegat = Omegaq .* driveWindow;
dE = E(2,:) - E(1,:) - 2 * pi * freq;
dEt = dE(qIdx);
dEtDressed  = sqrt(dEt.^2 + Omegat.^2) .* energyWindow;
if mod(qR+1,2) - 1 < 0
    dEtDressed = -dEtDressed;
end
dEtDiabatic = dEt .* (~energyWindow);
phi = trapz(q2,dEtDressed + dEtDiabatic);
end