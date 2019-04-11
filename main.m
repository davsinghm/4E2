addpath 'utils' 'utils/flow_code';

close all;
clear;

% block size
mb_size = [4, 4]; % h x w

% "make" sure
if system("cd FFmpeg && make") ~= 0
    error("make error");
end

seqs = get_sintel_sequences();
seqs_avg_mc_mad = NaN(1, 3); % average mc frame mad
seqs_avg_sm_cost = NaN(1, 3); % average smoothness cost

ft_i = 0;
for ft = {'groundtruth', 'ffmpeg', 'fastmotion', 'deepflow', 'pca-flow'} % 1 for gt, 2 for ffmpeg, 3 for fast-motion, 4 for deepflow, 5 for pca-flow
    ft_i = ft_i + 1;
for seq_i = 1 : size(seqs, 1)

    seq_name = seqs(seq_i, 1);
    frames_dir = seqs(seq_i, 2);
    flo_dir = seqs(seq_i, 3);
    occ_dir = seqs(seq_i, 4);
    no_of_frames = str2num(seqs(seq_i, 5));

    orig_input_file_fmt = sprintf('%s/frame_%%04d.png', frames_dir);
    flo_file_fmt = sprintf('%s/frame_%%04d.flo', flo_dir); % if loading external mvs
    occ_file_fmt = sprintf('%s/frame_%%04d.png', occ_dir);

    % generate and read ffmpeg mvs
    if 1 % always do this for now to check frame_type (or no_of_frames)
        temp_mvs_vid_file = "tmp/mvs.mp4"; % temporary file from which the mvs are extracted. the file is encoded from original source by x264, saving mvs to it.

        % encode orignal file to intermediary file with specific settings (gop size etc)
        sub_me = 1; % subme: 7: rd (default), 0: full pel only, 1: qpel sad 1 iter, 2: qpel sad 1 iter
        bframes_no = 0;
        ref_frames = 0;
        key_int = 2; % max interval b/w IDR-frames (aka keyframes)
        crf = 17;
        x264_execute(orig_input_file_fmt, temp_mvs_vid_file, crf, bframes_no, ref_frames, key_int);

        % read mvs from file
        temp_mvs_file = "tmp/mvs.txt";
        ffmpeg_export_mvs(temp_mvs_vid_file, temp_mvs_file);
        [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(temp_mvs_file, mb_size);
    end

    fprintf('\nsequence: %s, ft: %s\n', seq_name, ft{1});

    no_of_frames = size(frames_type, 2);
    % frame data, mad
    frames_mc_mad = NaN(1, no_of_frames); % each mc frame's mad
    frames_smoothness_cost = NaN(1, no_of_frames); % each frame's smoothness cost

    for frame_no = 1 : no_of_frames
        frame_rgb = imread(sprintf(orig_input_file_fmt, frame_no));
        frame = rgb2gray(frame_rgb);

        % ignore other frames for now
        if frame_no > 1 && frames_type(frame_no) == 'p'

            % fill u and v with same mv from block
            [height, width, chans] = size(frame);
            [frame_flo, frame_occ_map] = load_frame_flow(ft{1}, seq_name, frame_no, flo_file_fmt, occ_file_fmt, mvs_x, mvs_y, frame, frame_prev, mb_size);

            if 1 % visualize mvs
                viz_mvs_fig_title = sprintf('%s, frame: %d', seq_name, frame_no);
                viz_mvs = visualize_mvs(frame_rgb, viz_mvs_fig_title, 1, frame_flo, 16, 16, 1); % visualize every 16th mv
                saveas(viz_mvs, sprintf('tmp/%s_vismvs_frame%04d_%s', seq_name, frame_no, ft{1}), 'svg');
            end

            if 1 % save flow color image
                vis_flow_color = flowToColor(frame_flo);
                imwrite(vis_flow_color, sprintf('tmp/%s_visflow_frame%04d_%s.png', seq_name, frame_no, ft{1}));
            end

            mc_previous = generate_mc_frame(frame_prev, frame_flo);

            frames_mc_mad(frame_no) = mean2(abs(double(frame) - double(mc_previous)));
            frames_smoothness_cost(frame_no) = smoothness_cost_frame(frame_flo);
            fprintf("frame_%03d, mc_diff: %.16f, smoothness: %d\n", frame_no, frames_mc_mad(frame_no), frames_smoothness_cost(frame_no));

            % figure(2);
            % imshow(frame_prev);
            % title('The previous frame');
            %
            if 1 % show and save mc frame
                mc_previous_rgb = uint8(generate_mc_frame(frame_rgb_prev, frame_flo)); % from double
                figure(3);
                imshow(mc_previous_rgb); title('The MC Previous Frame');
                % write mc frame to disk
                imwrite(mc_previous_rgb, sprintf('tmp/%s_mc_frame_%04d_%s.png', seq_name, frame_no, ft{1}));
            end

            % figure(4);
            % imshow(uint8(128 + double(frame_prev) - double(frame)));
            % title('The (non-mc) frame difference');
            %
            % figure(5);
            % imshow(uint8(128 + double(frame_prev) - double(mc_previous)));
            % title('The MC frame difference');
        end

        frame_rgb_prev = frame_rgb;
        frame_prev = frame;
        frame_no = frame_no + 1;
    end

    % % show mad graphs
    % figure(1);
    % hold on;
    i_y = ~isnan(frames_mc_mad);% & ~isnan(frames_non_mc_mad);
    % frames_x = 1 : size(i_y(i_y), 2);
    % plot(frames_x, frames_mc_mad(i_y));
    % plot(frames_x, frames_smoothness_cost(i_y));
    % plot(frames_x, frames_non_mc_mad(i_y));
    % legend({'MC MAD', 'Smoothness Cost'});
    % xlabel('Frame'); ylabel('Cost');
    % hold off;

    % calc avg costs: include only non-nan values
    seqs_avg_mc_mad(seq_i, ft_i) = mean(frames_mc_mad(~isnan(frames_mc_mad)));
    seqs_avg_sm_cost(seq_i, ft_i) = mean(frames_smoothness_cost(~isnan(frames_smoothness_cost)));

    fprintf("avg_mc_diff: %.16f, avg_sm_cost: %.16f\n", seqs_avg_mc_mad(seq_i, ft_i), seqs_avg_sm_cost(seq_i, ft_i));
end
end

% sequence vs avg mc mad
figure(6);
hold on;
title('Sequence vs Average MC Frame MAD');
plot_x = 1 : size(seqs_avg_mc_mad, 1);
bar(plot_x, [ seqs_avg_mc_mad(:, 1), seqs_avg_mc_mad(:, 2), seqs_avg_mc_mad(:, 3), seqs_avg_mc_mad(:, 4), seqs_avg_mc_mad(:, 5) ]); % 1 gt, 2 ffmpeg, 3 fm, 4 df, 5 pca
legend({'Groundtruth', 'FFmpeg Raw MVs', 'FastMotion', 'DeepFlow', 'PCA-Flow'});
xlabel('Sequence'); ylabel('Average MC MAD');
hold off;

% sequence vs avg mc mad
figure(7);
hold on;
title('Sequence vs Average Smoothness Cost');
plot_x = 1 : size(seqs_avg_sm_cost, 1);
bar(plot_x, [ seqs_avg_sm_cost(:, 1), seqs_avg_sm_cost(:, 2), seqs_avg_sm_cost(:, 3), seqs_avg_sm_cost(:, 4), seqs_avg_sm_cost(:, 5) ]); % 1 gt, 2 ffmpeg, 3 fm, 4 df, 5 pca
legend({'Groundtruth', 'FFmpeg Raw MVs', 'FastMotion', 'DeepFlow', 'PCA-Flow'});
xlabel('Sequence'); ylabel('Average Smoothness Cost');
hold off;

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
function flow = fill_dense_mvs_from_blocks(frame_size, mvs, mb_size)
    block_size_h = mb_size(1); block_size_w = mb_size(2);
    flow = NaN(frame_size(1), frame_size(2), 2);
    for i = 1 : size(mvs, 1)
        for j = 1 : size(mvs, 2)
            for mb_i = 1 : block_size_h
                for mb_j = 1 : block_size_w
                    % conditions, to make sure the matrix doesn't grow more
                    % than x, y
                    if mb_i + (i - 1) * block_size_h <= frame_size(1) ...
                            && mb_j + (j - 1) * block_size_w <= frame_size(2)
                        flow(mb_i + (i - 1) * block_size_h, ...
                            mb_j + (j - 1) * block_size_w, ...
                            1 ) = mvs(i, j, 1);
                        flow(mb_i + (i - 1) * block_size_h, ...
                            mb_j + (j - 1) * block_size_w, ...
                            2 ) = mvs(i, j, 2);
                    end
                end
            end
        end
    end
end

function [frame_flo, frame_occ_map] = load_frame_flow(flow_type, seq_name, frame_no, flo_file_fmt, occ_file_fmt, mvs_x, mvs_y, frame, frame_prev, mb_size)

    flow_cache_dir = 'flow-cache';
    [height, width, chans] = size(frame);
    frame_flo_flipped_filename = sprintf('%s/%s/%s/frame_%04d.flo', flow_cache_dir, seq_name, flow_type, frame_no);

    % load or generate occlusion map
    if strcmp(flow_type, 'groundtruth')
        frame_occ_map = imread(sprintf(occ_file_fmt, frame_no - 1)) > 128; % load prev frame occ file, as we are generating current frame from previous frame.
    else
        frame_occ_map = zeros([height, width]); % empty map; no occlusions
    end

    if isfile(frame_flo_flipped_filename) % check if file exists
        fprintf('load_frame_flow: returning pre-generated flo file\n');
        frame_flo = readFlowFile(frame_flo_flipped_filename);
        return;
    end

    switch flow_type
        case 'groundtruth'
            frame_flo = readFlowFile(sprintf(flo_file_fmt, frame_no - 1)); % flow files have negative mvs footnote [1]
        case {'ffmpeg', 'fastmotion'} % ffmpeg mvs or fast motion
            frame_mvs(:, :, 1) = mvs_x(:, :, frame_no);
            frame_mvs(:, :, 2) = mvs_y(:, :, frame_no);
            if strcmp(flow_type, 'fastmotion')
                frame_mvs = fast_motion(frame, frame_prev, frame_mvs, mb_size, frame_no);
            end
            frame_flo = fill_dense_mvs_from_blocks([height, width], frame_mvs, mb_size);
        case {'deepflow', 'pca-flow'} % opencv
            % generate flow file
            ret_code = system(sprintf('./%s %s %s tmp/flow.flo', ['opencv-', flow_type], sprintf(orig_input_file_fmt, frame_no - 1), sprintf(orig_input_file_fmt, frame_no)));
            if ret_code ~= 0
                error('flow gen exit code is: %d', ret_code);
            end
            % read flow file
            frame_flo = readFlowFile('tmp/flow.flo');
    end

    % fwd mvs to bwd
    if ~strcmp(flow_type, 'ffmpeg') && ~strcmp(flow_type, 'fastmotion')
        frame_flo = flip_flo_fwd_to_bwd(frame_flo, frame_occ_map); % test, arg: -ve, i.e. orig dir
    end

    % save flow, so that we don't have to generate it everytime:
    %    check directory:
    [success, message, messageid] = mkdir(sprintf('%s/%s/%s', flow_cache_dir, seq_name, flow_type));
    if success ~= 1
        error(message);
    end
    %    write flow file
    writeFlowFile(frame_flo, sprintf('%s/%s/%s/frame_%04d.flo', flow_cache_dir, seq_name, flow_type, frame_no));
end

% show vectors using quiver
function fig = visualize_mvs(frame, fig_title, figure_no, mvs, step_w, step_h, show_nan)
    fig = figure(figure_no);
    [height, width, ~] = size(frame);
    imshow(frame); axis on;
    title(fig_title, 'Interpreter', 'none');

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);
    X = x(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    Y = y(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    U = mvs(Y(:, 1), X(1, :), 1);
    V = mvs(Y(:, 1), X(1, :), 2);

    hold on;
    quiver(X, Y, U, V, 0, 'g-', 'linewidth', 1);
    if show_nan %show nan with crosses
        plot(X(isnan(U)), Y(isnan(V)), 'rx');
    end
    shg;
    hold off;
end

% interpolate mc frame. replaces zeros where mvs are NaN
function mc_frame = generate_mc_frame(frame, flow)
    x = ones(size(frame, 1), 1) * (1 : size(frame, 2));
    y = (1 : size(frame, 1))' * ones(1, size(frame, 2));

    % relace NaN values with zero in mc frame
    flow(isnan(flow)) = 0;

    offset_x = x + flow(:, :, 1);
    offset_y = y + flow(:, :, 2);
    mc_frame = double(frame);
    for chan = 1 : size(frame, 3)
        mc_frame(:, :, chan) = interp2(x, y, double(frame(:, :, chan)), offset_x, offset_y);
    end

    % the pixel values are return nan, when (default, linear) extrapolation doesn't work
    % replacing it with zero for averaging
    mc_frame(isnan(mc_frame)) = 0;
end

% note [1]:
% based on experiments and observations:
% mvs in sintel's groundtruth flow files are negated and frame_%04d.flo offset is -1.
% this means for frame 2, the flow file is frame_0001.flo.
% this is best config, tested over each sequence, which gives minimum average
% motion compensated frame difference over whole sequence.
