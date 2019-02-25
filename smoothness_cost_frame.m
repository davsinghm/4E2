% uses smoothness_cost_mv to calculate mean
function cost = smoothness_cost_frame(mvs_x, mvs_y)
    mbs_width = size(mvs_x, 2);
    mbs_height = size(mvs_y, 1);
    costs = zeros(size(mvs_x));
    for mb_x = 1 : mbs_width
        for mb_y = 1 : mbs_height
            [neighbors_x, neighbors_y] = get_neighbors(mb_x, mb_y, mvs_x, mvs_y);
            costs(mb_y, mb_x) = smoothness_cost_mv(mvs_x(mb_y, mb_x), mvs_y(mb_y, mb_x), neighbors_x, neighbors_y);
        end
    end
end

function [neighbors_x, neighbors_y] = get_neighbors(mb_x, mb_y, mvs_x, mvs_y)
    neighbors_x = nan(3, 3);
    neighbors_y = nan(3, 3);
    start_x = -1; start_y = -1;
    end_x = 1; end_y = -1;
    if (mb_x == 1)
        start_x = 0;
    end
    if (mb_y == 1)
        start_y = 0;
    end
    if (mb_x == size(mvs_x, 2))
        end_x = 0;
    end
    if (mb_y == size(mvs_y, 1))
        end_y = 0;
    end
    for nx = start_x : end_x
        for ny = start_y : end_y
        end
    end
end
