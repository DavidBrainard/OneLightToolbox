function OLCheckPrimaryCorrection(protocolParams)
%%OLCheckPrimaryCorrection  Check how well correction of primaries worked.
%
% Syntax:
%    OLCheckPrimaryCorrection(protocolParams)
%
% Description:
%    This script analyzes the output of the procedure that tunes up the primaries based on 
%    a measurement/update loop.  Its main purpose in life is to help us debug the procedure,
%    running it would not be a normal part of operation, as long as the validations come out well.
%
% Input:
%      protocolParams (struct)               Parameters of the current protocol.
%
% Output:
%      None.
%
% Optional key/value pairs:
%    None.

% 06/18/17  dhb  Update header comment.  Rename.
% 09/01/17  mab  Start generalizing by having it read protocol params.

%% THIS NEEDS UPDATING TO WORK THROUGH MULTIPLE CORRECTED DIRECTIONS, ETC.
%% IT IS CURRENTLY A QUICK UPDATE OF AN OLD ROUTINE.

%% Get some data to analyze
%
% This is hard coded in right now, until we mind-meld this code with our new approach approach.
cacheBasePath = getpref(protocolParams.protocol, 'DirectionCorrectedPrimariesBasePath');
load(fullfile(cacheBasePath, protocolParams.observerID, protocolParams.todayDate, protocolParams.sessionName, 'Direction_LightFlux_330_330_20.mat'));

% Identify the box
theBox = protocolParams.calibrationType;

% Convert data to standardized naming for here
eval(['theData = ' theBox ';  clear ' theBox ';']);

%% Correction actually run?
%
% If not, we can't really do a full analysis
if (~isfield(theData{1}.data,'correction'))
    fprintf('Correction not actually run.  Not analyzing.\n');
    fprintf('Could add a plot of primaries and nominal spectra here if desired.\n');
    return;
end

%% Discover the observer age
theObserverAgeIndex = find(~(cellfun(@isempty, {theData{1}.data.correction})));

%% How many iterations were run?  And how many primaries were there?
nIterations = size(theData{1}.data(theObserverAgeIndex).correction.backgroundSpdMeasuredAll, 2);
nPrimaries = size(theData{1}.data(theObserverAgeIndex).correction.modulationPrimaryUsedAll, 1);

%% What's the wavelength sampling?
wls = SToWls([380 2 201]);

%% Skipped primaries
%
% Not sure we need this
nShortPrimariesSkip = theData{1}.cal.describe.nShortPrimariesSkip;
nLongPrimariesSkip = theData{1}.cal.describe.nLongPrimariesSkip;

%% Determine some axis limits
%
% Spectral power
ylimMax = 1.1*max(max([theData{1}.data(theObserverAgeIndex).correction.modulationSpdMeasuredAll theData{1}.data(theObserverAgeIndex).correction.backgroundSpdMeasuredAll]));

%% Print some diagnostic information
kScale = theData{1}.data(theObserverAgeIndex).correction.kScale;
fprintf('Value of kScale: %0.2f\n',kScale);

%% Start a diagnositic plot
contrastPlot = figure; clf; set(contrastPlot,'Position',[220,600 500 500]);
backgroundPlot = figure; clf; set(backgroundPlot,'Position',[220 600 1150 725]);
modulationPlot = figure; clf; set(modulationPlot,'Position',[220 600 1150 725]);

%% Get the calibration file, for some checks
cal = theData{1}.data(theObserverAgeIndex).cal;

%% Clean up cal file primaries by zeroing out light we don't think is really there.    
zeroItWLRangeMinus = 100;
zeroItWLRangePlus = 100;
cal = OLZeroCalPrimariesAwayFromPeak(cal,zeroItWLRangeMinus,zeroItWLRangePlus);

%% Get correction parameters
correctDescribe = theData{1}.data(theObserverAgeIndex).correctionDescribe;

%% Plot what we got
%
% We multiply measurements by kScale to bring everything into a consistent space
backgroundPrimaryInitial = theData{1}.data(theObserverAgeIndex).correction.backgroundPrimaryInitial;
backgroundSpectrumDesired = theData{1}.data(theObserverAgeIndex).correction.backgroundSpdDesired;

modulationSpectrumDesired = theData{1}.data(theObserverAgeIndex).correction.modulationSpdDesired;
modulationPrimaryInitial = theData{1}.data(theObserverAgeIndex).correction.modulationPrimaryInitial;
spectraMeasured = [];
primariesUsed = [];
primaryFig = figure;
for ii = 1:nIterations
    % Pull out some data for convenience
    backgroundSpectrumMeasuredScaled = kScale*theData{1}.data(theObserverAgeIndex).correction.backgroundSpdMeasuredAll(:,ii);
    backgroundPrimaryUsed = theData{1}.data(theObserverAgeIndex).correction.backgroundPrimaryUsedAll(:,ii);
    backgroundNextPrimaryTruncatedLearningRate = theData{1}.data(theObserverAgeIndex).correction.backgroundNextPrimaryTruncatedLearningRateAll(:,ii);
    backgroundDeltaPrimaryTruncatedLearningRate  = theData{1}.data(theObserverAgeIndex).correction.backgroundDeltaPrimaryTruncatedLearningRateAll(:,ii);
    if (any(backgroundNextPrimaryTruncatedLearningRate ~= backgroundPrimaryUsed + backgroundDeltaPrimaryTruncatedLearningRate))
        error('Background Hmmm.');
    end
    backgroundNextSpectrumPredictedTruncatedLearningRate = OLPredictSpdFromDeltaPrimaries(backgroundDeltaPrimaryTruncatedLearningRate,backgroundPrimaryUsed,backgroundSpectrumMeasuredScaled,cal);
      
    % Find delta primaries for next iter from scratch here.  This is to
    % verify that we know how we did it, so that we can then explore other
    % methods of doing so.
    if (correctDescribe.learningRateDecrease)
        learningRateThisIter = correctDescribe.learningRate*(1-(ii-1)*0.75/(correctDescribe.nIterations-1));
    else
        learningRateThisIter = correctDescribe.learningRate;
    end
    backgroundDeltaPrimaryTruncatedLearningRateAgain = OLLinearDeltaPrimaries(backgroundPrimaryUsed,backgroundSpectrumMeasuredScaled,backgroundSpectrumDesired,learningRateThisIter,correctDescribe.smoothness,cal);
    if (correctDescribe.iterativeSearch)
        [backgroundDeltaPrimaryTruncatedLearningRateAgain,backgroundNextSpectrumPredictedTruncatedLearningRateAgain] = ...
            OLIterativeDeltaPrimaries(backgroundDeltaPrimaryTruncatedLearningRateAgain,backgroundPrimaryUsed,backgroundSpectrumMeasuredScaled,backgroundSpectrumDesired,learningRateThisIter,cal);
    end
    [backgroundDeltaPrimaryTruncatedLearningRateAgain1,backgroundNextSpectrumPredictedTruncatedLearningRateAgain1] = ...
            OLIterativeDeltaPrimaries(backgroundPrimaryInitial-backgroundPrimaryUsed,backgroundPrimaryUsed,backgroundSpectrumMeasuredScaled,backgroundSpectrumDesired,learningRateThisIter,cal);         
    
    modulationSpectrumMeasuredScaled = kScale*theData{1}.data(theObserverAgeIndex).correction.modulationSpdMeasuredAll(:,ii);
    modulationPrimaryUsed = theData{1}.data(theObserverAgeIndex).correction.modulationPrimaryUsedAll(:,ii);
    modulationNextPrimaryTruncatedLearningRate = theData{1}.data(theObserverAgeIndex).correction.modulationNextPrimaryTruncatedLearningRateAll(:,ii);
    modulationDeltaPrimaryTruncatedLearningRate  = theData{1}.data(theObserverAgeIndex).correction.modulationDeltaPrimaryTruncatedLearningRateAll(:,ii);
    if (any(modulationNextPrimaryTruncatedLearningRate ~= modulationPrimaryUsed + modulationDeltaPrimaryTruncatedLearningRate))
        error('Nodulation Hmmm.');
    end
    modulationNextSpectrumPredictedTruncatedLearningRate = OLPredictSpdFromDeltaPrimaries(modulationDeltaPrimaryTruncatedLearningRate,modulationPrimaryUsed,modulationSpectrumMeasuredScaled,cal);
    
    % We can build up a correction matrix for predcition of delta spds from
    % delta primaries, based on what we've measured so far.
    if (ii == 1)
        backgroundSpectrumInitial = backgroundSpectrumMeasuredScaled;
        modulationSpectrumInitial = modulationSpectrumMeasuredScaled;    
    else
        spectraMeasured = [spectraMeasured backgroundSpectrumMeasuredScaled modulationSpectrumMeasuredScaled];
        primariesUsed = [primariesUsed backgroundPrimaryUsed modulationPrimaryUsed];
        spectraPredicted = cal.computed.pr650M*primariesUsed+cal.computed.pr650MeanDark(:,ones(size(primariesUsed,2),1));
        for kk = 1:size(spectraMeasured,2)
            primariesRecovered(:,kk) = lsqnonneg(cal.computed.pr650M,spectraMeasured(:,kk)-cal.computed.pr650MeanDark);
        end
        spectraPredictedFromRecovered = cal.computed.pr650M*primariesRecovered+cal.computed.pr650MeanDark(:,ones(size(primariesUsed,2),1));
        
        whichPrimaries = [25,35,52];
        theColors = ['r' 'g' 'b' 'k' 'c'];
        figure(primaryFig); clf; hold on
        for kk = 1:length(whichPrimaries)
            whichColor = rem(kk,length(theColors)) + 1;
            plot(primariesUsed(whichPrimaries(kk),:),primariesRecovered(whichPrimaries(kk),:),theColors(whichColor),'LineWidth',3);
        end
        plot([0 1],[0 1],'k:');
        xlabel('Primaries Used'); ylabel('Primaries Recovered');
        xlim([0 1]); ylim([-1 1]);
        
        figure; clf; 
        lastFigIndex = 0;
        for kk = 1:2
            subplot(1,2,kk); hold on;
            plot(spectraMeasured(:,lastFigIndex+kk),'ro');
            plot(spectraPredicted(:,lastFigIndex+kk) ,'bx');
            plot(spectraPredictedFromRecovered(:,lastFigIndex+kk),'r');
        end 
        lastFigIndex = lastFigIndex + 2;
        
        whichPrimaries = [25,35,52];
        theColors = ['r' 'g' 'b' 'k' 'c'];
        figure(primaryFig); clf; hold on
        for kk = 1:length(whichPrimaries)
            whichColor = rem(kk,length(theColors)) + 1;
            plot(primariesUsed(whichPrimaries(kk),:),primariesRecovered(whichPrimaries(kk),:),theColors(whichColor),'LineWidth',3);
        end
        plot([0 1],[0 1],'k:');
        xlabel('Primaries Used'); ylabel('Primaries Recovered');
        xlim([0 1]); ylim([-1 1]);
    end 
    
    %% Background tracking plot
    %
    % Black is the spectrum our little heart desires.
    % Green is what we measured.
    % Red is what our procedure thinks we'll get on the next iteration.
    figure(backgroundPlot); clf;
    subplot(2,2,1); hold on 
    plot(wls,backgroundSpectrumDesired,'k:','LineWidth',3);
    plot(wls,backgroundSpectrumMeasuredScaled,'g','LineWidth',2);
    xlabel('Wavelength'); ylabel('Spd Power'); title(sprintf('Background Spd, iter %d',ii));
    legend({'Desired','Measured'},'Location','NorthWest');

    % Black is the initial primaries we started with
    % Green is what we used to measure the spectra on this iteration.
    % Blue is the primaries we'll ask for next iteration.
    subplot(2,2,2); hold on
    plot(1:nPrimaries,backgroundPrimaryInitial,'k:','LineWidth',3);
    plot(1:nPrimaries,backgroundPrimaryUsed,'g','LineWidth',2);
    plot(1:nPrimaries,backgroundNextPrimaryTruncatedLearningRate,'b','LineWidth',2);
    xlabel('Primary Number'); ylabel('Primary Value'); title(sprintf('Background Primary, iter %d',ii));
    legend({'Initial','Used','Next'},'Location','NorthEast');
    
    % Green is the difference between what we want and what we measured.
    % Black is what we predicted it would be on this iteration.
    % Red is what we think it will be on the the next iteration.
    subplot(2,2,3); hold on 
    plot(wls,backgroundSpectrumDesired-backgroundSpectrumMeasuredScaled,'g','LineWidth',5);
    if (ii > 1)
        plot(wls,backgroundDeltaPredictedLastTime,'k:','LineWidth',5);
    else
        plot(NaN,NaN);
    end
    plot(wls,backgroundSpectrumDesired-backgroundNextSpectrumPredictedTruncatedLearningRate,'r','LineWidth',5);
    plot(wls,backgroundSpectrumDesired-backgroundNextSpectrumPredictedTruncatedLearningRateAgain1,'c','LineWidth',  3);
    if (correctDescribe.iterativeSearch)
        plot(wls,backgroundSpectrumDesired-backgroundNextSpectrumPredictedTruncatedLearningRateAgain,'k:','LineWidth',1);
    end
    title('Predicted delta spectrum on next iteration');
    xlabel('Wavelength'); ylabel('Delta Spd Power'); title(sprintf('Spd Deltas, iter %d',ii));
    legend({'Measured Current Delta','Predicted Current Delta','Predicted Next Delta','Predicted Other Start'},'Location','NorthWest');
    backgroundDeltaPredictedLastTime = backgroundSpectrumDesired-backgroundNextSpectrumPredictedTruncatedLearningRate;
    ylim([-10e-4 10e-4]);
    
    % Green is the difference between the primaries we will ask for on the
    % next iteration and those we just used.
    subplot(2,2,4); hold on
    plot(1:nPrimaries,backgroundNextPrimaryTruncatedLearningRate-backgroundPrimaryUsed,'g','LineWidth',2);
    ylim([-0.5 0.5]);
    xlabel('Primary Number'); ylabel('Primary Value');
    title('Delta primary for next iteration');
    
    %% Modulation tracking plot
    %
    % Black is the spectrum our little heart desires.
    % Green is what we measured.
    % Red is what our procedure thinks we'll get on the next iteration.
    figure(modulationPlot); clf;
    subplot(2,2,1); hold on 
    plot(wls,modulationSpectrumDesired,'k:','LineWidth',3);
    plot(wls,modulationSpectrumMeasuredScaled,'g','LineWidth',2);
    xlabel('Wavelength'); ylabel('Spd Power'); title(sprintf('Modulation Spd, iter %d',ii));
    legend({'Desired','Measured'},'Location','NorthWest');

    % Black is the initial primaries we started with
    % Green is what we used to measure the spectra on this iteration.
    % Blue is the primaries we'll ask for next iteration.
    subplot(2,2,2); hold on
    plot(1:nPrimaries,modulationPrimaryInitial,'k:','LineWidth',3);
    plot(1:nPrimaries,modulationPrimaryUsed,'g','LineWidth',2);
    plot(1:nPrimaries,modulationNextPrimaryTruncatedLearningRate,'b','LineWidth',2);
    xlabel('Primary Number'); ylabel('Primary Value'); title(sprintf('Modulation Primary, iter %d',ii));
    legend({'Initial','Used','Next'},'Location','NorthEast');
    
    % Green is the difference between what we want and what we measured.
    % Black is what we predicted it would be on this iteration.
    % Red is what we think it will be on the the next iteration.
    subplot(2,2,3); hold on 
    plot(wls,modulationSpectrumDesired-modulationSpectrumMeasuredScaled,'g','LineWidth',4);
    if (ii > 1)
        plot(wls,modulatoinDeltaPredictedLastTime,'k:','LineWidth',3);
    else
        plot(NaN,NaN);
    end
    plot(wls,modulationSpectrumDesired-modulationNextSpectrumPredictedTruncatedLearningRate,'r','LineWidth',2);
    title('Predicted delta spectrum on next iteration');
    xlabel('Wavelength'); ylabel('Delta Spd Power'); title(sprintf('Spd Deltas, iter %d',ii));
    legend({'Measured Current Delta','Predicted Current Delta','Predicted Next Delta',},'Location','NorthWest');
    modulatoinDeltaPredictedLastTime = modulationSpectrumDesired-modulationNextSpectrumPredictedTruncatedLearningRate;
    ylim([-10e-4 10e-4]);
    
    % Green is the difference between the primaries we will ask for on the
    % next iteration and those we just used.
    subplot(2,2,4); hold on
    plot(1:nPrimaries,modulationNextPrimaryTruncatedLearningRate-modulationPrimaryUsed,'g','LineWidth',2);
    ylim([-0.5 0.5]);
    xlabel('Primary Number'); ylabel('Primary Value');
    title('Delta primary for next iteration');
    
    % Compute contrasts

    % NEED TO GET PHOTORECEPTORS FROM DIRECTION CACHE FILE AND/OR GENERATE THEM.  SEE
    % OLAnalyzeDirectionCorrectedPrimaries for the basic way this looks.  THEN SHOULD
    % BE ABLE TO PLOT CONTRASTS PRETTY EASILY.
    %
    % Grab cell array of photoreceptor classes.  Use what was in the direction file
    % if it is there, otherwise standard L, M, S and Mel.
    %
    % This might not be the most perfect check for what is stored with the nominal direction primaries,
    % but until it breaks we'll go with it.
    % if isfield(directionCacheData.directionParams,'photoreceptorClasses')
    %     if (directionCacheData.data(protocolParams.observerAgeInYrs).describe.params.fieldSizeDegrees ~=  protocolParams.fieldSizeDegrees)
    %         error('Field size used for direction does not match that specified in protocolPrams.');
    %     end
    %     if (directionCacheData.data(protocolParams.observerAgeInYrs).describe.params.pupilDiameterMm ~=  protocolParams.pupilDiameterMm)
    %         error('Pupil diameter used for direction does not match that specified in protocolPrams.');
    %     end
    %     photoreceptorClasses = directionCacheData.data(protocolParams.observerAgeInYrs).describe.photoreceptors;
    %     T_receptors = directionCacheData.data(protocolParams.observerAgeInYrs).describe.T_receptors;
    % else
    %     photoreceptorClasses = {'LConeTabulatedAbsorbance'  'MConeTabulatedAbsorbance'  'SConeTabulatedAbsorbance'  'Melanopsin'};
    %     T_receptors = GetHumanPhotoreceptorSS(S,photoreceptorClasses,protocolParams.fieldSizeDegrees,protocolParams.observerAgeInYrs,protocolParams.pupilDiameterMm,[],[]);
    % end

    % backgroundReceptors = T_receptors*backgroundSpectrumMeasuredScaled;
    % modulationReceptors = T_receptors*modulationSpectrumMeasuredScaled;
    % contrasts(:,ii) = (modulationReceptors-backgroundReceptors) ./ backgroundReceptors;
    
    %% Contrast figure
    % figure(contrastPlot);
    % subplot(1,2,1);
    % hold off;
    % plot(1:ii, 100*contrasts(1, 1:ii), '-sr', 'MarkerFaceColor', 'r'); hold on
    % plot(1:ii, 100*contrasts(2, 1:ii), '-sg', 'MarkerFaceColor', 'g');
    % plot(1:ii, 100*contrasts(3, 1:ii), '-sb', 'MarkerFaceColor', 'b');
    % xlabel('Iteration #'); xlim([0 nIterations+1]);
    % ylabel('LMS Contrast'); %ylim(]);
    % subplot(1,2,2);
    % hold off;
    % plot(1:ii,contrasts(4, 1:ii), '-sc', 'MarkerFaceColor', 'c'); hold on
    % xlabel('Iteration #'); xlim([0 nIterations+1]);
    % ylabel('Mel Contrast');
    
    %% Force draw
    drawnow;
    
    % Report some things we might want to know
    nZeroBgSettings(ii) = length(find(theData{1}.data(theObserverAgeIndex).correction.backgroundPrimaryUsedAll(:,ii) == 0));
    nOneBgSettings(ii) = length(find(theData{1}.data(theObserverAgeIndex).correction.backgroundPrimaryUsedAll(:,ii) == 1));
    nZeroModSettings(ii) = length(find(theData{1}.data(theObserverAgeIndex).correction.modulationPrimaryUsedAll(:,ii) == 0));
    nOneModSettings(ii) = length(find(theData{1}.data(theObserverAgeIndex).correction.modulationPrimaryUsedAll(:,ii) == 1));
    fprintf('Iteration %d\n',ii);
    fprintf('\tNumber zero bg primaries: %d, one bg primaries: %d, zero mod primaries: %d, one mod primaries: %d\n',nZeroBgSettings(ii),nOneBgSettings(ii),nZeroModSettings(ii),nOneModSettings(ii));
    
    %commandwindow;
    %pause;
    
end