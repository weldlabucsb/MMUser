%% Pd to Keysight
% trialNumberPd2Keysight = 8639; % 100% moglabs mod depth
% trialNumberPd2Keysight = 8579; % 150% moglabs mod depth
% trialNumberPd2Keysight = 8718; % 200% moglabs mod depth, keysight
% trialNumberPd2Keysight = 9009; % 200% moglabs mod depth, spectrum
% trialNumberPd2Keysight = 9000; % 200% moglabs mod depth, spectrum
%trialNumberPd2Keysight = 9164; % 200% moglabs mod depth, spectrum
% trialNumberPd2Keysight = 9241; % 200% moglabs mod depth, spectrum
% trialNumberPd2Keysight = 9625; % 200% moglabs mod depth, spectrum
trialNumberPd2Keysight = 10017; % 200% moglabs mod depth, spectrum

sName = "LatticeScope";
becExp = loadBecExp(trialNumberPd2Keysight);
s = loadVar(fullfile(becExp.HardwareLogPath,becExp.DataPrefix + "_" + num2str(1)) + "_" + sName + ".mat");
rampTime = becExp.HardwareData.hw_KPRamp1Time;
scopeDuration = s.Duration;
nSample = s.NSample;
idx = s.TimeList >= (scopeDuration/2) & s.TimeList <= (scopeDuration/2 + rampTime);
% V = linspace(-1,1,numel(find(idx))); % 100% moglabs mod depth
% V = linspace(-0.65,1,numel(find(idx))); % 150% moglabs mod depth
V = linspace(-0.5,0.55,numel(find(idx))); % 200% moglabs mod depth
KP1Pd = s.Sample(1,idx);
KP2Pd = s.Sample(2,idx);
KP1Pd2Keysight = slmengine(KP1Pd,V, 'plot', 'on', 'increasing', 'on');
KP2Pd2Keysight = slmengine(KP2Pd,V, 'plot', 'on', 'increasing', 'on');


%% Depth to Pd
trialNumberKP1Kd = 10114;
trialNumberKP2Kd = 10115;

becExp = loadBecExp(trialNumberKP1Kd);
k = becExp.KapitzaDirac.DepthOverAmplitude;
off = mean(becExp.KapitzaDirac.PulseOffset);
KP1Depth2Pd = @(x) x./k + off;
KP1Pd2Depth = @(v) (v - off) * k; %new function to handle am spec calcs etc. 

becExp = loadBecExp(trialNumberKP2Kd);
k = becExp.KapitzaDirac.DepthOverAmplitude;
off = mean(becExp.KapitzaDirac.PulseOffset);
KP2Depth2Pd = @(x) x./k + off;
KP2Pd2Depth = @(v) (v - off) * k; %new function to handle am spec calcs etc. 

%% AM spectroscopy calculations -- added 7.15.2026 by snh
addpath('B:\_Li\Machine Code\LatticeCode\');

% =========== User Settings ============
trialNumberKP1Am = 10094; 
trialNumberKP2Am = 10095; 

amSpecFreqKP1 = 620;    %kHz
amSpecFreqKP2 = 1018;      %kHz


% --- KP1 Processing ---
becExp1 = loadBecExp(trialNumberKP1Am);
[amMeanVKp1, validCount1] = getAverageValidScopeVoltage(becExp1, sName, 1); 
kdScopeDepthKP1 = KP1Pd2Depth(amMeanVKp1);
%s1 = getValidScopeTrace(becExp1, sName, 1);        %old method
%amMeanVKp1 = mean(s1.Sample(1, 1:fix(end/5)));
%kdScopeDepthKP1 = KP1Pd2Depth(amMeanVKp1);

minDepth1 = becExp1.HardwareData.hw_KP1RampDepthSpec(1) - 25;
maxDepth1 = becExp1.HardwareData.hw_KP1RampDepthSpec(1) + 25;
errorFunction1 = @(depth) findTransitionFrequency_V2(depth, 1, 3, 0) - amSpecFreqKP1; 
amSpecDepthKP1 = fzero(errorFunction1, [minDepth1, maxDepth1]);
amKdFactorKP1 = amSpecDepthKP1 / kdScopeDepthKP1 ;

fprintf('-------- KP1 Results --------\n');
fprintf('Averaged %d valid traces.\n', validCount1);
fprintf('Closest match for f=%.0f kHz is %.4f Er\n', amSpecFreqKP1, amSpecDepthKP1);
fprintf('Mean voltage of %.4fV gives %.4f Er using KD.\n', ...
    amMeanVKp1, kdScopeDepthKP1);
fprintf('Resulting correction factor for KP1 = %.6f\n\n', amKdFactorKP1);

fprintf('-------- Loading KP2... --------\n');

% --- KP2 Processing ---
becExp2 = loadBecExp(trialNumberKP2Am);
[amMeanVKp2, validCount2] = getAverageValidScopeVoltage(becExp2, sName, 1); % the last entry needs to be 2 for older runs (pre-july 29th)
kdScopeDepthKP2 = KP2Pd2Depth(amMeanVKp2);
%s2 = getValidScopeTrace(becExp2, sName, 2); 
%amMeanVKp2 = mean(s2.Sample(2, 1:fix(end/5)));
%kdScopeDepthKP2 = KP2Pd2Depth(amMeanVKp2);

initialDepthGuess2 = becExp2.HardwareData.hw_KP1RampDepthSpec(1); 
errorFunction2 = @(depth) findTransitionFrequency_V2(depth, 1, 3, 0) - amSpecFreqKP2; 
amSpecDepthKP2 = fzero(errorFunction2, initialDepthGuess2);
amKdFactorKP2 = amSpecDepthKP2 / kdScopeDepthKP2  ;

fprintf('---------- KP2 Results ----------\n');
fprintf('Averaged %d valid traces.\n', validCount2);
fprintf('Closest match for f=%.0f kHz is %.4f Er\n', amSpecFreqKP2, amSpecDepthKP2);
fprintf('Mean voltage of %.4fV gives %.4f Er using KD. \n', ...
    amMeanVKp2, kdScopeDepthKP2);
fprintf('Resulting correction factor for KP2 = %.6f\n',amKdFactorKP2);
fprintf('---------- Complete. ----------\n');
	
%% Save
%save("C:\Users\WOODHOUSE\Documents\MMUser\script\lattice\LatticeCalib.mat",...
 %  "KP1Pd2Keysight","KP2Pd2Keysight","KP1Depth2Pd","KP2Depth2Pd")
	
%% --- Helper Function --- (new version, takes the avg of traces as long as not mistriggered)
function [avgMeanVoltage, validCount] = getAverageValidScopeVoltage(becExp, sName, Ch)
    runNum = 1;
    maxRuns = 40; 
    validMeans = []; % Array to store mean voltages of non-mistriggered runs

    while runNum <= maxRuns
        filePath = fullfile(becExp.HardwareLogPath, becExp.DataPrefix + "_" + num2str(runNum) + "_" + sName + ".mat");
 
        if exist(filePath, 'file')
            s = loadVar(filePath);
            
            % just taking the first segment (first 1/5th)
            traceSegment = s.Sample(Ch, 1:fix(end/5));
            currentMean = mean(traceSegment);
            
            if currentMean >= 0.0007
                validMeans(end + 1) = currentMean; %#ok<AGROW>
            else
                warning('Run %d mistriggered (%.4fV), skipping...', runNum, currentMean);
            end
        end
        runNum = runNum + 1;
    end

    validCount = length(validMeans);
    if validCount > 0
        % Calculate the overall average from the collected segment means
        avgMeanVoltage = mean(validMeans);
    else
        error('Could not find any valid scope traces within %d runs.', maxRuns);
    end
end
%% --- Helper Function --- (old version which assumed mean V was consistent across runs. really, scope induced noise causes ~10mV jumps)
function s = getValidScopeTrace(becExp, sName, Ch)
    runNum = 1;
    maxRuns = 30; % Added a limit to prevent infinite loops
    while runNum <= maxRuns
        filePath = fullfile(becExp.HardwareLogPath, becExp.DataPrefix + "_" + num2str(runNum) + "_" + sName + ".mat");
 
        if exist(filePath, 'file')
            s = loadVar(filePath);
            if mean(s.Sample(Ch, 1:fix(end/5))) >= 0.0007
                return; 
            end
            warning('Run %d mistriggered (%.4fV), trying next run...', runNum, mean(s.Sample(Ch, 1:fix(end/5))));
        else
            %warning('File for run %d not found.', runNum);
        end
        runNum = runNum + 1;
    end
    error('Could not find a valid scope trace within %d runs.', maxRuns);
end