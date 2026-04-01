function keysightVoltage = Depth2Keysight1(depthEr)
    load LatticeCalib.mat
    keysightVoltage = slmeval(KP1Depth2Pd(depthEr),KP1Pd2Keysight);
end