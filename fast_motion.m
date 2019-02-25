function [mvs_out_x, mvs_out_y] = fast_motion(frame, frame_prev, mvs_x, mvs_y, mb_size, frame_no)
    mbs_width = size(mvs_x, 2);
    mbs_height = size(mvs_y, 1);
    write_stats = 0;
    if write_stats
        stats_file = fopen(sprintf('fm_stats_frame%03d.txt', frame_no), 'w');
    end

    for iter = 1 : 5
        % this iteration is for jumping the block in current frame
        for jump = 0 : 2
            for mb_x = 2 + jump : 3 : mbs_width - 1
                for mb_y = 2 + jump : 3 : mbs_height - 1
                    % start with current motion vector
                    min_cost = cost_mad(frame, frame_prev, mvs_x(mb_y, mb_x), mvs_y(mb_y, mb_x), mb_x, mb_y, mb_size);

                    % prepare candidate mvs
                    candidates = 1;
                    cand_mv_x = zeros(1, 9);
                    cand_mv_y = zeros(1, 9);
                    for cx = -1 : 1
                        for cy = -1 : 1
                            if (~isnan(mvs_x(mb_y + cy, mb_x + cx)) && ~isnan(mvs_x(mb_y + cy, mb_x + cx)))
                                cand_mv_x(candidates) = mvs_x(mb_y + cy, mb_x + cx);
                                cand_mv_y(candidates) = mvs_y(mb_y + cy, mb_x + cx);
                            end
                            candidates = candidates + 1;
                        end
                    end

                    % add for each +/- offset
                if 0
                    c_no = candidates;
                    for offset = 1 : 2
                        for c_i = 1 : c_no
                            cand_mv_x(candidates) = cand_mv_x(c_i) + offset;
                            cand_mv_y(candidates) = cand_mv_y(c_i) + offset;
                            candidates = candidates + 1;
                            cand_mv_x(candidates) = cand_mv_x(c_i) + offset;
                            cand_mv_y(candidates) = cand_mv_y(c_i) - offset;
                            candidates = candidates + 1;
                            cand_mv_x(candidates) = cand_mv_x(c_i) - offset;
                            cand_mv_y(candidates) = cand_mv_y(c_i) + offset;
                            candidates = candidates + 1;
                            cand_mv_x(candidates) = cand_mv_x(c_i) - offset;
                            cand_mv_y(candidates) = cand_mv_y(c_i) - offset;
                            candidates = candidates + 1;
                        end
                    end
                end

                    % test new candidates
                    for cand = 1 : candidates - 1
                        cost = cost_mad(frame, frame_prev, cand_mv_x(cand), cand_mv_y(cand), mb_x, mb_y, mb_size);
                        if cost < min_cost
                            if write_stats
                                fprintf(stats_file, 'mb: (%d, %d), min_cost: %d, new_cost: %d, mv: (%d, %d), new_mv: (%d, %d)\n', mb_x, mb_y, min_cost, cost, mvs_x(mb_y, mb_x), mvs_y(mb_y, mb_x), cand_mv_x(cand), cand_mv_y(cand));
                            end
                            mvs_x(mb_y, mb_x) = cand_mv_x(cand);
                            mvs_y(mb_y, mb_x) = cand_mv_y(cand);
                            min_cost = cost;
                        end
                    end
                end
            end
        end
    end
    if write_stats
        fclose(stats_file);
    end
    mvs_out_x = mvs_x;
    mvs_out_y = mvs_y;
end

% calc mad for current func
function cost = cost_mad(frame, frame_prev, mv_x, mv_y, mb_x, mb_y, mb_size)
    chans = size(frame, 3);
    % start with nan, so that if loop doesn't run completely, the resulting
    % mean is nan
    mb_diff = nan(mb_size(1), mb_size(2), chans);
    start_x = mb_x * mb_size(2);
    start_y = mb_y * mb_size(1);
    for chan = 1 : chans
        for x1 = 1 : mb_size(2)
            for y1 = 1 : mb_size(1)
                curr_x = clip(floor(start_x + x1), 1, size(frame, 2));
                curr_y = clip(floor(start_y + y1), 1, size(frame, 1));
                prev_x = clip(floor(start_x + x1 + mv_x), 1, size(frame_prev, 2));
                prev_y = clip(floor(start_y + y1 + mv_y), 1, size(frame_prev, 1));
                mb_diff(y1, x1, chan) = double(frame(curr_y, curr_x, chan)) - double(frame_prev(prev_y, prev_x, chan));
            end
        end
    end
    cost = mean2(abs(mb_diff));
end

function ret = clip(val, a, b)
    ret = max(a, min(val, b));
end
