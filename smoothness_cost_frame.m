% uses smoothness_cost_mv to calculate mean
% returns mean of smoothness costs of mvs. ignores nan mvs
% warns about isolated mv. if mv has all nan surroundings
function cost = smoothness_cost_frame(flow)
    costs = nan(1, 1);
    cost_i = 1;
    for i = 1 : size(flow, 1)
        for j = 1 : size(flow, 2)
            mv_x = flow(i, j, 1);
            mv_y = flow(i, j, 2);
            neighbors = get_neighbor_mvs(j, i, flow);

            % don't include cost of nan mv in costs
            if isnan(mv_x) || isnan(mv_y)
                continue;
            end

            smoothness = smoothness_cost_mv([mv_x, mv_y], neighbors);
            if ~isnan(smoothness)
                costs(cost_i) = smoothness;
                cost_i = cost_i + 1;
            else
                fprintf('warning: (isolated mv?) the smoothness cost is nan at (i, j): %d, %d\n', i, j);
            end

        end
    end
    cost = mean(costs);
end
