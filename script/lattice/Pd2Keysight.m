function keysightVoltage = Pd2Keysight(pdVoltage,latticeIdx)
    load LatticeCalib.mat
    if latticeIdx == 1
        keysightVoltage = slmeval(pdVoltage,KP1Pd2Keysight);
    else
        keysightVoltage = slmeval(pdVoltage,KP2Pd2Keysight);
    end
end