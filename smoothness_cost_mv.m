% neighbors_x/y needs to be of size 3x3.
% nan values of neighbors will be ignored.
% diagonal values of neighbors are multiplied by a factor for normalization
%
% @returns nan if no neighbors were found
function cost = smoothness_cost_mv(mv_x, mv_y, neighbors_x, neighbors_y)
    e_dists = nan(1, 1);
    num = 0;
    for n_y = 1 : 3
        for n_x = 1 : 3
            if (n_x == 2 && n_y == 2)
                continue; % ignore centre val
            end
            if (~isnan(neighbors_x(n_y, n_x)) && ~isnan(neighbors_y(n_y, n_x)))
                num = num + 1;
                mv_d = [mv_x, mv_y] - [neighbors_x(n_y, n_x), neighbors_y(n_y, n_x)];
                % TODO multiply with diagonal factor
                e_dists(num) = sqrt(mv_d * mv_d');
            end
        end
    end
    cost = sum(e_dists);
end
