function inits = getInit(lb, ub, numSections, numRuns)
    %This function returns grid initializations
    numP    = length(lb);         %number of free parameters
    inits   = NaN(numRuns, numP); %initialize the matrix
    %given the number of sections and the lower and upper boundaries,
    %we can make a finer grid for each parameter
    midVals = arrayfun(@(idx) linspace(lb(idx), ub(idx), numSections), ...
                1:numP, 'UniformOutput', false);
    %repeatedly draw a number from 1:numSections with replacement for each
    %parameter 
    Indices = arrayfun(@(idx) randsample(numSections, numRuns, true), 1:numP,...
                'UniformOutput', false);
    for i = 1:numP; inits(:,i) = midVals{i}(Indices{i}); end
end