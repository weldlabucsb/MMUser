%% MRC
figure
hold on

t = readtable("C:\Users\WOODHOUSE\Documents\BeamStabil\Data\BeamStab_2025-04-09T11-58-26.csv");
t0 = t.ms * 1e-3;
t0 = t0 - t0(1);
plot(t0,t.RY2_V_ - mean(t.RY2_V_))
disp(std(t.RY2_V_))


t = readtable("C:\Users\WOODHOUSE\Documents\BeamStabil\Data\BeamStab_2025-04-09T12-07-38.csv");
t0 = t.ms * 1e-3;
t0 = t0 - t0(1);
plot(t0(t0>50),t.RY2_V_(t0>50) - mean(t.RY2_V_(t0>50)))
disp(std(t.RY2_V_(t0>50)))

t = readtable("C:\Users\WOODHOUSE\Documents\BeamStabil\Data\BeamStab_2025-04-09T12-19-03.csv");
t0 = t.ms * 1e-3;
t0 = t0 - t0(1);
plot(t0,t.RY2_V_ - mean(t.RY2_V_))
disp(std(t.RY2_V_))

t = readtable("C:\Users\WOODHOUSE\Documents\BeamStabil\Data\BeamStab_2025-04-09T12-34-17.csv");
t0 = t.ms * 1e-3;
t0 = t0 - t0(1);
plot(t0,t.RY2_V_ - mean(t.RY2_V_))
disp(std(t.RY2_V_))

legend("high power","low power","low power with power PID","even higher power")
xlabel("Time [s]")
ylabel("Piezo Position [V]")
render