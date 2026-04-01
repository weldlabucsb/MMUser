clear; clc;
close all

%% Parameters
% Hardware parameters
mainAwgAddress = "TCPIP0::172.16.0.3::inst0::INSTR";
pulseAwgAddress = "TCPIP0::172.16.0.4::inst0::INSTR";
scopeAddress = "TCPIP0::172.16.0.6::inst0::INSTR";
voltageRange = [-1,0.8]; % keysight output voltage range
awgSr = 20e6; % keysight sampling rate
mlSr = 20e6;
scopeNSample = 1e6;

% Closed-Loop parameters
maxIter        = 50;     % Maximum number of outer DAgger loops
batchSize       = 5;      % Number of random target sine waves per loop
errorThreshold  = 0.01;   % Acceptable average RMSE (e.g., 10 mV)
consecutiveGood = 0;      % Counter for convergence tracking

% Waveform parameters
maxFreq = 2.4e6;
minFreq = 100e3;
maxAmp1 = 0.5;
maxAmp2 = 1;
duration = 2e-3;
beta = 0.97; % reduction factor of amp mod at the maximal frequency

scopeSr = scopeNSample/duration;

%% Device settings
% Scope
scope = SiglentSDS2104XPlus(scopeAddress);
scope.Duration = duration;
scope.IsEnabled = [true,true,false,false];
scope.TriggerSource = "External";
scope.TriggerLevel = 0.3;
scope.VerticalRange = [0.6,1.2,2,2];
scope.VerticalOffset= [-0.3+0.01,-0.6+0.01,0,0];
% scope.VerticalRange = [2,2,2,2];
% scope.VerticalOffset= [0,0,0,0];
scope.NSample = scopeNSample;
scope.connect
scope.set
scope.startFromEdge

% Pulse AWG
pulseAwg = Keysight33500B(pulseAwgAddress);
pulseAwg.SamplingRate = [1000,pulseAwg.SamplingRateLimit/10];
pulseAwg.TriggerSource(2) = "Software";
pulseAwg.IsOutput = [false,true];
pulseAwg.OutputMode = ["Normal","Normal"];
pulseWf = WaveformList("pulse",waveformOrigin = { ...
    ConstantWave(duration = 5e-6, offset =3)...
    });
pulseAwg.WaveformList = {[],pulseWf};
pulseAwg.OutputLoad(2) = "Infinity";
pulseAwg.connect
pulseAwg.set
pulseAwg.upload

% Main AWG
mainAwg = Keysight33600A(mainAwgAddress);
mainAwg.SamplingRate = [awgSr,awgSr];
mainAwg.TriggerSource = ["External","External"];
mainAwg.IsOutput = [true,true];
mainAwg.OutputMode = ["Normal","Normal"];
mainAwg.OutputLoad = ["Infinity","Infinity"];
mainAwg.Offset = [-1,-1];
mainAwg.connect
mainAwg.set

%% Initialize master dataset cell arrays (1xN sequences)
xDataset1 = {}; % Input: Measured Scope Voltage (Optical Reality), KP1
yDataset1 = {}; % Target: Applied AWG Voltage (Control Signal), KP1
xDataset2 = {}; % Input: Measured Scope Voltage (Optical Reality), KP2
yDataset2 = {}; % Target: Applied AWG Voltage (Control Signal), KP2

%% Baseline chirp
disp('Gathering initial seed data (Chirp)...');

% Generate a broad chirp to teach basic physics
wf = LinearFrequencyRamp( ...
    duration = duration, ...
    amplitude= voltageRange(2)-voltageRange(1), ...
    offset   = mean(voltageRange)/2, ...
    startFrequency = 100e3,...
    stopFrequency = maxFreq,...
    samplingRate = awgSr ...
    );
wfl = WaveformList("chirp",waveformOrigin = {wf});

% Execute hardware functions
sendWaveform(pulseAwg,mainAwg,{wfl,wfl});
pause(0.01)
scopeRaw = readScope(scope);

% Align time delay, downsample, and store
[scopeMl1, awgMl1,delay1] = preprocessData(scopeRaw(1,:), wf.Sample, scopeSr, awgSr, mlSr);
[amp1,offset1] = readAmpOffset(scopeMl1,1000);
xDataset1{end+1} = [scopeMl1;amp1;offset1];
yDataset1{end+1} = realWf2MlWf(awgMl1(1,:),voltageRange);

[scopeMl2, awgMl2,delay2] = preprocessData(scopeRaw(2,:), wf.Sample, scopeSr, awgSr, mlSr);
[amp2,offset2] = readAmpOffset(scopeMl2,1000);
xDataset2{end+1} = [scopeMl2;amp2;offset2];
yDataset2{end+1} = realWf2MlWf(awgMl2,voltageRange);


%% The "seed" data (Iteration 0)
disp('Gathering initial seed data (Chirp)...');
nOffset = 10;
offsetList = linspace(voltageRange(1) + 0.5, voltageRange(2) - 0.1,nOffset);

for ii = 1:nOffset
    pause(0.2)
amp = min(abs(offsetList(ii)-voltageRange)) * 2;
% Generate a broad chirp to teach basic physics
wflAM = WaveformList("AM",samplingRate=awgSr,waveformOrigin={...
SineWave(...
amplitude=amp,...
offset = amp/2,...
frequency=5e3,...
duration=duration)...    
});
wflFM = WaveformList("FM",samplingRate=awgSr,waveformOrigin={...
LinearRamp(startValue=100e3,stopValue=maxFreq,duration=duration,rampTime=duration)...    
});

wf = SineWaveModulated( ...
    duration = duration, ...
    amplitude= 0, ...
    frequency=0.1, ...
    offset   = offsetList(ii), ...
    samplingRate = awgSr, ...
    amplitudeModulation=wflAM,...
    frequencyModulation=wflFM...
    );
wfl = WaveformList("chirp",waveformOrigin = {wf},samplingRate=awgSr);

% Execute hardware functions
sendWaveform(pulseAwg,mainAwg,{wfl,wfl});
pause(0.1)
scopeRaw = readScope(scope);

% Align time delay, downsample, and store
[scopeMl1, awgMl1] = preprocessData(scopeRaw(1,:), wf.Sample, scopeSr, awgSr, mlSr,delay1);
[amp1,offset1] = readAmpOffset(scopeMl1);
xDataset1{end+1} = [scopeMl1;amp1;offset1];
yDataset1{end+1} = realWf2MlWf(awgMl1(1,:),voltageRange);

[scopeMl2, awgMl2] = preprocessData(scopeRaw(2,:), wf.Sample, scopeSr, awgSr, mlSr,delay2);
[amp2,offset2] = readAmpOffset(scopeMl2);
xDataset2{end+1} = [scopeMl2;amp2;offset2];
yDataset2{end+1} = realWf2MlWf(awgMl2,voltageRange);
end

%% More seed

% for b = 1:10
%     % a. Generate a random target optical sine wave
%     targetFreq1 = randi([minFreq, maxFreq]); % 100 kHz to 1.5 MHz
%     targetFreq2 = randi([minFreq, maxFreq]); % 100 kHz to 1.5 MHz
%     targetOffset1 = rand() * maxAmp1 / 2;    % Ensure signal stays positive
%     targetOffset2 = rand() * maxAmp2 / 2;    % Ensure signal stays positive
%     targetAmp1 = min(0.01 + (maxAmp1 * rand()),targetOffset1);   % Scale to your expected PD voltage
%     targetAmp2 = min(0.01 + (maxAmp2 * rand()),targetOffset2);   % Scale to your expected PD voltage
% 
%     wf1 = SineWave(...
%         frequency=targetFreq1,...
%         amplitude=targetAmp1,...
%         offset=targetOffset1,...
%         samplingRate=awgSr,...
%         duration=duration,...
%         phase = 3 * pi / 2 ...
%         );
%     wf2 = SineWave(...
%         frequency=targetFreq2,...
%         amplitude=targetAmp2,...
%         offset=targetOffset2,...
%         samplingRate=awgSr,...
%         duration=duration,...
%         phase = 3 * pi / 2 ...
%         );
% 
%     % b. Predict the raw AWG voltage (Bounded to +/- 1V by tanhLayer)
%     awgwfl1 = WaveformList("1",waveformOrigin={wf1},samplingRate=awgSr);
%     awgwfl1.TransformFunction = "Pd2Keysight1";
%     awgwfl2 = WaveformList("1",waveformOrigin={wf2},samplingRate=awgSr);
%     awgwfl2.TransformFunction = "Pd2Keysight2";
% 
%     % % c. PHYSICS CONSTRAINT 2: Enforce Strict Periodicity
%     % samples_per_period = round(scopeSr / targetFreq1);
%     %
%     % % Extract one period from the steady-state portion (skip first 20%)
%     % steady_start = max(1, round(0.2 * length(predictedAwg)));
%     % one_period = predictedAwg(steady_start : (steady_start + samples_per_period - 1));
%     %
%     % % Tile (repeat) it to fill the expected duration
%     % num_repeats = ceil(length(ideal_scope_target) / samples_per_period);
%     % periodic_awg_ml = repmat(one_period, 1, num_repeats);
%     % periodic_awg_ml = periodic_awg_ml(1:length(ideal_scope_target));
% 
%     % d. Upsample and Execute on Hardware
%     % predicted_awg_hw = resample(periodic_awg_ml, awgSr, scopeSr);
%     pause(0.3)
%     sendWaveform(pulseAwg, mainAwg, {awgwfl1,awgwfl2})
%     pause(0.1)
% 
% 
%     % e. Process the resulting physical reality
%     % We pair the actual scope measurement with the PERIODIC awg signal
%     scopeRaw = readScope(scope);
% 
%     % Align time delay, downsample, and store
%     [scopeMl1, awgMl1] = preprocessData(scopeRaw(1,:), awgwfl1.Sample, scopeSr, awgSr, mlSr,delay1);
%     xDataset1{end+1} = scopeMl1;
%     yDataset1{end+1} = realWf2MlWf(awgMl1(1,:),voltageRange);
% 
%     [scopeMl2, awgMl2] = preprocessData(scopeRaw(2,:), awgwfl1.Sample, scopeSr, awgSr, mlSr,delay2);
%     xDataset2{end+1} = scopeMl2;
%     yDataset2{end+1} = realWf2MlWf(awgMl2,voltageRange);
% 
% end


%% Define the Neural Network
numFeatures = 3;     % 1 Channel (Target Optical Amplitude)
numResponses = 1;    % 1 Channel (Required AWG Voltage)
numHiddenUnits = 50; % Number of LSTM memory cells

layers = [ ...
    sequenceInputLayer(numFeatures)
    lstmLayer(numHiddenUnits, 'OutputMode', 'sequence')
    fullyConnectedLayer(numResponses)
    tanhLayer
    regressionLayer];

% Keep epochs low because we continuously re-train in the loop
options = trainingOptions('adam', ...
    'MaxEpochs', 50, ...
    'GradientThreshold', 1, ...
    'InitialLearnRate', 0.005, ...
    'Verbose', 0, ...
    'Plots', 'none',...
    'ExecutionEnvironment','cpu');

disp('Training initial baseline model...');
net1 = trainNetwork(xDataset1, yDataset1, layers, options);
net2 = trainNetwork(xDataset2, yDataset2, layers, options);

%% The Main Closed-Loop (DAgger) Optimization
disp('Starting closed-loop optimization with periodicity constraints...');

for iter = 1:maxIter
    fprintf('\n--- Iteration %d / %d ---\n', iter, maxIter);
    batchError1 = 0;
    batchError2 = 0;

    for b = 1:batchSize
        % a. Generate a random target optical sine wave
        targetFreq1 = randi([minFreq, maxFreq]); % 100 kHz to 1.5 MHz
        targetFreq2 = randi([minFreq, maxFreq]); % 100 kHz to 1.5 MHz
        targetOffset1 = max(rand() * maxAmp1 / 2, 0.01);    % Ensure signal stays positive
        targetOffset2 = max(rand() * maxAmp2 / 2, 0.01);    % Ensure signal stays positive
        targetAmp1 = min(0.01 + (maxAmp1 * rand()),targetOffset1 * 2) * beta;   % Scale to your expected PD voltage
        targetAmp2 = min(0.01 + (maxAmp2 * rand()),targetOffset2 * 2) * beta;   % Scale to your expected PD voltage

        wf1 = SineWave(...
            frequency=targetFreq1,...
            amplitude=targetAmp1,...
            offset=targetOffset1,...
            samplingRate=awgSr,...
            duration=duration,...
            phase = 3 * pi / 2 ...
            );
        wf2 = SineWave(...
            frequency=targetFreq2,...
            amplitude=targetAmp2,...
            offset=targetOffset2,...
            samplingRate=awgSr,...
            duration=duration,...
            phase = 3 * pi / 2 ...
            );

        % b. Predict the raw AWG voltage (Bounded to +/- 1V by tanhLayer)
        tList = wf1.StartTime : wf1.TimeStep : wf1.EndTime;
        ns = numel(wf1.Sample);
        predictedAwg1 = mlWf2realWf(predict(net1, [wf1.Sample;ones(1,ns)*targetAmp1/2;ones(1,ns)*targetOffset1]),voltageRange);
        predictedAwg2 = mlWf2realWf(predict(net2, [wf2.Sample;ones(1,ns)*targetAmp2/2;ones(1,ns)*targetOffset2]),voltageRange);
        awgWf1 = InterpolatedWaveform(duration = duration,samplingRate=awgSr);
        awgWf1.TimeData = tList;
        awgWf1.SampleData = predictedAwg1;
        awgWf2 = InterpolatedWaveform(duration = duration,samplingRate=awgSr);
        awgWf2.TimeData = tList;
        awgWf2.SampleData = predictedAwg2;
        awgwfl1 = WaveformList("1",waveformOrigin={awgWf1},samplingRate=awgSr);
        awgwfl2 = WaveformList("1",waveformOrigin={awgWf2},samplingRate=awgSr);

        % % c. PHYSICS CONSTRAINT 2: Enforce Strict Periodicity
        % samples_per_period = round(scopeSr / targetFreq1);
        %
        % % Extract one period from the steady-state portion (skip first 20%)
        % steady_start = max(1, round(0.2 * length(predictedAwg)));
        % one_period = predictedAwg(steady_start : (steady_start + samples_per_period - 1));
        %
        % % Tile (repeat) it to fill the expected duration
        % num_repeats = ceil(length(ideal_scope_target) / samples_per_period);
        % periodic_awg_ml = repmat(one_period, 1, num_repeats);
        % periodic_awg_ml = periodic_awg_ml(1:length(ideal_scope_target));

        % d. Upsample and Execute on Hardware
        % predicted_awg_hw = resample(periodic_awg_ml, awgSr, scopeSr);
        sendWaveform(pulseAwg, mainAwg, {awgwfl1,awgwfl2})
        pause(0.2)

        % e. Process the resulting physical reality
        % We pair the actual scope measurement with the PERIODIC awg signal
        scopeRaw = readScope(scope);

        % Align time delay, downsample, and store
        [scopeMl1, awgMl1] = preprocessData(scopeRaw(1,:), awgwfl1.Sample, scopeSr, awgSr, mlSr,delay1);
        [amp1,offset1] = readAmpOffset(scopeMl1);
        disp("ch1 amp:")
        disp([mean(amp1),mean(targetAmp1)/2;])
        disp("ch1 offset:")
        disp([mean(offset1),mean(targetOffset1)])
        xDataset1{end+1} = [scopeMl1;amp1;offset1];
        yDataset1{end+1} = realWf2MlWf(awgMl1(1,:),voltageRange);

        [scopeMl2, awgMl2] = preprocessData(scopeRaw(2,:), awgwfl2.Sample, scopeSr, awgSr, mlSr,delay2);
        [amp2,offset2] = readAmpOffset(scopeMl2);
        disp("ch2 amp:")
        disp([mean(amp2),mean(targetAmp2)/2;])
        disp("ch2 offset:")
        disp([mean(offset2),mean(targetOffset2)])
        xDataset2{end+1} = [scopeMl2;amp2;offset2];
        yDataset2{end+1} = realWf2MlWf(awgMl2,voltageRange);

        % Calculate RMSE for convergence tracking
        wf1s = wf1.Sample(20:end);
        min_len = min(length(scopeMl1), length(wf1s));
        y_true = scopeMl1(1:min_len);
        y_pred = wf1s(1:min_len);
        waveform_rmse = sqrt(mean((y_true - y_pred).^2));
        batchError1 = batchError1 + waveform_rmse;

        wf2s = wf2.Sample(20:end);
        min_len = min(length(scopeMl2), length(wf2s));
        y_true = scopeMl2(1:min_len);
        y_pred = wf2s(1:min_len);
        waveform_rmse = sqrt(mean((y_true - y_pred).^2));
        batchError2 = batchError2 + waveform_rmse;
    end

    % f. Convergence Check
    avg_batch_rmse = (batchError1+batchError2) / batchSize;
    fprintf('Average RMSE for Batch %d: %.4f V\n', iter, avg_batch_rmse);

    if avg_batch_rmse < errorThreshold
        consecutiveGood = consecutiveGood + 1;
        if consecutiveGood >= 3
            disp('Network has converged to the error threshold! Stopping.');
            break; % Exit loop
        end
    else
        consecutiveGood = 0; % Reset counter if error spikes
    end

    % g. Re-train the network on the expanded, constrained dataset
    disp('Updating network with new hardware reality...');
    net1 = trainNetwork(xDataset1, yDataset1, net1.Layers, options);
    net2 = trainNetwork(xDataset2, yDataset2, net2.Layers, options);
end

%% 5. Save the Final Model
disp('Saving the converged model...');
save('Predistortion_Model.mat', 'net1', 'net2', 'awgSr', 'scopeSr', 'duration');
disp('Done! You can now use this model for instant, periodic waveform generation.');

% =========================================================================
% Helper & Hardware Functions
% =========================================================================

function [scopeMl, awgMl,delay] = preprocessData(scopeRaw, awgRaw, scopeSr, awgSr, mlSr,delay)
ignoredPoints = 20;
awgUp = resample(awgRaw, scopeSr, awgSr);
if nargin == 5
    delay = finddelay(awgUp, scopeRaw);
end

if delay > 0
    % Scope is delayed relative to AWG (Expected physical reality)
    scopeAligned = scopeRaw(delay+1:end);
    awgAligned = awgRaw;
    % else
    %     % AWG appears delayed (Usually only happens if scope trigger is late)
    %     scopeAligned = scopeMl(1:end+delay);
    %     awgAligned = awgMl(-delay+1:end);
end

scopeMl = resample(scopeAligned, mlSr, scopeSr);
awgMl   = resample(awgAligned, mlSr, awgSr);

% Ensure they match exactly in length
minLen = min(length(scopeMl), length(awgMl));
scopeMl = scopeMl(ignoredPoints:minLen-ignoredPoints);
awgMl = awgMl(ignoredPoints:minLen-ignoredPoints);

% Ensure 1xN row vectors for the Deep Learning Toolbox
scopeMl = reshape(scopeMl, 1, []);
awgMl = reshape(awgMl, 1, []);
end

function sendWaveform(pulseAwg, mainAwg, wfl)
% INSERT YOUR KEYSIGHT AWG SCPI / VISA CODE HERE
% E.g., writeline(awg_obj, '*RST'); ... load waveform ... writeline(awg_obj, '*TRG');
mainAwg.WaveformList = wfl;
mainAwg.set
mainAwg.upload
pulseAwg.trigger
end

function scopeData = readScope(scope)
% INSERT YOUR SCOPE TRIGGERING & READOUT CODE HERE
% Wait for trigger, pull the waveform, and return it as a 1D array.

% --- DUMMY RESPONSE FOR SCRIPT TESTING ---
scope.read
scopeData = scope.Sample;
end

function wfRescaled = realWf2MlWf(wf,voltageRange)
wfRescaled = 2 * (wf - voltageRange(1)) ./ (voltageRange(2) - voltageRange(1)) - 1;
end

function wfRescaled = mlWf2realWf(wf,voltageRange)
wfRescaled = ((wf + 1) * (voltageRange(2) - voltageRange(1)) / 2) + voltageRange(1);
end

function [amp,offset] = readAmpOffset(scopeTrace,windowSize)
if nargin == 1
    windowSize = 400;
end
offset = movmean(scopeTrace, windowSize);
centeredScope = scopeTrace - offset;
[amp, ~] = envelope(centeredScope, windowSize, 'peak');
end