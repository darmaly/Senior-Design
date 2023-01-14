%% ECE 4950 Project 2
close all
clc
clear
clear('cam')


%% Get Webcam Setup
%% Check cam list
cam_list = webcamlist

% Assign webcam
cam_name = cam_list{1}

% Check webcam propeties
cam = webcam(cam_name)

preview(cam);

%%
closePreview(cam);

%% Snapshot background image

background = snapshot(cam);

figure();
imshow(background)
title('Background');

%% Snapshot image with colors
img = snapshot(cam);

figure();
imshow(img)
title('Image With Foreground');


%% Extract photos
gameState.originalImage  = img;
gameState.currentImage   = img;

%% Subtract background
img_sub = background - img;
gameState.differenceImage  = img_sub;
gameState.currentImage     = img_sub;

figure();
imshow(img_sub)
title('Subtracted Background');

%% Normalize image for background subtraction and make it binary
img_norm = img_sub;
dimensions = size(img_norm);
height = dimensions(1);
width = dimensions(2);

for i=1:height
    for j=1:width
        if (img_sub(i,j,1) > 2 || ...
            img_sub(i,j,2) > 2 || ...
            img_sub(i,j,3) > 2)

            img_norm(i,j,:) = [175, 200, 175];
        end
    end
end

%img_gray = rgb2gray(img_norm);
img_bin = im2bw(img_norm);

%figure();
%imshow(img_bin)
%title('Binary Image');

% Erode image
SE = strel('disk', 15);
img_erode = imerode(img_bin, SE);

%figure();
%imshow(img_erode)
%title('Eroded Image');

% Dilate image
SE = strel('disk', 7);
img_dilate = imdilate(img_erode, SE);
gameState.diffNoiselessImage    = img_dilate;
gameState.currentImage          = img_dilate;

%figure();
%imshow(img_dilate)
%title('Dilated Image');

% Get image info
STATS = regionprops(img_dilate,'all');

%% Print overlay
figure();
imshow(img)
hold on;

items = size(STATS);
for i = 1:items
    if(STATS(i).Area ~= 0)
        plot(STATS(i).Centroid(1), STATS(i).Centroid(2), 'kO', 'MarkerFaceColor','k');
    end
end

title('Original Image With Centroid Dots');

%% Color detection

for i = 1:items
    if(STATS(i).Area ~= 0)
        P = impixel(img,STATS(i).Centroid(1), STATS(i).Centroid(2));
        if((P(1) > 100 && P(1) <= 255) && (P(2) > 150 && P(2) <= 255) && (P(3) < 200))
            text(STATS(i).Centroid(1), STATS(i).Centroid(2),'Yellow','VerticalAlignment','top');
            gameState.wellColor(i) = 0;
        end
        if((P(1) > 100) && (P(2) < 100) && (P(3) < 120))
            text(STATS(i).Centroid(1), STATS(i).Centroid(2),'Red','VerticalAlignment','top');
            gameState.wellColor(i) = 1;
        end
        if((P(1) < 100) && (P(2) > 10 && P(2) < 230) && (P(3) < 150))
            text(STATS(i).Centroid(1), STATS(i).Centroid(2),'Green','VerticalAlignment','top');
            gameState.wellColor(i) = 2;
        end
        if((P(1) < 100) && (P(2) < 200) && (P(3) > 100))
            text(STATS(i).Centroid(1), STATS(i).Centroid(2),'Blue','VerticalAlignment','top');
            gameState.wellColor(i) = 3;
        end
    end
end


%% Determine centroid of Original Background

img_bin2 = im2bw(background);

SE2 = strel('disk', 10);
img_erode2 = imerode(img_bin2, SE2);

SE2 = strel('disk', 7);
img_dilate2 = imdilate(img_erode2, SE2);


STATS2 = regionprops(img_dilate2,'all');
items2 = size(STATS2);

max_area = 0;
index_loc = 0;

for i = 1:items2
    if(STATS2(i).Area > max_area)
        max_area = STATS2(i).Area;
        index_loc = i;
    end
end


center = [STATS2(index_loc).Centroid(1), STATS2(index_loc).Centroid(2)];

%% Determine Angle of Centroids

for i = 1:items
    if(STATS(i).Area ~= 0)
        offset_x = center(1) - STATS(i).Centroid(1);
        offset_y = center(2) - STATS(i).Centroid(2);
        gameState.wellLoc(i) = 360 * atan(offset_y/offset_x) / (2*pi);
        if(offset_y < 0 && offset_x > 0)
            gameState.wellLoc(i) = -(180 + gameState.wellLoc(i));
        end
        if(offset_y > 0 && offset_x > 0)
            gameState.wellLoc(i) = 180 - gameState.wellLoc(i);
        end
        if(offset_y > 0 && offset_x < 0)
            gameState.wellLoc(i) = -gameState.wellLoc(i);
        end
        if(offset_y < 0 && offset_x < 0)
            gameState.wellLoc(i) = -gameState.wellLoc(i);
        end
        caption = sprintf('Angle = %f',gameState.wellLoc(i));
        text(STATS(i).Centroid(1), STATS(i).Centroid(2),caption);        
    end
end

hold off;

%% Get user input for what color they would like to go to
matlab.apputil.getInstalledAppInfo;

appHand = ECE4950_GUI;
