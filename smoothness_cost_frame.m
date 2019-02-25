% uses smoothness_cost_mv to calculate mean
function cost = smoothness_cost_frame(mvs_x, mvs_y)
    mbs_width = size(mvs_x, 2);
    mbs_height = size(mvs_y, 1);
    costs = zeros(size(mvs_x));
    for mb_x = 1 : mbs_width
        for mb_y = 1 : mbs_height
            [neighbors_x, neighbors_y] = get_neighbors(mb_x, mb_y, mvs_x, mvs_y);
            sc = smoothness_cost_mv(mvs_x(mb_y, mb_x), mvs_y(mb_y, mb_x), neighbors_x, neighbors_y);
            if isnan(sc)
                sc = 0;
                fprintf('warning: the smoothness cost is nan for mb: %d, %d\n', mb_x, mb_y);
            end
            costs(mb_y, mb_x) = sc;
        end
    end
    cost = mean2(costs);
end

function [neighbors_x, neighbors_y] = get_neighbors(mb_x, mb_y, mvs_x, mvs_y)
    neighbors_x = nan(3, 3);
    neighbors_y = nan(3, 3);
    start_x = -1; start_y = -1;
    end_x = 1; end_y = 1;
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
            neighbors_x(2 + ny, 2 + nx) = mvs_x(mb_y + ny, mb_x + nx);
            neighbors_y(2 + ny, 2 + nx) = mvs_y(mb_y + ny, mb_x + nx);
        end
    end
end
