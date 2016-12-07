classdef OLCalibrationTypes
    % OLCalibrationTypes - Enumeration class for the different OneLight calibration types.
    %
    % OLCalibrationTypes properties:
    % CalFileName - The calibration file name associated with the calibration type.
    
    properties
        CalFileName;
    end
    
    methods
        function obj = OLCalibrationTypes(s)
            obj.CalFileName = s;
        end
    end
    
    enumeration
        % Classic eye pieces (pupil/psychophysics)
        BoxBRandomizedLongCableBEyePiece2_ND00('OLBoxBRandomizedLongCableBEyePiece2_ND00');
        BoxBRandomizedLongCableBEyePiece1_ND02('OLBoxBRandomizedLongCableBEyePiece1_ND02');
        BoxDRandomizedLongCableAEyePiece2_ND03('OLBoxDRandomizedLongCableAEyePiece2_ND03');
        BoxDRandomizedLongCableAEyePiece2_ND06('OLBoxDRandomizedLongCableAEyePiece2_ND06');
        %Note: Short RandomizedShortCableA is the collimating lens cable
        %w/o collimating lens.
        BoxCRandomizedShortCableAEyePiece1_ND05('OLBoxCRandomizedShortCableAEyePiece1_ND05');
            
        % Stubby Eye piece (scanner)
        BoxBRandomizedLongCableDStubby1_ND00('OLBoxBRandomizedLongCableDStubby1_ND00');
        BoxBRandomizedLongCableDStubby1_ND02('OLBoxBRandomizedLongCableDStubby1_ND02');
        BoxBRandomizedLongCableDStubby1_ND02_ND40CassetteB('OLBoxBRandomizedLongCableDStubby1_ND02_ND40CassetteB');
        BoxCRandomizedLongCableDStubby1_ND05('OLBoxCRandomizedLongCableDStubby1_ND05');
        BoxCRandomizedLongCableDStubby1_ND10('OLBoxCRandomizedLongCableDStubby1_ND10');
        BoxARandomizedShortCableBStubby1_ND00('OLBoxARandomizedShortCableBStubby1_ND00');
        
        %Hybrid configuration for psychophysics w/ MRI components        
        BoxBRandomizedLongCableBStubby1_ND02('OLBoxBRandomizedLongCableBStubby1_ND02');
    end
end
