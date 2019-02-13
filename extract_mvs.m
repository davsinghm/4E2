% exported mv format from ffmpeg
% 
% frame_count: starting from 0.
%              a counter in display order fed to avfilter
% frame_type:  p, b (i or u: when unknown)
% mv_dst:      "Absolute destination position. Can be outside the frame area."
% mv_src:      "Absolute source position. Can be outside the frame area.fp"
% mv_type:     f (forward predicted), b (backward predicted) (, u: when unknown)
mv_format = "frame_count: %d, frame_type: %c, mv_dst: (%d, %d), mv_src: (%d, %d), mv_type: %c\n";

input_file = "test.mp4";
mvs_filename = "mvs.txt";
ret_code = system(strcat("cd FFmpeg ", ...
                "&& make ", ...
                "&& ./ffmpeg -y -flags2 +export_mvs -i ", "../", input_file, " ", ...
                "-vf codecview=mv_type=fp+bp -c:v libx264 -preset ultrafast -crf 0 ", ...
                "../test_out.mp4 > ../", mvs_filename));
if ret_code == 0
	mvs_file = fopen(mvs_filename, 'r');
    %mvs_raw = fscanf(mvs_file, mv_format, [7, Inf]);
    fclose(mvs_file);
end

% convert mvs_raw to more readable form
mvs_x = ones(1, 1, max(mvs_raw(1, 2))); % max value of frame + 1
mvs_y = zeros(1, 1, max(mvs_raw(1, 2)));
for j = 1:size(mvs_raw, 2)
	frame = mvs_raw(1, j) + 1; % frame start at 0
    frame_type = mvs_raw(2, j); % (char/byte) p, b or u
    % ignore other frames for now
    if frame_type == 'p'
        mv_dst = [mvs_raw(3, j) + 1, mvs_raw(4, j) + 1]; % abs dst pos (x, y)
        mv_src = [mvs_raw(5, j) + 1, mvs_raw(6, j) + 1]; % abs src pos (x, y)
        mvs_x(mv_dst(2), mv_dst(1), frame) = mv_src(1) - mv_dst(1);
        mvs_y(mv_dst(2), mv_dst(1), frame) = mv_src(2) - mv_dst(2);
    end
end
% TODO convert mvs_raw to more readable form
%      > mv val + position
%      > per frame matrix
%      > constants for vals at skip block instead of zeroes in mvs_x,y
%      > convert src to mb for mem management ?

% open the video for visualization
frame = 76;
video_reader = VideoReader(input_file);
input_video_frame = read(video_reader, frame);
figure(1);
[rows, cols, chans] = size(input_video_frame);
X = ones(rows, 1) * (1 : cols);
Y = (1 : rows)' * ones(1, cols);
image((1:cols), (1:rows), input_video_frame);
title(['Frame ', num2str(frame)]);

% show vectors using quiver
Xpos = X(1 : 1 : end, 1 : 1 : end);
Ypos = Y(1 : 1 : end, 1 : 1 : end);
vx = ones(size(X)) * NaN;
vy = vx;
width = min(size(X, 2), size(mvs_x, 2));
height = min(size(X, 1), size(mvs_x, 1));
for x = 1 : width
    for y = 1 : height
        vx(y, x) = mvs_x(y, x, frame);
        vy(y, x) = mvs_y(y, x, frame);
    end
end

%vx(1 : 1 : end, 1 : 1 : end) = -15 * ones(size(Xpos));
%vy(1 : 1 : end, 1 : 1 : end) = 25 * ones(size(Xpos));
hold on
quiver(X, Y, vx, vy, 0, 'r-', 'linewidth', 2); shg
hold off;

% Just to show how quiver works
% Xpos = X(8 : 16 : end, 8 : 16 : end);
% Ypos = Y(8 : 16 : end, 8 : 16 : end);
% vx = ones(size(X)) * NaN;
% vy = vx;
% vx(8 : 16 : end, 8 : 16 : end) = -15 * ones(size(Xpos));
% vy(8 : 16 : end, 8 : 16 : end) = 25 * ones(size(Xpos));
% hold on
% quiver(X, Y, vx, vy, 0, 'r-', 'linewidth', 2); shg
% hold off;

% previous_video_frame = read(video_reader, frame - 1);
% figure(2);
% image(previous_video_frame);
% title('The previous frame');
% 
% offset_X = X + vx;
% offset_Y = Y + vy;
% mc_previous = double(previous_video_frame);
% for col = 1 : 3,
%   mc_previous(:, :, col) = interp2(X, Y, double(previous_video_frame(:, :, col)), offset_X, offset_Y);
% end;
% 
% figure(3);
% image(mc_previous);
% title('The motion compensated previous frame');
% 
% figure(4);
% image(uint8(128 + double(previous_video_frame) - double(input_video_frame)));
% title('The NON motion compensated frame difference');


% [X,Y]
% index = 1;
% for row = 1:min(size(input_video, 1) , size(mvs_y(:,:,frame), 1))
%     for col = 1:min(size(input_video, 2), size(mvs_x(:,:,frame), 2))
%         %if mvs_x(row,col,frame) ~= 0 || mvs_x(row,col,frame) ~= 0
%             X(index) = col;
%             Y(index) = row;
%             DX = mvs_x(row, col, frame);
%             DY = mvs_y(row, col, frame);
%             index = index + 1;
%         %end
%     end
% end

%DX = mvs_x(:, , frame);
%DY = mvs_y(:, :, frame);
%contour(X,Y,Z)

% hold on;
% quiver(X,Y,DX,DY,0)
%hold off;