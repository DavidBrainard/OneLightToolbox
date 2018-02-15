function protocolParams = OLValidateDirectionCorrectedPrimaries(ol,protocolParams,prePost)
%%OLValidateCorrectedPrimaries  Measure and check the corrected primaries
%
% Syntax:
%     protocolParams = OLValidateDirectionCorrectedPrimaries(ol,protocolParams,prePost)
%
% Description:
%     This script uses the radiometer to measure the light coming out of the eyepiece and 
%     calculates the receptor contrasts.  This is a check on how well we
%     are hitting our desired target.  Typically we run this before and
%     after the experimental session.
%
% Input:
%     ol (object)                   Open OneLight object.
%
%     protocolParams (struct)       Protocol parameters structure.
%
%     prePost (string)              'Pre' or 'Post' to indicate validations pre or post experiment.  
%
% Output:
%     protocolParams (struct)       Protocol parameters structure updated with session log info.
%
% Optional key/value pairs:
%     None.
%
% See also: OLValidateCacheFileOOC.

% 06/18/17  dhb  Added header comment.
% 08/21/17  dhb  Save out protocolParams as part of results structure. May be useful for later analysis.

%% Update session log file
OLSessionLog(protocolParams,mfilename,'StartEnd','start','PrePost',prePost);

%% Cache files to validate
theDirections = unqiue(protocolParams.directionNames);

%% Input and output file locations.
cacheDir = fullfile(getpref(protocolParams.protocol, 'DirectionCorrectedPrimariesBasePath'), protocolParams.observerID, protocolParams.todayDate, protocolParams.sessionName);
outDir = fullfile(getpref(protocolParams.protocol, 'DirectionCorrectedValidationBasePath'), protocolParams.observerID, protocolParams.todayDate, protocolParams.sessionName);
if(~exist(outDir,'dir'))
    mkdir(outDir)
end

%% Obtain correction params from OLCorrectionParamsDictionary,
%
% These are box specific, according to the boxName specified in
% protocolParams.boxName
dd = OLCorrectionParamsDictionary();
correctionParams = dd(protocolParams.boxName);

%% Open up a radiometer object
if (~protocolParams.simulate.oneLight)
    [spectroRadiometerOBJ,S] = OLOpenSpectroRadiometerObj('PR-670');
else
    spectroRadiometerOBJ = [];
    S = [];
end

%% Open up lab jack for temperature measurements
if (~protocolParams.simulate.oneLight & protocolParams.takeTemperatureMeasurements)
    % Gracefully attempt to open the LabJack.  If it doesn't work and the user OK's the
    % change, then the takeTemperature measurements flag is set to false and we proceed.
    % Otherwise it either worked (good) or we give up and throw an error.
    [protocolParams.takeTemperatureMeasurements, quitNow, theLJdev] = OLCalibrator.OpenLabJackTemperatureProbe(protocolParams.takeTemperatureMeasurements);
    if (quitNow)
        error('Unable to get temperature measurements to work as requested');
    end
else
    theLJdev = [];
end

%% Validate each direction
%
% Respect the flag, as when the protocol contains multiple trial types
% that use the same direction file, we only need to validate once per
% direction.
for ii = 1:protocolParams.nValidationsPerDirection
    for dd = 1:length(theDirections)
        
        % Do the validation if the flag is true.
        if (protocolParams.doCorrection(dd))
            theDirectionCacheFileName = sprintf('Direction_%s', protocolParams.directionNames{dd});
            
            fprintf('\nValidation measurements, direction %d, %s, %s, measurement %d of %d, \n',dd,theDirectionCacheFileName,prePost,ii,protocolParams.nValidationsPerDirection);

            % Take the measurement
            results = OLValidateCacheFileOOC(fullfile(cacheDir,[theDirectionCacheFileName '.mat']), ol, spectroRadiometerOBJ, S, theLJdev, ...
                'approach',                     protocolParams.approach, ...
                'simulate',                     protocolParams.simulate.oneLight, ...
                'observerAgeInYrs',             protocolParams.observerAgeInYrs, ...
                'calibrationType',              protocolParams.calibrationType, ...
                'takeCalStateMeasurements',     protocolParams.takeCalStateMeasurements, ...
                'takeTemperatureMeasurements',  protocolParams.takeTemperatureMeasurements, ...
                'verbose',                      protocolParams.verbose);
            
            % Save the validation information in an ordinary .mat file.  Append prePost and iteration number in name.
            outputFile = fullfile(outDir,sprintf('%s_%s_%d.mat', theDirectionCacheFileName,prePost,ii));
            results.protocolParams = protocolParams;
            save(outputFile,'results');
            if (protocolParams.verbose), fprintf('\tSaved validation results to %s\n', outputFile); end
        end
    end
end

%% Close the radiometer object
if (~protocolParams.simulate.oneLight)
    if (~isempty(spectroRadiometerOBJ))
        spectroRadiometerOBJ.shutDown();
    end
    
    if (~isempty(theLJdev))
        theLJdev.close;
    end
end

%% Log that we did the validation
OLSessionLog(protocolParams,mfilename,'StartEnd','end','PrePost',prePost);
