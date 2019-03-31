function flow = flip_flo_fwd_to_bwd(input_flow)
    [height, width, ~] = size(input_flow);

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);

    flow = nan(size(input_flow));
    new_pos(:, :, 1) = round(x + input_flow(:, :, 1));
    new_pos(:, :, 2) = round(y + input_flow(:, :, 2));

    for i = 1 : size(new_pos, 1);
        for j = 1 : size(new_pos, 2);
            x = new_pos(i, j, 1);
            y = new_pos(i, j, 2);
            if x > width || x < 1 || y > height || y < 1
                continue;
            end;
            flow(y, x, 1) = -input_flow(i, j, 1);
            flow(y, x, 2) = -input_flow(i, j, 2);
        end
    end
end
