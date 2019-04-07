% 'occ_map' represents logical map, which is true at occluded areas in current
% frame. since the flow file is mapping from previous frame pixels to current,
% we have to ignore mvs where occ_map is true.
function flow = flip_flo_fwd_to_bwd(input_flow, occ_map)
    [height, width, ~] = size(input_flow);

    X = ones(height, 1) * (1 : width);
    Y = (1 : height)' * ones(1, width);

    flow = nan(size(input_flow));

    new_pos_x = round(X + input_flow(:, :, 1));
    new_pos_y = round(Y + input_flow(:, :, 2));
    for i = 1 : height;
        for j = 1 : width;
            x = new_pos_x(i, j);
            y = new_pos_y(i, j);
            if x > width || x < 1 || y > height || y < 1
                continue;
            end;
            % ignore occluded areas
            if occ_map(i, j)
                continue;
            end
            flow(y, x, 1) = -input_flow(i, j, 1);
            flow(y, x, 2) = -input_flow(i, j, 2);
        end
    end

    % replace nan values
    for i = 1 : height;
        for j = 1 : width;

            if ~isnan(flow(i, j, 1)) && ~isnan(flow(i, j, 2))
                continue;
            end

            % ignore occluded areas
            if occ_map(i, j)
                continue;
            end

            if i == 1 || i == height || j == 1 || j == width
                continue;
            end

            if ~isnan(flow(i - 1, j, 1)) && ~isnan(flow(i + 1, j, 1)) && ...
                ~isnan(flow(i - 1, j, 2)) && ~isnan(flow(i + 1, j, 2))
                flow(i, j, 1) = (flow(i - 1, j, 1) + flow(i + 1, j, 1)) / 2;
                flow(i, j, 2) = (flow(i - 1, j, 2) + flow(i + 1, j, 2)) / 2;
                continue;
            end

            if ~isnan(flow(i, j - 1, 1)) && ~isnan(flow(i, j + 1, 1)) && ...
                ~isnan(flow(i, j - 1, 2)) && ~isnan(flow(i, j + 1, 2))
                flow(i, j, 1) = (flow(i, j - 1, 1) + flow(i, j + 1, 1)) / 2;
                flow(i, j, 2) = (flow(i, j - 1, 2) + flow(i, j + 1, 2)) / 2;
                continue;
            end
        end
    end
end
