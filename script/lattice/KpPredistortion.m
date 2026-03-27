classdef KpPredistortion < handle
    %KPPREDISTORTION Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Method = "LSTM"
        NChannel = 2
        RunIdx = 1
        IterationIdx = 1
        SamplingRateAwg = 20e6 % keysight sampling rate
        SamplingRateMl = 20e6 % Machine learning sampling rate
        NSampleScope = 1e6 % Number of samples on the scope
        SamplingRateScope = 1e9
        VoltageRange = [-1,0.8] % Keysight output voltage range
        PowerVoltageRange = [1,1.3] % Precilaser power PD voltage range
        FrequencyRange = [100e3,1.2e6] % Frequency range of modulation
        AmplitudeMaximum = [0.6, 1.1] % Maximum amplitude on the scope for KP1 and KP2
        ChirpDuration = 1e-3 % Duration of the chirp pulse
        SineDuration = 1e-3 % Duration of the sine pulse
        Beta = 0.8 % Reduction factor of AM modulation
        NIgnoredSample = 20 % Number of ignored samples at the beginning and the end
        IsIncludeAmpOffset = true % If we want to include amplitude and offset in the training
        IsNormalizeError = false % If we normalize the RMS error to the target offset
        IsCpu = true % If we use CPU to do training
        WindowSize = 400 % For calculating the amplitude and offset
        NOffset = 10 % Numbers of offset for pretraining data set
        NBatch = 5 % Numbers of runs per batch
        NIteration = 50     % Maximum number of outer DAgger loops
        ErrorThreshold  = 0.01;   % Acceptable average RMSE (e.g., 10 mV)
    end

    properties (SetAccess = public)
        ConsecutiveGood = 0;      % Counter for convergence tracking
        BatchError = [1;1];
        BatchErrorStd = [0;0];
        Scope
        PulseAwg
        MainAwg
        Delay
        Offset = [0,0];
        Dataset
        Network cell
        NetworkLayers
        NetworkOptions
    end

    properties (Constant)
        MainAwgAddress = "TCPIP0::172.16.0.3::inst0::INSTR"
        PulseAwgAddress = "TCPIP0::172.16.0.4::inst0::INSTR"
        ScopeAddress = "TCPIP0::172.16.0.6::inst0::INSTR"
    end

    methods
        function obj = KpPredistortion()
            %KPPREDISTORTION Construct an instance of this class
            %   Detailed explanation goes here
        end

        function setHardware(obj)
            %% Scope
            obj.Scope = SiglentSDS2104XPlus(obj.ScopeAddress);
            obj.Scope.Duration = obj.ChirpDuration;
            obj.Scope.IsEnabled = [true,true,true,false];
            obj.Scope.TriggerSource = "External";
            obj.Scope.TriggerLevel = 0.3;
            obj.Scope.VerticalRange = [0.6,1.2,1.5,2];
            obj.Scope.VerticalOffset= [-0.3+0.02,-0.6+0.02,-0.75 + .02,0];
            obj.Scope.NSample = obj.ChirpDuration * obj.SamplingRateScope;
            obj.Scope.connect
            obj.Scope.set
            obj.Scope.startFromEdge

            %% Pulse AWG
            obj.PulseAwg = Keysight33500B(obj.PulseAwgAddress);
            obj.PulseAwg.SamplingRate = [1000,obj.PulseAwg.SamplingRateLimit/10];
            obj.PulseAwg.TriggerSource(2) = "Software";
            obj.PulseAwg.IsOutput = [false,true];
            obj.PulseAwg.OutputMode = ["Normal","Normal"];
            pulseWf = WaveformList("pulse",waveformOrigin = { ...
                ConstantWave(duration = 5e-6, offset =3)...
                });
            obj.PulseAwg.WaveformList = {[],pulseWf};
            obj.PulseAwg.OutputLoad(2) = "Infinity";
            obj.PulseAwg.connect
            obj.PulseAwg.set
            obj.PulseAwg.upload

            %% Main AWG
            wfl = WaveformList("const",waveformOrigin = { ...
                ConstantWave(duration = 1e-3, offset = -1)...
                });
            obj.MainAwg = Keysight33600A(obj.MainAwgAddress);
            obj.MainAwg.WaveformList = {wfl,wfl};
            obj.MainAwg.SamplingRate = [obj.SamplingRateAwg,obj.SamplingRateAwg];
            obj.MainAwg.TriggerSource = ["External","External"];
            obj.MainAwg.IsOutput = [true,true];
            obj.MainAwg.OutputMode = ["Normal","Normal"];
            obj.MainAwg.OutputLoad = ["Infinity","Infinity"];
            obj.MainAwg.Offset = [-1,-1];
            obj.MainAwg.connect
            obj.MainAwg.set
            obj.MainAwg.upload

        end

        function initializeDataset(obj)
            s.X = {};
            s.Y = {};
            s.XTarget = {};
            s.LaserPower = [];
            s(2) = s;
            obj.Dataset = s;
            obj.RunIdx = 1;
            obj.IterationIdx = 1;
        end

        function measureOffset(obj)
            wfl = WaveformList("const",waveformOrigin = { ...
                ConstantWave(duration = 1e-3, offset = -1)...
                });
            obj.sendAndRead({wfl,wfl})
            pause(0.3)
            for ii = 1:obj.NChannel
                obj.Offset(ii) = mean(obj.Scope.Sample(ii,:));
            end
        end

        function getChirpData(obj)
            disp('Gathering initial seed data (Chirp)...');
            %% Generate a broad chirp to teach basic physics
            wf = LinearFrequencyRamp( ...
                duration = obj.ChirpDuration, ...
                amplitude= range(obj.VoltageRange), ...
                offset   = mean(obj.VoltageRange)/2, ...
                startFrequency = obj.FrequencyRange(1),...
                stopFrequency = obj.FrequencyRange(2),...
                samplingRate = obj.SamplingRateAwg ...
                );
            wfl = WaveformList("chirp",waveformOrigin = {wf});

            %% Execute hardware functions
            obj.sendAndRead({wfl,wfl})

            %% Align time delay, downsample, and store
            obj.processData([],true)
            obj.RunIdx = obj.RunIdx + 1;
        end

        function getAmpModChirpData(obj)
            nOffset = obj.NOffset;
            voltageRange = obj.VoltageRange;
            awgSr = obj.SamplingRateAwg;
            duration = obj.ChirpDuration;
            offsetList = linspace(voltageRange(1) + 0.5, voltageRange(2) - 0.1,nOffset);
            for jj = 1:nOffset
                disp("Gathering initial amp-mod seed data run" +jj + "...");
                pause(0.4)
                amp = min(abs(offsetList(jj)-voltageRange)) * 2;
                %% Generate a broad chirp to teach basic physics
                wflAM = WaveformList("AM",samplingRate=awgSr,waveformOrigin={...
                    SineWave(...
                    amplitude=amp,...
                    offset = amp/2,...
                    frequency=5e3,...
                    duration=duration)...
                    });
                wflFM = WaveformList("FM",samplingRate=awgSr,waveformOrigin={...
                    LinearRamp(...
                    startValue=obj.FrequencyRange(1),...
                    stopValue=obj.FrequencyRange(2),...
                    duration=duration,...
                    rampTime=duration)...
                    });

                wf = SineWaveModulated( ...
                    duration = duration, ...
                    amplitude= 0, ...
                    frequency=0.1, ...
                    offset   = offsetList(jj), ...
                    samplingRate = awgSr, ...
                    amplitudeModulation=wflAM,...
                    frequencyModulation=wflFM...
                    );
                wfl = WaveformList("chirp",waveformOrigin = {wf},samplingRate=awgSr);

                %% Execute hardware functions
                obj.sendAndRead({wfl,wfl});

                %% Align time delay, downsample, and store
                obj.processData([],false)
                obj.RunIdx = obj.RunIdx + 1;
            end
        end

        function pretrain(obj)
            switch obj.Method
                case "LSTM"
                    %% LSTM
                    if obj.IsIncludeAmpOffset
                        numFeatures = 3;     % 1 Channel (Target Optical Amplitude)
                    else
                        numFeatures = 1;
                    end
                    numResponses = 1;    % 1 Channel (Required AWG Voltage)
                    numHiddenUnits = 50; % Number of LSTM memory cells

                    obj.NetworkLayers = [ ...
                        sequenceInputLayer(numFeatures)
                        lstmLayer(numHiddenUnits, 'OutputMode', 'sequence')
                        fullyConnectedLayer(numResponses)
                        tanhLayer
                        regressionLayer];

                    % Keep epochs low because we continuously re-train in the loop
                    obj.NetworkOptions = trainingOptions('adam', ...
                        'MaxEpochs', 25, ...
                        'GradientThreshold', 1, ...
                        'InitialLearnRate', 0.005, ...
                        'Verbose', 0, ...
                        'Plots', 'training-progress',...
                        'ExecutionEnvironment','cpu',...
                        'MiniBatchSize',12);
                    if ~obj.IsCpu
                        obj.NetworkOptions.ExecutionEnvironment = 'gpu';
                    end
                case "NARX"
                    %% NARX
                    delaySecond = 2e-6; % Look at the last xxxus of the AWG commands and Scope
                    hiddenUnits = 15;      % NARX is highly efficient; 15-20 units is usually plenty
                    delay = 1:round(delaySecond * obj.SamplingRateMl);
                    for ii = 1:obj.NChannel
                        obj.Network{ii} = narxnet(delay, delay, hiddenUnits, 'open', 'trainbr');
                        obj.Network{ii}.trainParam.showWindow = true; % Keep true to watch the rapid convergence
                        obj.Network{ii}.trainParam.epochs = 50;       % trainlm converges much faster than Adam
                        obj.Network{ii}.trainParam.min_grad = 1e-7;   % Prevent early stopping
                    end

            end

            disp('Training initial baseline model...');
            obj.updateNetwork
        end

        function train(obj)
            disp('Starting closed-loop optimization with periodicity constraints...');
            maxAmp = obj.AmplitudeMaximum;
            beta = obj.Beta;
            awgSr = obj.SamplingRateAwg;
            duration = obj.SineDuration;
            obj.ConsecutiveGood = 0;
            obj.Scope.Duration = obj.SineDuration;
            obj.Scope.NSample = obj.SamplingRateScope * obj.SineDuration;
            obj.Scope.set
            obj.Scope.startFromEdge

            for iter = obj.IterationIdx:obj.NIteration
                fprintf('\n--- Iteration %d / %d ---\n', iter, obj.NIteration);

                for b = 1:obj.NBatch
                    wfl = cell(1,2);
                    targetWf = {};
                    laserPower = obj.measureLaserPower;
                    for ii = 1:obj.NChannel
                        %% Generate a random target optical sine wave
                        targetFreq = randi(obj.FrequencyRange); % 100 kHz to 1.5 MHz
                        targetOffset = max(rand() * maxAmp(ii) / 2, maxAmp(ii)/30) + obj.Offset(ii);    % Ensure signal stays positive
                        targetAmp = min(0.01 + (maxAmp(ii) * rand()),targetOffset * 2) * beta;   % Scale to your expected PD voltage

                        targetWf{ii} = SineWave(...
                            frequency=targetFreq,...
                            amplitude=targetAmp,...
                            offset=targetOffset,...
                            samplingRate=awgSr,...
                            duration=duration,...
                            phase = 3 * pi / 2 ...
                            );

                        %% Predict the raw AWG voltage (Bounded to +/- 1V by tanhLayer)
                        tList = targetWf{ii}.StartTime : targetWf{ii}.TimeStep : targetWf{ii}.EndTime;
                        ns = numel(targetWf{ii}.Sample);
                        switch obj.Method
                            case "LSTM"
                                if obj.IsIncludeAmpOffset
                                    predictedAwg = obj.mlWf2realWf(predict(obj.Network{ii},...
                                        [obj.realScope2MlScope(ii,targetWf{ii}.Sample,laserPower);...
                                        ones(1,ns)*targetAmp/2 ./ obj.AmplitudeMaximum(ii) * 2;...
                                        obj.realScope2MlScope(ii,ones(1,ns)*targetOffset,laserPower)...
                                        ]));
                                else
                                    predictedAwg = obj.mlWf2realWf(predict(obj.Network{ii},...
                                        [obj.realScope2MlScope(ii,targetWf{ii}.Sample,laserPower);...
                                        ]));
                                end
                            case "NARX"
                                ideal_target_mapped = obj.realScope2MlScope(ii,targetWf{ii}.Sample,laserPower);
                                ideal_target_cell = con2seq(ideal_target_mapped);
                                % 1. Find the maximum delay your network requires
                                % MATLAB stores this automatically in the numInputDelays property
                                net_open = obj.Network{ii};
                                max_delay = net_open.numInputDelays;

                                % 2. Extract EXACTLY that many points from the very end of your last DAgger iteration
                                last_X = obj.Dataset(ii).X{end}(:, end-max_delay+1:end);
                                last_Y = obj.Dataset(ii).Y{end}(:, end-max_delay+1:end);

                                % 3. Convert these small history chunks to sequence format
                                last_X_cell = con2seq(last_X);
                                last_Y_cell = con2seq(last_Y);

                                % 4. Trick preparets into perfectly formatting our initial states (Xi, Ai)
                                % Because last_X_cell is exactly 'max_delay' long, preparets consumes it entirely
                                % to build the initial delay states, leaving no leftover timesteps.
                                % 4. Prime the OPEN-LOOP states
                                [~, Xi_open, Ai_open] = preparets(net_open, last_X_cell, {}, last_Y_cell);

                                % 5. Close the loop AND translate the states!
                                % This converts the 2-input open-loop states into 1-input closed-loop states
                                [net_closed, Xi_closed, Ai_closed] = closeloop(net_open, Xi_open, Ai_open);

                                % 6. Predict!
                                % Now we feed the closed-loop states into the closed-loop network
                                predicted_awg_cell = net_closed(ideal_target_cell, Xi_closed, Ai_closed);
                                predictedAwg = obj.mlWf2realWf(cell2mat(predicted_awg_cell));
                        end
                        awgWf = InterpolatedWaveform(duration = duration,samplingRate=awgSr);
                        awgWf.TimeData = tList;
                        awgWf.SampleData = predictedAwg;
                        wfl{ii} = WaveformList("1",waveformOrigin={awgWf},samplingRate=awgSr);

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
                    end

                    %% Send waveform and process
                    pause(1)
                    obj.sendAndRead(wfl)
                    obj.processData(targetWf,false)
                    obj.RunIdx = obj.RunIdx + 1;
                end
                obj.IterationIdx = obj.IterationIdx + 1;
                %% Convergence Check
                obj.computeError(iter)
                obj.plotTrainingProgress
                obj.plotLaserPower
                for ii = 1:obj.NChannel
                    fprintf("KP" + ii + ": average normalized RMSE for Batch %d: %.4f \n", iter, obj.BatchError(ii,iter));
                end
                if obj.IsNormalizeError
                    th = obj.ErrorThreshold;
                    th = [th;th];
                else
                    th = obj.ErrorThreshold .* obj.AmplitudeMaximum / 2;
                    th = th.';
                end
                if all(obj.BatchError(:,iter) < th(1:obj.NChannel))
                    obj.ConsecutiveGood = obj.ConsecutiveGood + 1;
                    if obj.ConsecutiveGood >= 3
                        disp('Network has converged to the error threshold! Stopping.');
                        obj.saveNetwork
                        break; % Exit loop
                    end
                else
                    obj.ConsecutiveGood = 0; % Reset counter if error spikes
                end

                %% Re-train the network on the expanded, constrained dataset
                disp('Updating network with new hardware reality...');
                obj.updateNetwork
            end
        end

        function updateNetwork(obj)
            tic
            for ii = 1:obj.NChannel
                switch obj.Method
                    case "LSTM"
                        obj.Network{ii} = trainNetwork(obj.Dataset(ii).X, obj.Dataset(ii).Y,...
                            obj.NetworkLayers, obj.NetworkOptions);
                        delete(findall(0, 'Type', 'figure', 'Tag', 'NNET_CNN_TRAININGPLOT_UIFIGURE'));
                    case "NARX"
                        num_batches = length(obj.Dataset(ii).X);
                        num_timesteps = size(obj.Dataset(ii).X{1}, 2);  % e.g., 20000
                        num_features_X = size(obj.Dataset(ii).X{1}, 1); % e.g., 3 (Scope Trace, Amp, Offset)
                        num_features_Y = size(obj.Dataset(ii).Y{1}, 1); % e.g., 1 (AWG command)

                        % 2. Preallocate the cell arrays for speed
                        X_cell = cell(1, num_timesteps);
                        Y_cell = cell(1, num_timesteps);

                        % 3. Pack the data into concurrent batches!
                        % We slice across all iterations at each specific timestep
                        for t = 1:num_timesteps
                            % Preallocate the matrices for this specific timestep
                            x_step = zeros(num_features_X, num_batches);
                            y_step = zeros(num_features_Y, num_batches);

                            % Gather that exact timestep from every DAgger iteration
                            for b = 1:num_batches
                                x_step(:, b) = obj.Dataset(ii).X{b}(:, t);
                                y_step(:, b) = obj.Dataset(ii).Y{b}(:, t);
                            end

                            % Store the batch matrix in the cell array
                            X_cell{1, t} = x_step;
                            Y_cell{1, t} = y_step;
                        end
                        % combined_inputs = [X_cell; Y_cell];
                        [Xs, Xi, Ai, Ys] = preparets(obj.Network{ii}, X_cell, {}, Y_cell);

                        % Train the network using actual measured scope and actual applied AWG data
                        obj.Network{ii} = train(obj.Network{ii}, Xs, Ys, Xi, Ai);
                end
            end
            toc
        end

        function saveNetwork(obj)
            net = obj.Network;
            disp('Saving the  model...');
            save('PredistortionModel.mat', net);
            disp('Done! You can now use this model for instant, periodic waveform generation.');
        end

        function sendAndRead(obj,wfl)
            obj.MainAwg.WaveformList = wfl;
            obj.MainAwg.set
            obj.MainAwg.upload
            obj.PulseAwg.trigger
            pause(0.3)
            obj.Scope.read
        end

        function laserPower = measureLaserPower(obj)
            % obj.Scope.set
            pause(1)
            obj.PulseAwg.trigger
            pause(0.1)
            obj.Scope.read
            laserPower = mean(obj.Scope.Sample(3,:));
        end

        function processData(obj,targetWf,isSaveDelay)
            arguments
                obj KpPredistortion
                targetWf = []
                isSaveDelay = false
            end
            ignoredPoints = obj.NIgnoredSample;
            scopeSr = obj.SamplingRateScope;
            awgSr = obj.SamplingRateAwg;
            mlSr = obj.SamplingRateMl;
            laserPower = mean(obj.Scope.Sample(3,:));
            for ii = 1:obj.NChannel
                obj.Dataset(ii).LaserPower(obj.RunIdx) = laserPower;
                scopeRaw = obj.Scope.Sample(ii,:);
                awgRaw = obj.MainAwg.WaveformList{ii}.Sample;
                awgUp = resample(awgRaw, scopeSr, awgSr);

                %% Compute delay
                if isSaveDelay
                    obj.Delay(ii) = finddelay(awgUp, scopeRaw);
                end

                if obj.Delay(ii) > 0
                    % Scope is delayed relative to AWG (Expected physical reality)
                    scopeAligned = scopeRaw(obj.Delay(ii)+1:end);
                else
                    error("Delay is found to be negative. Check if you have a signal.")
                end

                %% Resample to match the machine learning sampling rate
                scopeMl = resample(scopeAligned, mlSr, scopeSr);
                awgMl   = resample(awgRaw, mlSr, awgSr);

                %% Ensure they match exactly in length
                minLen = min(length(scopeMl), length(awgMl));
                scopeMl = scopeMl(ignoredPoints:minLen-ignoredPoints);
                awgMl = awgMl(ignoredPoints:minLen-ignoredPoints);
                scopeMl = reshape(scopeMl, 1, []);
                awgMl = reshape(awgMl, 1, []);
                awgMl = obj.realWf2MlWf(awgMl);
                scopeMl = obj.realScope2MlScope(ii,scopeMl,laserPower);

                %% Save data
                obj.Dataset(ii).Y{obj.RunIdx} = awgMl;
                if isempty(targetWf)
                    obj.Dataset(ii).XTarget{obj.RunIdx} = ones(1,numel(awgMl)) * obj.AmplitudeMaximum(ii)/2;
                else
                    target = resample(targetWf{ii}.Sample, mlSr, awgSr);
                    obj.Dataset(ii).XTarget{obj.RunIdx} = target(ignoredPoints:minLen-ignoredPoints);
                end
                if ~obj.IsIncludeAmpOffset
                    obj.Dataset(ii).X{obj.RunIdx} = scopeMl;
                else
                    % compute offset and amplitude
                    if isSaveDelay
                        windowSize = 1e3;
                    else
                        windowSize = obj.WindowSize;
                    end
                    offset = movmean(scopeMl, windowSize);
                    centeredScope = scopeMl - offset;
                    [amp, ~] = envelope(centeredScope, windowSize, 'peak');
                    obj.Dataset(ii).X{obj.RunIdx} = [scopeMl;amp;offset];
                end

            end
        end

        function computeError(obj,batchIdx)
            for b = batchIdx
                runIdx = ((2 + obj.NOffset) + (b-1) * obj.NBatch) : ((1 + obj.NOffset) + (b) * obj.NBatch);
                for ii = 1:obj.NChannel
                    be = zeros(1,obj.NBatch);
                    for jj = 1:obj.NBatch
                        measured =  obj.mlScope2realScope(ii,obj.Dataset(ii).X{runIdx(jj)}(1,:),obj.Dataset(ii).LaserPower(runIdx(jj)));
                        target = obj.Dataset(ii).XTarget{runIdx(jj)}(1,:);
                        offset = mean(target);
                        if obj.IsNormalizeError
                            be(jj) = sqrt(mean(abs(measured - target).^2))/offset;
                        else
                            be(jj) = sqrt(mean(abs(measured - target).^2));
                        end
                    end
                    obj.BatchError(ii,b) = mean(be);
                    obj.BatchErrorStd(ii,b) = std(be);
                end
            end
        end

        function wfRescaled = realWf2MlWf(obj,wf)
            voltageRange = obj.VoltageRange;
            wfRescaled = 2 * (wf - voltageRange(1)) ./ (voltageRange(2) - voltageRange(1)) - 1;
        end

        function wfRescaled = mlWf2realWf(obj,wf)
            voltageRange = obj.VoltageRange;
            wfRescaled = ((wf + 1) * (voltageRange(2) - voltageRange(1)) / 2) + voltageRange(1);
        end

        function scopeRescaled = realScope2MlScope(obj,chIdx,scopeTrace,laserPower)
            voltageRange = [0,obj.AmplitudeMaximum(chIdx)./obj.PowerVoltageRange(1)];
            scopeRescaled = 2 * (scopeTrace./laserPower - voltageRange(1)) ./ (voltageRange(2) - voltageRange(1)) - 1;
        end

        function scopeRescaled = mlScope2realScope(obj,chIdx,scopeTrace,laserPower)
            voltageRange = [0,obj.AmplitudeMaximum(chIdx)./obj.PowerVoltageRange(1)];
            scopeRescaled = (((scopeTrace + 1) * (voltageRange(2) - voltageRange(1)) / 2) + voltageRange(1)) * laserPower;
        end

        function plot(obj,runIdx,timeRange)
            arguments
                obj
                runIdx
                timeRange = [0.5e-4,0.6e-4]
            end
            if runIdx > obj.RunIdx
                error("runIdx too large")
            end
            sr = obj.SamplingRateMl;
            fig = figure(243);
            tiledlayout(2,2)
            for ii = 1:obj.NChannel
                ax = nexttile(ii);
                scopeMl = obj.mlScope2realScope(ii,obj.Dataset(ii).X{runIdx}(1,:),obj.Dataset(ii).LaserPower(runIdx));
                awgMl = obj.mlWf2realWf(obj.Dataset(ii).Y{runIdx}(1,:));
                targetMl = obj.Dataset(ii).XTarget{runIdx}(1,:);
                nSample = numel(scopeMl);
                t = 0:(1/sr):(nSample/sr - 1/sr);
                tIdx = t>=timeRange(1) & t<=timeRange(2);
                t = t * 1e3;
                plot(ax,t(tIdx),scopeMl(tIdx),t(tIdx),targetMl(tIdx))
                xlabel("Time [ms]")
                ylabel("Photodiode Voltage [V]")
                legend("Measured","Target")
                ax.Title.String = "KP" + ii;

                ax = nexttile(2 + ii);
                plot(ax,t(tIdx),awgMl(tIdx))
                xlabel("Time [ms]")
                ylabel("AWG Voltage [V]")

            end
        end

        function plotTrainingProgress(obj)
            iter = size(obj.BatchError,2);
            iter = 1:iter;
            close(figure(42423))
            figure(42423)
            hold on
            for ii = 1:obj.NChannel
                eb(ii) = errorbar(iter,obj.BatchError(ii,:),obj.BatchErrorStd(ii,:),'.');
                legend(eb(ii),"KP"+ii)
            end
            hold off
            xlabel("Iteration Number")
            if obj.IsNormalizeError
                ylabel("Normalized Batch RMS Error")
            else
                ylabel("Batch RMS Error [V]")
            end
            render
            for ii = 1:obj.NChannel
                eb(ii).LineStyle = '-';
            end
            box on
            drawnow
        end
    
        function plotLaserPower(obj)
            runs = numel(obj.Dataset(1).LaserPower);
            runs = 1:runs;
            close(figure(42523))
            figure(42523)
            l = plot(runs,obj.Dataset(1).LaserPower,'.');
            xlabel("Run Index")
            ylabel("Precilaser Power [a.u.]")
            render
            l.LineStyle = '-';
            box on
            drawnow
        end
    end
end

