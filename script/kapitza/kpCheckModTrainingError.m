% kpCheckModTrainingError.m
% Given mod params, extract waveform and extract DC Error and ModDepth
% Error from trained dataset

function [DCError, ModDepthError]=kpCheckModTrainingError(V0, f, ModDepth, beta)
    
    folderPath = "B:\_Li\_LithiumData\HardwareLogs\KpPredistortionData";
    dataPath = findLatestFile(folderPath);
    kpp = loadVar(dataPath,"kpp");
    
    DCError=[0,0];
    ModDepthError=[0,0];

    load("LatticeCalib.mat");
    
    for ii=1:2
        ind=kpp.findDatasetIndex(ii, 'KpParameterResults', [V0; f; ModDepth; beta]);
        trainedresult=kpp.Dataset(ii).KpResults{ind};
        times=kpp.Dataset(ii).KpResultsTimeList{ind};
            MeanVoltage=mean(trainedresult);

        a=fitSine(times, trainedresult, 2*pi*f);
        figure(893783+ii);
        plot(times, trainedresult);
        hold on 
        plot(times, a(times));
        hold off

        % disp('test')
        MeanVoltage=a.c; %c is the offset in the fitsine model 
        ModDepthVoltage=a.a; %a is the amplitude in the fitsine model, mid to pk

        MeanVoltage=MeanVoltage/kpp.CorrFactor(ii);
        ModDepthVoltage=ModDepthVoltage/kpp.CorrFactor(ii);
    

        if ii==1
            transferfunc=KP1Pd2Depth;
        else
            transferfunc=KP2Pd2Depth;
        end
        MeanEr=transferfunc(MeanVoltage);
        disp(MeanEr);

        % if chIdx == 1
        %         depthWf = SineWave(...
        %             frequency    = f,...
        %             amplitude    = alpha * beta * V0,...
        %             offset       = alpha / 2 * V0,...
        %             samplingRate = sr,...
        %             duration     = duration,...
        %             phase        = pi + phi ...
        %             );
        %     else
        %         depthWf = SineWave(...
        %             frequency    = f,...
        %             amplitude    = (1+alpha/2) * V0 * (alpha/(2+alpha)) * 2 * beta,...
        %             offset       = (1+alpha/2) * V0,...
        %             samplingRate = sr,...
        %             duration     = duration,...
        %             phase        = phi ...
        %             );
        %     end

        if ii==1
            targetmeanEr=ModDepth/2*V0;
            targetmoddepthEr=ModDepth*beta*V0/2;
        else
            targetmeanEr=(1+ModDepth/2) * V0;
            targetmoddepthEr=(1+ModDepth/2) * V0 * (ModDepth/(2+ModDepth)) * beta;
        end

        DCError(ii)=MeanEr-targetmeanEr;

        ModDepthEr=1/2*(transferfunc(MeanVoltage+ModDepthVoltage)-transferfunc(MeanVoltage-ModDepthVoltage));
        ModDepthError(ii)=ModDepthEr-targetmoddepthEr;
    end
    
    


% % %     % 1. Generate synthetic noisy sine wave data for demonstration
% % % % Model: y = A * sin(2*pi*f*t + phase) + offset
% % % true_amplitude = ModDepth*beta;
% % % true_frequency = f; % Hz
% % % true_offset = true_amplitude/2;     % Mean voltage
% % % true_phase = 0;
% % % 
% % % fs = 20e6;             % Sampling frequency
% % % t = (0:1/fs:800e-6)';     % Time vector (200 ms)
% % % % y_clean = true_amplitude * sin(2*pi*true_frequency*t + true_phase) + true_offset;
% % % y_data = trainedresult; % Add noise
% % % 
% % % size(t);
% % % size(y_data);
% % % 
% % % % 2. Define the sine wave model function handle
% % % % p(1) = amplitude, p(2) = frequency (Hz), p(3) = phase, p(4) = offset (mean voltage)
% % % sineModel = @(p, t) p(1) * sin(2 * pi * p(2) * t + p(3)) + p(4);
% % % 
% % % % 3. Estimate initial guesses (Crucial for convergence!)
% % % % Offset estimate: mean of the data
% % % offset_init = mean(y_data);
% % % 
% % % % Amplitude estimate: half of peak-to-peak value
% % % amplitude_init = (max(y_data) - min(y_data)) / 2;
% % % 
% % % % Frequency estimate: Quick FFT-based estimation (or you can specify if known)
% % % n = length(y_data);
% % % Y = abs(fft(y_data - offset_init));
% % % f_axis = (0:n-1)*(fs/n);
% % % [~, idx] = max(Y(1:floor(n/2)));
% % % freq_init = f_axis(idx);
% % % 
% % % phase_init = 0; % Default initial phase
% % % 
% % % p0 = [amplitude_init, freq_init, phase_init, offset_init];
% % % 
% % % % 4. Perform Curve Fitting using lsqcurvefit
% % % options = optimoptions('lsqcurvefit', 'Display', 'off');
% % % [p_opt, ~] = lsqcurvefit(sineModel, p0, t, y_data, [], [], options);
% % % 
% % % % 5. Extract Results
% % % extracted_amplitude = abs(p_opt(1)); % Amplitude is positive
% % % extracted_offset = p_opt(4);        % Mean voltage / DC offset
% % % extracted_frequency = p_opt(2);
% % % 
% % % % Display results
% % % fprintf('--- Fit Results ---\n');
% % % fprintf('Extracted Amplitude:    %.4f V\n', extracted_amplitude);
% % % fprintf('Extracted Mean Voltage: %.4f V\n', extracted_offset);
% % % fprintf('Extracted Frequency:    %.4f Hz\n', extracted_frequency);


end

