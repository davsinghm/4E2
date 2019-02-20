close all;
clear;

input_file = "test.mp4";

% block size
block_size_w = 4;
block_size_h = 4;

% "make" sure
if system("cd FFmpeg && make") ~= 0
    error("make error");
end

avg_frames_mc_mad = NaN(1, 51);
avg_frames_non_mc_mad = NaN(1, 51);
for crf = 1 : 51

% encode orignal file to input_file with specific settings (gop size etc)
if 1
    orig_input_file = "test_orig.mp4";
    sub_me = 1; % subme: 7: rd (default), 0: full pel only, 1: qpel sad 1 iter, 2: qpel sad 1 iter
    bframes_no = 0;
    ref_frames = 0;
    key_int = 2; % max interval b/w IDR-frames (aka keyframes)
    x264_execute(orig_input_file, input_file, crf, bframes_no, ref_frames, key_int);
end

if 1
    mvs_filename = "mvs.txt";
    ffmpeg_export_mvs(input_file, mvs_filename);
    [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(mvs_filename, block_size_w, block_size_h);
end

no_of_frames = size(frames_type, 2);
% frame data, mad
frames_mc_mad = NaN(1, no_of_frames);
frames_non_mc_mad = NaN(1, no_of_frames);

% open the video
video_reader = VideoReader(input_file);

frame_no = 1;
while hasFrame(video_reader)
    frame = readFrame(video_reader);

    frame_mvs_x = mvs_x(:, :, frame_no);
    frame_mvs_y = mvs_y(:, :, frame_no);

    if 0
        visualize_mvs(frame, 1, frame_mvs_x, frame_mvs_y, block_size_w, block_size_h);
    end

    % ignore other frames for now
    if frame_no > 1 && frames_type(frame_no) == 'p'

        % fill u and v with same mv from block
        [height, width, chans] = size(frame);
        [u, v] = fill_dense_mvs_from_blocks([height, width], frame_mvs_x, frame_mvs_y, block_size_w, block_size_h);
        mc_previous = generate_mc_frame(frame_previous, u, v);

        mc_mad = mean2(abs(double(frame) - double(mc_previous)));
        non_mc_mad = mean2(abs(double(frame) - double(frame_previous)));

        frames_mc_mad(frame_no) = mc_mad;
        frames_non_mc_mad(frame_no) = non_mc_mad;

        % figure(2);
        % image(frame_previous);
        % title('The previous frame');
        %
        % figure(3);
        % image(uint8(mc_previous));
        % title('The motion compensated previous frame');
        %
        % figure(4);
        % image(uint8(128 + double(frame_previous) - double(frame)));
        % title('The (non-mc) frame difference');
        %
        % figure(5);
        % image(uint8(128 + double(frame_previous) - double(mc_previous)));
        % title('The MC frame difference');
    end

    frame_previous = frame;
    frame_no = frame_no + 1;
end

% show mad graphs
figure(1);
i_y = ~isnan(frames_mc_mad) & ~isnan(frames_non_mc_mad);
frames_x = 1 : size(i_y(i_y), 2);
plot(frames_x, frames_mc_mad(i_y));
hold on;
plot(frames_x, frames_non_mc_mad(i_y));
hold off;

avg_frames_mc_mad(crf) = mean(frames_mc_mad(i_y));
avg_frames_non_mc_mad(crf) = mean(frames_non_mc_mad(i_y));

end

figure(2);
avg_frames_x = 1 : size(avg_frames_mc_mad, 2);
plot(avg_frames_x, avg_frames_mc_mad);
hold on;
plot(avg_frames_x, avg_frames_non_mc_mad);
hold off;
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

% interpolate mc frame. replaces zeros where mvs - u, v are NaN
function mc_frame = generate_mc_frame(frame, u, v)
    x = ones(size(frame, 1), 1) * (1 : size(frame, 2));
    y = (1 : size(frame, 1))' * ones(1, size(frame, 2));

    % relace NaN values with zero in mc frame
    u(isnan(u)) = 0;
    v(isnan(v)) = 0;

    offset_x = x + u;
    offset_y = y + v;
    mc_frame = double(frame);
    for chan = 1 : 3
        mc_frame(:, :, chan) = interp2(x, y, double(frame(:, :, chan)), offset_x, offset_y);
    end

    % FIXME even when u and v have valid nums, it still gives NaN. figure out what makes them NaN
    % update: quick looks, seems like there are on edges when mvs are outside the frame
    mc_frame(isnan(mc_frame)) = 0;
end
