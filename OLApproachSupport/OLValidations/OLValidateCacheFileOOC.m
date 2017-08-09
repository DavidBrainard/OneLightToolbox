function results = OLValidateCacheFileOOC(cacheFileName, ol, spectroRadiometerOBJ, S, theLJdev, varargin)
%OLValidateCacheFileOOC  Validate spectra in a cache file
%
% Usage:
%     results = OLValidateCacheFileOOC(cacheFileName, ol, meterType)
%
% Description:
%     Measures the primaries in a cache file so we can see how well they are doing
%     what they are supposed to.
%
% Input:
%     cacheFileName (string)          - Absolute path full name of the cache file to validate.
%     ol (object)                     - Open OneLight object.
%     spectroRadiometerOBJ (object)   - Object for the measurement meter. Can be passed empty if simulating.
%     S                               - Wavelength sampling for measurements. Can be passed empty if simulating.
%     theLJdev                        - Lab jack device.  Pass empty will skip temperature measurements.
%
% Output:
%     results (struct)                - Results structure
%
% Optional key/value pairs:
%      Keyword                         Default                          Behavior
%
%     'approach'                       ''                               What approach is calling us?
%     'simulate'                       false                            Run in simulation mode.
%     'observerAgeInYrs'               32                               Observer age to correct for.
%     'noRadiometerAdjustment '        true                             Does not pause to allow aiming of radiometer.
%     'pauseDuration'                  0                                How long to pause (in secs) after radiometer is aimed by user.
%     'calibrationType'                ''                               Calibration type
%     'takeTemperatureMeasurements'    false                            Take temperature measurements? (Requires a connected LabJack dev with a temperature probe.)
%     'takeCalStateMeasurements'       true                             Take OneLight state measurements
%     'useAverageGamma'                false                            Force the useAverageGamma mode in the calibration?
%     'zeroPrimariesAwayFromPeak'      false                            Zero out calibrated primaries well away from their peaks.
%     'verbose'                        false                            Print out things in progress.
%
% See also: OLValidateDirectionCorrectedPrimaries, OLGetCacheAndCalData

% 1/21/14  dhb, ms  Convert to use OLSettingsToStartsStops.
% 1/30/14  ms       Added keyword parameters to make this useful.
% 7/06/16  npc      Adapted to use PR650dev/PR670dev objects
% 9/2/16   ms       Updated with new CalStateMeas option
% 10/20/16 npc      Added ability to record temperature measurements
% 12/21/16 npc      Updated for new class @LJTemperatureProbe
% 06/05/17 dhb      Remove old verbose arg to OLSettingsToStartsStops
% 07/27/17 dhb      Massive interface redo.

% Parse the input
p = inputParser;
p.addParameter('approach','', @isstr);
p.addParameter('simulate',false,@islogical);
p.addParameter('noRadiometerAdjustment', true, @islogical);
p.addParameter('pauseDuration',0,@inumeric);
p.addParameter('observerAgeInYrs', 32, @isscalar);
p.addParameter('calibrationType','', @isstr);
p.addParameter('takeCalStateMeasurements', false, @islogical);
p.addParameter('takeTemperatureMeasurements', false, @islogical);
p.addParameter('useAverageGamma', false, @islogical);
p.addParameter('zeroPrimariesAwayFromPeak', false, @islogical);
p.addParameter('verbose',false,@islogical);
p.parse(varargin{:});
validationDescribe = p.Results;

%% Check input OK
if (~validationDescribe.simulate & (isempty(spectroRadiometerOBJ) | isempty(S)))
    error('Must pass radiometer objecta and S, unless simulating');
end

%% Get cached direction data as well as calibration file.  
[cacheData,adjustedCal] = OLGetCacheAndCalData(cacheFileName, validationDescribe);
if (isempty(S))
    S = adjustedCal.describe.S;
end

%% Set meterToggle so that we don't use the Omni radiometer in various measuremnt calls below.
meterToggle = [true false]; od = [];

%% Let user get the radiometer set up if desired.
if (~validationDescribe.noRadiometerAdjustment)
    ol.setAll(true);
    commandwindow;
    fprintf('- Focus the radiometer and press enter to pause %d seconds and start measuring.\n', validationDescribe.pauseDuration);
    input('');
    ol.setAll(false);
    pause(validationDescribe.pauseDuration);
else
    ol.setAll(false);
end

%% Since we're working with hardware, things can go wrong.
%
% Use a try/catch to maximize robustness.
try
    % Keep time
    startMeas = GetSecs;
    
    % Say hello
    if (validationDescribe.verbose), fprintf('- Performing radiometer measurements.\n'); end;
    
    % State and temperature measurements
    if (~validationDescribe.simulate & validationDescribe.calStateMeas)
        if (validationDescribe.verbose), fprintf('- State measurements \n'); end;
        [~, results.calStateMeas] = OLCalibrator.TakeStateMeasurements(adjustedCal, ol, od, spectroRadiometerOBJ, meterToggle, nAverage, theLJdev, 'standAlone',true);
    else
        results.calStateMeas = [];
    end
    if (~validationDescribe.simulate & validationDescribe.takeTemperatureMeasurements & ~isempty(theLJdev))
        [~, results.temperatureMeas] = theLJdev.measure();
    else
        results.temperatureMeas = [];
    end
        
    % Get background primary and max positive difference primary
    backgroundPrimary = cacheData.data(validationDescribe.observerAgeInYrs).backgroundPrimary;
    differencePrimary = cacheData.data(validationDescribe.observerAgeInYrs).modulationPrimarySignedPositive-backgroundPrimary;
    
    % Make measurements for each power level
    validationDescribe.powerLevels = cacheData.directionParams.validationPowerLevels;
    nPowerLevels = length(validationDescribe.powerLevels);
    for i = 1:nPowerLevels
        if (validationDescribe.verbose), fprintf('- Measuring spectrum %d, level %g...\n', i, validationDescribe.powerLevels(i)); end;
        
        % Get primaries for this power level
        primaries = backgroundPrimary+validationDescribe.powerLevels(i).*differencePrimary;
        
        % Convert the primaries to starts/stops mirror settings in two easy steps
        settings = OLPrimaryToSettings(adjustedCal, primaries);
        [starts,stops] = OLSettingsToStartsStops(adjustedCal, settings);
        
        % Take the measurements.  Simulate with OLPrimaryToSpd when not measuring.
        if (~validationDescribe.simulate)
            results.directionMeas(i).meas = OLTakeMeasurementOOC(ol, od, spectroRadiometerOBJ, starts, stops, S, meterToggle, nAverage);
        else
            results.directionMeas(i).meas.pr650.spectrum = OLPrimaryToSpd(adjustedCal,primaries);
            results.directionMeas(i).meas.pr650.time = [mglGetSecs mglGetSecs];
            results.directionMeas(i).meas.omni = [];
        end
        
        % Save out information about this power level.
        results.directionMeas(i).powerLevel = validationDescribe.powerLevels(i);
        results.directionMeas(i).primaries = primaries;
        results.directionMeas(i).settings = settings;
        results.directionMeas(i).starts = starts;
        results.directionMeas(i).stops = stops;
        results.directionMeas(i).predictedSpd = OLPrimaryToSpd(adjustedCal,primaries); 
    end
    
    % Time at finish
    stopMeas = GetSecs;
    
    % Turn the OneLight mirrors off.
    ol.setAll(false);
    
    % Close the radiometer
    if (~validationDescribe.simulate)
        if (~isempty(spectroRadiometerOBJ))
            spectroRadiometerOBJ.shutDown();
        end
    end
    
    % Save out useful information
    [calID, calIDTitle] = OLGetCalID(adjustedCal);
    results.validationDescribe = validationDescribe;
    results.validationDescribe.calID = calID;
    results.validationDescribe.calIDTitle = calIDTitle;
    results.validationDescribe.cal = adjustedCal;
    results.validationDescribe.cache.data = cacheData.data;
    results.validationDescribe.cache.cacheFileName = cacheFileName;
    results.validationDescribe.validationDate = datestr(now, 'mmddyy');
    results.validationDescribe.validationTime = datestr(now, 'hh:mm:ss');
    results.validationDescribe.startMeas = startMeas;
    results.validationDescribe.stopMeas = stopMeas;
    results.validationDescribe.S = S;

% Handle the error case
catch e
    
    % Turn the OneLight mirrors off.
    ol.setAll(false);
    
     % Close the radiometer
    if (~validationDescribe.simulate)
        if (~isempty(spectroRadiometerOBJ))
            spectroRadiometerOBJ.shutDown();
        end
        
        if (~isempty(theLJdev))
            theLJdev.close;
        end
    end
    
    % Rethrow the error
    rethrow(e)
end
