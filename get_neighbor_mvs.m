function neighbors = get_neighbor_mvs(x, y, flow)
    neighbors = nan(3, 3, 2);
    start_x = -1; start_y = -1;
    end_x = 1; end_y = 1;
    if (x == 1)
        start_x = 0;
    end
    if (y == 1)
        start_y = 0;
    end
    if (x == size(flow, 2))
        end_x = 0;
    end
    if (y == size(flow, 1))
        end_y = 0;
    end
    for nx = start_x : end_x
        for ny = start_y : end_y
            neighbors(2 + ny, 2 + nx, 1) = flow(y + ny, x + nx, 1);
            neighbors(2 + ny, 2 + nx, 2) = flow(y + ny, x + nx, 2);
        end
    end
end
