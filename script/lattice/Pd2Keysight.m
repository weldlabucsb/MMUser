function keysightVoltage = Pd2Keysight(pdVoltage,latticeIdx)
    load ScopeLatticeCalib.mat
    if latticeIdx == 1
        keysightVoltage = slmeval(pdVoltage,KP1);
    else
        keysightVoltage = slmeval(pdVoltage,KP2);
    end
end