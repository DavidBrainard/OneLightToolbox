function correctedDirection = OLCorrectDirection(direction, oneLight, varargin)
% Corrects OLDirection iteratively to attain predicted SPD
%
% Syntax:
%   correctedDirection = OLCorrectDirection(OLDirection, OneLight, radiometer)
%   correctedDirection = OLCorrectDirection(OLDirection, SimulatedOneLight)
%
% Description:
%    Detailed explanation goes here
%
% Inputs:
%    direction          - OLDirection object specifying the direction to
%                         correct.
%    oneLight           - a OneLight device driver object to control a
%                         OneLight device, can be real or simulated
%    radiometer         - Radiometer object to control a
%                         spectroradiometer. Can be passed empty when
%                         simulating
%
% Outputs:
%    correctedDirection - a new, corrected OLDirection, with the corrected
%                         primaries. Additional meta- and
%                         debugging-information got added to the structure
%                         in the 'describe' property.
%
% Optional key/value pairs:
%    nIterations            - Number of iterations. Default is 20.
%    learningRate           - Learning rate. Default is .8.
%    learningRateDecrease   - Decrease learning rate over iterations?
%                             Default is true.
%    asympLearningRateFactor- If learningRateDecrease is true, the
%                             asymptotic learning rate is
%                             (1-asympLearningRateFactor)*learningRate.
%                             Default = .5.
%    smoothness             - Smoothness parameter for OLSpdToPrimary.
%                             Default .001.
%    iterativeSearch        - Do iterative search with fmincon on each
%                             measurement interation? Default is false.
%
% See also:
%    OLCorrectPrimaryValues, OLValidateDirection, OLValidatePrimaryValues
%

% History:
%    02/09/18  jv  created around OLCorrectPrimaryValues, based on
%                  OLCorrectCacheFileOOC.

%% Input validation
parser = inputParser;
parser.addRequired('direction',@(x) isa(x,'OLDirection_unipolar'));
parser.addRequired('oneLight',@(x) isa(x,'OneLight'));
parser.addOptional('radiometer',[],@(x) isempty(x) || isa(x,'Radiometer'));
parser.KeepUnmatched = true; % allows fastforwarding of kwargs to OLCorrectPrimaryValues
parser.parse(direction,oneLight,varargin{:});
assert(isscalar(direction),'OneLightToolbox:OLDirection:ValidateDirection:NonScalar',...
    'Can currently only validate a single OLDirection at a time');
% assert(all(matchingCalibration(direction,background)),'OneLightToolbox:OLDirection:ValidateDirection:UnequalCalibration',...
%     'Directions and backgrounds do not share a calibration');
radiometer = parser.Results.radiometer;

correction.time = now;

%% Correct differential primary values
[correctedDifferentialPrimaryValues, correctionData] = OLCorrectPrimaryValues(direction.differentialPrimaryValues,direction.calibration,oneLight,radiometer,varargin{:});

%% Assign to OLDirection
newDescribe.createdFrom = struct('operator','correction','nominal',direction);
newDescribe.correction.dataPositiveCorrection = correctionData;
correctedDirection = OLDirection_unipolar(correctedDifferentialPrimaryValues,direction.calibration,newDescribe);

%% Save desired SPD in new direction
correctedDirection.SPDdesired = direction.SPDdesired;

end