% exported mv format from ffmpeg
%
% read the mvs from file @mvs_filename in following format:
% "frame_count: %d, frame_type: %c, mv_dst: (%d, %d), mv_src: (%d, %d), mv_type: %c\n";
% where:
% frame_count: starting from 0.
%              a counter in display order fed to avfilter
% frame_type:  p, b (i or u: when unknown)
% mv_dst:      "Absolute destination position. Can be outside the frame area."
% mv_src:      "Absolute source position. Can be outside the frame area.fp"
% mv_type:     f (forward predicted), b (backward predicted) (, u: when unknown)
%
% @return [@mvs_x, @mvs_y]: one motion vector per block, NaN where no mvs was
% found. block size is defined by @block_size_w and @block_size_h
function [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(mvs_filename, block_size_w, block_size_h)

    % TODO convert mvs_raw to more readable form
    %      > mv val + position
    %      > per frame matrix
    %      > constants for vals at skip block instead of zeroes in mvs_x,y
    %      > convert src to mb for mem management ?

    mv_format = "frame_count: %d, frame_type: %c, mv_dst: (%d, %d), mv_src: (%d, %d), mv_type: %c\n";

    mvs_file = fopen(mvs_filename, 'r');
    mvs_raw = fscanf(mvs_file, mv_format, [7, Inf]);
    fclose(mvs_file);

    % convert mvs_raw to more readable form
    no_of_frames = max(mvs_raw(1, :)) + 2; % max value of frame_no + 2 (one for starting from zero, one for last frame?)
    mvs_type = zeros(1, 1, no_of_frames);
    frames_type = zeros(1, no_of_frames);
    mvs_x = NaN(1, 1, no_of_frames); % set initial values to NaN
    mvs_y = NaN(1, 1, no_of_frames);
    for j = 1 : size(mvs_raw, 2)
    	  frame_no = mvs_raw(1, j) + 1; % frame start at 0
        frames_type(frame_no) = mvs_raw(2, j); % (char/byte) p, b or u
        mv_dst = [mvs_raw(3, j), mvs_raw(4, j)]; % abs dst pos (x, y)
        mv_src = [mvs_raw(5, j), mvs_raw(6, j)]; % abs src pos (x, y)
        x = floor(mv_dst(1) / block_size_w) + 1;
        y = floor(mv_dst(2) / block_size_h) + 1;
        mvs_type(y, x, frame_no) = mvs_raw(7, j);

        mvs_x(y, x, frame_no) = mv_src(1) - mv_dst(1);
        mvs_y(y, x, frame_no) = mv_src(2) - mv_dst(2);
    end
end
