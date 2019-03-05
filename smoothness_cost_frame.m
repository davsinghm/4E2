% uses smoothness_cost_mv to calculate mean
function cost = smoothness_cost_frame(mvs_x, mvs_y)
    mbs_width = size(mvs_x, 2);
    mbs_height = size(mvs_y, 1);
    costs = zeros(size(mvs_x));
    for mb_x = 1 : mbs_width
        for mb_y = 1 : mbs_height
            [neighbors_x, neighbors_y] = get_neighbor_mvs(mb_x, mb_y, mvs_x, mvs_y);
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
