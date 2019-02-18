close all;
clear;

input_file = "test.mp4";

% block size
block_size_w = 16;
block_size_h = 16;

% "make" sure
system("cd FFmpeg && make");

% encode orignal file to input_file with specific settings (gop size etc)
if 1
    orig_input_file = "test_orig.mp4";
    sub_me = 1;
    bframes_no = 0;
    ref_frames = 0;
    key_int = 2; % max interval b/w IDR-frames (aka keyframes)
    x264_execute(orig_input_file, input_file, 22, ref_frames, sub_me, key_int);
end

if 1
    mvs_filename = "mvs.txt";
    ffmpeg_export_mvs(input_file, mvs_filename);
    [mvs_x, mvs_y] = extract_mvs(mvs_filename, block_size_w, block_size_h);
end

% open the video for visualization
frame_no = 78;
video_reader = VideoReader(input_file);
frame = read(video_reader, frame_no);
visualize_mvs(frame, 1, mvs_x(:, :, frame_no), mvs_y(:, :, frame_no), block_size_w, block_size_h);

previous_video_frame = read(video_reader, frame_no - 1);
% figure(2);
% image(previous_video_frame);
% title('The previous frame');

% fill u and v with same mv from block
[height, width, chans] = size(frame);
[u, v] = fill_dense_mvs_from_blocks([height, width], mvs_x(:, :, frame_no), mvs_y(:, :, frame_no), block_size_w, block_size_h);

x = ones(height, 1) * (1 : width);
y = (1 : height)' * ones(1, width);
offset_x = x + u;
offset_y = y + v;
mc_previous = double(previous_video_frame);
for chan = 1 : 3
    mc_previous(:, :, chan) = interp2(x, y, double(previous_video_frame(:, :, chan)), ...
                                     offset_x, offset_y);
end
% relace NaN values with zero in mc frame
mc_previous(isnan(mc_previous)) = 0;

figure(3);
image(uint8(mc_previous));
title('The motion compensated previous frame');

figure(4);
image(uint8(128 + double(previous_video_frame) - double(frame)));
title('The (non-mc) frame difference');

figure(5);
image(uint8(128 + double(previous_video_frame) - double(mc_previous)));
title('The MC frame difference');

non_mc_e = double(previous_video_frame) - double(frame);
mc_e = double(frame) - double(mc_previous);
mae_non_mc_e = mean(mean(abs(non_mc_e(:, :, 1))))
mae_mc_e = mean(mean(abs(mc_e(:, :, 1))))


% need to generate error based on original frames

% export mvs from @input_file and save to @mvs_filename
function ffmpeg_export_mvs(input_file, mvs_filename)
    ret = system(sprintf("./FFmpeg/ffmpeg -y -flags2 +export_mvs -i %1$s -vf codecview=mv_type=fp+bp -c:v libx264 -preset ultrafast -crf 0 codecview_%1$s > %2$s", input_file, mvs_filename));
    if ret ~= 0
        error("ffmpeg exit code is: %d", ret);
    end
end

% fill @u and @v matrices which are equal to @frame_size from @mvs_x, @mvs_y which are block level
function [u, v] = fill_dense_mvs_from_blocks(frame_size, mvs_x, mvs_y, block_size_w, block_size_h)
    u = NaN(frame_size);
    v = NaN(frame_size);
    for i = 1 : size(mvs_y, 1)
        for j = 1 : size(mvs_x, 2)
            for mb_i = 1 : block_size_h
                for mb_j = 1 : block_size_w
                    % conditions, to make sure the matrix doesn't grow more
                    % than x, y
                    if mb_i + (i - 1) * block_size_h <= frame_size(1) ...
                            && mb_j + (j - 1) * block_size_w <= frame_size(2)
                        u(mb_i + (i - 1) * block_size_h, ...
                          mb_j + (j - 1) * block_size_w ...
                         ) ...
                           = mvs_x(i, j);
                        v(mb_i + (i - 1) * block_size_h, ...
                          mb_j + (j - 1) * block_size_w ...
                         ) ...
                           = mvs_y(i, j);
                    end
                end
            end
        end
    end
end

% show vectors using quiver
function visualize_mvs(frame, figure_no, mvs_x, mvs_y, block_size_w, block_size_h)
    figure(figure_no);
    [height, width, ~] = size(frame);
    image((1 : width), (1 : height), frame);
    title(['Frame ', num2str(figure_no)]);

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);
    x_pos = x(floor(block_size_w / 2) : block_size_w : end, ...
              floor(block_size_h / 2) : block_size_h : end);
    y_pos = y(floor(block_size_w / 2) : block_size_w : end, ...
              floor(block_size_h / 2) : block_size_h : end);
    u = NaN(size(x_pos));
    v = NaN(size(y_pos));
    for i = 1 : min(size(u, 1), size(mvs_x, 1))
        for j = 1 : min(size(v, 2), size(mvs_y, 2))
            u(i, j) = mvs_x(i, j);
            v(i, j) = mvs_y(i, j);
        end
    end

    hold on;
    quiver(x_pos, y_pos, u, v, 0, 'r-', 'linewidth', 1); shg;
    hold off;
end
