% ModulationParamsDictionary
%
% Description:
%     Generate dictionary with modulation params.
%
% Note:
%     When you add a new type, you need to add that type to the corresponding switch statment
%     in OLCheckCacheParamsAgainstCurrentParams.
%
% See also: OLCheckCacheParamsAgainstCurrentParams.

% 6/23/17  npc  Wrote it.
% 7/19/17  npc  Added a type for each modulation. For now, there is only one type: 'basic'. 
%               Defaults and checking are done according to type.
%               Isomorphic direction name and cache filename.

function d = OLModulationParamsDictionary(protocolParams)
% Initialize dictionary
d = containers.Map();

%% MaxContrast3sSegment
modulationName = 'MaxContrast3sSegment';
type = 'basic';

params = defaultParams(type);
params.name = modulationName;
d = paramsValidateAndAppendToDictionary(d, params);

end

function d = paramsValidateAndAppendToDictionary(d, params)

% Get all the expected field names for this type
allFieldNames = fieldnames(defaultParams(params.type));

% Test that there are no extra params
if (~all(ismember(fieldnames(params),allFieldNames)))
    fprintf(2,'\nParams struct contain extra params\n');
    fNames = fieldnames(params);
    idx = ismember(fieldnames(params),allFieldNames);
    idx = find(idx == 0);
    for k = 1:numel(idx)
        fprintf(2,'- ''%s'' \n', fNames{idx(k)});
    end
    error('Remove extra params or update defaultParams\n');
end

% Test that all expected params exist and that they have the expected type
switch (params.type)
    case 'basic'
        assert((isfield(params, 'dictionaryType')           && ischar(params.dictionaryType)),              sprintf('params.dictionaryType does not exist or it does not contain a string value.'));
        assert((isfield(params, 'type')                     && ischar(params.type)),                        sprintf('params.type does not exist or it does not contain a string value.'));
        assert((isfield(params, 'name')                     && ischar(params.name)),                        sprintf('params.name does not exist or it does not contain a string value.'));
        assert((isfield(params, 'trialDuration')            && isnumeric(params.trialDuration)),            sprintf('params.trialDuration does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'timeStep')                 && isnumeric(params.timeStep)),                 sprintf('params.timeStep does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'cosineWindowIn')           && islogical(params.cosineWindowIn)),           sprintf('params.cosineWindowIn does not exist or it does not contain a boolean value.'));
        assert((isfield(params, 'cosineWindowOut')          && islogical(params.cosineWindowOut)),          sprintf('params.cosineWindowOut does not exist or it does not contain a boolean value.'));
        assert((isfield(params, 'cosineWindowDurationSecs') && isnumeric(params.cosineWindowDurationSecs)), sprintf('params.cosineWindowDurationSecs does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'nFrequencies')             && isnumeric(params.nFrequencies)),             sprintf('params.nFrequencies does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'nPhases')                  && isnumeric(params.nPhases)),                  sprintf('params.nPhases does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'modulationMode')           && ischar(params.modulationMode)),              sprintf('params.modulationMode does not exist or it does not contain a string value.'));
        assert((isfield(params, 'modulationWaveForm')       && ischar(params.modulationWaveForm)),          sprintf('params.modulationWaveForm does not exist or it does not contain a string value.'));
        assert((isfield(params, 'modulationFrequencyTrials')&& isnumeric(params.modulationFrequencyTrials)),sprintf('params.modulationFrequencyTrials does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'modulationPhase')          && isnumeric(params.modulationPhase)),          sprintf('params.modulationPhase does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'phaseRandSec')             && isnumeric(params.phaseRandSec)),             sprintf('params.phaseRandSec does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'preStepTimeSec')           && isnumeric(params.preStepTimeSec)),           sprintf('params.preStepTimeSec does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'stepTimeSec')              && isnumeric(params.stepTimeSec)),              sprintf('params.stepTimeSec does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'carrierFrequency')         && isnumeric(params.carrierFrequency)),         sprintf('params.carrierFrequency does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'carrierPhase')             && isnumeric(params.carrierPhase)),             sprintf('params.carrierPhase does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'nContrastScalars')         && isnumeric(params.nContrastScalars)),         sprintf('params.nContrastScalars does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'contrastScalars')          && isnumeric(params.contrastScalars)),          sprintf('params.contrastScalars does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'maxContrast')              && isnumeric(params.maxContrast)),              sprintf('params.maxContrast does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'coneNoise')                && isnumeric(params.coneNoise)),                sprintf('params.coneNoise does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'coneNoiseFrequency')       && isnumeric(params.coneNoiseFrequency)),       sprintf('params.coneNoiseFrequency does not exist or it does not contain a numeric value.'));
        assert((isfield(params, 'stimulationMode')          && ischar(params.stimulationMode)),             sprintf('params.stimulationMode does not exist or it does not contain a string value.'));
    otherwise
        error('Unknown modulation starts/stops type');
end

% All validations OK. Add entry to the dictionary.
d(params.name) = params;
end


function params = defaultParams(type)

params = struct();
params.type = type;
params.name = '';

switch (type)
    case 'basic'
        params.dictionaryType = 'Modulation';
        params.trialDuration = 3;                   % Number of seconds to show each trial
        params.timeStep = 1/64;                     % Number ms of each sample time
        params.cosineWindowIn = true;               % If true, have a cosine fade-in
        params.cosineWindowOut = true;              % If true, have a cosine fade-out
        params.cosineWindowDurationSecs = 0.5;      % Duration (in secs) of the cosine fade-in
        
        % Modulation information
        params.nFrequencies = 1;                    % Total number of frequencies
        params.nPhases = 1;                         % Total number of phases
        params.modulationMode = 'pulse';
        params.modulationWaveForm = 'pulse';
        
        % Modulation frequency parameters
        params.modulationFrequencyTrials = [];     % Sequence of modulation frequencies
        params.modulationPhase = [];
        
        params.phaseRandSec = [0];                 % Phase shifts in seconds
        params.preStepTimeSec = 0.5;               % Time before step
        params.stepTimeSec = 2;
        
        % Carrier frequency parameters
        params.carrierFrequency = [-1];            % Sequence of carrier frequencies
        params.carrierPhase = [-1];
        
        % Contrast scaling
        params.nContrastScalars = 1;               % Number of different contrast scales
        params.contrastScalars = [1];              % Contrast scalars (as proportion of max.)
        params.maxContrast = 4;
        
        params.coneNoise = 0;                      % Do cone noise?
        params.coneNoiseFrequency = 8;
        
        % Stimulation mode
        params.stimulationMode = 'maxmel';
    otherwise
        error('Unknown modulation starts/stops type: ''%s''.\n', type);
end
end

