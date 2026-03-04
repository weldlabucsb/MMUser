function keysightVoltage = Pd2Keysight2(pdVoltage)
    load ScopeLatticeCalib.mat
    keysightVoltage = slmeval(pdVoltage,KP2);
end