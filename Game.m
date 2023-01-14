classdef Game < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        EMPTY                   = -999;
        MAGNET                  = 'D7';
        SIZE                    = 8;
        AREA_LOWER_BOUND        = 1800;
        AREA_UPPER_BOUND        = 2600;
        DIFFERENCE_CUTOFF       = 20;
        WASHER_AREA_CUTOFF      = 5000;
        MOTOR_MODEL             = 'motorS22';
            

        bb_xMin                                                             % these are the bounding boxes at the current location
        bb_yMin
        bb_xMax
        bb_yMax 

        wellLocation            = [];
        centroid_x              = [];
        centroid_y              = [];
        wellColor               = [];
        homeLocation
        origin
        currentLocation
        currentAngle
        sortedIndexing
        num_items_game
        img_background                                                      % stored background image
        img_snapshot                                                        % current state of the board... a snapshot of it                                                  
        boardSTATS                                                          % STATS struct of the background image
        gameSTATS                                                           % STATS struct of the actual game
        cam                                                                 % camera
    end

    methods (Static)
        function gs = createGame(background_PATH, filledBoard_PATH)
            gs                      = Game;                                 % create an instance of the class Game
            % handles camera vs file input
            if (exist('background_PATH', 'var'))
                gs.img_background   = imread(background_PATH);              % background img
                gs.img_snapshot     = imread(filledBoard_PATH);             % current game state
            else
                gs.initializeCamera();
                gs.img_background   = snapshot(gs.cam);                     % background img
                gs.img_snapshot     = gs.img_background;                    % current game state
            end
            gs.calibrateOrigin();
            gs.calibrateWellLocations();
        end
        

        function ToggleMagnet()
            if a.readDigitalPin(self.MAGNET == 0)
                a.writeDigitalPin(self.MAGNET, 1);
            else
                a.writeDigitalPin(self.MAGNET, 0);
            end
        end
    end

    methods
        function self = initializeCamera(self, test)
            camList                     = webcamlist;
            camName                     = camList{1};
            self.cam                    = webcam(camName);
            preview(self.cam);
            
            if (exist('test', 'var'))
                pause(test);
            end
            closePreview(self.cam)
        end

        function self = calibrateOrigin(self)
            %% Determine centroid of Original Background
            img_binary                  = im2bw(self.img_background);
            SE                          = strel('disk', 8);
            img_eroded                  = imerode(img_binary, SE);
            SE                          = strel('disk', 5);
            img_dilated                 = imdilate(img_eroded, SE);
            figure();
            imshow(img_eroded)
            self.boardSTATS             = regionprops(img_dilated,'all');
            maxArea                     = 0;
            minArea                     = 640 * 480;
            originIndex                 = 1;
            %homeIndex                   = 1;

            % finding home for magnet hand
            for i = 1 : size(self.boardSTATS)
                if(self.boardSTATS(i).Area > maxArea)
                    maxArea         = self.boardSTATS(i).Area;
                    originIndex     = i;
                    homeIndex       = i;
                
                end
                if(self.boardSTATS(i).Area < 650 && self.boardSTATS(i).Area > 580)
                    homeIndex       = i;
                end
            end
            self.origin         = [self.boardSTATS(originIndex).Centroid(1), self.boardSTATS(homeIndex).Centroid(2)];
            Xref                = self.origin(1) - self.boardSTATS(homeIndex).Centroid(1);
            Yref                = self.origin(2) - self.boardSTATS(homeIndex).Centroid(2);
            self.homeLocation   = 360 * atan(Yref / Xref) / (2*pi);         % should always be zero
        end
    
        function self = updateState(self)
            self.img_snapshot       = snapshot(self.cam);
            img_difference          = self.img_background - self.img_snapshot;
            img_normalized          = img_difference;
            dimensions              = size(img_normalized);
            height                  = dimensions(1);
            width                   = dimensions(2);
            

            for i = 1:height
                for j = 1:width
                    if (img_difference(i,j,1) > self.DIFFERENCE_CUTOFF || ...
                        img_difference(i,j,2) > self.DIFFERENCE_CUTOFF || ...
                        img_difference(i,j,3) > self.DIFFERENCE_CUTOFF)
                        img_normalized(i,j,:) = [175, 200, 175];
                    end
                end
            end
            img_binary                  = im2bw(img_normalized);
            SE                          = strel('disk', 5);
            img_eroded                  = imerode(img_binary, SE);
            SE                          = strel('disk', 4);
            img_diffNoiseless           = imdilate(img_eroded, SE);
            self.gameSTATS              = regionprops(img_diffNoiseless, 'all');
            self.num_items_game         = size(self.gameSTATS);
            figure();
            imshow(img_diffNoiseless)
            P = 0;

            for i = 1:self.SIZE
                P(1) = 0;
                P(2) = 0;
                P(3) = 0;
                for j = 10 : 20
                    P =  P + impixel(self.img_snapshot,self.centroid_x(i) + j, self.centroid_y(i));
                    P =  P + impixel(self.img_snapshot,self.centroid_x(i) - j, self.centroid_y(i));
                    P =  P + impixel(self.img_snapshot,self.centroid_x(i), self.centroid_y(i) + j);
                    P =  P + impixel(self.img_snapshot,self.centroid_x(i), self.centroid_y(i) - j);
                end

                P = P / 40; 
                if((P(1) > 180 && P(1) <= 255) && (P(2) > 180 && P(2) <= 255) && (P(3) < 50))
                    color           = 'Yellow';
                    color_number    = 0;
                elseif(((P(1) > 80) && (P(2) < .8*P(1)) && (P(3) < .8*P(1))))
                    color           = 'Red';
                    color_number    = 1;
                elseif((P(1) < .8*P(2)) && (P(2) > 70) && (P(3) < .95*P(2)))
                    color           = 'Green';
                    color_number    = 2;
                elseif(((P(1) < .95*P(3)) && (P(2) < .90*P(3)) && (P(3) > 100)))
                    color           = 'Blue';
                    color_number    = 3;
                else
                    color           = 'none';
                    color_number    = self.EMPTY;
                end
                self.wellColor(i)       = color_number;
            end
        end 
        
        function self = calibrateWellLocations(self)
            j                               = 1;
            for i = 1:size(self.boardSTATS)
                Xref                = self.origin(1) - self.boardSTATS(i).Centroid(1);
                Yref                = self.origin(2) - self.boardSTATS(i).Centroid(2);
                tmp_WellLoc         = 360 * atan(Yref / Xref) / (2*pi);
                if(self.boardSTATS(i).Area > self.AREA_LOWER_BOUND && ...
                        self.boardSTATS(i).Area < self.AREA_UPPER_BOUND)
                        self.wellLocation(j)    = round(tmp_WellLoc * 10) / 10;
                        self.wellColor(j)       = self.EMPTY;

                        if(Yref < 0 && Xref > 0)
                            self.wellLocation(j) = -(180 + self.wellLocation(j)) + 360;
                        end
                        if(Yref > 0 && Xref > 0)
                            self.wellLocation(j) = 180 - self.wellLocation(j);
                        end
                        if(Yref > 0 && Xref < 0)
                            self.wellLocation(j) = -self.wellLocation(j);
                        end
                        if(Yref < 0 && Xref < 0)
                            self.wellLocation(j) = -self.wellLocation(j) + 360;
                        end
                        self.centroid_x(j)       = self.boardSTATS(i).Centroid(1);
                        self.centroid_y(j)       = self.boardSTATS(i).Centroid(2);
                        j                        = j + 1;
                end
            end
            [self.wellLocation, self.sortedIndexing]    = sort(self.wellLocation);
            self.wellColor                              = self.wellColor(self.sortedIndexing);
            self.centroid_x                             = self.centroid_x(self.sortedIndexing);
            self.centroid_y                             = self.centroid_y(self.sortedIndexing);
            self.currentLocation                        = 0;
            self.currentAngle                           = 0;
        end
    
        function vacantIndex = findVacancy(self)

            vacantIndex         = -1;
            k                   = self.SIZE;

            for i = 1 : self.SIZE
                if (self.wellColor(i) == self.EMPTY)
                    vacantIndex = i;
                    return
                end
                if (self.wellColor(k) == self.EMPTY)
                    vacantIndex = k;
                    return
                end
            end
        end
        
        function self = movePartHelper(self, partIndex, destIndex)
            if (partIndex == destIndex || self.wellColor(partIndex) == self.EMPTY)
                return
            end

            if (self.wellColor(destIndex) ~= self.EMPTY)
                vacantIndex = findVacancy(self);
                self.movePartHelper(destIndex, vacantIndex);
            end
            % send command to motor
            Simulink.SimulationInput(self.MOTOR_MODEL);
            PartLocation            = num2str(self.wellLocation(partIndex));
            DestLocation            = num2str(self.wellLocation(destIndex));
            set_param('motorS22/desiredPosition','Value', PartLocation);
            pause(.5);
            set_param('motorS22/Magnet','Value',num2str('1'));
            pause(1.5);
            set_param('motorS22/desiredPosition','Value',DestLocation);
            self.currentLocation = destIndex;
            pause(.5);
            set_param('motorS22/Magnet','Value',num2str('0'));
            pause(1.5);
        end
  
        function self = movePart(self, partIndex, destIndex)
            % update part locations here
            if (self.wellColor(partIndex) == self.EMPTY || partIndex == destIndex)
                return
            end
            self.movePartHelper(partIndex, destIndex);
            self.returnHome();
            if (self.wellColor(destIndex) ~= self.EMPTY)
              self.wellColor(self.findVacancy())  = self.wellColor(destIndex);
            end
            self.wellColor(destIndex)             = self.wellColor(partIndex);
            self.wellColor(partIndex)             = self.EMPTY;
            self.updateState();
            
        end

        function self = returnHome(self)
            Simulink.SimulationInput(self.MOTOR_MODEL);
            set_param('motorS22/desiredPosition', 'Value', num2str(self.homeLocation));
            self.currentLocation    = self.homeLocation;
            self.currentAngle       = 0;
            pause(1);
        end
    end
end