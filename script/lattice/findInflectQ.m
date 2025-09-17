close all
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
bandIndx = 2;
dq = 1e-4;
v0List = 4:0.01:20;
dEdq3 = zeros(size(v0List));
dEdq2 = dEdq3;
dEdq1 = dEdq3;
qI = dEdq3;
parfor ii = 1:numel(v0List)
    [dEdq3(ii),dEdq2(ii),dEdq1(ii),qI(ii)] = computeBandDerivative3(v0List(ii),1e-3,3);
end
figure
hold on
xlabel('$V_0$ [$E_{\mathrm{R}}$]','Interpreter','latex')
yyaxis left
l = plot(v0List,dEdq3);
ylabel('$d^3E/dq^3$ [$E_{\mathrm{R}}/\hbar^3 k_{\rm L}^3$]','Interpreter','latex');
yyaxis right
plot(v0List,dEdq1)
ylabel('$dE/dq$ [$E_{\mathrm{R}}/\hbar k_{\rm L}$]','Interpreter','latex')
render
co = colororder;
l.Color = co(1,:);
hold off
xlim([4,20])

figure
plot(v0List,qI)
xlabel('$V_0$ [$E_{\mathrm{R}}$]','Interpreter','latex')
ylabel('$q_I$ [$\hbar k_{\rm L}$]','Interpreter','latex')
render
xlim([4,20])


%% Compute inflect point

function [dEdq3,dEdq2,dEdq1,qI] = computeBandDerivative3(v0,dq,n)
    q = 0:dq:1;
    E = computeBand(v0,q,n);
    dEdq1 = gradient(E,dq);
    dEdq2 = gradient(dEdq1,dq);
    [~,qIdx] = min(abs(dEdq2));
    dEdq3 = gradient(dEdq2,dq);
    dEdq3 = abs(dEdq3(qIdx));
    dEdq2 = dEdq2(qIdx);
    dEdq1 = abs(dEdq1(qIdx));
    qI = q(qIdx);
end

function E = computeBand(v0,q,n)
nMax = 55;
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