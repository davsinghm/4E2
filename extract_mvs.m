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
    % mvs_raw = fscanf(mvs_file, mv_format, [7, Inf]);
    fclose(mvs_file);
end

% convert mvs_raw to more readable form
mvs_x = zeros(1, 1, max(mvs_raw(1, 2))); % max value of frame + 1
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
frame = 2;
video_reader = VideoReader(input_file);
input_video = read(video_reader, frame);
figure
imshow(input_video);

% [X,Y]
index = 1;
for row = 1:min(size(input_video, 1) , size(mvs_y(:,:,frame), 1))
    for col = 1:min(size(input_video, 2), size(mvs_x(:,:,frame), 2))
        if mvs_x(row,col,frame) ~= 0 || mvs_x(row,col,frame) ~= 0
            X(index) = col;
            Y(index) = row;
            DX = mvs_x(row, col, frame);
            DY = mvs_y(row, col, frame);
            index = index + 1;
        end
    end
end

%DX = mvs_x(:, , frame);
%DY = mvs_y(:, :, frame);
%contour(X,Y,Z)

hold on;
quiver(X,Y,DX,DY)
%hold off;