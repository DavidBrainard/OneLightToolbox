function [waveform, timestep, waveformDuration] = OLWaveformFromParams(waveformParams)
% Generate a named waveform from the given parameters
%
% Syntax:
%   waveform = OLWaveformFromParams(waveformParameters)
%   [waveform, timestep, waveformDuration] = OLWaveformFromParams(waveformParameters)  
%
% Description:
%    For several common types of waveforms, this function can generate the
%    actual waveform from parameters.
%
%    This function currently knows about the following types:
%       - pulse
%       - sinusoid
%
%    These parameters can be generated by OLWaveformParamsDefaults,
%    validated by OLWaveformParamsValidate, and several sets of
%    parameters are predefined in OLWaveformParamsDictionary.
%
% Inputs:
%    waveformParams   - struct defining the parameters for a type of
%                       waveform. Can be generated using
%                       OLWaveformParamsDefaults
%
% Outputs:
%    waveform         - a 1xt rowvector of differentialScalars in range [0,1] at each 
%                       timepoint.
%    timestep         - Timestep used to generate waveform
%    waveformDuration - Duration of the total waveform in seconds, at the
%                       given timestep (see above)
%
% Optional key/value pairs:
%    None.
%
% Notes:
%    None.
%
% See also:
%    OLWaveformParamsDefaults, OLWaveformParamsValidate,
%    OLWaveformParamsDictionary

% History:
%    01/29/18  jv, dhb  extracted from OLCalculateStartsStopsModulation,
%                       OLReceptorIsolateMakeModulationStartsStops

% Examples:

%% Generate timebase
timestep = waveformParams.timeStep;
waveformDuration = waveformParams.stimulusDuration;
timebase = 0:waveformParams.timeStep:waveformParams.stimulusDuration-waveformParams.timeStep;

switch waveformParams.type
    case 'pulse'
        % Pulse: a step of some unipolar contrast in some direction, from a
        % background, and returning back to that background. Can be
        % windowed.
        waveform = ones(1,length(timebase));
        
    case 'sinusoid'
        % Sinusoid: a bipolar variation of some contrast in some direction,
        % from a background, and returning back to that background. Can be
        % windowed.
        waveform = sin(2*pi*waveformParams.frequency*timebase+(pi/180)*waveformParams.phaseDegs);
    
    case 'squarewave'
        % Squarewave: a bipolar variation of some contrast in some direction,
        % from a background, and returning back to that background. Can be
        % windowed.
        waveform = sin(2*pi*waveformParams.frequency*timebase+(pi/180)*waveformParams.phaseDegs);
        waveform = waveform + 1 > 1;

    otherwise
        error('Unknown waveform type specified');
end
waveform = waveformParams.contrast * waveform;

%% Windowing
% At present all windows are half-cosine.
% Define if there should be a cosine fading at the beginning of
% end of the stimulus.
waveformParams.window.type = 'cosine';
waveformParams.window.cosineWindowIn = waveformParams.cosineWindowIn;
waveformParams.window.cosineWindowOut = waveformParams.cosineWindowOut;
waveformParams.window.cosineWindowDurationSecs = waveformParams.cosineWindowDurationSecs;
waveformParams.window.nWindowed = waveformParams.cosineWindowDurationSecs/waveformParams.timeStep;

% Then half-cosine window if specified
if (waveformParams.window.cosineWindowIn || waveformParams.window.cosineWindowOut)
    cosineWindow = ((cos(pi + linspace(0, 1, waveformParams.window.nWindowed)*pi)+1)/2);
    cosineWindowReverse = cosineWindow(end:-1:1);
end
if (waveformParams.window.cosineWindowIn)
    waveform(1:waveformParams.window.nWindowed) = waveform(1:waveformParams.window.nWindowed).*cosineWindow;
end
if (waveformParams.window.cosineWindowOut)
    waveform(end-waveformParams.window.nWindowed+1:end) = waveform(end-waveformParams.window.nWindowed+1:end).*cosineWindowReverse;
end

end