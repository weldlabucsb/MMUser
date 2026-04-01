function keysightVoltage = Pd2Keysight1(pdVoltage)
    load LatticeCalib.mat
    keysightVoltage = slmeval(pdVoltage,KP1Pd2Keysight);
end