classdef GameData < handle
    % to use this class:
    % import GameData.*
    % gameState = constructGameBoard("background_image_path", "filled_image_path")
    % gameState.updateBoard();

    properties
        PERIMETER_UPPER_BOUND           = 170;                              % upper & lower bound is a buffer which isolates all 8 well
        PERIMETER_LOWER_BOUND           = 160;                              % locations. *** this may need to be modified
        EMPTY                           = -999;
        SIZE                            = 8;
        MAGNET                          = 'D3';
        wellLocation    = [];                                               % all 8 well locations start with a wellColor of -999
                                                                            % wellLocation will be calculated and represented as an angle
                                                                            % we need these locations to know where to drop off our washer

        bb_xMin
        bb_yMin
        bb_xMax
        bb_yMax                                                             % contains the bounding box for each of the game pieces
        sortedIndexing  = [];
        wellColor       = [];                                               % -999 will be an empty well location
        wellLetter      = ['H', 'F', 'D', 'B', 'A', 'C', 'E', 'G'];         % holds the letter value of each well location
        washerLocation  = [];                                               % hold the location of any washers on the board
        wellLocMotor    = [];                                               % holds the positive and negative locations for the shortest distance from homeLocation
        washerLetter    = [''];                                             % holds the cooresponding letter of the washer

        origin                                                              % this may need to be calculated from the rectangle
        homeLocation                                                        % starting point for the electromagnet
        num_items_board
        num_items_game
        img_background                                                      % stored background image
        img_snapshot                                                        % current state of the board... a snapshot of it
        img_difference                                                     
        img_diffNoiseless                                                  
        boardSTATS                                                          % STATS struct of the background image
        gameSTATS                                                           % STATS struct of the actual game
        cam              = [];                                              % camera
    end

    methods(Static)
        function gameState = constructGameBoard(background_PATH, filledBoard_PATH)
            gameState                       = GameData;                     % create an instance of our class
            if exist('background_PATH', 'var')
                gameState.img_background    = imread(background_PATH);      % set background img **webcam
                gameState.img_snapshot      = imread(filledBoard_PATH);     
                
            else
                gameState                   = initializeCamera();
                gameState.background        = snapshot(gameState.cam);
                gameState.img_snapshot      = snapshot(gameState.cam);
            end
            
            gameState.calibrateOrigin();
            gameState.calibrateWellLocations();
            gameState.updateGame();
        end

        function arduinoMagnet()
            if a.readDigitalPin('D6' == 0)
                a.writeDigitalPin('D6', 1);
            else
                a.writeDigitalPin('D6', 0);
            end
        end
    end


    methods
        
        function self = initilizeCamera(self)
            camList                     = webcamlist;
            camName                     = camList{1};
            self.cam                    = webcam(camName);
            preview(self.cam);
            closePreview(self.cam)
        end
        % FUNCTION
        % sets the center of our gameboard and the calibrates the location
        % of our motorhand. This means:
        %   1 :: homeLocation should just be '0'
        %   2 :: the origin uses the y-coordinate from the largest circle's
        %        centroid and the x-coordinate from the small rectangle
        %        (homeLocation)
        function self = calibrateOrigin(self)
            %% Determine centroid of Original Background
            img_binary                  = im2bw(self.img_background);
            SE                          = strel('disk', 10);
            img_eroded                  = imerode(img_binary, SE);
            SE                          = strel('disk', 7);
            img_dilated                 = imdilate(img_eroded, SE);
            self.boardSTATS             = regionprops(img_dilated,'all');
            self.num_items_board        = size(self.boardSTATS);
            
            % maxArea will find the x coordinate of the origin and the
            % minArea will find the y coordinate. homeLocation == 0 degrees
            maxArea                     = 0;
            minArea                     = 640 * 480;
            originIndex                 = 0;
            homeIndex                   = 0;

            for i = 1:self.num_items_board
                if(self.boardSTATS(i).Area > maxArea)
                    maxArea         = self.boardSTATS(i).Area;
                    originIndex     = i;
                end
                if(self.boardSTATS(i).Area < minArea)
                    minArea         = self.boardSTATS(i).Area;
                    homeIndex       = i;                                    % home for magnet hand
                end
            end
            self.origin         = [self.boardSTATS(originIndex).Centroid(1), self.boardSTATS(homeIndex).Centroid(2)];
            Xref                = self.origin(1) - self.boardSTATS(homeIndex).Centroid(1);
            Yref                = self.origin(2) - self.boardSTATS(homeIndex).Centroid(2);
            self.homeLocation   = 360 * atan(Yref / Xref) / (2*pi);         % should always be zero
        end
        
        % FUNCTION
        % initialize the gameboard. This sets the wellLocation of each
        % space on the gameboard to their respective angle from the origin
        function self = calibrateWellLocations(self)
            self.num_items_board            = size(self.boardSTATS);
            j                               = 1;
            tmp_letter                      = 'A';
            for i = 1:self.num_items_board
                Xref                = self.origin(1) - self.boardSTATS(i).Centroid(1);
                Yref                = self.origin(2) - self.boardSTATS(i).Centroid(2);
                tmp_WellLoc         = 360 * atan(Yref / Xref) / (2*pi);
                if(self.boardSTATS(i).Perimeter > self.PERIMETER_LOWER_BOUND && ...
                        self.boardSTATS(i).Perimeter < self.PERIMETER_UPPER_BOUND)
                        self.wellLocation(j)    = round(tmp_WellLoc * 10) / 10;
                        self.wellColor(j)       = self.EMPTY;

                        if(Yref < 0 && Xref > 0)
                            self.wellLocMotor(j) = -(180 + self.wellLocation(j));
                            self.wellLocation(j) = -(180 + self.wellLocation(j)) + 360;
                        end
                        if(Yref > 0 && Xref > 0)
                            self.wellLocMotor(j) = 180 - self.wellLocation(j);
                            self.wellLocation(j) = 180 - self.wellLocation(j);
                        end
                        if(Yref > 0 && Xref < 0)
                            self.wellLocMotor(j) = -self.wellLocation(j);
                            self.wellLocation(j) = -self.wellLocation(j);
                        end
                        if(Yref < 0 && Xref < 0)
                            self.wellLocMotor(j) = -180 + self.wellLocation(j);
                            self.wellLocation(j) = -self.wellLocation(j) + 360;
                        end


                        self.bb_xMin(j)         = ceil(self.boardSTATS(j).BoundingBox(1));
                        self.bb_xMax(j)         = self.bb_xMin(j) + self.boardSTATS(j).BoundingBox(3) - 1;
                        self.bb_yMin(j)         = ceil(self.boardSTATS(j).BoundingBox(2));
                        self.bb_yMax(j)         = self.bb_yMin(j) + self.boardSTATS(j).BoundingBox(4) - 1;

                        j                       = j + 1;
                        tmp_letter              = tmp_letter + 1;
                end
            end
            [self.wellLocation, self.sortedIndexing]    = sort(self.wellLocation);
            self.bb_xMin                                = self.bb_xMin(self.sortedIndexing);
            self.bb_xMax                                = self.bb_xMax(self.sortedIndexing);
            self.bb_yMin                                = self.bb_yMin(self.sortedIndexing);
            self.bb_yMax                                = self.bb_yMax(self.sortedIndexing);
            self.wellColor                              = self.wellColor(self.sortedIndexing);
            self.wellLetter                             = self.wellLetter(self.sortedIndexing);
        end
        
        % FUNCTION
        function self = updateGame(self)
            self.img_difference     = self.img_background - self.img_snapshot;
            img_normalized          = self.img_difference;
            dimensions              = size(img_normalized);
            height                  = dimensions(1);
            width                   = dimensions(2);
            

            for i = 1:height
                for j = 1:width
                    if (self.img_difference(i,j,1) > 2 || ...
                        self.img_difference(i,j,2) > 2 || ...
                        self.img_difference(i,j,3) > 2)
                        img_normalized(i,j,:) = [175, 200, 175];
                    end
                end
            end
            img_binary              = im2bw(img_normalized);
            SE                      = strel('disk', 15);
            img_eroded              = imerode(img_binary, SE);
            SE                      = strel('disk', 7);
            self.img_diffNoiseless  = imdilate(img_eroded, SE);
            self.gameSTATS          = regionprops(self.img_diffNoiseless, 'all');
            self.num_items_game     = size(self.gameSTATS);

            for i = 1:self.num_items_game
                if(self.gameSTATS(i).Area > 100)
                    P = impixel(self.img_snapshot,self.gameSTATS(i).Centroid(1), self.gameSTATS(i).Centroid(2));
                    if((P(1) > 180 && P(1) <= 255) && (P(2) > 180 && P(2) <= 255) && (P(3) < 90))
                        color           = 'Yellow';
                        color_number    = 0;
                    elseif((P(1) > 150) && (P(2) < 50) && (P(3) < 50))
                        color           = 'Red';
                        color_number    = 1;
                    elseif((P(1) < 150) && (P(2) > 10 && P(2) < 230) && (P(3) < 100))
                        color           = 'Green';
                        color_number    = 2;
                    elseif((P(1) < 100) && (P(2) < 200) && (P(3) > 100))
                        color           = 'Blue';
                        color_number    = 3;
                    else
                        color           = 'none';
                        color_number    = self.EMPTY;
                    end
                    %text(self.gameSTATS(i).Centroid(1), self.gameSTATS(i).Centroid(2), join('  ', color));

                    x_centroid = self.gameSTATS(i).Centroid(1);
                    y_centroid = self.gameSTATS(i).Centroid(2);

                    k = 1;

                    % find if centroid lies in a bounding box
                    for j = 1:self.num_items_board
                        x_min       = ceil(self.boardSTATS(j).BoundingBox(1));
                        x_max       = x_min + self.boardSTATS(j).BoundingBox(3) - 1;
                        y_min       = ceil(self.boardSTATS(j).BoundingBox(2));
                        y_max       = y_min + self.boardSTATS(j).BoundingBox(4) - 1;

                        if (self.boardSTATS(j).Perimeter > self.PERIMETER_LOWER_BOUND && self.boardSTATS(j).Perimeter < self.PERIMETER_UPPER_BOUND)
                            if (x_centroid > x_min && x_centroid < x_max && y_centroid > y_min && y_centroid < y_max)
                                self.wellColor(k)       = color_number;
                                self.washerLetter(i)    = char(self.wellLetter(k));
                            end  
                            k = k + 1;
                        end
                    end   
                end
            end 

            % find and calibate angles
            for i = 1:self.num_items_game
                if(self.gameSTATS(i).Area > 100)
                    offset_x                = self.origin(1) - self.gameSTATS(i).Centroid(1);
                    offset_y                = self.origin(2) - self.gameSTATS(i).Centroid(2);
                    self.washerLocation(i)  = 360 * atan(offset_y/offset_x) / (2*pi);

                    if(offset_y < 0 && offset_x > 0)
                        self.washerLocation(i) = -(180 + self.washerLocation(i)) + 360;
                    end
                    if(offset_y > 0 && offset_x > 0)
                        self.washerLocation(i) = 180 - self.washerLocation(i);
                    end
                    if(offset_y > 0 && offset_x < 0)
                        self.washerLocation(i) = -self.washerLocation(i);
                    end
                    if(offset_y < 0 && offset_x < 0)
                        self.washerLocation(i) = -self.washerLocation(i) + 360;
                    end      
                end
            end
            self.wellColor = self.wellColor(self.sortedIndexing);
        end
    
    
        % FUNCTION
        % this function returns the index of the nearest empty game space
        % relative to the homeLocation
        %        nearestVacancyIndex = findNearestVacancy(gameState, 3)
        %           >> nearestVacancyIndex = 1
        function nearestVacantIndex = findNearestVacancy(self)
            % check for the closest position to home first
            nearestVacantIndex = -1;
            k = self.SIZE/2;
            for i = self.SIZE/2 + 1 : self.SIZE
                
                if (self.wellColor(i) == self.EMPTY)
                    nearestVacantIndex = i;
                end
                if (k > 0 && self.wellColor(k) == self.EMPTY)
                    nearestVacantIndex = k;
                end
                k = k - 1;
            end

        end
        
        function self = movePartHelper(self, partIndex, destinationIndex)
            if (partIndex == destinationIndex)
                return
            end
            if (self.wellColor(destinationIndex) ~= self.EMPTY)
                nearestVacancyIndex = findNearestVacancy(self);
                self.movePartHelper(destinationIndex, nearestVacancyIndex);
            end
            % send command to motor
            partIndex_motor         = self.sortedIndexing(partIndex);
            destinationIndex_motor  = self.sortedIndexing(destinationIndex);
            
            mdl     = 'motorS22';
            in      = Simulink.SimulationInput(mdl);
            set_param('motorS22/desiredPosition','Value',num2str(self.wellLocMotor(partIndex_motor)));
            pause(.5);
            set_param('motorS22/Magnet','Value',num2str('1'));
            pause(1.5);
            set_param('motorS22/desiredPosition','Value',num2str(self.wellLocMotor(destinationIndex_motor)));
            pause(.5);
            set_param('motorS22/Magnet','Value',num2str('0'));
            pause(1.5);
        end
        function self = movePart(self, partIndex, destinationIndex)
                self.movePartHelper(partIndex, destinationIndex);
                self.returnHome();
        end

        function self = returnHome(self)
            mdl     = 'motorS22';
            in      = Simulink.SimulationInput(mdl);

            set_param('motorS22/desiredPosition','Value',num2str(self.homeLocation));
            pause(1);
        end



    end
end






