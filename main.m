addpath 'utils';

close all;
clear;

% block size
block_size_w = 4;
block_size_h = 4;
mb_size = [block_size_h, block_size_w];

% "make" sure
if system("cd FFmpeg && make") ~= 0
    error("make error");
end

avg_frames_mc_mad = NaN(1, 51);
avg_frames_non_mc_mad = NaN(1, 51);
for crf = 17 : 17

orig_input_file = "test_orig.mp4";
temp_mvs_vid_file = "tmp/mvs.mp4"; % temporary file from which the mvs are extracted. the file is encoded from original source by x264, saving mvs to it.

% encode orignal file to intermediary file with specific settings (gop size etc)
if 1
    sub_me = 1; % subme: 7: rd (default), 0: full pel only, 1: qpel sad 1 iter, 2: qpel sad 1 iter
    bframes_no = 0;
    ref_frames = 0;
    key_int = 2; % max interval b/w IDR-frames (aka keyframes)
    x264_execute(orig_input_file, temp_mvs_vid_file, crf, bframes_no, ref_frames, key_int);
end

if 1
    temp_mvs_file = "tmp/mvs.txt";
    ffmpeg_export_mvs(temp_mvs_vid_file, temp_mvs_file);
    [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(temp_mvs_file, block_size_w, block_size_h);

    if 1 % disable subpel
        mvs_x = round(mvs_x);
        mvs_y = round(mvs_y);
    end
end

no_of_frames = size(frames_type, 2);
% frame data, mad
frames_mc_mad = NaN(1, no_of_frames);
frames_non_mc_mad = NaN(1, no_of_frames);
frames_smoothness_cost = NaN(1, no_of_frames);

% open the video
video_reader = VideoReader(orig_input_file);

tic;
frame_no = 1;
while hasFrame(video_reader)
    frame = rgb2gray(readFrame(video_reader));

    frame_mvs_x = mvs_x(:, :, frame_no);
    frame_mvs_y = mvs_y(:, :, frame_no);

    % ignore other frames for now
    if frame_no > 1 && frames_type(frame_no) == 'p'

        % fill u and v with same mv from block
        [height, width, chans] = size(frame);
        % fast motion: refine motion vectors
        [frame_mvs_x, frame_mvs_y] = fast_motion(frame, frame_prev, frame_mvs_x, frame_mvs_y, mb_size, frame_no);
        frame_flo = fill_dense_mvs_from_blocks([height, width], frame_mvs_x, frame_mvs_y, block_size_w, block_size_h);
        if 1
            visualize_mvs(frame, 1, frame_flo, 16, 16); % visualize every 16th mv
        end
        mc_previous = generate_mc_frame(frame_prev, frame_flo);

        mc_mad = mean2(abs(double(frame) - double(mc_previous)));
        non_mc_mad = mean2(abs(double(frame) - double(frame_prev)));
        smoothness_cost = smoothness_cost_frame(frame_mvs_x, frame_mvs_y);

        frames_mc_mad(frame_no) = mc_mad;
        frames_non_mc_mad(frame_no) = non_mc_mad;
        frames_smoothness_cost(frame_no) = smoothness_cost;
        fprintf("frame_no: %03d, mc_diff: %.16f, smoothness: %d\n", frame_no, mc_mad, smoothness_cost);

        % figure(2);
        % image(frame_prev);
        % title('The previous frame');
        %
        % figure(3);
        % image(uint8(mc_previous));
        % title('The motion compensated previous frame');
        %
        % figure(4);
        % image(uint8(128 + double(frame_prev) - double(frame)));
        % title('The (non-mc) frame difference');
        %
        % figure(5);
        % image(uint8(128 + double(frame_prev) - double(mc_previous)));
        % title('The MC frame difference');
    end

    frame_prev = frame;
    frame_no = frame_no + 1;
end
toc;

% show mad graphs
figure(1);
hold on;
i_y = ~isnan(frames_mc_mad) & ~isnan(frames_non_mc_mad);
frames_x = 1 : size(i_y(i_y), 2);
plot(frames_x, frames_mc_mad(i_y));
plot(frames_x, frames_non_mc_mad(i_y));
plot(frames_x, frames_smoothness_cost(i_y));
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

% export mvs from video and save to mvs_file
function ffmpeg_export_mvs(video_file, temp_mvs_file)
    codecview_file = strsplit(video_file, '.');
    codecview_file = codecview_file(1);
    ret = system(sprintf("./FFmpeg/ffmpeg -y -flags2 +export_mvs -i %1$s -vf codecview=mv_type=fp+bp -c:v libx264 -preset ultrafast -crf 0 %2$s_codecview.mp4 > %3$s", video_file, codecview_file, temp_mvs_file));
    if ret ~= 0
        error("ffmpeg exit code is: %d", ret);
    end
end

% fill @u and @v matrices which are equal to @frame_size from @mvs_x, @mvs_y which are block level
function flo = fill_dense_mvs_from_blocks(frame_size, mvs_x, mvs_y, block_size_w, block_size_h)
    flo = NaN(frame_size(1), frame_size(2), 2);
    for i = 1 : size(mvs_y, 1)
        for j = 1 : size(mvs_x, 2)
            for mb_i = 1 : block_size_h
                for mb_j = 1 : block_size_w
                    % conditions, to make sure the matrix doesn't grow more
                    % than x, y
                    if mb_i + (i - 1) * block_size_h <= frame_size(1) ...
                            && mb_j + (j - 1) * block_size_w <= frame_size(2)
                        flo(mb_i + (i - 1) * block_size_h, ...
                            mb_j + (j - 1) * block_size_w, ...
                            1 ) = mvs_x(i, j);
                        flo(mb_i + (i - 1) * block_size_h, ...
                            mb_j + (j - 1) * block_size_w, ...
                            2 ) = mvs_y(i, j);
                    end
                end
            end
        end
    end
end

% show vectors using quiver
function visualize_mvs(frame, figure_no, mvs, step_w, step_h)
    figure(figure_no);
    [height, width, ~] = size(frame);
    imshow(frame); axis on;
    title(['Frame ', num2str(figure_no)]);

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);
    X = x(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    Y = y(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    U = mvs(Y(: , 1), X(1, :), 1);
    V = mvs(Y(: , 1), X(1, :), 2);

    hold on;
    quiver(X, Y, U, V, 0, 'g-', 'linewidth', 1); shg;
    hold off;
end

% interpolate mc frame. replaces zeros where mvs are NaN
function mc_frame = generate_mc_frame(frame, flo)
    x = ones(size(frame, 1), 1) * (1 : size(frame, 2));
    y = (1 : size(frame, 1))' * ones(1, size(frame, 2));

    % relace NaN values with zero in mc frame
    flo(isnan(flo)) = 0;

    offset_x = x + flo(:, :, 1);
    offset_y = y + flo(:, :, 2);
    mc_frame = double(frame);
    for chan = 1 : size(frame, 3)
        mc_frame(:, :, chan) = interp2(x, y, double(frame(:, :, chan)), offset_x, offset_y);
    end

    % FIXME even when u and v have valid nums, it still gives NaN. figure out what makes them NaN
    % update: quick looks, seems like there are on edges when mvs are outside the frame
    mc_frame(isnan(mc_frame)) = 0;
end
