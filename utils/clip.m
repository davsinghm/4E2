% TODO inline min and max functions
function ret = clip(val, a, b)
    ret = max(a, min(val, b));
