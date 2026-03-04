function keysightVoltage = Pd2Keysight1(pdVoltage)
    load ScopeLatticeCalib.mat
    keysightVoltage = slmeval(pdVoltage,KP1);
end