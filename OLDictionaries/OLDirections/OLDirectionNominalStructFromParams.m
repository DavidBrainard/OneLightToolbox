function directionStruct = OLDirectionNominalStructFromParams(directionParams,backgroundPrimary,calibration,varargin)
% Generate a parameterized direction from the given parameters
%
% Syntax:
%   directionStruct = OLDirectionNominalFromParams(directionParameters, backgroundPrimary, calibration)
%   directionStruct = OLDirectionNominalFromParams(..., 'verbose', true)
%
% Description:
%    For several common types of directions, this function can generate the
%    actual direction from parameters.
%
%    This function currently knows about the following types:
%       - unipolar
%       - bipolar
%       - lightfluxchrom
%
%    These parameters can be generated by OLDirectionParamsDefaults,
%    validated by OLDirectionParamsValidate, and several sets of
%    parameters are predefined in OLDirectionParamsDictionary.
%
% Inputs:
%    directionParams   - struct defining the parameters for a type of
%                        direction. Can be generated using
%                        OLDirectionParamsDefaults
%    backgroundPrimary - the primary values for the background
%    calibration       - OneLight calibration struct
%
% Outputs:
%    directionStruct   - a 1x60 struct array (one struct per observer age
%                        1:60 yrs), with the following fields:
%                          * backgroundPrimary   : the primary values for
%                                                  the background.
%                          * differentialPositive: the difference in 
%                                                  primary values to be
%                                                  added to the background
%                                                  primary to create the
%                                                  positive direction
%                          * differentialNegative: the difference in 
%                                                  primary values to be
%                                                  added to the background
%                                                  primary to create the
%                                                  negative direction
%                          * describe            : Any additional
%                                                 (meta)-information that
%                                                 might be stored
%
% Optional key/value pairs:
%    observerAge       - (vector of) observer age(s) to generate direction
%                        struct for. When numel(observerAge > 1), output
%                        directionStruct will still be of size [1,60], so
%                        that the index is the observerAge. When
%                        numel(observerAge == 1), directionStruct will be
%                        a single struct. Default is 20:60.
%    verbose           - boolean flag to print output. Default false.
%
% Notes:
%    None.
%
% See also:
%    OLDirectionParamsDefaults, OLDirectionParamsValidate,
%    OLDirectionParamsDictionary

% History:
%    01/31/18  jv  wrote it, based on OLWaveformFromParams and
%                  OLReceptorIsolateMakeDirectionNominalPrimaries

%% Input validation
parser = inputParser();
parser.addRequired('directionParams',@isstruct);
parser.addRequired('backgroundPrimary');
parser.addRequired('calibration',@isstruct);
parser.addParameter('verbose',false,@islogical);
parser.addParameter('observerAge',20:60,@isnumeric);
parser.parse(directionParams,backgroundPrimary,calibration,varargin{:});

S = calibration.describe.S;
backgroundSpd = OLPrimaryToSpd(calibration, backgroundPrimary);

%% Generate direction
switch directionParams.type
    case {'bipolar', 'unipolar'}
        % Pupil diameter in mm.
        pupilDiameterMm = directionParams.pupilDiameterMm;
        
        % Photoreceptor classes: cell array of strings
        photoreceptorClasses = directionParams.photoreceptorClasses;
        
        % Set up what will be common to all observer ages
        % Pull out the 'M' matrix
        B_primary = calibration.computed.pr650M;
        
        % Set up some parameters for the optimization
        whichPrimariesToPin = [];       % Primaries we want to pin
        whichReceptorsToIgnore = directionParams.whichReceptorsToIgnore;    % Receptors to ignore
        whichReceptorsToIsolate = directionParams.whichReceptorsToIsolate;    % Receptors to stimulate
        whichReceptorsToMinimize = directionParams.whichReceptorsToMinimize;
        
        % Peg desired contrasts
        desiredContrasts = directionParams.modulationContrast;
        
        % Assign a zero 'ambientSpd' variable if we're not using the
        % measured ambient.
        if directionParams.useAmbient
            ambientSpd = calibration.computed.pr650MeanDark;
        else
            ambientSpd = zeros(size(B_primary,1),1);
        end
        
        if (parser.Results.verbose), fprintf('\nGenerating stimuli which isolate receptor classes:'); end
        for i = 1:length(whichReceptorsToIsolate)
            if (parser.Results.verbose), fprintf('\n  - %s', photoreceptorClasses{whichReceptorsToIsolate(i)}); end
        end
        if (parser.Results.verbose), fprintf('\nGenerating stimuli which ignore receptor classes:'); end
        if ~isempty(whichReceptorsToIgnore)
            for i = 1:length(whichReceptorsToIgnore)
                if (parser.Results.verbose), fprintf('\n  - %s', photoreceptorClasses{whichReceptorsToIgnore(i)}); end
            end
        else
            if (parser.Results.verbose), fprintf('\n  - None'); end
        end
        
        % Make direction information for each observer age
        for observerAgeInYears = parser.Results.observerAge
            % Say hello
            if (parser.Results.verbose), fprintf('\nObserver age: %g\n',observerAgeInYears); end
            
            % Get original backgroundPrimary
            backgroundPrimary = parser.Results.backgroundPrimary;
            
            % Get fraction bleached for background we're actually using
            if (directionParams.doSelfScreening)
                fractionBleached = OLEstimateConePhotopigmentFractionBleached(S,backgroundSpd,pupilDiameterMm,directionParams.fieldSizeDegrees,observerAgeInYears,photoreceptorClasses);
            else
                fractionBleached = zeros(1,length(photoreceptorClasses));
            end
            
            % Get lambda max shift.  Currently not passed but could be.
            lambdaMaxShift = [];
            
            % Construct the receptor matrix based on the bleaching fraction to this background.
            T_receptors = GetHumanPhotoreceptorSS(S,photoreceptorClasses,directionParams.fieldSizeDegrees,observerAgeInYears,pupilDiameterMm,lambdaMaxShift,fractionBleached);
                      
            % Isolate the receptors by calling the ReceptorIsolate
            initialPrimary = backgroundPrimary;
            modulationPrimarySignedPositive = ReceptorIsolate(T_receptors, whichReceptorsToIsolate, ...
                whichReceptorsToIgnore,whichReceptorsToMinimize,B_primary,backgroundPrimary,...
                initialPrimary,whichPrimariesToPin,directionParams.primaryHeadRoom,directionParams.maxPowerDiff,...
                desiredContrasts,ambientSpd);
            
            differentialPositive = modulationPrimarySignedPositive - backgroundPrimary;
            differentialNegative = -1 * differentialPositive;
            
            % IF UNIPOLAR, REPLACE BACKGROUND WITH NEGATIVE MAX EXCURSION
            if (strcmp(directionParams.type,'unipolar'))
                backgroundPrimary = backgroundPrimary + differentialNegative;
                differentialPositive = modulationPrimarySignedPositive - backgroundPrimary;
                differentialNegative = 0 * differentialPositive;
            end
            
            % Look at both negative and positive swing and double check that we're within gamut
            modulationPrimarySignedPositive = backgroundPrimary+differentialPositive;
            modulationPrimarySignedNegative = backgroundPrimary+differentialNegative;
            if any(modulationPrimarySignedNegative > 1) || any(modulationPrimarySignedNegative < 0)  || any(modulationPrimarySignedPositive > 1)  || any(modulationPrimarySignedPositive < 0)
                error('Out of bounds.')
            end
            
            % Compute spds, constrasts
            backgroundSpd = OLPrimaryToSpd(calibration,backgroundPrimary);
            backgroundReceptors = T_receptors*backgroundSpd;
            differenceSpdSignedPositive = B_primary*differentialPositive;
            differenceReceptorsPositive = T_receptors*differenceSpdSignedPositive;
            isolateContrastsSignedPositive = differenceReceptorsPositive ./ backgroundReceptors;
            modulationSpdSignedPositive = backgroundSpd+differenceSpdSignedPositive;
            
            differenceSpdSignedNegative = B_primary*(-differentialPositive);
            modulationSpdSignedNegative = backgroundSpd+differenceSpdSignedNegative;
            
            % Print out contrasts. This routine is in the Silent Substitution Toolbox.
            if (parser.Results.verbose), ComputeAndReportContrastsFromSpds(sprintf('\n> Observer age: %g',observerAgeInYears),photoreceptorClasses,T_receptors,backgroundSpd,modulationSpdSignedPositive); end
            
            % [DHB NOTE: MIGHT WANT TO SAVE THE VALUES HERE AND PHOTOPIC LUMINANCE TOO.]
            % Print out luminance info.  This routine is also in the Silent Substitution Toolbox
            if (parser.Results.verbose), GetLuminanceAndTrolandsFromSpd(S, backgroundSpd, pupilDiameterMm, true); end
            
            %% Assign all the cache fields
            % Business end
            directionStruct(observerAgeInYears).backgroundPrimary = backgroundPrimary;              
            directionStruct(observerAgeInYears).differentialPositive = differentialPositive;                            
            directionStruct(observerAgeInYears).differentialNegative = differentialNegative;            
            
            % Description
            directionStruct(observerAgeInYears).describe.params = directionParams;
            directionStruct(observerAgeInYears).describe.modulationPrimarySignedPositive = modulationPrimarySignedPositive;
            directionStruct(observerAgeInYears).describe.modulationPrimarySignedNegative = modulationPrimarySignedNegative;
            directionStruct(observerAgeInYears).describe.B_primary = B_primary;
            directionStruct(observerAgeInYears).describe.ambientSpd = ambientSpd;
            directionStruct(observerAgeInYears).describe.backgroundSpd = backgroundSpd;
            directionStruct(observerAgeInYears).describe.modulationSpdSignedPositive = modulationSpdSignedPositive;
            directionStruct(observerAgeInYears).describe.modulationSpdSignedNegative = modulationSpdSignedNegative;
            directionStruct(observerAgeInYears).describe.photoreceptors = photoreceptorClasses;
            directionStruct(observerAgeInYears).describe.lambdaMaxShift = lambdaMaxShift;
            directionStruct(observerAgeInYears).describe.fractionBleached = fractionBleached;
            directionStruct(observerAgeInYears).describe.S = S;
            directionStruct(observerAgeInYears).describe.T_receptors = T_receptors;
            directionStruct(observerAgeInYears).describe.S_receptors = S;
            directionStruct(observerAgeInYears).describe.contrast = isolateContrastsSignedPositive;
            directionStruct(observerAgeInYears).describe.contrastSignedPositive = isolateContrastsSignedPositive;
                   
            clear modulationPrimarySignedNegative modulationSpdSignedNegative
        end
        
    case 'lightfluxchrom'
        % A light flux pulse or modulation, computed given background.
        % 
        % Note: This has access to useAmbient and primaryHeadRoom parameters but does
        % not currently use them. That is because this counts on the background having
        % been set up to accommodate the desired modulation.
        
        % Modulation.  This is the background scaled up by the factor that the background
        % was originally scaled down by.
        modulationPrimarySignedPositive = backgroundPrimary*directionParams.lightFluxDownFactor;
        modulationSpdSignedPositive = OLPrimaryToSpd(calibration, modulationPrimarySignedPositive);
        differentialPositive = modulationPrimarySignedPositive - backgroundPrimary;
        differentialNegative = -1 * differentialPositive;
        
        % Check gamut
        if (any(modulationPrimarySignedPositive > 1) || any(modulationPrimarySignedPositive < 0))
            error('Out of gamut error for the modulation');
        end
        
        % Replace the values
        for observerAgeInYrs = parser.Results.observerAge
            directionStruct(observerAgeInYrs).differentialPositive = differentialPositive;
            directionStruct(observerAgeInYrs).differentialNegative = differentialNegative;     
            directionStruct(observerAgeInYrs).backgroundPrimary = backgroundPrimary;
            directionStruct(observerAgeInYrs).describe.backgroundSpd = backgroundSpd;
            directionStruct(observerAgeInYrs).describe.modulationPrimarySignedPositive = modulationPrimarySignedPositive;
            directionStruct(observerAgeInYrs).describe.modulationSpdSignedPositive = modulationSpdSignedPositive;      
            directionStruct(observerAgeInYrs).describe.params = directionParams;
        end

    otherwise
        error('Unknown direction type specified');
end

if numel(parser.Results.observerAge == 1)
    directionStruct = directionStruct(parser.Results.observerAge);
end

end