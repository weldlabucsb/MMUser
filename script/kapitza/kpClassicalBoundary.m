function Omega = kpClassicalBoundary(alpha,idx)
arguments
    alpha = linspace(1,30,100);
    idx = 1
end
switch idx
    case 1
        Omega = alpha/sqrt(2);
    case 2
        Omega = 0.126491 * sqrt(-250. + 139. * alpha);
    case 3
        Omega = 0.126491 * sqrt(250. + 139. * alpha);
end
end

