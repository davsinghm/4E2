% exported mv format from ffmpeg
%
% read the mvs from file @mvs_filename in following format:
% "frame_count: %d, frame_type: %c, mv_dst: (%d, %d), mv_src: (%d, %d), mv_type: %c, motion: (%d, %d, %d), mb: (%d, %d)\n";
% where:
% frame_count: starting from 0.
%              a counter in display order fed to avfilter
% frame_type:  p, b (i or u: when unknown)
% mv_dst:      "Absolute destination position. Can be outside the frame area."
% mv_src:      "Absolute source position. Can be outside the frame area.fp"
% mv_type:     f (forward predicted), b (backward predicted) (, u: when unknown)
% motion:      motion_x, motion_y and motion_scale
%              motion vector:
%                  mv_src_x = mv_dst_x + motion_x / motion_scale
%                  mv_src_y = mv_dst_y + motion_y / motion_scale
% mb:         macroblock width and height
%
% @param      enable_subpel: if disabled, the value will be rounded off
% @return [@mvs_x, @mvs_y]: one motion vector per block, NaN where no mvs was
% found. block size is defined by @block_size_w and @block_size_h
function [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(mvs_filename, block_size_w, block_size_h)

    mv_format = "frame_count: %d, frame_type: %c, mv_dst: (%d, %d), mv_src: (%d, %d), mv_type: %c, motion: (%d, %d, %d), mb: (%d, %d)\n";

    mvs_file = fopen(mvs_filename, 'r');
    mvs_raw = fscanf(mvs_file, mv_format, [12, Inf]);
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
        w = mvs_raw(11, j);
        h = mvs_raw(12, j);
        % if w or h > block_size_*, copy same mvs to each sub-block
        for mb_j = 0 : max(1, floor(w / block_size_w)) - 1
            for mb_i = 0 : max(1, floor(h / block_size_h)) - 1
                mb_x = floor(floor((mv_dst(1) - w / 2)) / block_size_w) + 1; % TODO this overlaps the block in the loop. clip the loop over a parent block position
                mb_y = floor(floor((mv_dst(2) - h / 2)) / block_size_h) + 1;
                x = mb_x + mb_j;
                y = mb_y + mb_i;
                mvs_type(y, x, frame_no) = mvs_raw(7, j);
                mvs_x(y, x, frame_no) = mvs_raw(8, j) / mvs_raw(10, j); % motion_x / motion_scale
                mvs_y(y, x, frame_no) = mvs_raw(9, j) / mvs_raw(10, j); % motion_y / motion_scale
            end
        end
    end
end
