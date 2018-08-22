function [deltaPrimaries,predictedSPD] = OLIterativeDeltaPrimariesContrast(deltaPrimaries0,primariesUsed,targetContrasts,measuredSPD,backgroundSPD,T_receptors,learningRate,cal)
% Use small signal approximation to estimate primaries that attain target contrast
%
% Syntax:
%     [deltaPrimaries,predictedSPD] = OLIterativeDeltaPrimariesContrast(deltaPrimaries0,primariesUsed,targetContrasts,measuredSPD,backgroundSPD,T_receptors,learningRate,cal)
%
% Desicription:
%     Use numerical search to find the deltaPrimaries that should be added to
%     primariesUsed, given that the desired contrasts are contrastDesired and the
%     spd measued for primariesUsed is measuredSPD.
%
%     If deltaPrimaries0 is passed as the empty matrix, the search starts at 0.
%     Otherwise at the passed value of deltaPrimaries0.
%
% Inputs:
%    deltaPrimaries0         - nPrimariesx1 column vector with initial
%                              guess as to deltaPrimaires.  Passing empty
%                              matrix sets this to all zeros.
%    primairesUsed           - nPrimariesx1 column vector with primaries
%                              used to produce measuredSPD.
%    measuredSPD             - nWlsx1 column vector with measured spectral
%                              power distribution when primariesUsed was used.
%    targetContrasts         - nReceptorsx1 column vector, giving target
%                              contrasts for each receptor class.
%    backgroundSPD           - nWlsx1 column vector, with background
%                              spectral power distribution with respect to
%                              which to compute contrasts.  This should be
%                              unscaled.
%    T_receptors             - nReceptorsxnWls matrix specifying receptor
%                              fundamentals.
%    learningRate            - Number betweenn 0 and 1. Aim this fraction
%                              from current contrasts towards target contrasts.
%    cal                     - struct containing calibration for OneLight
%
% Outputs:
%    deltaPrimaries          - nPrimariesx1 column vector column vector of delta
%                              primary values,
%    predictedSPD            - nWlsx1 column vector with the spectral power
%                              distribution predicted when deltaPrimaries is
%                              added to primariesUsed.

% Options for fmincon
if (verLessThan('matlab','2016a'))
    options = optimoptions('fmincon','Diagnostics','off','Display','off','Algorithm','active-set');
    options.MaxFunEvals = 200;
    options.TolFun = 1e-3;
else
    options = optimoptions('fmincon','Diagnostics','off','Display','off','Algorithm','active-set','OptimalityTolerance',1e-3,'MaxFunctionEvaluations',200);
end

% These bounds on deltas keep primaries in range 0-1.
vlb = -primariesUsed;
vub = 1-primariesUsed;

% Compute contrasts obtained with current measurement
backgroundReceptors = T_receptors*backgroundSPD;
measuredReceptors = T_receptors*mesuredSPD;
measuredContrasts = (measuredReceptors - backgroundReceptors) ./ backgroundReceptors;

% Figure out desired contrasts given learning rate
targetContrastsLearningRate =  measuredContrasts + learningRate*(targetContrasts - measuredContrasts);

% Initialize starting point
if (isempty(deltaPrimaries0))
    deltaPrimaries0 = zeros(size(primariesUsed));
end

% Use fmincon to find the desired primaries
deltaPrimaries = fmincon(@(deltaPrimaries)OLIterativeDeltaPrimariesContrastErrorFunction(deltaPrimaries,primariesUsed,targetContrastsLearningRate,measuredSPD,backgroundSPD,T_receptors,cal),...
    deltaPrimaries0,[],[],[],[],vlb,vub,[],options);

% When we search, we evaluate error based on the
% truncated version, so we just truncate here so that
% the effect matches that of the search.  The bounds on
% the search should prevent truncation, but just in case.
deltaPrimaries = OLTruncatedDeltaPrimaries(deltaPrimaries,primariesUsed,cal);

% Get predicted Spd
predictedSPD = OLPredictSpdFromDeltaPrimaries(deltaPrimaries,primariesUsed,spdMeasured,cal);

end 

function f = OLIterativeDeltaPrimariesContrastErrorFunction(deltaPrimaries,primariesUsed,targetContrasts,measuredSPD,backgroundSPD,T_receptors,cal)
% OLIterativeDeltaPrimariesErrorFunction  Error function for delta primary iterated search
%   f = OLIterativeDeltaPrimariesErrorFunction(deltaPrimaries,primariesUsed,targetContrasts,measuredSPD,backgroundSPD,T_receptors,contrastDesiredLearningRate,cal)
%
% Figures out how close the passed delta primaries come to producing the
% target contrasts, using small signal approximation and taking gamut
% limitations into account.

% Get small signal predicted SPD. This truncates primaries into range if
% they are not alredy.
predictedSPD = OLPredictSpdFromDeltaPrimaries(deltaPrimaries,primariesUsed,measuredSPD,cal);

% Get predicted contrasts
backgroundReceptors = T_receptors*backgroundSPD;
predictedReceptors = T_receptors*predictedSPD;
predictedContrasts = (predictedReceptors - backgroundReceptors) ./ backgroundReceptors;

% Compute error
diffContrasts = targetContrasts-predictedContrasts;
f = sqrt(mean(diffContrasts(:).^2));
end