%% ECE 4950 Project 2
close all
clc
clear
clear('cam')


%% Get Webcam Setup
% Check cam list
cam_list = webcamlist

% Assign webcam
cam_name = cam_list{1}

%Check webcam propeties
cam = webcam(cam_name)

%preview(cam);

%%
%closePreview(cam);

%% Snapshot background image

background = snapshot(cam);

figure();
imshow(background);
title('Background');
imsave();

%% Snapshot image with colors



%% Get user input for what color they would like to go to
matlab.apputil.run('ECE4950_GUIAPP');