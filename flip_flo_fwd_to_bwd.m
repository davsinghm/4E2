function flo = flip_flo_fwd_to_bwd(orig_flo)
    [height, width, ~] = size(orig_flo);

    x = ones(height, 1) * (1 : width);
    y = (1 : height)' * ones(1, width);

    flo = nan(size(orig_flo));
    temp_flo(:, :, 1) = round(x + orig_flo(:, :, 1));
    temp_flo(:, :, 2) = round(y + orig_flo(:, :, 2));

    for i = 1 : size(temp_flo, 1);
        for j = 1 : size(temp_flo, 2);
            x = temp_flo(i, j, 1);
            y = temp_flo(i, j, 2);
            if x > width || x < 1 || y > height || y < 1
                continue;
            end;
            flo(y, x, 1) = -orig_flo(i, j, 1);
            flo(y, x, 2) = -orig_flo(i, j, 2);
        end
    end
end
