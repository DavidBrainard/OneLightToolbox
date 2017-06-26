function OLFlickerDemo(varargin)
% OLFlickerDemo - Demonstrates how to flicker with the OneLight.
%
% Examples:
%   OLFlickerDemo
%   OLFlickerDemo('simulate',true);
%   OLFlickerDemo('useCache',false);
%
% Description:
% Demo that shows how to open the OneLight, use the cache, and flicker the
% light engine.  The cache let's us store precomputed spectra, primaries,
% and settings values so that they don't need to be computed everytime the
% program is run.  The cache system makes sure that the precomputed
% settings are in sync with the calibration file.  If the cache file
% doesn't exist, it will be created.
%
% Optional key/value pairs:
% 'useCache' (logical) - Toggles the use of the spectra cache.  Default: true
% 'stimType' (string) - Takes any of the following values: 'ShowSpectrum',
%                       'BinaryFlicker', 'DriftGabor', 'DriftSine'.
% 'recompute' (logical) - Let's you force a recomputation of the spectra
%                         and rewrite the cache file.  Only useful if using the cache.
%                         Default: false
% 'processOnly' (logical) - If true, then the program doesn't communicate
%                           with the OneLight engine.  Default: false
% 'hz' (scalar) - The rate at which the program cycles through the set of
%                 spectra to display.  Default: 1
% 'simulate' (logical) - Run in simulation mode? Default: false.
% 'nIterations' (scalar) - Number of interations of modulation to show.
%                          Inf means keep going until key press.
%                          Default: Inf
% 'lambda' (scalar) - Smoothing parameter for OLSpdToPrimary.  Default 0.1.

% 6/5/17  dhb  Add simulation mode with mb.

%% Parse input parameters.
p = inputParser;
p.addParameter('useCache', true, @islogical);
p.addParameter('stimType', 'ShowSpectrum', @isstr);
p.addParameter('recompute', false, @islogical);
p.addParameter('hz', 1, @isscalar);
p.addParameter('processOnly', false, @islogical);
p.addParameter('simulate', true, @islogical);
p.addParameter('nIterations', Inf, @isscalar);
p.addParameter('lambda', 0.1, @isscalar);
p.parse(varargin{:});
params = p.Results;

%% Select the cache file pased on the stim type.
%
% These are precomputed and are part of the demo.
switch lower(params.stimType)
    case 'showspectrum'
        cacheFile = 'ShowSpectrum';
    case 'binaryflicker'
        cacheFile = 'BinaryFlicker';
    case 'driftgabor'
        cacheFile = 'DriftGabor';
    case 'driftsine'
        cacheFile = 'DriftSine';
    otherwise
        error('OLFlickerDemo:Invalid stim type "%s".', params.stimType);
end

%% Setup some program variables.
cacheDir = fullfile(fileparts(which('OLFlickerDemo')), 'cache');
calFileName = 'OneLight';

%% Create the OneLight object.
%
% Simulate if desired, and don't do it at all if this is running in process
% only mode.
if ~params.processOnly
    ol = OneLight('simulate',params.simulate);
end

%% Load the calibration file.  Need to point at a current calibration.
whichCalType = 'OLDemoCal';
oneLightCal = OLGetCalibrationStructure('CalibrationType',whichCalType,'CalibrationDate','latest');

%% Compute spectra if necessary or requested
doCompute = ~params.useCache;
if params.useCache
    % Create a cache object.  This object encapsulates the cache folder and
    % the actions we can take on the cache files.  We pass it the
    % calibration data so it can validate the cache files we want to load.
    cache = OLCache(cacheDir, oneLightCal);
    
    % For fun, let's list the potentially available cache files.  
    % All this method really does is return a directory listing of the
    % .mat files in the cache directory.  So it's a bit lame.
    % 
    % You could call exist on these to see if they were cache files for the
    % current calibration.  You'd want to strip off the .mat from the
    % filename first.
    possibleCacheFiles = cache.list;
    if (~isempty(possibleCacheFiles))
        fprintf('Found possible cache files:\n');
        for i = 1:length(possibleCacheFiles)
            fprintf('\t%s\n',possibleCacheFiles(i).name);
        end
    else
        fprintf('No cache files for OLFlickerDemo yet exist');
    end
         
    % Look to see if the cache file exists we want exists for the current calibration.
    % This method is bit more sophisticated, as it actually checks the
    % contents of the file, if it exists.
    cacheFileExists = cache.exist(cacheFile);
    
    % Load the cache file if it exists and we're not forcing a recompute of
    % the target spectra.
    if cacheFileExists && ~params.recompute
        % Load the cache file.  This function will check to make sure the
        % cache file is in sync with the calibration data we loaded above.
        % If it returns isStale is true, then we need to recompute.
        fprintf(' - Loading cache file %s\n',cacheFile);
        [cacheData,isStale] = cache.load(cacheFile);
        if (isStale)
            fprintf(' - Cached data is stale, will recompute\n');
            doCompute = true;
        else
            fprintf(' - Loaded valid cache data\n');
        end
        
    else
        if params.recompute
            fprintf('- Manual recompute toggled.\n');
        else
            fprintf('- Cache file does not exist, will be computed and saved.\n');
        end
        doCompute = true;
        
        % Initalize the cacheData to be computed with the calibration
        % structure.
        clear cacheData;
        cacheData.cal = oneLightCal;
    end
end

%% Compute modulations if necessary
%
% We do this either because we need to recompute a stale cache file, or
% because we decided not to use cache files.
if doCompute
    % Say what we're up to
    fprintf('Computing data to cache\n');
    
    % Specify the spectra depending on our stim type.
    switch lower(params.stimType)
        case {'binaryflicker', 'showspectrum'}
            % Each of these options shows a Gaussian function of wavelength
            % in each frame.  The vector gaussCenters provides the center
            % wavelengths of the Gaussians, and the bandwidth specifies the
            % standard deviation (in nm).  The options differ only in terms
            % of these details.
            switch lower(params.stimType)
                case 'binaryflicker'
                    gaussCenters = [400, 700];
                    bandwidth = 30;
                case 'showspectrum'
                    gaussCenters = 400:2:700;
                    bandwidth = 10;
            end
            
            % Determine number of spectra and generate the Gaussians.
            %
            % We need to scale them all by a common factor so that they are
            % in gamut.  So we find the max scale factor for each that will
            % be in gamut and then apply the minimum of these to all of hte
            % spds.
            numSpectra = length(gaussCenters);
            scaleFactors = zeros(1, numSpectra);
            targetSpds = zeros(oneLightCal.describe.S(3), numSpectra);
            for i = 1:numSpectra
                fprintf('- Computing spectra %d of %d...', i, numSpectra);
                center = gaussCenters(i);
                targetSpds(:,i) = normpdf(oneLightCal.computed.pr650Wls, center, bandwidth)';
                
                % Find the scale factor that leads to the maximum relative targetSpd that is within
                % the OneLight's gamut.
                [~, scaleFactors(i), ~] = OLFindMaxSpectrum(oneLightCal, targetSpds(:,i), params.lambda, false);
                
                fprintf('Done\n');
            end
            minScaleFactor = min(scaleFactors);
            targetSpds = targetSpds * minScaleFactor;
            
            % Convert the spectra into gamma corrected mirror settings and the starts/stops
            % matrices that actually get passed to the hardware.  These are
            % stored as fields of a structure called cacheData, which we
            % will save in a cache file.
            fprintf('- Calculating primaries, settings, starts/stops ...');
            [cacheData.settings, cacheData.primaries, cacheData.predictedSpds] = ...
                OLSpdToSettings(oneLightCal, targetSpds, 'lambda', params.lambda);
            [cacheData.starts,cacheData.stops] = OLSettingsToStartsStops(oneLightCal,cacheData.settings);
            fprintf('Done\n');
            
        case {'driftgabor', 'driftsine'}
            % This is going to produce a spectrum that drifts over
            % wavelength a sinusoidal function of wavelength ('driftsine')
            % or a sinusoidal function of wavelength that is windowed by a
            % Gaussian function of wavelength.  I think we coded these
            % because we thought that if we did, we would be the first
            % people in the universe ever to have looked at such a
            % stimulus.
            switch lower(params.stimType)
                % Create the window.  Either Gaussian or just ones
                case 'driftgabor'
                    fractionOfSpectrumForWindow = 0.15;
                    sig = round(oneLightCal.describe.S(3) * fractionOfSpectrumForWindow);
                    stimulusWindow = CustomGauss([1 oneLightCal.describe.S(3)], sig, sig, 0, 0, 1, [0 0])';
                case 'driftsine'
                    stimulusWindow = ones(oneLightCal.describe.S(3), 1);
            end
            
            % Calculate 1 temporal cycle of the drifting sinusoidal spectrum.
            % We'll subdivide it into a reasonable number steps (nSpectra) to make it look smooth.
            % We'll also go ahead and multiply by the window.
            %
            % Variable spectralFrequency is the number of cycles of the
            % sinusoid across the visible spectrum.  The convenience
            % variable x is the samples along the visible spectrum.
            numSpectra = 100;
            spectralFrequency = 2;
            targetSpds = zeros(oneLightCal.describe.S(3), numSpectra);
            x = 0:(oneLightCal.describe.S(3)-1);
            for i = 0:(numSpectra-1)
                fprintf('- Computing spectra %d of %d...', i+1, numSpectra);
                targetSpds(:,i+1) = sin(2*pi*spectralFrequency*x/oneLightCal.describe.S(3) + 2*pi*i/numSpectra)' .* stimulusWindow;
                
                % Normalize to [0,1] range, rather than [-1,1] that comes
                % out of a raw sinusoid.
                targetSpds(:,i+1) = (targetSpds(:,i+1) + 1) / 2;
                fprintf('Done\n');
            end
            
            % We need to scale them all by a common factor so that they are
            % in gamut.  So we find the max scale factor for each that will
            % be in gamut and then apply the minimum of these to all of hte
            % spds.
            scaleFactors = zeros(1, numSpectra);
            for i = 1:numSpectra
                fprintf('- Computing scale factors %d of %d...', i, numSpectra);
                [~, scaleFactors(i), ~] = OLFindMaxSpectrum(oneLightCal, targetSpds(:,i), params.lambda, false);
                fprintf('Done\n');
            end
            minScaleFactor = min(scaleFactors);
            targetSpds = targetSpds * minScaleFactor;
            
            % Convert the spectra into gamma corrected mirror settings.  We use the
            % static OLCache method "compute" so that we guarantee we calculate the
            % cache in the same way that an OLCache object's load method does.
            fprintf('- Calculating primaries, settigns, starts/stops ...');
            [cacheData.settings, cacheData.primaries, cacheData.predictedSpds] = ...
                OLSpdToSettings(oneLightCal, targetSpds, 'lambda', params.lambda);
            [cacheData.starts,cacheData.stops] = OLSettingsToStartsStops(oneLightCal,cacheData.settings);
            fprintf('Done\n');
    end
end

%% Save cacheData to cache file if necessary
%
% By the time we get here, the structure cacheData has the primaries,
% settings and starts/stops for each modulation, computed with respect to
% the current calibration time.
%
% We want to save the spectra and mirror settings data if we're using the
% cache to make sure we update the cache file in case anything was
% recomputed.
if params.useCache && doCompute
    fprintf('- Saving cache file: %s\n', cacheFile);
    cache.save(cacheFile, cacheData);
end

% We will base the duration of each frame, i.e. length of time showing a
% particular set of mirrors, on the frequency, such that we will go through
% all the settings at the specified hz value.
durationPerCycleSecs = 1/params.hz;
framesPerCycle = size(cacheData.starts, 1);
durationPerFrameSecs = durationPerCycleSecs / framesPerCycle;

%% Actually talk to the OneLight (or its simulated version)
if ~params.processOnly
    keyPress = OLFlicker(ol, cacheData.starts, cacheData.stops, durationPerFrameSecs, params.nIterations);
    ol.close;
end