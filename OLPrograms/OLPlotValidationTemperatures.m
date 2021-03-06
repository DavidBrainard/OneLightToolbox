function OLPlotValidationTemperatures(varargin)
% OLPlotValidationTemperatures
%
%   Syntax:
%       OLPlotValidationTemperatures(varargin)
%
%   Optional parameter name/value pairs chosen from the following:
%       'targetCalType' - the type of cal
%           default: 'BoxDRandomizedLongCableAStubby1_ND02'
%
%       'rootDir'       - the location of the MELA_materials directory
%           default: '/Users1/DropBoxLinks/DropboxAguirreBrainardLabs/MELA_materials'
%
%   Description:
%       Plots validation temperature data for a given cal type.
%
%   Examples:
%    (1)   OLPlotValidationTemperatures(...
%           'targetCalType', 'BoxDRandomizedLongCableAStubby1_ND03', ...
%           'rootDir', 'Users/nicolas/Dropbox/MELA_materials');
%   
%    (2)   OLPlotValidationTemperatures('targetCalType', 'cals')
%
% 1/25/17  NPC     Wrote it.
% 1/27/17  NPC     If no targetCalType is passed, attempt to guess it.

% Parse inputs
p = inputParser;
p.addParameter('targetCalType', [], @ischar);
p.addParameter('rootDir', '/Users1/DropBoxLinks/DropboxAguirreBrainardLabs/MELA_materials/OneLightCalData', @ischar);
p.parse(varargin{:});

% Fetch and plot the temperature data
retrieveAndPlotTemperatureData(p.Results.rootDir, p.Results.targetCalType);
end


function retrieveAndPlotTemperatureData(rootDir, theTargetCalType)
    % Query user to select a cache file
    [theValidationCacheFile, pathName] = uigetfile('*.mat', 'Select a cache file to open', rootDir);
    s = load(fullfile(pathName,theValidationCacheFile));

    % Get the data
    availableCalTypes = fieldnames(s);
    if (isempty(theTargetCalType))
        theTargetCalType = availableCalTypes{1};
        if (numel(availableCalTypes)>1)
            fprintf(2,'Found more than 1 calTypes in that file. Analyzing the first one (''%s'')\n', theTargetCalType);  
        end
    else
        if (~ismember(theTargetCalType, availableCalTypes))
            fprintf(2,'''%s'' cal type not found in ''%s''.\n', theTargetCalType, fullfile(pathName,theValidationCacheFile));
            fprintf(2,'Cal types found:\n');
            for k = 1:numel(availableCalTypes)
                fprintf(2,'%d: ''%s''\n', k, availableCalTypes{k});
            end
            return
        end
    end
    s = s.(theTargetCalType);

    % Attempt to extract temperature data
    for calibrationIndex = 1:numel(s)
        foundTemperatureData(calibrationIndex) = false;
        
        theMeasurementData = s{calibrationIndex};
        if (~isstruct(theMeasurementData))
            fprintf(2, ' ''theMeasurementData'' is not a struct. A struct is expected. Skipping ...\n');
        else
            if (isfield(theMeasurementData, 'temperatureData'))
                allTemperatureData(calibrationIndex,:,:,:) = theMeasurementData.temperatureData.modulationAllMeas;
                foundTemperatureData(calibrationIndex) = true;
            elseif (isfield(theMeasurementData, 'temperature'))
                allFieldNames = fieldnames(theMeasurementData.temperature);
                for k = 1:numel(allFieldNames)
                    allTemperatureData(calibrationIndex,k,:,:) = theMeasurementData.temperature.(allFieldNames{k});
                end
                foundTemperatureData(calibrationIndex) = true;
            elseif (isfield(theMeasurementData, 'raw')) && (isfield(theMeasurementData.raw, 'temperature'))
                allFieldNames = fieldnames(theMeasurementData.raw.temperature);
                if (ismember('value', allFieldNames))
                    allTemperatureData(calibrationIndex,1,:,:) = theMeasurementData.raw.temperature.value;
                    foundTemperatureData(calibrationIndex) = true;
                else
                    allFieldNames
                    error('Did not find ''value'' field.');
                end
            else 
                fprintf('[calibration index: %d]: There were no ''temperatureData'' or ''temperature'' fields found in ''theMeasurementData'' struct of ''%s''.\n', calibrationIndex, fullfile(pathName,theValidationCacheFile));
                theMeasurementData
            end
        end
        
        if (isfield(theMeasurementData, 'date'))
            dateString{calibrationIndex} = sprintf('%s\nDate:%s', strrep(theTargetCalType, '_', ''),theMeasurementData.date);
        elseif (isfield(theMeasurementData,'describe')) &&  (isfield(theMeasurementData.describe, 'validationDate'))
            dateString{calibrationIndex} = sprintf('%s\nDate:%s', strrep(theTargetCalType, '_', ''), theMeasurementData.describe.validationDate);
        elseif (isfield(theMeasurementData, 'describe')) && (isfield(theMeasurementData.describe, 'date'))
            dateString{calibrationIndex} = sprintf('%s\nDate:%s', strrep(theTargetCalType, '_', ''), theMeasurementData.describe.date);
        else
            dateString{calibrationIndex} = sprintf('%s\nDate: could not be determined from the data file. Contact Nicolas.\n', strrep(theTargetCalType, '_', ''));
        end
        
    end
    
    if (any(foundTemperatureData) == 0)
        fprintf('None of the %d calibrations contain temperature data. Exiting\n', numel(s));
        return;
    end
  
    if (ndims(allTemperatureData) ~= 4)
        error('Something went wrong with the assumption of how temperature data are stored.\n');
    end
    clear 's'

    % Compute temperature range
    tempRange = [floor(min(allTemperatureData(:)))-1 ceil(max(allTemperatureData(:)))+1];

    % Plot data
    hFig = figure(1); clf;
    set(hFig, 'Position', [10 10 1150 540]);

    for calibrationIndex = 1:size(allTemperatureData,1)
        theTemperatureData = allTemperatureData(calibrationIndex,:,:,:);
        theOneLightTemp = [];
        theAmbientTemp = [];
        for iter1 = 1:size(theTemperatureData,2)
            for iter2 = 1:size(theTemperatureData,3)
                theOneLightTemp(numel(theOneLightTemp)+1) = theTemperatureData(1,iter1, iter2,1);
                theAmbientTemp(numel(theAmbientTemp)+1) = theTemperatureData(1,iter1, iter2,2);
            end
        end

        subplot(1,size(allTemperatureData,1), calibrationIndex)
        plot(1:numel(theOneLightTemp), theOneLightTemp(:), 'ro-', 'LineWidth', 1.5, 'MarkerSize', 10, 'MarkerFaceColor', [1 0.7 0.7]);
        hold on
        plot(1:numel(theOneLightTemp), theAmbientTemp(:), 'bo-', 'LineWidth', 1.5, 'MarkerSize', 10, 'MarkerFaceColor', [0.7 0.7 1.0]);

        hL = legend({'OneLight', 'Ambient'}, 'Location', 'SouthEast');
        % Finish plot
        box off
        grid on
        pbaspect([1 1 1])
        hL.FontSize = 12;
        hL.FontName = 'Menlo';       
        XLims = [0 numel(theOneLightTemp)+1];
        set(gca, 'XLim', XLims, 'YLim', tempRange, 'XTick', [1:2:numel(theOneLightTemp)], 'YTick', 0:1:100);
        set(gca, 'FontSize', 12);
        xlabel('measurement index', 'FontSize', 14, 'FontWeight', 'bold');
        ylabel('temperature (deg Celcius)', 'FontSize', 14, 'FontWeight', 'bold');
        drawnow;
        title(dateString{calibrationIndex});
    end
end
