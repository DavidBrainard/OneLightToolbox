function OLCharacterizeBandInteractions
% OLCharacterizeBandInteractions - Characterize interactions between bands of the OneLight device.
%
% Syntax:
% OLCharacterizeBandInteractions
%
% 5/2/16  npc  Wrote it.
%

    % Ask for email recipient
    emailRecipient = GetWithDefault('Send status email to','cottaris@psych.upenn.edu');
    
    
    % Import a calibration 
    cal = OLGetCalibrationStructure;
    
    nPrimariesNum = cal.describe.numWavelengthBands;
    
    % Measure at these levels
    primaryLevels = 0.0:0.33:1.0;
    
    referenceBands = round(nPrimariesNum/2); % For now fix the reference band to the center band. 
    % referenceBands = 6:10:nPrimariesNum-6;
    
    % Activate (one at a time) bands +/- 5  around reference band
    range = 10;
    interactingBands = [(-range:-1) (1:range)];
    
    nSpectraMeasured = numel(referenceBands) * numel(interactingBands) * numel(primaryLevels) * numel(primaryLevels);
    primaryValues = zeros(nPrimariesNum, nSpectraMeasured); 
    
    spectrumIndex = 0;
    for referenceBandIndex = 1:numel(referenceBands)
        referenceBand = referenceBands(referenceBandIndex);
        for interactingBandIndex = 1:numel(interactingBands)
            interactingBand = referenceBand + interactingBands(interactingBandIndex);
            for referenceBandPrimaryLevelIndex = 1:numel(primaryLevels)
                referenceBandPrimaryLevel = primaryLevels(referenceBandPrimaryLevelIndex);
                for interactingBandPrimaryLevelIndex = 1:numel(primaryLevels)
                    interactingBandPrimaryLevel = primaryLevels(interactingBandPrimaryLevelIndex);
                    activation = zeros(nPrimariesNum,1);
                    activation(referenceBand) = referenceBandPrimaryLevel;
                    activation(interactingBand) = interactingBandPrimaryLevel;
                    spectrumIndex = spectrumIndex + 1;
                    primaryValues(:,spectrumIndex) = activation;
                    data(spectrumIndex).activation = struct(...
                        'referenceBand', referenceBand, ...
                        'interactingBand', interactingBand', ...
                        'referenceBandPrimaryLevel', referenceBandPrimaryLevel, ...
                        'interactingBandPrimaryLevel', interactingBandPrimaryLevel, ...
                        'primaries', activation ...
                        );
                end % interactingBandPrimaryLevelIndex
            end % referenceBandPrimaryLevelIndex
        end % interactingBandIndex
    end % referenceBandIndex
    
    figure(1);
    clf;
    subplot('Position', [0.04 0.04 0.95 0.95]);
    pcolor(1:nPrimariesNum, 1:nSpectraMeasured, primaryValues');
    xlabel('primary no');
    ylabel('spectrum no');
    set(gca, 'CLim', [0 1]);
    title('primary values');
    colormap(gray);
    
    settingsValues = OLPrimaryToSettings(cal, primaryValues);
    figure(2);
    clf;
    subplot('Position', [0.04 0.04 0.95 0.95]);
    pcolor(1:nPrimariesNum, 1:nSpectraMeasured, settingsValues');
    xlabel('primary no');
    ylabel('spectrum no');
    set(gca, 'CLim', [0 1]);
    colormap(gray);
    title('settings values');
    pause
    
    % Compute starts and stops for all examined settings
    [startsArray,stopsArray] = OLSettingsToStartsStops(cal,settingsValues);
    
    
    spectroRadiometerOBJ = [];
    ol = [];
    
    try
        Svector = [380 2 201];
        meterToggle = [1 0];
        od = [];
        nAverage = 1;
        nRepeats = 1;
        
        % Instantiate a PR670 object
        spectroRadiometerOBJ  = PR670dev(...
            'verbosity',        1, ...       % 1 -> minimum verbosity
            'devicePortString', [] ...       % empty -> automatic port detection)
        );

        % Set options Options available for PR670:
        spectroRadiometerOBJ.setOptions(...
            'verbosity',        1, ...
            'syncMode',         'OFF', ...      % choose from 'OFF', 'AUTO', [20 400];        
            'cyclesToAverage',  1, ...          % choose any integer in range [1 99]
            'sensitivityMode',  'EXTENDED', ... % choose between 'STANDARD' and 'EXTENDED'.  'STANDARD': (exposure range: 6 - 6,000 msec, 'EXTENDED': exposure range: 6 - 30,000 msec
            'exposureTime',     'ADAPTIVE', ... % choose between 'ADAPTIVE' (for adaptive exposure), or a value in the range [6 6000] for 'STANDARD' sensitivity mode, or a value in the range [6 30000] for the 'EXTENDED' sensitivity mode
            'apertureSize',     '1 DEG' ...   % choose between '1 DEG', '1/2 DEG', '1/4 DEG', '1/8 DEG'
        );
        
        % Get handle to OneLight
        ol = OneLight;

        % Do all the measurements
        for repeatIndex = 1:nRepeats
            for spectrumIndex = 1:nSpectraMeasured
                fprintf('Measuring spectrum %d of %d (repeat: %d/%d)\n', spectrumIndex, nSpectraMeasured, repeatIndex, nRepeats);
                pause(0.1);
                primaryValues = data(spectrumIndex).activation.primaries;
                settingsValues = OLPrimaryToSettings(cal, primaryValues);
                [starts,stops] = OLSettingsToStartsStops(cal,settingsValues);
                measurement = OLTakeMeasurementOOC(ol, od, spectroRadiometerOBJ, starts, stops, Svector, meterToggle, nAverage);
                data(spectrumIndex).measurement(:, repeatIndex)       = measurement.pr650.spectrum;
                data(spectrumIndex).timeOfMeasurement(:, repeatIndex) = measurement.pr650.time(1);
                figure(3);
                clf;
                subplot(2,1,1);
                bar(primaryValues);
                set(gca, 'YLim', [0 1], 'XLim', [0 nPrimariesNum+1]);
                subplot(2,1,2);
                plot(SToWls(Svector), measurement.pr650.spectrum, 'k-');
                drawnow;
            end
        end
        
        % Save data
        filename = sprintf('BandInteractions_%s_%s.mat', cal.describe.calType, datestr(now, 'dd-mmm-yyyy_HH_MM_SS'));
        save(filename, 'data', 'cal', '-v7.3');
        fprintf('Data saved in ''%s''. \n', filename); 
        SendEmail(emailRecipient, 'OneLight Calibration Complete', 'Finished!');
        
        % Shutdown spectroradiometer
        spectroRadiometerOBJ.shutDown();
        
        % Shutdown OneLight
        ol.shutdown();
        
    catch err
        fprintf('Failed with message: ''%s''... ', err.message);
        if (~isempty(spectroRadiometerOBJ))
            % Shutdown spectroradiometer
            spectroRadiometerOBJ.shutDown();
        end
        
        SendEmail(emailRecipient, 'OneLight Calibration Failed', ...
            ['Calibration failed with the following error' err.message]);
        
        if (~isempty(ol))
            % Shutdown OneLight
            ol.shutdown();
        end
        
        keyboard;
        rethrow(e);
    end
 
end
