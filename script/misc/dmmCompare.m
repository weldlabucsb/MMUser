watchFolder = "C:\Users\WOODHOUSE\Documents\KickStart\Projects";
file = ["DMM-1 Run 122 2025-01-23T14.06.02.csv","DMM-1 Run 120 2025-01-23T14.03.56.csv","DMM-1 Run 106 2025-01-23T13.44.42.csv"];
% file2 = "DMM-1 Run 120 2025-01-23T14.03.56.csv";
delay = 0.2;
duration = 1;
f = cell(1,3);
P = cell(1,3);
% figure
% hold on
for ii = 1:3
    dataPath = fullfile(watchFolder,file(ii));
    data = readtable(dataPath);
    t = data.DMM_1Time_s_(1:end-10);
    V = data.DMM_1MX_b_X_(1:end-10);
    idx = find(t>delay & t<duration);
    if mod(numel(idx),2)~=0
        idx = [idx(1)-1,idx];
    end
    L = numel(idx);
    T = t(2) - t(1);
    t = (0:L-1)*T;
    V = V(idx);
    Y = fft(V);
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f{ii} = (1/T)*(0:(L/2))/L;
    P{ii} = abs(P1).^2;
end
loglog(f{1},P{1},f{2},P{2},f{3},P{3})
xlabel("Frequency [Hz]")
ylabel("FFT of the error signal")
legend("With PID Iso-Amp shorted","No PID","With PID Iso-Amp working")
render