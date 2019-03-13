function mvs_out = fast_motion(frame, frame_prev, mvs, mb_size, frame_no)
    %TODO only add (0, 0) for skip blocks as candidate

    scale = 4; % for quaterpel, 2 and 1 if disabled
    lambda = 0.5;
    frame = imresize(frame, scale);
    frame_prev = imresize(frame_prev, scale);
    mb_size = scale * mb_size;

    frame_width = size(frame, 2);
    frame_height = size(frame, 1);
    write_stats = 0;
    if write_stats
        stats_file = fopen(sprintf('fm_stats_frame%03d.txt', frame_no), 'w');
    end

    for iter = 1 : 3
        % this iteration is for jumping the block in current frame
        %for jump = 0 : 0
            for mb_x = 2 : size(mvs, 2) - 1 % TODO handle edge mbs
                for mb_y = 2 : size(mvs, 1) - 1
                    % prepare candidate mvs, make sure to include current mv
                    cand_mv = zeros(1, 2);
                    candidates = 1;

                    % add valid neighbors as candidates
                    for cx = -1 : 1
                        for cy = -1 : 1
                            c_mv_x = mvs(mb_y + cy, mb_x + cx, 1);
                            c_mv_y = mvs(mb_y + cy, mb_x + cx, 2);
                            if ~isnan(c_mv_x) && ~isnan(c_mv_y) && c_mv_x ~= 0 && c_mv_y ~= 0 %ignore nan and already added (0, 0) mvs
                                cand_mv(candidates, 1) = c_mv_x;
                                cand_mv(candidates, 2) = c_mv_y;
                                candidates = candidates + 1;
                            end
                        end
                    end

                    % add (0, 0) to candidates
                    cand_mv(candidates, 1) = 0;
                    cand_mv(candidates, 2) = 0;
                    candidates = candidates + 1;

                    % add for each +/- offset
                    if 1
                        c_no = candidates;
                        for offset = 0.25 : 0.25 : 0.5
                            for c_i = 1 : c_no
                                cand_mv(candidates, 1) = cand_mv(c_i, 1) + offset;
                                cand_mv(candidates, 2) = cand_mv(c_i, 2) + offset;
                                candidates = candidates + 1;
                                cand_mv(candidates, 1) = cand_mv(c_i, 1) + offset;
                                cand_mv(candidates, 2) = cand_mv(c_i, 2) - offset;
                                candidates = candidates + 1;
                                cand_mv(candidates, 1) = cand_mv(c_i, 1) - offset;
                                cand_mv(candidates, 2) = cand_mv(c_i, 2) + offset;
                                candidates = candidates + 1;
                                cand_mv(candidates, 1) = cand_mv(c_i, 1) - offset;
                                cand_mv(candidates, 2) = cand_mv(c_i, 2) - offset;
                                candidates = candidates + 1;
                            end
                        end
                    end

                    % frame val positions at current mb
                    start_x = (mb_x - 1) * mb_size(2) + 1;
                    start_y = (mb_y - 1) * mb_size(1) + 1;
                    end_x = start_x + mb_size(2) - 1;
                    end_y = start_y + mb_size(1) - 1;
                    block_xs = start_x : scale : end_x;
                    block_ys = start_y : scale : end_y;
                    % skip block if out of bounds
                    if end_x > frame_width || start_x < 1 || end_y > frame_height || start_y < 1
                        continue;
                    end
                    block_curr = frame(block_ys, block_xs);
                    neighbors = get_neighbor_mvs(mb_x, mb_y, mvs);
                    min_cost = intmax('int64'); % initial

                    % test new candidates
                    for cand = 1 : candidates - 1
                        mv_x = cand_mv(cand, 1) * scale;
                        mv_y = cand_mv(cand, 2) * scale;

                        % skip if out of bounds
                        if  end_x + round(mv_x) > frame_width  || start_x + round(mv_x) < 1 || ...
                            end_y + round(mv_y) > frame_height || start_y + round(mv_y) < 1
                            continue;
                        end

                        mad = mean2(abs(block_curr - frame_prev(block_ys + round(mv_y), block_xs + round(mv_x))));
                        smoothness = smoothness_cost_mv([cand_mv(cand, 1), cand_mv(cand, 2)], neighbors);
                        cost = mad + lambda * smoothness;
                        if cost < min_cost
                            if write_stats
                                if min_cost ~= intmax('int64')
                                    fprintf(stats_file, 'mb: (%4d, %4d), min_cost: %10.05f, new_cost: %10.05f(mad: %7.02f, smc: %7.02f), mv: (%9.04f, %9.04f), new_mv: (%9.04f, %9.04f)\n', ...
                                            mb_x, mb_y, min_cost, cost, mad, smoothness, mvs(mb_y, mb_x, 1), mvs(mb_y, mb_x, 2), cand_mv(cand, 1), cand_mv(cand, 2));
                                end
                            end
                            mvs(mb_y, mb_x, 1) = cand_mv(cand, 1);
                            mvs(mb_y, mb_x, 2) = cand_mv(cand, 2);
                            min_cost = cost;
                        end
                    end
                end
            end
        %end
    end

    if write_stats
        fclose(stats_file);
    end

    mvs_out = mvs;
end
