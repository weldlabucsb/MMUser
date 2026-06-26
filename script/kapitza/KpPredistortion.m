classdef KpPredistortion < handle
    %KPPREDISTORTION Summary of this class goes here
    %   Detailed explanation goes here

    properties
        Method = "LSTM" % Training method: LSTM, NARX, MLP, ILC
        NChannel = 2 % Number of training channels
        RunIdx = 1
        IterationIdx = 1
        SamplingRateAwg = 20e6 % keysight sampling rate
        SamplingRateMl = 20e6 % Machine learning sampling rate
        SamplingRateRamp = 50e6;
        SamplingRateRampSave = 1e6;
        NSampleScope = 1e6 % Number of samples on the scope
        SamplingRateScope = 1e9
        VoltageRange = [-1,0.8] % Keysight output voltage range
        PowerVoltageRange = [1,1.3] % Precilaser power PD voltage range
        FrequencyRange = [100e3,1.2e6] % Frequency range of modulation
        AmplitudeMaximum = [2.4, 4.7] / 2 % Maximum amplitude on the scope for KP1 and KP2
        ChirpDuration = 1e-3 % Duration of the chirp pulse
        SineDuration = 1e-3 % Duration of the sine pulse
        Beta = 0.8 % Reduction factor of AM modulation
        IgnoredTime = 1e-6 % Transient time after pulsing on the modulation
        DelayTimeEstimated = [1.85e-6,1.8e-6] % Estimated total delay time
        WindowSize = 400 % For calculating the amplitude and offset
        NOffset = 10 % Numbers of offset for pretraining data set
        NBatch = 5 % Numbers of runs per batch
        NIteration = 50     % Maximum number of outer DAgger loops
        ErrorThreshold  = 0.01;   % Acceptable average RMSE (e.g., 10 mV)
        IsIncludeAmpOffset = true % If we want to include amplitude and offset in the training
        IsNormalizeError = true % If we normalize the RMS error to the target offset
        IsCpu = true % If we use CPU to do training
        IsNormalizeToLaserPower = false % If we normalize the measurement to laser power
        IsUsingSpectrum = false % If we use spectrum AWG as the main AWG
        IsGuessUsingOldData = false % If we use old data to guess the starting point
        IsInverted = true % If we predict KP waveform using inverted condition
        IsRampUpModulation = true % If we want to ramp up the modulation in 1 us
        AlphaMaximum = 60;
        NGrid = 10;
        BandwidthPd = [10,11]*1e6
        RampTime = 10e-3
        InitialDepth = []
        AlphaListOverride = []
        FrequencyListOverride = []
        IsOverride = 0
        BmTime = 100e-6
        IsUseCorrection = 0 %Allows the use of a correction factor for the two lattices to account for differences between KD and AM Spec
        CorrFactor = [0.944, 1.25] % Guess for correction based on AM spectroscopy
        IsUseGenDatabase = 1; %Argument to allow saving and retrieving from an alternative dataset that saves and retrieves from a dataset with arguments that depend not on phase diagram parameters but generic parameters regarding the ramptimes, start and stop values, modulation depths and frequencies, and so on.

    end

    properties (SetAccess = protected)
        ConsecutiveGood = 0;     
        BatchError = [1;1]; % Error of each batch
        BatchErrorStd = [0;0]; % Std of the error
        Scope % Scope device connection
        PulseAwg % Pulse AWG device connection
        MainAwg % Main AWG device connection
        Delay % Delay time measured from chirp pulse
        DelayFunc % Delay as a function of frequency measured from sine pulses
        Offset = [0,0]; % Offset voltage levels on the scope when laser is off
        Dataset % Data
        Network cell = cell(1,2) % Neural network
        NetworkLayers
        NetworkOptions 
        Error double = [1;1] % Error of each run
        IsTraining = false
    end

    properties (Constant)
        MainAwgAddress = "TCPIP0::172.16.0.3::inst0::INSTR"
        MainAwgAddress2 = "TCPIP::172.16.0.0::inst0";
        PulseAwgAddress = "TCPIP0::172.16.0.4::inst0::INSTR"
        ScopeAddress = "TCPIP0::172.16.0.6::inst0::INSTR"
    end

    properties (Dependent)
        NIgnoredSample % Number of ignored samples at the beginning and the end
    end

    methods
        function obj = KpPredistortion()
            
        end

        function nis = get.NIgnoredSample(obj)
            nis = round(obj.SamplingRateMl * obj.IgnoredTime);
        end

        function setHardware(obj)
            disp("Setting hardware...")
            %% Scope
            obj.Scope = SiglentSDS2104XPlus(obj.ScopeAddress);
            obj.Scope.Duration = 10^round(log10(obj.ChirpDuration));
            obj.Scope.IsEnabled = [true,true,false,false];
            obj.Scope.TriggerSource = "External";
            obj.Scope.TriggerLevel = 0.3;
            obj.Scope.VerticalRange = [2.5,5,1.5,2];
            obj.Scope.VerticalOffset= [-1.24,-2.4,-0.75 + .02,0];
            obj.Scope.NSample = 10^round(log10(obj.ChirpDuration)) * obj.SamplingRateScope;
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
            if ~obj.IsUsingSpectrum
                obj.MainAwg = Keysight33600A(obj.MainAwgAddress);
            else
                obj.MainAwg = SpectrumDN2662_02(obj.MainAwgAddress2);
            end
            obj.MainAwg.WaveformList = {wfl,wfl};
            obj.MainAwg.SamplingRate = [obj.SamplingRateAwg,obj.SamplingRateAwg];
            obj.MainAwg.TriggerSource = ["External","External"];
            obj.MainAwg.TriggerDelay = [130.775e-9,0];
            obj.MainAwg.IsOutput = [true,true];
            obj.MainAwg.OutputMode = ["Normal","Normal"];
            obj.MainAwg.OutputLoad = ["Infinity","Infinity"];
            obj.MainAwg.Offset = [-1,-1];
            obj.MainAwg.connect
            obj.MainAwg.set
            obj.MainAwg.upload
            obj.PulseAwg.trigger
            obj.SamplingRateAwg = obj.MainAwg.SamplingRate(1);
            obj.SamplingRateMl = obj.MainAwg.SamplingRate(1);

        end

        function rollOff = PdRollOff(obj,chIdx,f)
            fc = obj.BandwidthPd(chIdx);
            rollOff = 1 / sqrt(1+(f/fc)^2);
        end

        function initializeDataset(obj)
            disp("Initializing dataset...")
            s.X = {};
            s.Y = {};
            s.XTarget = {};
            s.LaserPower = [];
            s.Harmonics = {};
            s.KpParameter = {};
            s.KpRampParameter = {};
            s.YRamp = {};
            s(2) = s;
            obj.Dataset = s;
            obj.RunIdx = 1;
            obj.IterationIdx = 1;
            obj.Error = [1;1];
            obj.BatchError = [1;1];
            obj.BatchErrorStd = [0;0]; 
        end

        function measureOffset(obj)
            disp("Measuring offset...")
            wfl = WaveformList("const",waveformOrigin = { ...
                ConstantWave(duration = obj.Scope.Duration * 1.2, offset = -1)...
                });
            obj.sendAndRead({wfl,wfl})
            pause(0.3)
            for chIdx = 1:obj.NChannel
                obj.Offset(chIdx) = mean(obj.Scope.Sample(chIdx,:));
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
            laserPower = obj.measureLaserPower;

            %% Execute hardware functions
            obj.sendAndRead({wfl,wfl})

            %% Align time delay, downsample, and store
            for chIdx = 1:obj.NChannel
                if obj.Method == "MLP" || obj.Method == "ILC"
                    obj.processData(chIdx,[],laserPower(chIdx),true,false);
                else
                    obj.processData(chIdx,[],laserPower(chIdx),true);
                    obj.RunIdx = obj.RunIdx + 1;
                end
            end
        end

        function measureDelay(obj)
            disp('Measuring frequency dependent delay...');
            % obj.setHardware
            nGrid = 20;
            fList = linspace(obj.FrequencyRange(1),obj.FrequencyRange(2),nGrid);
            obj.setScopeChirp
            pause(0.5)
            scopeSr = obj.SamplingRateScope;
            awgSr = obj.SamplingRateAwg;
            delay = [0;0];
            for ff = 1:nGrid
                %% Generate a broad chirp to teach basic physics
                wf = SineWave( ...
                    duration = obj.ChirpDuration, ...
                    amplitude= 0.8, ...
                    offset   = 0, ...
                    frequency = fList(ff),...
                    samplingRate = obj.SamplingRateAwg ...
                    );
                wfl = WaveformList("sine",waveformOrigin = {wf});

                %% Execute hardware functions
                obj.sendAndRead({wfl,wfl})

                %% Find delay
                T = 1/fList(ff);
                timeWindow = round(T * scopeSr * 70);
                sPerPeriod = round(T * scopeSr);
                startPoint = 3 * sPerPeriod + 1;
                endPoint = startPoint - 1 + timeWindow;
                for chIdx = 1:obj.NChannel
                    %% Resample data
                    if ff == 1
                        offset = round(obj.DelayTimeEstimated(chIdx) * scopeSr + sPerPeriod/10);
                    else
                        offset = round(delay(chIdx,ff-1) + sPerPeriod/10);
                    end
                    scopeRaw = obj.Scope.Sample(chIdx,:);
                    awgRaw = obj.MainAwg.WaveformList{chIdx}.Sample;
                    awgUp = resample(awgRaw, scopeSr, awgSr);
                    scopeRaw = scopeRaw(offset+startPoint:endPoint + offset);
                    awgUp = awgUp(startPoint:endPoint);
                    freq_resolution = scopeSr / numel(awgUp);
                    target_bin = round(fList(ff) / freq_resolution) + 1;

                    %% Compute delay
                    awgUp = awgUp - min(awgUp);
                    awgUp = awgUp ./ max(awgUp);
                    scopeRaw = scopeRaw - min(scopeRaw);
                    scopeRaw = scopeRaw ./ max(scopeRaw);

                    fft_sig1 = fft(awgUp);
                    fft_sig2 = fft(scopeRaw);
                    phase1 = angle(fft_sig1(target_bin));
                    phase2 = angle(fft_sig2(target_bin));
                    phase_diff = wrapToPi(phase1 - phase2);
                    measured_delay_sec = phase_diff / (2 * pi * fList(ff));

                    delay(chIdx,ff) = round(measured_delay_sec * scopeSr) + offset;

                    nPlot = delay(chIdx,ff) + sPerPeriod * 3;
                    x = obj.Scope.Sample(chIdx,:);
                    x = x(1:nPlot);
                    y = obj.MainAwg.WaveformList{chIdx}.Sample;
                    y = resample(y, scopeSr, awgSr);
                    y = [zeros(1,delay(chIdx,ff)),y];
                    y = y(1:nPlot);
                    x = x - min(x);
                    x = x ./ max(x);
                    y = y - min(y);
                    y = y ./ max(y);

                    %% Visualization
                    figure(9475+chIdx)
                    plot(1:nPlot,x,1:nPlot,y)
                    xlabel("Sample Index")
                    ylabel("Normalized Sample")
                    legend("Control Voltage","Scope Measurement Shifted")
                    title("KP" + chIdx + ", f = " + fList(ff)/1e6 + " MHz")
                end
            end

            %% Use SLM toolbox to do delay interpolation
            obj.DelayFunc = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                if delay(chIdx,1) > delay(chIdx,end)
                    slme = slmengine(fList,delay(chIdx,:), 'plot', 'on', 'decreasing', 'on');
                else
                    slme = slmengine(fList,delay(chIdx,:), 'plot', 'on', 'increasing', 'on');
                end
                obj.DelayFunc{chIdx} = @(f) round(slmeval(f,slme));
            end
            pause(1)
            close all
        end

        function getKpModData(obj,V0)
            disp('ILC: gathering control voltage data under KP constraints...')
            tic;
            %% Set parameters
            obj.setScopeSine
            nGrid = obj.NGrid;
            if obj.IsOverride
                fList=obj.FrequencyListOverride;
            else
                fList = linspace(obj.FrequencyRange(1),obj.FrequencyRange(2),nGrid);
            end
            laserPower = obj.measureLaserPower;
            rampCalib = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                rampCalib{chIdx} = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
            end
            ignoredPoints = obj.NIgnoredSample;
            awgSr = obj.SamplingRateAwg;

            %% Training parameters
            nIter0 = 50;        % How many times to update the waveform
            PRange = [0.6,0.6]/2;        % The "Proportional" gain range
            PFunc = @(f) (-tanh(2 * (f-100e3)/(1.2e6-100e3)) + 1) * range(PRange) + PRange(1);
            lowPassFreq = 10e6; % Low pass filter for the feedback
            eth0 = obj.ErrorThreshold;

            %% Main loop
            for vv = 1:numel(V0)
                V0Target = obj.getInitialDepthTarget(V0(vv));
                if obj.IsOverride
                    alphaList=obj.AlphaListOverride;
                    
                else
                    alphaList = linspace(2*V0Target/V0(vv)/obj.Beta,obj.AlphaMaximum,nGrid);
                end
                nAlphaCounts=length(alphaList);
                nFreqCounts=length(fList);
                for aa = 1:nAlphaCounts
                    obj.setScopeRangeKp(V0(vv),alphaList(aa))
                    for ff = 1:nFreqCounts
                        %% Update training parameters
                        % if alphaList(aa) <= 6
                        %     nIter = nIter0 * 2;
                        % else
                        %     nIter = nIter0;
                        % end
                        nIter = nIter0;
                        P = PFunc(fList(ff)) * ones(1,obj.NChannel);
                        if fList(ff) >= 1.8e6
                            eth = eth0 * 1.6;
                        else
                            eth = eth0;
                        end

                        %% Prepare target and initial control waveform guess
                        targetWf = cell(1,2);
                        controlWfl = cell(1,2);
                        isExact = [false,false];
                        nCycle = floor(obj.SineDuration * fList(ff));
                        for chIdx = 1:obj.NChannel
                            [controlWfl{chIdx},targetWfl,isExact(chIdx)] = obj.predictKpMod(...
                                chIdx,...
                                V0(vv),...
                                fList(ff),...
                                alphaList(aa),...
                                obj.Beta,...
                                nCycle,...
                                laserPower(chIdx),...
                                ~obj.IsGuessUsingOldData,...
                                0);
                            targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                        end
                        if obj.IsGuessUsingOldData && any(~isExact)
                            for chIdx = 1:obj.NChannel
                                [controlWfl{chIdx},targetWfl,~] = obj.predictKpMod(...
                                    chIdx,...
                                    V0(vv),...
                                    fList(ff),...
                                    alphaList(aa),...
                                    obj.Beta,...
                                    nCycle,...
                                    laserPower(chIdx),...
                                    true,...
                                    0);
                                targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                            end
                        end
                        % if obj.IsGuessUsingOldData && all(isExact)
                        %     nIter = round(nIter/5);
                        % end

                        %% Perform training
                        errorHistory = cell(1,obj.NChannel);
                        isConverged = zeros(1,obj.NChannel);
                        for kk = 1:nIter
                            if all(isConverged)
                                break
                            end
                            obj.sendAndRead(controlWfl)
                            % controlWfl = cell(1,2);
                            for chIdx = 1:obj.NChannel 
                                %% Stop if converged
                                if isConverged(chIdx)
                                    continue
                                end

                                %% Update P gain
                                if kk > 3 ...
                                        && errorHistory{chIdx}(kk-1) - errorHistory{chIdx}(kk-2) > 0 ...
                                        && errorHistory{chIdx}(kk-2) - errorHistory{chIdx}(kk-3) > 0
                                    P(chIdx) = P(chIdx) * 0.8;
                                end

                                %% Update control voltage from error signal
                                tList = targetWf{chIdx}.StartTime : targetWf{chIdx}.TimeStep : targetWf{chIdx}.EndTime;
                                [controlMl,targetMl,scopeMl] = obj.processData(chIdx,targetWf{chIdx},laserPower(chIdx),false,false,false);
                                controlMl = obj.mlWf2realWf(controlMl);
                                errorHistory{chIdx}(kk) = obj.computeErrorRaw(...
                                    scopeMl(ignoredPoints+1:end - ignoredPoints),...
                                    targetMl(ignoredPoints+1:end - ignoredPoints),...
                                    obj.realScope2MlScope(chIdx,targetWf{chIdx}.Offset,laserPower(chIdx))+1);
                                controlMl = controlMl + P(chIdx) * (targetMl - scopeMl);
                                controlMl = lowpass(controlMl, lowPassFreq, awgSr);
                                controlMl = max(min(controlMl, obj.VoltageRange(2)), obj.VoltageRange(1));
                                controlWf = InterpolatedWaveform(duration = targetWf{chIdx}.Duration,samplingRate=awgSr);
                                controlWf.TimeData = tList;
                                controlWf.SampleData = controlMl;
                                controlWfl{chIdx} = WaveformList("1",waveformOrigin={controlWf},samplingRate=awgSr);

                                %% Visualization
                                figure(3523+chIdx)
                                subplot(2,1,1);
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,targetMl,laserPower(chIdx)), 'k--', 'LineWidth', 1.5); hold on;
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,scopeMl,laserPower(chIdx)), 'r', 'LineWidth', 1); hold off;
                                title(sprintf(['KP',num2str(chIdx),', Iteration %d: Target vs Measured Output'], kk));
                                xlabel('Time (us)'); ylabel('Voltage (V)');
                                legend('Target', 'Measured');

                                subplot(2,1,2);
                                semilogy(1:kk, errorHistory{chIdx}(1:kk), '-o', 'LineWidth', 1.5);
                                title('RMS Error Convergence');
                                xlabel('Iteration'); ylabel('Normalized RMS Error');
                                grid on;

                                drawnow;

                                %% Check if this channel is converged
                                if errorHistory{chIdx}(kk) < eth0
                                    isConverged(chIdx) = 1;
                                end
                                if kk >= 10
                                    histError = errorHistory{chIdx}(end-9:end);
                                    if std(histError) / mean(histError) < 0.1 || std(histError) < eth0/3
                                        isConverged(chIdx) = 1;
                                    end
                                end
                            end
                        end
                        %% Update dataset
                        for chIdx = 1:obj.NChannel
                            runIdx = numel(obj.Dataset(chIdx).KpParameter) + 1;
                            if isExact(chIdx)
                                [~,~,runIdx] = obj.findKpModData(chIdx,V0(vv),fList(ff),alphaList(aa),obj.Beta);
                            end
                            obj.Dataset(chIdx).KpParameter{runIdx} = [V0(vv);fList(ff);alphaList(aa);obj.Beta];
                            obj.Dataset(chIdx).Y{runIdx} = controlWfl{chIdx}.Sample;
                            % obj.Dataset(chIdx).XTarget{obj.RunIdx} = targetWf{chIdx}.Sample;
                            obj.Error(chIdx,runIdx) = errorHistory{chIdx}(end);

                            disp("KP" + chIdx + ", V0 = " + V0(vv) +" Er, f = " + fList(ff)/1e6 + " MHz, alpha = " + alphaList(aa))
                            disp("error: " + errorHistory{chIdx}(end))
                        end
                        obj.RunIdx = runIdx + 1;
                    end
                end
            end
            obj.saveObj
            obj.setHardware
            toc
        end

        function getKpRampData(obj,V0, lowPassFreq, isPhaseFree, itercts)
            if nargin<3
                lowPassFreq=1e3;
                sliderCt=1e4;
            else
                awgSr = obj.SamplingRateRamp;
                sliderCt=ceil(awgSr/lowPassFreq);
            end
            if nargin<4
                isPhaseFree=0;
            end
            if nargin<5
                itercts=50;
            end

            

            disp('ILC: gathering control voltage data for KP Ramp...')
            tic;
            obj.IsTraining = true;
            %% Set parameters
            obj.setScopeRamp
            nGrid = obj.NGrid;
            laserPower = obj.measureLaserPower;
            rampCalib = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                rampCalib{chIdx} = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
            end
            ignoredPoints = obj.NIgnoredSample;
            
            awgSr = obj.SamplingRateRamp;
            obj.MainAwg.SamplingRate = [awgSr,awgSr];
            obj.MainAwg.set
            ignoredPoints = round(ignoredPoints * awgSr / obj.SamplingRateMl);

            %% Training parameters
            nIter0 = itercts;        % How many times to update the waveform
            P = [0.6,0.6];
            eth0 = obj.ErrorThreshold;

            %% Main loop
            for vv = 1:numel(V0)
                V0Target = obj.getInitialDepthTarget(V0(vv));
                
                if obj.IsOverride
                    alphaList=obj.AlphaListOverride;
                else
                    alphaList = linspace(2*V0Target/V0(vv)/obj.Beta,obj.AlphaMaximum,nGrid);
                end
                nAlphaCount=length(alphaList);
                targetDepth = obj.getInitialDepthTarget(V0(vv));
                for aa = 1:nAlphaCount
                    obj.setScopeRangeKp(V0(vv),alphaList(aa))
                        %% Update training parameters
                        % if alphaList(aa) <= 6
                        %     nIter = nIter0 * 2;
                        % else
                        %     nIter = nIter0;
                        % end
                        nIter = nIter0;
                        eth = eth0;
                        % lowPassFreq = 1e3;

                        %% Prepare target and initial control waveform guess
                        targetWf = cell(1,2);
                        controlWfl = cell(1,2);
                        isExact = [false,false];
                        for chIdx = 1:obj.NChannel
                            [controlWfl{chIdx},targetWfl,isExact(chIdx)] = obj.predictKpRamp(...
                                chIdx,...
                                V0(vv),...
                                alphaList(aa),...
                                obj.Beta,...
                                laserPower(chIdx),...
                                ~obj.IsGuessUsingOldData);
                            targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                        end
                        if obj.IsGuessUsingOldData && any(~isExact)
                            for chIdx = 1:obj.NChannel
                                [controlWfl{chIdx},targetWfl,~] = obj.predictKpRamp(...
                                    chIdx,...
                                    V0(vv),...
                                    alphaList(aa),...
                                    obj.Beta,...
                                    laserPower(chIdx),...
                                    true);
                                targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                            end
                        end

                        %% Perform training
                        errorHistory = cell(1,obj.NChannel);
                        isConverged = zeros(1,obj.NChannel);
                        for kk = 1:nIter
                            if all(isConverged)
                                break
                            end
                            
                            obj.sendAndRead(controlWfl,0.5)
                            % pause(10e-3);
                            % controlWfl = cell(1,2);
                            for chIdx = 1:obj.NChannel 
                                %% Stop if converged
                                if isConverged(chIdx)
                                    continue
                                end

                                %% Update P gain
                                if kk > 3 ...
                                        && errorHistory{chIdx}(kk-1) - errorHistory{chIdx}(kk-2) > 0 ...
                                        && errorHistory{chIdx}(kk-2) - errorHistory{chIdx}(kk-3) > 0
                                    P(chIdx) = P(chIdx) * 0.8;
                                end

                                %% Update control voltage from error signal
                                tList = targetWf{chIdx}.StartTime : targetWf{chIdx}.TimeStep : targetWf{chIdx}.EndTime;
                                
                                [controlMl,targetMl,scopeMl] = obj.processData(chIdx,targetWf{chIdx},laserPower(chIdx),false,false,false);
                                controlMl = obj.mlWf2realWf(controlMl);
                                errorHistory{chIdx}(kk) = obj.computeErrorRaw(...
                                    scopeMl(ignoredPoints+1:end - ignoredPoints),...
                                    targetMl(ignoredPoints+1:end - ignoredPoints),...
                                    obj.realScope2MlScope(chIdx,targetWf{chIdx}.StopValue/2,laserPower(chIdx))+1);
                                controlMl = controlMl + P(chIdx) * (targetMl - scopeMl);   
                                controlMl = max(min(controlMl, obj.VoltageRange(2)), obj.VoltageRange(1));
                                if isPhaseFree
                                    [b,a] = butter(4, lowPassFreq/(awgSr/2), 'low');
                                    controlMl = filtfilt(b,a,controlMl);
                                else
                                    controlMl = lowpass(controlMl, lowPassFreq, awgSr);
                                end
                                controlMl = movmean(controlMl,sliderCt);
                                controlWf = InterpolatedWaveform(duration = targetWf{chIdx}.Duration,samplingRate=awgSr);
                                controlWf.TimeData = tList;
                                controlWf.SampleData = controlMl;
                                controlWfl{chIdx} = WaveformList("1",waveformOrigin={controlWf},samplingRate=awgSr);

                                %% Visualization
                                figure(3523+chIdx)
                                subplot(2,1,1);
                                plot(tList*1e3, obj.mlScope2realScope(chIdx,targetMl,laserPower(chIdx)), 'k--', 'LineWidth', 1.5); hold on;
                                plot(tList*1e3, obj.mlScope2realScope(chIdx,scopeMl,laserPower(chIdx)), 'r', 'LineWidth', 1); hold off;
                                title(sprintf(['KP',num2str(chIdx),', Iteration %d: Target vs Measured Output'], kk));
                                xlabel('Time (ms)'); ylabel('Voltage (V)');
                                legend('Target', 'Measured');

                                subplot(2,1,2);
                                semilogy(1:kk, errorHistory{chIdx}(1:kk), '-o', 'LineWidth', 1.5);
                                title('RMS Error Convergence');
                                xlabel('Iteration'); ylabel('Normalized RMS Error');
                                grid on;

                                drawnow;

                                %% Check if this channel is converged
                                if errorHistory{chIdx}(kk) < eth0
                                    isConverged(chIdx) = 1;
                                end
                                if kk >= 10
                                    histError = errorHistory{chIdx}(end-9:end);
                                    if  std(histError) < eth0/3 || std(histError) / mean(histError) < 0.1 
                                        isConverged(chIdx) = 1;
                                    end
                                end
                            end
                        end
                        %% Update dataset
                        for chIdx = 1:obj.NChannel
                            runIdx = numel(obj.Dataset(chIdx).KpRampParameter) + 1;
                            if isExact(chIdx)
                                [~,~,runIdx] = obj.findKpRampData(chIdx,V0(vv),alphaList(aa),obj.Beta,obj.IsInverted,targetDepth, obj.RampTime);
                            end
                            obj.Dataset(chIdx).KpRampParameter{runIdx} = [V0(vv);alphaList(aa);obj.Beta;obj.IsInverted;targetDepth;obj.RampTime];
                            obj.Dataset(chIdx).YRamp{runIdx} = resample(controlWfl{chIdx}.Sample,obj.SamplingRateRampSave,awgSr);
                            % obj.Dataset(chIdx).XTarget{obj.RunIdx} = targetWf{chIdx}.Sample;
                            obj.Error(chIdx,runIdx) = errorHistory{chIdx}(end);

                            disp("KP" + chIdx + ", V0 = " + V0(vv) +" Er, " + " alpha = " + alphaList(aa))
                            disp("error: " + errorHistory{chIdx}(end))
                        end
                        obj.RunIdx = runIdx + 1;
                end
            end
            obj.IsTraining = false;
            obj.saveObj
            obj.setHardware
            toc
        end

        function getFourierData(obj)
            %% Generate target waveform parameters
            nGrid = obj.NGrid;
            ampMaxActual = obj.AmplitudeMaximum * 0.88;
            fList = linspace(obj.FrequencyRange(1),obj.FrequencyRange(2),nGrid);
            % fList = linspace(obj.FrequencyRange(2),obj.FrequencyRange(2),1);
            ignoredPoints = obj.NIgnoredSample;
            scopeSr = obj.SamplingRateScope;
            awgSr = obj.SamplingRateAwg;
            mlSr = obj.SamplingRateMl;
            offsetList = cell(1,obj.NChannel);
            rampCalib = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                offsetList{chIdx} = linspace(0.02,obj.AmplitudeMaximum(chIdx)/2,nGrid);
                % offsetList{chIdx} = linspace(ampMaxActual(chIdx)/2,ampMaxActual(chIdx)/2,1);
                rampCalib{chIdx} = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
            end
            obj.setScopeSine

            %% Training parameters
            nIter = 50;        % How many times to update the waveform
            PRange = [0.3,0.6];        % The "Proportional" gain (usually 0.3 to 0.8)
            PFunc = @(f) (-tanh(2 * (f-100e3)/(1.2e6-100e3)) + 1) * range(PRange) + PRange(1);
            lowPass = 10e6;
            nHarmonics = 5; % Up to 5th harmonic

            %% Main loop
            for ff = 1:numel(fList)
                P = PFunc(fList(ff));
                for oo = 1:numel(offsetList{1})
                    ampList = cell(1,obj.NChannel);
                    for chIdx = 1:obj.NChannel
                        maxAmp = min([offsetList{chIdx}(oo),ampMaxActual(chIdx) - offsetList{chIdx}(oo)]);
                        ampList{chIdx} = linspace(0.01,maxAmp,nGrid) * obj.Beta * 2;
                    end
                    for aa = 1:numel(ampList{1})
                        % Guess the control waveform from DC
                        % calibration
                        targetWf = cell(1,obj.NChannel);
                        controlWfl = cell(1,2);
                        for chIdx = 1:obj.NChannel
                            [controlWfl{chIdx},targetWf{chIdx}] = obj.guessFromDc(...
                                fList(ff),...
                                ampList{chIdx}(aa),...
                                offsetList{chIdx}(oo),...
                                rampCalib{chIdx},0);
                        end

                        errorHistory = cell(1,obj.NChannel);
                        laserPower = 1;
                        tList = targetWf{1}.StartTime : targetWf{1}.TimeStep : targetWf{1}.EndTime;
                        for kk = 1:nIter
                            % Feedback control

                            obj.sendAndRead(controlWfl)
                            controlWfl = cell(1,2);
                            for chIdx = 1:obj.NChannel
                                delay = obj.DelayFunc{chIdx}(fList(ff));
                                scopeRaw = obj.Scope.Sample(chIdx,:);
                                awgRaw = obj.MainAwg.WaveformList{chIdx}.Sample;
                                scopeAligned = scopeRaw(delay+1:end);
                                scopeMl = resample(scopeAligned, mlSr, scopeSr);
                                awgMl   = resample(awgRaw, mlSr, awgSr);

                                minLen = min(length(scopeMl), length(awgMl));
                                scopeMl = scopeMl(1:minLen);
                                awgMl = awgMl(1:minLen);
                                scopeMl = obj.realScope2MlScope(chIdx,scopeMl,laserPower);
                                targetMl = resample(targetWf{chIdx}.Sample, mlSr, awgSr);
                                targetMl = targetMl(1:minLen);
                                targetMl = obj.realScope2MlScope(chIdx,targetMl,laserPower);

                                errorCurrent = targetMl - scopeMl;
                                errorHistory{chIdx}(kk) = rms(errorCurrent(ignoredPoints+1:end - ignoredPoints)) ./...
                                    (obj.realScope2MlScope(chIdx,offsetList{chIdx}(oo),laserPower)+1);
                                awgMl = awgMl + P * errorCurrent;
                                awgMl = lowpass(awgMl, lowPass, awgSr);
                                awgMl = max(min(awgMl, obj.VoltageRange(2)), obj.VoltageRange(1));
                                controlWf = InterpolatedWaveform(duration = obj.SineDuration,samplingRate=awgSr);
                                controlWf.TimeData = tList;
                                controlWf.SampleData = awgMl;
                                controlWfl{chIdx} = WaveformList("1",waveformOrigin={controlWf},samplingRate=awgSr);


                                % --- Visualization ---
                                figure(3523+chIdx)
                                subplot(2,1,1);
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,targetMl,laserPower), 'k--', 'LineWidth', 1.5); hold on;
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,scopeMl,laserPower), 'r', 'LineWidth', 1); hold off;
                                title(sprintf('Iteration %d: Target vs Measured Output', kk));
                                xlabel('Time (us)'); ylabel('Voltage (V)');
                                legend('Target', 'Measured');

                                subplot(2,1,2);
                                plot(1:kk, errorHistory{chIdx}(1:kk), '-o', 'LineWidth', 1.5);
                                title('RMS Error Convergence');
                                xlabel('Iteration'); ylabel('Normalized RMS Error');
                                grid on;

                                drawnow;


                            end
                        end
                        % Extract Fourier Coefficients for the MLP Dataset
                        % Now that we have the perfect input waveform (u_current), extract
                        % its fundamental and harmonic components using dot products.


                        omega = 2 * pi * fList(ff);
                        T = 1/fList(ff);
                        tList = tList(ignoredPoints+1:end-ignoredPoints);
                        tTotal = tList(end) - tList(1);
                        nT = floor(tTotal/T);
                        tIdx = tList <= (nT * T + tList(1));
                        tList = tList(tIdx);
                        for chIdx = 1:obj.NChannel
                            abCoeffs = zeros(2*nHarmonics,1);
                            u_current = controlWfl{chIdx}.Sample;
                            u_current = u_current(ignoredPoints+1:end-ignoredPoints);
                            u_current = u_current(tIdx);
                            a0 = mean(u_current); % DC offset
                            for n = 1:nHarmonics

                                % Dot product with cosine (for 'a' coefficients)
                                an = (2/length(tList)) * sum(u_current .* cos(n * omega * tList));
                                % Dot product with sine (for 'b' coefficients)
                                bn = (2/length(tList)) * sum(u_current .* sin(n * omega * tList));

                                abCoeffs(2*n - 1) = an;
                                abCoeffs(2*n) = bn;
                            end
                            obj.Dataset(chIdx).X{obj.RunIdx} = [fList(ff);ampList{chIdx}(aa);offsetList{chIdx}(oo)];
                            obj.Dataset(chIdx).Y{obj.RunIdx} = [a0;abCoeffs];
                            obj.Error(chIdx,obj.RunIdx) = errorHistory{chIdx}(end);

                            disp("KP" + chIdx +", f = " + fList(ff)/1e6 + " MHz, amp =  " + ampList{chIdx}(aa) + ", offset = " + offsetList{chIdx}(oo))
                            disp("error: "+errorHistory{chIdx}(end))
                        end
                        obj.RunIdx = obj.RunIdx + 1;
                    end
                end
            end
        end

        function getAmpModChirpData(obj)
            nOffset = obj.NOffset;
            voltageRange = obj.VoltageRange;
            awgSr = obj.SamplingRateAwg;
            duration = obj.ChirpDuration;
            offsetList = linspace(voltageRange(1) + 0.5, voltageRange(2) - 0.1,nOffset);
            laserPower = obj.measureLaserPower;
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
                for chIdx = 1:obj.NChannel
                    obj.processData(chIdx,[],laserPower(chIdx),false);
                end
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
                    for chIdx = 1:obj.NChannel
                        obj.Network{chIdx} = narxnet(delay, delay, hiddenUnits, 'open', 'trainbr');
                        obj.Network{chIdx}.trainParam.showWindow = true; % Keep true to watch the rapid convergence
                        obj.Network{chIdx}.trainParam.epochs = 50;       % trainlm converges much faster than Adam
                        obj.Network{chIdx}.trainParam.min_grad = 1e-7;   % Prevent early stopping
                    end
                case "MLP"
                    %% MLP
                    hiddenLayerSizes = [16 8];
                    for chIdx = 1:obj.NChannel
                        obj.Network{chIdx} = fitnet(hiddenLayerSizes);

                        % Optional: Setup division of data for training, validation, testing
                        obj.Network{chIdx}.divideParam.trainRatio = 70/100;
                        obj.Network{chIdx}.divideParam.valRatio = 15/100;
                        obj.Network{chIdx}.divideParam.testRatio = 15/100;
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
            obj.setScopeSine

            for iter = obj.IterationIdx:obj.NIteration
                fprintf('\n--- Iteration %d / %d ---\n', iter, obj.NIteration);

                for b = 1:obj.NBatch
                    wfl = cell(1,2);
                    targetWf = {};
                    laserPower = obj.measureLaserPower;
                    for chIdx = 1:obj.NChannel
                        %% Generate a random target optical sine wave
                        targetFreq = randi(obj.FrequencyRange); % 100 kHz to 1.5 MHz
                        targetOffset = max(rand() * maxAmp(chIdx) / 2, maxAmp(chIdx)/30) + obj.Offset(chIdx);    % Ensure signal stays positive
                        targetAmp = min(0.01 + (maxAmp(chIdx) * rand()),targetOffset * 2) * beta;   % Scale to your expected PD voltage

                        targetWf{chIdx} = SineWave(...
                            frequency=targetFreq,...
                            amplitude=targetAmp,...
                            offset=targetOffset,...
                            samplingRate=awgSr,...
                            duration=duration,...
                            phase = 3 * pi / 2 ...
                            );
                        awgWf = obj.predictAwg(chIdx,targetWf{chIdx},laserPower(chIdx));
                        wfl{chIdx} = WaveformList("1",waveformOrigin={awgWf},samplingRate=awgSr);

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
                    for chIdx = 1:obj.NChannel
                        obj.processData(chIdx,targetWf,laserPower(chIdx),false);
                    end
                    obj.RunIdx = obj.RunIdx + 1;
                end
                obj.IterationIdx = obj.IterationIdx + 1;
                %% Convergence Check
                obj.computeError(iter)
                obj.plotTrainingProgress
                obj.plotLaserPower
                for chIdx = 1:obj.NChannel
                    fprintf("KP" + chIdx + ": average normalized RMSE for Batch %d: %.4f \n", iter, obj.BatchError(chIdx,iter));
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

        function kpTest(obj,V0,isDc)
            arguments
                obj
                V0
                isDc = false
            end
            obj.setScopeSine
            laserPower = obj.measureLaserPower;
            %% Get KD data
            load('LatticeCalib.mat','KP1Depth2Pd','KP2Depth2Pd')
            k(1) = 1/(KP1Depth2Pd(1)-KP1Depth2Pd(0));
            off(1) = KP1Depth2Pd(0);
            k(2) = 1/(KP2Depth2Pd(1)-KP2Depth2Pd(0));
            off(2) = KP2Depth2Pd(0);

            %% Get the harmonic frequency
            atom = getAtom("Lithium7");
            laser = Laser(wavelength = 1064e-9,power = 1);
            ol = OpticalLattice(atom,laser);
            ol.DepthSpec = V0 * ol.RecoilEnergy;
            f0 = ol.HarmonicFrequency;

            %% Scan parameters
            nGrid = obj.NGrid;
            V0Target = obj.getInitialDepthTarget(V0);
            

            if obj.IsOverride
                alphaList=obj.AlphaListOverride;
                fList=obj.FrequencyListOverride;
            else
                alphaList = linspace(2*V0Target/V0/obj.Beta,obj.AlphaMaximum,nGrid);
                fList = linspace(obj.FrequencyRange(1),obj.FrequencyRange(2),nGrid);
            end

            nAlphaCount=length(alphaList);
            nFreqCount=length(fList);
            
            %% Output parameters
            errorList = zeros(nFreqCount,nAlphaCount,obj.NChannel);
            tRange = [0.3,0.8]*1e-4;
            V0Measured = zeros(nFreqCount,nAlphaCount);
            modDepthMeasured = zeros(2,nFreqCount,nAlphaCount);
            phaseDiffMeasured = zeros(nFreqCount,nAlphaCount);

            for aa = 1:nAlphaCount
                obj.setScopeRangeKp(V0,alphaList(aa))
                for ff = 1:nFreqCount
                    %% Get data
                    controlWfl = cell(1,2);
                    targetWfl = cell(1,2);
                    nCycle = floor(obj.SineDuration * fList(ff));
                    for chIdx = 1:obj.NChannel
                        [controlWfl{chIdx},targetWfl{chIdx}] = obj.predictKpMod(chIdx,V0,fList(ff),alphaList(aa),obj.Beta,nCycle,laserPower(chIdx),isDc);
                    end
                    obj.sendAndRead(controlWfl)

                    t = obj.Scope.TimeList;
                    fs = 1/(t(2) - t(1));
                    idx = t>=tRange(1) & t<=tRange(2);
                    t = t(idx);
                    f = fList(ff);
                    V = zeros(1,2);
                    phase = zeros(1,2);
                    alpha = alphaList(aa);
                    beta = obj.Beta;

                    %% Analysis
                    for chIdx = 1:obj.NChannel
                        % RMS
                        [~,targetMl,scopeMl] = obj.processData(chIdx,targetWfl{chIdx}.WaveformOrigin{1},laserPower(chIdx),false,false);
                        scopeMl = obj.mlScope2realScope(chIdx,scopeMl,laserPower(chIdx));
                        targetMl = obj.mlScope2realScope(chIdx,targetMl,laserPower(chIdx));
                        offset = mean(targetMl);
                        errorList(ff,aa,chIdx) = obj.computeErrorRaw(scopeMl,targetMl,offset);

                        % Sine fit
                        s = obj.Scope.Sample(chIdx,idx);
                        basis = [sin(2*pi*f*t.'), cos(2*pi*f*t.')];
                        coeffs = basis \ s.';
                        guessPhase = wrapTo2Pi(atan2(coeffs(2), coeffs(1)));

                        fd = SineFit1D([t.',s.']);
                        fd.IsOverride = true;
                        fd.setDefaultOverride;
                        fd.StartPointOverride(2) = f;
                        fd.LowerOverride(2) = f;
                        fd.UpperOverride(2) = f;
                        fd.StartPointOverride(3) = guessPhase;
                        fd.do;
                        V(chIdx) = k(chIdx) * (fd.Coefficient(4) - off(chIdx));
                        phase(chIdx) = wrapToPi(fd.Coefficient(3));
                        if chIdx == 1
                            modDepthTarget = alpha / 2 * beta;
                        else
                            modDepthTarget = (1+alpha/2) * alpha / (2 + alpha) * beta;
                        end
                        modDepthMeasured(chIdx,ff,aa) = (k(chIdx) * fd.Coefficient(1)/V0/modDepthTarget - 1);
                        
                        % Plot
                        figure(34824+chIdx)
                        fd.NPlot = 1e6;
                        plot(t.',s.',fd.FitPlotData(:,1),fd.FitPlotData(:,2));
                        xlim([t(1),t(1)+10e-6])
                        title("Sine Fit, KP" + chIdx)
                        drawnow

                        figure(3482+chIdx)
                        plot(1:numel(scopeMl),scopeMl,1:numel(targetMl),targetMl)
                        title("KP" + chIdx )
                        legend("Measured","Target")
                        drawnow
                    end
                    V0Measured(ff,aa) = (abs(V(1) - V(2)) - V0)/V0;
                    phaseDiffMeasured(ff,aa) = (abs(diff(phase)) - pi)/pi;
                    pause(0.1)
                    disp([aa,ff])
                end
            end
            plotError(V0Measured,"$V_0$")
            plotError(phaseDiffMeasured,"Phase Difference")
            plotError(squeeze(modDepthMeasured(1,:,:)),"Modulation Depth, KP1")
            plotError(squeeze(modDepthMeasured(2,:,:)),"Modulation Depth, KP2")

            function plotError(data,tt)
                figure
                imagesc(data,XData=alphaList * beta,YData=  fList/ f0)
                xlabel("$\alpha$")
                ylabel("$\Omega$")
                cb = colorbar;
                cb.Label.String = "Normalized Error";
                title(tt,'Interpreter','latex')
                render
                clim([-max(abs(data(:))),max(abs(data(:)))])
                colormap(bluewhitered)
            end

            for chIdx = 1:obj.NChannel
                close(figure(4830+chIdx))
                figure(4830+chIdx)
                imagesc(errorList(:,:,chIdx),'XData',alphaList,'YData',fList / f0);
                xlabel("$\alpha$")
                ylabel("$\Omega$")
                cb = colorbar;
                cb.Label.String = "Error, KP"+chIdx;
                title("KP" + chIdx + ", V0 = " + V0 + ", beta = " + obj.Beta + ...
                    " Mean Error = " + mean(errorList(:,:,chIdx),"all"))
                clim([0,0.03])
                render
            end
            obj.setHardware
        end

        function targetWfl = getKpModTarget(obj,chIdx,V0,f,alpha,beta,nCycle,phi)
            % Get the target optical waveform for the given KP parameters
            calibName = "KP" + chIdx + "Depth2Pd";
            kdCalib = loadVar("LatticeCalib.mat",calibName);
            sr = obj.SamplingRateAwg;
            duration = 1/f * nCycle;

            rollOff = obj.PdRollOff(chIdx,f); % Takes into account the photodiode induced rolloff from selected gains.
            if nargin == 7
                phi = obj.getPhaseTarget(V0,alpha,beta);
            end

            if obj.IsUseCorrection
                V0=V0*obj.CorrFactor(chIdx);
            end

            if chIdx == 1
                depthWf = SineWave(...
                    frequency    = f,...
                    amplitude    = alpha * beta * V0,...
                    offset       = alpha / 2 * V0,...
                    samplingRate = sr,...
                    duration     = duration,...
                    phase        = pi + phi ...
                    );
            else
                depthWf = SineWave(...
                    frequency    = f,...
                    amplitude    = (1+alpha/2) * V0 * (alpha/(2+alpha)) * 2 * beta,...
                    offset       = (1+alpha/2) * V0,...
                    samplingRate = sr,...
                    duration     = duration,...
                    phase        = phi ...
                    );
            end
            targetWf = SineWave(...
                frequency    = f,...
                amplitude    = range(kdCalib(depthWf.Sample)) * rollOff,...
                offset       = kdCalib(depthWf.Offset),...
                samplingRate = sr,...
                duration     = duration,...
                phase        = depthWf.Phase ...
                );
            targetWfl = WaveformList("1",waveformOrigin = {targetWf},samplingRate = sr);
        end

        function targetWfl = getGenModTarget(obj,chIdx,MeanDepth,f, ModDepth, nCycle,phi) %%Still Incomplete, need to think about how to createnew PhaseTarget function
            % Get the target optical waveform for the given KP parameters
            calibName = "KP" + chIdx + "Depth2Pd";
            kdCalib = loadVar("LatticeCalib.mat",calibName);
            sr = obj.SamplingRateAwg;
            duration = 1/f * nCycle;

            rollOff = obj.PdRollOff(chIdx,f);
            if nargin < 8
                phi = 0;
            end

            if obj.IsUseCorrection
                MeanDepth=MeanDepth*obj.CorrFactor(chIdx);
                ModDepth=ModDepth*obj.CorrFactor(chIdx);
            end

            
            depthWf = SineWave(...
                frequency    = f,...
                amplitude    = ModDepth,...
                offset       = MeanDepth,...
                samplingRate = sr,...
                duration     = duration,...
                phase        = phi ...
                );
            
            targetWf = SineWave(...
                frequency    = f,...
                amplitude    = range(kdCalib(depthWf.Sample)) * rollOff,...
                offset       = kdCalib(depthWf.Offset),...
                samplingRate = sr,...
                duration     = duration,...
                phase        = depthWf.Phase ...
                );
            targetWfl = WaveformList("1",waveformOrigin = {targetWf},samplingRate = sr);
        end

        function targetWfl = getKpRampTarget(obj,chIdx,V0,alpha,beta, rampTimeSet)
            if nargin<6
                rampTimeSet=obj.RampTime;
            end
            % Get the target optical waveform for the given KP parameters
            calibName = "KP" + chIdx + "Depth2Pd";
            kdCalib = loadVar("LatticeCalib.mat",calibName);
            sr = obj.SamplingRateRamp;

            phi = obj.getPhaseTarget(V0,alpha,beta);
            % if obj.IsInverted
            %     phi = asin(-2/alpha/beta);
            % else
            %     phi = 0;
            % end
            % phi = real(phi);

            if obj.IsUseCorrection
                V0=V0*obj.CorrFactor(chIdx);
            end

            if chIdx == 1
                VRamp = alpha/2 * V0 * (1 + beta * sin(phi + pi));
            else
                VRamp = (alpha/2 +1) * V0 * (1 + beta * alpha / (alpha + 2) * sin(phi));
            end
            wfRamp = TanhRamp(...
                duration=rampTimeSet,...
                rampTime=rampTimeSet,...
                startValue=kdCalib(0),...
                stopValue=kdCalib(VRamp),samplingRate = sr);

            targetWfl = WaveformList("1",waveformOrigin = {wfRamp},samplingRate = sr);
        end

        function targetWfl = getTanhRampTarget(obj,chIdx,Vinit, V0, rampTimeSet)
            %Extracts a waveformlist with a tanhramp with given parameters
            %without relying on alpha and beta for the waveform, just
            %expecte lattice depths in Er. 
            if nargin<5
                rampTimeSet=obj.RampTime;
            end

            if obj.IsUseCorrection
                V0=V0*obj.CorrFactor(chIdx);
                Vinit=Vinit*obj.CorrFactor(chIdx);
            end
            % Get the target optical waveform for the given KP parameters
            calibName = "KP" + chIdx + "Depth2Pd";
            kdCalib = loadVar("LatticeCalib.mat",calibName);
            sr = obj.SamplingRateRamp;
            wfRamp = TanhRamp(...
                duration=rampTimeSet,...
                rampTime=rampTimeSet,...
                startValue=kdCalib(Vinit),...
                stopValue=kdCalib(V0),samplingRate = sr);
            targetWfl = WaveformList("1",waveformOrigin = {wfRamp},samplingRate = sr);
        end

        function phi = getPhaseTarget(obj,V0,alpha,beta)
            VTarget = obj.getInitialDepthTarget(V0);
            if obj.IsInverted
                VTarget = - VTarget;
            end

            phi = asin((VTarget/V0 - 1)/alpha/beta);
            if ~isreal(phi)
                warning("The phase is not real. Check your VTarget, alpha, beta values")
                phi = real(phi);
            end
        end

        function VTarget = getInitialDepthTarget(obj,V0)
            if ~isempty(obj.InitialDepth)
                VTarget = obj.InitialDepth;
            else
                VTarget = V0;
            end
        end

        function controlWfl = predictKp(obj,chIdx,V0,f,alpha,beta,nCycle,rampTime,isBm, isrunningExp, bmTime)
            if nargin<10
                isrunningExp=0;
            end

            if nargin<11
                bmTime=obj.BmTime;
            else
                obj.BmTime=bmTime;
            end

            if isrunningExp
                obj.IsTraining=0;
            end

            if nCycle > 0
                wflMod = obj.predictKpMod(chIdx,V0,f,alpha,beta,nCycle,1,false);
            end
            wflRamp = obj.predictKpRamp(chIdx,V0,alpha,beta,1,false,rampTime);
            if nCycle > 0
                rampSample = wflRamp.Sample;
                endControlVal = rampSample(end);
                tTriansient = obj.IgnoredTime * 2;
                nS = tTriansient * obj.SamplingRateAwg;
                sIdx = 1:nS;
                wfMod = wflMod.WaveformOrigin{1};
                if obj.IsRampUpModulation
                    wfMod.SampleData(sIdx) = endControlVal * flip(sIdx-1)/(nS-1) + wfMod.SampleData(sIdx).' .* (sIdx-1)/(nS-1);
                end
                if isBm
                    % the next 6  lines are for no Bm training
                    % wfRampDown = LinearRamp(...
                    %     duration = obj.BmTime,...
                    %     rampTime = obj.BmTime,...
                    %     startValue = wfMod.SampleData(end),...
                    %     stopValue = -0.5);
                    % controlWfl = WaveformList("c",waveformOrigin={wflRamp.WaveformOrigin{1},wfMod,wfRampDown},samplingRate = obj.SamplingRateAwg);
                    
                    %Use next two lines if trying to use training for kprampdown (other option is above):              
                    wfRampDown = obj.predictKpRamp(chIdx,V0,alpha,beta,1,false, obj.BmTime, false);
                    controlWfl = WaveformList("c",waveformOrigin={wflRamp.WaveformOrigin{1},wfMod,wfRampDown.WaveformOrigin{1}},samplingRate = obj.SamplingRateAwg);
                else
                    controlWfl = WaveformList("c",waveformOrigin={wflRamp.WaveformOrigin{1},wfMod},samplingRate = obj.SamplingRateAwg);
                end
            else
                if isBm
                    % wfRampDown = LinearRamp(...
                    %     duration = obj.BmTime,...
                    %     rampTime = obj.BmTime,...
                    %     startValue = wflRamp.Sample(end),...
                    %     stopValue = -0.5);
                    % controlWfl = WaveformList("c",waveformOrigin={wflRamp.WaveformOrigin{1},wfRampDown},samplingRate = obj.SamplingRateAwg);
                    % Use lines for KpRampDown with training.
                    wfRampDown = obj.predictKpRamp(chIdx,V0,alpha,beta,1,false, obj.BmTime, false);
                    controlWfl = WaveformList("c",waveformOrigin={wflRamp.WaveformOrigin{1},wfRampDown.WaveformOrigin{1}},samplingRate = obj.SamplingRateAwg);
                else
                    controlWfl = wflRamp;
                end
            end
        end

        function [controlWfl,targetWfl,isExact] = predictKpMod(obj,chIdx,V0,f,alpha,beta,nCycle,laserPower,isDc,phi)
            % Predict control waveform from KP parameters
            [~,isExact] = obj.findKpModData(chIdx,V0,f,alpha,beta);
            sr = obj.SamplingRateAwg;
            duration = 1/f * nCycle;
            targetWfl = obj.getKpModTarget(chIdx,V0,f,alpha,beta,nCycle);
            targetWf = targetWfl.WaveformOrigin{1};
            if nargin == 10
                targetWf.Phase = phi;
            end
            if ~isreal(targetWf.Phase)
                warning("Wrong target phase.")
                targetWf.Phase = real(targetWf.Phase);
            end
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            if isDc
                rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                controlWf.SampleData = controlWfSampe;
                controlWf.TimeData = tList;
            elseif obj.Method == "ILC"
                nRs = 1;
                % tCut = obj.IgnoredTime;
                [controlVoltage,isExact] = obj.findKpModData(chIdx,V0,f,alpha,beta);
                % controlVoltage = resample(controlVoltage,sr * nRs, sr);
                sr = sr * nRs;
                T = 1/f;
                nIgnoredCycle = 1;
                num_periods = floor(length(controlVoltage) / (T * sr));
                L_analysis = round(num_periods * T * sr);
                x_trunc = controlVoltage(1:L_analysis);
                t_orig = 0:1/sr:numel(controlVoltage)/sr*2;
                t_orig = t_orig(1:numel(controlVoltage));
                t_trunc = t_orig(1:L_analysis);
                sPerCycle = round(T * sr);
                x_trunc = x_trunc(sPerCycle * nIgnoredCycle + 1:end-sPerCycle * nIgnoredCycle);
                t_trunc = t_trunc(sPerCycle * nIgnoredCycle + 1:end-sPerCycle * nIgnoredCycle);
                L_analysis = numel(x_trunc);
                
                % Define how many harmonics to extract (up to Nyquist)
                % max_k = floor((sr/2) / f); % Divided the number of orders by ten to save time
                max_k = 40;
                ck = zeros(max_k + 1, 1); % Store complex coefficients

                for k = 0:max_k
                    % Create the complex exponential basis function for this harmonic
                    basis = exp(-1j * 2 * pi * k * f * t_trunc);

                    % Project the signal onto the basis (The Discrete Fourier Integral)
                    % This is the manual equivalent of the FFT at a specific frequency
                    ck(k+1) = (1/L_analysis) * sum(x_trunc .* basis);
                end

                %% 3. Reconstruction for New Duration
                % tic;
                new_duration = (nCycle+2 * nIgnoredCycle) / f;
                t_new = (0:1/sr:new_duration-1/sr)';
                reconstructed = zeros(size(t_new));
                % Sum the harmonics (Synthesis)
                % We skip k=0 (DC) in the loop and add it separately
                tShift = mod(targetWf.Phase,2*pi) / 2 / pi * T;
                t = t_new + tShift;
                for k = 1:max_k
                    % We use 2 * real(ck * exp(jwt)) to account for negative frequencies
                    reconstructed = reconstructed + ...
                        2 * real(ck(k+1) * exp(1j * 2 * pi * k * f * t));
                end

                % kList = (1:max_k).';
                % TT = exp(1j * 2 * pi * kList * f * t.');
                % reconstructed = 2 * real(ck(2:max_k+1).' * TT).';
                % toc;

                % Add the DC offset (k=0)
                controlVoltage = reconstructed + real(ck(1));
                controlVoltage = resample(controlVoltage,sr/nRs,sr);
                sPerCycle = round(T * sr/nRs);
                controlVoltage = controlVoltage(sPerCycle * nIgnoredCycle + 1:end-sPerCycle*nIgnoredCycle);


                tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime * 2;
                tList = tList(1:numel(controlVoltage));
                controlWf = InterpolatedWaveform(duration = range(tList),samplingRate=sr);
                controlWf.SampleData = controlVoltage;
                controlWf.TimeData = tList;
                targetWfl.WaveformOrigin{1}.Duration = tList(end) - tList(1);
            else
                controlWf = obj.predictAwg(chIdx,targetWf,laserPower);
            end
            controlWfl = WaveformList("1",waveformOrigin={controlWf},samplingRate=sr);
        end

        function [controlWfl,targetWfl,isExact] = predictSineMod(obj,chIdx,V0,f,ModDepth,nCycle,laserPower,isDc,phi)
            % Predict control waveform from KP parameters
            [~,isExact,~,~] = obj.findSineModData(chIdx,V0,f,ModDepth);
            sr = obj.SamplingRateAwg;
            duration = 1/f * nCycle;
            targetWfl = obj.getGenModTarget(chIdx,V0,f,ModDepth,nCycle);
            targetWf = targetWfl.WaveformOrigin{1};
            if nargin == 9
                targetWf.Phase = phi;
            end
            if ~isreal(targetWf.Phase)
                warning("Wrong target phase.")
                targetWf.Phase = real(targetWf.Phase);
            end
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            if isDc
                rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                controlWf.SampleData = controlWfSampe;
                controlWf.TimeData = tList;
            elseif obj.Method == "ILC"
                nRs = 1;
                % tCut = obj.IgnoredTime;
                [controlVoltage,isExact,~,success] = obj.findSineModData(chIdx,V0,f,ModDepth);
                if ~success
                    rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                    controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                    controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                    controlWf.SampleData = controlWfSampe;
                    controlWf.TimeData = tList;
                else
                    % controlVoltage = resample(controlVoltage,sr * nRs, sr);
                    sr = sr * nRs;
                    T = 1/f;
                    nIgnoredCycle = 1;
                    num_periods = floor(length(controlVoltage) / (T * sr));
                    L_analysis = round(num_periods * T * sr);
                    x_trunc = controlVoltage(1:L_analysis);
                    t_orig = 0:1/sr:numel(controlVoltage)/sr*2;
                    t_orig = t_orig(1:numel(controlVoltage));
                    t_trunc = t_orig(1:L_analysis);
                    sPerCycle = round(T * sr);
                    x_trunc = x_trunc(sPerCycle * nIgnoredCycle + 1:end-sPerCycle * nIgnoredCycle);
                    t_trunc = t_trunc(sPerCycle * nIgnoredCycle + 1:end-sPerCycle * nIgnoredCycle);
                    L_analysis = numel(x_trunc);
                    
                    % Define how many harmonics to extract (up to Nyquist)
                    % max_k = floor((sr/2) / f); % Divided the number of orders by ten to save time
                    max_k = 40;
                    ck = zeros(max_k + 1, 1); % Store complex coefficients
    
                    for k = 0:max_k
                        % Create the complex exponential basis function for this harmonic
                        basis = exp(-1j * 2 * pi * k * f * t_trunc);
    
                        % Project the signal onto the basis (The Discrete Fourier Integral)
                        % This is the manual equivalent of the FFT at a specific frequency
                        ck(k+1) = (1/L_analysis) * sum(x_trunc .* basis);
                    end
    
                    %% 3. Reconstruction for New Duration
                    % tic;
                    new_duration = (nCycle+2 * nIgnoredCycle) / f;
                    t_new = (0:1/sr:new_duration-1/sr)';
                    reconstructed = zeros(size(t_new));
                    % Sum the harmonics (Synthesis)
                    % We skip k=0 (DC) in the loop and add it separately
                    tShift = mod(targetWf.Phase,2*pi) / 2 / pi * T;
                    t = t_new + tShift;
                    for k = 1:max_k
                        % We use 2 * real(ck * exp(jwt)) to account for negative frequencies
                        reconstructed = reconstructed + ...
                            2 * real(ck(k+1) * exp(1j * 2 * pi * k * f * t));
                    end
    
                    % kList = (1:max_k).';
                    % TT = exp(1j * 2 * pi * kList * f * t.');
                    % reconstructed = 2 * real(ck(2:max_k+1).' * TT).';
                    % toc;
    
                    % Add the DC offset (k=0)
                    controlVoltage = reconstructed + real(ck(1));
                    controlVoltage = resample(controlVoltage,sr/nRs,sr);
                    sPerCycle = round(T * sr/nRs);
                    controlVoltage = controlVoltage(sPerCycle * nIgnoredCycle + 1:end-sPerCycle*nIgnoredCycle);
    
    
                    tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime * 2;
                    tList = tList(1:numel(controlVoltage));
                    controlWf = InterpolatedWaveform(duration = range(tList),samplingRate=sr);
                    controlWf.SampleData = controlVoltage;
                    controlWf.TimeData = tList;
                    targetWfl.WaveformOrigin{1}.Duration = tList(end) - tList(1);
                end
            else
                controlWf = obj.predictAwg(chIdx,targetWf,laserPower);
            end
            controlWfl = WaveformList("1",waveformOrigin={controlWf},samplingRate=sr);
        end

        function [controlWfl,targetWfl,isExact] = predictKpRamp(obj,chIdx,V0,alpha,beta,laserPower,isDc, rampTime, isRampup)
            if nargin<8
                rampTime=obj.RampTime;
            end

            if nargin<9
                isRampup=true;
            end
            % Predict control waveform from KP parameters
            isExact = false;
            if obj.IsTraining
                sr = obj.SamplingRateRamp;
            else
                sr = obj.SamplingRateAwg;
            end
            duration = rampTime;
            targetWfl = obj.getKpRampTarget(chIdx,V0,alpha,beta, duration);

            targetWf = targetWfl.WaveformOrigin{1};
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            if isDc
                rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                controlWf.SampleData = controlWfSampe;
                controlWf.TimeData = tList;
            elseif obj.Method == "ILC"
                targetDepth = obj.getInitialDepthTarget(V0);
                nCut = 2500;
                tList = targetWf.StartTime :(1/sr) : targetWf.EndTime;
                [controlVoltage,isExact] = obj.findKpRampData(chIdx,V0,alpha,beta,obj.IsInverted,targetDepth, rampTime);
                controlVoltage = resample(controlVoltage,sr,obj.SamplingRateRampSave);
                controlVoltage(1:nCut) = repmat(mean(controlVoltage(nCut+1:nCut*2)),1,nCut);
                controlVoltage(end-nCut+1:end) = repmat(mean(controlVoltage(end-nCut*2+1:end-nCut)),1,nCut);
                controlVoltage = controlVoltage(1:numel(tList));
                controlWf = InterpolatedWaveform(duration = range(tList),samplingRate=sr);
                controlWf.SampleData = controlVoltage;
                controlWf.TimeData = tList;
                targetWfl.WaveformOrigin{1}.Duration = tList(end) - tList(1);
            else
                controlWf = obj.predictAwg(chIdx,targetWf,laserPower);
            end
            if ~isRampup
                controlWf.SampleData=flip(controlWf.SampleData);
            end

            

            controlWfl = WaveformList("1",waveformOrigin={controlWf},samplingRate=sr);
        end

        function [controlWfl,targetWfl,isExact] = predictTanhRamp(obj,chIdx,Vinit, V0, laserPower, isDc, rampTime)
            if nargin<7
                rampTime=obj.RampTime;
            end

            
            % Predict control waveform from KP parameters
            isExact = false;
            if obj.IsTraining
                sr = obj.SamplingRateRamp;
            else
                sr = obj.SamplingRateAwg;
            end
            duration = rampTime;
            targetWfl = obj.getTanhRampTarget(chIdx,Vinit, V0, duration);

            targetWf = targetWfl.WaveformOrigin{1};
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            if isDc
                rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                controlWf.SampleData = controlWfSampe;
                controlWf.TimeData = tList;
            elseif obj.Method == "ILC" %% This is the tricky one as it needs to handle the absence of the waveform for now and not extract from the empty dataset
                targetDepth = obj.getInitialDepthTarget(V0);
                nCut = 2500;
                tList = targetWf.StartTime :(1/sr) : targetWf.EndTime;
                [controlVoltage,isExact, ~, success] = obj.findTanhRampData(chIdx,Vinit, V0,rampTime); %This is the line to change, need to work with new dataset
                
                if success

                controlVoltage = resample(controlVoltage,sr,obj.SamplingRateRampSave);
                controlVoltage(1:nCut) = repmat(mean(controlVoltage(nCut+1:nCut*2)),1,nCut);
                controlVoltage(end-nCut+1:end) = repmat(mean(controlVoltage(end-nCut*2+1:end-nCut)),1,nCut);
                controlVoltage = controlVoltage(1:numel(tList));
                controlWf = InterpolatedWaveform(duration = range(tList),samplingRate=sr);
                controlWf.SampleData = controlVoltage;
                controlWf.TimeData = tList;
                targetWfl.WaveformOrigin{1}.Duration = tList(end) - tList(1);

                else
                    disp('Could not extract ramp data, guessing using transfer functions');
                    rampCalib = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
                    controlWfSampe = slmeval(targetWf.Sample,rampCalib);
                    controlWf = InterpolatedWaveform(duration = duration,samplingRate=sr);
                    controlWf.SampleData = controlWfSampe;
                    controlWf.TimeData = tList;
                end
            else
                controlWf = obj.predictAwg(chIdx,targetWf,laserPower);
            end
            

            controlWfl = WaveformList("1",waveformOrigin={controlWf},samplingRate=sr);
        end

        function controlWfl = predictAwg(obj,chIdx,targetWf,laserPower)
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            ns = numel(targetWf.Sample);
            switch obj.Method
                case "LSTM"
                    if obj.IsIncludeAmpOffset
                        predictedAwg = obj.mlWf2realWf(predict(obj.Network{chIdx},...
                            [obj.realScope2MlScope(chIdx,targetWf.Sample,laserPower);...
                            ones(1,ns)*targetWf.Amplitude/2 ./ obj.AmplitudeMaximum(chIdx) * 2;...
                            obj.realScope2MlScope(chIdx,ones(1,ns)*targetWf.Offset,laserPower)...
                            ]));
                    else
                        predictedAwg = obj.mlWf2realWf(predict(obj.Network{chIdx},...
                            [obj.realScope2MlScope(chIdx,targetWf.Sample,laserPower);...
                            ]));
                    end
                case "NARX"
                    ideal_target_mapped = obj.realScope2MlScope(chIdx,targetWf.Sample,laserPower);
                    ideal_target_cell = con2seq(ideal_target_mapped);
                    % 1. Find the maximum delay your network requires
                    % MATLAB stores this automatically in the numInputDelays property
                    net_open = obj.Network{chIdx};
                    max_delay = net_open.numInputDelays;

                    % 2. Extract EXACTLY that many points from the very end of your last DAgger iteration
                    last_X = obj.Dataset(chIdx).X{end}(:, end-max_delay+1:end);
                    last_Y = obj.Dataset(chIdx).Y{end}(:, end-max_delay+1:end);

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
                case "MLP"
                    % Define a new desired sine wave target
                    target_Amp = targetWf.Amplitude;       % Volts
                    target_Offset = targetWf.Offset;    % Volts
                    target_Freq = targetWf.Frequency;    % MHz
                    target_Phase = targetWf.Phase;

                    X_new = [target_Freq; target_Amp; target_Offset];

                    % Predict the Fourier coefficients
                    Y_pred = obj.Network{chIdx}(X_new);
                    % Extract coefficients
                    a0 = Y_pred(1);
                    ab_coeffs = Y_pred(2:end); % [a1; b1; a2; b2; ...]

                    % Setup time vector for exactly one period of the target frequency
                    omega = 2 * pi * target_Freq;

                    % Reconstruct the signal
                    predictedAwg = a0 * ones(size(tList)); % Start with DC component

                    for k = 1:numel(ab_coeffs)/2
                        idx_a = 2*k - 1;
                        idx_b = 2*k;

                        ak = ab_coeffs(idx_a);
                        bk = ab_coeffs(idx_b);

                        % Add the k-th harmonic
                        predictedAwg = predictedAwg +...
                            ak * cos(k * omega * tList + k * (target_Phase - 3 * pi / 2)) +...
                            bk * sin(k * omega * tList + k * (target_Phase - 3 * pi / 2));
                    end
            end
            awgSr = obj.SamplingRateAwg;
            controlWfl = InterpolatedWaveform(duration = targetWf.Duration,samplingRate=awgSr);
            controlWfl.TimeData = tList;
            controlWfl.SampleData = predictedAwg;
            

        end

        function updateNetwork(obj)
            tic
            for chIdx = 1:obj.NChannel
                switch obj.Method
                    case "LSTM"
                        obj.Network{chIdx} = trainNetwork(obj.Dataset(chIdx).X, obj.Dataset(chIdx).Y,...
                            obj.NetworkLayers, obj.NetworkOptions);
                        delete(findall(0, 'Type', 'figure', 'Tag', 'NNET_CNN_TRAININGPLOT_UIFIGURE'));
                    case "NARX"
                        num_batches = length(obj.Dataset(chIdx).X);
                        num_timesteps = size(obj.Dataset(chIdx).X{1}, 2);  % e.g., 20000
                        num_features_X = size(obj.Dataset(chIdx).X{1}, 1); % e.g., 3 (Scope Trace, Amp, Offset)
                        num_features_Y = size(obj.Dataset(chIdx).Y{1}, 1); % e.g., 1 (AWG command)

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
                                x_step(:, b) = obj.Dataset(chIdx).X{b}(:, t);
                                y_step(:, b) = obj.Dataset(chIdx).Y{b}(:, t);
                            end

                            % Store the batch matrix in the cell array
                            X_cell{1, t} = x_step;
                            Y_cell{1, t} = y_step;
                        end
                        % combined_inputs = [X_cell; Y_cell];
                        [Xs, Xi, Ai, Ys] = preparets(obj.Network{chIdx}, X_cell, {}, Y_cell);

                        % Train the network using actual measured scope and actual applied AWG data
                        obj.Network{chIdx} = train(obj.Network{chIdx}, Xs, Ys, Xi, Ai);
                    case "MLP"
                        [obj.Network{chIdx}, ~] = train(obj.Network{chIdx}, cell2mat(obj.Dataset(chIdx).KpParameter), cell2mat(obj.Dataset(chIdx).Y));
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

        function saveObj(obj)
            kpp = obj;
            folderName = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
            save(fullfile(folderName,"KppData_" + string(datetime,'yyyy_MM_dd_HH_mm_ss') + ".mat"),"kpp")
        end

        function sendAndRead(obj,wfl,waitTime)
            if nargin == 2
                waitTime = 0.3;
            end
            obj.MainAwg.WaveformList = wfl;
            obj.MainAwg.set
            if obj.IsUsingSpectrum
                pause(0.1)
                obj.MainAwg.upload
            end
            obj.PulseAwg.trigger
            pause(waitTime)
            obj.Scope.read
        end

        function laserPower = measureLaserPower(obj)
            % Measure reference laser power for KP1 and KP2
            if obj.IsNormalizeToLaserPower
                pause(0.3)
                wfl = WaveformList("const",waveformOrigin = { ...
                    ConstantWave(duration = obj.Scope.Duration * 1.2, offset = 0)...
                    });
                obj.sendAndRead({wfl,wfl})
                delayPoints = obj.DelayFunc * obj.SamplingRateScope;
                ignoredPoints = obj.IgnoredTime * obj.SamplingRateScope;
                nPoints = round(delayPoints + ignoredPoints);
                laserPower = mean(obj.Scope.Sample(:,nPoints:end),2);
                pause(0.3)
            else
                laserPower = [1;1];
            end
        end

        function [controlMl,targetMl,scopeMl] =  processData(obj,chIdx,targetWf,laserPower,isSaveDelay,isSaveData,isIgnore)
            arguments
                obj KpPredistortion
                chIdx = 1
                targetWf = []
                laserPower = 1
                isSaveDelay = false
                isSaveData = true
                isIgnore = true
            end
            if isIgnore
                ignoredPoints = obj.NIgnoredSample;
            else
                ignoredPoints = 0;
            end
            scopeSr = obj.Scope.SamplingRate;
            awgSr = obj.MainAwg.SamplingRate(1);
            mlSr = awgSr;
            if isSaveData
                obj.Dataset(chIdx).LaserPower(obj.RunIdx) = laserPower;
            end
            scopeRaw = obj.Scope.Sample(chIdx,:);
            awgRaw = obj.MainAwg.WaveformList{chIdx}.Sample;
            awgUp = resample(awgRaw, scopeSr, awgSr);

            %% Compute delay
            if  (obj.Method ~= "MLP" && obj.Method ~= "ILC")
                if isSaveDelay
                    obj.Delay(chIdx) = finddelay(awgUp, scopeRaw);
                end
                if obj.Delay(chIdx) > 0
                    % Scope is delayed relative to AWG (Expected physical reality)
                    scopeAligned = scopeRaw(obj.Delay(chIdx)+1:end);
                else
                    error("Delay is found to be negative. Check if you have a signal.")
                end
            else
                if isfield(targetWf,"Frequency")
                    f = targetWf.Frequency;
                else
                    f = obj.FrequencyRange(1);
                end
                delay = obj.DelayFunc{chIdx}(f);
                delay = round(delay * scopeSr / obj.SamplingRateScope);
                scopeAligned = scopeRaw(delay+1:end);
            end

            %% Resample to match the machine learning sampling rate
            scopeMl = resample(scopeAligned, mlSr, scopeSr);
            controlMl   = resample(awgRaw, mlSr, awgSr);

            %% Ensure they match exactly in length
            minLen = min(length(scopeMl), length(controlMl));
            scopeMl = scopeMl(1+ignoredPoints:minLen-ignoredPoints);
            controlMl = controlMl(1+ignoredPoints:minLen-ignoredPoints);
            scopeMl = reshape(scopeMl, 1, []);
            controlMl = reshape(controlMl, 1, []);
            controlMl = obj.realWf2MlWf(controlMl);
            scopeMl = obj.realScope2MlScope(chIdx,scopeMl,laserPower);
            if ~isempty(targetWf)
                targetMl = resample(targetWf.Sample, mlSr, awgSr);
                targetMl = targetMl(1+ignoredPoints:minLen-ignoredPoints);
            else
                targetMl = ones(1,numel(controlMl)) * obj.AmplitudeMaximum(chIdx)/2;
            end
            targetMl = obj.realScope2MlScope(chIdx,targetMl,laserPower);

            %% Save data
            if isSaveData
                obj.Dataset(chIdx).Y{obj.RunIdx} = controlMl;
                obj.Dataset(chIdx).XTarget{obj.RunIdx} = targetMl;
                if ~obj.IsIncludeAmpOffset
                    obj.Dataset(chIdx).X{obj.RunIdx} = scopeMl;
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
                    obj.Dataset(chIdx).X{obj.RunIdx} = [scopeMl;amp;offset];
                end
            end
        end

        function computeError(obj,batchIdx)
            for b = batchIdx
                runIdx = ((2 + obj.NOffset) + (b-1) * obj.NBatch) : ((1 + obj.NOffset) + (b) * obj.NBatch);
                for chIdx = 1:obj.NChannel
                    be = zeros(1,obj.NBatch);
                    for jj = 1:obj.NBatch
                        measured =  obj.mlScope2realScope(chIdx,obj.Dataset(chIdx).X{runIdx(jj)}(1,:),obj.Dataset(chIdx).LaserPower(runIdx(jj)));
                        target = obj.Dataset(chIdx).XTarget{runIdx(jj)}(1,:);
                        offset = mean(target);
                        be(jj) = obj.computeErrorRaw(measured,target,offset);
                    end
                    obj.BatchError(chIdx,b) = mean(be);
                    obj.BatchErrorStd(chIdx,b) = std(be);
                end
            end
        end

        function er = computeErrorRaw(obj,measured,target,offset)
            arguments
                obj
                measured
                target
                offset = 0.5
            end
            if obj.IsNormalizeError
                er = rms(measured - target)/offset;
            else
                er = rms(measured - target);
            end
        end

        function [controlVoltage,isExact,runIdx] = findKpModData(obj,chIdx,V0,f,alpha,beta)
            % Find the best matched KP control waveform from the dataset,
            % then determine if this is an exact match
            A = cell2mat(obj.Dataset(chIdx).KpParameter);
            v = [V0;f;alpha;beta];
            mu = mean(A, 2);
            sig = std(A, 0, 2);
            sig(sig==0) = mu(sig == 0);
            A_norm = (A - mu) ./ sig;
            v_norm = (v - mu) ./ sig;
            [~, runIdx] = min(vecnorm(A_norm - v_norm));
            if isempty(runIdx)
                error("can not find matching KP record")
            end
            controlVoltage = obj.Dataset(chIdx).Y{runIdx};
            isExact = all(v == A(:,runIdx));
            
        end

        function [controlVoltage,isExact,runIdx,success] = findSineModData(obj,chIdx,V0,f,ModDepth)
            % Find the best matched KP control waveform from the dataset,
            % then determine if this is an exact match
            try
            A = cell2mat(obj.Dataset(chIdx).SineModParameter);
            v = [V0;f;ModDepth];
            mu = mean(A, 2);
            sig = std(A, 0, 2);
            sig(sig==0) = mu(sig == 0);
            A_norm = (A - mu) ./ sig;
            v_norm = (v - mu) ./ sig;
            [~, runIdx] = min(vecnorm(A_norm - v_norm));
            if isempty(runIdx)
                error("can not find matching KP record")
            end
            controlVoltage = obj.Dataset(chIdx).SineMod{runIdx};
            isExact = all(v == A(:,runIdx));
            success=true;
            catch
                controlVoltage=zeros(1, 25);
                isExact=[0];
                success=false;
                runIdx=0;
            end
        end

        function [controlVoltage,isExact,runIdx] = findKpRampData(obj,chIdx,V0,alpha,beta,isInverted,targetDepth, rampTime)
            % Find the best matched KP control waveform from the dataset,
            % then determine if this is an exact match
            A = cell2mat(obj.Dataset(chIdx).KpRampParameter);
            v = [V0;alpha;beta;isInverted;targetDepth; rampTime];
            mu = mean(A, 2);
            sig = std(A, 0, 2);
            sig(sig==0) = mu(sig == 0);
            A_norm = (A - mu) ./ sig;
            v_norm = (v - mu) ./ sig;
            [~, runIdx] = min(vecnorm(A_norm - v_norm));
            if isempty(runIdx)
                error("can not find matching KP record")
            end
            controlVoltage = obj.Dataset(chIdx).YRamp{runIdx};
            isExact = all(v == A(:,runIdx));
        end

        function [controlVoltage,isExact,runIdx, success] = findTanhRampData(obj,chIdx,Vinit,V0,rampTime)
            % Find the best matched KP control waveform from the dataset,
            % then determine if this is an exact match

            try
            A = cell2mat(obj.Dataset(chIdx).TanhRampParameter);
            v = [Vinit; V0; rampTime];
            mu = mean(A, 2);
            sig = std(A, 0, 2);
            sig(sig==0) = mu(sig == 0);
            A_norm = (A - mu) ./ sig;
            v_norm = (v - mu) ./ sig;
            [~, runIdx] = min(vecnorm(A_norm - v_norm));
            if isempty(runIdx)
                error("can not find matching KP record")
            end
            controlVoltage = obj.Dataset(chIdx).TanhRamp{runIdx};
            isExact = all(v == A(:,runIdx));
            success=true;

            catch
               controlVoltage=zeros(1, 25);
               isExact = [0];
               success = false;
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

        function [controlWfl,targetWf] = guessFromDc(obj,f,amp,offset,rampCalib,phase)
            % Guess the control voltage from DC calibration
            targetWf = SineWave(...
                frequency    = f,...
                amplitude    = amp,...
                offset       = offset,...
                samplingRate = obj.SamplingRateAwg,...
                duration     = obj.SineDuration,...
                phase = phase ...
                );
            tList = targetWf.StartTime : targetWf.TimeStep : targetWf.EndTime;
            controlVoltage = slmeval(targetWf.Sample,rampCalib);
            guessWf = InterpolatedWaveform(duration = obj.SineDuration,samplingRate=obj.SamplingRateAwg);
            guessWf.SampleData = controlVoltage;
            guessWf.TimeData = tList;
            controlWfl = WaveformList("guess",samplingRate=obj.SamplingRateAwg,waveformOrigin={guessWf});
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
            for chIdx = 1:obj.NChannel
                ax = nexttile(chIdx);
                scopeMl = obj.mlScope2realScope(chIdx,obj.Dataset(chIdx).X{runIdx}(1,:),obj.Dataset(chIdx).LaserPower(runIdx));
                awgMl = obj.mlWf2realWf(obj.Dataset(chIdx).Y{runIdx}(1,:));
                targetMl = obj.Dataset(chIdx).XTarget{runIdx}(1,:);
                nSample = numel(scopeMl);
                t = 0:(1/sr):(nSample/sr - 1/sr);
                tIdx = t>=timeRange(1) & t<=timeRange(2);
                t = t * 1e3;
                plot(ax,t(tIdx),scopeMl(tIdx),t(tIdx),targetMl(tIdx))
                xlabel("Time [ms]")
                ylabel("Photodiode Voltage [V]")
                legend("Measured","Target")
                ax.Title.String = "KP" + chIdx;

                ax = nexttile(2 + chIdx);
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
            for chIdx = 1:obj.NChannel
                eb(chIdx) = errorbar(iter,obj.BatchError(chIdx,:),obj.BatchErrorStd(chIdx,:),'.');
                legend(eb(chIdx),"KP"+chIdx)
            end
            hold off
            xlabel("Iteration Number")
            if obj.IsNormalizeError
                ylabel("Normalized Batch RMS Error")
            else
                ylabel("Batch RMS Error [V]")
            end
            render
            for chIdx = 1:obj.NChannel
                eb(chIdx).LineStyle = '-';
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

        function setScopeSine(obj)
            % Set scope duration based on sine pulse duration
            obj.Scope.Duration = 10^round(log10(obj.SineDuration));
            obj.Scope.NSample = obj.SamplingRateScope * 10^round(log10(obj.SineDuration));
            obj.Scope.set
            % pause(0.3)
            obj.Scope.startFromEdge
        end

        function setScopeChirp(obj)
            % Set scope duration based on chirp pulse duration
            obj.Scope.Duration = 10^round(log10(obj.ChirpDuration));
            obj.Scope.NSample = obj.SamplingRateScope * 10^round(log10(obj.ChirpDuration));
            obj.Scope.set
            % pause(0.3)
            obj.Scope.startFromEdge
        end

        function setScopeRamp(obj)
            % obj.Scope.Duration = obj.RampTime;
            if obj.RampTime >= 200e-3
                obj.Scope.Duration = 500e-3;
            else
                obj.Scope.Duration = 20e-3;
            end
            obj.Scope.NSample = 1e6;
            obj.Scope.set
            % pause(0.3)
            obj.Scope.startFromEdge
        end
    
        function setScopeRangeKp(obj,V0,alpha)
            for chIdx = 1:obj.NChannel
                calibName = "KP" + chIdx + "Depth2Pd";
                kdCalib = loadVar("LatticeCalib.mat",calibName);
                if obj.IsUseCorrection
                    V0=V0*obj.CorrFactor(chIdx);
                end
                if chIdx == 1
                    VRange = kdCalib(alpha * V0) * 1.1;
                else
                    VRange = kdCalib((alpha + 1) * V0) * 1.1;
                end
                obj.Scope.VerticalRange(chIdx) = VRange;
                obj.Scope.VerticalOffset(chIdx) = -VRange/2 ;
            end
            obj.Scope.set
            obj.Scope.startFromEdge
            pause(0.5)
        end

        function setScopeRangeGen(obj,V0) %Just sets the range to go above +/- the value inputed for general scope range setting.
            for chIdx = 1:obj.NChannel
                calibName = "KP" + chIdx + "Depth2Pd";
                kdCalib = loadVar("LatticeCalib.mat",calibName);
                if obj.IsUseCorrection
                    V0=V0*obj.CorrFactor(chIdx);
                end
                VRange = kdCalib(V0) * 1.2;
                obj.Scope.VerticalRange(chIdx) = VRange;
                obj.Scope.VerticalOffset(chIdx) = -VRange/2 ;
            end
            obj.Scope.set
            obj.Scope.startFromEdge
            pause(0.5)
        end

        

        function UpdateKpRampDataset(obj)
            % for idx=1:2
            %     datasetlength=length(obj.Dataset(idx).KpRampParameter);
            %     A=cell2mat(obj.Dataset(idx).KpRampParameter);
            %     for ii=1:datasetlength
            %         clear Aset
            %         Aset=squeeze(A(:, ii));
            %         if length(Aset)<6
            %             Aset=[Aset;obj.RampTime];
            %             obj.Dataset(idx).KpRampParameter{ii}=Aset;
            %         end
            %     end
            % end
            % obj.Dataset(1).KpRampParameter(82:94)=[];
            % obj.Dataset(1).YRamp(82:94)=[];
            % obj.Dataset(2).KpRampParameter(82:94)=[];
            % obj.Dataset(1).YRamp(82:94)=[];
            % obj.RampTime=10e-3;
            obj.IsTraining=false;
            obj.saveObj;

        end
        
        function TrainTanhRamp(obj, InitVal, EndVal, RampTime, lowPassFreq, isPhaseFree, itercts)
            %Add params to fill the remaining waveforms
            if nargin<5
                lowPassFreq=1e3;
                sliderCt=1e4;
            else
                awgSr = obj.SamplingRateRamp;
                sliderCt=ceil(awgSr/lowPassFreq);
            end
            if nargin<6
                isPhaseFree=0;
            end
            if nargin<7
                itercts=50;
            end

            disp('ILC: gathering control voltage data for KP Ramp...')
            tic;
            obj.IsTraining = true; %Allows for switching of some hardware parameters for specificness to training.
            laserPower = obj.measureLaserPower;
            %% Set parameters and scope settings

            %Should I reconsider how this is done, so that I don't have to
            %reconnect the devices if its already connected during a higher
            %level connections.
                %Maybe this is better with some transient variables that
                %tell whether something is connected or not. 
            obj.setScopeRamp
            % nGrid = obj.NGrid;
            % laserPower = obj.measureLaserPower;
            rampCalib = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                rampCalib{chIdx} = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
            end
            ignoredPoints = obj.NIgnoredSample;
            
            awgSr = obj.SamplingRateRamp;
            obj.MainAwg.SamplingRate = [awgSr,awgSr];
            obj.MainAwg.set
            ignoredPoints = round(ignoredPoints * awgSr / obj.SamplingRateMl);

                
            obj.IsTraining=true;

            %% Training parameters
            nIter0 = itercts;        % How many times to update the waveform
            P = [0.6,0.6];
            eth0 = obj.ErrorThreshold;

            obj.setScopeRangeGen(max([InitVal,  EndVal])); %This needs to be modified, to avoid KpRampSpecificParameters

            nIter = nIter0;
            eth = eth0;

            %% Extract Target
            targetWf = cell(1,2);
            controlWfl = cell(1,2);
            isExact = [false,false];
            for chIdx = 1:obj.NChannel
                [controlWfl{chIdx},targetWfl,isExact(chIdx)] = obj.predictTanhRamp(...
                    chIdx,...
                    InitVal,...
                    EndVal,...
                    laserPower(chIdx),...
                    ~obj.IsGuessUsingOldData, ...
                    RampTime);
                targetWf{chIdx} = targetWfl.WaveformOrigin{1};
            end
            if obj.IsGuessUsingOldData && any(~isExact)
                for chIdx = 1:obj.NChannel
                    [controlWfl{chIdx},targetWfl,isExact(chIdx)] = obj.predictTanhRamp(...
                        chIdx,...
                        InitVal,...
                        EndVal,...
                        laserPower(chIdx),...
                        true,...
                        RampTime);
                    targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                end
            end
            %% Perform training
            errorHistory = cell(1,obj.NChannel);
            isConverged = zeros(1,obj.NChannel);
            for kk = 1:nIter
                if all(isConverged)
                    break
                end
                
                obj.sendAndRead(controlWfl,0.5)
                % pause(10e-3);
                % controlWfl = cell(1,2);
                for chIdx = 1:obj.NChannel 
                    %% Stop if converged
                    if isConverged(chIdx)
                        continue
                    end

                    %% Update P gain
                    if kk > 3 ...
                            && errorHistory{chIdx}(kk-1) - errorHistory{chIdx}(kk-2) > 0 ...
                            && errorHistory{chIdx}(kk-2) - errorHistory{chIdx}(kk-3) > 0
                        P(chIdx) = P(chIdx) * 0.8;
                    end

                    %% Update control voltage from error signal
                    tList = targetWf{chIdx}.StartTime : targetWf{chIdx}.TimeStep : targetWf{chIdx}.EndTime;
                    
                    [controlMl,targetMl,scopeMl] = obj.processData(chIdx,targetWf{chIdx},laserPower(chIdx),false,false,false);
                    controlMl = obj.mlWf2realWf(controlMl);
                    errorHistory{chIdx}(kk) = obj.computeErrorRaw(...
                        scopeMl(ignoredPoints+1:end - ignoredPoints),...
                        targetMl(ignoredPoints+1:end - ignoredPoints),...
                        obj.realScope2MlScope(chIdx,targetWf{chIdx}.StopValue/2,laserPower(chIdx))+1);
                    controlMl = controlMl + P(chIdx) * (targetMl - scopeMl);   
                    controlMl = max(min(controlMl, obj.VoltageRange(2)), obj.VoltageRange(1));
                    if isPhaseFree
                        [b,a] = butter(4, lowPassFreq/(awgSr/2), 'low');
                        controlMl = filtfilt(b,a,controlMl);
                    else
                        controlMl = lowpass(controlMl, lowPassFreq, awgSr);
                    end
                    controlMl = movmean(controlMl,sliderCt);
                    controlWf = InterpolatedWaveform(duration = targetWf{chIdx}.Duration,samplingRate=awgSr);
                    controlWf.TimeData = tList;
                    controlWf.SampleData = controlMl;
                    controlWfl{chIdx} = WaveformList("1",waveformOrigin={controlWf},samplingRate=awgSr);

                    %% Visualization
                    figure(3523+chIdx)
                    subplot(2,1,1);
                    plot(tList*1e3, obj.mlScope2realScope(chIdx,targetMl,laserPower(chIdx)), 'k--', 'LineWidth', 1.5); hold on;
                    plot(tList*1e3, obj.mlScope2realScope(chIdx,scopeMl,laserPower(chIdx)), 'r', 'LineWidth', 1); hold off;
                    title(sprintf(['KP',num2str(chIdx),', Iteration %d: Target vs Measured Output'], kk));
                    xlabel('Time (ms)'); ylabel('Voltage (V)');
                    legend('Target', 'Measured');

                    subplot(2,1,2);
                    semilogy(1:kk, errorHistory{chIdx}(1:kk), '-o', 'LineWidth', 1.5);
                    title('RMS Error Convergence');
                    xlabel('Iteration'); ylabel('Normalized RMS Error');
                    grid on;

                    drawnow;

                    %% Check if this channel is converged
                    if errorHistory{chIdx}(kk) < eth0
                        isConverged(chIdx) = 1;
                    end
                    if kk >= 10
                        histError = errorHistory{chIdx}(end-9:end);
                        if  std(histError) < eth0/3 || std(histError) / mean(histError) < 0.1 
                            isConverged(chIdx) = 1;
                        end
                    end
                end
            end

            %% Update dataset
            for chIdx = 1:obj.NChannel
                try
                    runIdx = numel(obj.Dataset(chIdx).TanhRampParameter) + 1;
                catch
                    runIdx = 1;
                end
                if isExact(chIdx)
                    [~,~,runIdxVal, success] = obj.findTanhRampData(chIdx,InitVal, EndVal, RampTime);
                    if success
                        runIdx=runIdxVal; %Prevents breaking if the field doesn't exist
                    end
                end
                obj.Dataset(chIdx).TanhRampParameter{runIdx} = [InitVal; EndVal; RampTime];
                obj.Dataset(chIdx).TanhRamp{runIdx} = resample(controlWfl{chIdx}.Sample,obj.SamplingRateRampSave,awgSr);
                % obj.Dataset(chIdx).XTarget{obj.RunIdx} = targetWf{chIdx}.Sample;
                % obj.Error(chIdx,runIdx) = errorHistory{chIdx}(end);
                % %Probably not set for arbitary errors yet
    
                disp("Tanh Ramp Ch " + chIdx + ", VInit = " + InitVal +" Er, V0 = " + EndVal + " Er,  RampTime = " + RampTime)
                disp("error: " + errorHistory{chIdx}(end))
            end
            % obj.RunIdx = runIdx + 1;

            obj.IsTraining = false;
            obj.saveObj
            obj.setHardware
            toc

        end
        

        function TrainModWaveform(obj, MeanDepth, ModFrequency, ModDepth)
            %% Set parameters
            obj.setScopeSine
            laserPower = obj.measureLaserPower;
            rampCalib = cell(1,obj.NChannel);
            for chIdx = 1:obj.NChannel
                rampCalib{chIdx} = loadVar("LatticeCalib.mat","KP" + chIdx + "Pd2Keysight");
            end
            ignoredPoints = obj.NIgnoredSample;
            awgSr = obj.SamplingRateAwg;

            %% Training parameters
            nIter0 = 50;        % How many times to update the waveform
            PRange = [0.6,0.6]/2;        % The "Proportional" gain range
            PFunc = @(f) (-tanh(2 * (f-100e3)/(1.2e6-100e3)) + 1) * range(PRange) + PRange(1); %Unsure how this is derived
            lowPassFreq = 10e6; % Low pass filter for the feedback
            eth0 = obj.ErrorThreshold;

            %% Main loop
            
            V0Target = MeanDepth;
            obj.setScopeRangeGen(MeanDepth+ModDepth)% (
                    
            %% Update training parameters
            % if alphaList(aa) <= 6
            %     nIter = nIter0 * 2;
            % else
            %     nIter = nIter0;
            % end
            nIter = nIter0;
            P = PFunc(ModFrequency) * ones(1,obj.NChannel);
            if ModFrequency >= 1.8e6
                eth = eth0 * 1.6;
            else
                eth = eth0;
            end

            %% Prepare target and initial control waveform guess
            targetWf = cell(1,2);
            controlWfl = cell(1,2);
            isExact = [false,false];
            nCycle = floor(obj.SineDuration * ModFrequency);
            for chIdx = 1:obj.NChannel
                [controlWfl{chIdx},targetWfl,isExact(chIdx)] = obj.predictSineMod(...
                    chIdx,...
                    MeanDepth,...
                    ModFrequency,...
                    ModDepth,...
                    nCycle,...
                    laserPower(chIdx),...
                    ~obj.IsGuessUsingOldData,...
                    0);
                targetWf{chIdx} = targetWfl.WaveformOrigin{1};
            end
                        if obj.IsGuessUsingOldData && any(~isExact)
                            for chIdx = 1:obj.NChannel
                                [controlWfl{chIdx},targetWfl,~] = obj.predictKpMod(...
                                    chIdx,...
                                    MeanDepth,...
                                    ModFrequency,...
                                    ModDepth,...
                                    nCycle,...
                                    laserPower(chIdx),...
                                    true,...
                                    0);
                                targetWf{chIdx} = targetWfl.WaveformOrigin{1};
                            end
                        end
                        % if obj.IsGuessUsingOldData && all(isExact)
                        %     nIter = round(nIter/5);
                        % end

                        %% Perform training
                        errorHistory = cell(1,obj.NChannel);
                        isConverged = zeros(1,obj.NChannel);
                        for kk = 1:nIter
                            if all(isConverged)
                                break
                            end
                            obj.sendAndRead(controlWfl)
                            % controlWfl = cell(1,2);
                            for chIdx = 1:obj.NChannel 
                                %% Stop if converged
                                if isConverged(chIdx)
                                    continue
                                end

                                %% Update P gain
                                if kk > 3 ...
                                        && errorHistory{chIdx}(kk-1) - errorHistory{chIdx}(kk-2) > 0 ...
                                        && errorHistory{chIdx}(kk-2) - errorHistory{chIdx}(kk-3) > 0
                                    P(chIdx) = P(chIdx) * 0.8;
                                end

                                %% Update control voltage from error signal
                                tList = targetWf{chIdx}.StartTime : targetWf{chIdx}.TimeStep : targetWf{chIdx}.EndTime;
                                [controlMl,targetMl,scopeMl] = obj.processData(chIdx,targetWf{chIdx},laserPower(chIdx),false,false,false);
                                controlMl = obj.mlWf2realWf(controlMl);
                                errorHistory{chIdx}(kk) = obj.computeErrorRaw(...
                                    scopeMl(ignoredPoints+1:end - ignoredPoints),...
                                    targetMl(ignoredPoints+1:end - ignoredPoints),...
                                    obj.realScope2MlScope(chIdx,targetWf{chIdx}.Offset,laserPower(chIdx))+1);
                                controlMl = controlMl + P(chIdx) * (targetMl - scopeMl);
                                controlMl = lowpass(controlMl, lowPassFreq, awgSr);
                                controlMl = max(min(controlMl, obj.VoltageRange(2)), obj.VoltageRange(1));
                                controlWf = InterpolatedWaveform(duration = targetWf{chIdx}.Duration,samplingRate=awgSr);
                                controlWf.TimeData = tList;
                                controlWf.SampleData = controlMl;
                                controlWfl{chIdx} = WaveformList("1",waveformOrigin={controlWf},samplingRate=awgSr);

                                %% Visualization
                                figure(3523+chIdx)
                                subplot(2,1,1);
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,targetMl,laserPower(chIdx)), 'k--', 'LineWidth', 1.5); hold on;
                                plot(tList*1e6, obj.mlScope2realScope(chIdx,scopeMl,laserPower(chIdx)), 'r', 'LineWidth', 1); hold off;
                                title(sprintf(['KP',num2str(chIdx),', Iteration %d: Target vs Measured Output'], kk));
                                xlabel('Time (us)'); ylabel('Voltage (V)');
                                legend('Target', 'Measured');

                                subplot(2,1,2);
                                semilogy(1:kk, errorHistory{chIdx}(1:kk), '-o', 'LineWidth', 1.5);
                                title('RMS Error Convergence');
                                xlabel('Iteration'); ylabel('Normalized RMS Error');
                                grid on;

                                drawnow;

                                %% Check if this channel is converged
                                if errorHistory{chIdx}(kk) < eth0
                                    isConverged(chIdx) = 1;
                                end
                                if kk >= 10
                                    histError = errorHistory{chIdx}(end-9:end);
                                    if std(histError) / mean(histError) < 0.1 || std(histError) < eth0/3
                                        isConverged(chIdx) = 1;
                                    end
                                end
                            end
                        end
                        %% Update dataset
                        for chIdx = 1:obj.NChannel
                            try
                                runIdx = numel(obj.Dataset(chIdx).SineModParameter) + 1;
                            catch
                                runIdx=1;
                            end
                            if isExact(chIdx)
                                [~,~,runIdxVal,success] = obj.findSineModData(chIdx,MeanDepth,ModFrequency,ModDepth);
                                if success
                                    runIdx=runIdxVal;
                                end
                            end
                            obj.Dataset(chIdx).SineModParameter{runIdx} = [MeanDepth;ModFrequency;ModDepth];
                            obj.Dataset(chIdx).SineMod{runIdx} = controlWfl{chIdx}.Sample;
                            % obj.Dataset(chIdx).XTarget{obj.RunIdx} = targetWf{chIdx}.Sample;
                            obj.Error(chIdx,runIdx) = errorHistory{chIdx}(end);

                            disp("KP" + chIdx + ", Depth = " + MeanDepth +" Er, f = " + ModFrequency/1e6 + " MHz, Mod Depth = " + ModDepth)
                            disp("error: " + errorHistory{chIdx}(end))
                        end
                        % obj.RunIdx = runIdx + 1;
                    
            obj.IsTraining = false;
            obj.saveObj
            obj.setHardware
        end
        
    end
end

