classdef OLDirection_bipolar < OLDirection
    % Class defining a direction for use with OneLight devices
    %
    % Description:
    %    A direction of modulation, is a direction (vector) in primary space
    %    that corresponds to some desired direction in spectral or receptor
    %    space. An OLDirection object defines a direction as 2 vector
    %    componenents in primary space: the positive differential vector, and
    %    the negative differential vector. The positive and negative component
    %    of the direction are defined separately, because they can be
    %    asymmetric. Since these specifications are device/calibration
    %    dependent, the OLDirection object also stores a OneLight calibration
    %    struct.
    
    % History:
    %    03/02/18  jv  wrote it.
    %    03/12/18  jv  converted to OLDirection_bipolar
    
    properties
        differentialPositive;
        differentialNegative;
    end
    
    methods
        function this = OLDirection_bipolar(differentialPositive, differentialNegative, calibration, varargin)
            % Constructor for OLDirection_bipolar objects
            %
            %
            %
            
            % Parse input
            parser = inputParser();
            parser.addRequired('differentialPositive',@isnumeric);
            parser.addRequired('differentialNegative',@isnumeric);
            parser.addRequired('calibration',@isstruct);
            parser.addOptional('describe',struct(),@isstruct);
            parser.StructExpand = false;
            parser.parse(differentialPositive, differentialNegative, calibration, varargin{:});
            
            % Assign
            this.differentialPositive = differentialPositive;
            this.differentialNegative = differentialNegative;
            this.calibration = calibration;
            this.describe = parser.Results.describe;
        end        
    end
    
    %% Overloaded
    methods
        function out = eq(A,B)
            % Determine equality
            %
            %
            assert(isa(A,'OLDirection'),'OneLightToolbox:OLDirection:plus:InvalidInput','Inputs have to be OLDirection');
            assert(isa(B,'OLDirection'),'OneLightToolbox:OLDirection:plus:InvalidInput','Inputs have to be OLDirection');
            
            % Compare if calibrations match
            outCal = matchingCalibration(A,B);
            
            % Check if differentials match
            outDiffs = all([A.differentialPositive] == [B.differentialPositive]) & ...
                  all([A.differentialNegative] == [B.differentialNegative]);   
              
            % Combine
            out = outCal & outDiffs;
        end        
        
        function out = times(A,B)
            % Scale OLDirection; overloads the .* operator
            %
            % One of the operators has to be numerical, the other has to be
            % an (array of) OLDirection_bipolar(s)
            %
            %   X.*Y denotes element-by-element multiplication. X and Y
            %   must have compatible sizes. In the simplest cases, they can
            %   be the same size or one can be a scalar. Two inputs have
            %   compatible sizes if, for every dimension, the dimension
            %   sizes of the inputs are either the same or one of them is
            %   1.
            
            % Input validation
            if isa(A,'OLDirection')
                assert(isnumeric(B),'OneLightToolbox:OLDirection:times:InvalidInput','One input has to be numerical.');
                directions = A;
                scalars = B;
            elseif isnumeric(A)
                assert(isa(B,'OLDirection'),'OneLightToolbox:OLDirection:times:InvalidInput','One input has to be an OLDirection object.');
                directions = B;
                scalars = A;
            else
                error('OneLightToolbox:OLDirection:times:InvalidInput','One input has to be numerical.');
            end
            assert(iscolumn(scalars) || isrow(scalars),'OneLightToolbox:OLDirection:times:InvalidInput','Can currently only handle 1-dimensional vectors of scalars.');
            assert(iscolumn(directions) || isrow(directions),'OneLightToolbox:OLDirection:times:InvalidInput','Can currently only handle 1-dimensional array of OLDirections.');
            
            % Fencepost output
            out = OLDirection_bipolar.empty();
            
            % Create scaled directions
            d = 1;
            for s = scalars
                % Get the current direction
                direction = directions(d);
                if ~isscalar(directions)
                    d = d+1;
                end
                
                % Create new direction
                newDescribe = struct('createdFrom',struct('a',direction,'b',s,'operator','.*'),'correction',[],'validation',[]);
                newDirection = OLDirection_bipolar(s*direction.differentialPositive,s*direction.differentialNegative,direction.calibration,newDescribe);
                out = [out newDirection];
            end
        end
    end
end