function fast_motion(frame, frame_prev, mvs_x, mvs_y, mb_size)
    mbs_width = size(mvs_x, 2);
    mbs_height = size(mvs_y, 1);
    % iteration is for skipping the block in current frame
    for iter = 0 : 2
        for mb_x = 2 + iter : 3 : mbs_width - 1
            for mb_y = 2 + iter : 3 : mbs_height - 1
                min_cost = 1024 * 1024 * 1024; %TODO

                % prepare candidate mvs
                cand_mv_x = zeros(3, 3);
                cand_mv_y = zeros(3, 3);
                for cx = -1 : 1
                    for cy = -1 : 1
                        cand_mv_x(2 + cy, 2 + cx) = mvs_x(mb_y + cy, mb_x + cx);
                        cand_mv_y(2 + cy, 2 + cx) = mvs_y(mb_y + cy, mb_x + cx);
                    end
                end

                % try new candidates
                for cx = 1 : 3
                    for cy = 1 : 3
                        mvc_x = cand_mv_x(cx);
                        mvc_y = cand_mv_y(cy);
                        cost = cost_mad(frame, frame_prev, mvs_x, mvs_y, mb_x, mb_y, mb_size);
                        if min_cost < cost
                            mvs_x(mb_y, mb_x) = mvc_x;
                            mvs_y(mb_y, mb_x) = mvc_y;
                            min_cost = cost;
                        end
                    end
                end
            end
        end
    end
end

% calc mad for current func
function cost = cost_mad(frame, frame_prev, mvs_x, mvs_y, mb_x, mb_y, mb_size)
    mv = [mvs_y(mb_y, mb_x), mvs_x(mb_y, mb_x)];
    mb_diff = zeros(mb_size);
    start_x = mb_x * mb_size(2);
    start_y = mb_y * mb_size(1);
    for x1 = 1 : mb_size(2)
        for y1 = 1 : mb_size(1)
            curr_x = max(0, min(start_y + y1, size(frame, 2)));
            curr_y = max(0, min(start_x + x1, size(frame, 1)));
            prev_x = max(0, min(start_y + y1 + mv(2), size(frame_prev, 2)));
            prev_y = max(0, min(start_x + x1 + mv(1), size(frame_prev, 1)));
            mb_diff(y1, x1) = frame(curr_y, curr_x) - frame_prev(prev_y, prev_x);
        end
    end
    cost = mean2(abs(mb_diff));
end
