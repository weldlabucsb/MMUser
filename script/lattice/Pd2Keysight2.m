function keysightVoltage = Pd2Keysight2(pdVoltage)
    load LatticeCalib.mat
    keysightVoltage = slmeval(pdVoltage,KP2Pd2Keysight);
end