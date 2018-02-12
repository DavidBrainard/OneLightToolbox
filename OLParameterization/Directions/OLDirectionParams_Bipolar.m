classdef OLDirectionParams_Bipolar < OLDirectionParams
% Parameter-object for Bipolar directions
%   Detailed explanation goes here
    
    properties
        photoreceptorClasses = {'LConeTabulatedAbsorbance'  'MConeTabulatedAbsorbance'  'SConeTabulatedAbsorbance'  'Melanopsin'};
        fieldSizeDegrees(1,1) = 27.5;
        pupilDiameterMm(1,1) = 8.0;
        maxPowerDiff(1,1) = 0.1;
        baseModulationContrast = [];
        modulationContrast = [];
        whichReceptorsToIsolate = [];
        whichReceptorsToIgnore = [];
        whichReceptorsToMinimize = [];
        whichPrimariesToPin = [];
        directionsYoked = 0;
        directionsYokedAbs = 0;
        receptorIsolateMode = 'Standard';
        doSelfScreening = false;
    end
    
    methods
        function obj = OLDirectionParams_Bipolar
            obj.type = 'bipolar';
            obj.name = '';
            obj.cacheFile = '';
            
            obj.primaryHeadRoom = .005;
        end
        
        function name = OLDirectionNameFromParams(directionParams)
            name = sprintf('%s_bipolar_%d_%d_%d',directionParams.baseName,round(10*directionParams.fieldSizeDegrees),round(10*directionParams.pupilDiameterMm),round(1000*directionParams.baseModulationContrast));
        end
        
        function directionStruct = OLDirectionNominalStructFromParams(directionParams, calibration, varargin)
            % Generate a parameterized direction from the given parameters
            %
            % Syntax:
            %   directionStruct = OLDirectionNominalStructFromParams(directionParameters, calibration)
            %   directionStruct = OLDirectionNominalStructFromParams(directionParameters, calibration, backgroundPrimary)            
            %   directionStruct = OLDirectionNominalStructFromParams(..., 'observerAge', obseverAge)
            %
            % Description:
            %
            % Inputs:
            %    directionParams   - OLDirectionParams_Bipolar object
            %                        defining the parameters for a unipolar
            %                        direction
            %    calibration       - OneLight calibration struct
            %    backgroundPrimary - [OPTIONAL] the primary values for the
            %                        background. If not passed, will try
            %                        and construct background from primary,
            %                        params, or name stored in
            %                        directionParams
            %
            % Outputs:
            %    directionStruct   - a 1x60 struct array (one struct per
            %                        observer age 1:60 yrs), with the
            %                        following fields:
            %                          * backgroundPrimary   : the primary
            %                                                  values for
            %                                                  the
            %                                                  background.
            %                          * differentialPositive: the
            %                                                  difference
            %                                                  in primary
            %                                                  values to be
            %                                                  added to the
            %                                                  background
            %                                                  primary to
            %                                                  create the
            %                                                  positive
            %                                                  direction
            %                          * differentialNegative: the
            %                                                  difference
            %                                                  in primary
            %                                                  values to be
            %                                                  added to the
            %                                                  background
            %                                                  primary to
            %                                                  create the
            %                                                  negative
            %                                                  direction
            %                          * calibration         : OneLight
            %                                                  calibration
            %                                                  struct used
            %                                                  to generate
            %                                                  the
            %                                                  directionStruct
            %                          * describe            : Any
            %                                                  additional
            %                                                  (meta)-
            %                                                  information
            %                                                  that might
            %                                                  be stored
            %
            % Optional key/value pairs:
            %    observerAge       - (vector of) observer age(s) to
            %                        generate direction struct for. When
            %                        numel(observerAge > 1), output
            %                        directionStruct will still be of size
            %                        [1,60], so that the index is the
            %                        observerAge. When numel(observerAge ==
            %                        1), directionStruct will be a single
            %                        struct. Default is 20:60.
            %
            % Notes:
            %    None.
            %
            % See also:
            %    OLBackgroundNominalPrimaryFromParams, 
            %    OLDirectionParamsDictionary

            % History:
            %    01/31/18  jv  wrote it, based on OLWaveformFromParams and
            %                  OLReceptorIsolateMakeDirectionNominalPrimaries
            %    02/12/18  jv  inserted in OLDirectionParams_ classes.
            
            %% Input validation
            parser = inputParser();
            parser.addRequired('directionParams',@(x) isstruct(x) || isa(x,'OLDirectionParams'));
            parser.addRequired('calibration',@isstruct);
            parser.addOptional('backgroundPrimary',[],@isnumeric);
            parser.addParameter('verbose',false,@islogical);
            parser.addParameter('observerAge',1:60,@isnumeric);
            parser.parse(directionParams,calibration,varargin{:});
                      
            %% Set some params
            % Pull out the 'M' matrix
            B_primary = calibration.computed.pr650M;
            
            % Wavelength sampling
            S = calibration.describe.S;

            % Assign a zero 'ambientSpd' variable if we're not using the
            % measured ambient.
            if directionParams.useAmbient
                ambientSpd = calibration.computed.pr650MeanDark;
            else
                ambientSpd = zeros(size(B_primary,1),1);
            end
            
            % Peg desired contrasts
            desiredContrasts = directionParams.modulationContrast;

            %% Get / make background primary
            if isempty(parser.Results.backgroundPrimary) % No primary specified in call            
                if isempty(directionParams.backgroundPrimary) % No primary specified in params
                    if isempty(directionParams.backgroundParams) % No background params specified
                        assert(isprop(directionParams,'backgroundName') && ~isempty(directionParams.backgroundName),'No backgroundPrimary, backgroundParams, or backgroundName specified')
                        
                        % Get backgroundParams from stored name
                        directionParams.backgroundParams = OLBackgroundParamsFromName(directionParams.backgroundName);
                    end
                    
                    % Make backgroundPrimary from params
                    directionParams.backgroundPrimary = OLBackgroundNominalPrimaryFromParams(directionParams.backgroundParams, calibration);
                end
                
                % Use backgroundPrimary stored in directionParams
                backgroundPrimary = directionParams.backgroundPrimary;
            else
                % Use backgroundPrimary specified in function call
                backgroundPrimary = parser.Results.backgroundPrimary;
            end
            
            backgroundSpd = OLPrimaryToSpd(calibration, currentBackgroundPrimary);

            %% Make direction information for each observer age
            for observerAgeInYears = parser.Results.observerAge
                % Set currentBackgroundPrimary for iteration
                currentBackgroundPrimary = backgroundPrimary;
                
                % Get fraction bleached for background we're actually using
                if (directionParams.doSelfScreening)
                    fractionBleached = OLEstimateConePhotopigmentFractionBleached(S,backgroundSpd,directionParams.pupilDiameterMm,directionParams.fieldSizeDegrees,observerAgeInYears,directionParams.photoreceptorClasses);
                else
                    fractionBleached = zeros(1,length(directionParams.photoreceptorClasses));
                end

                % Get lambda max shift.  Currently not passed but could be.
                lambdaMaxShift = [];

                % Construct the receptor matrix based on the bleaching fraction to this background.
                T_receptors = GetHumanPhotoreceptorSS(S,directionParams.photoreceptorClasses,directionParams.fieldSizeDegrees,observerAgeInYears,directionParams.pupilDiameterMm,lambdaMaxShift,fractionBleached);

                % Isolate the receptors by calling the ReceptorIsolate
                initialPrimary = currentBackgroundPrimary;
                modulationPrimarySignedPositive = ReceptorIsolate(T_receptors, directionParams.whichReceptorsToIsolate, ...
                    directionParams.whichReceptorsToIgnore,directionParams.whichReceptorsToMinimize,B_primary,currentBackgroundPrimary,...
                    initialPrimary,directionParams.whichPrimariesToPin,directionParams.primaryHeadRoom,directionParams.maxPowerDiff,...
                    desiredContrasts,ambientSpd);

                differentialPositive = modulationPrimarySignedPositive - currentBackgroundPrimary;
                differentialNegative = -1 * differentialPositive;

                %% Check gamut
                modulationPrimarySignedPositive = currentBackgroundPrimary + differentialPositive;
                modulationPrimarySignedNegative = currentBackgroundPrimary + differentialNegative;
                if any(modulationPrimarySignedNegative > 1) || any(modulationPrimarySignedNegative < 0)  || any(modulationPrimarySignedPositive > 1)  || any(modulationPrimarySignedPositive < 0)
                    error('Out of bounds.')
                end

                %% Calculate SPDs
                backgroundSpd = OLPrimaryToSpd(calibration, currentBackgroundPrimary);
                nominalSPDPositive = OLPrimaryToSpd(calibration, modulationPrimarySignedPositive);
                nominalSPDNegative = OLPrimaryToSpd(calibration, modulationPrimarySignedNegative);

                %% Assign all the fields
                % Business end
                directionStruct(observerAgeInYears).backgroundPrimary = currentBackgroundPrimary;              
                directionStruct(observerAgeInYears).differentialPositive = differentialPositive;                            
                directionStruct(observerAgeInYears).differentialNegative = differentialNegative;            
                directionStruct(observerAgeInYears).calibration = calibration;

                % Description
                directionStruct(observerAgeInYears).describe.observerAge = observerAgeInYears;
                directionStruct(observerAgeInYears).describe.params = directionParams;
                directionStruct(observerAgeInYears).describe.SPDAmbient = ambientSpd;
                directionStruct(observerAgeInYears).describe.NominalSPDBackground = backgroundSpd;
                directionStruct(observerAgeInYears).describe.NominalSPDPositiveModulation = nominalSPDPositive;
                directionStruct(observerAgeInYears).describe.NominalSPDNegativeModulation = nominalSPDNegative;
            end
            
            %% If a single age was specified, pull out just that struct.
            if numel(parser.Results.observerAge == 1)
                directionStruct = directionStruct(parser.Results.observerAge);
            end
        end
        
        function valid = OLDirectionParamsValidate(directionParams)
            valid = true;
        end
    end
    
end