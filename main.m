addpath 'utils' 'utils/flow_code';

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

avg_seqs_mc_mad = NaN(1, 3);
seqs = get_sintel_sequences();

for me = 1 : 3 % 1 for gt, 2 for fm, 3 for other
for seq_i = 1 : size(seqs, 1)

    seq_name = seqs(seq_i, 1);
    frames_dir = seqs(seq_i, 2);
    flo_dir = seqs(seq_i, 3);
    %no_of_frames = str2num(seqs(seq_i, 4)); do this when not restricted to p

    orig_input_file_fmt = sprintf('%s/frame_%%04d.png', frames_dir);
    flo_file_fmt = sprintf('%s/frame_%%04d.flo', flo_dir); % if loading external mvs

    % generate and read ffmpeg mvs
    if me == 2 || 1 % always do this for now to check frame_type (or no_of_frames)
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
        [mvs_x, mvs_y, mvs_type, frames_type] = extract_mvs(temp_mvs_file, block_size_w, block_size_h);
    end

    no_of_frames = size(frames_type, 2);
    % frame data, mad
    frames_mc_mad = NaN(1, no_of_frames);
    %frames_non_mc_mad = NaN(1, no_of_frames);
    %frames_smoothness_cost = NaN(1, no_of_frames);

    for frame_no = 1 : no_of_frames
        frame = rgb2gray(imread(sprintf(orig_input_file_fmt, frame_no)));

        % ignore other frames for now
        if frame_no > 1 && frames_type(frame_no) == 'p'

            % fill u and v with same mv from block
            [height, width, chans] = size(frame);
            switch me
                case 1 % use groundtruth
                    frame_flo = -readFlowFile(sprintf(flo_file_fmt, frame_no - 1)); % flow files have negative mvs footnote [1]
                    frame_flo = flip_flo_fwd_to_bwd(-frame_flo); % test, arg: -ve, i.e. orig dir
                case {2, 3} % ffmpeg mvs or fast motion
                    frame_mvs_x = mvs_x(:, :, frame_no);
                    frame_mvs_y = mvs_y(:, :, frame_no);
                    if me == 3 % fast motion: refine motion vectors
                        %[frame_mvs_x, frame_mvs_y] = fast_motion(frame, frame_prev, frame_mvs_x, frame_mvs_y, mb_size, frame_no);
                    end
                    frame_flo = fill_dense_mvs_from_blocks([height, width], frame_mvs_x, frame_mvs_y, block_size_w, block_size_h);
            end

            if 0 % visualize mvs
                visualize_mvs(frame, seq_name, 1, frame_flo, 16, 16); % visualize every 16th mv
            end

            if 0 %save flow color image
                vis_flow_color = flowToColor(frame_flo);
                imwrite(vis_flow_color, sprintf('tmp/frame_%04d.png', frame_no));
            end

            mc_previous = generate_mc_frame(frame_prev, frame_flo);

            mc_mad = mean2(abs(double(frame) - double(mc_previous)));
            non_mc_mad = mean2(abs(double(frame) - double(frame_prev)));
            smoothness_cost = smoothness_cost_frame(frame_flo(1), frame_flo(2));

            frames_mc_mad(frame_no) = mc_mad;
            %frames_non_mc_mad(frame_no) = non_mc_mad;
            %frames_smoothness_cost(frame_no) = smoothness_cost;
            fprintf("frame_no: %03d, mc_diff: %.16f, smoothness: %d\n", frame_no, mc_mad, smoothness_cost);

            % figure(2);
            % imshow(frame_prev);
            % title('The previous frame');
            %
            % figure(3);
            % imshow(uint8(mc_previous));
            % title('The motion compensated previous frame');
            %
            % figure(4);
            % imshow(uint8(128 + double(frame_prev) - double(frame)));
            % title('The (non-mc) frame difference');
            %
            % figure(5);
            % imshow(uint8(128 + double(frame_prev) - double(mc_previous)));
            % title('The MC frame difference');
        end

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

    avg_seq_mc_mad = mean(frames_mc_mad(i_y));
    fprintf("avg_mc_diff: %.16f\n", avg_seq_mc_mad);
    avg_seqs_mc_mad(seq_i, me) = avg_seq_mc_mad;

end
end

figure(2);
hold on;
avg_frames_x = 1 : size(avg_seqs_mc_mad, 1);
plot(avg_frames_x, avg_seqs_mc_mad(:, 1)); % 1 == gt
plot(avg_frames_x, avg_seqs_mc_mad(:, 2)); % 2 == ffmpeg
plot(avg_frames_x, avg_seqs_mc_mad(:, 3)); % 3 == fm
legend({'Groundtruth', 'FFmpeg Raw MVs', 'FastMotion'});
xlabel('Sequence'); ylabel('Average MC MAD');
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
function visualize_mvs(frame, seq_name, figure_no, mvs, step_w, step_h, show_nan)
    figure(figure_no);
    [height, width, ~] = size(frame);
    imshow(frame); axis on;
    title([seq_name, ', F: ', num2str(figure_no)]);

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);
    X = x(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    Y = y(floor(step_w / 2) : step_w : end, floor(step_h / 2) : step_h : end);
    U = mvs(Y(: , 1), X(1, :), 1);
    V = mvs(Y(: , 1), X(1, :), 2);

    hold on;
    quiver(X, Y, U, V, 0, 'g-', 'linewidth', 1);
    if show_nan %show nan with crosses
        plot(X(isnan(U)), Y(isnan(V)), 'rx');
    end
    shg;
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

% note [1]:
% based on experiments and observations:
% mvs in sintel's groundtruth flow files are negated and frame_%04d.flo offset is -1.
% this means for frame 2, the flow file is frame_0001.flo.
% this is best config, tested over each sequence, which gives minimum average
% motion compensated frame difference over whole sequence.
