function keysightVoltage = Depth2Keysight2(depthEr)
    load LatticeCalib.mat
    keysightVoltage = slmeval(KP2Depth2Pd(depthEr),KP2Pd2Keysight);
end