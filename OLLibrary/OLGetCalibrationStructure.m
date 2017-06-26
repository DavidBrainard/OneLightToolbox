function cal = OLGetCalibrationStructure(varargin)
%OLGetCalibrationStructure - Get calibration structure from calibration file
%
% Examples:
%   cal = OLGetCalibrationStructure
%   cal = OLGetCalibrationStructure('CalibrationType','BoxDRandomizedLongCableAStubby1_ND02');
%   cal = OLGetCalibrationStructure('CalibrationType','BoxDRandomizedLongCableAStubby1_ND02','CalibrationDate','latest');
%   cal = OLGetCalibrationStructure('CalibrationType','BoxDRandomizedLongCableAStubby1_ND02','CalibrationDate','08-May-2017 12:30:33');
%
% We reference calibration files by their calibration file type.  These are
% enumerated in the class OLCalibrationType, so you need to edit the class
% definition file (OLCalibrationType.m in OneLightToolbox) when you want to
% add a calibration type.  The enumeration assocaites a calibration
% filename with each type.  Typically these are the same as each other, but
% the level of indirection allows for some flexibility.
%
% By default, this function looks for calibration files in the directory
% specified by getpref('OneLight','OneLightCalData').  You can override
% this by passing a CalibrationFolder key/value pair.
%
% With no arguments, this function prompts user to specify an available
% calibration type and a date. The available types are a subset of what is
% in the enumeration corresponding to types where there is an actual
% calibration file in the specified calibration folder.
%
% The calibration type and date can also be specified with optional
% key/value pairs, so that you can avoid the prompts if you want.
%
% Calibration types are specified by an enumeration, which the options
% defined in 'OLCalibrationTypes'.
%
% We typically set the 'OneLight' preferences in a local hook file, which
% is exectuted by ToolboxToolbox via tbUseProject.
%
% Optional key/value pairs
%   'CalibrationType','theCalibrationType' - Use the passed calibration type.
%   'CalibrationDate','theDateString' - Use the passed calibration date string.
%                                     - You can pass 'latest' to get the
%                                       most recent calibration.
%   'CalibrationFolder,'theFolderString' - Path to folder where calibration
%                                          files will be searched for.
%                                          Default is the empty string,
%                                          which causes the routine to look
%                                          in the result of
%                                          getpref('OneLight','OneLightCalData').
%
% See also: OLCalibrationTypes.

%
% 4/4/13  dhb, ms  Pulled out of a calling program as separate function.
% 6/4/17  dhb      Add key/value pair options.
% 6/6/17  dhb      Greatly expanded comments.
%         dhb      Added 'CalibrationFolder' key/value pair.

%% Parse key/value pairs
p = inputParser;
p.addParameter('CalibrationType', '', @isstr);
p.addParameter('CalibrationDate', '', @isstr);
p.addParameter('CalibrationFolder', '', @isstr);
p.parse(varargin{:});
params = p.Results;

%% Set the folder in which the calibration files live.
if (isempty(params.CalibrationFolder))
    calFolder = getpref('OneLight', 'OneLightCalData');
else
    calFolder = params.CalibrationFolder;
end
    
% Get the list of possible calibration types.
calTypes = enumeration('OLCalibrationTypes');

% Figure out the available calibration types, that is those 
% where there is an actual calibration file in the calibration folder.
availableCalTypes = OLGetAvailableCalibrationTypes('CalibrationFolder',params.CalibrationFolder);
numAvailableCalTypes = length(availableCalTypes);

% Determine calibration type to use.
%
% Either this was passed and we just make sure it is available
% or we prompt user to tell us.
calIndex = 0;
if (isempty(params.CalibrationType))
    keepPrompting = true;
    while keepPrompting
        % Show the available calibration types.
        fprintf('\n*** Available Calibration Types ***\n\n');
        for i = 1:length(availableCalTypes)
            fprintf('%d - %s\n', i, availableCalTypes(i).char);
        end
        fprintf('\n');
        
        calIndex = GetInput('Select a Calibration Type', 'number', 1);
        
        % Check the selection.
        if calIndex >= 1 && calIndex <= numAvailableCalTypes
            keepPrompting = false;
        else
            fprintf('\n* Invalid selection\n');
        end
    end
    
    % Extract the calibration file name.
    cal = availableCalTypes(calIndex).CalFileName;
else
    for i = 1:numAvailableCalTypes
        if (strcmp(params.CalibrationType,availableCalTypes(i).char))
            calIndex = i;
            break;
        end
    end
    if calIndex >= 1 && calIndex <= numAvailableCalTypes
    else
        error('Passed calibration type is not available');
    end
    
    % Extract the calibration file name.
    cal = availableCalTypes(calIndex).CalFileName;
end

% If we only have the name of the calibration file, prompt for the version
% of the calibration data we want.
calIndex = 0;
if ischar(cal)
    % Get all the calibration data.
    [~, cals] = LoadCalFile(cal, [], getpref('OneLight', 'OneLightCalData'));
    
    % Have the user select a calibration if there is more than 1 and we
    % didn't pass which one we wanted.
    if (length(cals) > 1)
        
        switch (params.CalibrationDate)
            case ''
                % Now have the user select an available calibration type to
                % analyze.
                keepPrompting = true;
                while keepPrompting
                    % Show the available calibration types.
                    fprintf('\n*** Available Calibrations ***\n\n');
                    for i = 1:length(cals)
                        fprintf('%d - %s\n', i, cals{i}.describe.date);
                    end
                    fprintf('\n');
                    
                    calIndex = GetWithDefault('Select a Calibration', length(cals));
                    
                    % Check the selection.
                    if calIndex >= 1 && calIndex <= length(cals)
                        keepPrompting = false;
                    else
                        fprintf('\n* Invalid selection\n');
                    end
                end
            case 'latest'
                calIndex = length(cals);
            otherwise
                for i = 1:length(cals)
                    if (strcmp(cals{i}.describe.date,params.CalibrationDate))
                        calIndex = i;
                        break;
                    end
                end
                if calIndex >= 1 && calIndex <= length(cals)
                else
                    error('Invalid calibration date specified');
                end
        end
    else
        calIndex = 1;
    end
    
    % Extract the desired calibration.
    cal = cals{calIndex};
end

