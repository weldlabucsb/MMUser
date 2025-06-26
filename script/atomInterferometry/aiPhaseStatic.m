function phi = aiPhaseStatic(V0,qR,dq)
%AIPHASESTATIC Summary of this function goes here
%   Only compute the dynamical phase
arguments
    V0 double
    qR double
    dq double
end
nMax = 55;
n = [2,3];
q = qR : dq : (2 - qR);
eList = computeBand(V0);
phi = trapz(q,diff(eList,1,1));
    function E = computeBand(v0)
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
end

