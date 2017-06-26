function testPR670repeatability
    load ('/Users/Shared/Matlab/Experiments/PR650Checks/xPR-670_1/PR-670_1_Sphere_09-Mar-2016.mat')
    
    for k = 1:numel(theSpectra)
        spds(:,k) = theSpectra{k};
    end
    meanSPD = mean(spds,2);
    
    spdGain = 1000;
    hFig = figure(1); clf; set(hFig, 'Color', [1 1 1]); 
    subplot('Position', [0.04 0.05 0.45 0.94]);
    hold on
    for k = 1:numel(theSpectra)
        plot(spdGain*(squeeze(spds(:,k))), 'k-', 'LineWidth', 2.0);
    end
    set(gca,  'XLim', [1 numel(meanSPD)], 'XTickLabel', {}, 'FontSize', 16);
    ylabel('energy (mWatts)', 'FontSize', 20, 'FontWeight', 'bold');
    xlabel('wavelength', 'FontSize', 20, 'FontWeight', 'bold');
    grid on
    
    subplot('Position', [0.53 0.05 0.45 0.94]);
    hold on
    for k = 1:numel(theSpectra)
        plot(spdGain*(squeeze(spds(:,k)) - meanSPD), 'k-', 'LineWidth', 2.0);
    end
    set(gca, 'YLim', 0.5*[-1 1], 'XLim', [1 numel(meanSPD)], 'XTickLabel', {}, 'FontSize', 16);
    xlabel('wavelength', 'FontSize', 20, 'FontWeight', 'bold');
    grid on
    
    NicePlot.exportFigToPDF('PR670.pdf', hFig, 300);
end
