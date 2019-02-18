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
    ret_code = system(strcat("cd FFmpeg ", ...
                    "&& make ", ...
                    "&& ./ffmpeg -y -flags2 +export_mvs -i ", "../", input_file, " ", ...
                    "-vf codecview=mv_type=fp+bp -c:v libx264 -preset ultrafast -crf 0 ", ...
                    "../test_out.mp4 > ../", mvs_filename));
    if ret_code == 0
        [mvs_x, mvs_y] = extract_mvs(mvs_filename, block_size_w, block_size_h);
    else
        fprintf("\nffmpeg exit code is: %d\n", ret_code);
        return;
    end
end

% open the video for visualization
frame = 78;
video_reader = VideoReader(input_file);
input_video_frame = read(video_reader, frame);
figure(1);
[rows, cols, chans] = size(input_video_frame);
x = ones(rows, 1) * (1 : cols);
y = (1 : rows)' * ones(1, cols);
image((1:cols), (1:rows), input_video_frame);
title(['Frame ', num2str(frame)]);

% show vectors using quiver
xpos = x(floor(block_size_w / 2) : block_size_w : end, ...
         floor(block_size_h / 2) : block_size_h : end);
ypos = y(floor(block_size_w / 2) : block_size_w : end, ...
         floor(block_size_h / 2) : block_size_h : end);
u = NaN(size(xpos));
v = NaN(size(xpos));
for i = 1 : min(size(u, 1), size(mvs_x, 1))
    for j = 1 : min(size(v, 2), size(mvs_y, 2))
        u(i, j) = mvs_x(i, j, frame);
        v(i, j) = mvs_y(i, j, frame);
    end
end

%vx(1 : 1 : end, 1 : 1 : end) = -15 * ones(size(Xpos));
%vy(1 : 1 : end, 1 : 1 : end) = 25 * ones(size(Xpos));
hold on
quiver(xpos, ypos, u, v, 0, 'r-', 'linewidth', 1); shg
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

previous_video_frame = read(video_reader, frame - 1);
figure(2);
image(previous_video_frame);
title('The previous frame');

% fill u and v with same mv from block
u = NaN(size(x));
v = NaN(size(x));
for i = 1 : size(mvs_y, 1)
    for j = 1 : size(mvs_x, 2)
        for mb_i = 1 : block_size_h
            for mb_j = 1 : block_size_w
                % conditions, to make sure the matrix doesn't grow more
                % than x, y
                if mb_i + (i-1) * block_size_h <= size(x, 1) ...
                        && mb_j + (j - 1) * block_size_w <= size(x, 2)
                    u(mb_i + (i - 1) * block_size_h, ...
                      mb_j + (j - 1) * block_size_w ...
                     ) ...
                       = mvs_x(i, j, frame);
                    v(mb_i + (i - 1) * block_size_h, ...
                      mb_j + (j - 1) * block_size_w ...
                     ) ...
                       = mvs_y(i, j, frame);
                end
            end
        end
    end
end

offset_x = x + u;
offset_y = y + v;
mc_previous = double(previous_video_frame);
for col = 1 : 3
  mcpic ...
        = interp2(x, y, double(previous_video_frame(:, :, col)), ...
                  offset_x, offset_y);
    [index] = find(isnan(mcpic));
    mcpic(index) = zeros(length(index), 1);
    mc_previous(:, :, col) = mcpic;
end

figure(3);
image(uint8(mc_previous));
title('The motion compensated previous frame');

figure(4);
image(uint8(128 + double(previous_video_frame) - double(input_video_frame)));
title('The (non-mc) frame difference');


figure(5);
image(uint8(128 + double(previous_video_frame) - double(mc_previous)));
title('The MC frame difference');

non_mc_e = double(previous_video_frame) - double(input_video_frame);
mc_e = double(input_video_frame) - double(mc_previous);
mae_non_mc_e =  mean(mean(abs(non_mc_e(:, :, 1))))
mae_mc_e = mean(mean(abs(mc_e(:, :, 1))))


% need to generate error based on original frames
