sigma1 = 65e-6;
sigma2 = 55e-6;
sigmaA = 33e-6;
V0 = 120;
nx = 1000;
x = linspace(-5 * sigmaA,5 * sigmaA,nx);
[X,Y] = meshgrid(x,x);
atomicDensity = boseFunctionApprox(exp(-(X.^2+Y.^2)/(sigmaA^2)),2);
atomicDensity = atomicDensity ./ sum(atomicDensity(:));
V1 = V0 * exp(-2 * (X.^2 + Y.^2)/(sigma1)^2);
V2 = V0 * exp(-2 * (X.^2 + Y.^2)/(sigma2)^2);
figure(1)
imagesc(V1-V2)
title("Net Depth [Er]")
colorbar
figure(2)
imagesc(atomicDensity)
title("Atomic Density")
colorbar
disp(sum((V1-V2).*atomicDensity,'all'))