function [neighbors_x, neighbors_y] = get_neighbor_mvs(mb_x, mb_y, mvs_x, mvs_y)
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
