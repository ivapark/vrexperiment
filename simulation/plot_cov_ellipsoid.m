clear; clc;

% ---- load the covariance matrices you saved earlier ----
% If your file is named differently, change it here:
load("empirical_cov_results.mat");   % expects SigmaByCond

% If your variable is called val, comment out the next line.
val = SigmaByCond;

k = 1;              % <-- condition index to visualize (1..27)
S = val(:,:,k);

% safety checks
assert(all(size(S)==[3 3]), "val(:,:,k) must be 3x3.");
S = (S + S')/2;     % symmetrize (numerical stability)

% eigen-decomposition
[V,D] = eig(S);
D = max(D, 0);      % clamp tiny negatives from numerical noise

r = 2;              % 2-sigma ellipsoid (try 1, 2, 3)

% unit sphere
[u,v] = meshgrid(linspace(0,2*pi,60), linspace(0,pi,30));
x = cos(u).*sin(v); 
y = sin(u).*sin(v); 
z = cos(v);
pts = [x(:) y(:) z(:)]';

% transform sphere -> ellipsoid
A = V * sqrt(D) * r;
E = A * pts;

X = reshape(E(1,:), size(x));
Y = reshape(E(2,:), size(y));
Z = reshape(E(3,:), size(z));

figure;
surf(X,Y,Z); 
axis equal; grid on;
xlabel('X'); ylabel('Y'); zlabel('Z');
title("Error covariance ellipsoid (condition " + k + ", r=" + r + ")");
