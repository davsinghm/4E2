% neighbors_x/y needs to be of size 3x3.
% nan values of neighbors will be ignored.
% diagonal values of neighbors are multiplied by a factor for normalization
%
% @returns nan if no neighbors were found
function cost = smoothness_cost_mv(mv, neighbors)
    e_dists = nan(1, 1);
    e_dists_i = 1;
    for i = 1 : 3
        for j = 1 : 3
            if (i == 2 && j == 2) || ...
                isnan(neighbors(i, j, 1)) || isnan(neighbors(i, j, 2))
                continue; % ignore centre val
            end

            mv_d = mv - [neighbors(i, j, 1), neighbors(i, j, 2)];
            % TODO multiply with diagonal factor
            e_dists(e_dists_i) = sqrt(mv_d * mv_d');
            e_dists_i = e_dists_i + 1;
        end
    end
    cost = sum(e_dists);
end
